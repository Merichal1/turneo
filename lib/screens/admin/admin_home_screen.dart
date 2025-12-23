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

  void _open(BuildContext context, String route) {
    Navigator.of(context).pushNamed(route);
  }

  DateTime _monthStart(DateTime now) => DateTime(now.year, now.month, 1);
  DateTime _monthEnd(DateTime now) => DateTime(now.year, now.month + 1, 1);

  @override
  Widget build(BuildContext context) {
    final String empresaId = AppConfig.empresaId;

    return SafeArea(
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

              final trabajadores = trabajadoresSnap.data!;
              final trabajadoresActivos = trabajadores.length;

              // "Pendientes de pago" -> usamos notificaciones no leídas (leido == false)
              final unreadStream = FirebaseFirestore.instance
                  .collection('empresas')
                  .doc(empresaId)
                  .collection('notificaciones')
                  .where('leido', isEqualTo: false)
                  .snapshots();

              return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: unreadStream,
                builder: (context, unreadSnap) {
                  final pendientes = unreadSnap.data?.docs.length ?? 0;

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
                              Text(
                                'Panel Principal',
                                style: Theme.of(context)
                                    .textTheme
                                    .headlineSmall
                                    ?.copyWith(fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Resumen de actividad y accesos rápidos',
                                style: Theme.of(context)
                                    .textTheme
                                    .bodyMedium
                                    ?.copyWith(color: const Color(0xFF6B7280)),
                              ),
                              const SizedBox(height: 24),

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
                                value: '$pendientes',
                                icon: Icons.notifications_active_outlined,
                                expand: false,
                              ),

                              const SizedBox(height: 24),

                              Text(
                                'Accesos Rápidos',
                                style: Theme.of(context)
                                    .textTheme
                                    .titleMedium
                                    ?.copyWith(fontWeight: FontWeight.w600),
                              ),
                              const SizedBox(height: 12),
                              Wrap(
                                spacing: 12,
                                runSpacing: 12,
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

                              const SizedBox(height: 24),

                              _UpcomingEventsCard(
                                empresaId: empresaId,
                                expandChild: false,
                                onOpenCalendar: () => _open(context, Routes.adminEvents),
                              ),
                              const SizedBox(height: 16),
                              _RecentNotificationsCard(
                                empresaId: empresaId,
                                expandChild: false,
                                onOpenNotifications: () =>
                                    _open(context, Routes.adminNotifications),
                              ),
                            ],
                          ),
                        );
                      }

                      // Web / escritorio
                      return Padding(
                        padding: padding,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Panel Principal',
                              style: Theme.of(context)
                                  .textTheme
                                  .headlineSmall
                                  ?.copyWith(fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Resumen de actividad y accesos rápidos',
                              style: Theme.of(context)
                                  .textTheme
                                  .bodyMedium
                                  ?.copyWith(color: const Color(0xFF6B7280)),
                            ),
                            const SizedBox(height: 24),

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
                                  value: '$pendientes',
                                  icon: Icons.notifications_active_outlined,
                                ),
                              ],
                            ),

                            const SizedBox(height: 24),

                            Text(
                              'Accesos Rápidos',
                              style: Theme.of(context)
                                  .textTheme
                                  .titleMedium
                                  ?.copyWith(fontWeight: FontWeight.w600),
                            ),
                            const SizedBox(height: 12),
                            Wrap(
                              spacing: 12,
                              runSpacing: 12,
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

                            const SizedBox(height: 24),

                            Expanded(
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    flex: 2,
                                    child: _UpcomingEventsCard(
                                      empresaId: empresaId,
                                      expandChild: true,
                                      onOpenCalendar: () =>
                                          _open(context, Routes.adminEvents),
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    flex: 2,
                                    child: _RecentNotificationsCard(
                                      empresaId: empresaId,
                                      expandChild: true,
                                      onOpenNotifications: () =>
                                          _open(context, Routes.adminNotifications),
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
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final bool expand;

  const _SummaryCard({
    required this.title,
    required this.value,
    required this.icon,
    this.expand = true,
  });

  @override
  Widget build(BuildContext context) {
    final card = Container(
      height: 90,
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            blurRadius: 18,
            offset: const Offset(0, 8),
            color: Colors.black.withOpacity(0.04),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              color: const Color(0xFFE5E7EB),
            ),
            child: Icon(icon, size: 22),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  title,
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: const Color(0xFF6B7280)),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: Theme.of(context)
                      .textTheme
                      .titleLarge
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
        ],
      ),
    );

    if (expand) return Expanded(child: card);
    return card;
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

  @override
  Widget build(BuildContext context) {
    final bg = isPrimary ? const Color(0xFF111827) : Colors.white;
    final fg = isPrimary ? Colors.white : const Color(0xFF111827);
    final border = isPrimary ? Colors.transparent : const Color(0xFFE5E7EB);

    return InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18, color: fg),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(color: fg, fontWeight: FontWeight.w500),
            ),
          ],
        ),
      ),
    );
  }
}

class _UpcomingEventsCard extends StatelessWidget {
  const _UpcomingEventsCard({
    required this.empresaId,
    this.expandChild = true,
    this.onOpenCalendar,
  });

  final String empresaId;
  final bool expandChild;
  final VoidCallback? onOpenCalendar;

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
              separatorBuilder: (_, __) => const Divider(height: 14),
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
              separatorBuilder: (_, __) => const Divider(height: 14),
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

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            blurRadius: 18,
            offset: const Offset(0, 8),
            color: Colors.black.withOpacity(0.04),
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
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.w600),
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

  Color _statusBg(String status) {
    final s = status.toLowerCase();
    if (s.contains('pend')) return const Color(0xFFFFF7ED);
    if (s.contains('final')) return const Color(0xFFECFDF5);
    if (s.contains('cancel')) return const Color(0xFFFEF2F2);
    return const Color(0xFFE5E7EB);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.w500)),
                const SizedBox(height: 2),
                Text(
                  '$date   •   $workers',
                  style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: _statusBg(status),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              status,
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500),
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

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            margin: const EdgeInsets.only(top: 4),
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: dotColor, shape: BoxShape.circle),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.w500)),
                const SizedBox(height: 2),
                Text(
                  timeAgo,
                  style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
