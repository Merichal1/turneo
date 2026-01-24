import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../config/app_config.dart';
import '../../core/services/firestore_service.dart';
import '../../models/disponibilidad_evento.dart';

class WorkerNotificationsScreen extends StatelessWidget {
  const WorkerNotificationsScreen({super.key});

  // ====== THEME (Turneo / Admin-like) ======
  static const Color _bg = Color(0xFFF6F8FC);
  static const Color _card = Colors.white;
  static const Color _border = Color(0xFFE5E7EB);
  static const Color _textDark = Color(0xFF111827);
  static const Color _textGrey = Color(0xFF6B7280);
  static const Color _blue = Color(0xFF2563EB);
  static const Color _soft = Color(0xFFF9FAFB);

  @override
  Widget build(BuildContext context) {
    const empresaId = AppConfig.empresaId;
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return const Scaffold(
        body: Center(child: Text('Inicia sesión para ver tus avisos.')),
      );
    }

    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _bg,
        elevation: 0,
        centerTitle: false,
        title: const Text(
          'Avisos',
          style: TextStyle(
            color: _textDark,
            fontWeight: FontWeight.w900,
          ),
        ),
        iconTheme: const IconThemeData(color: _textDark),
      ),
      body: StreamBuilder<List<DisponibilidadEvento>>(
        // Stream 1: Solicitudes técnicas de eventos
        stream: FirestoreService.instance
            .listenSolicitudesDisponibilidadTrabajador(user.uid),
        builder: (context, dispoSnap) {
          // Stream 2: Notificaciones generales enviadas por el Admin
          return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: FirebaseFirestore.instance
                .collection('empresas')
                .doc(empresaId)
                .collection('notificaciones')
                .where('dirigidoA', whereIn: ['todos', user.uid]) // ✅ igual
                .orderBy('creadoEn', descending: true)
                .snapshots(),
            builder: (context, notifSnap) {
              if (dispoSnap.connectionState == ConnectionState.waiting ||
                  notifSnap.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              if (dispoSnap.hasError) {
                return _CenteredError(
                  text: 'Error cargando solicitudes:\n${dispoSnap.error}',
                );
              }
              if (notifSnap.hasError) {
                return _CenteredError(
                  text: 'Error cargando notificaciones:\n${notifSnap.error}',
                );
              }

              final solicitudes = dispoSnap.data ?? [];
              final notifDocs = notifSnap.data?.docs ?? [];

              if (solicitudes.isEmpty && notifDocs.isEmpty) {
                return const _EmptyState();
              }

              return ListView(
                padding: const EdgeInsets.fromLTRB(14, 6, 14, 14),
                children: [
                  // ===== Resumen arriba (muy pro) =====
                  _SummaryBar(
                    pendientes: solicitudes
                        .where((s) => (s.estado).toLowerCase() == 'pendiente')
                        .length,
                    comunicados: notifDocs.length,
                  ),
                  const SizedBox(height: 12),

                  // --- SECCIÓN 1: SOLICITUDES (prioridad) ---
                  if (solicitudes.isNotEmpty) ...[
                    const _SectionHeader(
                      title: 'Solicitudes de eventos',
                      subtitle: 'Responde para indicar disponibilidad',
                      icon: Icons.event_note,
                    ),
                    const SizedBox(height: 10),
                    ...solicitudes.map(
                      (s) => _SolicitudCard(
                        solicitud: s,
                        empresaId: empresaId,
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // --- SECCIÓN 2: COMUNICADOS ---
                  if (notifDocs.isNotEmpty) ...[
                    const _SectionHeader(
                      title: 'Comunicados',
                      subtitle: 'Mensajes generales del administrador',
                      icon: Icons.notifications_outlined,
                    ),
                    const SizedBox(height: 10),
                    ...notifDocs.map((doc) => _GeneralNotifCard(doc: doc)),
                  ],

                  const SizedBox(height: 90), // espacio menú inferior
                ],
              );
            },
          );
        },
      ),
    );
  }
}

