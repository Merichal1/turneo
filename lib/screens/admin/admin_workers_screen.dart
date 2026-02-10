import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../config/app_config.dart';

class AdminWorkersScreen extends StatefulWidget {
  const AdminWorkersScreen({super.key});

  @override
  State<AdminWorkersScreen> createState() => _AdminWorkersScreenState();
}

class _AdminWorkersScreenState extends State<AdminWorkersScreen> {
  // 🎨 Turneo style constants
  static const Color _bg = Color(0xFFF6F8FC);
  static const Color _textDark = Color(0xFF111827);
  static const Color _textGrey = Color(0xFF6B7280);
  static const Color _blue = Color(0xFF2563EB);

  final TextEditingController _searchController = TextEditingController();
  String _searchTerm = '';
  int _statusFilter = 0; // 0 todos, 1 activos, 2 baja/inactivos

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // ✅ Lee campos tanto en raíz como dentro de "perfil" / "laboral"
  _WorkerVM _mapDocToWorkerVM(QueryDocumentSnapshot<Map<String, dynamic>> d) {
    final data = d.data();

    final perfil = (data['perfil'] is Map) ? Map<String, dynamic>.from(data['perfil']) : <String, dynamic>{};
    final laboral = (data['laboral'] is Map) ? Map<String, dynamic>.from(data['laboral']) : <String, dynamic>{};

    String readString(dynamic v) => (v ?? '').toString().trim();
    bool readBool(dynamic v, {bool def = false}) => v is bool ? v : def;

    final nombre = readString(data['nombre']).isNotEmpty ? readString(data['nombre']) : readString(perfil['nombre']);
    final apellidos =
        readString(data['apellidos']).isNotEmpty ? readString(data['apellidos']) : readString(perfil['apellidos']);
    final correo = readString(data['correo']).isNotEmpty ? readString(data['correo']) : readString(perfil['correo']);
    final telefono =
        readString(data['telefono']).isNotEmpty ? readString(data['telefono']) : readString(perfil['telefono']);
    final dni = readString(data['dni']).isNotEmpty ? readString(data['dni']) : readString(perfil['dni']);
    final ciudad = readString(data['ciudad']).isNotEmpty ? readString(data['ciudad']) : readString(perfil['ciudad']);

    final puesto = readString(data['puesto']).isNotEmpty ? readString(data['puesto']) : readString(laboral['puesto']);

    final activo = readBool(data['activo'], def: true);
    final tieneVehiculo = readBool(
      data['tieneVehiculo'] is bool ? data['tieneVehiculo'] : laboral['tieneVehiculo'],
      def: false,
    );

    // ✅ LA CLAVE: photoUrl puede estar en raíz o en perfil.photoUrl
    final photoUrlRoot = readString(data['photoUrl']);
    final photoUrlPerfil = readString(perfil['photoUrl']);
    final photoUrl = photoUrlRoot.isNotEmpty ? photoUrlRoot : photoUrlPerfil;

    final nombreCompleto = ('${nombre.isEmpty ? '—' : nombre} ${apellidos.isEmpty ? '' : apellidos}')
        .trim()
        .replaceAll(RegExp(r'\s+'), ' ');

    return _WorkerVM(
      id: d.id,
      nombre: nombre,
      apellidos: apellidos,
      nombreCompleto: nombreCompleto.isEmpty ? '—' : nombreCompleto,
      correo: correo,
      telefono: telefono,
      dni: dni,
      ciudad: ciudad,
      puesto: puesto,
      activo: activo,
      tieneVehiculo: tieneVehiculo,
      photoUrl: photoUrl,
    );
  }

