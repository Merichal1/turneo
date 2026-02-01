import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../routes/app_routes.dart';
import '../../config/app_config.dart';
import '../../core/services/firestore_service.dart';
import '../../models/evento.dart';
import '../../models/trabajador.dart';

class AdminHomeScreen extends StatelessWidget {
  const AdminHomeScreen({super.key});

  // 🎨 Turneo style (igual que login)
  static const Color _bg = Color(0xFFF6F8FC);
  static const Color _card = Colors.white;
  static const Color _textDark = Color(0xFF111827);
  static const Color _textGrey = Color(0xFF6B7280);
  static const Color _border = Color(0xFFE5E7EB);
  static const Color _blue = Color(0xFF2563EB);

  void _open(BuildContext context, String route) {
    Navigator.of(context).pushNamed(route);
  }

  DateTime _monthStart(DateTime now) => DateTime(now.year, now.month, 1);
  DateTime _monthEnd(DateTime now) => DateTime(now.year, now.month + 1, 1);

  // ==========================
  // PENDIENTES DE PAGO (GLOBAL + DETALLE POR EVENTO)
  // ==========================
  Stream<_PendingPaymentsSummary> _getPagosPendientesSummaryStream(String empresaId) {
    final db = FirebaseFirestore.instance;

    // Si quieres limitar el cálculo a eventos “recientes” para rendimiento:
    // final from = DateTime.now().subtract(const Duration(days: 365)); // 1 año
    // y filtras por fechaInicio >= from.
    return db
        .collection('empresas')
        .doc(empresaId)
        .collection('eventos')
        .snapshots()
        .asyncMap((eventosSnap) async {
      int totalPendientes = 0;
      final List<_EventPending> detalle = [];

      for (final evDoc in eventosSnap.docs) {
        final evData = evDoc.data();
        final estado = (evData['estado'] ?? '').toString().toLowerCase();
        if (estado == 'cancelado') continue; // ✅ no contamos cancelados

        final String nombre = (evData['nombre'] ?? 'Evento sin nombre').toString();

        // Fecha (para mostrar)
        DateTime? fechaInicio;
        final rawFecha = evData['fechaInicio'];
        if (rawFecha is Timestamp) fechaInicio = rawFecha.toDate();

        // Contamos pendientes en ESTE evento:
        // asistio==true && pagado==false
        final dispSnap = await evDoc.reference
            .collection('disponibilidad')
            .where('asistio', isEqualTo: true)
            .where('pagado', isEqualTo: false)
            .get();

        final count = dispSnap.docs.length;
        if (count > 0) {
          totalPendientes += count;
          detalle.add(_EventPending(
            eventoId: evDoc.id,
            nombre: nombre,
            fechaInicio: fechaInicio,
            pendientes: count,
          ));
        }
      }

      // Ordenamos por más pendientes, y si empata por fecha más reciente
      detalle.sort((a, b) {
        final c = b.pendientes.compareTo(a.pendientes);
        if (c != 0) return c;
        final da = a.fechaInicio ?? DateTime.fromMillisecondsSinceEpoch(0);
        final dbb = b.fechaInicio ?? DateTime.fromMillisecondsSinceEpoch(0);
        return dbb.compareTo(da);
      });

      return _PendingPaymentsSummary(
        total: totalPendientes,
        porEvento: detalle,
      );
    });
  }

