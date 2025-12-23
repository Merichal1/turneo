import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../config/app_config.dart';
import '../../core/services/firestore_service.dart';
import '../../models/disponibilidad_evento.dart';

class WorkerNotificationsScreen extends StatelessWidget {
  const WorkerNotificationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    const empresaId = AppConfig.empresaId;
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return const Scaffold(
        body: Center(child: Text('Inicia sesión para ver tus avisos.')),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF3F4F6),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        title: const Text(
          'Avisos y Solicitudes',
          style: TextStyle(color: Color(0xFF111827), fontWeight: FontWeight.bold),
        ),
      ),
      body: StreamBuilder<List<DisponibilidadEvento>>(
        // Stream 1: Solicitudes técnicas de eventos
        stream: FirestoreService.instance.listenSolicitudesDisponibilidadTrabajador(user.uid),
        builder: (context, dispoSnap) {
          // Stream 2: Notificaciones generales enviadas por el Admin
          return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: FirebaseFirestore.instance
                .collection('empresas')
                .doc(empresaId)
                .collection('notificaciones')
                .where('dirigidoA', whereIn: ['todos', user.uid]) // Filtro funcional
                .orderBy('creadoEn', descending: true)
                .snapshots(),
            builder: (context, notifSnap) {
              if (dispoSnap.connectionState == ConnectionState.waiting ||
                  notifSnap.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              final solicitudes = dispoSnap.data ?? [];
              final notifDocs = notifSnap.data?.docs ?? [];

              if (solicitudes.isEmpty && notifDocs.isEmpty) {
                return const Center(
                  child: Text('No tienes notificaciones por ahora.',
                      style: TextStyle(color: Color(0xFF6B7280))),
                );
              }

              return ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // --- SECCIÓN 1: SOLICITUDES DE TRABAJO (Prioridad) ---
                  if (solicitudes.isNotEmpty) ...[
                    const _SectionHeader(title: 'Solicitudes de Eventos'),
                    ...solicitudes.map((s) => _SolicitudCard(
                          solicitud: s,
                          empresaId: empresaId,
                        )),
                    const SizedBox(height: 20),
                  ],

                  // --- SECCIÓN 2: COMUNICADOS GENERALES ---
                  if (notifDocs.isNotEmpty) ...[
                    const _SectionHeader(title: 'Comunicados'),
                    ...notifDocs.map((doc) => _GeneralNotifCard(doc: doc)),
                  ],
                  const SizedBox(height: 80), // Espacio para el menú inferior
                ],
              );
            },
          );
        },
      ),
    );
  }
}

// --- WIDGET: CABECERA DE SECCIÓN ---
class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12, left: 4),
      child: Text(title,
          style: const TextStyle(
              fontSize: 14, fontWeight: FontWeight.bold, color: Colors.grey)),
    );
  }
}

// --- CARD: SOLICITUD DE DISPONIBILIDAD ---
class _SolicitudCard extends StatelessWidget {
  final DisponibilidadEvento solicitud;
  final String empresaId;

  const _SolicitudCard({required this.solicitud, required this.empresaId});

  @override
  Widget build(BuildContext context) {
    final s = solicitud;
    final bool esPendiente = s.estado == 'pendiente';

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.event_note, color: Color(0xFF6366F1)),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text('Solicitud de Evento',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                ),
                _EstadoBadge(estado: s.estado),
              ],
            ),
            const SizedBox(height: 10),
            Text('Se requiere tu disponibilidad como: ${s.trabajadorRol}',
                style: const TextStyle(color: Color(0xFF4B5563))),
            const SizedBox(height: 15),
            if (esPendiente)
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => _responder(context, 'rechazado'),
                      style: OutlinedButton.styleFrom(foregroundColor: Colors.red),
                      child: const Text('Rechazar'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => _responder(context, 'aceptado'),
                      style: ElevatedButton.styleFrom(backgroundColor: const Color.fromARGB(255, 235, 235, 240)),
                      child: const Text('Aceptar'),
                    ),
                  ),
                ],
              )
            else
              Text(
                s.estado == 'aceptado' 
                  ? 'Has marcado que estás disponible.' 
                  : 'Has marcado que no estás disponible.',
                style: TextStyle(
                  fontStyle: FontStyle.italic,
                  color: s.estado == 'aceptado' ? Colors.green : Colors.red,
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _responder(BuildContext context, String nuevoEstado) async {
    try {
      await FirestoreService.instance.actualizarEstadoDisponibilidad(
        empresaId: empresaId,
        eventoId: solicitud.eventoId,
        disponibilidadId: solicitud.id,
        nuevoEstado: nuevoEstado,
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }
}

// --- CARD: NOTIFICACIÓN GENERAL ---
class _GeneralNotifCard extends StatelessWidget {
  final QueryDocumentSnapshot<Map<String, dynamic>> doc;
  const _GeneralNotifCard({required this.doc});

  @override
  Widget build(BuildContext context) {
    final data = doc.data();
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        leading: const CircleAvatar(
          backgroundColor: Color(0xFFE0E7FF),
          child: Icon(Icons.notifications, color: Color.fromARGB(255, 103, 96, 172), size: 20),
        ),
        title: Text(data['titulo'] ?? 'Aviso',
            style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(data['body'] ?? ''),
        trailing: Text(data['tag'] ?? '',
            style: const TextStyle(fontSize: 10, color: Colors.grey)),
      ),
    );
  }
}

// --- WIDGET: BADGE DE ESTADO ---
class _EstadoBadge extends StatelessWidget {
  final String estado;
  const _EstadoBadge({required this.estado});

  @override
  Widget build(BuildContext context) {
    Color color = Colors.orange;
    String texto = 'Pendiente';
    if (estado == 'aceptado') { color = Colors.green; texto = 'Disponible'; }
    if (estado == 'rechazado') { color = Colors.red; texto = 'No disponible'; }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
      child: Text(texto, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold)),
    );
  }
}