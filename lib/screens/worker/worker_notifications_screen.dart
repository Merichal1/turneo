import 'package:flutter/material.dart';

import '../../config/app_config.dart';
import '../../core/services/firestore_service.dart';
import '../../models/disponibilidad_evento.dart';

class WorkerNotificationsScreen extends StatelessWidget {
  const WorkerNotificationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    const empresaId = AppConfig.empresaId;

    // ⚠️ Mientras no tenemos auth, usa aquí un ID real de trabajador
    const trabajadorIdDemo = 'soeX8CRQY9RFWrBFtmai';

    return Scaffold(
      backgroundColor: const Color(0xFFF3F4F6),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        title: const Text(
          'Notificaciones',
          style: TextStyle(
            color: Color(0xFF111827),
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: false,
      ),
      body: StreamBuilder<List<DisponibilidadEvento>>(
        stream: FirestoreService.instance
            .listenSolicitudesDisponibilidadTrabajador(trabajadorIdDemo),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting &&
              !snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Text(
                'Error al cargar notificaciones:\n${snapshot.error}',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.red),
              ),
            );
          }

          final solicitudes = snapshot.data ?? [];

          if (solicitudes.isEmpty) {
            return const Center(
              child: Text(
                'No tienes notificaciones por ahora.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Color(0xFF6B7280),
                ),
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
            itemCount: solicitudes.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final s = solicitudes[index];

              final fechaTexto = _formatFechaHora(s.creadoEn);

              return Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.04),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ===== Cabecera: icono + título + fecha + chip estado
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(
                          Icons.event_available,
                          size: 20,
                          color: Color(0xFF6366F1),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Solicitud de disponibilidad',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF111827),
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                fechaTexto,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Color(0xFF6B7280),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                s.trabajadorRol.isNotEmpty
                                    ? 'Rol: ${s.trabajadorRol}'
                                    : 'Rol: No especificado',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Color(0xFF4B5563),
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Evento ID: ${s.eventoId}',
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: Color(0xFF9CA3AF),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        _EstadoChip(estado: s.estado),
                      ],
                    ),

                    const SizedBox(height: 12),

                    const Text(
                      'El administrador te pide que confirmes si estás disponible para este evento.',
                      style: TextStyle(
                        fontSize: 13,
                        color: Color(0xFF4B5563),
                      ),
                    ),

                    const SizedBox(height: 12),

                    // ===== Botones Aceptar / Rechazar
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: s.estado == 'rechazado'
                                ? null
                                : () async {
                                    await _cambiarEstado(
                                      context: context,
                                      empresaId: empresaId,
                                      solicitud: s,
                                      nuevoEstado: 'rechazado',
                                    );
                                  },
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: Color(0xFFDC2626)),
                            ),
                            child: const Text(
                              'Rechazar',
                              style: TextStyle(color: Color(0xFFDC2626)),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: s.estado == 'aceptado'
                                ? null
                                : () async {
                                    await _cambiarEstado(
                                      context: context,
                                      empresaId: empresaId,
                                      solicitud: s,
                                      nuevoEstado: 'aceptado',
                                    );
                                  },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF4F46E5),
                              padding:
                                  const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            child: const Text('Aceptar'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  Future<void> _cambiarEstado({
    required BuildContext context,
    required String empresaId,
    required DisponibilidadEvento solicitud,
    required String nuevoEstado,
  }) async {
    try {
      await FirestoreService.instance.actualizarEstadoDisponibilidad(
        empresaId: empresaId,
        eventoId: solicitud.eventoId,
        disponibilidadId: solicitud.id,
        nuevoEstado: nuevoEstado,
      );

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              nuevoEstado == 'aceptado'
                  ? 'Has aceptado la solicitud.'
                  : 'Has rechazado la solicitud.',
            ),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al actualizar: $e'),
          ),
        );
      }
    }
  }
}

/// Chip para mostrar el estado de la solicitud
class _EstadoChip extends StatelessWidget {
  final String estado;

  const _EstadoChip({required this.estado});

  @override
  Widget build(BuildContext context) {
    final e = estado.toLowerCase();
    Color bg;
    Color fg;
    String label;

    switch (e) {
      case 'aceptado':
        bg = const Color(0xFFDCFCE7);
        fg = const Color(0xFF166534);
        label = 'Aceptado';
        break;
      case 'rechazado':
        bg = const Color(0xFFFEF2F2);
        fg = const Color(0xFFB91C1C);
        label = 'Rechazado';
        break;
      default:
        bg = const Color(0xFFFEF3C7);
        fg = const Color(0xFF92400E);
        label = 'Pendiente';
        break;
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

String _pad2(int v) => v.toString().padLeft(2, '0');

String _formatFechaHora(DateTime dt) {
  return '${_pad2(dt.day)}/${_pad2(dt.month)}/${dt.year} · '
      '${_pad2(dt.hour)}:${_pad2(dt.minute)}';
}