  @override
  Widget build(BuildContext context) {
    const empresaId = AppConfig.empresaId;

    final stream = FirebaseFirestore.instance
        .collection('empresas')
        .doc(empresaId)
        .collection('trabajadores')
        .orderBy('nombre_lower')
        .snapshots()
        .map((snap) => snap.docs.map(_mapDocToWorkerVM).toList());

    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _bg,
        elevation: 0,
        surfaceTintColor: _bg,
        title: const Text(
          'Gestión de Personal',
          style: TextStyle(
            color: _textDark,
            fontWeight: FontWeight.w900,
          ),
        ),
        centerTitle: false,
      ),
      body: StreamBuilder<List<_WorkerVM>>(
        stream: stream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Text(
                'Error al cargar trabajadores:\n${snapshot.error}',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.red),
              ),
            );
          }

          final todos = snapshot.data ?? [];

          // Filtrado por nombre
          var trabajadores = _searchTerm.isEmpty
              ? todos
              : todos.where((t) => t.nombreCompleto.toLowerCase().contains(_searchTerm)).toList();

          // Filtrado por estado (UI)
          if (_statusFilter == 1) {
            trabajadores = trabajadores.where((t) => t.activo == true).toList();
          } else if (_statusFilter == 2) {
            trabajadores = trabajadores.where((t) => t.activo == false).toList();
          }

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
                child: _HeaderControls(
                  searchController: _searchController,
                  onSearchChanged: (value) => setState(() => _searchTerm = value.trim().toLowerCase()),
                  statusFilter: _statusFilter,
                  onStatusChanged: (v) => setState(() => _statusFilter = v),
                ),
              ),
              Expanded(
                child: trabajadores.isEmpty
                    ? const Center(
                        child: Text(
                          'No se han encontrado trabajadores.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: _textGrey),
                        ),
                      )
                    : LayoutBuilder(
                        builder: (context, constraints) {
                          final columns =
                              constraints.maxWidth >= 980 ? 3 : (constraints.maxWidth >= 700 ? 2 : 1);
                          return GridView.builder(
                            padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
                            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: columns,
                              crossAxisSpacing: 14,
                              mainAxisSpacing: 14,
                              childAspectRatio: columns == 1 ? 1.9 : 1.7,
                            ),
                            itemCount: trabajadores.length,
                            itemBuilder: (context, index) {
                              final t = trabajadores[index];
                              return _WorkerCard(
                                trabajador: t,
                                onTap: () => _openWorkerForm(context: context, trabajador: t),
                                onEdit: () => _openWorkerForm(context: context, trabajador: t),
                                onDelete: () async {
                                  final confirmed = await _showConfirmDialog(context, t.nombreCompleto);
                                  if (confirmed == true) {
                                    await _deleteWorker(empresaId: empresaId, trabajadorId: t.id);
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(content: Text('Trabajador "${t.nombreCompleto}" eliminado')),
                                      );
                                    }
                                  }
                                },
                              );
                            },
                          );
                        },
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<bool?> _showConfirmDialog(BuildContext context, String nombre) {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Eliminar trabajador'),
        content: Text('¿Seguro que quieres eliminar a "$nombre"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
  }
}

// ────────────────────────── VIEW MODEL ──────────────────────────

class _WorkerVM {
  final String id;
  final String nombre;
  final String apellidos;
  final String nombreCompleto;
  final String correo;
  final String telefono;
  final String dni;
  final String ciudad;
  final String puesto;
  final bool activo;
  final bool tieneVehiculo;
  final String photoUrl;

  const _WorkerVM({
    required this.id,
    required this.nombre,
    required this.apellidos,
    required this.nombreCompleto,
    required this.correo,
    required this.telefono,
    required this.dni,
    required this.ciudad,
    required this.puesto,
    required this.activo,
    required this.tieneVehiculo,
    required this.photoUrl,
  });
}

// --- COMPONENTES DE CABECERA Y FILTROS ---

class _HeaderControls extends StatelessWidget {
  static const Color _border = Color(0xFFE5E7EB);
  static const Color _textGrey = Color(0xFF6B7280);
  static const Color _blue = Color(0xFF2563EB);

  final TextEditingController searchController;
  final void Function(String) onSearchChanged;
  final int statusFilter;
  final void Function(int) onStatusChanged;

  const _HeaderControls({
    required this.searchController,
    required this.onSearchChanged,
    required this.statusFilter,
    required this.onStatusChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: _border),
        boxShadow: const [BoxShadow(color: Color(0x14000000), blurRadius: 24, offset: Offset(0, 10))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Administra tu equipo de trabajo', style: TextStyle(color: _textGrey, fontWeight: FontWeight.w600)),
          const SizedBox(height: 10),
          TextField(
            controller: searchController,
            onChanged: onSearchChanged,
            decoration: InputDecoration(
              hintText: 'Buscar personal por nombre...',
              prefixIcon: const Icon(Icons.search, size: 20, color: _textGrey),
              filled: true,
              fillColor: const Color(0xFFF9FAFB),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(999), borderSide: BorderSide.none),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(999),
                borderSide: const BorderSide(color: _border),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(999),
                borderSide: const BorderSide(color: _blue, width: 2),
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 14),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _Pill(label: 'Todos', selected: statusFilter == 0, onTap: () => onStatusChanged(0)),
              const SizedBox(width: 8),
              _Pill(label: 'Activos', selected: statusFilter == 1, onTap: () => onStatusChanged(1)),
              const SizedBox(width: 8),
              _Pill(label: 'De baja', selected: statusFilter == 2, onTap: () => onStatusChanged(2)),
            ],
          ),
        ],
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _Pill({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFF2563EB) : Colors.white,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: selected ? Colors.transparent : const Color(0xFFE5E7EB)),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.white : const Color(0xFF111827),
            fontWeight: FontWeight.w800,
            fontSize: 12,
          ),
        ),
      ),
    );
  }
}

