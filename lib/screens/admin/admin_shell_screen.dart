import 'package:flutter/material.dart';
import 'admin_home_screen.dart';
import 'admin_events_screen.dart';
import 'admin_payments_history_screen.dart';
import 'admin_notificaciones_screen.dart';
import 'admin_workers_screen.dart';

// OJO: de momento NO importamos admin_database_screen.dart para evitar conflictos
// import 'admin_database_screen.dart';

class AdminShellScreen extends StatefulWidget {
  const AdminShellScreen({super.key});

  @override
  State<AdminShellScreen> createState() => _AdminShellScreenState();
}

class _AdminShellScreenState extends State<AdminShellScreen> {
  int _selectedIndex = 0;

  // Páginas del menú lateral
  // NO ponemos "const [ ... ]" porque algunas pantallas pueden no tener constructor const
  final List<Widget> _pages = [
  const AdminHomeScreen(),                 // 0 – Dashboard
  const AdminEventsScreen(),
  const AdminWorkersScreen(),          // 1 – Eventos
  const AdminNotificacionesScreen(), // 3 – Notificaciones
  const AdminPaymentsHistoryScreen(),// 4 – Pagos
  const AdminDatabaseScreen(),       // 5 – Empresas (puede seguir siendo placeholder)
];

  @override
  Widget build(BuildContext context) {
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

  Widget _buildSideMenu(BuildContext context) {
    return Container(
      width: 220,
      color: Colors.white,
      child: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 24),
            // Logo / nombre app
            Text(
              'EventStaff Admin',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 32),

            // Opciones de menú
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
              icon: Icons.payments_outlined,
              label: 'Pagos',
              isSelected: _selectedIndex == 4,
              onTap: () => _onItemTap(4),
            ),
            _SideMenuItem(
              icon: Icons.business_outlined,
              label: 'Empresas',
              isSelected: _selectedIndex == 5,
              onTap: () => _onItemTap(5),
            ),

            const Spacer(),
            const Divider(),
            ListTile(
              leading: const CircleAvatar(
                radius: 16,
                child: Text('AC'),
              ),
              title: const Text('Admin Carlos'),
              subtitle: const Text('admin@eventstaff.com'),
            ),
            TextButton.icon(
              onPressed: () {
                // TODO: lógica de logout
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

// ───────────────────────── Placeholders para que compile ─────────────────────


// Empresas / Base de datos
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
