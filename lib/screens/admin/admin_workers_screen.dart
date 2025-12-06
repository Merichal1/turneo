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
  final TextEditingController _searchController = TextEditingController();
  String _searchTerm = '';

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
        .map(
          (snap) => snap.docs
              .map((d) => Trabajador.fromFirestore(d))
              .toList(),
        );

    return Scaffold(
      backgroundColor: const Color(0xFFF3F4F6),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        title: const Text(
          'Trabajadores',
          style: TextStyle(
            color: Color(0xFF111827),
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: false,
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openWorkerForm(context: context),
        icon: const Icon(Icons.add),
        label: const Text('Nuevo'),
      ),
      body: StreamBuilder<List<Trabajador>>(
        stream: stream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting &&
              !snapshot.hasData) {
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

          // ===== FILTRADO POR NOMBRE =====
          final trabajadores = _searchTerm.isEmpty
              ? todos
              : todos
                  .where(
                    (t) => t.nombreCompleto
                        .toLowerCase()
                        .contains(_searchTerm),
                  )
                  .toList();

          if (trabajadores.isEmpty) {
            return const Center(
              child: Text(
                'No se han encontrado trabajadores con ese nombre.\n'
                'Prueba a cambiar el filtro o añade uno nuevo.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Color(0xFF6B7280),
                ),
              ),
            );
          }

          return Column(
            children: [
              // ===== BARRA DE BÚSQUEDA =====
              Container(
                color: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                child: Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Lista de usuarios',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF111827),
                        ),
                      ),
                    ),
                    SizedBox(
                      width: 260,
                      child: TextField(
                        controller: _searchController,
                        onChanged: (value) {
                          setState(() {
                            _searchTerm = value.trim().toLowerCase();
                          });
                        },
                        decoration: InputDecoration(
                          isDense: true,
                          hintText: 'Buscar por nombre...',
                          prefixIcon: const Icon(Icons.search, size: 18),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(999),
                          ),
                          contentPadding:
                              const EdgeInsets.symmetric(horizontal: 12),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1, thickness: 1),
              // ===== CABECERA TIPO TABLA =====
              Container(
                color: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                child: Row(
                  children: const [
                    SizedBox(
                      width: 260,
                      child: Text(
                        'Nombre / Correo',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF6B7280),
                        ),
                      ),
                    ),
                    SizedBox(
                      width: 120,
                      child: Text(
                        'Ciudad',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF6B7280),
                        ),
                      ),
                    ),
                    SizedBox(
                      width: 120,
                      child: Text(
                        'Puesto',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF6B7280),
                        ),
                      ),
                    ),
                    SizedBox(
                      width: 70,
                      child: Text(
                        'Edad',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF6B7280),
                        ),
                      ),
                    ),
                    SizedBox(
                      width: 90,
                      child: Text(
                        'Años exp.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF6B7280),
                        ),
                      ),
                    ),
                    SizedBox(
                      width: 120,
                      child: Text(
                        'DNI',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF6B7280),
                        ),
                      ),
                    ),
                    SizedBox(
                      width: 130,
                      child: Text(
                        'Teléfono',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF6B7280),
                        ),
                      ),
                    ),
                    SizedBox(
                      width: 80,
                      child: Text(
                        'Vehículo',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF6B7280),
                        ),
                      ),
                    ),
                    SizedBox(width: 48), // iconos editar/borrar
                  ],
                ),
              ),
              const Divider(height: 1, thickness: 1),
              // ===== LISTA DE FILAS =====
              Expanded(
                child: ListView.separated(
                  itemCount: trabajadores.length,
                  separatorBuilder: (_, __) =>
                      const Divider(height: 1, thickness: 0.4),
                  itemBuilder: (context, index) {
                    final t = trabajadores[index];

                    final rowColor = index.isEven
                        ? const Color(0xFFFFFFFF)
                        : const Color(0xFFF9FAFB);

                    return InkWell(
                      onTap: () => _openWorkerForm(
                        context: context,
                        trabajador: t,
                      ),
                      child: Container(
                        color: rowColor,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 10,
                        ),
                        child: Row(
                          children: [
                            // Nombre + correo + estado
                            SizedBox(
                              width: 260,
                              child: Row(
                                children: [
                                  CircleAvatar(
                                    radius: 18,
                                    backgroundColor: const Color(0xFFE5E7EB),
                                    child: Text(
                                      _initials(t.nombre, t.apellidos),
                                      style: const TextStyle(
                                        color: Color(0xFF111827),
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Expanded(
                                              child: Text(
                                                t.nombreCompleto,
                                                overflow: TextOverflow.ellipsis,
                                                style: const TextStyle(
                                                  fontSize: 14,
                                                  fontWeight: FontWeight.w600,
                                                  color: Color(0xFF111827),
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 4),
                                            _ActivoChip(activo: t.activo),
                                          ],
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          t.correo,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            fontSize: 11,
                                            color: Color(0xFF6B7280),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            // Ciudad
                            SizedBox(
                              width: 120,
                              child: Text(
                                t.ciudad.isNotEmpty ? t.ciudad : '-',
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: Color(0xFF4B5563),
                                ),
                              ),
                            ),
                            // Puesto
                            SizedBox(
                              width: 120,
                              child: Text(
                                t.puesto.isNotEmpty ? t.puesto : '-',
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: Color(0xFF4B5563),
                                ),
                              ),
                            ),
                            // Edad
                            SizedBox(
                              width: 70,
                              child: Text(
                                t.edad > 0 ? '${t.edad}' : '-',
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: Color(0xFF4B5563),
                                ),
                              ),
                            ),
                            // Años experiencia
                            SizedBox(
                              width: 90,
                              child: Text(
                                t.aniosExperiencia > 0
                                    ? '${t.aniosExperiencia}'
                                    : '-',
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: Color(0xFF4B5563),
                                ),
                              ),
                            ),
                            // DNI
                            SizedBox(
                              width: 120,
                              child: Text(
                                t.dni.isNotEmpty ? t.dni : '-',
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: Color(0xFF4B5563),
                                ),
                              ),
                            ),
                            // Teléfono
                            SizedBox(
                              width: 130,
                              child: Text(
                                t.telefono.isNotEmpty ? t.telefono : '-',
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: Color(0xFF4B5563),
                                ),
                              ),
                            ),
                            // Vehículo
                            SizedBox(
                              width: 80,
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    t.tieneVehiculo
                                        ? Icons.directions_car
                                        : Icons.close,
                                    size: 18,
                                    color: t.tieneVehiculo
                                        ? const Color(0xFF15803D)
                                        : const Color(0xFF9CA3AF),
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    t.tieneVehiculo ? 'Sí' : 'No',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: Color(0xFF4B5563),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            // Icono editar
                            IconButton(
                              onPressed: () => _openWorkerForm(
                                context: context,
                                trabajador: t,
                              ),
                              icon: const Icon(Icons.edit_outlined, size: 20),
                              tooltip: 'Editar',
                            ),
                            // Icono borrar
                            IconButton(
                              onPressed: () async {
                                final confirmed = await showDialog<bool>(
                                  context: context,
                                  builder: (context) => AlertDialog(
                                    title: const Text('Eliminar trabajador'),
                                    content: Text(
                                      '¿Seguro que quieres eliminar a "${t.nombreCompleto}"?',
                                    ),
                                    actions: [
                                      TextButton(
                                        onPressed: () =>
                                            Navigator.pop(context, false),
                                        child: const Text('Cancelar'),
                                      ),
                                      TextButton(
                                        onPressed: () =>
                                            Navigator.pop(context, true),
                                        style: TextButton.styleFrom(
                                          foregroundColor: Colors.red,
                                        ),
                                        child: const Text('Eliminar'),
                                      ),
                                    ],
                                  ),
                                );
                                if (confirmed == true) {
                                  await _deleteWorker(
                                    empresaId: empresaId,
                                    trabajadorId: t.id,
                                  );
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          'Trabajador "${t.nombreCompleto}" eliminado',
                                        ),
                                      ),
                                    );
                                  }
                                }
                              },
                              icon: const Icon(Icons.delete_outline, size: 20),
                              tooltip: 'Eliminar',
                            ),
                          ],
                        ),
                      ),
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
}