// --- TARJETA DEL TRABAJADOR ---

class _WorkerCard extends StatelessWidget {
  final _WorkerVM trabajador;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final Future<void> Function() onDelete;

  const _WorkerCard({
    required this.trabajador,
    required this.onTap,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    const Color _blue = Color(0xFF2563EB);
    const Color _textDark = Color(0xFF111827);
    const Color _textGrey = Color(0xFF6B7280);

    final bool hasPhoto = trabajador.photoUrl.trim().isNotEmpty;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        boxShadow: const [BoxShadow(color: Color(0x14000000), blurRadius: 24, offset: Offset(0, 10))],
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  // ✅ Avatar robusto: si la URL falla en web, no se queda roto
                  CircleAvatar(
                    radius: 18,
                    backgroundColor: const Color(0xFFEFF6FF),
                    child: ClipOval(
                      child: SizedBox(
                        width: 36,
                        height: 36,
                        child: hasPhoto
                            ? Image.network(
                                trabajador.photoUrl,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => _InitialsAvatar(
                                  initials: _initials(trabajador.nombre, trabajador.apellidos),
                                ),
                                loadingBuilder: (ctx, child, progress) {
                                  if (progress == null) return child;
                                  return const Center(
                                    child: SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(strokeWidth: 2),
                                    ),
                                  );
                                },
                              )
                            : _InitialsAvatar(
                                initials: _initials(trabajador.nombre, trabajador.apellidos),
                              ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          trabajador.nombreCompleto,
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: _textDark),
                          overflow: TextOverflow.ellipsis,
                        ),
                      Text(
                        trabajador.puesto,
                        style: const TextStyle(
                          color: _textGrey,
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                        ),
                      ),
                      ],
                    ),
                  ),
                  PopupMenuButton<String>(
                    onSelected: (v) => v == 'edit' ? onEdit() : onDelete(),
                    itemBuilder: (_) => const [
                      PopupMenuItem(value: 'edit', child: Text('Editar')),
                      PopupMenuItem(value: 'delete', child: Text('Eliminar', style: TextStyle(color: Colors.red))),
                    ],
                    child: const Icon(Icons.more_vert, color: _textGrey),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  _ActivoChip(activo: trabajador.activo),
                  const SizedBox(width: 8),
                  if (trabajador.tieneVehiculo)
                    const _IconTag(
                      icon: Icons.directions_car,
                      label: 'Vehículo',
                      color: Color(0xFF15803D),
                      bg: Color(0xFFDCFCE7),
                    ),
                ],
              ),
              const Spacer(),
              _InfoRow(icon: Icons.email_outlined, text: trabajador.correo.isEmpty ? '-' : trabajador.correo),
              const SizedBox(height: 4),
              _InfoRow(icon: Icons.phone_outlined, text: trabajador.telefono.isEmpty ? '-' : trabajador.telefono),
            ],
          ),
        ),
      ),
    );
  }
}

class _InitialsAvatar extends StatelessWidget {
  final String initials;
  const _InitialsAvatar({required this.initials});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFEFF6FF),
      alignment: Alignment.center,
      child: Text(
        initials,
        style: const TextStyle(
          color: Color(0xFF2563EB),
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

// --- WIDGETS DE APOYO ADICIONALES ---

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String text;
  const _InfoRow({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 16, color: const Color(0xFF6B7280)),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(color: Color(0xFF374151), fontWeight: FontWeight.w600, fontSize: 13),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

class _IconTag extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final Color bg;
  const _IconTag({required this.icon, required this.label, required this.color, required this.bg});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(999)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(label, style: TextStyle(color: color, fontWeight: FontWeight.w800, fontSize: 10)),
        ],
      ),
    );
  }
}

class _ActivoChip extends StatelessWidget {
  final bool activo;
  const _ActivoChip({required this.activo});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: activo ? const Color(0xFFDCFCE7) : const Color(0xFFFFEDD5),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        activo ? 'Activo' : 'De baja',
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w900,
          color: activo ? const Color(0xFF15803D) : const Color(0xFF9A3412),
        ),
      ),
    );
  }
}

// --- LÓGICA DE FIREBASE Y FORMULARIO ---

Future<void> _deleteWorker({required String empresaId, required String trabajadorId}) async {
  await FirebaseFirestore.instance.collection('empresas').doc(empresaId).collection('trabajadores').doc(trabajadorId).delete();
}

