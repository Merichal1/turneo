import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../config/app_config.dart';
import '../../core/services/firestore_service.dart';
import '../../models/disponibilidad_evento.dart';

class WorkerNotificationsScreen extends StatelessWidget {
  const WorkerNotificationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    const empresaId = AppConfig.empresaId;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const Scaffold(
        body: Center(
          child: Text('Debes iniciar sesión para ver tus notificaciones.'),
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
            .listenSolicitudesDisponibilidadTrabajador(trabajadorId),
        builder: (context, dispoSnap) {
          if (dispoSnap.hasError) {
            return Center(
              child: Text(
                'Error al cargar solicitudes de disponibilidad:\n${dispoSnap.error}',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.red),
              ),
            );
          }

          // Segundo stream: notificaciones generales de la empresa
          return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: FirestoreService.instance
                .notificacionesRef(empresaId)
                .orderBy('creadoEn', descending: true)
                .snapshots(),
            builder: (context, notifSnap) {
              if ((dispoSnap.connectionState == ConnectionState.waiting &&
                      !dispoSnap.hasData) ||
                  (notifSnap.connectionState == ConnectionState.waiting &&
                      !notifSnap.hasData)) {
                return const Center(child: CircularProgressIndicator());
              }

              if (notifSnap.hasError) {
                return Center(
                  child: Text(
                    'Error al cargar notificaciones:\n${notifSnap.error}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.red),
                  ),
                );
              }

              final solicitudes = dispoSnap.data ?? [];
              final notifDocs = notifSnap.data?.docs ?? [];

              // Unificamos todo en una sola lista de items
              final items = <_WorkerNotifItem>[];

              // 1) Solicitudes de disponibilidad
              for (final s in solicitudes) {
                items.add(_WorkerNotifItem.fromSolicitud(s));
              }

              // 2) Notificaciones generales de la empresa
              for (final doc in notifDocs) {
                final data = doc.data();
                final ts = data['creadoEn'] as Timestamp?;
                final createdAt = ts?.toDate() ?? DateTime.now();
                final title = (data['titulo'] as String?) ?? 'Notificación';
                final body = (data['body'] as String?) ?? '';
                final tag = (data['tag'] as String?) ?? 'General';

                items.add(
                  _WorkerNotifItem.fromGeneral(
                    id: doc.id,
                    title: title,
                    body: body,
                    tag: tag,
                    createdAt: createdAt,
                  ),
                );
              }

              // Ordenamos por fecha descendente (lo más reciente arriba)
              items.sort(
                (a, b) => b.createdAt.compareTo(a.createdAt),
              );

              if (items.isEmpty) {
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
                itemCount: items.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  final item = items[index];

                  if (item.isSolicitud) {
                    final s = item.solicitud!;
                    final fechaTexto = _formatFechaHora(s.creadoEn);
                    return _SolicitudCard(
                      solicitud: s,
                      fechaTexto: fechaTexto,
                      empresaId: empresaId,
                    );
                  } else {
                    return _GeneralNotifCard(item: item);
                  }
                },
              );
            },
          );
        },
      ),
    );
  }
}

// =============== MODELO UNIFICADO PARA LA LISTA ===============

class _WorkerNotifItem {
  final String id;
  final DateTime createdAt;

  // Si es solicitud de disponibilidad
  final DisponibilidadEvento? solicitud;

  // Si es notificación general
  final String? titulo;
  final String? cuerpo;
  final String? tag;

  bool get isSolicitud => solicitud != null;

  _WorkerNotifItem._({
    required this.id,
    required this.createdAt,
    this.solicitud,
    this.titulo,
    this.cuerpo,
    this.tag,
  });

  factory _WorkerNotifItem.fromSolicitud(DisponibilidadEvento s) {
    return _WorkerNotifItem._(
      id: s.id,
      createdAt: s.creadoEn,
      solicitud: s,
    );
  }

  factory _WorkerNotifItem.fromGeneral({
    required String id,
    required String title,
    required String body,
    required String tag,
    required DateTime createdAt,
  }) {
    return _WorkerNotifItem._(
      id: id,
      createdAt: createdAt,
      solicitud: null,
      titulo: title,
      cuerpo: body,
      tag: tag,
    );
  }
}

// =============== CARD: SOLICITUD DE DISPONIBILIDAD ===============

class _SolicitudCard extends StatelessWidget {
  final DisponibilidadEvento solicitud;
  final String fechaTexto;
  final String empresaId;

  const _SolicitudCard({
    required this.solicitud,
    required this.fechaTexto,
    required this.empresaId,
  });

  @override
  Widget build(BuildContext context) {
    final s = solicitud;

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
          // Cabecera: icono + título + fecha + chip estado
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
                    padding: const EdgeInsets.symmetric(vertical: 12),
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
  }
}

// =============== CARD: NOTIFICACIÓN GENERAL DE LA EMPRESA ===============

class _GeneralNotifCard extends StatelessWidget {
  final _WorkerNotifItem item;

  const _GeneralNotifCard({required this.item});

  @override
  Widget build(BuildContext context) {
    final title = item.titulo ?? 'Notificación';
    final body = item.cuerpo ?? '';
    final tag = item.tag ?? 'General';

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
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.notifications,
            size: 20,
            color: Color(0xFF4F46E5),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF111827),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  body,
                  style: const TextStyle(
                    fontSize: 13,
                    color: Color(0xFF4B5563),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _formatFechaHora(item.createdAt),
                  style: const TextStyle(
                    fontSize: 11,
                    color: Color(0xFF9CA3AF),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: const Color(0xFFE5E7EB),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              tag,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: Color(0xFF4B5563),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// =============== LÓGICA CAMBIO ESTADO SOLICITUD ===============

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

// =============== ESTADO CHIP (SOLICITUD DISPONIBILIDAD) ===============

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

// =============== HELPERS FECHA/HORA ===============

String _pad2(int v) => v.toString().padLeft(2, '0');

String _formatFechaHora(DateTime dt) {
  return '${_pad2(dt.day)}/${_pad2(dt.month)}/${dt.year} · '
      '${_pad2(dt.hour)}:${_pad2(dt.minute)}';
}
