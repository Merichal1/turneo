import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class AdminDatabaseScreen extends StatefulWidget {
  const AdminDatabaseScreen({super.key});

  @override
  State<AdminDatabaseScreen> createState() => _AdminDatabaseScreenState();
}

class _AdminDatabaseScreenState extends State<AdminDatabaseScreen> {
  final _pathCtrl = TextEditingController(text: 'users'); // colección inicial
  final _searchCtrl = TextEditingController();
  final _favorites = <String>['users', 'events', 'payments', 'notifications'];
  String _selectedPath = 'users';
  int _limit = 100;

  @override
  void initState() {
    super.initState();
    _selectedPath = _pathCtrl.text.trim();
  }

  @override
  void dispose() {
    _pathCtrl.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  bool get _isCollectionPath {
    // Un path con número impar de segmentos es colección (p.ej. "users" o "events/123/shifts")
    final segs = _selectedPath.split('/').where((s) => s.isNotEmpty).toList();
    return segs.isNotEmpty && segs.length.isOdd;
  }

  CollectionReference<Map<String, dynamic>> _collectionRef() {
    return FirebaseFirestore.instance.collection(_selectedPath);
  }

  Future<void> _createDoc() async {
    if (!_isCollectionPath) {
      _snack('Indica una colección (no un documento) para crear un documento nuevo.');
      return;
    }
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => _DocEditorDialog(
        title: 'Crear documento en $_selectedPath',
        initialData: {},
      ),
    );
    if (result != null) {
      await _collectionRef().add(result);
      _snack('Documento creado.');
    }
  }

