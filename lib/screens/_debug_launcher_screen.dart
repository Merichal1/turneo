import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../routes/app_routes.dart';

class DebugLauncherScreen extends StatefulWidget {
  const DebugLauncherScreen({super.key});

  @override
  State<DebugLauncherScreen> createState() => _DebugLauncherScreenState();
}

class _DebugLauncherScreenState extends State<DebugLauncherScreen> {
  String _query = '';

  // Definimos secciones para mostrar bonito en el launcher.
  final Map<String, List<_DebugItem>> _sections = {
    'Auth': [
      _DebugItem('Login', Routes.login, Icons.login),
      _DebugItem('Register', Routes.register, Icons.app_registration),
      _DebugItem('Change Password', Routes.changePassword, Icons.password),
    ],
    'Admin': [
      _DebugItem('Admin Shell', Routes.adminShell, Icons.dashboard_customize),
      _DebugItem('Admin Home', Routes.adminHome, Icons.home_filled),
      _DebugItem('Admin Events', Routes.adminEvents, Icons.event),
      _DebugItem('Admin Database', Routes.adminDatabase, Icons.storage),
      _DebugItem('Admin Import', Routes.adminImport, Icons.file_upload),
      _DebugItem('Payments History', Routes.adminPaymentsHistory, Icons.receipt_long),
      _DebugItem('Notifications', Routes.adminNotifications, Icons.notifications),
    ],
    'Worker': [
      _DebugItem('Worker Home', Routes.workerHome, Icons.badge),
      _DebugItem('Worker Events', Routes.workerEvents, Icons.event_note),
    ],
    'Common': [
      _DebugItem('Splash', Routes.splash, Icons.surfing),
      _DebugItem('Error', Routes.error, Icons.error_outline),
    ],
  };

  @override
  Widget build(BuildContext context) {
    assert(!kReleaseMode,
        'El DebugLauncherScreen no debe mostrarse en Release.');

    final filtered = _filterByQuery(_sections, _query);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Launcher de interfaces'),
        centerTitle: false,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: TextField(
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search),
                hintText: 'Busca: admin, worker, login...',
                border: OutlineInputBorder(),
              ),
              onChanged: (v) => setState(() => _query = v.trim()),
            ),
          ),
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.only(bottom: 24),
              separatorBuilder: (_, __) => const Divider(height: 24),
              itemCount: filtered.length,
              itemBuilder: (context, index) {
                final sectionTitle = filtered.keys.elementAt(index);
                final items = filtered[sectionTitle]!;
                return _Section(title: sectionTitle, items: items);
              },
            ),
          ),
        ],
      ),
    );
  }

  Map<String, List<_DebugItem>> _filterByQuery(
    Map<String, List<_DebugItem>> data,
    String q,
  ) {
    if (q.isEmpty) return data;
    final lower = q.toLowerCase();
    final Map<String, List<_DebugItem>> res = {};
    data.forEach((section, items) {
      final matches = items
          .where((e) =>
              e.title.toLowerCase().contains(lower) ||
              e.route.toLowerCase().contains(lower))
          .toList();
      if (matches.isNotEmpty) res[section] = matches;
    });
    return res;
  }
}

class _Section extends StatelessWidget {
  final String title;
  final List<_DebugItem> items;
  const _Section({required this.title, required this.items});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Card(
        elevation: 2,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              const Divider(height: 8),
              ...items.map((e) => ListTile(
                    leading: Icon(e.icon),
                    title: Text(e.title),
                    subtitle: Text(e.route),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => Navigator.of(context).pushNamed(e.route),
                  )),
            ],
          ),
        ),
      ),
    );
  }
}

class _DebugItem {
  final String title;
  final String route;
  final IconData icon;
  const _DebugItem(this.title, this.route, this.icon);
}

