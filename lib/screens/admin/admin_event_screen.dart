import 'package:flutter/material.dart';

class AdminEventScreen extends StatefulWidget {
  const AdminEventScreen({super.key});
  @override
  State<AdminEventScreen> createState() => _AdminEventScreenState();
}

class _AdminEventScreenState extends State<AdminEventScreen> {
  // TODO: stream de eventos desde Firestore
  final _events = <Map<String, dynamic>>[
    {
      'id': 'e1',
      'name': 'Concierto Centro',
      'date': DateTime.now().add(const Duration(days: 2)),
      'location': 'Córdoba',
      'assigned': 3,
      'status': 'activo',
    },
  ];

  void _openEditor({Map<String, dynamic>? event}) {
    showDialog(
      context: context,
      builder: (_) => _EventEditorDialog(
        initial: event,
        onSave: (data) {
          // TODO: create/update en Firestore
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Evento guardado')));
        },
      ),
    );
  }

  void _confirmDelete(String id) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Eliminar evento'),
        content: const Text('¿Seguro que quieres eliminar este evento?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Eliminar')),
        ],
      ),
    );
    if (ok == true) {
      // TODO: eliminar en Firestore
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Evento eliminado')));
    }
  }

  void _askAvailability(String eventId) {
    // TODO: enviar notificación (topic grupo / todos / filtrados) con tiempo de respuesta
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Notificación de disponibilidad enviada')));
  }

  void _autoAssign(String eventId) {
    // TODO: Functions: selección automática por criterios (edad, experiencia, puesto, carnet)
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Asignación automática realizada')));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Eventos')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          FilledButton.icon(
            onPressed: () => _openEditor(),
            icon: const Icon(Icons.add),
            label: const Text('Crear evento'),
          ),
          const SizedBox(height: 12),
          ..._events.map((e) => Card(
                child: ListTile(
                  leading: const Icon(Icons.event),
                  title: Text(e['name']),
                  subtitle: Text(
                      'Fecha: ${e['date']}\nUbicación: ${e['location']}\nAsignados: ${e['assigned']} • Estado: ${e['status']}'),
                  isThreeLine: true,
                  trailing: PopupMenuButton<String>(
                    onSelected: (v) {
                      if (v == 'edit') _openEditor(event: e);
                      if (v == 'delete') _confirmDelete(e['id']);
                      if (v == 'notify') _askAvailability(e['id']);
                      if (v == 'auto') _autoAssign(e['id']);
                    },
                    itemBuilder: (_) => const [
                      PopupMenuItem(value: 'edit', child: Text('Editar')),
                      PopupMenuItem(value: 'delete', child: Text('Eliminar')),
                      PopupMenuItem(value: 'notify', child: Text('Preguntar disponibilidad')),
                      PopupMenuItem(value: 'auto', child: Text('Asignación automática')),
                    ],
                  ),
                ),
              )),
        ],
      ),
    );
  }
}

class _EventEditorDialog extends StatefulWidget {
  final Map<String, dynamic>? initial;
  final void Function(Map<String, dynamic> data) onSave;
  const _EventEditorDialog({this.initial, required this.onSave});

  @override
  State<_EventEditorDialog> createState() => _EventEditorDialogState();
}

class _EventEditorDialogState extends State<_EventEditorDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _locCtrl = TextEditingController();
  DateTime? _date;
  String _type = 'General';

  @override
  void initState() {
    super.initState();
    final i = widget.initial;
    if (i != null) {
      _nameCtrl.text = i['name'] ?? '';
      _locCtrl.text = i['location'] ?? '';
      _date = i['date'] as DateTime?;
      _type = i['type'] ?? 'General';
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _locCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.initial == null ? 'Crear evento' : 'Editar evento'),
      content: SizedBox(
        width: 420,
        child: Form(
          key: _formKey,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            TextFormField(
              controller: _nameCtrl,
              decoration: const InputDecoration(labelText: 'Nombre del evento'),
              validator: (v) => (v == null || v.isEmpty) ? 'Requerido' : null,
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _locCtrl,
              decoration: const InputDecoration(labelText: 'Ubicación'),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      final now = DateTime.now();
                      final d = await showDatePicker(
                        context: context,
                        firstDate: now,
                        lastDate: DateTime(now.year + 2),
                        initialDate: _date ?? now.add(const Duration(days: 1)),
                      );
                      if (d != null) {
                        final t = await showTimePicker(
                          context: context,
                          initialTime: TimeOfDay.fromDateTime(_date ?? now),
                        );
                        if (t != null) {
                          setState(() {
                            _date = DateTime(d.year, d.month, d.day, t.hour, t.minute);
                          });
                        }
                      }
                    },
                    icon: const Icon(Icons.schedule),
                    label: Text(_date == null ? 'Fecha y hora' : _date.toString()),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              value: _type,
              items: const [
                DropdownMenuItem(value: 'General', child: Text('General')),
                DropdownMenuItem(value: 'Concierto', child: Text('Concierto')),
                DropdownMenuItem(value: 'Congreso', child: Text('Congreso')),
              ],
              onChanged: (v) => setState(() => _type = v ?? 'General'),
              decoration: const InputDecoration(labelText: 'Tipo'),
            ),
          ]),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
        FilledButton(
          onPressed: () {
            if (!_formKey.currentState!.validate() || _date == null) return;
            widget.onSave({
              'name': _nameCtrl.text.trim(),
              'location': _locCtrl.text.trim(),
              'date': _date,
              'type': _type,
              'status': 'activo',
            });
          },
          child: const Text('Guardar'),
        ),
      ],
    );
  }
}
