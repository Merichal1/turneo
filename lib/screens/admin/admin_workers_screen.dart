import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../config/app_config.dart';
import '../../models/trabajador.dart';

class AdminWorkersScreen extends StatefulWidget {
  const AdminWorkersScreen({super.key});

  @override
  State<AdminWorkersScreen> createState() => _AdminWorkersScreenState();
}

class _AdminWorkersScreenState extends State<AdminWorkersScreen> {
  // 🎨 Turneo style
  static const Color _bg = Color(0xFFF6F8FC);
  static const Color _card = Colors.white;
  static const Color _border = Color(0xFFE5E7EB);
  static const Color _textDark = Color(0xFF111827);
  static const Color _textGrey = Color(0xFF6B7280);
  static const Color _blue = Color(0xFF2563EB);

  final TextEditingController _searchController = TextEditingController();
  String _searchTerm = '';

  // (UI) filtro estilo “Todos / Activos / De baja”
  int _statusFilter = 0; // 0 todos, 1 activos, 2 baja/inactivos

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
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
        .map((snap) => snap.docs.map((d) => Trabajador.fromFirestore(d)).toList());

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
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: _blue,
        foregroundColor: Colors.white,
        onPressed: () => _openWorkerForm(context: context),
        icon: const Icon(Icons.add),
        label: const Text(
          'Añadir Personal',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      body: StreamBuilder<List<Trabajador>>(
        stream: stream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            final error = snapshot.error;
            return Center(
              child: Text(
                'Error al cargar trabajadores:\n${error.runtimeType}\n$error',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.red),
              ),
            );
          }

          final todos = snapshot.data ?? [];

          // ===== FILTRADO POR NOMBRE (MISMA FUNCIONALIDAD) =====
          var trabajadores = _searchTerm.isEmpty
              ? todos
              : todos.where((t) => t.nombreCompleto.toLowerCase().contains(_searchTerm)).toList();

          // ===== FILTRADO POR ESTADO (SOLO UI) =====
          if (_statusFilter == 1) {
            trabajadores = trabajadores.where((t) => t.activo == true).toList();
          } else if (_statusFilter == 2) {
            trabajadores = trabajadores.where((t) => t.activo == false).toList();
          }

          if (trabajadores.isEmpty) {
            return const Center(
              child: Text(
                'No se han encontrado trabajadores.\n'
                'Prueba a cambiar el filtro o añade uno nuevo.',
                textAlign: TextAlign.center,
                style: TextStyle(color: _textGrey),
              ),
            );
          }

          return LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth >= 980;
              final isMedium = constraints.maxWidth >= 700 && constraints.maxWidth < 980;

              final columns = isWide ? 3 : (isMedium ? 2 : 1);

              return Column(
                children: [
                  // ===== HEADER: buscador + filtros =====
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
                    child: _HeaderControls(
                      searchController: _searchController,
                      onSearchChanged: (value) {
                        setState(() => _searchTerm = value.trim().toLowerCase());
                      },
                      statusFilter: _statusFilter,
                      onStatusChanged: (v) => setState(() => _statusFilter = v),
                    ),
                  ),

                  // ===== GRID/LISTA DE TARJETAS =====
                  Expanded(
                    child: GridView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: columns,
                        crossAxisSpacing: 14,
                        mainAxisSpacing: 14,
                        // altura similar a tu mock
                        childAspectRatio: columns == 1 ? 1.65 : 1.55,
                      ),
                      itemCount: trabajadores.length,
                      itemBuilder: (context, index) {
                        final t = trabajadores[index];
                        return _WorkerCard(
                          trabajador: t,
                          onTap: () => _openWorkerForm(context: context, trabajador: t),
                          onEdit: () => _openWorkerForm(context: context, trabajador: t),
                          onDelete: () async {
                            final confirmed = await showDialog<bool>(
                              context: context,
                              builder: (context) => AlertDialog(
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                title: const Text('Eliminar trabajador'),
                                content: Text('¿Seguro que quieres eliminar a "${t.nombreCompleto}"?'),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(context, false),
                                    child: const Text('Cancelar'),
                                  ),
                                  TextButton(
                                    onPressed: () => Navigator.pop(context, true),
                                    style: TextButton.styleFrom(foregroundColor: Colors.red),
                                    child: const Text('Eliminar'),
                                  ),
                                ],
                              ),
                            );

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
                    ),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }
}

