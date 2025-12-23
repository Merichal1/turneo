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
          child: Text('Debes iniciar sesión para ver tus solicitudes.'),
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
          if (eventosSnap.connectionState == ConnectionState.waiting && !eventosSnap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final eventos = eventosSnap.data ?? [];
          final mapaEventos = {for (final e in eventos) e.id: e};

          return StreamBuilder<List<DisponibilidadEvento>>(
            stream: FirestoreService.instance.listenSolicitudesDisponibilidadTrabajador(trabajadorId),
            builder: (context, dispoSnap) {
              if (dispoSnap.connectionState == ConnectionState.waiting && !dispoSnap.hasData) {
                return const Center(child: CircularProgressIndicator());
              }

              final solicitudes = dispoSnap.data ?? [];

              if (solicitudes.isEmpty) {
                return const Center(
                  child: Text(
                    'No tienes solicitudes pendientes.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Color(0xFF6B7280)),
                  ),
                );
              }

              // Ordenar: pendientes primero
              solicitudes.sort((a, b) {
                const orden = {'pendiente': 0, 'aceptado': 1, 'rechazado': 2};
                return (orden[a.estado] ?? 99).compareTo(orden[b.estado] ?? 99);
              });

              return ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: solicitudes.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  final d = solicitudes[index];
                  final evento = mapaEventos[d.eventoId];
                  final tituloEvento = evento?.nombre ?? 'Evento desconocido';
                  final fecha = evento != null ? _formatFechaCorta(evento.fechaInicio) : '';

                  return Card(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  tituloEvento,
                                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                                ),
                              ),
                              if (fecha.isNotEmpty)
                                Text(fecha, style: const TextStyle(fontSize: 12, color: Colors.grey)),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              _EstadoDisponibilidadChip(estado: d.estado, asignado: d.asignado),
                              const Spacer(),
                              if (d.estado == 'pendiente') ...[
                                // BOTÓN RECHAZAR: Solo funcional si no está asignado
                                TextButton(
                                  onPressed: d.asignado 
                                    ? null 
                                    : () async {
                                        final confirmed = await _mostrarDialogoConfirmacion(context);
                                        if (confirmed == true) {
                                          await FirestoreService.instance.actualizarEstadoDisponibilidad(
                                            empresaId: empresaId,
                                            eventoId: d.eventoId,
                                            disponibilidadId: d.id,
                                            nuevoEstado: 'rechazado',
                                          );
                                        }
                                      },
                                  child: Text(
                                    'Rechazar',
                                    style: TextStyle(
                                      color: d.asignado ? Colors.grey : const Color(0xFFB91C1C),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF6366F1),
                                    foregroundColor: Colors.white,
                                  ),
                                  onPressed: () async {
                                    await FirestoreService.instance.actualizarEstadoDisponibilidad(
                                      empresaId: empresaId,
                                      eventoId: d.eventoId,
                                      disponibilidadId: d.id,
                                      nuevoEstado: 'aceptado',
                                    );
                                  },
                                  child: const Text('Aceptar'),
                                ),
                              ],
                              if (d.asignado)
                                const Text(
                                  'ASIGNADO',
                                  style: TextStyle(fontWeight: FontWeight.bold, color: Colors.indigo),
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

  Future<bool?> _mostrarDialogoConfirmacion(BuildContext context) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Rechazar solicitud"),
        content: const Text("¿Estás seguro de que no estás disponible para este evento?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("CANCELAR")),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text("RECHAZAR")),
        ],
      ),
    );
  }
}

class _EstadoDisponibilidadChip extends StatelessWidget {
  final String estado;
  final bool asignado;
  const _EstadoDisponibilidadChip({required this.estado, required this.asignado});

  @override
  Widget build(BuildContext context) {
    Color bg = const Color(0xFFE5E7EB);
    Color fg = const Color(0xFF4B5563);
    String label = 'Pendiente';

    if (asignado) {
      bg = const Color(0xFFDBEAFE);
      fg = const Color(0xFF1D4ED8);
      label = 'Asignado';
    } else if (estado == 'aceptado') {
      bg = const Color(0xFFDCFCE7);
      fg = const Color(0xFF15803D);
      label = 'Disponible';
    } else if (estado == 'rechazado') {
      bg = const Color(0xFFFEF2F2);
      fg = const Color(0xFFB91C1C);
      label = 'No disponible';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
      child: Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: fg)),
    );
  }
}

String _formatFechaCorta(DateTime d) {
  return "${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}";
}