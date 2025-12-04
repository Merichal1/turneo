import 'package:flutter/material.dart';

class AdminHomeScreen extends StatelessWidget {
  const AdminHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Panel Principal',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 4),
            Text(
              'Resumen de actividad y accesos rápidos',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: const Color(0xFF6B7280),
                  ),
            ),
            const SizedBox(height: 24),

            // Primera fila: tarjetas resumen
            Row(
              children: const [
                _SummaryCard(
                  title: 'Eventos este mes',
                  value: '24',
                  icon: Icons.calendar_today_outlined,
                ),
                SizedBox(width: 16),
                _SummaryCard(
                  title: 'Trabajadores activos',
                  value: '156',
                  icon: Icons.people_outline,
                ),
                SizedBox(width: 16),
                _SummaryCard(
                  title: 'Pendientes de pago',
                  value: '8',
                  icon: Icons.notifications_active_outlined,
                ),
              ],
            ),

            const SizedBox(height: 24),

            // Accesos rápidos
            Text(
              'Accesos Rápidos',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
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
                  onTap: () {},
                ),
                _QuickActionButton(
                  label: 'Enviar Disponibilidad',
                  icon: Icons.send_outlined,
                  onTap: () {},
                ),
                _QuickActionButton(
                  label: 'Ver Calendario',
                  icon: Icons.calendar_month_outlined,
                  onTap: () {},
                ),
                _QuickActionButton(
                  label: 'Gestionar Trabajadores',
                  icon: Icons.people_alt_outlined,
                  onTap: () {},
                ),
              ],
            ),

            const SizedBox(height: 24),

            // Parte inferior: Próximos eventos / Notificaciones recientes
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Expanded(
                    flex: 2,
                    child: _UpcomingEventsCard(),
                  ),
                  SizedBox(width: 16),
                  Expanded(
                    flex: 2,
                    child: _RecentNotificationsCard(),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;

  const _SummaryCard({
    required this.title,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        height: 90,
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
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: const Color(0xFF6B7280),
                        ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    value,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
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
              style: TextStyle(
                color: fg,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _UpcomingEventsCard extends StatelessWidget {
  const _UpcomingEventsCard();

  @override
  Widget build(BuildContext context) {
    return _CardWrapper(
      title: 'Próximos Eventos',
      child: Column(
        children: const [
          _EventRow(
            title: 'Boda Hotel Ritz',
            date: '15 Nov 2025',
            workers: '12 trabajadores',
            status: 'Confirmado',
          ),
          _EventRow(
            title: 'Cena Corporativa Tech Summit',
            date: '18 Nov 2025',
            workers: '8 trabajadores',
            status: 'Pendiente',
          ),
          _EventRow(
            title: 'Cóctel Inauguración',
            date: '20 Nov 2025',
            workers: '6 trabajadores',
            status: 'Confirmado',
          ),
          _EventRow(
            title: 'Banquete Navidad Empresa ABC',
            date: '22 Nov 2025',
            workers: '15 trabajadores',
            status: 'Confirmado',
          ),
        ],
      ),
    );
  }
}

class _RecentNotificationsCard extends StatelessWidget {
  const _RecentNotificationsCard();

  @override
  Widget build(BuildContext context) {
    return _CardWrapper(
      title: 'Notificaciones Recientes',
      child: Column(
        children: const [
          _NotificationRow(
            title: 'María García aceptó evento "Boda Hotel Ritz"',
            timeAgo: 'Hace 5 min',
            dotColor: Colors.green,
          ),
          _NotificationRow(
            title: 'Recordatorio: Evento mañana - 3 trabajadores sin confirmar',
            timeAgo: 'Hace 1 hora',
            dotColor: Colors.orange,
          ),
          _NotificationRow(
            title: 'Carlos Ruiz rechazó evento "Cena Corporativa"',
            timeAgo: 'Hace 2 horas',
            dotColor: Colors.red,
          ),
          _NotificationRow(
            title: 'Nuevo trabajador registrado: Ana Martínez',
            timeAgo: 'Hace 3 horas',
            dotColor: Colors.blue,
          ),
        ],
      ),
    );
  }
}

class _CardWrapper extends StatelessWidget {
  final String title;
  final Widget child;

  const _CardWrapper({
    required this.title,
    required this.child,
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
          Text(
            title,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
          ),
          const SizedBox(height: 12),
          Expanded(child: child),
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
                Text(title,
                    style: const TextStyle(fontWeight: FontWeight.w500)),
                const SizedBox(height: 2),
                Text(
                  '$date   •   $workers',
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF6B7280),
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFFE5E7EB),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              status,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w500,
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
            decoration: BoxDecoration(
              color: dotColor,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(fontWeight: FontWeight.w500)),
                const SizedBox(height: 2),
                Text(
                  timeAgo,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF6B7280),
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
