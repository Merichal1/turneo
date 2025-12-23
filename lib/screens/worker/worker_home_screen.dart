import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../core/services/firestore_service.dart';
import '../../models/disponibilidad_evento.dart';

import 'worker_main_menu_screen.dart';
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
    _pages = [
      WorkerMainMenuScreen(onNavigateToTab: _setTabFromMenu), // 0
      const WorkerAvailabilityScreen(), // 1 ✅ (antes era 2)
      const WorkerNotificationsScreen(), // 2
      const WorkerHistoryScreen(), // 3
      const WorkerChatScreen(), // 4
      const WorkerProfileScreen(), // 5
    ];
  }

  void _setTabFromMenu(int index) {
    setState(() => _currentIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const Scaffold(body: Center(child: Text('Sesión no válida')));
    }

    return StreamBuilder<List<DisponibilidadEvento>>(
      stream: FirestoreService.instance
          .listenSolicitudesDisponibilidadTrabajador(user.uid),
      builder: (context, snapshot) {
        final solicitudes = snapshot.data ?? [];
        final int pendientes = solicitudes
            .where((s) => s.estado.toLowerCase() == 'pendiente')
            .length;

        return Scaffold(
          body: IndexedStack(
            index: _currentIndex,
            children: _pages,
          ),
          bottomNavigationBar: BottomNavigationBar(
            type: BottomNavigationBarType.fixed,
            currentIndex: _currentIndex,
            onTap: (i) => setState(() => _currentIndex = i),
            selectedItemColor: const Color(0xFF6366F1),
            unselectedItemColor: const Color(0xFF9CA3AF),
            items: [
              const BottomNavigationBarItem(
                icon: Icon(Icons.home_outlined),
                activeIcon: Icon(Icons.home),
                label: 'Inicio',
              ),
              const BottomNavigationBarItem(
                icon: Icon(Icons.calendar_month_outlined),
                activeIcon: Icon(Icons.calendar_month),
                label: 'Calendario',
              ),
              BottomNavigationBarItem(
                icon: _NotificationIcon(
                  unread: pendientes,
                  selected: _currentIndex == 2,
                ),
                label: 'Avisos',
              ),
              const BottomNavigationBarItem(
                icon: Icon(Icons.history),
                label: 'Historial',
              ),
              const BottomNavigationBarItem(
                icon: Icon(Icons.chat_bubble_outline),
                label: 'Chat',
              ),
              const BottomNavigationBarItem(
                icon: Icon(Icons.person_outline),
                label: 'Perfil',
              ),
            ],
          ),
        );
      },
    );
  }
}

class _NotificationIcon extends StatelessWidget {
  final int unread;
  final bool selected;
  const _NotificationIcon({required this.unread, required this.selected});

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Icon(selected ? Icons.notifications : Icons.notifications_none),
        if (unread > 0)
          Positioned(
            right: -4,
            top: -2,
            child: Container(
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                color: Colors.red,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.white, width: 1.5),
              ),
              constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
              child: Center(
                child: Text(
                  unread > 9 ? '9+' : '$unread',
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
