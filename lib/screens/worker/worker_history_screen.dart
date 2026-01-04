import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

import '../../config/app_config.dart';
import '../../core/services/firestore_service.dart';
import '../../models/evento.dart';
import '../../models/disponibilidad_evento.dart';

class WorkerHistoryScreen extends StatefulWidget {
  const WorkerHistoryScreen({super.key});

  @override
  State<WorkerHistoryScreen> createState() => _WorkerHistoryScreenState();
}

class _WorkerHistoryScreenState extends State<WorkerHistoryScreen> {
  String _selectedFilter = 'Todos';

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    const empresaId = AppConfig.empresaId;

    if (user == null) {
      return const Scaffold(body: Center(child: Text('Inicia sesión')));
    }

    return SafeArea(
      child: Scaffold(
        backgroundColor: const Color(0xFFF3F4F6),
        body: StreamBuilder<List<Evento>>(
          stream: FirestoreService.instance.listenEventos(empresaId),
          builder: (context, eventosSnap) {
            if (!eventosSnap.hasData) {
              return const Center(child: CircularProgressIndicator());
            }

            final eventos = eventosSnap.data!;
            final Map<String, Evento> eventoById = {for (final e in eventos) e.id: e};

            return StreamBuilder<List<DisponibilidadEvento>>(
              stream: FirestoreService.instance
                  .listenSolicitudesDisponibilidadTrabajador(user.uid),
              builder: (context, dispoSnap) {
                if (!dispoSnap.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final solicitudes = dispoSnap.data!;
                final now = DateTime.now();

                final List<HistoryEvent> all = [];

                for (final s in solicitudes) {
                  final e = eventoById[s.eventoId];
                  if (e == null) continue;

                  final status = _statusFor(e, s, now);
                  final extra = _extraInfoFor(e, s, now);

                  all.add(
                    HistoryEvent(
                      id: e.id,
                      title: e.nombre,
                      date: DateFormat("d MMM yyyy", "es_ES").format(e.fechaInicio),
                      time:
                          "${DateFormat("HH:mm").format(e.fechaInicio)} – ${DateFormat("HH:mm").format(e.fechaFin)}",
                      role: (s.trabajadorRol.trim().isEmpty) ? "—" : s.trabajadorRol.trim(),
                      location: _addressForEvento(e),
                      status: status,
                      extraInfo: extra,
                      sortDate: e.fechaInicio,
                    ),
                  );
                }

                // Orden: más reciente arriba
                all.sort((a, b) => b.sortDate.compareTo(a.sortDate));

                final filtered = all.where((ev) {
                  if (_selectedFilter == 'Todos') return true;

                  final map = {
                    'Completados': EventStatus.completed,
                    'Rechazados': EventStatus.rejected,
                    'Próximos': EventStatus.upcoming,
                    'Cancelados': EventStatus.cancelled,
                  };

                  return ev.status == map[_selectedFilter];
                }).toList();

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header (igual)
                    const Padding(
                      padding: EdgeInsets.fromLTRB(16, 18, 16, 10),
                      child: Row(
                        children: [
                          Icon(Icons.history, size: 24),
                          SizedBox(width: 8),
                          Text(
                            'Historial',
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Filtros (igual)
                    Padding(
                      padding: const EdgeInsets.only(left: 16),
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            _filter('Todos'),
                            _filter('Completados'),
                            _filter('Rechazados'),
                            _filter('Próximos'),
                            _filter('Cancelados'),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 12),

                    // Lista (igual)
                    Expanded(
                      child: filtered.isEmpty
                          ? const Center(
                              child: Text(
                                "No hay eventos en este filtro",
                                style: TextStyle(color: Color(0xFF6B7280)),
                              ),
                            )
                          : ListView.builder(
                              padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                              itemCount: filtered.length,
                              itemBuilder: (context, index) {
                                final e = filtered[index];
                                return _HistoryCard(event: e);
                              },
                            ),
                    ),
                  ],
                );
              },
            );
          },
        ),
      ),
    );
  }

  Widget _filter(String label) {
    final selected = label == _selectedFilter;

    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.white : const Color(0xFF111827),
            fontWeight: FontWeight.w500,
          ),
        ),
        selected: selected,
        onSelected: (_) => setState(() => _selectedFilter = label),
        selectedColor: const Color(0xFF111827),
        backgroundColor: Colors.white,
        side: const BorderSide(color: Color(0xFFE5E7EB)),
        labelPadding: const EdgeInsets.symmetric(horizontal: 14),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // LÓGICA: estado del chip + texto extra
  // ─────────────────────────────────────────────────────────────

  EventStatus _statusFor(Evento e, DisponibilidadEvento s, DateTime now) {
    final evEstado = e.estado.toLowerCase();

    // Cancelado por empresa
    if (evEstado == 'cancelado') return EventStatus.cancelled;

    // Rechazado por trabajador
    if (s.estado.toLowerCase() == 'rechazado') return EventStatus.rejected;

    // Aceptado + asignado => próximo o completado
    if (s.asignado == true) {
      if (e.fechaFin.isBefore(now)) return EventStatus.completed;
      return EventStatus.upcoming;
    }

    // Aceptado pero NO asignado, o pendiente => no es próximo
    // Lo metemos como rechazado para que aparezca en "Rechazados" (histórico negativo / no asignado)
    return EventStatus.rejected;
  }

  String _extraInfoFor(Evento e, DisponibilidadEvento s, DateTime now) {
    final evEstado = e.estado.toLowerCase();
    final sEstado = s.estado.toLowerCase();

    if (evEstado == 'cancelado') return "Cancelado por empresa";
    if (sEstado == 'rechazado') return "Rechazado";

    if (s.asignado == true) {
      if (e.fechaFin.isBefore(now)) return "Completado";
      return "Confirmado";
    }

    if (sEstado == 'aceptado') return "Aceptado (no asignado)";
    return "Pendiente";
  }

  String _addressForEvento(Evento e) {
    final parts = <String>[];
    if (e.ciudad.trim().isNotEmpty) parts.add(e.ciudad.trim());
    if (e.direccion.trim().isNotEmpty) parts.add(e.direccion.trim());
    return parts.isEmpty ? "—" : parts.join(' - ');
  }
}

// ─────────────────────────────────────────────────────────────
// MODEL (mismo diseño, sólo añadimos sortDate para ordenar)
// ─────────────────────────────────────────────────────────────

enum EventStatus { completed, rejected, upcoming, cancelled }

class HistoryEvent {
  final String id;
  final String title;
  final String date;
  final String time;
  final String role;
  final String location;
  final EventStatus status;
  final String extraInfo;

