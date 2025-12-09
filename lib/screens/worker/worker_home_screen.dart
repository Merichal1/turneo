import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../core/services/firestore_service.dart';
import '../../models/disponibilidad_evento.dart';

import 'worker_main_menu_screen.dart';
import 'worker_event_screen.dart';
import 'worker_availability_screen.dart';
import 'worker_notifications_screen.dart';
import 'worker_history_screen.dart';
import 'worker_chat_screen.dart';
import 'worker_profile_screen.dart';

class WorkerHomeScreen extends StatefulWidget {
  const WorkerHomeScreen({super.key});

  @override
  State<WorkerHomeScreen> createState() => _WorkerHomeScreenState();
}

class _WorkerHomeScreenState extends State<WorkerHomeScreen> {
  int _currentIndex = 0;

  late final List<Widget> _pages;

  @override
  void initState() {
    super.initState();

    // Inicializamos las páginas, la 0 será el NUEVO menú principal
    _pages = [
      WorkerMainMenuScreen(
        onNavigateToTab: _setTabFromMenu,
      ), // 0 – Menú principal
      const WorkerEventsScreen(),        // 1 – Eventos
      const WorkerAvailabilityScreen(),  // 2 – Disponibilidad
      const WorkerNotificationsScreen(), // 3 – Notificaciones
      WorkerHistoryScreen(),             // 4 – Historial
      WorkerChatScreen(),                // 5 – Chat
      WorkerProfileScreen(),             // 6 – Perfil
    ];
  }

  void _setTabFromMenu(int index) {
    // El índice que recibimos es el de la barra inferior (no el de la lista)
    setState(() {
      _currentIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return const Scaffold(
        body: Center(
          child: Text('Debes iniciar sesión como trabajador.'),
        ),
      );
    }

    // Escuchamos las solicitudes de disponibilidad de ese trabajador
    return StreamBuilder<List<DisponibilidadEvento>>(
      stream: FirestoreService.instance
          .listenSolicitudesDisponibilidadTrabajador(user.uid),
      builder: (context, snapshot) {
        final solicitudes = snapshot.data ?? [];

        // Contamos las solicitudes en estado "pendiente" (unread básicas)
        final int pendientes = solicitudes
            .where((s) => s.estado.toLowerCase() == 'pendiente')
            .length;

        return Scaffold(
          body: SafeArea(child: _pages[_currentIndex]),
          bottomNavigationBar: BottomNavigationBar(
            type: BottomNavigationBarType.fixed,
            currentIndex: _currentIndex,
            onTap: (i) => setState(() => _currentIndex = i),
            selectedItemColor: const Color(0xFF111827),
            unselectedItemColor: const Color(0xFF9CA3AF),
            showUnselectedLabels: true,
            items: [
              const BottomNavigationBarItem(
                icon: Icon(Icons.home_outlined),
                activeIcon: Icon(Icons.home),
                label: 'Inicio',
              ),
              const BottomNavigationBarItem(
                icon: Icon(Icons.event_note_outlined),
                activeIcon: Icon(Icons.event_note),
                label: 'Eventos',
              ),
              const BottomNavigationBarItem(
                icon: Icon(Icons.event_available_outlined),
                activeIcon: Icon(Icons.event_available),
                label: 'Disponib.',
              ),
              BottomNavigationBarItem(
                // Icono con bolita roja si hay pendientes
                icon: _NotificationIcon(
                  unread: pendientes,
                  selected: _currentIndex == 3,
                ),
                label: 'Notificaciones',
              ),
              const BottomNavigationBarItem(
                icon: Icon(Icons.history),
                label: 'Historial',
              ),
              const BottomNavigationBarItem(
                icon: Icon(Icons.chat_bubble_outline),
                activeIcon: Icon(Icons.chat_bubble),
                label: 'Chat',
              ),
              const BottomNavigationBarItem(
                icon: Icon(Icons.person_outline),
                activeIcon: Icon(Icons.person),
                label: 'Perfil',
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Icono de notificaciones con badge rojo
class _NotificationIcon extends StatelessWidget {
  final int unread;
  final bool selected;

  const _NotificationIcon({
    required this.unread,
    required this.selected,
  });

  @override
  Widget build(BuildContext context) {
    final baseIcon = selected
        ? const Icon(Icons.notifications)
        : const Icon(Icons.notifications_none);

    if (unread <= 0) {
      return baseIcon;
    }

    // Si hay más de 9, mostramos "9+"
    final String display = unread > 9 ? '9+' : unread.toString();

    return Stack(
      clipBehavior: Clip.none,
      children: [
        baseIcon,
        Positioned(
          right: -2,
          top: -2,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
            decoration: BoxDecoration(
              color: Colors.red,
              borderRadius: BorderRadius.circular(10),
            ),
            constraints: const BoxConstraints(
              minWidth: 16,
              minHeight: 16,
            ),
            child: Center(
              child: Text(
                display,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 9,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
