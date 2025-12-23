import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../../config/app_config.dart';
import '../../core/services/firestore_service.dart';
import '../../models/trabajador.dart';

class AdminNotificacionesScreen extends StatefulWidget {
  const AdminNotificacionesScreen({super.key});

  @override
  State<AdminNotificacionesScreen> createState() => _AdminNotificacionesScreenState();
}

class _AdminNotificacionesScreenState extends State<AdminNotificacionesScreen> {
  final String _empresaId = AppConfig.empresaId;
  String _filtro = 'Todas';
  final List<String> _chips = const ['Todas', 'Sistema', 'Usuarios', 'Eventos'];

  @override
  Widget build(BuildContext context) {
    // Referencia corregida a la colección
    final notifsQuery = FirebaseFirestore.instance
        .collection('empresas')
        .doc(_empresaId)
        .collection('notificaciones')
        .orderBy('creadoEn', descending: true);

    return Scaffold(
      backgroundColor: const Color(0xFFF3F4F6),
      appBar: AppBar(
        title: const Text('Notificaciones (Admin)', style: TextStyle(fontWeight: FontWeight.w600)),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _abrirCrearNotificacion,
        icon: const Icon(Icons.add),
        label: const Text('Nueva notificación'),
      ),
      body: Column(
        children: [
          _buildFilters(),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: notifsQuery.snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                
                final docs = snapshot.data!.docs;
                final items = docs.map((doc) => _Notif.fromFirestore(doc)).toList();
                final filtrados = _filtro == 'Todas' ? items : items.where((n) => n.tag == _filtro).toList();

                if (filtrados.isEmpty) return const Center(child: Text("No hay notificaciones"));

                return ListView.builder(
                  itemCount: filtrados.length,
                  itemBuilder: (context, index) => _buildNotifCard(filtrados[index]),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilters() {
    return SizedBox(
      height: 60,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        children: _chips.map((chip) => Padding(
          padding: const EdgeInsets.only(right: 8),
          child: ChoiceChip(
            label: Text(chip),
            selected: _filtro == chip,
            onSelected: (val) => setState(() => _filtro = chip),
          ),
        )).toList(),
      ),
    );
  }

  Widget _buildNotifCard(_Notif n) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: ListTile(
        leading: const CircleAvatar(backgroundColor: Color(0xFF4F46E5), child: Icon(Icons.notifications, color: Colors.white, size: 20)),
        title: Text(n.title, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(n.body),
        trailing: Text(n.tag, style: const TextStyle(fontSize: 10, color: Colors.grey)),
      ),
    );
  }

  Future<void> _abrirCrearNotificacion() async {
    final tituloCtrl = TextEditingController();
    final bodyCtrl = TextEditingController();
    String? trabajadorSeleccionado = "todos"; // ID del trabajador o "todos"
    String tag = 'Sistema';

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom, left: 16, right: 16, top: 16),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Enviar Notificación', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),
                StreamBuilder<List<Trabajador>>(
                  stream: FirestoreService.instance.listenTrabajadores(_empresaId),
                  builder: (context, snap) {
                    final trabajadores = snap.data ?? [];
                    return DropdownButtonFormField<String>(
                      value: trabajadorSeleccionado,
                      decoration: const InputDecoration(labelText: "Enviar a...", border: OutlineInputBorder()),
                      items: [
                        const DropdownMenuItem(value: "todos", child: Text("Todos los trabajadores")),
                        ...trabajadores.map((t) => DropdownMenuItem(value: t.id, child: Text(t.nombre)))
                      ],
                      onChanged: (val) => setModalState(() => trabajadorSeleccionado = val),
                    );
                  },
                ),
                const SizedBox(height: 12),
                TextField(controller: tituloCtrl, decoration: const InputDecoration(labelText: 'Título', border: OutlineInputBorder())),
                const SizedBox(height: 12),
                TextField(controller: bodyCtrl, maxLines: 3, decoration: const InputDecoration(labelText: 'Mensaje', border: OutlineInputBorder())),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () async {
                    if (tituloCtrl.text.isEmpty || bodyCtrl.text.isEmpty) return;
                    await FirebaseFirestore.instance.collection('empresas').doc(_empresaId).collection('notificaciones').add({
                      'titulo': tituloCtrl.text,
                      'body': bodyCtrl.text,
                      'tag': tag,
                      'dirigidoA': trabajadorSeleccionado,
                      'creadoEn': FieldValue.serverTimestamp(),
                    });
                    Navigator.pop(context);
                  },
                  child: const Text("ENVIAR AHORA"),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Notif {
  final String id, title, body, tag;
  _Notif({required this.id, required this.title, required this.body, required this.tag});
  factory _Notif.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return _Notif(id: doc.id, title: data['titulo'] ?? '', body: data['body'] ?? '', tag: data['tag'] ?? 'Sistema');
  }
}