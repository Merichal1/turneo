// lib/screens/admin/admin_shell_screen.dart

import 'package:flutter/material.dart';
import 'admin_home_screen.dart';
import 'admin_event_screen.dart';
import 'admin_notificaciones_screen.dart';
import 'admin_database_screen.dart';
import 'admin_payments_history_screen.dart';

class AdminShellScreen extends StatefulWidget {
  final int initialIndex;
  const AdminShellScreen({super.key, this.initialIndex = 0});
  @override State<AdminShellScreen> createState() => _AdminShellScreenState();
}

class _AdminShellScreenState extends State<AdminShellScreen> {
  late int _index = widget.initialIndex; // ← usamos el valor inicial que venga

  late final List<_TabItem> _tabs = [
    _TabItem('Usuarios', Icons.people_alt_outlined, () => const AdminHomeScreen()),
    _TabItem('Eventos', Icons.event_outlined, () => const AdminEventScreen()),
    _TabItem('Notificaciones', Icons.notifications_active_outlined, () => const AdminNotificacionesScreen()),
    _TabItem('Base de datos', Icons.storage_outlined, () => const AdminDatabaseScreen()),
    _TabItem('Pagos', Icons.receipt_long_outlined, () => const AdminPaymentsHistoryScreen()),
  ];

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, c) {
      final isWide = c.maxWidth >= 900;

      final titleStyle = Theme.of(context).textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w800,
            letterSpacing: -0.4,
          );

      final shellHeader = _ShellHeader(
        title: 'Administrador — ${_tabs[_index].label}',
        onSearch: (q) {
          // TODO: propaga búsqueda a la pestaña activa si lo deseas
        },
      );

      final content = IndexedStack(
  index: _index,
  children: _tabs
      .map((t) => _KeepAlive(
            child: _SectionFrame(child: t.builder), // ✅ sin paréntesis
          ))
      .toList(),
);


      if (isWide) {
        // —— DESKTOP / TABLET (Sidebar elegante)
        return Scaffold(
          backgroundColor: Theme.of(context).colorScheme.background,
          appBar: PreferredSize(
            preferredSize: const Size.fromHeight(64),
            child: AppBar(
              elevation: 0,
              title: Text('Turneo', style: titleStyle),
              actions: const [_UserAvatarButton()],
            ),
          ),
          body: Row(
            children: [
              const SizedBox(width: 16),
              _Sidebar(
                index: _index,
                onTap: (i) => setState(() => _index = i),
                items: _tabs,
              ),
              const VerticalDivider(width: 1),
              Expanded(
                child: Column(
                  children: [
                    shellHeader,
                    const SizedBox(height: 8),
                    Expanded(child: content),
                  ],
                ),
              ),
              const SizedBox(width: 12),
            ],
          ),
        );
      }

      // —— MÓVIL (Bottom bar limpio)
      return Scaffold(
        appBar: AppBar(
          title: Text('Administrador — ${_tabs[_index].label}', style: titleStyle),
          actions: const [_UserAvatarButton()],
        ),
        body: Column(
          children: [
            shellHeader,
            const SizedBox(height: 8),
            Expanded(child: content),
          ],
        ),
        bottomNavigationBar: NavigationBar(
          selectedIndex: _index,
          onDestinationSelected: (i) => setState(() => _index = i),
          destinations: _tabs
              .map((t) => NavigationDestination(icon: Icon(t.icon), label: t.label))
              .toList(),
        ),
      );
    });
  }
}

class _TabItem {
  final String label;
  final IconData icon;
  final Widget Function() builder;
  _TabItem(this.label, this.icon, this.builder);
}

class _Sidebar extends StatelessWidget {
  final int index;
  final void Function(int) onTap;
  final List<_TabItem> items;
  const _Sidebar({required this.index, required this.onTap, required this.items});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      width: 240,
      margin: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: cs.outline.withOpacity(0.08)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 16, offset: const Offset(0, 6))],
      ),
      child: NavigationRail(
        selectedIndex: index,
        onDestinationSelected: onTap,
        labelType: NavigationRailLabelType.all,
        useIndicator: true,
        groupAlignment: -1.0,
        destinations: [
          for (final t in items)
            NavigationRailDestination(
              icon: _SidebarIcon(icon: t.icon),
              selectedIcon: _SidebarIcon(icon: t.icon, selected: true),
              label: Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Text(t.label, style: const TextStyle(fontWeight: FontWeight.w800)),
              ),
            ),
        ],
      ),
    );
  }
}

class _SidebarIcon extends StatelessWidget {
  final IconData icon;
  final bool selected;
  const _SidebarIcon({required this.icon, this.selected = false});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: selected ? cs.primary.withOpacity(0.18) : cs.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cs.outline.withOpacity(0.06)),
      ),
      child: Icon(icon, size: 20, color: selected ? cs.primary : cs.onSurface.withOpacity(0.9)),
    );
  }
}

class _ShellHeader extends StatelessWidget {
  final String title;
  final void Function(String query)? onSearch;
  const _ShellHeader({required this.title, this.onSearch});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: LinearGradient(
          colors: [cs.primary.withOpacity(0.10), cs.surface],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(color: cs.outline.withOpacity(0.06)),
      ),
      child: Row(
        children: [
          Text(title, style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
          const Spacer(),
          SizedBox(
            width: 280,
            child: TextField(
              onSubmitted: (v) => onSearch?.call(v),
              decoration: const InputDecoration(
                hintText: 'Buscar…',
                prefixIcon: Icon(Icons.search),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionFrame extends StatelessWidget {
  final Widget Function() child;
  const _SectionFrame({required this.child});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
          ),
          child: child(),
        ),
      ),
    );
  }
}

class _UserAvatarButton extends StatelessWidget {
  const _UserAvatarButton();
  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: 'Mi cuenta',
      onPressed: () {/* TODO: abrir perfil/ajustes */},
      icon: const CircleAvatar(
        radius: 14,
        child: Icon(Icons.person, size: 16),
      ),
    );
  }
}

class _KeepAlive extends StatefulWidget {
  final Widget child;
  const _KeepAlive({super.key, required this.child});
  @override
  State<_KeepAlive> createState() => _KeepAliveState();
}
class _KeepAliveState extends State<_KeepAlive> with AutomaticKeepAliveClientMixin {
  @override
  Widget build(BuildContext context) { super.build(context); return widget.child; }
  @override
  bool get wantKeepAlive => true;
}
