import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../config/app_config.dart';
import '../../core/services/firestore_service.dart';
import '../../models/evento.dart';
import '../../models/disponibilidad_evento.dart';

class WorkerEventsScreen extends StatefulWidget {
  const WorkerEventsScreen({super.key});

  @override
  State<WorkerEventsScreen> createState() => _WorkerEventsScreenState();
}

class _WorkerEventsScreenState extends State<WorkerEventsScreen> {
  bool _verTodos = false; // Toggle para filtrar eventos

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final empresaId = AppConfig.empresaId;
    if (user == null) return const Scaffold(body: Center(child: Text('Inicia sesión')));

    return Scaffold(
      backgroundColor: const Color(0xFFF3F4F6),
      appBar: AppBar(
        title: const Text('Mis Eventos', style: TextStyle(fontWeight: FontWeight.bold)),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(50),
          child: Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _FilterButton(label: "Próximos", isSelected: !_verTodos, onTap: () => setState(() => _verTodos = false)),
                const SizedBox(width: 12),
                _FilterButton(label: "Todos", isSelected: _verTodos, onTap: () => setState(() => _verTodos = true)),
              ],
            ),
          ),
        ),
      ),
      body: StreamBuilder<List<Evento>>(
        stream: FirestoreService.instance.listenEventos(empresaId),
        builder: (context, eventosSnap) {
          if (!eventosSnap.hasData) return const Center(child: CircularProgressIndicator());

          return StreamBuilder<List<DisponibilidadEvento>>(
            stream: FirestoreService.instance.listenSolicitudesDisponibilidadTrabajador(user.uid),
            builder: (context, dispoSnap) {
              if (!dispoSnap.hasData) return const Center(child: CircularProgressIndicator());

              final solicitudes = dispoSnap.data!;
              final Map<String, DisponibilidadEvento> mapaDispo = {for (var d in solicitudes) d.eventoId: d};

              // FILTRADO Y ORDENACIÓN
              var eventos = eventosSnap.data!.where((e) {
                final d = mapaDispo[e.id];
                if (d == null || !d.asignado) return false;
                if (!_verTodos) return e.fechaInicio.isAfter(DateTime.now()); // Solo futuros
                return true;
              }).toList();

              // Ordenar: Próximos (Ascendente) / Todos (Descendente)
              if (_verTodos) {
                eventos.sort((a, b) => b.fechaInicio.compareTo(a.fechaInicio));
              } else {
                eventos.sort((a, b) => a.fechaInicio.compareTo(b.fechaInicio));
              }

              if (eventos.isEmpty) return Center(child: Text(_verTodos ? 'No hay historial' : 'No tienes eventos próximos'));

              return ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: eventos.length,
                itemBuilder: (context, index) {
                  final e = eventos[index];
                  final d = mapaDispo[e.id]!;
                  final haPasado = e.fechaInicio.isBefore(DateTime.now());

                  return Card(
                    color: haPasado ? Colors.white.withOpacity(0.8) : Colors.white,
                    margin: const EdgeInsets.only(bottom: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    child: ListTile(
                      contentPadding: const EdgeInsets.all(16),
                      title: Text(e.nombre, style: TextStyle(fontWeight: FontWeight.bold, color: haPasado ? Colors.grey : Colors.black)),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 4),
                          Text('${_formatFechaCorta(e.fechaInicio)} · ${_formatHora(e.fechaInicio)}', style: const TextStyle(color: Color(0xFF6366F1))),
                          Text('${e.ciudad} - ${e.direccion}', style: const TextStyle(fontSize: 12)),
                        ],
                      ),
                      trailing: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          if (haPasado) const Text("FINALIZADO", style: TextStyle(fontSize: 9, color: Colors.grey, fontWeight: FontWeight.bold)),
                          _EstadoBadge(asignado: d.asignado),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}

class _FilterButton extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;
  const _FilterButton({required this.label, required this.isSelected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        decoration: BoxDecoration(color: isSelected ? const Color(0xFF6366F1) : Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: const Color(0xFF6366F1))),
        child: Text(label, style: TextStyle(color: isSelected ? Colors.white : const Color(0xFF6366F1), fontWeight: FontWeight.bold, fontSize: 13)),
      ),
    );
  }
}

class _EstadoBadge extends StatelessWidget {
  final bool asignado;
  const _EstadoBadge({required this.asignado});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: const Color(0xFFDBEAFE), borderRadius: BorderRadius.circular(6)),
      child: const Text("ASIGNADO", style: TextStyle(color: Color(0xFF1D4ED8), fontSize: 10, fontWeight: FontWeight.bold)),
    );
  }
}

// Helpers de formato
String _formatFechaCorta(DateTime d) => "${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}";
String _formatHora(DateTime d) => "${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}";