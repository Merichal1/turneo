import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'admin_home_screen.dart';
import 'admin_events_screen.dart';
import 'admin_workers_screen.dart';
import 'admin_notificaciones_screen.dart';
import 'admin_payments_history_screen.dart';
import 'admin_chat_screen.dart';

class AdminShellScreen extends StatefulWidget {
  const AdminShellScreen({super.key});

  @override
  State<AdminShellScreen> createState() => _AdminShellScreenState();
}

class _AdminShellScreenState extends State<AdminShellScreen> {
  int _selectedIndex = 0;

  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  // ✅ Mantiene estado de cada pantalla (shell fijo)
  // ❗ NO lo marques const. Evita problemas con pantallas no-const o cambios en hot reload.
  late final List<Widget> _pages = [
    const AdminHomeScreen(),               // 0 – Dashboard
    const AdminEventsScreen(),             // 1 – Eventos
    const AdminWorkersScreen(),            // 2 – Trabajadores
    const AdminNotificacionesScreen(),     // 3 – Notificaciones
    const AdminChatScreen(),               // 4 – Chat
    const AdminPaymentsHistoryScreen(),    // 5 – Gestión
  ];

  // 🎨 Estilo Turneo (login)
  static const Color _bg = Color(0xFFF6F8FC);
  static const Color _textDark = Color(0xFF111827);
  static const Color _textGrey = Color(0xFF6B7280);
  static const Color _border = Color(0xFFE5E7EB);
  static const Color _blue = Color(0xFF2563EB);

  bool _redirecting = false;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final user = snap.data;

