import 'package:flutter/material.dart';

import 'admin_event_screen.dart';

/// Wrapper para mantener compatibilidad con el shell antiguo.
/// Si en algún sitio se usa `AdminEventsScreen`, simplemente
/// mostramos `AdminEventScreen` (que es el que ya hemos arreglado).
class AdminEventsScreen extends StatelessWidget {
  const AdminEventsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const AdminEventScreen();
  }
}