  void _showPendientesDetalleModal(BuildContext context, _PendingPaymentsSummary summary) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (ctx) {
        final items = summary.porEvento;
        return Padding(
          padding: EdgeInsets.only(
            left: 18,
            right: 18,
            top: 18,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 18,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Row(
                children: [
                  const Icon(Icons.receipt_long_outlined, color: _blue),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Pendientes de pago (detalle)',
                      style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: _blue.withOpacity(0.10),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: _blue.withOpacity(0.2)),
                    ),
                    child: Text(
                      '${summary.total} total',
                      style: const TextStyle(fontWeight: FontWeight.w900, color: _blue),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              const Divider(height: 1),
              const SizedBox(height: 12),

              if (items.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 18),
                  child: Text(
                    'No hay pagos pendientes 🎉',
                    style: TextStyle(fontWeight: FontWeight.w800, color: _textGrey),
                  ),
                )
              else
                ConstrainedBox(
                  constraints: BoxConstraints(
                    maxHeight: MediaQuery.of(ctx).size.height * 0.65,
                  ),
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: items.length,
                    separatorBuilder: (_, __) => const Divider(height: 16),
                    itemBuilder: (_, i) {
                      final e = items[i];
                      final dateTxt = (e.fechaInicio == null)
                          ? '—'
                          : DateFormat('dd/MM/yyyy', 'es_ES').format(e.fechaInicio!);

                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: Container(
                          width: 42,
                          height: 42,
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFFBEB),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: const Color(0xFFFDE68A)),
                          ),
                          child: const Icon(Icons.warning_amber_rounded, color: Color(0xFFF59E0B)),
                        ),
                        title: Text(
                          e.nombre,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w900),
                        ),
                        subtitle: Text(
                          'Fecha: $dateTxt',
                          style: const TextStyle(color: _textGrey, fontWeight: FontWeight.w600),
                        ),
                        trailing: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFFBEB),
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(color: const Color(0xFFFDE68A)),
                          ),
                          child: Text(
                            '${e.pendientes} pendientes',
                            style: const TextStyle(
                              fontWeight: FontWeight.w900,
                              color: Color(0xFFF59E0B),
                              fontSize: 12,
                            ),
                          ),
                        ),
                        // Si quieres, aquí puedes navegar a tu pantalla de pagos (si tienes ruta).
                        // onTap: () => Navigator.pop(ctx),
                      );
                    },
                  ),
                ),

              const SizedBox(height: 14),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _blue,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    elevation: 0,
                  ),
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('CERRAR', style: TextStyle(fontWeight: FontWeight.w900)),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final String empresaId = AppConfig.empresaId;

    return SafeArea(
      child: Container(
        color: _bg,
        child: StreamBuilder<List<Evento>>(
          stream: FirestoreService.instance.listenEventos(empresaId),
          builder: (context, eventosSnap) {
            if (!eventosSnap.hasData) {
              return const Center(child: CircularProgressIndicator());
            }

            final eventos = eventosSnap.data!;
            final now = DateTime.now();
            final mStart = _monthStart(now);
            final mEnd = _monthEnd(now);

            final eventosEsteMes = eventos.where((e) {
              final d = e.fechaInicio;
              return d.isAfter(mStart.subtract(const Duration(milliseconds: 1))) &&
                  d.isBefore(mEnd) &&
                  e.estado.toLowerCase() != 'cancelado';
            }).length;

            return StreamBuilder<List<Trabajador>>(
              stream: FirestoreService.instance.listenTrabajadores(empresaId),
              builder: (context, trabajadoresSnap) {
                if (!trabajadoresSnap.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final trabajadoresActivos = trabajadoresSnap.data!.length;

                return StreamBuilder<_PendingPaymentsSummary>(
                  stream: _getPagosPendientesSummaryStream(empresaId),
                  builder: (context, pagosSnap) {
                    final summary = pagosSnap.data ?? const _PendingPaymentsSummary(total: 0, porEvento: []);

                    return LayoutBuilder(
                      builder: (context, constraints) {
                        final isCompact = constraints.maxWidth < 800;
                        final padding = EdgeInsets.all(isCompact ? 16.0 : 24.0);

                        if (isCompact) {
                          return SingleChildScrollView(
                            padding: padding,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const SizedBox(height: 4),
                                Text(
                                  'Panel Principal',
                                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                        fontWeight: FontWeight.w900,
                                        color: _textDark,
                                      ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  'Resumen de actividad y accesos rápidos',
                                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: _textGrey),
                                ),
                                const SizedBox(height: 18),

                                _SummaryCard(
                                  title: 'Eventos este mes',
                                  value: '$eventosEsteMes',
                                  icon: Icons.calendar_today_outlined,
                                  expand: false,
                                ),
                                const SizedBox(height: 12),
                                _SummaryCard(
                                  title: 'Trabajadores activos',
                                  value: '$trabajadoresActivos',
                                  icon: Icons.people_outline,
                                  expand: false,
                                ),
                                const SizedBox(height: 12),
                                _SummaryCard(
                                  title: 'Pendientes de pago',
                                  value: '${summary.total}',
                                  icon: Icons.payments_outlined,
                                  expand: false,
                                  infoTooltip: 'Pulsa para ver detalle por evento',
                                  onInfoTap: () => _showPendientesDetalleModal(context, summary),
                                  onTap: () => _showPendientesDetalleModal(context, summary),
                                ),

                                const SizedBox(height: 22),

                                Text(
                                  'Accesos Rápidos',
                                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                        fontWeight: FontWeight.w800,
                                        color: _textDark,
                                      ),
                                ),
                                const SizedBox(height: 12),
                                Wrap(
                                  spacing: 10,
                                  runSpacing: 10,
                                  children: [
                                    _QuickActionButton(
                                      label: 'Crear Evento',
                                      icon: Icons.add,
                                      isPrimary: true,
                                      onTap: () => _open(context, Routes.adminEvents),
                                    ),
                                    _QuickActionButton(
                                      label: 'Enviar Disponibilidad',
                                      icon: Icons.send_outlined,
                                      onTap: () => _open(context, Routes.adminNotifications),
                                    ),
                                    _QuickActionButton(
                                      label: 'Ver Calendario',
                                      icon: Icons.calendar_month_outlined,
                                      onTap: () => _open(context, Routes.adminEvents),
                                    ),
                                    _QuickActionButton(
                                      label: 'Gestionar Trabajadores',
                                      icon: Icons.people_alt_outlined,
                                      onTap: () => _open(context, Routes.adminWorkers),
                                    ),
                                  ],
                                ),

                                const SizedBox(height: 22),

                                _UpcomingEventsCard(
                                  empresaId: empresaId,
                                  expandChild: false,
                                  onOpenCalendar: () => _open(context, Routes.adminEvents),
                                ),
                                const SizedBox(height: 16),
                                _RecentNotificationsCard(
                                  empresaId: empresaId,
                                  expandChild: false,
                                  onOpenNotifications: () => _open(context, Routes.adminNotifications),
                                ),
                                const SizedBox(height: 8),
                              ],
                            ),
                          );
                        }

                        // WEB / DESKTOP
                        return Padding(
                          padding: padding,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Panel Principal',
                                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                      fontWeight: FontWeight.w900,
                                      color: _textDark,
                                    ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                'Resumen de actividad y accesos rápidos',
                                style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: _textGrey),
                              ),
                              const SizedBox(height: 20),

                              Row(
                                children: [
                                  _SummaryCard(
                                    title: 'Eventos este mes',
                                    value: '$eventosEsteMes',
                                    icon: Icons.calendar_today_outlined,
                                  ),
                                  const SizedBox(width: 16),
                                  _SummaryCard(
                                    title: 'Trabajadores activos',
                                    value: '$trabajadoresActivos',
                                    icon: Icons.people_outline,
                                  ),
                                  const SizedBox(width: 16),
                                  _SummaryCard(
                                    title: 'Pendientes de pago',
                                    value: '${summary.total}',
                                    icon: Icons.payments_outlined,
                                    infoTooltip: 'Pulsa para ver detalle por evento',
                                    onInfoTap: () => _showPendientesDetalleModal(context, summary),
                                    onTap: () => _showPendientesDetalleModal(context, summary),
                                  ),
                                ],
                              ),

                              const SizedBox(height: 22),

                              Text(
                                'Accesos Rápidos',
                                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                      fontWeight: FontWeight.w800,
                                      color: _textDark,
                                    ),
                              ),
                              const SizedBox(height: 12),
                              Wrap(
                                spacing: 10,
                                runSpacing: 10,
                                children: [
                                  _QuickActionButton(
                                    label: 'Crear Evento',
                                    icon: Icons.add,
                                    isPrimary: true,
                                    onTap: () => _open(context, Routes.adminEvents),
                                  ),
                                  _QuickActionButton(
                                    label: 'Enviar Disponibilidad',
                                    icon: Icons.send_outlined,
                                    onTap: () => _open(context, Routes.adminNotifications),
                                  ),
                                  _QuickActionButton(
                                    label: 'Ver Calendario',
                                    icon: Icons.calendar_month_outlined,
                                    onTap: () => _open(context, Routes.adminEvents),
                                  ),
                                  _QuickActionButton(
                                    label: 'Gestionar Trabajadores',
                                    icon: Icons.people_alt_outlined,
                                    onTap: () => _open(context, Routes.adminWorkers),
                                  ),
                                ],
                              ),

                              const SizedBox(height: 22),

                              Expanded(
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(
                                      flex: 2,
                                      child: _UpcomingEventsCard(
                                        empresaId: empresaId,
                                        expandChild: true,
                                        onOpenCalendar: () => _open(context, Routes.adminEvents),
                                      ),
                                    ),
                                    const SizedBox(width: 16),
                                    Expanded(
                                      flex: 2,
                                      child: _RecentNotificationsCard(
                                        empresaId: empresaId,
                                        expandChild: true,
                                        onOpenNotifications: () => _open(context, Routes.adminNotifications),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    );
                  },
                );
              },
            );
          },
        ),
      ),
    );
  }
}