        // ✅ Si no hay usuario, redirige una sola vez
        if (user == null) {
          if (!_redirecting) {
            _redirecting = true;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (!mounted) return;
              Navigator.of(context).pushNamedAndRemoveUntil('/welcome', (_) => false);
              // Si tu ruta es /login:
              // Navigator.of(context).pushNamedAndRemoveUntil('/login', (_) => false);
            });
          }
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }

        // ✅ Reset del flag si vuelve a haber user
        _redirecting = false;

        return LayoutBuilder(
          builder: (context, constraints) {
            final isWide = constraints.maxWidth >= 900;
            final isCompact = constraints.maxWidth < 600;

            if (isWide) return _buildWideScaffold(context, user);
            return _buildNarrowScaffold(context, user, isCompact: isCompact);
          },
        );
      },
    );
  }

  // ---------------------------
  // WIDE (web/desktop): side menu fijo
  // ---------------------------
  Widget _buildWideScaffold(BuildContext context, User user) {
    return Scaffold(
      backgroundColor: _bg,
      body: Row(
        children: [
          _buildSideMenu(context, user),
          Expanded(
            child: Container(
              color: _bg,
              child: IndexedStack(
                index: _selectedIndex,
                children: _pages,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------
  // NARROW (mobile/tablet): drawer + bottom nav (compact)
  // ---------------------------
  Widget _buildNarrowScaffold(BuildContext context, User user, {required bool isCompact}) {
    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: _bg,
      drawer: Drawer(
        child: _buildDrawerMenu(context, user),
      ),
      // ✅ Sin AppBar aquí para que NO “salte” ni duplique con las pantallas internas
      body: SafeArea(
        child: IndexedStack(
          index: _selectedIndex,
          children: _pages,
        ),
      ),
      bottomNavigationBar: isCompact
          ? NavigationBar(
              selectedIndex: _compactNavIndex(),
              onDestinationSelected: (idx) {
                if (idx == 3) {
                  _scaffoldKey.currentState?.openDrawer();
                  return;
                }
                _onItemTap(idx);
              },
              destinations: const [
                NavigationDestination(
                  icon: Icon(Icons.dashboard_outlined),
                  label: 'Inicio',
                ),
                NavigationDestination(
                  icon: Icon(Icons.event_outlined),
                  label: 'Eventos',
                ),
                NavigationDestination(
                  icon: Icon(Icons.group_outlined),
                  label: 'Equipo',
                ),
                NavigationDestination(
                  icon: Icon(Icons.menu),
                  label: 'Más',
                ),
              ],
            )
          : null,
    );
  }

  int _compactNavIndex() {
    if (_selectedIndex <= 2) return _selectedIndex;
    return 3;
  }

  // ---------------------------
  // Drawer menu
  // ---------------------------
  Widget _buildDrawerMenu(BuildContext context, User user) {
    final email = (user.email ?? '').trim();

    return SafeArea(
      child: Container(
        color: Colors.white,
        child: ListView(
          padding: const EdgeInsets.symmetric(vertical: 12),
          children: [
            const SizedBox(height: 8),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 14),
              child: _TurneoBrandHeader(),
            ),
            const SizedBox(height: 12),
            const Divider(height: 1),

            _drawerItem(context, icon: Icons.dashboard_outlined, label: 'Dashboard', index: 0),
            _drawerItem(context, icon: Icons.event_outlined, label: 'Eventos', index: 1),
            _drawerItem(context, icon: Icons.group_outlined, label: 'Trabajadores', index: 2),
            _drawerItem(context, icon: Icons.notifications_outlined, label: 'Notificaciones', index: 3),
            _drawerItem(context, icon: Icons.chat_bubble_outline, label: 'Chat', index: 4),
            _drawerItem(context, icon: Icons.payments_outlined, label: 'Gestión', index: 5),

            const SizedBox(height: 10),
            const Divider(height: 1),

            ListTile(
              leading: const CircleAvatar(
                radius: 18,
                backgroundColor: Color(0xFFEFF6FF),
                child: Text(
                  'AD',
                  style: TextStyle(color: _blue, fontWeight: FontWeight.w800),
                ),
              ),
              title: const Text('Administrador', style: TextStyle(fontWeight: FontWeight.w700)),
              subtitle: Text(email.isEmpty ? '—' : email, style: const TextStyle(color: _textGrey)),
            ),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: OutlinedButton.icon(
                icon: const Icon(Icons.logout),
                label: const Text('Cerrar sesión'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: _blue,
                  side: const BorderSide(color: _border),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () async {
                  Navigator.of(context).pop(); // cierra drawer
                  await FirebaseAuth.instance.signOut(); // el StreamBuilder redirige
                },
              ),
            ),

            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  Widget _drawerItem(
    BuildContext context, {
    required IconData icon,
    required String label,
    required int index,
  }) {
    final isSelected = _selectedIndex == index;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      child: ListTile(
        leading: Icon(icon, color: isSelected ? _blue : _textGrey),
        title: Text(
          label,
          style: TextStyle(
            color: isSelected ? _textDark : _textGrey,
            fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
          ),
        ),
        selected: isSelected,
        selectedTileColor: const Color(0xFFEFF6FF),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        onTap: () {
          Navigator.of(context).pop();
          _onItemTap(index);
        },
      ),
    );
  }

  // ---------------------------
  // Side menu (wide)
  // ---------------------------
  Widget _buildSideMenu(BuildContext context, User user) {
    final email = (user.email ?? '').trim();

    return Container(
      width: 250,
      color: Colors.white,
      child: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 16),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 14),
              child: _TurneoBrandHeader(),
            ),
            const SizedBox(height: 16),

            _SideMenuItem(
              icon: Icons.dashboard_outlined,
              label: 'Dashboard',
              isSelected: _selectedIndex == 0,
              onTap: () => _onItemTap(0),
            ),
            _SideMenuItem(
              icon: Icons.event_outlined,
              label: 'Eventos',
              isSelected: _selectedIndex == 1,
              onTap: () => _onItemTap(1),
            ),
            _SideMenuItem(
              icon: Icons.group_outlined,
              label: 'Trabajadores',
              isSelected: _selectedIndex == 2,
              onTap: () => _onItemTap(2),
            ),
            _SideMenuItem(
              icon: Icons.notifications_outlined,
              label: 'Notificaciones',
              isSelected: _selectedIndex == 3,
              onTap: () => _onItemTap(3),
            ),
            _SideMenuItem(
              icon: Icons.chat_bubble_outline,
              label: 'Chat',
              isSelected: _selectedIndex == 4,
              onTap: () => _onItemTap(4),
            ),
            _SideMenuItem(
              icon: Icons.payments_outlined,
              label: 'Gestión',
              isSelected: _selectedIndex == 5,
              onTap: () => _onItemTap(5),
            ),

            const Spacer(),
            const Divider(height: 1),

            ListTile(
              leading: const CircleAvatar(
                radius: 18,
                backgroundColor: Color(0xFFEFF6FF),
                child: Text('AD', style: TextStyle(color: _blue, fontWeight: FontWeight.w800)),
              ),
              title: const Text('Administrador', style: TextStyle(fontWeight: FontWeight.w700)),
              subtitle: Text(email.isEmpty ? '—' : email, style: const TextStyle(color: _textGrey)),
            ),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.logout),
                  label: const Text('Cerrar sesión'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: _blue,
                    side: const BorderSide(color: _border),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () async {
                    await FirebaseAuth.instance.signOut(); // el StreamBuilder redirige
                  },
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  void _onItemTap(int index) {
    if (_selectedIndex == index) return;
    setState(() => _selectedIndex = index);
  }
}

// ------------------------------------
// UI pieces
// ------------------------------------

class _TurneoBrandHeader extends StatelessWidget {
  const _TurneoBrandHeader();

  static const Color _blue = Color(0xFF2563EB);
  static const Color _textDark = Color(0xFF111827);

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: _blue,
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(Icons.restaurant_menu, color: Colors.white, size: 20),
        ),
        const SizedBox(width: 10),
        const Text(
          'Turneo',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: _textDark,
          ),
        ),
      ],
    );
  }
}

class _SideMenuItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _SideMenuItem({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  static const Color _blue = Color(0xFF2563EB);
  static const Color _textDark = Color(0xFF111827);
  static const Color _textGrey = Color(0xFF6B7280);

  @override
  Widget build(BuildContext context) {
    final bg = isSelected ? const Color(0xFFEFF6FF) : Colors.transparent;
    final ic = isSelected ? _blue : _textGrey;
    final tx = isSelected ? _textDark : _textGrey;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Icon(icon, size: 20, color: ic),
              const SizedBox(width: 12),
              Text(
                label,
                style: TextStyle(
                  color: tx,
                  fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
