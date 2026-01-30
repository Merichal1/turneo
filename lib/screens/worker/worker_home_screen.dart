import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:turneo/screens/auth/turneo_start_screen.dart';

import '../../config/app_config.dart';
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
  // ====== THEME (Turneo / Login) ======
  static const Color _bg = Color(0xFFF6F8FC);

  int _currentIndex = 0;
  late final List<Widget> _pages;

  @override
  void initState() {
    super.initState();
    _pages = [
      WorkerMainMenuScreen(onNavigateToTab: _setTabFromMenu), // 0
      const WorkerAvailabilityScreen(), // 1
      const WorkerNotificationsScreen(), // 2
      const WorkerHistoryScreen(), // 3
      const WorkerChatScreen(), // 4
      const WorkerProfileScreen(), // 5
    ];
  }

  void _setTabFromMenu(int index) {
    if (_currentIndex == index) return;
    setState(() => _currentIndex = index);
  }

  DocumentReference<Map<String, dynamic>> _workerRef(String uid) {
    return FirebaseFirestore.instance
        .collection('empresas')
        .doc(AppConfig.empresaId)
        .collection('trabajadores')
        .doc(uid);
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
if (user == null) {
  // ⚠️ No hay sesión -> mandamos a Welcome y limpiamos stack
  WidgetsBinding.instance.addPostFrameCallback((_) {
    if (!context.mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const TurneoStartScreen()),
      (route) => false,
    );
  });

  // UI momentánea mientras redirige
  return const Scaffold(
    backgroundColor: _bg,
    body: Center(child: CircularProgressIndicator()),
  );
}


    // 1) Stream A: solicitudes (para badge)
    final solicitudesStream = FirestoreService.instance
        .listenSolicitudesDisponibilidadTrabajador(user.uid);

    // 2) Stream B: doc trabajador (para photoUrl)
    final workerDocStream = _workerRef(user.uid).snapshots();

    return StreamBuilder<List<DisponibilidadEvento>>(
      stream: solicitudesStream,
      builder: (context, snapshotSolicitudes) {
        final solicitudes = snapshotSolicitudes.data ?? [];
        final int pendientes = solicitudes
            .where((s) => s.estado.toLowerCase() == 'pendiente')
            .length;

        return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: workerDocStream,
          builder: (context, snapshotWorker) {
            final data = snapshotWorker.data?.data();
            final photoUrl = (data?['photoUrl'] ?? '').toString().trim();

            return Scaffold(
              backgroundColor: _bg,

              // ✅ Shell fija: no hay transiciones, mantiene estado
              body: IndexedStack(
                index: _currentIndex,
                children: _pages,
              ),

              // ✅ BottomBar premium (pill + sombra + badge + avatar perfil)
              bottomNavigationBar: _TurneoBottomBar(
                currentIndex: _currentIndex,
                onTap: (i) {
                  if (_currentIndex == i) return;
                  setState(() => _currentIndex = i);
                },
                pendientes: pendientes,
                profilePhotoUrl: photoUrl,
              ),
            );
          },
        );
      },
    );
  }
}

/// BottomBar estilo Turneo (parece app “grande”)
class _TurneoBottomBar extends StatelessWidget {
  static const Color _bg = Color(0xFFF6F8FC);
  static const Color _card = Colors.white;
  static const Color _border = Color(0xFFE5E7EB);

  final int currentIndex;
  final ValueChanged<int> onTap;
  final int pendientes;

  // ✅ nuevo: foto perfil (opcional)
  final String profilePhotoUrl;

  const _TurneoBottomBar({
    required this.currentIndex,
    required this.onTap,
    required this.pendientes,
    required this.profilePhotoUrl,
  });

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).padding.bottom;

    // ✅ En móvil queda “floating”
    return SafeArea(
      top: false,
      child: Container(
        color: _bg,
        padding: EdgeInsets.fromLTRB(12, 10, 12, 10 + (bottom > 0 ? 0 : 6)),
        child: Container(
          decoration: BoxDecoration(
            color: _card,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: _border),
            boxShadow: const [
              BoxShadow(
                color: Color(0x14000000),
                blurRadius: 24,
                offset: Offset(0, 10),
              ),
            ],
          ),
          child: Row(
            children: [
              _NavItem(
                label: 'Inicio',
                icon: Icons.home_outlined,
                activeIcon: Icons.home,
                selected: currentIndex == 0,
                onTap: () => onTap(0),
              ),
              _NavItem(
                label: 'Calendario',
                icon: Icons.calendar_month_outlined,
                activeIcon: Icons.calendar_month,
                selected: currentIndex == 1,
                onTap: () => onTap(1),
              ),
              _NavItem(
                label: 'Avisos',
                icon: Icons.notifications_none,
                activeIcon: Icons.notifications,
                selected: currentIndex == 2,
                onTap: () => onTap(2),
                badge: pendientes,
              ),
              _NavItem(
                label: 'Historial',
                icon: Icons.history,
                activeIcon: Icons.history,
                selected: currentIndex == 3,
                onTap: () => onTap(3),
              ),
              _NavItem(
                label: 'Chat',
                icon: Icons.chat_bubble_outline,
                activeIcon: Icons.chat_bubble,
                selected: currentIndex == 4,
                onTap: () => onTap(4),
              ),
              // ✅ Perfil: si hay foto, mostramos avatar en vez del icono
              _NavItem(
                label: 'Perfil',
                icon: Icons.person_outline,
                activeIcon: Icons.person,
                selected: currentIndex == 5,
                onTap: () => onTap(5),
                photoUrl: profilePhotoUrl,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  static const Color _blue = Color(0xFF2563EB);
  static const Color _textGrey = Color(0xFF6B7280);

  final String label;
  final IconData icon;
  final IconData activeIcon;
  final bool selected;
  final VoidCallback onTap;
  final int badge;

  // ✅ nuevo: foto opcional (solo la usamos en Perfil)
  final String? photoUrl;

  const _NavItem({
    required this.label,
    required this.icon,
    required this.activeIcon,
    required this.selected,
    required this.onTap,
    this.badge = 0,
    this.photoUrl,
  });

  @override
  Widget build(BuildContext context) {
    final fg = selected ? _blue : _textGrey;
    final bg = selected ? const Color(0xFFEFF6FF) : Colors.transparent;

    final hasPhoto = (photoUrl ?? '').trim().isNotEmpty;

    return Expanded(
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  // ✅ Si hay foto, usamos CircleAvatar
                  //    si no, icono como siempre.
                  if (hasPhoto)
                    CircleAvatar(
                      radius: 11, // equivalente al tamaño del icono (22)
                      backgroundColor:
                          selected ? const Color(0xFFEFF6FF) : Colors.white,
                      backgroundImage: NetworkImage(photoUrl!.trim()),
                    )
                  else
                    Icon(selected ? activeIcon : icon, color: fg, size: 22),

                  if (badge > 0)
                    Positioned(
                      right: -8,
                      top: -6,
                      child: _Badge(count: badge),
                    ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: selected ? FontWeight.w900 : FontWeight.w700,
                  color: fg,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  final int count;
  const _Badge({required this.count});

  @override
  Widget build(BuildContext context) {
    final text = count > 9 ? '9+' : '$count';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: const Color(0xFFEF4444),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white, width: 1.5),
        boxShadow: const [
          BoxShadow(
            color: Color(0x22000000),
            blurRadius: 8,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 10,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}
