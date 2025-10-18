import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'dart:math' as math;


/// ------------ CONFIGURACIÓN DE COLECCIONES (columnas y etiquetas) ------------
class CollectionConfig {
  final String title;
  final List<ColumnSpec> columns; // qué campos mostramos en la tabla
  final List<String> quickSearchIn; // campos para buscar
  const CollectionConfig({
    required this.title,
    required this.columns,
    required this.quickSearchIn,
  });
}

class ColumnSpec {
  final String field;
  final String label;
  final bool isBoolean;
  final bool isTimestamp;
  final bool shrink; // para iconos/chips
  final String? Function(Map<String, dynamic> row)? compute; // p.ej nombre completo
  const ColumnSpec({
    required this.field,
    required this.label,
    this.isBoolean = false,
    this.isTimestamp = false,
    this.shrink = false,
    this.compute,
  });
}

const Map<String, CollectionConfig> kCollections = {
  'users': CollectionConfig(
    title: 'Usuarios',
    quickSearchIn: ['nombre', 'apellidos', 'email', 'telefono', 'dni'],
    columns: [
      ColumnSpec(field: 'nombre', label: 'Nombre'),
      ColumnSpec(field: 'apellidos', label: 'Apellidos'),
      ColumnSpec(field: 'email', label: 'Email'),
      ColumnSpec(field: 'telefono', label: 'Teléfono', shrink: true),
      ColumnSpec(field: 'puesto', label: 'Puesto', shrink: true),
      ColumnSpec(field: 'role', label: 'Rol', shrink: true),
      ColumnSpec(field: 'activo', label: 'Activo', isBoolean: true, shrink: true),
      ColumnSpec(field: 'vehiculo', label: 'Vehículo', isBoolean: true, shrink: true),
      ColumnSpec(field: 'carnetConducir', label: 'Carnet', isBoolean: true, shrink: true),
      ColumnSpec(field: 'createdAt', label: 'Alta', isTimestamp: true, shrink: true),
    ],
  ),
  // Añade más colecciones aquí si quieres...
};

/// ------------------------- PANTALLA PRINCIPAL -------------------------
class AdminDatabaseScreen extends StatefulWidget {
  const AdminDatabaseScreen({super.key});

  @override
  State<AdminDatabaseScreen> createState() => _AdminDatabaseScreenState();
}

class _AdminDatabaseScreenState extends State<AdminDatabaseScreen> {
  final _pathCtrl = TextEditingController(text: 'users');
  final _searchCtrl = TextEditingController();
  final _favorites = <String>['users', 'events', 'payments', 'notifications'];
  String _selectedPath = 'users';
  int _limit = 100;

