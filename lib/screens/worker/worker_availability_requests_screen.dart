import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../config/app_config.dart';
import '../../core/services/firestore_service.dart';
import '../../models/evento.dart';
import '../../models/disponibilidad_evento.dart';

class WorkerAvailabilityRequestsScreen extends StatelessWidget {
  const WorkerAvailabilityRequestsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final empresaId = AppConfig.empresaId;

    if (user == null) {
      return const Scaffold(
        body: Center(
          child: Text(
            'Debes iniciar sesión como trabajador para ver tus solicitudes.',
          ),
        ),
      );
    }

    final trabajadorId = user.uid;

    return Scaffold(
      backgroundColor: const Color(0xFFF3F4F6),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        title: const Text(
          'Mis solicitudes de disponibilidad',
          style: TextStyle(
            color: Color(0xFF111827),
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: StreamBuilder<List<Evento>>(
        stream: FirestoreService.instance.listenEventos(empresaId),
        builder: (context, eventosSnap) {
          if (eventosSnap.connectionState == ConnectionState.waiting &&
              !eventosSnap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final eventos = eventosSnap.data ?? [];
          final mapaEventos = {
            for (final e in eventos) e.id: e,
          };

          return StreamBuilder<List<DisponibilidadEvento>>(
            stream: FirestoreService.instance
                .listenSolicitudesDisponibilidadTrabajador(trabajadorId),
            builder: (context, dispoSnap) {
              if (dispoSnap.connectionState == ConnectionState.waiting &&
                  !dispoSnap.hasData) {
                return const Center(child: CircularProgressIndicator());
              }

              final solicitudes = dispoSnap.data ?? [];

              if (solicitudes.isEmpty) {
                return const Center(
                  child: Text(
                    'De momento no tienes solicitudes de disponibilidad.\n'
                    'Cuando tu empresa te envíe una, aparecerá aquí.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Color(0xFF6B7280),
                    ),
                  ),
                );
              }

              // Ordenamos: pendientes primero, luego aceptadas, luego rechazadas
              solicitudes.sort((a, b) {
                const orden = {'pendiente': 0, 'aceptado': 1, 'rechazado': 2};
                final oa = orden[a.estado] ?? 99;
                final ob = orden[b.estado] ?? 99;
                if (oa != ob) return oa.compareTo(ob);
                return a.creadoEn.compareTo(b.creadoEn);
              });

              return ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                itemCount: solicitudes.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  final d = solicitudes[index];
                  final evento = mapaEventos[d.eventoId];

                  final tituloEvento = evento?.nombre ?? 'Evento ${d.eventoId}';
                  final fecha =
                      evento != null ? _formatFechaCorta(evento.fechaInicio) : '';

                  return Card(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Cabecera: nombre evento + fecha
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  tituloEvento,
                                  style: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              if (fecha.isNotEmpty)
                                Text(
                                  fecha,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Color(0xFF6B7280),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Empresa: $empresaId',
                            style: const TextStyle(
                              fontSize: 11,
                              color: Color(0xFF9CA3AF),
                            ),
                          ),
                          const SizedBox(height: 8),

                          Row(
                            children: [
                              _EstadoDisponibilidadChip(
                                estado: d.estado,
                                asignado: d.asignado,
                              ),
                              const Spacer(),
                              if (d.estado == 'pendiente') ...[
                                TextButton(
                                  onPressed: () async {
                                    await FirestoreService.instance
                                        .actualizarEstadoDisponibilidad(
                                      empresaId: empresaId,
                                      eventoId: d.eventoId,
                                      disponibilidadId: d.id,
                                      nuevoEstado: 'rechazado',
                                    );
                                  },
                                  child: const Text(
                                    'Rechazar',
                                    style: TextStyle(color: Color(0xFFB91C1C)),
                                  ),
                                ),
                                const SizedBox(width: 4),
                                ElevatedButton(
                                  onPressed: () async {
                                    await FirestoreService.instance
                                        .actualizarEstadoDisponibilidad(
                                      empresaId: empresaId,
                                      eventoId: d.eventoId,
                                      disponibilidadId: d.id,
                                      nuevoEstado: 'aceptado',
                                    );
                                  },
                                  child: const Text('Aceptar'),
                                ),
                              ],
                              if (d.estado == 'aceptado' && !d.asignado)
                                const Text(
                                  'Pendiente de asignación',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Color(0xFF6B7280),
                                  ),
                                ),
                              if (d.asignado)
                                const Text(
                                  'ASIGNADO',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF1D4ED8),
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}

class _EstadoDisponibilidadChip extends StatelessWidget {
  final String estado;
  final bool asignado;

  const _EstadoDisponibilidadChip({
    required this.estado,
    required this.asignado,
  });

  @override
  Widget build(BuildContext context) {
    Color bg;
    Color fg;
    String label = estado;

    switch (estado) {
      case 'aceptado':
        bg = const Color(0xFFDCFCE7);
        fg = const Color(0xFF15803D);
        label = 'Disponible';
        break;
      case 'rechazado':
        bg = const Color(0xFFFEF2F2);
        fg = const Color(0xFFB91C1C);
        label = 'No disponible';
        break;
      case 'pendiente':
      default:
        bg = const Color(0xFFE5E7EB);
        fg = const Color(0xFF4B5563);
        label = 'Pendiente';
        break;
    }

    if (asignado) {
      bg = const Color(0xFFDBEAFE);
      fg = const Color(0xFF1D4ED8);
      label = 'Asignado';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w500,
          color: fg,
        ),
      ),
    );
  }
}

String _formatFechaCorta(DateTime d) {
  final dia = d.day.toString().padLeft(2, '0');
  final mes = d.month.toString().padLeft(2, '0');
  final year = d.year.toString();
  return '$dia/$mes/$year';
}
