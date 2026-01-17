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

  final GlobalKey<ScaffoldState> _scaffoldKey =
      GlobalKey<ScaffoldState>(); // NUEVO

  // Orden EXACTO de las pantallas según el menú
  final List<Widget> _pages = [
    const AdminHomeScreen(), // 0 – Dashboard
    const AdminEventsScreen(), // 1 – Eventos
    const AdminWorkersScreen(), // 2 – Trabajadores
    const AdminNotificacionesScreen(), // 3 – Notificaciones
    const AdminChatScreen(), // 4 – Chat
    const AdminPaymentsHistoryScreen(), // 5 – Pagos
    const AdminDatabaseScreen(), // 6 – Empresas
  ];

@override
Widget build(BuildContext context) {
  return StreamBuilder<User?>(
    stream: FirebaseAuth.instance.authStateChanges(),
    builder: (context, snapshot) {
      if (snapshot.connectionState == ConnectionState.waiting) {
        return const Scaffold(body: Center(child: CircularProgressIndicator()));
      }

      final user = snapshot.data;

      if (user == null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          Navigator.of(context).pushNamedAndRemoveUntil('/login', (_) => false);
        });
        return const Scaffold(body: Center(child: CircularProgressIndicator()));
      }

      return LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth >= 900;
          final isCompact = constraints.maxWidth < 600;

          if (isWide) return _buildWideScaffold(context);
          return _buildNarrowScaffold(context, isCompact: isCompact);
        },
      );
    },
  );
}


  // NUEVO: Layout escritorio/web: menú lateral fijo (como estaba antes)
  Widget _buildWideScaffold(BuildContext context) {
    return Scaffold(
      body: Row(
        children: [
          _buildSideMenu(context),
          Expanded(
            child: Container(
              color: const Color(0xFFF5F6FA),
              child: _pages[_selectedIndex],
            ),
          ),
        ],
      ),
    );
  }

  // NUEVO: Layout móvil/tablet: Drawer + (en móvil) NavigationBar inferior
  Widget _buildNarrowScaffold(BuildContext context, {required bool isCompact}) {
    return Scaffold(
      key: _scaffoldKey, // NUEVO
      drawer: Drawer(
        child: _buildDrawerMenu(context), // NUEVO
      ),
      appBar: AppBar(
        title: Text(_titleForIndex(_selectedIndex)), // NUEVO
      ),
      body: Container(
        color: const Color(0xFFF5F6FA),
        child: _pages[_selectedIndex],
      ),
      bottomNavigationBar: isCompact
          ? NavigationBar(
              selectedIndex: _compactNavIndex(), // NUEVO
              onDestinationSelected: (idx) {
                // 0 Dashboard, 1 Eventos, 2 Trabajadores, 3 Más // NUEVO
                if (idx == 3) {
                  _scaffoldKey.currentState?.openDrawer(); // NUEVO
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

  // NUEVO
  int _compactNavIndex() {
    // Si estás en sección secundaria (notificaciones/chat/pagos/empresas), marcamos "Más".
    if (_selectedIndex <= 2) return _selectedIndex;
    return 3;
  }

  // NUEVO
  String _titleForIndex(int index) {
    switch (index) {
      case 0:
        return 'Dashboard';
      case 1:
        return 'Eventos';
      case 2:
        return 'Trabajadores';
      case 3:
        return 'Notificaciones';
      case 4:
        return 'Chat';
      case 5:
        return 'Gestión';
      case 6:
        return 'Empresas';
      default:
        return 'Admin';
    }
  }

  // NUEVO
  Widget _buildDrawerMenu(BuildContext context) {
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.symmetric(vertical: 12),
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Text(
              'EventStaff Admin',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
          ),
          const Divider(),
          _drawerItem(
            context,
            icon: Icons.dashboard_outlined,
            label: 'Dashboard',
            index: 0,
          ),
          _drawerItem(
            context,
            icon: Icons.event_outlined,
            label: 'Eventos',
            index: 1,
          ),
          _drawerItem(
            context,
            icon: Icons.group_outlined,
            label: 'Trabajadores',
            index: 2,
          ),
          _drawerItem(
            context,
            icon: Icons.notifications_outlined,
            label: 'Notificaciones',
            index: 3,
          ),
          _drawerItem(
            context,
            icon: Icons.chat_bubble_outline,
            label: 'Chat',
            index: 4,
          ),
          _drawerItem(
            context,
            icon: Icons.payments_outlined,
            label: 'Gestión',
            index: 5,
          ),
          const Divider(),
          const ListTile(
            leading: CircleAvatar(
              radius: 16,
              child: Text('AD'),
            ),
            title: Text('Administrador'),
            subtitle: Text('admin@eventstaff.com'),
          ),
          ListTile(
            leading: const Icon(Icons.logout, size: 20),
            title: const Text('Cerrar sesión'),
            onTap: () async {
              Navigator.of(context).pop();
              await FirebaseAuth.instance.signOut();
              if (!mounted) return;
              Navigator.of(context).pushNamedAndRemoveUntil('/login', (_) => false);
            },
          ),
        ],
      ),
    );
  }

  // NUEVO
  Widget _drawerItem(
    BuildContext context, {
    required IconData icon,
    required String label,
    required int index,
  }) {
    final isSelected = _selectedIndex == index;
    return ListTile(
      leading: Icon(icon),
      title: Text(label),
      selected: isSelected,
      selectedTileColor: Colors.black.withOpacity(0.06), // NUEVO
      onTap: () {
        Navigator.of(context).pop(); // NUEVO
        _onItemTap(index);
      },
    );
  }

  Widget _buildSideMenu(BuildContext context) {
    return Container(
      width: 220,
      color: Colors.white,
      child: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 24),
            Text(
              'EventStaff Admin',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 32),
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
            _SideMenuItem(
              icon: Icons.business_outlined,
              label: 'Empresas',
              isSelected: _selectedIndex == 6,
              onTap: () => _onItemTap(6),
            ),
            const Spacer(),
            const Divider(),
            const ListTile(
              leading: CircleAvatar(
                radius: 16,
                child: Text('AD'),
              ),
              title: Text('Administrador'),
              subtitle: Text('admin@eventstaff.com'),
            ),
            TextButton.icon(
              onPressed: () async {
                await FirebaseAuth.instance.signOut();
                if (!mounted) return;
                Navigator.of(context).pushNamedAndRemoveUntil('/login', (_) => false);
              },
              icon: const Icon(Icons.logout, size: 18),
              label: const Text('Cerrar sesión'),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  void _onItemTap(int index) {
    setState(() {
      _selectedIndex = index;
    });
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

  @override
  Widget build(BuildContext context) {
    final bgColor = isSelected ? const Color(0xFF111827) : Colors.transparent;
    final textColor = isSelected ? Colors.white : const Color(0xFF4B5563);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            children: [
              Icon(icon, size: 20, color: textColor),
              const SizedBox(width: 12),
              Text(
                label,
                style: TextStyle(
                  color: textColor,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Placeholder para Empresas
class AdminDatabaseScreen extends StatelessWidget {
  const AdminDatabaseScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Text(
        'Pantalla de Empresas / Base de datos (pendiente de implementar)',
        style: TextStyle(fontSize: 18),
      ),
    );
  }
}