// ============================
// UI: Summary bar (header)
// ============================
class _SummaryBar extends StatelessWidget {
  static const Color _card = Colors.white;
  static const Color _border = Color(0xFFE5E7EB);
  static const Color _textDark = Color(0xFF111827);
  static const Color _textGrey = Color(0xFF6B7280);
  static const Color _blue = Color(0xFF2563EB);

  final int pendientes;
  final int comunicados;

  const _SummaryBar({
    required this.pendientes,
    required this.comunicados,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _border),
        boxShadow: const [
          BoxShadow(
            color: Color(0x12000000),
            blurRadius: 18,
            offset: Offset(0, 8),
          )
        ],
      ),
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          const CircleAvatar(
            radius: 18,
            backgroundColor: Color(0xFFEFF6FF),
            child: Icon(Icons.inbox_outlined, color: _blue, size: 18),
          ),
          const SizedBox(width: 10),
          const Expanded(
            child: Text(
              'Centro de avisos',
              style: TextStyle(
                color: _textDark,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          _MiniPill(
            label: 'Pendientes',
            value: pendientes,
            fg: pendientes > 0 ? const Color(0xFFB45309) : _textGrey,
            bg: pendientes > 0 ? const Color(0xFFFFEDD5) : const Color(0xFFF3F4F6),
          ),
          const SizedBox(width: 8),
          _MiniPill(
            label: 'Comunicados',
            value: comunicados,
            fg: const Color(0xFF1D4ED8),
            bg: const Color(0xFFEFF6FF),
          ),
        ],
      ),
    );
  }
}

class _MiniPill extends StatelessWidget {
  final String label;
  final int value;
  final Color fg;
  final Color bg;

  const _MiniPill({
    required this.label,
    required this.value,
    required this.fg,
    required this.bg,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$value',
            style: TextStyle(fontWeight: FontWeight.w900, color: fg),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: fg),
          ),
        ],
      ),
    );
  }
}

// ============================
// UI: Empty / Error
// ============================
class _EmptyState extends StatelessWidget {
  static const Color _textGrey = Color(0xFF6B7280);
  static const Color _textDark = Color(0xFF111827);

  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.notifications_none, size: 34, color: _textGrey),
            SizedBox(height: 10),
            Text(
              'No tienes notificaciones por ahora.',
              style: TextStyle(
                color: _textDark,
                fontWeight: FontWeight.w800,
              ),
            ),
            SizedBox(height: 6),
            Text(
              'Cuando el administrador te envíe avisos o solicitudes,\naparecerán aquí.',
              textAlign: TextAlign.center,
              style: TextStyle(color: _textGrey, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }
}

class _CenteredError extends StatelessWidget {
  final String text;
  const _CenteredError({required this.text});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.red, fontWeight: FontWeight.w700),
        ),
      ),
    );
  }
}

// ============================
// UI: Section header
// ============================
class _SectionHeader extends StatelessWidget {
  static const Color _textDark = Color(0xFF111827);
  static const Color _textGrey = Color(0xFF6B7280);

  final String title;
  final String subtitle;
  final IconData icon;

  const _SectionHeader({
    required this.title,
    required this.subtitle,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        CircleAvatar(
          radius: 16,
          backgroundColor: const Color(0xFFEFF6FF),
          child: Icon(icon, size: 16, color: const Color(0xFF2563EB)),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: _textDark,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
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
    );
  }
}

// ============================
// Card: Solicitud
// ============================
class _SolicitudCard extends StatelessWidget {
  static const Color _card = Colors.white;
  static const Color _border = Color(0xFFE5E7EB);
  static const Color _textDark = Color(0xFF111827);
  static const Color _textGrey = Color(0xFF6B7280);
  static const Color _soft = Color(0xFFF9FAFB);

  final DisponibilidadEvento solicitud;
  final String empresaId;

  const _SolicitudCard({required this.solicitud, required this.empresaId});

