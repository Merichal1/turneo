import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class WorkerMainMenuScreen extends StatelessWidget {
  final void Function(int) onNavigateToTab;

  const WorkerMainMenuScreen({
    super.key,
    required this.onNavigateToTab,
  });

  // ====== THEME (Turneo / Login) ======
  static const Color _bg = Color(0xFFF6F8FC);
  static const Color _card = Colors.white;
  static const Color _border = Color(0xFFE5E7EB);
  static const Color _textDark = Color(0xFF111827);
  static const Color _textGrey = Color(0xFF6B7280);
  static const Color _blue = Color(0xFF2563EB);

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final email = (user?.email ?? '').trim();
    final displayName = (user?.displayName ?? '').trim();

    final String saludoNombre = displayName.isNotEmpty
        ? displayName
        : (email.isNotEmpty ? email.split('@').first : 'Trabajador');

    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ===== Header =====
              Container(
                padding: const EdgeInsets.all(16),
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
                child: Row(
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: _blue,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Icon(
                        Icons.restaurant_menu,
                        color: Colors.white,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Hola, $saludoNombre 👋',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w900,
                              color: _textDark,
                            ),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'Aquí puedes ver asignaciones, marcar no disponibilidad y revisar avisos.',
                            style: TextStyle(
                              fontSize: 12.5,
                              color: _textGrey,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // ===== Quick actions =====
              const Text(
                'Accesos rápidos',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w900,
                  color: _textDark,
                ),
              ),
              const SizedBox(height: 10),

              LayoutBuilder(
                builder: (context, c) {
                  final w = c.maxWidth;
                  int cols = 2;
                  if (w >= 900) cols = 4;
                  else if (w >= 600) cols = 3;

                  return GridView.count(
                    crossAxisCount: cols,
                    shrinkWrap: true,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    physics: const NeverScrollableScrollPhysics(),
                    children: [
                      _MenuCard(
                        icon: Icons.calendar_month,
                        title: 'Mi calendario',
                        subtitle: 'Asignaciones + no disponibilidad',
                        accent: const Color(0xFF10B981),
                        onTap: () => onNavigateToTab(1), // ✅ Calendario
                      ),
                      _MenuCard(
                        icon: Icons.notifications,
                        title: 'Notificaciones',
                        subtitle: 'Solicitudes del administrador',
                        accent: const Color(0xFFF97316),
                        onTap: () => onNavigateToTab(2), // ✅ Avisos
                      ),
                      _MenuCard(
                        icon: Icons.history,
                        title: 'Historial',
                        subtitle: 'Eventos anteriores y estados',
                        accent: const Color(0xFF3B82F6),
                        onTap: () => onNavigateToTab(3), // ✅ Historial
                      ),
                      _MenuCard(
                        icon: Icons.chat_bubble,
                        title: 'Mensajes',
                        subtitle: 'Chat con el admin',
                        accent: const Color(0xFF6366F1),
                        onTap: () => onNavigateToTab(4), // ✅ Chat
                      ),
                    ],
                  );
                },
              ),

              const SizedBox(height: 18),

              // ===== Account =====
              const Text(
                'Tu cuenta',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w900,
                  color: _textDark,
                ),
              ),
              const SizedBox(height: 10),

              const SizedBox(height: 12),

              // opcional: card info (solo UI, no rompe nada)
              if (email.isNotEmpty)
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: _card,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: _border),
                  ),
                  child: Row(
                    children: const [
                      Icon(Icons.verified_user_outlined, color: _blue),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Tu sesión está activa.',
                          style: TextStyle(
                            color: _textDark,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MenuCard extends StatelessWidget {
  static const Color _card = Colors.white;
  static const Color _border = Color(0xFFE5E7EB);
  static const Color _textDark = Color(0xFF111827);
  static const Color _textGrey = Color(0xFF6B7280);

  final IconData icon;
  final String title;
  final String subtitle;
  final Color accent;
  final VoidCallback onTap;

  const _MenuCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.accent,
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
            CircleAvatar(
              radius: 18,
              backgroundColor: accent.withOpacity(0.12),
              child: Icon(icon, color: accent, size: 20),
            ),
            const Spacer(),
            Text(
              title,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w900,
                color: _textDark,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 11.5,
                color: _textGrey,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ListTileCard extends StatelessWidget {
  static const Color _card = Colors.white;
  static const Color _border = Color(0xFFE5E7EB);
  static const Color _textDark = Color(0xFF111827);
  static const Color _textGrey = Color(0xFF6B7280);

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
      borderRadius: BorderRadius.circular(18),
      color: _card,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: _border),
            boxShadow: const [
              BoxShadow(
                color: Color(0x10000000),
                blurRadius: 14,
                offset: Offset(0, 6),
              ),
            ],
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: const Color(0xFFEFF6FF),
                child: Icon(icon, size: 20, color: const Color(0xFF2563EB)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                        color: _textDark,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 12,
                        color: _textGrey,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right,
                size: 22,
                color: Color(0xFF9CA3AF),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