  final DateTime sortDate;

  HistoryEvent({
    required this.id,
    required this.title,
    required this.date,
    required this.time,
    required this.role,
    required this.location,
    required this.status,
    required this.extraInfo,
    required this.sortDate,
  });
}

// ─────────────────────────────────────────────────────────────
// CARD (SIN CAMBIOS DE DISEÑO)
// ─────────────────────────────────────────────────────────────

class _HistoryCard extends StatelessWidget {
  final HistoryEvent event;

  const _HistoryCard({required this.event});

  Color _statusColor(EventStatus s) {
    switch (s) {
      case EventStatus.completed:
        return const Color(0xFF10B981);
      case EventStatus.rejected:
        return const Color(0xFFEF4444);
      case EventStatus.upcoming:
        return const Color(0xFF3B82F6);
      case EventStatus.cancelled:
        return const Color(0xFFF59E0B);
    }
  }

  String _statusText(EventStatus s) {
    switch (s) {
      case EventStatus.completed:
        return "Completado";
      case EventStatus.rejected:
        return "Rechazado";
      case EventStatus.upcoming:
        return "Próximo";
      case EventStatus.cancelled:
        return "Cancelado";
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            blurRadius: 10,
            offset: const Offset(0, 4),
            color: Colors.black.withOpacity(0.05),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Título + estado
          Row(
            children: [
              Expanded(
                child: Text(
                  event.title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: _statusColor(event.status).withOpacity(0.12),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  _statusText(event.status),
                  style: TextStyle(
                    color: _statusColor(event.status),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 8),

          // Fecha + Hora
          Row(
            children: [
              const Icon(Icons.calendar_today_outlined, size: 16),
              const SizedBox(width: 6),
              Text(event.date),
              const SizedBox(width: 16),
              const Icon(Icons.schedule, size: 16),
              const SizedBox(width: 6),
              Text(event.time),
            ],
          ),

          const SizedBox(height: 10),

          // Rol
          Row(
            children: [
              const Icon(Icons.work_outline, size: 16),
              const SizedBox(width: 6),
              Text(event.role),
            ],
          ),

          const SizedBox(height: 10),

          // Ubicación
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.location_on_outlined, size: 16),
              const SizedBox(width: 6),
              Expanded(child: Text(event.location)),
            ],
          ),

          const SizedBox(height: 12),

          // Extra info
          Text(
            event.extraInfo,
            style: const TextStyle(
              fontSize: 13,
              color: Color(0xFF6B7280),
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
