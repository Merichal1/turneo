import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../../config/app_config.dart';

class AdminNotificacionesScreen extends StatefulWidget {
  const AdminNotificacionesScreen({super.key});

  @override
  State<AdminNotificacionesScreen> createState() => _AdminNotificacionesScreenState();
}

class _AdminNotificacionesScreenState extends State<AdminNotificacionesScreen> {
  // 🎨 Turneo style (como login)
  static const Color _bg = Color(0xFFF6F8FC);
  static const Color _card = Colors.white;
  static const Color _border = Color(0xFFE5E7EB);
  static const Color _textDark = Color(0xFF111827);
  static const Color _textGrey = Color(0xFF6B7280);
  static const Color _blue = Color(0xFF2563EB);

  final String _empresaId = AppConfig.empresaId;

  String _filtro = 'Todas';
  final List<String> _chips = const ['Todas', 'Sistema', 'Usuarios', 'Eventos'];

  @override
  Widget build(BuildContext context) {
    final notifsQuery = FirebaseFirestore.instance
        .collection('empresas')
        .doc(_empresaId)
        .collection('notificaciones')
        .orderBy('creadoEn', descending: true);

    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _bg,
        elevation: 0,
        surfaceTintColor: _bg,
        title: const Text(
          'Notificaciones',
          style: TextStyle(
            color: _textDark,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: _blue,
        foregroundColor: Colors.white,
        onPressed: _abrirCrearNotificacion,
        icon: const Icon(Icons.add),
        label: const Text(
          'Nueva notificación',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
            child: _FiltersCard(
              chips: _chips,
              selected: _filtro,
              onSelected: (v) => setState(() => _filtro = v),
            ),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: notifsQuery.snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final docs = snapshot.data!.docs;
                final items = docs.map((doc) => _Notif.fromFirestore(doc)).toList();

                final filtrados = _filtro == 'Todas'
                    ? items
                    : items.where((n) => n.tag == _filtro).toList();

                if (filtrados.isEmpty) {
                  return const Center(
                    child: Text(
                      "No hay notificaciones",
                      style: TextStyle(color: _textGrey, fontWeight: FontWeight.w600),
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
                  itemCount: filtrados.length,
                  itemBuilder: (context, index) => _NotifCard(n: filtrados[index]),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _abrirCrearNotificacion() async {
    final tituloCtrl = TextEditingController();
    final bodyCtrl = TextEditingController();

    // ✅ CAMBIO PEDIDO: enviar por ROLES (no por lista de trabajadores)
    // Guardamos en Firestore: "todos" o "rol:camarero" etc.
    String dirigidoA = "todos";
    String tag = 'Sistema';

    // Roles (puedes añadir/quitar sin tocar funcionalidad)
    const roles = [
      'camarero',
      'cocinero',
      'metre',
      'limpiador',
      'logistica',
      'coordinador',
    ];

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom + 16,
            left: 16,
            right: 16,
            top: 16,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header
                Row(
                  children: [
                    const Text(
                      'Enviar Notificación',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
                    ),
                    const Spacer(),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                // Card destino + tag
                Container(
                  padding: const EdgeInsets.all(14),
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
                  child: Column(
                    children: [
                      DropdownButtonFormField<String>(
                        value: dirigidoA,
                        decoration: InputDecoration(
                          labelText: "Enviar a...",
                          filled: true,
                          fillColor: const Color(0xFFF9FAFB),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: _border),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: _blue, width: 2),
                          ),
                        ),
                        items: [
                          const DropdownMenuItem(
                            value: "todos",
                            child: Text("Todos los trabajadores"),
                          ),
                          const DropdownMenuItem(
                            value: "rol:*",
                            child: Text("— Por rol —"),
                          ),
                          ...roles.map(
                            (r) => DropdownMenuItem(
                              value: "rol:$r",
                              child: Text(r[0].toUpperCase() + r.substring(1)),
                            ),
                          ),
                        ],
                        onChanged: (val) {
                          if (val == null) return;
                          // Evita dejar seleccionado el separador "rol:*"
                          if (val == "rol:*") return;
                          setModalState(() => dirigidoA = val);
                        },
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        value: tag,
                        decoration: InputDecoration(
                          labelText: "Categoría (tag)",
                          filled: true,
                          fillColor: const Color(0xFFF9FAFB),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: _border),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: _blue, width: 2),
                          ),
                        ),
                        items: const [
                          DropdownMenuItem(value: 'Sistema', child: Text('Sistema')),
                          DropdownMenuItem(value: 'Usuarios', child: Text('Usuarios')),
                          DropdownMenuItem(value: 'Eventos', child: Text('Eventos')),
                        ],
                        onChanged: (v) {
                          if (v == null) return;
                          setModalState(() => tag = v);
                        },
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 12),

                // Campos texto
                TextField(
                  controller: tituloCtrl,
                  decoration: InputDecoration(
                    labelText: 'Título',
                    filled: true,
                    fillColor: const Color(0xFFF9FAFB),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: _border),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: _blue, width: 2),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: bodyCtrl,
                  maxLines: 3,
                  decoration: InputDecoration(
                    labelText: 'Mensaje',
                    filled: true,
                    fillColor: const Color(0xFFF9FAFB),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: _border),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: _blue, width: 2),
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _blue,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: () async {
                      if (tituloCtrl.text.trim().isEmpty || bodyCtrl.text.trim().isEmpty) return;

                      await FirebaseFirestore.instance
                          .collection('empresas')
                          .doc(_empresaId)
                          .collection('notificaciones')
                          .add({
                        'titulo': tituloCtrl.text.trim(),
                        'body': bodyCtrl.text.trim(),
                        'tag': tag,
                        'dirigidoA': dirigidoA, // ✅ ahora "todos" o "rol:camarero"
                        'creadoEn': FieldValue.serverTimestamp(),
                      });

                      if (context.mounted) Navigator.pop(context);
                    },
                    icon: const Icon(Icons.send),
                    label: const Text(
                      "ENVIAR AHORA",
                      style: TextStyle(fontWeight: FontWeight.w900),
                    ),
                  ),
                ),

                const SizedBox(height: 18),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ==========================
// UI Widgets
// ==========================

class _FiltersCard extends StatelessWidget {
  static const Color _border = Color(0xFFE5E7EB);
  static const Color _textDark = Color(0xFF111827);
  static const Color _blue = Color(0xFF2563EB);

  final List<String> chips;
  final String selected;
  final ValueChanged<String> onSelected;

  const _FiltersCard({
    required this.chips,
    required this.selected,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
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
          const Text(
            'Filtrar',
            style: TextStyle(color: _textDark, fontWeight: FontWeight.w900),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Wrap(
                spacing: 10,
                children: chips.map((chip) {
                  final isSelected = selected == chip;
                  return InkWell(
                    borderRadius: BorderRadius.circular(999),
                    onTap: () => onSelected(chip),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: isSelected ? _blue : Colors.white,
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(color: isSelected ? Colors.transparent : _border),
                      ),
                      child: Text(
                        chip,
                        style: TextStyle(
                          color: isSelected ? Colors.white : _textDark,
                          fontWeight: FontWeight.w900,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _NotifCard extends StatelessWidget {
  static const Color _border = Color(0xFFE5E7EB);
  static const Color _textDark = Color(0xFF111827);
  static const Color _textGrey = Color(0xFF6B7280);
  static const Color _blue = Color(0xFF2563EB);

  final _Notif n;
  const _NotifCard({required this.n});

  IconData _iconForTag(String tag) {
    switch (tag) {
      case 'Eventos':
        return Icons.event_outlined;
      case 'Usuarios':
        return Icons.group_outlined;
      case 'Sistema':
      default:
        return Icons.notifications_outlined;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: _border),
        boxShadow: const [
          BoxShadow(
            color: Color(0x14000000),
            blurRadius: 24,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              backgroundColor: const Color(0xFFEFF6FF),
              child: Icon(_iconForTag(n.tag), color: _blue),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    n.title,
                    style: const TextStyle(
                      fontWeight: FontWeight.w900,
                      color: _textDark,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    n.body,
                    style: const TextStyle(
                      color: Color(0xFF374151),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      _TagPill(text: n.tag),
                      const SizedBox(width: 8),
                      if (n.dirigidoA.isNotEmpty) _ToPill(text: n.dirigidoA),
                    ],
                  )
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TagPill extends StatelessWidget {
  static const Color _blue = Color(0xFF2563EB);

  final String text;
  const _TagPill({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFEFF6FF),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: _blue,
          fontWeight: FontWeight.w900,
          fontSize: 11,
        ),
      ),
    );
  }
}

class _ToPill extends StatelessWidget {
  final String text;
  const _ToPill({required this.text});

  String _pretty(String raw) {
    if (raw == 'todos') return 'Para: Todos';
    if (raw.startsWith('rol:')) {
      final r = raw.replaceFirst('rol:', '');
      if (r.isEmpty) return 'Para: Rol';
      return 'Para: ${r[0].toUpperCase()}${r.substring(1)}';
    }
    return 'Para: $raw';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFF3F4F6),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        _pretty(text),
        style: const TextStyle(
          color: Color(0xFF374151),
          fontWeight: FontWeight.w900,
          fontSize: 11,
        ),
      ),
    );
  }
}

// ==========================
// Model
// ==========================

class _Notif {
  final String id, title, body, tag, dirigidoA;

  _Notif({
    required this.id,
    required this.title,
    required this.body,
    required this.tag,
    required this.dirigidoA,
  });

  factory _Notif.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return _Notif(
      id: doc.id,
      title: (data['titulo'] ?? '').toString(),
      body: (data['body'] ?? '').toString(),
      tag: (data['tag'] ?? 'Sistema').toString(),
      dirigidoA: (data['dirigidoA'] ?? '').toString(),
    );
  }
}