  @override
  Widget build(BuildContext context) {
    final s = solicitud;
    final bool esPendiente = s.estado == 'pendiente';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
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
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const CircleAvatar(
                radius: 16,
                backgroundColor: Color(0xFFEFF6FF),
                child: Icon(Icons.event_note, color: Color(0xFF2563EB), size: 16),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'Solicitud de evento',
                  style: TextStyle(
                    color: _textDark,
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                  ),
                ),
              ),
              _EstadoBadge(estado: s.estado),
            ],
          ),
          const SizedBox(height: 10),

          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: _soft,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: _border),
            ),
            child: Text(
              'Se requiere tu disponibilidad como: ${s.trabajadorRol}',
              style: const TextStyle(
                color: _textGrey,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),

          const SizedBox(height: 12),

          if (esPendiente)
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _responder(context, 'rechazado'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFFB91C1C),
                      side: const BorderSide(color: _border),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: const Text(
                      'Rechazar',
                      style: TextStyle(fontWeight: FontWeight.w900),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => _responder(context, 'aceptado'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2563EB),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      elevation: 0,
                    ),
                    child: const Text(
                      'Aceptar',
                      style: TextStyle(fontWeight: FontWeight.w900),
                    ),
                  ),
                ),
              ],
            )
          else
            Text(
              s.estado == 'aceptado'
                  ? 'Has marcado que estás disponible.'
                  : 'Has marcado que no estás disponible.',
              style: TextStyle(
                fontStyle: FontStyle.italic,
                fontWeight: FontWeight.w700,
                color: s.estado == 'aceptado'
                    ? const Color(0xFF15803D)
                    : const Color(0xFFB91C1C),
              ),
            ),
        ],
      ),
    );
  }

  void _responder(BuildContext context, String nuevoEstado) async {
    try {
      await FirestoreService.instance.actualizarEstadoDisponibilidad(
        empresaId: empresaId,
        eventoId: solicitud.eventoId,
        disponibilidadId: solicitud.id,
        nuevoEstado: nuevoEstado,
      );

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            nuevoEstado == 'aceptado'
                ? 'Perfecto, has aceptado la solicitud.'
                : 'Has rechazado la solicitud.',
          ),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }
}

// ============================
// Card: Notificación general
// ============================
class _GeneralNotifCard extends StatelessWidget {
  static const Color _card = Colors.white;
  static const Color _border = Color(0xFFE5E7EB);
  static const Color _textDark = Color(0xFF111827);
  static const Color _textGrey = Color(0xFF6B7280);

  final QueryDocumentSnapshot<Map<String, dynamic>> doc;
  const _GeneralNotifCard({required this.doc});

  @override
  Widget build(BuildContext context) {
    final data = doc.data();
    final titulo = (data['titulo'] ?? 'Aviso').toString();
    final body = (data['body'] ?? '').toString();
    final tag = (data['tag'] ?? '').toString();

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
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
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        leading: const CircleAvatar(
          backgroundColor: Color(0xFFEFF6FF),
          child: Icon(Icons.notifications, color: Color(0xFF2563EB), size: 18),
        ),
        title: Text(
          titulo,
          style: const TextStyle(
            color: _textDark,
            fontWeight: FontWeight.w900,
          ),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(
            body,
            style: const TextStyle(
              color: _textGrey,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        trailing: tag.isEmpty
            ? null
            : Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFFF3F4F6),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: _border),
                ),
                child: Text(
                  tag,
                  style: const TextStyle(
                    fontSize: 10,
                    color: _textGrey,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
      ),
    );
  }
}

// ============================
// Badge: Estado
// ============================
class _EstadoBadge extends StatelessWidget {
  final String estado;
  const _EstadoBadge({required this.estado});

  @override
  Widget build(BuildContext context) {
    Color color = const Color(0xFFB45309);
    String texto = 'Pendiente';

    if (estado == 'aceptado') {
      color = const Color(0xFF15803D);
      texto = 'Disponible';
    }
    if (estado == 'rechazado') {
      color = const Color(0xFFB91C1C);
      texto = 'No disponible';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.10),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withOpacity(0.22)),
      ),
      child: Text(
        texto,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}