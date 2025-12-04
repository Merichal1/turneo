// TODO Implement this library.
import 'package:flutter/material.dart';

class WorkerNotificationsScreen extends StatefulWidget {
  const WorkerNotificationsScreen({super.key});

  @override
  State<WorkerNotificationsScreen> createState() =>
      _WorkerNotificationsScreenState();
}

class _WorkerNotificationsScreenState
    extends State<WorkerNotificationsScreen> {
  String _selectedFilter = 'Todas';

  final List<NotificationItem> _notifications = [
    NotificationItem(
      id: '1',
      title: 'Nueva solicitud de evento',
      body: 'La empresa Eventos Premium te ha enviado una solicitud para '
          'la Boda García-Martínez el 16 noviembre.',
      timeLabel: 'Hace 2 h',
      type: NotificationType.request,
      unread: true,
    ),
    NotificationItem(
      id: '2',
      title: 'Recordatorio de evento',
      body: 'Recuerda que mañana tienes la Cena corporativa Tech Summit '
          'a las 20:00.',
      timeLabel: 'Hace 6 h',
      type: NotificationType.reminder,
      unread: true,
    ),
    NotificationItem(
      id: '3',
      title: 'Mensaje nuevo del coordinador',
      body: 'Carlos (coordinador) ha escrito en el chat del evento '
          '“Boda García-Martínez”.',
      timeLabel: 'Ayer',
      type: NotificationType.chat,
      unread: false,
    ),
    NotificationItem(
      id: '4',
      title: 'Actualización de estado de pago',
      body: 'Se ha actualizado el estado de pago de tu evento '
          '“Cóctel inauguración Galería Arte”: Pagado.',
      timeLabel: 'Ayer',
      type: NotificationType.system,
      unread: false,
    ),
    NotificationItem(
      id: '5',
      title: 'Turno añadido a tu calendario',
      body: 'Se ha añadido el evento “Conferencia Tech” el 25 noviembre '
          'a tu calendario.',
      timeLabel: 'Hace 3 días',
      type: NotificationType.system,
      unread: false,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final filtered = _notifications.where((n) {
      if (_selectedFilter == 'Todas') return true;
      if (_selectedFilter == 'Solicitudes' &&
          n.type == NotificationType.request) return true;
      if (_selectedFilter == 'Recordatorios' &&
          n.type == NotificationType.reminder) return true;
      if (_selectedFilter == 'Sistema' &&
          n.type == NotificationType.system) return true;
      if (_selectedFilter == 'Chat' &&
          n.type == NotificationType.chat) return true;
      return false;
    }).toList();

    final int unreadCount = _notifications.where((n) => n.unread).length;

    return SafeArea(
      child: Scaffold(
        backgroundColor: const Color(0xFFF3F4F6),
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // AppBar “manual”
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Row(
                children: [
                  const Icon(Icons.notifications_none, size: 24),
                  const SizedBox(width: 8),
                  const Text(
                    'Notificaciones',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Spacer(),
                  if (unreadCount > 0)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFF111827),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        '$unreadCount nuevas',
                        style: const TextStyle(
                          fontSize: 11,
                          color: Colors.white,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                ],
              ),
            ),

            // Filtros
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _FilterChip(
                      label: 'Todas',
                      selected: _selectedFilter == 'Todas',
                      onTap: () => _setFilter('Todas'),
                    ),
                    const SizedBox(width: 8),
                    _FilterChip(
                      label: 'Solicitudes',
                      selected: _selectedFilter == 'Solicitudes',
                      onTap: () => _setFilter('Solicitudes'),
                    ),
                    const SizedBox(width: 8),
                    _FilterChip(
                      label: 'Recordatorios',
                      selected: _selectedFilter == 'Recordatorios',
                      onTap: () => _setFilter('Recordatorios'),
                    ),
                    const SizedBox(width: 8),
                    _FilterChip(
                      label: 'Sistema',
                      selected: _selectedFilter == 'Sistema',
                      onTap: () => _setFilter('Sistema'),
                    ),
                    const SizedBox(width: 8),
                    _FilterChip(
                      label: 'Chat',
                      selected: _selectedFilter == 'Chat',
                      onTap: () => _setFilter('Chat'),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 12),

            // Lista de notificaciones
            Expanded(
              child: Container(
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius:
                      BorderRadius.vertical(top: Radius.circular(24)),
                ),
                child: ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                  itemCount: filtered.length,
                  separatorBuilder: (_, __) => const Divider(
                    height: 16,
                    thickness: 0.6,
                    indent: 48, // para que no corte el icono
                  ),
                  itemBuilder: (context, index) {
                    final n = filtered[index];
                    return _NotificationTile(
                      item: n,
                      onTap: () => _markAsRead(n),
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _setFilter(String v) {
    setState(() {
      _selectedFilter = v;
    });
  }

  void _markAsRead(NotificationItem n) {
    if (!n.unread) return;
    setState(() {
      final idx = _notifications.indexWhere((x) => x.id == n.id);
      if (idx != -1) {
        _notifications[idx] =
            _notifications[idx].copyWith(unread: false);
      }
    });
  }
}

// ──────────────────────────────── MODELO ────────────────────────────────

enum NotificationType {
  request,
  reminder,
  system,
  chat,
}

class NotificationItem {
  final String id;
  final String title;
  final String body;
  final String timeLabel;
  final NotificationType type;
  final bool unread;

  NotificationItem({
    required this.id,
    required this.title,
    required this.body,
    required this.timeLabel,
    required this.type,
    required this.unread,
  });

  NotificationItem copyWith({bool? unread}) {
    return NotificationItem(
      id: id,
      title: title,
      body: body,
      timeLabel: timeLabel,
      type: type,
      unread: unread ?? this.unread,
    );
  }
}

// ──────────────────────────────── WIDGETS UI ───────────────────────────────

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final bg = selected ? const Color(0xFF111827) : Colors.white;
    final fg = selected ? Colors.white : const Color(0xFF111827);
    final border =
        selected ? Colors.transparent : const Color(0xFFE5E7EB);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: border),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: fg,
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }
}

class _NotificationTile extends StatelessWidget {
  final NotificationItem item;
  final VoidCallback onTap;

  const _NotificationTile({
    required this.item,
    required this.onTap,
  });

  IconData _iconForType(NotificationType t) {
    switch (t) {
      case NotificationType.request:
        return Icons.assignment_turned_in_outlined;
      case NotificationType.reminder:
        return Icons.schedule_outlined;
      case NotificationType.system:
        return Icons.info_outline;
      case NotificationType.chat:
        return Icons.chat_bubble_outline;
    }
  }

  Color _iconColor(NotificationType t) {
    switch (t) {
      case NotificationType.request:
        return const Color(0xFF2563EB);
      case NotificationType.reminder:
        return const Color(0xFFF97316);
      case NotificationType.system:
        return const Color(0xFF10B981);
      case NotificationType.chat:
        return const Color(0xFF7C3AED);
    }
  }

  @override
  Widget build(BuildContext context) {
    final icon = _iconForType(item.type);
    final iconColor = _iconColor(item.type);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Icono
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: iconColor.withOpacity(0.08),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              icon,
              size: 22,
              color: iconColor,
            ),
          ),
          const SizedBox(width: 12),

          // Texto
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        item.title,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: item.unread
                              ? FontWeight.w600
                              : FontWeight.w500,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      item.timeLabel,
                      style: const TextStyle(
                        fontSize: 11,
                        color: Color(0xFF9CA3AF),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  item.body,
                  style: const TextStyle(
                    fontSize: 13,
                    color: Color(0xFF6B7280),
                  ),
                ),
                if (item.unread) ...[
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          color: Color(0xFF111827),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      const Text(
                        'Nuevo',
                        style: TextStyle(
                          fontSize: 11,
                          color: Color(0xFF111827),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