  Future<void> _editDoc(String docId, Map<String, dynamic> data) async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => _DocEditorDialog(
        title: 'Editar $docId',
        initialData: data,
      ),
    );
    if (result != null) {
      await _collectionRef().doc(docId).set(result, SetOptions(merge: false));
      _snack('Documento guardado.');
    }
  }

  Future<void> _deleteDoc(String docId) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Eliminar documento'),
        content: Text('¿Eliminar "$docId" en "$_selectedPath"? Esta acción no se puede deshacer.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Eliminar')),
        ],
      ),
    );
    if (ok == true) {
      await _collectionRef().doc(docId).delete();
      _snack('Documento eliminado.');
    }
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  void _openPath(String path) {
    setState(() {
      _selectedPath = path.trim();
      _pathCtrl.text = _selectedPath;
    });
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      body: Row(
        children: [
          // Sidebar: favoritos y navegación rápida
          Container(
            width: 260,
            margin: const EdgeInsets.fromLTRB(16, 16, 8, 16),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: cs.outline.withOpacity(0.08)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Colección / Ruta', style: TextStyle(fontWeight: FontWeight.w800)),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _pathCtrl,
                        decoration: const InputDecoration(
                          hintText: 'p. ej. users o events/ABC/shifts',
                          prefixIcon: Icon(Icons.folder_outlined),
                        ),
                        onSubmitted: (_) => _openPath(_pathCtrl.text),
                      ),
                    ),
                    const SizedBox(width: 8),
                    FilledButton(
                      onPressed: () => _openPath(_pathCtrl.text),
                      child: const Text('Abrir'),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    const Text('Favoritos', style: TextStyle(fontWeight: FontWeight.w800)),
                    const Spacer(),
                    IconButton(
                      tooltip: 'Añadir favorito',
                      onPressed: () async {
                        final p = _pathCtrl.text.trim();
                        if (p.isEmpty) return;
                        if (!_favorites.contains(p)) {
                          setState(() => _favorites.add(p));
                        }
                      },
                      icon: const Icon(Icons.star_border),
                    )
                  ],
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: ListView.separated(
                    itemCount: _favorites.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (_, i) {
                      final p = _favorites[i];
                      final sel = p == _selectedPath;
                      return ListTile(
                        dense: true,
                        leading: Icon(sel ? Icons.folder : Icons.folder_open_outlined),
                        title: Text(p, maxLines: 1, overflow: TextOverflow.ellipsis),
                        trailing: IconButton(
                          tooltip: 'Quitar',
                          onPressed: () => setState(() => _favorites.removeAt(i)),
                          icon: const Icon(Icons.close, size: 18),
                        ),
                        selected: sel,
                        onTap: () => _openPath(p),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Text('Límite'),
                    const SizedBox(width: 8),
                    DropdownButton<int>(
                      value: _limit,
                      onChanged: (v) => setState(() => _limit = v ?? 100),
                      items: const [50, 100, 200, 500]
                          .map((e) => DropdownMenuItem(value: e, child: Text('$e')))
                          .toList(),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Panel de colección / documentos
          Expanded(
            child: Column(
              children: [
                // Barra de acciones
                Container(
                  margin: const EdgeInsets.fromLTRB(8, 16, 16, 8),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Theme.of(context).cardColor,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: cs.outline.withOpacity(0.08)),
                  ),
                  child: Row(
                    children: [
                      Icon(_isCollectionPath ? Icons.folder_outlined : Icons.description_outlined, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _selectedPath.isEmpty ? '(sin ruta)' : _selectedPath,
                          style: const TextStyle(fontWeight: FontWeight.w800),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 12),
                      SizedBox(
                        width: 260,
                        child: TextField(
                          controller: _searchCtrl,
                          decoration: const InputDecoration(
                            hintText: 'Buscar por ID…',
                            prefixIcon: Icon(Icons.search),
                          ),
                          onChanged: (_) => setState(() {}),
                        ),
                      ),
                      const SizedBox(width: 12),
                      FilledButton.icon(
                        onPressed: _isCollectionPath ? _createDoc : null,
                        icon: const Icon(Icons.add),
                        label: const Text('Nuevo doc'),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 4),

                // Contenido (stream de documentos)
                Expanded(
                  child: _isCollectionPath
                      ? StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                          stream: FirebaseFirestore.instance
                              .collection(_selectedPath)
                              .limit(_limit)
                              .snapshots(),
                          builder: (context, snap) {
                            if (snap.connectionState == ConnectionState.waiting) {
                              return const Center(child: CircularProgressIndicator());
                            }
                            if (snap.hasError) {
                              return Center(child: Text('Error: ${snap.error}'));
                            }
                            final docs = snap.data?.docs ?? [];
                            final filtered = docs.where((d) {
                              final q = _searchCtrl.text.trim();
                              if (q.isEmpty) return true;
                              return d.id.toLowerCase().contains(q.toLowerCase());
                            }).toList();

                            if (filtered.isEmpty) {
                              return const Center(child: Text('No hay documentos.'));
                            }

                            return ListView.separated(
                              padding: const EdgeInsets.fromLTRB(8, 8, 16, 16),
                              itemCount: filtered.length,
                              separatorBuilder: (_, __) => const SizedBox(height: 10),
                              itemBuilder: (_, i) {
                                final d = filtered[i];
                                final data = d.data();
                                return _DocCard(
                                  docId: d.id,
                                  data: data,
                                  onEdit: () => _editDoc(d.id, data),
                                  onDelete: () => _deleteDoc(d.id),
                                  onOpenSub: (subPath) => _openPath('$_selectedPath/${d.id}/$subPath'),
                                );
                              },
                            );
                          },
                        )
                      : Center(
                          child: Text(
                            'La ruta seleccionada no es una colección.\nEjemplo de colección: "users" o "events/ABC/shifts".',
                            textAlign: TextAlign.center,
                          ),
                        ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DocCard extends StatelessWidget {
  final String docId;
  final Map<String, dynamic> data;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final void Function(String subPath) onOpenSub;

  const _DocCard({
    required this.docId,
    required this.data,
    required this.onEdit,
    required this.onDelete,
    required this.onOpenSub,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // encabezado
            Row(
              children: [
                const Icon(Icons.description_outlined, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    docId,
                    style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                OutlinedButton.icon(onPressed: onEdit, icon: const Icon(Icons.edit_outlined), label: const Text('Editar')),
                const SizedBox(width: 8),
                IconButton(
                  tooltip: 'Eliminar',
                  onPressed: onDelete,
                  style: ButtonStyle(
                    foregroundColor: MaterialStateProperty.all(cs.error),
                  ),
                  icon: const Icon(Icons.delete_outline),
                ),
              ],
            ),
            const SizedBox(height: 10),

            // contenido
            SelectableText(_pretty(data), style: const TextStyle(fontFamily: 'monospace', height: 1.3)),

            // subcolecciones rápidas
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _SubcollectionChip(
                  label: 'Abrir subcolección…',
                  onOpen: (sub) {
                    if (sub.trim().isEmpty) return;
                    onOpenSub(sub.trim());
                  },
                )
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _pretty(Map<String, dynamic> map, [int indent = 0]) {
    final buf = StringBuffer();
    final spaces = '  ' * indent;
    buf.writeln('{');
    map.forEach((k, v) {
      buf.write('${'  ' * (indent + 1)}$k: ');
      if (v is Map<String, dynamic>) {
        buf.write(_pretty(v, indent + 1));
      } else if (v is List) {
        buf.writeln('[');
        for (final item in v) {
          buf.write('${'  ' * (indent + 2)}$item,\n');
        }
        buf.write('${'  ' * (indent + 1)}]\n');
      } else {
        buf.writeln(v);
      }
    });
    buf.write('$spaces}\n');
    return buf.toString();
  }
}

class _SubcollectionChip extends StatefulWidget {
  final String label;
  final void Function(String path) onOpen;
  const _SubcollectionChip({required this.label, required this.onOpen});
  @override
  State<_SubcollectionChip> createState() => _SubcollectionChipState();
}

class _SubcollectionChipState extends State<_SubcollectionChip> {
  final _ctrl = TextEditingController();
  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 220,
          child: TextField(
            controller: _ctrl,
            decoration: const InputDecoration(
              hintText: 'subcollection (p.ej. shifts)',
              prefixIcon: Icon(Icons.subdirectory_arrow_right),
            ),
          ),
        ),
        const SizedBox(width: 8),
        OutlinedButton(
          onPressed: () => widget.onOpen(_ctrl.text),
          child: const Text('Abrir'),
        ),
      ],
    );
  }
}

class _DocEditorDialog extends StatefulWidget {
  final String title;
  final Map<String, dynamic> initialData;

  const _DocEditorDialog({
    required this.title,
    required this.initialData,
  });

  @override
  State<_DocEditorDialog> createState() => _DocEditorDialogState();
}

class _DocEditorDialogState extends State<_DocEditorDialog> {
  late List<_FieldRow> _rows;

  @override
  void initState() {
    super.initState();
    _rows = widget.initialData.entries
        .map((e) => _FieldRow(name: e.key, value: e.value))
        .toList();
  }

  void _addRow() {
    setState(() => _rows.add(_FieldRow(name: '', value: '')));
  }

  void _save() {
    final map = <String, dynamic>{};
    for (final r in _rows) {
      if (r.name.trim().isEmpty) continue;
      map[r.name.trim()] = r.parsedValue;
    }
    Navigator.pop(context, map);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: SizedBox(
        width: 520,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (int i = 0; i < _rows.length; i++)
              _FieldEditor(
                key: ValueKey('row_$i'),
                row: _rows[i],
                onDelete: () => setState(() => _rows.removeAt(i)),
              ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: OutlinedButton.icon(
                onPressed: _addRow,
                icon: const Icon(Icons.add),
                label: const Text('Añadir campo'),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
        FilledButton(onPressed: _save, child: const Text('Guardar')),
      ],
    );
  }
}

class _FieldRow {
  String name;
  String type; // 'string' | 'number' | 'bool' | 'timestamp' | 'map' | 'list'
  String stringVal;
  String numberVal;
  bool boolVal;
  DateTime? tsVal;
  String mapJson;
  String listJson;

  _FieldRow({
    required this.name,
    required dynamic value,
  })  : type = _guessType(value),
        stringVal = value?.toString() ?? '',
        numberVal = (value is num) ? value.toString() : '',
        boolVal = (value is bool) ? value : false,
        tsVal = (value is Timestamp) ? value.toDate() : null,
        mapJson = (value is Map<String, dynamic>) ? value.toString() : '{}',
        listJson = (value is List) ? value.toString() : '[]';

  dynamic get parsedValue {
    switch (type) {
      case 'string':
        return stringVal;
      case 'number':
        final n = num.tryParse(numberVal);
        return n ?? 0;
      case 'bool':
        return boolVal;
      case 'timestamp':
        return tsVal != null ? Timestamp.fromDate(tsVal!) : null;
      case 'map':
        // Simplificado: intenta decodificar con formato {k: v}. Para robustez, usa JSON real.
        return _parseLooseMap(mapJson);
      case 'list':
        return _parseLooseList(listJson);
    }
    return stringVal;
  }

  static String _guessType(dynamic v) {
    if (v is num) return 'number';
    if (v is bool) return 'bool';
    if (v is Timestamp) return 'timestamp';
    if (v is Map<String, dynamic>) return 'map';
    if (v is List) return 'list';
    return 'string';
  }

  static Map<String, dynamic> _parseLooseMap(String s) {
    // Permite entradas estilo {a: 1, b: true}
    final out = <String, dynamic>{};
    final trimmed = s.trim();
    if (trimmed.isEmpty) return out;
    final body = trimmed
        .replaceAll(RegExp(r'^\{|\}$'), '')
        .trim();
    if (body.isEmpty) return out;
    final parts = body.split(',');
    for (final p in parts) {
      final kv = p.split(':');
      if (kv.length < 2) continue;
      final k = kv.first.trim();
      final raw = kv.sublist(1).join(':').trim();
      out[k] = _coerce(raw);
    }
    return out;
  }

  static List _parseLooseList(String s) {
    final out = <dynamic>[];
    final trimmed = s.trim();
    if (trimmed.isEmpty) return out;
    final body = trimmed
        .replaceAll(RegExp(r'^\[|\]$'), '')
        .trim();
    if (body.isEmpty) return out;
    final parts = body.split(',');
    for (final p in parts) {
      out.add(_coerce(p.trim()));
    }
    return out;
  }

  static dynamic _coerce(String raw) {
    if (raw.toLowerCase() == 'true') return true;
    if (raw.toLowerCase() == 'false') return false;
    final n = num.tryParse(raw);
    if (n != null) return n;
    return raw;
  }
}

class _FieldEditor extends StatefulWidget {
  final _FieldRow row;
  final VoidCallback onDelete;
  const _FieldEditor({super.key, required this.row, required this.onDelete});

  @override
  State<_FieldEditor> createState() => _FieldEditorState();
}

class _FieldEditorState extends State<_FieldEditor> {
  late final TextEditingController _nameCtrl;
  late final TextEditingController _stringCtrl;
  late final TextEditingController _numberCtrl;
  late final TextEditingController _mapCtrl;
  late final TextEditingController _listCtrl;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.row.name);
    _stringCtrl = TextEditingController(text: widget.row.stringVal);
    _numberCtrl = TextEditingController(text: widget.row.numberVal);
    _mapCtrl = TextEditingController(text: widget.row.mapJson);
    _listCtrl = TextEditingController(text: widget.row.listJson);
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _stringCtrl.dispose();
    _numberCtrl.dispose();
    _mapCtrl.dispose();
    _listCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final row = widget.row;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // nombre del campo
          SizedBox(
            width: 160,
            child: TextField(
              controller: _nameCtrl,
              decoration: const InputDecoration(labelText: 'Campo'),
              onChanged: (v) => row.name = v,
            ),
          ),
          const SizedBox(width: 8),

          // tipo
          SizedBox(
            width: 140,
            child: DropdownButtonFormField<String>(
              value: row.type,
              decoration: const InputDecoration(labelText: 'Tipo'),
              items: const [
                DropdownMenuItem(value: 'string', child: Text('String')),
                DropdownMenuItem(value: 'number', child: Text('Number')),
                DropdownMenuItem(value: 'bool', child: Text('Bool')),
                DropdownMenuItem(value: 'timestamp', child: Text('Timestamp')),
                DropdownMenuItem(value: 'map', child: Text('Map')),
                DropdownMenuItem(value: 'list', child: Text('List')),
              ],
              onChanged: (v) => setState(() => row.type = v ?? 'string'),
            ),
          ),
          const SizedBox(width: 8),

          // valor según el tipo
          Expanded(child: _valueEditor(row)),
          const SizedBox(width: 8),

          IconButton(
            tooltip: 'Eliminar campo',
            onPressed: widget.onDelete,
            icon: const Icon(Icons.delete_outline),
          )
        ],
      ),
    );
  }

  Widget _valueEditor(_FieldRow row) {
    switch (row.type) {
      case 'string':
        return TextField(
          controller: _stringCtrl,
          decoration: const InputDecoration(labelText: 'Valor (String)'),
          onChanged: (v) => row.stringVal = v,
        );
      case 'number':
        return TextField(
          controller: _numberCtrl,
          decoration: const InputDecoration(labelText: 'Valor (Number)'),
          keyboardType: TextInputType.number,
          onChanged: (v) => row.numberVal = v,
        );
      case 'bool':
        return Row(
          children: [
            const Text('False'),
            Switch(
              value: row.boolVal,
              onChanged: (b) => setState(() => row.boolVal = b),
            ),
            const Text('True'),
          ],
        );
      case 'timestamp':
        return OutlinedButton.icon(
          onPressed: () async {
            final now = DateTime.now();
            final d = await showDatePicker(
              context: context,
              firstDate: DateTime(now.year - 2),
              lastDate: DateTime(now.year + 5),
              initialDate: row.tsVal ?? now,
            );
            if (d == null) return;
            final t = await showTimePicker(context: context, initialTime: TimeOfDay.fromDateTime(row.tsVal ?? now));
            if (t == null) return;
            setState(() => row.tsVal = DateTime(d.year, d.month, d.day, t.hour, t.minute));
          },
          icon: const Icon(Icons.schedule),
          label: Text(row.tsVal?.toString() ?? 'Seleccionar fecha y hora'),
        );
      case 'map':
        return TextField(
          controller: _mapCtrl,
          decoration: const InputDecoration(labelText: 'Map {k: v, ...}'),
          maxLines: 3,
          onChanged: (v) => row.mapJson = v,
        );
      case 'list':
        return TextField(
          controller: _listCtrl,
          decoration: const InputDecoration(labelText: 'List [a, b, ...]'),
          maxLines: 3,
          onChanged: (v) => row.listJson = v,
        );
    }
    return const SizedBox.shrink();
  }
}
