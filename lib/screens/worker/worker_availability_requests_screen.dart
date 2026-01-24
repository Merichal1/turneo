import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../config/app_config.dart';
import '../../core/services/firestore_service.dart';
import '../../models/evento.dart';
import '../../models/disponibilidad_evento.dart';

class WorkerAvailabilityRequestsScreen extends StatelessWidget {
  const WorkerAvailabilityRequestsScreen({super.key});

  // ====== Estilo (igual que admin / Turneo) ======
  static const Color _bg = Color(0xFFF6F8FC);
  static const Color _card = Colors.white;
  static const Color _border = Color(0xFFE5E7EB);
  static const Color _textDark = Color(0xFF111827);
  static const Color _textGrey = Color(0xFF6B7280);
  static const Color _blue = Color(0xFF2563EB);

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
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _bg,
        elevation: 0,
        title: const Text(
          'Solicitudes',
          style: TextStyle(
            color: _textDark,
            fontWeight: FontWeight.w900,
          ),
        ),
        centerTitle: false,
      ),
      body: StreamBuilder<List<Evento>>(
        stream: FirestoreService.instance.listenEventos(empresaId),
        builder: (context, eventosSnap) {
          if (eventosSnap.connectionState == ConnectionState.waiting &&
              !eventosSnap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final eventos = eventosSnap.data ?? [];
          final mapaEventos = {for (final e in eventos) e.id: e};

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
                return const _EmptyState();
              }

              // Ordenar: pendientes primero
              solicitudes.sort((a, b) {
                const orden = {'pendiente': 0, 'aceptado': 1, 'rechazado': 2};
                return (orden[a.estado] ?? 99).compareTo(orden[b.estado] ?? 99);
              });

              final pendientes = solicitudes.where((s) => s.estado == 'pendiente').length;

              return ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                children: [
                  // Header “bonito”
                  Container(
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
                    child: Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: const Color(0xFFEFF6FF),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: const Color(0xFFDBEAFE)),
                          ),
                          child: const Icon(Icons.event_available, color: _blue),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Tus solicitudes',
                                style: TextStyle(
                                  color: _textDark,
                                  fontWeight: FontWeight.w900,
                                  fontSize: 14,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                pendientes > 0
                                    ? 'Tienes $pendientes pendiente(s) de responder'
                                    : 'Todo al día ✅',
                                style: const TextStyle(
                                  color: _textGrey,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 12),

                  // Lista
                  ...solicitudes.map((d) {
                    final evento = mapaEventos[d.eventoId];
                    final tituloEvento = evento?.nombre ?? 'Evento desconocido';
                    final fecha = evento != null ? _formatFechaCorta(evento.fechaInicio) : '';

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _SolicitudModernCard(
                        empresaId: empresaId,
                        solicitud: d,
                        tituloEvento: tituloEvento,
                        fecha: fecha,
                      ),
                    );
                  }),
                ],
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

// ------------------
// Empty state bonito
// ------------------
class _EmptyState extends StatelessWidget {
  const _EmptyState();

  static const Color _bg = Color(0xFFF6F8FC);
  static const Color _textDark = Color(0xFF111827);
  static const Color _textGrey = Color(0xFF6B7280);
  static const Color _blue = Color(0xFF2563EB);

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: const Color(0xFFEFF6FF),
                borderRadius: BorderRadius.circular(18),
              ),
              child: const Icon(Icons.mark_email_read_outlined, color: _blue, size: 28),
            ),
            const SizedBox(height: 12),
            const Text(
              'No tienes solicitudes pendientes',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: _textDark,
                fontWeight: FontWeight.w900,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Cuando el admin te pida disponibilidad, te aparecerá aquí.',
              textAlign: TextAlign.center,
              style: TextStyle(color: _textGrey, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }
}

// ------------------
// Card moderno
// ------------------
class _SolicitudModernCard extends StatelessWidget {
  final DisponibilidadEvento solicitud;
  final String empresaId;
  final String tituloEvento;
  final String fecha;

  const _SolicitudModernCard({
    required this.solicitud,
    required this.empresaId,
    required this.tituloEvento,
    required this.fecha,
  });

  static const Color _card = Colors.white;
  static const Color _border = Color(0xFFE5E7EB);
  static const Color _textDark = Color(0xFF111827);
  static const Color _textGrey = Color(0xFF6B7280);
  static const Color _blue = Color(0xFF2563EB);

  @override
  Widget build(BuildContext context) {
    final d = solicitud;
    final bool esPendiente = d.estado == 'pendiente';

    return Container(
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
          // Top row
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(Icons.event_note, color: _blue, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      tituloEvento,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: _textDark,
                        fontWeight: FontWeight.w900,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(Icons.badge_outlined, size: 14, color: _textGrey),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            'Rol: ${d.trabajadorRol}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: _textGrey,
                              fontWeight: FontWeight.w600,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  if (fecha.isNotEmpty)
                    Text(
                      fecha,
                      style: const TextStyle(
                        fontSize: 11,
                        color: _textGrey,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  const SizedBox(height: 6),
                  _EstadoDisponibilidadChip(
                    estado: d.estado,
                    asignado: d.asignado,
                  ),
                ],
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Footer actions
          if (esPendiente) ...[
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
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
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFFB91C1C),
                      side: const BorderSide(color: _border),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: Text(
                      'Rechazar',
                      style: TextStyle(
                        color: d.asignado ? Colors.grey : const Color(0xFFB91C1C),
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2563EB),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    onPressed: () async {
                      await FirestoreService.instance.actualizarEstadoDisponibilidad(
                        empresaId: empresaId,
                        eventoId: d.eventoId,
                        disponibilidadId: d.id,
                        nuevoEstado: 'aceptado',
                      );
                    },
                    child: const Text(
                      'Aceptar',
                      style: TextStyle(fontWeight: FontWeight.w900),
                    ),
                  ),
                ),
              ],
            ),
            if (d.asignado) ...[
              const SizedBox(height: 10),
              const _AssignedBanner(),
            ],
          ] else ...[
            Text(
              d.asignado
                  ? 'Ya estás ASIGNADO a este evento.'
                  : (d.estado == 'aceptado'
                      ? 'Has marcado que estás disponible.'
                      : 'Has marcado que no estás disponible.'),
              style: TextStyle(
                fontStyle: FontStyle.italic,
                color: d.asignado
                    ? const Color(0xFF1D4ED8)
                    : (d.estado == 'aceptado' ? const Color(0xFF15803D) : const Color(0xFFB91C1C)),
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ],
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

class _AssignedBanner extends StatelessWidget {
  const _AssignedBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFDBEAFE),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFBFDBFE)),
      ),
      child: const Row(
        children: [
          Icon(Icons.verified, color: Color(0xFF1D4ED8), size: 18),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              'ASIGNADO: no podrás rechazar esta solicitud.',
              style: TextStyle(
                color: Color(0xFF1D4ED8),
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
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
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: fg),
      ),
    );
  }
}

String _formatFechaCorta(DateTime d) {
  return "${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}";
}