  // Filtros sencillos pensados para "users"
  String _roleFilter = 'Todos';
  bool? _activoFilter; // null = todos

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
    final segs = _selectedPath.split('/').where((s) => s.isNotEmpty).toList();
    return segs.isNotEmpty && segs.length.isOdd;
  }

  CollectionReference<Map<String, dynamic>> _collectionRef() {
    return FirebaseFirestore.instance.collection(_selectedPath);
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

  Future<void> _createDoc() async {
    if (!_isCollectionPath) {
      _snack('Indica una colección para crear un documento nuevo.');
      return;
    }

    Map<String, dynamic>? result;

    if (_selectedPath == 'users') {
      // Formulario específico con validaciones
      result = await showDialog<Map<String, dynamic>>(
        context: context,
        builder: (_) => const _UserFormDialog(title: 'Nuevo usuario'),
      );
    } else {
      // Formulario genérico
      result = await showDialog<Map<String, dynamic>>(
        context: context,
        builder: (_) => _DocEditorDialog(
          title: 'Crear documento',
          initialData: const {},
        ),
      );
    }

    if (result != null) {
      await _collectionRef().add(result);
      _snack('Documento creado.');
    }
  }

  Future<void> _editDoc(String docId, Map<String, dynamic> data) async {
    Map<String, dynamic>? result;

    if (_selectedPath == 'users') {
      result = await showDialog<Map<String, dynamic>>(
        context: context,
        builder: (_) => _UserFormDialog(
          title: 'Editar usuario',
          initialData: data,
        ),
      );
    } else {
      result = await showDialog<Map<String, dynamic>>(
        context: context,
        builder: (_) => _DocEditorDialog(
          title: 'Editar $docId',
          initialData: data,
        ),
      );
    }

    if (result != null) {
      // merge:true para no perder campos que no estén en el formulario
      await _collectionRef().doc(docId).set(result, SetOptions(merge: true));
      _snack('Documento guardado.');
    }
  }

  Future<void> _deleteDoc(String docId) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Eliminar documento'),
        content: Text('¿Eliminar "$docId" en "$_selectedPath"?'),
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

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final config = kCollections[_selectedPath];

    return Scaffold(
      body: Row(
        children: [
          // ----------------- SIDEBAR -----------------
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
                          hintText: 'ej. users o events/ABC/shifts',
                          prefixIcon: Icon(Icons.folder_outlined),
                        ),
                        onSubmitted: (_) => _openPath(_pathCtrl.text),
                      ),
                    ),
                    const SizedBox(width: 8),
                    FilledButton(onPressed: () => _openPath(_pathCtrl.text), child: const Text('Abrir')),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    const Text('Favoritos', style: TextStyle(fontWeight: FontWeight.w800)),
                    const Spacer(),
                    IconButton(
                      tooltip: 'Añadir favorito',
                      onPressed: () {
                        final p = _pathCtrl.text.trim();
                        if (p.isEmpty) return;
                        if (!_favorites.contains(p)) setState(() => _favorites.add(p));
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

          // ----------------- PANEL PRINCIPAL -----------------
          Expanded(
            child: Column(
              children: [
                // Barra superior
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
                          config?.title ?? (_selectedPath.isEmpty ? '(sin ruta)' : _selectedPath),
                          style: const TextStyle(fontWeight: FontWeight.w800),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 12),
                      if (_selectedPath == 'users') ...[
                        DropdownButton<String>(
                          value: _roleFilter,
                          items: const ['Todos', 'admin', 'worker', 'user']
                              .map((r) => DropdownMenuItem(value: r, child: Text('Rol: $r')))
                              .toList(),
                          onChanged: (v) => setState(() => _roleFilter = v ?? 'Todos'),
                        ),
                        const SizedBox(width: 8),
                        DropdownButton<String>(
                          value: _activoFilter == null
                              ? 'Todos'
                              : (_activoFilter! ? 'Activos' : 'Inactivos'),
                          items: const ['Todos', 'Activos', 'Inactivos']
                              .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                              .toList(),
                          onChanged: (v) {
                            setState(() {
                              if (v == 'Activos') _activoFilter = true;
                              else if (v == 'Inactivos') _activoFilter = false;
                              else _activoFilter = null;
                            });
                          },
                        ),
                        const SizedBox(width: 12),
                      ],
                      SizedBox(
                        width: 260,
                        child: TextField(
                          controller: _searchCtrl,
                          decoration: const InputDecoration(
                            hintText: 'Buscar… (nombre, email, id)',
                            prefixIcon: Icon(Icons.search),
                          ),
                          onChanged: (_) => setState(() {}),
                        ),
                      ),
                      const SizedBox(width: 12),
                      FilledButton.icon(
                        onPressed: _isCollectionPath ? _createDoc : null,
                        icon: const Icon(Icons.add),
                        label: const Text('Nuevo'),
                      ),
                    ],
                  ),
                ),

                // Contenido
                Expanded(
                  child: !_isCollectionPath
                      ? Center(
                          child: Text(
                            'La ruta seleccionada no es una colección.\nEjemplos: "users" o "events/ABC/shifts".',
                            textAlign: TextAlign.center,
                          ),
                        )
                      : StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
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
                            if (docs.isEmpty) {
                              return const Center(child: Text('No hay registros.'));
                            }

                            final cfg = kCollections[_selectedPath];
                            final q = _searchCtrl.text.trim().toLowerCase();
                            final filtered = docs.where((d) {
                              final data = d.data();
                              // búsqueda
                              bool matches = q.isEmpty ||
                                  d.id.toLowerCase().contains(q) ||
                                  (cfg?.quickSearchIn.any((f) =>
                                          (data[f]?.toString().toLowerCase() ?? '')
                                              .contains(q)) ??
                                      false);
                              // filtros específicos users
                              if (_selectedPath == 'users') {
                                if (_roleFilter != 'Todos' &&
                                    (data['role']?.toString() ?? '') != _roleFilter) {
                                  matches = false;
                                }
                                if (_activoFilter != null &&
                                    (data['activo'] is bool) &&
                                    data['activo'] != _activoFilter) {
                                  matches = false;
                                }
                              }
                              return matches;
                            }).toList();

                            return _CollectionTable(
                              path: _selectedPath,
                              docs: filtered,
                              config: cfg,
                              onEdit: (id, data) => _editDoc(id, data),
                              onDelete: (id) => _deleteDoc(id),
                            );
                          },
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

/// ------------------------- TABLA / LISTADO -------------------------

class _CollectionTable extends StatefulWidget {
  final String path;
  final List<QueryDocumentSnapshot<Map<String, dynamic>>> docs;
  final CollectionConfig? config;
  final void Function(String id, Map<String, dynamic> data) onEdit;
  final void Function(String id) onDelete;

  const _CollectionTable({
    required this.path,
    required this.docs,
    required this.config,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  State<_CollectionTable> createState() => _CollectionTableState();
}

class _CollectionTableState extends State<_CollectionTable> {
  // Barra horizontal visible (tu barra)
  final ScrollController _hCtrl = ScrollController();
  // Barra vertical visible (para muchas filas)
  final ScrollController _vCtrl = ScrollController();

  // Anchos por columna (como antes) para garantizar overflow horizontal
  double _minColWidth(ColumnSpec c) => c.shrink ? 200.0 : 320.0;
  double _maxColWidth(ColumnSpec c) => c.shrink ? 260.0 : 380.0;

  @override
  void dispose() {
    _hCtrl.dispose();
    _vCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final columns = widget.config?.columns ?? const [
      ColumnSpec(field: '_id', label: 'ID', shrink: true),
      ColumnSpec(field: '_count', label: 'Campos', shrink: true),
    ];

    // Suma de anchos mínimos por columna + margen para "Acciones"
    final estimatedWidth =
        columns.fold<double>(0, (sum, c) => sum + _minColWidth(c)) + 200;

    return LayoutBuilder(
      builder: (context, constraints) {
        // Forzamos overflow horizontal para que SIEMPRE aparezca la barra
        final minTableWidth = math.max(estimatedWidth, constraints.maxWidth + 600);

        return ScrollConfiguration(
          behavior: const _NoGlowScrollBehavior(),
          // ---- BARRA HORIZONTAL (tu barra) ----
          child: Scrollbar(
            controller: _hCtrl,
            thumbVisibility: true,   // siempre visible
            trackVisibility: true,   // muestra pista
            interactive: true,
            notificationPredicate: (notif) =>
                notif.metrics.axis == Axis.horizontal, // solo horizontal
            child: SingleChildScrollView(
              controller: _hCtrl,
              scrollDirection: Axis.horizontal,
              physics: const ClampingScrollPhysics(),
              child: ConstrainedBox(
                // Asegura ancho mínimo suficiente para que haya scroll lateral
                constraints: BoxConstraints(
                  minWidth: minTableWidth,
                  // Altura mínima opcional para evitar "colapso" visual
                  minHeight: MediaQuery.of(context).size.height * 0.3,
                ),
                // ---- DENTRO: SCROLL VERTICAL con su barra ----
                child: Scrollbar(
                  controller: _vCtrl,
                  thumbVisibility: true,
                  trackVisibility: true,
                  interactive: true,
                  child: SingleChildScrollView(
                    controller: _vCtrl,
                    scrollDirection: Axis.vertical,
                    physics: const ClampingScrollPhysics(),
                    child: Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: _buildDataTable(context, columns),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  /// Construye la DataTable usando tu config/logic (chips, timestamps y acciones)
  Widget _buildDataTable(BuildContext context, List<ColumnSpec> columns) {
    final docs = widget.docs;

    if (docs.isEmpty) {
      return SizedBox(
        height: 160,
        child: Center(
          child: Text(
            'No hay documentos en ${widget.path}',
            style: Theme.of(context).textTheme.bodyLarge,
          ),
        ),
      );
    }

    return DataTable(
      headingRowHeight: 44,
      dataRowMinHeight: 40,
      dataRowMaxHeight: 60,
      columnSpacing: 24,
      showCheckboxColumn: false,
      headingTextStyle: Theme.of(context).textTheme.titleSmall,
      dividerThickness: 0.5,
      headingRowColor: MaterialStatePropertyAll(
        Theme.of(context).colorScheme.surfaceContainerHighest,
      ),
      columns: [
        ...columns.map(
          (c) => DataColumn(
            label: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: Text(c.label, style: const TextStyle(fontWeight: FontWeight.w600)),
            ),
          ),
        ),
        const DataColumn(label: SizedBox(width: 140, child: Text('Acciones'))),
      ],
      rows: docs.map((d) {
        final data = d.data();
        final cells = <DataCell>[];

        for (final c in columns) {
          // Booleano como chip (como antes)
          if (c.isBoolean && (data[c.field] is bool)) {
            cells.add(DataCell(_BoolChip(value: data[c.field] as bool)));
            continue;
          }

          String? display;
          final v = data[c.field];
          if (c.isTimestamp && v is Timestamp) {
            display = _fmtTs(v);
          } else if (c.compute != null) {
            display = c.compute!(data);
          } else if (c.field == '_id') {
            display = d.id;
          } else if (c.field == '_count') {
            display = '${data.length}';
          } else {
            display = v?.toString();
          }

          cells.add(
            DataCell(
              ConstrainedBox(
                constraints: BoxConstraints(
                  minWidth: _minColWidth(c), // suma ancho real por columna
                  maxWidth: _maxColWidth(c),
                ),
                child: Text(display ?? '-', overflow: TextOverflow.ellipsis),
              ),
            ),
          );
        }

        // Columna de acciones
        cells.add(
          DataCell(
            SizedBox(
              width: 140,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    tooltip: 'Editar',
                    icon: const Icon(Icons.edit_outlined),
                    onPressed: () => widget.onEdit(d.id, data),
                  ),
                  IconButton(
                    tooltip: 'Eliminar',
                    icon: const Icon(Icons.delete_outline),
                    onPressed: () => widget.onDelete(d.id),
                  ),
                ],
              ),
            ),
          ),
        );

        return DataRow(
          cells: cells,
          onSelectChanged: (_) => widget.onEdit(d.id, data),
        );
      }).toList(),
    );
  }
}

/// Evita el glow de overscroll (web/desktop)
class _NoGlowScrollBehavior extends ScrollBehavior {
  const _NoGlowScrollBehavior();

  @override
  Widget buildOverscrollIndicator(
      BuildContext context, Widget child, ScrollableDetails details) {
    return child;
  }

  // Compat con versiones antiguas; si no existe, no afecta.
  @override
  Widget buildViewportChrome(
      BuildContext context, Widget child, AxisDirection axisDirection) {
    return child;
  }
}

/// ------------------------- WIDGETS AUXILIARES -------------------------
class _BoolChip extends StatelessWidget {
  final bool value;
  const _BoolChip({required this.value});
  @override
  Widget build(BuildContext context) {
    final ok = value;
    return Chip(
      label: Text(ok ? 'Sí' : 'No'),
      avatar: Icon(ok ? Icons.check_circle : Icons.cancel, size: 16),
    );
  }
}

class _DetailSheet extends StatelessWidget {
  final String path;
  final String docId;
  final Map<String, dynamic> data;
  const _DetailSheet({required this.path, required this.docId, required this.data});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final keys = data.keys.toList()..sort();
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('$path • $docId', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: 12),
          Expanded(
            child: ListView.separated(
              itemCount: keys.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (_, i) {
                final k = keys[i];
                final v = data[k];
                return ListTile(
                  dense: true,
                  title: Text(k),
                  subtitle: Text(_prettyValue(v)),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  String _prettyValue(dynamic v) {
    if (v is Timestamp) return _fmtTs(v);
    if (v is bool) return v ? 'Sí' : 'No';
    if (v is List) return '[${v.join(', ')}]';
    if (v is Map) return '{${v.entries.map((e) => '${e.key}: ${e.value}').join(', ')}}';
    return v?.toString() ?? '-';
  }
}

String _fmtTs(Timestamp ts) {
  final d = ts.toDate().toLocal();
  final y = d.year.toString().padLeft(4, '0');
  final m = d.month.toString().padLeft(2, '0');
  final day = d.day.toString().padLeft(2, '0');
  final hh = d.hour.toString().padLeft(2, '0');
  final mm = d.minute.toString().padLeft(2, '0');
  return '$day/$m/$y $hh:$mm';
}

/// ------------------------- FORMULARIO USERS (crear/editar) -------------------------
class _UserFormDialog extends StatefulWidget {
  final String title;
  final Map<String, dynamic>? initialData;
  const _UserFormDialog({required this.title, this.initialData});

  @override
  State<_UserFormDialog> createState() => _UserFormDialogState();
}

class _UserFormDialogState extends State<_UserFormDialog> {
  final _formKey = GlobalKey<FormState>();

  // Campos
  final _nombre = TextEditingController();
  final _apellidos = TextEditingController();
  final _email = TextEditingController();
  final _telefono = TextEditingController();
  final _dni = TextEditingController();
  final _localidad = TextEditingController();
  final _puesto = TextEditingController();

  String _rol = 'worker'; // admin | worker | user
  bool _activo = true;
  bool _vehiculo = false;
  bool _carnetConducir = false;
  int _experiencia = 0;
  DateTime _alta = DateTime.now();

  @override
  void initState() {
    super.initState();
    final d = widget.initialData ?? {};
    _nombre.text = (d['nombre'] ?? '').toString();
    _apellidos.text = (d['apellidos'] ?? '').toString();
    _email.text = (d['email'] ?? '').toString();
    _telefono.text = (d['telefono'] ?? '').toString();
    _dni.text = (d['dni'] ?? '').toString();
    _localidad.text = (d['localidad'] ?? '').toString();
    _puesto.text = (d['puesto'] ?? '').toString();

    _rol = (d['role'] ?? _rol).toString();
    _activo = d['activo'] is bool ? d['activo'] as bool : _activo;
    _vehiculo = d['vehiculo'] is bool ? d['vehiculo'] as bool : _vehiculo;
    _carnetConducir =
        d['carnetConducir'] is bool ? d['carnetConducir'] as bool : _carnetConducir;
    _experiencia = d['experiencia'] is num ? (d['experiencia'] as num).toInt() : _experiencia;

    final ts = d['createdAt'];
    if (ts is Timestamp) _alta = ts.toDate();
  }

  @override
  void dispose() {
    _nombre.dispose();
    _apellidos.dispose();
    _email.dispose();
    _telefono.dispose();
    _dni.dispose();
    _localidad.dispose();
    _puesto.dispose();
    super.dispose();
  }

  String? _req(String? v) => (v == null || v.trim().isEmpty) ? 'Obligatorio' : null;

  String? _emailVal(String? v) {
    if (_req(v) != null) return 'Obligatorio';
    final rx = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
    if (!rx.hasMatch(v!.trim())) return 'Email inválido';
    return null;
  }

  String? _telVal(String? v) {
    if (_req(v) != null) return 'Obligatorio';
    final digits = v!.replaceAll(RegExp(r'\D'), '');
    if (digits.length < 9) return 'Teléfono inválido';
    return null;
  }

  String? _dniVal(String? v) {
    if (_req(v) != null) return 'Obligatorio';
    final rx = RegExp(r'^[0-9]{7,8}[A-Za-z]?$'); // validación simple
    if (!rx.hasMatch(v!.trim())) return 'DNI inválido';
    return null;
  }

  Future<void> _pickFecha() async {
    final now = DateTime.now();
    final d = await showDatePicker(
      context: context,
      firstDate: DateTime(now.year - 2),
      lastDate: DateTime(now.year + 5),
      initialDate: _alta,
    );
    if (d == null) return;
    final t = await showTimePicker(context: context, initialTime: TimeOfDay.fromDateTime(_alta));
    if (t == null) return;
    setState(() => _alta = DateTime(d.year, d.month, d.day, t.hour, t.minute));
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;

    final isEditing = widget.initialData != null;
    final createdAt = isEditing && widget.initialData!['createdAt'] is Timestamp
        ? widget.initialData!['createdAt'] as Timestamp
        : Timestamp.fromDate(_alta);

    final data = <String, dynamic>{
      'nombre': _nombre.text.trim(),
      'apellidos': _apellidos.text.trim(),
      'email': _email.text.trim(),
      'telefono': _telefono.text.trim(),
      'dni': _dni.text.trim(),
      'localidad': _localidad.text.trim(),
      'puesto': _puesto.text.trim(),
      'role': _rol,
      'activo': _activo,
      'vehiculo': _vehiculo,
      'carnetConducir': _carnetConducir,
      'experiencia': _experiencia,
      'createdAt': createdAt,
    };

    Navigator.pop(context, data);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: SizedBox(
        width: 560,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              children: [
                Row(children: [
                  Expanded(
                    child: TextFormField(
                      controller: _nombre,
                      decoration: const InputDecoration(labelText: 'Nombre *'),
                      validator: _req,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _apellidos,
                      decoration: const InputDecoration(labelText: 'Apellidos *'),
                      validator: _req,
                    ),
                  ),
                ]),
                const SizedBox(height: 8),
                Row(children: [
                  Expanded(
                    child: TextFormField(
                      controller: _email,
                      decoration: const InputDecoration(labelText: 'Email *'),
                      keyboardType: TextInputType.emailAddress,
                      validator: _emailVal,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _telefono,
                      decoration: const InputDecoration(labelText: 'Teléfono *'),
                      keyboardType: TextInputType.phone,
                      validator: _telVal,
                    ),
                  ),
                ]),
                const SizedBox(height: 8),
                Row(children: [
                  Expanded(
                    child: TextFormField(
                      controller: _dni,
                      decoration: const InputDecoration(labelText: 'DNI *'),
                      validator: _dniVal,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _localidad,
                      decoration: const InputDecoration(labelText: 'Localidad *'),
                      validator: _req,
                    ),
                  ),
                ]),
                const SizedBox(height: 8),
                Row(children: [
                  Expanded(
                    child: TextFormField(
                      controller: _puesto,
                      decoration: const InputDecoration(labelText: 'Puesto *'),
                      validator: _req,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: _rol,
                      decoration: const InputDecoration(labelText: 'Rol *'),
                      items: const [
                        DropdownMenuItem(value: 'admin', child: Text('admin')),
                        DropdownMenuItem(value: 'worker', child: Text('worker')),
                        DropdownMenuItem(value: 'user', child: Text('user')),
                      ],
                      onChanged: (v) => setState(() => _rol = v ?? 'worker'),
                    ),
                  ),
                ]),
                const SizedBox(height: 8),
                Row(children: [
                  Expanded(
                    child: InputDecorator(
                      decoration: const InputDecoration(labelText: 'Alta'),
                      child: Row(
                        children: [
                          Text(_fmtTs(Timestamp.fromDate(_alta))),
                          const Spacer(),
                          OutlinedButton.icon(
                            onPressed: _pickFecha,
                            icon: const Icon(Icons.schedule),
                            label: const Text('Cambiar'),
                          )
                        ],
                      ),
                    ),
                  ),
                ]),
                const SizedBox(height: 8),
                Row(children: [
                  Expanded(
                    child: InputDecorator(
                      decoration: const InputDecoration(labelText: 'Activo'),
                      child: Switch(value: _activo, onChanged: (v) => setState(() => _activo = v)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: InputDecorator(
                      decoration: const InputDecoration(labelText: 'Vehículo'),
                      child: Switch(value: _vehiculo, onChanged: (v) => setState(() => _vehiculo = v)),
                    ),
                  ),
                ]),
                const SizedBox(height: 8),
                Row(children: [
                  Expanded(
                    child: InputDecorator(
                      decoration: const InputDecoration(labelText: 'Carnet de conducir'),
                      child:
                          Switch(value: _carnetConducir, onChanged: (v) => setState(() => _carnetConducir = v)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      initialValue: '0',
                      decoration: const InputDecoration(labelText: 'Años de experiencia'),
                      keyboardType: TextInputType.number,
                      onChanged: (v) => _experiencia = int.tryParse(v) ?? 0,
                    ),
                  ),
                ]),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
        FilledButton(onPressed: _submit, child: const Text('Guardar')),
      ],
    );
  }
}

/// ------------------------- EDITOR GENÉRICO (reaprovechado) -------------------------
class _DocEditorDialog extends StatefulWidget {
  final String title;
  final Map<String, dynamic> initialData;

  const _DocEditorDialog({required this.title, required this.initialData});

  @override
  State<_DocEditorDialog> createState() => _DocEditorDialogState();
}

class _DocEditorDialogState extends State<_DocEditorDialog> {
  late List<_FieldRow> _rows;

  @override
  void initState() {
    super.initState();
    _rows = widget.initialData.entries.map((e) => _FieldRow(name: e.key, value: e.value)).toList();
    if (_rows.isEmpty) _rows.add(_FieldRow(name: '', value: ''));
  }

  void _addRow() => setState(() => _rows.add(_FieldRow(name: '', value: '')));

  void _save() {
    final map = <String, dynamic>{};
    for (final r in _rows) {
      if (r.name.trim().isEmpty) continue;
      final parsed = r.parsedValue;
      if (parsed == null) continue;
      map[r.name.trim()] = parsed;
    }
    Navigator.pop(context, map);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: SizedBox(
        width: 560,
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

  _FieldRow({required this.name, required dynamic value})
      : type = _guessType(value),
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
    final out = <String, dynamic>{};
    final trimmed = s.trim();
    if (trimmed.isEmpty) return out;
    final body = trimmed.replaceAll(RegExp(r'^\{|\}$'), '').trim();
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
    final body = trimmed.replaceAll(RegExp(r'^\[|\]$'), '').trim();
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
          SizedBox(
            width: 160,
            child: TextField(
              controller: _nameCtrl,
              decoration: const InputDecoration(labelText: 'Campo'),
              onChanged: (v) => row.name = v,
            ),
          ),
          const SizedBox(width: 8),
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
          Expanded(child: _valueEditor(row)),
          const SizedBox(width: 8),
          IconButton(
            tooltip: 'Eliminar campo',
            onPressed: widget.onDelete,
            icon: const Icon(Icons.delete_outline),
          ),
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
            Switch(value: row.boolVal, onChanged: (b) => setState(() => row.boolVal = b)),
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
            final t = await showTimePicker(
              context: context,
              initialTime: TimeOfDay.fromDateTime(row.tsVal ?? now),
            );
            if (t == null) return;
            setState(() => row.tsVal = DateTime(d.year, d.month, d.day, t.hour, t.minute));
          },
          icon: const Icon(Icons.schedule),
          label: Text(row.tsVal != null ? _fmtDate(row.tsVal!) : 'Seleccionar fecha y hora'),
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

  String _fmtDate(DateTime d) {
    final y = d.year.toString().padLeft(4, '0');
    final m = d.month.toString().padLeft(2, '0');
    final day = d.day.toString().padLeft(2, '0');
    final hh = d.hour.toString().padLeft(2, '0');
    final mm = d.minute.toString().padLeft(2, '0');
    return '$day/$m/$y $hh:$mm';
  }
}