String _initials(String nombre, String apellidos) {
  final n = (nombre).trim();
  final a = (apellidos).trim();
  if (n.isEmpty && a.isEmpty) return '??';
  final first = n.isNotEmpty ? n[0].toUpperCase() : '?';
  final second = a.isNotEmpty ? a[0].toUpperCase() : '';
  return '$first$second';
}

Future<void> _openWorkerForm({required BuildContext context, _WorkerVM? trabajador}) async {
  const empresaId = AppConfig.empresaId;
  final isEditing = trabajador != null;

  final nombreController = TextEditingController(text: trabajador?.nombre ?? '');
  final apellidosController = TextEditingController(text: trabajador?.apellidos ?? '');
  final emailController = TextEditingController(text: trabajador?.correo ?? '');
  final telefonoController = TextEditingController(text: trabajador?.telefono ?? '');
  final ciudadController = TextEditingController(text: trabajador?.ciudad ?? '');
  final dniController = TextEditingController(text: trabajador?.dni ?? '');

  String puesto = (trabajador?.puesto.isNotEmpty == true) ? trabajador!.puesto : 'camarero';
  bool tieneVehiculo = trabajador?.tieneVehiculo ?? false;
  bool activo = trabajador?.activo ?? true;

  await showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
    builder: (context) => StatefulBuilder(
      builder: (context, setState) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom + 20,
          left: 20,
          right: 20,
          top: 20,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(isEditing ? 'Editar trabajador' : 'Nuevo trabajador', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              TextField(controller: nombreController, decoration: const InputDecoration(labelText: 'Nombre', border: OutlineInputBorder())),
              const SizedBox(height: 12),
              TextField(controller: apellidosController, decoration: const InputDecoration(labelText: 'Apellidos', border: OutlineInputBorder())),
              const SizedBox(height: 12),
              TextField(controller: emailController, decoration: const InputDecoration(labelText: 'Correo', border: OutlineInputBorder())),
              const SizedBox(height: 12),
              TextField(controller: telefonoController, decoration: const InputDecoration(labelText: 'Teléfono', border: OutlineInputBorder())),
              const SizedBox(height: 12),
              TextField(controller: ciudadController, decoration: const InputDecoration(labelText: 'Ciudad', border: OutlineInputBorder())),
              const SizedBox(height: 12),
              TextField(controller: dniController, decoration: const InputDecoration(labelText: 'DNI', border: OutlineInputBorder())),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: puesto,
                decoration: const InputDecoration(labelText: 'Puesto', border: OutlineInputBorder()),
                items: ['camarero', 'cocinero', 'logistica', 'limpiador', 'metre', 'coordinador']
                    .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                    .toList(),
                onChanged: (v) => setState(() => puesto = v ?? 'camarero'),
              ),
              const SizedBox(height: 12),
              SwitchListTile(title: const Text('Vehículo propio'), value: tieneVehiculo, onChanged: (v) => setState(() => tieneVehiculo = v)),
              SwitchListTile(title: const Text('Activo'), value: activo, onChanged: (v) => setState(() => activo = v)),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2563EB),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.all(16),
                  ),
                  onPressed: () async {
                    if (nombreController.text.trim().isEmpty) return;

                    // ✅ IMPORTANTE: mantenemos photoUrl si existe y lo guardamos en raíz Y en perfil
                    final existingPhotoUrl = trabajador?.photoUrl ?? '';

                    final payload = <String, dynamic>{
                      'activo': activo,
                      'nombre_lower': '${nombreController.text} ${apellidosController.text}'.toLowerCase(),
                      'perfil': {
                        'nombre': nombreController.text.trim(),
                        'apellidos': apellidosController.text.trim(),
                        'correo': emailController.text.trim(),
                        'telefono': telefonoController.text.trim(),
                        'dni': dniController.text.trim(),
                        'ciudad': ciudadController.text.trim(),
                        if (existingPhotoUrl.isNotEmpty) 'photoUrl': existingPhotoUrl, // ✅ perfil.photoUrl
                      },
                      'laboral': {
                        'puesto': puesto,
                        'tieneVehiculo': tieneVehiculo,
                      },
                      if (existingPhotoUrl.isNotEmpty) 'photoUrl': existingPhotoUrl, // ✅ raiz photoUrl
                      'creadoEn': FieldValue.serverTimestamp(),
                    };

                    final ref = FirebaseFirestore.instance.collection('empresas').doc(empresaId).collection('trabajadores');

                    if (isEditing) {
                      await ref.doc(trabajador!.id).set(payload, SetOptions(merge: true));
                    } else {
                      await ref.add(payload);
                    }

                    if (context.mounted) Navigator.pop(context);
                  },
                  child: Text(isEditing ? 'Guardar Cambios' : 'Crear Trabajador'),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
