import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class WorkerMainMenuScreen extends StatelessWidget {
  final void Function(int) onNavigateToTab;

  const WorkerMainMenuScreen({
    super.key,
    required this.onNavigateToTab,
  });

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final email = user?.email ?? '';
    final displayName = user?.displayName ?? '';

    final String saludoNombre =
        displayName.isNotEmpty ? displayName : (email.split('@').first);

    return Scaffold(
      backgroundColor: const Color(0xFFF3F4F6),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // CABECERA
              Text(
                'Hola, $saludoNombre 👋',
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF111827),
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Este es tu panel principal. Desde aquí puedes ir a tus eventos, disponibilidad y más.',
                style: TextStyle(
                  fontSize: 13,
                  color: Color(0xFF6B7280),
                ),
              ),
              const SizedBox(height: 20),

              // BOTONES GRANDES
              GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  _MenuCard(
                    icon: Icons.event_note,
                    title: 'Mis eventos',
                    subtitle: 'Turnos y detalles',
                    color: const Color(0xFF3B82F6),
                    onTap: () => onNavigateToTab(1), // pestaña Eventos
                  ),
                  _MenuCard(
                    icon: Icons.event_available,
                    title: 'Disponibilidad',
                    subtitle: 'Marca cuándo puedes trabajar',
                    color: const Color(0xFF10B981),
                    onTap: () => onNavigateToTab(2), // pestaña Disponibilidad
                  ),
                  _MenuCard(
                    icon: Icons.notifications,
                    title: 'Notificaciones',
                    subtitle: 'Solicitudes del administrador',
                    color: const Color(0xFFF97316),
                    onTap: () => onNavigateToTab(3), // pestaña Notificaciones
                  ),
                  _MenuCard(
                    icon: Icons.chat_bubble,
                    title: 'Mensajes',
                    subtitle: 'Admin y compañeros',
                    color: const Color(0xFF6366F1),
                    onTap: () => onNavigateToTab(5), // pestaña Chat
                  ),
                ],
              ),

              const SizedBox(height: 24),

              // SECCIÓN PERFIL / HISTORIAL
              const Text(
                'Tu cuenta',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF111827),
                ),
              ),
              const SizedBox(height: 8),
              _ListTileCard(
                icon: Icons.history,
                title: 'Historial de eventos',
                subtitle: 'Eventos anteriores y estados',
                onTap: () => onNavigateToTab(4), // pestaña Historial
              ),
              const SizedBox(height: 8),
              _ListTileCard(
                icon: Icons.person,
                title: 'Mi perfil',
                subtitle: 'Datos personales y contacto',
                onTap: () => onNavigateToTab(6), // pestaña Perfil
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MenuCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  const _MenuCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: color.withOpacity(0.12),
              child: Icon(
                icon,
                color: color,
                size: 20,
              ),
            ),
            const Spacer(),
            Text(
              title,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Color(0xFF111827),
              ),
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 11,
                color: Color(0xFF6B7280),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ListTileCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _ListTileCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      borderRadius: BorderRadius.circular(14),
      color: Colors.white,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              CircleAvatar(
                radius: 16,
                backgroundColor: const Color(0xFFF3F4F6),
                child: Icon(
                  icon,
                  size: 18,
                  color: const Color(0xFF4B5563),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF6B7280),
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right,
                size: 20,
                color: Color(0xFF9CA3AF),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