// ===========================
// MODELOS INTERNOS
// ===========================
class _PendingPaymentsSummary {
  final int total;
  final List<_EventPending> porEvento;
  const _PendingPaymentsSummary({required this.total, required this.porEvento});
}

class _EventPending {
  final String eventoId;
  final String nombre;
  final DateTime? fechaInicio;
  final int pendientes;
  const _EventPending({
    required this.eventoId,
    required this.nombre,
    required this.fechaInicio,
    required this.pendientes,
  });
}

// ===========================
// WIDGETS (tus widgets + mini mejora para “info” y onTap)
// ===========================

class _SummaryCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final bool expand;

  // NUEVO:
  final VoidCallback? onTap;
  final VoidCallback? onInfoTap;
  final String? infoTooltip;

  const _SummaryCard({
    required this.title,
    required this.value,
    required this.icon,
    this.expand = true,
    this.onTap,
    this.onInfoTap,
    this.infoTooltip,
  });

  static const Color _card = Colors.white;
  static const Color _textDark = Color(0xFF111827);
  static const Color _textGrey = Color(0xFF6B7280);
  static const Color _border = Color(0xFFE5E7EB);
  static const Color _blue = Color(0xFF2563EB);

  @override
  Widget build(BuildContext context) {
    final content = Container(
      height: 96,
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _border),
        boxShadow: const [
          BoxShadow(
            color: Color(0x14000000),
            blurRadius: 24,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              color: const Color(0xFFEFF6FF),
              border: Border.all(color: const Color(0xFFD6E6FF)),
            ),
            child: Icon(icon, size: 22, color: _blue),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: _textGrey,
                              fontWeight: FontWeight.w600,
                            ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (onInfoTap != null)
                      Tooltip(
                        message: infoTooltip ?? 'Info',
                        child: InkWell(
                          onTap: onInfoTap,
                          borderRadius: BorderRadius.circular(999),
                          child: const Padding(
                            padding: EdgeInsets.all(6),
                            child: Icon(Icons.info_outline, size: 18, color: _textGrey),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w900,
                        color: _textDark,
                      ),
                ),
              ],
            ),
          ),
        ],
      ),
    );

    final wrapped = (onTap != null)
        ? InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: onTap,
            child: content,
          )
        : content;

    if (expand) return Expanded(child: wrapped);
    return wrapped;
  }
}

