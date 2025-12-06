import 'package:flutter/material.dart';
import 'worker_event_screen.dart';
import 'worker_availability_screen.dart';
import 'worker_notifications_screen.dart';
import 'worker_history_screen.dart';
import 'worker_chat_screen.dart';
import 'worker_profile_screen.dart';
import 'worker_availability_requests_screen.dart'; // 👈 NUEVO

class WorkerHomeScreen extends StatefulWidget {
  const WorkerHomeScreen({super.key});

  @override
  State<WorkerHomeScreen> createState() => _WorkerHomeScreenState();
}

class _WorkerHomeScreenState extends State<WorkerHomeScreen> {
  int _currentIndex = 0;

  // Páginas del bottom nav
  final List<Widget> _pages = [
    const WorkerEventsScreen(),          // 0 – Eventos
    const WorkerAvailabilityScreen(),    // 1 – Disponibilidad general
    const WorkerNotificationsScreen(),   // 2 – Notificaciones
    WorkerHistoryScreen(),               // 3 – Historial
    WorkerChatScreen(),                  // 4 – Chat
    WorkerProfileScreen(),               // 5 – Perfil
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(child: _pages[_currentIndex]),

      // 👇 FAB solo en la pestaña de Disponibilidad (index 1)
      floatingActionButton: _currentIndex == 1
          ? FloatingActionButton.extended(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const WorkerAvailabilityRequestsScreen(),
                  ),
                );
              },
              icon: const Icon(Icons.event_available_outlined),
              label: const Text('Mis solicitudes'),
            )
          : null,

      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        currentIndex: _currentIndex,
        onTap: (i) => setState(() => _currentIndex = i),
        selectedItemColor: const Color(0xFF111827),
        unselectedItemColor: const Color(0xFF9CA3AF),
        showUnselectedLabels: true,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.event_note_outlined),
            activeIcon: Icon(Icons.event_note),
            label: 'Eventos',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.event_available_outlined),
            activeIcon: Icon(Icons.event_available),
            label: 'Disponibilidad',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.notifications_none),
            activeIcon: Icon(Icons.notifications),
            label: 'Notificaciones',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.history),
            label: 'Historial',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.chat_bubble_outline),
            activeIcon: Icon(Icons.chat_bubble),
            label: 'Chat',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person_outline),
            activeIcon: Icon(Icons.person),
            label: 'Perfil',
          ),
        ],
      ),
    );
  }
}