class _HeaderControls extends StatelessWidget {
  static const Color _border = Color(0xFFE5E7EB);
  static const Color _textGrey = Color(0xFF6B7280);
  static const Color _textDark = Color(0xFF111827);
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
        boxShadow: const [
          BoxShadow(
            color: Color(0x14000000),
            blurRadius: 24,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: LayoutBuilder(
        builder: (context, c) {
          final compact = c.maxWidth < 720;

          final search = Expanded(
            child: TextField(
              controller: searchController,
              onChanged: onSearchChanged,
              decoration: InputDecoration(
                hintText: 'Buscar personal por nombre...',
                hintStyle: const TextStyle(color: _textGrey),
                prefixIcon: const Icon(Icons.search, size: 20, color: _textGrey),
                filled: true,
                fillColor: const Color(0xFFF9FAFB),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(999)),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(999),
                  borderSide: const BorderSide(color: _border),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(999),
                  borderSide: const BorderSide(color: _blue, width: 2),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              ),
            ),
          );

          final filters = Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _Pill(
                label: 'Todos',
                selected: statusFilter == 0,
                onTap: () => onStatusChanged(0),
              ),
              _Pill(
                label: 'Activos',
                selected: statusFilter == 1,
                onTap: () => onStatusChanged(1),
              ),
              _Pill(
                label: 'De baja',
                selected: statusFilter == 2,
                onTap: () => onStatusChanged(2),
              ),
            ],
          );

          if (compact) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Administra tu equipo de trabajo',
                  style: TextStyle(color: _textGrey, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 10),
                search,
                const SizedBox(height: 12),
                filters,
              ],
            );
          }

          return Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Text(
                      'Administra tu equipo de trabajo',
                      style: TextStyle(color: _textGrey, fontWeight: FontWeight.w600),
                    ),
                    SizedBox(height: 8),
                  ],
                ),
              ),
              search,
              const SizedBox(width: 12),
              filters,
            ],
          );
        },
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  static const Color _border = Color(0xFFE5E7EB);
  static const Color _textDark = Color(0xFF111827);
  static const Color _blue = Color(0xFF2563EB);

  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _Pill({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? _blue : Colors.white,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: selected ? Colors.transparent : _border),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.white : _textDark,
            fontWeight: FontWeight.w800,
            fontSize: 12,
          ),
        ),
      ),
    );
  }
}

class _WorkerCard extends StatelessWidget {
  static const Color _border = Color(0xFFE5E7EB);
  static const Color _textDark = Color(0xFF111827);
  static const Color _textGrey = Color(0xFF6B7280);
  static const Color _blue = Color(0xFF2563EB);

  final Trabajador trabajador;
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
    final initials = _initials(trabajador.nombre, trabajador.apellidos);

    final puesto = (trabajador.puesto.isNotEmpty) ? trabajador.puesto : '-';
    final email = (trabajador.correo.isNotEmpty) ? trabajador.correo : '-';
    final phone = (trabajador.telefono.isNotEmpty) ? trabajador.telefono : '-';
    final city = (trabajador.ciudad.isNotEmpty) ? trabajador.ciudad : '-';