// ==========================
// FORMULARIO CREAR / EDITAR
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

  final nombreController =
      TextEditingController(text: trabajador?.nombre ?? '');
  final apellidosController =
      TextEditingController(text: trabajador?.apellidos ?? '');
  final emailController =
      TextEditingController(text: trabajador?.correo ?? '');
  final telefonoController =
      TextEditingController(text: trabajador?.telefono ?? '');
  final ciudadController =
      TextEditingController(text: trabajador?.ciudad ?? '');
  final dniController = TextEditingController(text: trabajador?.dni ?? '');
  final edadController = TextEditingController(
    text: trabajador != null && trabajador.edad > 0
        ? trabajador.edad.toString()
        : '',
  );
  final aniosExpController = TextEditingController(
    text: trabajador != null && trabajador.aniosExperiencia > 0
        ? trabajador.aniosExperiencia.toString()
        : '',
  );

  String puesto = trabajador?.puesto.isNotEmpty == true
      ? trabajador!.puesto
      : 'camarero';
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
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
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
                    decoration: const InputDecoration(
                      labelText: 'Nombre',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: apellidosController,
                    decoration: const InputDecoration(
                      labelText: 'Apellidos',
                      border: OutlineInputBorder(),
                    ),
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
                    decoration: const InputDecoration(
                      labelText: 'Teléfono',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.phone,
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: ciudadController,
                    decoration: const InputDecoration(
                      labelText: 'Ciudad',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: dniController,
                    decoration: const InputDecoration(
                      labelText: 'DNI',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: puesto,
                          decoration: const InputDecoration(
                            labelText: 'Puesto',
                            border: OutlineInputBorder(),
                          ),
                          items: const [
                            DropdownMenuItem(
                                value: 'camarero', child: Text('Camarero')),
                            DropdownMenuItem(
                                value: 'cocinero', child: Text('Cocinero')),
                            DropdownMenuItem(
                                value: 'logistica', child: Text('Logística')),
                            DropdownMenuItem(
                                value: 'limpiador', child: Text('Limpiador')),
                            DropdownMenuItem(
                                value: 'metre', child: Text('Metre')),
                            DropdownMenuItem(
                                value: 'coordinador',
                                child: Text('Coordinador')),
                          ],
                          onChanged: (v) {
                            if (v != null) {
                              setState(() => puesto = v);
                            }
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: edadController,
                          decoration: const InputDecoration(
                            labelText: 'Edad',
                            border: OutlineInputBorder(),
                          ),
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
                    onChanged: (v) {
                      setState(() => tieneVehiculo = v);
                    },
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Activo en la empresa'),
                    value: activo,
                    onChanged: (v) {
                      setState(() => activo = v);
                    },
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
                            const SnackBar(
                              content: Text(
                                'Nombre y apellidos son obligatorios',
                              ),
                            ),
                          );
                          return;
                        }

                        final telefono = telefonoController.text.trim();
                        final dni = dniController.text.trim();
                        final edad =
                            int.tryParse(edadController.text.trim()) ?? 0;
                        final aniosExp =
                            int.tryParse(aniosExpController.text.trim()) ?? 0;

                        final nombreLower =
                            '$nombre $apellidos'.toLowerCase();
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
                            // Alta solo en Firestore (no crea usuario Auth)
                            await ref.add(data);
                          }

                          if (context.mounted) {
                            Navigator.of(context).pop();
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  isEditing
                                      ? 'Trabajador actualizado'
                                      : 'Trabajador creado',
                                ),
                              ),
                            );
                          }
                        } catch (e) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  'Error al guardar el trabajador: $e',
                                ),
                              ),
                            );
                          }
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          vertical: 14,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        isEditing ? 'Guardar cambios' : 'Crear trabajador',
                      ),
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
    final bg = activo ? const Color(0xFFDCFCE7) : const Color(0xFFF3F4F6);
    final fg = activo ? const Color(0xFF15803D) : const Color(0xFF6B7280);
    final text = activo ? 'Activo' : 'Inactivo';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w500,
          color: fg,
        ),
      ),
    );
  }
}
