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
  // ====== THEME (Turneo / Admin) ======
  static const Color _bg = Color(0xFFF6F8FC);
  static const Color _card = Colors.white;
  static const Color _border = Color(0xFFE5E7EB);
  static const Color _textDark = Color(0xFF111827);
  static const Color _textGrey = Color(0xFF6B7280);
  static const Color _blue = Color(0xFF2563EB);

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
        backgroundColor: _bg,
        body: StreamBuilder<List<Evento>>(
          stream: FirestoreService.instance.listenEventos(empresaId),
          builder: (context, eventosSnap) {
            if (eventosSnap.hasError) {
              return Center(child: Text('Error cargando eventos: ${eventosSnap.error}'));
            }
            if (!eventosSnap.hasData) {
              return const Center(child: CircularProgressIndicator());
            }

            final eventos = eventosSnap.data!;
            final Map<String, Evento> eventoById = {for (final e in eventos) e.id: e};

            return StreamBuilder<List<DisponibilidadEvento>>(
              stream: FirestoreService.instance.listenSolicitudesDisponibilidadTrabajador(user.uid),
              builder: (context, dispoSnap) {
                if (dispoSnap.hasError) {
                  return Center(child: Text('Error cargando historial: ${dispoSnap.error}'));
                }
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
                      title: (e.nombre.trim().isEmpty) ? 'Evento' : e.nombre.trim(),
                      date: DateFormat("d MMM yyyy", "es_ES").format(e.fechaInicio),
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
                    // Header (Turneo)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: const [
                          Text(
                            'Historial',
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w900,
                              color: _textDark,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'Tus eventos y su estado',
                            style: TextStyle(
                              color: _textGrey,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Filtros (Turneo)
                    Padding(
                      padding: const EdgeInsets.only(left: 16),
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            _filter('Todos'),
                            _filter('Completados'),
                            _filter('Rechazados'),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 12),

                    Expanded(
                      child: filtered.isEmpty
                          ? const Center(
                              child: Text(
                                "No hay eventos en este filtro",
                                style: TextStyle(
                                  color: _textGrey,
                                  fontWeight: FontWeight.w600,
                                ),
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
            color: selected ? Colors.white : _textDark,
            fontWeight: FontWeight.w800,
          ),
        ),
        selected: selected,
        onSelected: (_) => setState(() => _selectedFilter = label),
        selectedColor: _blue,
        backgroundColor: Colors.white,
        side: const BorderSide(color: _border),
        labelPadding: const EdgeInsets.symmetric(horizontal: 14),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // LÓGICA: estado del chip + texto extra (tu sistema)
  // ─────────────────────────────────────────────────────────────

  EventStatus _statusFor(Evento e, DisponibilidadEvento s, DateTime now) {
    final evEstado = (e.estado).toLowerCase();

    if (evEstado == 'cancelado') return EventStatus.cancelled;
    if (s.estado.toLowerCase() == 'rechazado') return EventStatus.rejected;

    if (s.asignado == true) {
      if (e.fechaFin.isBefore(now)) return EventStatus.completed;
      return EventStatus.upcoming;
    }

    // Aceptado pero no asignado o pendiente -> lo tratamos como rechazo histórico
    return EventStatus.rejected;
  }

  String _extraInfoFor(Evento e, DisponibilidadEvento s, DateTime now) {
    final evEstado = (e.estado).toLowerCase();
    final sEstado = (s.estado).toLowerCase();

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
    return parts.isEmpty ? "—" : parts.join(' · ');
  }
}

// ─────────────────────────────────────────────────────────────
// MODEL
// (✅ Quitadas horas y precio: no existen aquí)
// ─────────────────────────────────────────────────────────────

enum EventStatus { completed, rejected, upcoming, cancelled }

class HistoryEvent {
  final String id;
  final String title;
  final String date;
  final String role;
  final String location;
  final EventStatus status;
  final String extraInfo;
  final DateTime sortDate;

  HistoryEvent({
    required this.id,
    required this.title,
    required this.date,
    required this.role,
    required this.location,
    required this.status,
    required this.extraInfo,
    required this.sortDate,
  });
}

// ─────────────────────────────────────────────────────────────
// CARD (Diseño Turneo)
// ─────────────────────────────────────────────────────────────

class _HistoryCard extends StatelessWidget {
  final HistoryEvent event;

  const _HistoryCard({required this.event});

  static const Color _card = Colors.white;
  static const Color _border = Color(0xFFE5E7EB);
  static const Color _textDark = Color(0xFF111827);
  static const Color _textGrey = Color(0xFF6B7280);

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
    final c = _statusColor(event.status);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _border),
        boxShadow: const [
          BoxShadow(
            color: Color(0x12000000),
            blurRadius: 16,
            offset: Offset(0, 8),
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
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    color: _textDark,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: c.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  _statusText(event.status),
                  style: TextStyle(
                    color: c,
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 10),

          // Fecha (✅ sin horas)
          Row(
            children: [
              const Icon(Icons.calendar_today_outlined, size: 16, color: _textGrey),
              const SizedBox(width: 6),
              Text(
                event.date,
                style: const TextStyle(
                  color: _textDark,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),

          const SizedBox(height: 10),

          // Rol
          Row(
            children: [
              const Icon(Icons.work_outline, size: 16, color: _textGrey),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  event.role,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: _textDark,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 10),

          // Ubicación
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.location_on_outlined, size: 16, color: _textGrey),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  event.location,
                  style: const TextStyle(
                    color: _textGrey,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Extra info
          Text(
            event.extraInfo,
            style: const TextStyle(
              fontSize: 12,
              color: _textGrey,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