class _QuickActionButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool isPrimary;
  final VoidCallback onTap;

  const _QuickActionButton({
    required this.label,
    required this.icon,
    required this.onTap,
    this.isPrimary = false,
  });

  static const Color _blue = Color(0xFF2563EB);
  static const Color _textDark = Color(0xFF111827);
  static const Color _border = Color(0xFFE5E7EB);

  @override
  Widget build(BuildContext context) {
    final bg = isPrimary ? _blue : Colors.white;
    final fg = isPrimary ? Colors.white : _textDark;
    final border = isPrimary ? Colors.transparent : _border;

    return InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: border),
          boxShadow: isPrimary
              ? const [
                  BoxShadow(
                    color: Color(0x1A2563EB),
                    blurRadius: 16,
                    offset: Offset(0, 10),
                  )
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18, color: fg),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: fg,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ====== Esto ya lo tenías, lo dejo igual ======
class _UpcomingEventsCard extends StatelessWidget {
  const _UpcomingEventsCard({
    required this.empresaId,
    this.expandChild = true,
    this.onOpenCalendar,
  });

  final String empresaId;
  final bool expandChild;
  final VoidCallback? onOpenCalendar;

  static const Color _blue = Color(0xFF2563EB);

  String _statusLabel(String raw) {
    final s = raw.toLowerCase().trim();
    if (s == 'activo') return 'Confirmado';
    if (s == 'borrador') return 'Pendiente';
    if (s == 'finalizado') return 'Finalizado';
    if (s == 'cancelado') return 'Cancelado';
    return raw.toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    return _CardWrapper(
      title: 'Próximos Eventos',
      expandChild: expandChild,
      headerAction: onOpenCalendar == null
          ? null
          : TextButton(
              onPressed: onOpenCalendar,
              style: TextButton.styleFrom(foregroundColor: _blue),
              child: const Text("Ver calendario"),
            ),
      child: StreamBuilder<List<Evento>>(
        stream: FirestoreService.instance.listenEventos(empresaId),
        builder: (context, snap) {
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final now = DateTime.now();
          final items = snap.data!
              .where((e) =>
                  e.estado.toLowerCase() != 'cancelado' &&
                  e.fechaInicio.isAfter(now.subtract(const Duration(hours: 2))))
              .toList()
            ..sort((a, b) => a.fechaInicio.compareTo(b.fechaInicio));

          if (items.isEmpty) {
            return const Center(
              child: Text(
                "No hay eventos próximos",
                style: TextStyle(color: Color(0xFF6B7280)),
              ),
            );
          }

          final shown = expandChild ? items : items.take(4).toList();

          if (expandChild) {
            return ListView.separated(
              itemCount: shown.length,
              separatorBuilder: (_, __) => const Divider(height: 16),
              itemBuilder: (context, i) {
                final e = shown[i];
                final total = e.cantidadRequeridaTrabajadores;
                final fecha = DateFormat('dd MMM yyyy', 'es_ES').format(e.fechaInicio);
                return _EventRow(
                  title: e.nombre,
                  date: fecha,
                  workers: '$total trabajadores',
                  status: _statusLabel(e.estado),
                );
              },
            );
          }

          return Column(
            children: [
              for (final e in shown) ...[
                _EventRow(
                  title: e.nombre,
                  date: DateFormat('dd MMM yyyy', 'es_ES').format(e.fechaInicio),
                  workers: '${e.cantidadRequeridaTrabajadores} trabajadores',
                  status: _statusLabel(e.estado),
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _RecentNotificationsCard extends StatelessWidget {
  const _RecentNotificationsCard({
    required this.empresaId,
    this.expandChild = true,
    this.onOpenNotifications,
  });

  final String empresaId;
  final bool expandChild;
  final VoidCallback? onOpenNotifications;

  static const Color _blue = Color(0xFF2563EB);

  String _timeAgo(DateTime d) {
    final diff = DateTime.now().difference(d);
    if (diff.inSeconds < 30) return "Hace un momento";
    if (diff.inMinutes < 60) return "Hace ${diff.inMinutes} min";
    if (diff.inHours < 24) return "Hace ${diff.inHours} h";
    return "Hace ${diff.inDays} d";
  }

  Color _dotColor(Map<String, dynamic> n) {
    final leido = n['leido'] == true;
    final tag = (n['tag'] ?? '').toString().toLowerCase();
    if (!leido) {
      if (tag.contains('pago')) return Colors.orange;
      if (tag.contains('evento')) return const Color(0xFF6366F1);
      return Colors.redAccent;
    }
    return const Color(0xFF9CA3AF);
  }

  @override
  Widget build(BuildContext context) {
    return _CardWrapper(
      title: 'Notificaciones Recientes',
      expandChild: expandChild,
      headerAction: onOpenNotifications == null
          ? null
          : TextButton(
              onPressed: onOpenNotifications,
              style: TextButton.styleFrom(foregroundColor: _blue),
              child: const Text("Ver todas"),
            ),
      child: StreamBuilder<List<Map<String, dynamic>>>(
        stream: FirestoreService.instance.listenNotificacionesRecientes(empresaId),
        builder: (context, snap) {
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final items = snap.data!;
          if (items.isEmpty) {
            return const Center(
              child: Text(
                "Sin notificaciones",
                style: TextStyle(color: Color(0xFF6B7280)),
              ),
            );
          }

          final shown = expandChild ? items : items.take(4).toList();

          DateTime parseDate(Map<String, dynamic> n) {
            final raw = n['creadoEn'];
            if (raw is Timestamp) return raw.toDate();
            if (raw is DateTime) return raw;
            return DateTime.now();
          }

          if (expandChild) {
            return ListView.separated(
              itemCount: shown.length,
              separatorBuilder: (_, __) => const Divider(height: 16),
              itemBuilder: (context, i) {
                final n = shown[i];
                final titulo = (n['titulo'] ?? 'Notificación').toString();
                final dt = parseDate(n);
                return _NotificationRow(
                  title: titulo,
                  timeAgo: _timeAgo(dt),
                  dotColor: _dotColor(n),
                );
              },
            );
          }

          return Column(
            children: [
              for (final n in shown)
                _NotificationRow(
                  title: (n['titulo'] ?? 'Notificación').toString(),
                  timeAgo: _timeAgo(parseDate(n)),
                  dotColor: _dotColor(n),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _CardWrapper extends StatelessWidget {
  final String title;
  final Widget child;
  final bool expandChild;
  final Widget? headerAction;

  const _CardWrapper({
    required this.title,
    required this.child,
    this.expandChild = true,
    this.headerAction,
  });

  static const Color _card = Colors.white;
  static const Color _border = Color(0xFFE5E7EB);
  static const Color _textDark = Color(0xFF111827);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: _border),
        boxShadow: const [
          BoxShadow(
            color: Color(0x14000000),
            blurRadius: 24,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w900,
                        color: _textDark,
                      ),
                ),
              ),
              if (headerAction != null) headerAction!,
            ],
          ),
          const SizedBox(height: 12),
          if (expandChild) Expanded(child: child) else child,
        ],
      ),
    );
  }
}

class _EventRow extends StatelessWidget {
  final String title;
  final String date;
  final String workers;
  final String status;

  const _EventRow({
    required this.title,
    required this.date,
    required this.workers,
    required this.status,
  });

  static const Color _textGrey = Color(0xFF6B7280);
  static const Color _textDark = Color(0xFF111827);
  static const Color _border = Color(0xFFE5E7EB);

  Color _statusBg(String status) {
    final s = status.toLowerCase();
    if (s.contains('pend')) return const Color(0xFFEFF6FF);
    if (s.contains('final')) return const Color(0xFFECFDF5);
    if (s.contains('cancel')) return const Color(0xFFFEF2F2);
    return const Color(0xFFF3F4F6);
  }

  Color _statusFg(String status) {
    final s = status.toLowerCase();
    if (s.contains('pend')) return const Color(0xFF2563EB);
    if (s.contains('final')) return const Color(0xFF047857);
    if (s.contains('cancel')) return const Color(0xFFB91C1C);
    return const Color(0xFF374151);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: _border.withOpacity(0.7), width: 1),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    color: _textDark,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  '$date   •   $workers',
                  style: const TextStyle(
                    fontSize: 12,
                    color: _textGrey,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: _statusBg(status),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              status,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: _statusFg(status),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _NotificationRow extends StatelessWidget {
  final String title;
  final String timeAgo;
  final Color dotColor;

  const _NotificationRow({
    required this.title,
    required this.timeAgo,
    required this.dotColor,
  });

  static const Color _textGrey = Color(0xFF6B7280);
  static const Color _textDark = Color(0xFF111827);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            margin: const EdgeInsets.only(top: 6),
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: dotColor, shape: BoxShape.circle),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    color: _textDark,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  timeAgo,
                  style: const TextStyle(
                    fontSize: 12,
                    color: _textGrey,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
