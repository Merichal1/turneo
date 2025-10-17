import 'package:flutter/material.dart';

class AdminHomeScreen extends StatefulWidget {
  const AdminHomeScreen({super.key});
  @override
  State<AdminHomeScreen> createState() => _AdminHomeScreenState();
}

class _AdminHomeScreenState extends State<AdminHomeScreen> {
  String search = '';
  String group = '';
  String city = '';

  final groups = const ['Todos', 'Montaje', 'Camarero', 'Seguridad', 'Conductor'];

  void _openMessageComposer() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Crear mensaje'),
        content: const Text('TODO: Mensajería interna'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cerrar')),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final users = [
      {'name': 'Ana Pérez', 'group': 'Camarero', 'city': 'Córdoba'},
      {'name': 'Luis Gómez', 'group': 'Montaje', 'city': 'Sevilla'},
    ].where((u) {
      final okSearch = search.isEmpty || (u['name'] as String).toLowerCase().contains(search.toLowerCase());
      final okGroup = group.isEmpty || group == 'Todos' || u['group'] == group;
      final okCity = city.isEmpty || (u['city'] as String).toLowerCase().contains(city.toLowerCase());
      return okSearch && okGroup && okCity;
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Turneo — Administrador'),
        actions: [
          IconButton(
            onPressed: () => Navigator.pushNamed(context, '/admin/events'),
            icon: const Icon(Icons.event_note),
            tooltip: 'Gestionar eventos',
          ),
          IconButton(
            onPressed: () => Navigator.pushNamed(context, '/admin/import'),
            icon: const Icon(Icons.cloud_upload_outlined),
            tooltip: 'Importar',
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('Búsqueda y filtros', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              SizedBox(
                width: 280,
                child: TextField(
                  decoration: const InputDecoration(labelText: 'Nombre / Buscar'),
                  onChanged: (v) => setState(() => search = v),
                ),
              ),
              SizedBox(
                width: 220,
                child: DropdownButtonFormField<String>(
                  decoration: const InputDecoration(labelText: 'Grupo'),
                  value: group.isEmpty ? 'Todos' : group,
                  items: groups.map((g) => DropdownMenuItem(value: g, child: Text(g))).toList(),
                  onChanged: (v) => setState(() => group = v ?? ''),
                ),
              ),
              SizedBox(
                width: 220,
                child: TextField(
                  decoration: const InputDecoration(labelText: 'Localidad'),
                  onChanged: (v) => setState(() => city = v),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text('Usuarios', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          ...users.map((u) => Card(
                child: ListTile(
                  leading: const CircleAvatar(child: Icon(Icons.person)),
                  title: Text(u['name'] as String),
                  subtitle: Text('${u['group']} • ${u['city']}'),
                  trailing: Wrap(spacing: 8, children: [
                    OutlinedButton(onPressed: _openMessageComposer, child: const Text('Mensaje')),
                    FilledButton(onPressed: () {}, child: const Text('Pagos')),
                  ]),
                ),
              )),
          const Divider(height: 32),
          ListTile(
            leading: const Icon(Icons.history),
            title: const Text('Historial de pagos'),
            subtitle: const Text('Consulta y exporta'),
            onTap: () {},
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Icons.notifications_active_outlined),
        label: const Text('Notificación grupal'),
        onPressed: () {
          // TODO: enviar notificación a un grupo o por filtros
        },
      ),
    );
  }
}
