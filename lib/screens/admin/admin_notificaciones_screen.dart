import 'package:flutter/material.dart';

class AdminNotificacionesScreen extends StatefulWidget {
  const AdminNotificacionesScreen({super.key});

  @override
  State<AdminNotificacionesScreen> createState() =>
      _AdminNotificacionesScreenState();
}

class _AdminNotificacionesScreenState extends State<AdminNotificacionesScreen> {
  final List<_Notif> _all = [
    _Notif(id: '1', title: 'Backup completado', body: 'Firebase export OK', tag: 'Sistema'),
    _Notif(id: '2', title: 'Nuevo usuario', body: 'Se registró juan@example.com', tag: 'Usuarios'),
    _Notif(id: '3', title: 'Evento hoy', body: 'Revisar asignaciones de turnos', tag: 'Eventos'),
  ];

  String _filtro = 'Todas';
  final List<String> _chips = const ['Todas', 'No leídas', 'Sistema', 'Usuarios', 'Eventos'];

  @override
  Widget build(BuildContext context) {
    final items = _filtrar();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notificaciones (Admin)'),
        actions: [
          IconButton(
            tooltip: 'Marcar todas como leídas',
            onPressed: _marcarTodasLeidas,
            icon: const Icon(Icons.done_all),
          ),
          IconButton(
            tooltip: 'Limpiar leídas',
            onPressed: _borrarLeidas,
            icon: const Icon(Icons.clear_all),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _onRefresh,
        child: Column(
          children: [
            SizedBox(
              height: 56,
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                scrollDirection: Axis.horizontal,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemCount: _chips.length,
                itemBuilder: (context, i) {
                  final label = _chips[i];
                  final selected = _filtro == label;
                  return ChoiceChip(
                    label: Text(label),
                    selected: selected,
                    onSelected: (_) => setState(() => _filtro = label),
                  );
                },
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: items.isEmpty
                  ? _EmptyState(
                      title: 'Sin notificaciones',
                      subtitle: 'Cambia el filtro o tira para refrescar.',
                      icon: Icons.notifications_off_outlined,
                    )
                  : ListView.builder(
                      physics: const AlwaysScrollableScrollPhysics(),
                      itemCount: items.length,
                      itemBuilder: (context, index) {
                        final n = items[index];
                        return Dismissible(
                          key: ValueKey(n.id),
                          background: _swipeBg(Colors.green, Icons.mark_email_read, 'Leída'),
                          secondaryBackground: _swipeBg(Colors.red, Icons.delete_outline, 'Borrar'),
                          confirmDismiss: (dir) async {
                            if (dir == DismissDirection.startToEnd) {
                              setState(() => n.read = true);
                              return false; // no borrar, solo marcar leída
                            } else {
                              setState(() => _all.removeWhere((e) => e.id == n.id));
                              return true; // borrar
                            }
                          },
                          child: ListTile(
                            leading: Icon(
                              n.read ? Icons.notifications_none : Icons.notifications_active,
                            ),
                            title: Text(n.title,
                                style: n.read
                                    ? null
                                    : Theme.of(context)
                                        .textTheme
                                        .titleMedium
                                        ?.copyWith(fontWeight: FontWeight.w600)),
                            subtitle: Text(n.body),
                            trailing: Text(
                              n.tag,
                              style: Theme.of(context).textTheme.labelMedium,
                            ),
                            onTap: () => setState(() => n.read = true),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  List<_Notif> _filtrar() {
    Iterable<_Notif> it = _all;
    switch (_filtro) {
      case 'No leídas':
        it = it.where((n) => !n.read);
        break;
      case 'Sistema':
      case 'Usuarios':
      case 'Eventos':
        it = it.where((n) => n.tag == _filtro);
        break;
      default:
        // 'Todas' -> sin filtro
        break;
    }
    return it.toList();
  }

  Future<void> _onRefresh() async {
    // TODO: Sustituir por fetch real (Firestore/Functions).
    await Future<void>.delayed(const Duration(milliseconds: 600));
    if (mounted) setState(() {});
  }

  void _marcarTodasLeidas() {
    setState(() {
      for (final n in _all) {
        n.read = true;
      }
    });
  }

  void _borrarLeidas() {
    setState(() {
      _all.removeWhere((n) => n.read);
    });
  }

  Widget _swipeBg(Color c, IconData i, String text) {
    return Container(
      alignment: Alignment.centerLeft,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      color: c.withOpacity(0.15),
      child: Row(
        children: [
          Icon(i),
          const SizedBox(width: 8),
          Text(text),
        ],
      ),
    );
  }
}

class _Notif {
  final String id;
  final String title;
  final String body;
  final String tag;
  bool read;
  _Notif({
    required this.id,
    required this.title,
    required this.body,
    required this.tag,
    this.read = false,
  });
}

/// Pequeño estado vacío reutilizable
class _EmptyState extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;

  const _EmptyState({
    required this.title,
    required this.subtitle,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 64),
            const SizedBox(height: 12),
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(subtitle, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}
