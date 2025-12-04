import 'package:flutter/material.dart';

import '../../config/app_config.dart';
import '../../core/services/firestore_service.dart';
import '../../models/trabajador.dart';

class AdminWorkersScreen extends StatelessWidget {
  const AdminWorkersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    const empresaId = AppConfig.empresaId;

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
        label: const Text('Nuevo trabajador'),
      ),
      body: StreamBuilder<List<Trabajador>>(
        stream: FirestoreService.instance.listenTrabajadores(
          empresaId,
          soloActivos: false,
        ),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting &&
              !snapshot.hasData) {
            return const Center(
              child: CircularProgressIndicator(),
            );
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

          final trabajadores = snapshot.data ?? [];

          if (trabajadores.isEmpty) {
            return const Center(
              child: Text(
                'Todavía no hay trabajadores.\nPulsa en "Nuevo trabajador" para crear el primero.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Color(0xFF6B7280),
                ),
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
            itemCount: trabajadores.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final t = trabajadores[index];
              final fullName = [
                t.nombre,
                t.apellidos,
              ].where((s) => s.trim().isNotEmpty).join(' ');
              final subtitleLines = <String>[];

              if (t.correo.isNotEmpty) subtitleLines.add(t.correo);
              if (t.telefono.isNotEmpty) subtitleLines.add(t.telefono);
              if (t.puesto.isNotEmpty || t.ciudad.isNotEmpty) {
                final partes = [
                  if (t.puesto.isNotEmpty) t.puesto,
                  if (t.ciudad.isNotEmpty) t.ciudad,
                ];
                subtitleLines.add(partes.join(' · '));
              }

              return Dismissible(
                key: ValueKey(t.id),
                direction: DismissDirection.endToStart,
                background: Container(
                  alignment: Alignment.centerRight,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  decoration: BoxDecoration(
                    color: Colors.red.shade600,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(Icons.delete, color: Colors.white),
                ),
                confirmDismiss: (_) async {
                  final confirmed = await showDialog<bool>(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: const Text('Eliminar trabajador'),
                      content: Text(
                        '¿Seguro que quieres eliminar a "$fullName"? Esta acción no se puede deshacer.',
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context, false),
                          child: const Text('Cancelar'),
                        ),
                        TextButton(
                          onPressed: () => Navigator.pop(context, true),
                          style: TextButton.styleFrom(
                            foregroundColor: Colors.red,
                          ),
                          child: const Text('Eliminar'),
                        ),
                      ],
                    ),
                  );
                  if (confirmed == true) {
                    await FirestoreService.instance.borrarTrabajador(
                      empresaId,
                      t.id,
                    );
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Trabajador "$fullName" eliminado'),
                      ),
                    );
                  }
                  return confirmed ?? false;
                },
                child: InkWell(
                  onTap: () =>
                      _openWorkerForm(context: context, trabajador: t),
                  borderRadius: BorderRadius.circular(14),
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.04),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        CircleAvatar(
                          radius: 20,
                          child: Text(
                            (t.nombre.isNotEmpty
                                    ? t.nombre[0]
                                    : fullName.isNotEmpty
                                        ? fullName[0]
                                        : '?')
                                .toUpperCase(),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      fullName.isNotEmpty
                                          ? fullName
                                          : 'Sin nombre',
                                      style: const TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 3,
                                    ),
                                    decoration: BoxDecoration(
                                      color: t.activo
                                          ? const Color(0xFFDCFCE7)
                                          : const Color(0xFFF3F4F6),
                                      borderRadius: BorderRadius.circular(999),
                                    ),
                                    child: Text(
                                      t.activo ? 'Activo' : 'Inactivo',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w500,
                                        color: t.activo
                                            ? const Color(0xFF15803D)
                                            : const Color(0xFF6B7280),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              if (subtitleLines.isNotEmpty)
                                Text(
                                  subtitleLines.join('\n'),
                                  style: const TextStyle(
                                    fontSize: 13,
                                    color: Color(0xFF4B5563),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Future<void> _openWorkerForm({
    required BuildContext context,
    Trabajador? trabajador,
  }) async {
    final empresaId = AppConfig.empresaId;
    final isEditing = trabajador != null;

    final nombreController =
        TextEditingController(text: trabajador?.nombre ?? '');
    final apellidosController =
        TextEditingController(text: trabajador?.apellidos ?? '');
    final correoController =
        TextEditingController(text: trabajador?.correo ?? '');
    final telefonoController =
        TextEditingController(text: trabajador?.telefono ?? '');
    final ciudadController =
        TextEditingController(text: trabajador?.ciudad ?? '');
    final puestoController =
        TextEditingController(text: trabajador?.puesto ?? '');
    final experienciaController = TextEditingController(
      text: (trabajador?.aniosExperiencia ?? 0) > 0
          ? (trabajador!.aniosExperiencia).toString()
          : '',
    );
    final edadController = TextEditingController(
      text: (trabajador?.edad ?? 0) > 0 ? (trabajador!.edad).toString() : '',
    );
    bool activo = trabajador?.activo ?? true;
    bool tieneVehiculo = trabajador?.tieneVehiculo ?? false;

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
                          isEditing
                              ? 'Editar trabajador'
                              : 'Nuevo trabajador',
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
                      controller: correoController,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(
                        labelText: 'Correo',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: telefonoController,
                      keyboardType: TextInputType.phone,
                      decoration: const InputDecoration(
                        labelText: 'Teléfono',
                        border: OutlineInputBorder(),
                      ),
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
                      controller: puestoController,
                      decoration: const InputDecoration(
                        labelText: 'Puesto / Rol',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: experienciaController,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'Años de experiencia',
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextField(
                            controller: edadController,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'Edad',
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Activo'),
                      value: activo,
                      onChanged: (value) {
                        setState(() {
                          activo = value;
                        });
                      },
                    ),
                    CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Tiene vehículo propio'),
                      value: tieneVehiculo,
                      onChanged: (value) {
                        setState(() {
                          tieneVehiculo = value ?? false;
                        });
                      },
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () async {
                          final nombre = nombreController.text.trim();
                          final apellidos =
                              apellidosController.text.trim();
                          final correo = correoController.text.trim();
                          final telefono = telefonoController.text.trim();
                          final ciudad = ciudadController.text.trim();
                          final puesto = puestoController.text.trim();
                          final expText =
                              experienciaController.text.trim();
                          final edadText = edadController.text.trim();

                          if (nombre.isEmpty || correo.isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Nombre y correo son obligatorios',
                                ),
                              ),
                            );
                            return;
                          }

                          int exp = int.tryParse(expText) ?? 0;
                          int edad = int.tryParse(edadText) ?? 0;

                          final nuevo = Trabajador(
                            id: trabajador?.id ?? '',
                            activo: activo,
                            nombre: nombre,
                            apellidos: apellidos,
                            dni: trabajador?.dni ?? '',
                            correo: correo,
                            telefono: telefono,
                            ciudad: ciudad,
                            puesto: puesto,
                            aniosExperiencia: exp,
                            tieneVehiculo: tieneVehiculo,
                            edad: edad,
                            nombreLower: nombre.toLowerCase(),
                            ciudadLower: ciudad.toLowerCase(),
                          );

                          try {
                            if (isEditing) {
                              await FirestoreService.instance
                                  .actualizarTrabajador(
                                empresaId,
                                nuevo,
                              );
                            } else {
                              await FirestoreService.instance
                                  .crearTrabajador(
                                empresaId,
                                nuevo,
                              );
                            }

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
                          } catch (e) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  'Error al guardar: $e',
                                ),
                              ),
                            );
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
}