    return InkWell(
      borderRadius: BorderRadius.circular(22),
      onTap: onTap,
      child: Container(
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
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top: avatar + nombre/puesto + menu
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(
                    radius: 22,
                    backgroundColor: const Color(0xFFEFF6FF),
                    child: Text(
                      initials,
                      style: const TextStyle(
                        color: _blue,
                        fontWeight: FontWeight.w900,
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
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                            color: _textDark,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          puesto,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: _textGrey,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Menú 3 puntos: Editar / Eliminar (misma funcionalidad)
                  PopupMenuButton<String>(
                    tooltip: 'Opciones',
                    onSelected: (v) async {
                      if (v == 'edit') onEdit();
                      if (v == 'delete') await onDelete();
                    },
                    itemBuilder: (_) => const [
                      PopupMenuItem(value: 'edit', child: Text('Editar')),
                      PopupMenuItem(value: 'delete', child: Text('Eliminar')),
                    ],
                    child: const Padding(
                      padding: EdgeInsets.all(6),
                      child: Icon(Icons.more_vert, color: _textGrey),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 12),

              // Chip estado
              Row(
                children: [
                  _ActivoChip(activo: trabajador.activo),
                  const Spacer(),
                  if (trabajador.tieneVehiculo)
                    _IconTag(
                      icon: Icons.directions_car,
                      label: 'Vehículo',
                      color: const Color(0xFF15803D),
                      bg: const Color(0xFFDCFCE7),
                    )
                  else
                    _IconTag(
                      icon: Icons.close,
                      label: 'Sin vehículo',
                      color: const Color(0xFF6B7280),
                      bg: const Color(0xFFF3F4F6),
                    ),
                ],
              ),

              const SizedBox(height: 14),
              const Divider(height: 1, color: _border),
              const SizedBox(height: 12),

              // Datos (sin horas ni precio)
              _InfoRow(icon: Icons.email_outlined, text: email),
              const SizedBox(height: 10),
              _InfoRow(icon: Icons.phone_outlined, text: phone),
              const SizedBox(height: 10),
              _InfoRow(icon: Icons.location_on_outlined, text: city),

              const Spacer(),

              // Footer “ver más” / editar rápido
              Row(
                children: [
                  Text(
                    'Ver detalles',
                    style: TextStyle(
                      color: _blue.withOpacity(0.9),
                      fontWeight: FontWeight.w900,
                      fontSize: 12,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    tooltip: 'Editar',
                    onPressed: onEdit,
                    icon: const Icon(Icons.edit_outlined, color: _blue),
                  ),
                  IconButton(
                    tooltip: 'Eliminar',
                    onPressed: () async => await onDelete(),
                    icon: const Icon(Icons.delete_outline, color: Color(0xFFB91C1C)),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  static const Color _textGrey = Color(0xFF6B7280);

  final IconData icon;
  final String text;

  const _InfoRow({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: _textGrey),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Color(0xFF374151),
              fontWeight: FontWeight.w600,
            ),
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

  const _IconTag({
    required this.icon,
    required this.label,
    required this.color,
    required this.bg,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w800,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}

// ==========================
// FORMULARIO CREAR / EDITAR (NO TOCADO)
// ==========================

Future<void> _deleteWorker({
  required String empresaId,
  required String trabajadorId,
}) async {
  await FirebaseFirestore.instance
      .collection('empresas')
      .doc(empresaId)
      .collection('trabajadores')
      .doc(trabajadorId)
      .delete();
}

Future<void> _openWorkerForm({
  required BuildContext context,
  Trabajador? trabajador,
}) async {
  const empresaId = AppConfig.empresaId;
  final isEditing = trabajador != null;

  final nombreController = TextEditingController(text: trabajador?.nombre ?? '');
  final apellidosController = TextEditingController(text: trabajador?.apellidos ?? '');
  final emailController = TextEditingController(text: trabajador?.correo ?? '');
  final telefonoController = TextEditingController(text: trabajador?.telefono ?? '');
  final ciudadController = TextEditingController(text: trabajador?.ciudad ?? '');
  final dniController = TextEditingController(text: trabajador?.dni ?? '');
  final edadController = TextEditingController(
    text: trabajador != null && trabajador.edad > 0 ? trabajador.edad.toString() : '',
  );
  final aniosExpController = TextEditingController(
    text: trabajador != null && trabajador.aniosExperiencia > 0
        ? trabajador.aniosExperiencia.toString()
        : '',
  );

  String puesto = trabajador?.puesto.isNotEmpty == true ? trabajador!.puesto : 'camarero';
  bool tieneVehiculo = trabajador?.tieneVehiculo ?? false;
  bool activo = trabajador?.activo ?? true;

  await showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (context) {
      return Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom + 16,
          left: 16,
          right: 16,
          top: 16,
        ),
        child: StatefulBuilder(
          builder: (context, setState) {
            return SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        isEditing ? 'Editar trabajador' : 'Nuevo trabajador',
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                      ),
                      const Spacer(),
                      IconButton(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.close),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: nombreController,
                    decoration: const InputDecoration(labelText: 'Nombre', border: OutlineInputBorder()),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: apellidosController,
                    decoration: const InputDecoration(labelText: 'Apellidos', border: OutlineInputBorder()),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: emailController,
                    decoration: const InputDecoration(
                      labelText: 'Correo electrónico',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.emailAddress,
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: telefonoController,
                    decoration: const InputDecoration(labelText: 'Teléfono', border: OutlineInputBorder()),
                    keyboardType: TextInputType.phone,
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: ciudadController,
                    decoration: const InputDecoration(labelText: 'Ciudad', border: OutlineInputBorder()),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: dniController,
                    decoration: const InputDecoration(labelText: 'DNI', border: OutlineInputBorder()),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: puesto,
                          decoration: const InputDecoration(labelText: 'Puesto', border: OutlineInputBorder()),
                          items: const [
                            DropdownMenuItem(value: 'camarero', child: Text('Camarero')),
                            DropdownMenuItem(value: 'cocinero', child: Text('Cocinero')),
                            DropdownMenuItem(value: 'logistica', child: Text('Logística')),
                            DropdownMenuItem(value: 'limpiador', child: Text('Limpiador')),
                            DropdownMenuItem(value: 'metre', child: Text('Metre')),
                            DropdownMenuItem(value: 'coordinador', child: Text('Coordinador')),
                          ],
                          onChanged: (v) {
                            if (v != null) setState(() => puesto = v);
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: edadController,
                          decoration: const InputDecoration(labelText: 'Edad', border: OutlineInputBorder()),
                          keyboardType: TextInputType.number,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: aniosExpController,
                    decoration: const InputDecoration(
                      labelText: 'Años de experiencia',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: 8),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Dispone de vehículo propio'),
                    value: tieneVehiculo,
                    onChanged: (v) => setState(() => tieneVehiculo = v),
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Activo en la empresa'),
                    value: activo,
                    onChanged: (v) => setState(() => activo = v),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () async {
                        final nombre = nombreController.text.trim();
                        final apellidos = apellidosController.text.trim();
                        final correo = emailController.text.trim();
                        final ciudad = ciudadController.text.trim();

                        if (nombre.isEmpty || apellidos.isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Nombre y apellidos son obligatorios')),
                          );
                          return;
                        }

                        final telefono = telefonoController.text.trim();
                        final dni = dniController.text.trim();
                        final edad = int.tryParse(edadController.text.trim()) ?? 0;
                        final aniosExp = int.tryParse(aniosExpController.text.trim()) ?? 0;

                        final nombreLower = '$nombre $apellidos'.toLowerCase();
                        final ciudadLower = ciudad.toLowerCase();

                        final data = <String, dynamic>{
                          'activo': activo,
                          'nombre_lower': nombreLower,
                          'ciudad_lower': ciudadLower,
                          'perfil': {
                            'nombre': nombre,
                            'apellidos': apellidos,
                            'correo': correo,
                            'telefono': telefono,
                            'dni': dni,
                            'ciudad': ciudad,
                          },
                          'laboral': {
                            'puesto': puesto,
                            'edad': edad,
                            'añosExperiencia': aniosExp,
                            'tieneVehiculo': tieneVehiculo,
                          },
                          'creadoEn': FieldValue.serverTimestamp(),
                        };

                        try {
                          final ref = FirebaseFirestore.instance
                              .collection('empresas')
                              .doc(empresaId)
                              .collection('trabajadores');

                          if (isEditing) {
                            await ref.doc(trabajador!.id).update(data);
                          } else {
                            await ref.add(data);
                          }

                          if (context.mounted) {
                            Navigator.of(context).pop();
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text(isEditing ? 'Trabajador actualizado' : 'Trabajador creado')),
                            );
                          }
                        } catch (e) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Error al guardar el trabajador: $e')),
                            );
                          }
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2563EB),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: Text(isEditing ? 'Guardar cambios' : 'Crear trabajador'),
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            );
          },
        ),
      );
    },
  );
}

// ==========================
// HELPERS / WIDGETS
// ==========================

String _initials(String nombre, String apellidos) {
  final n = nombre.isNotEmpty ? nombre.trim().split(' ').first : '';
  final a = apellidos.isNotEmpty ? apellidos.trim().split(' ').first : '';
  final i1 = n.isNotEmpty ? n[0].toUpperCase() : '';
  final i2 = a.isNotEmpty ? a[0].toUpperCase() : '';
  final res = '$i1$i2';
  return res.isEmpty ? '?' : res;
}

class _ActivoChip extends StatelessWidget {
  final bool activo;

  const _ActivoChip({required this.activo});

  @override
  Widget build(BuildContext context) {
    final bg = activo ? const Color(0xFFDCFCE7) : const Color(0xFFFFEDD5);
    final fg = activo ? const Color(0xFF15803D) : const Color(0xFF9A3412);
    final text = activo ? 'Activo' : 'De baja';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w900,
          color: fg,
        ),
      ),
    );
  }
}
