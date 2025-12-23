import 'package:flutter/material.dart';
import 'admin_event_screen.dart';

/// Este widget actúa como el punto de entrada desde el menú lateral (Sidebar).
/// Simplemente carga la pantalla de gestión de eventos que hemos diseñado.
class AdminEventsScreen extends StatelessWidget {
  const AdminEventsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Usamos const para optimizar el rendimiento de renderizado
    return const AdminEventScreen();
  }
}