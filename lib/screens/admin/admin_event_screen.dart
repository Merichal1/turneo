import 'package:flutter/material.dart';

import '../../config/app_config.dart';
import '../../core/services/firestore_service.dart';
import '../../models/evento.dart';

const _roleOptions = <String>[
  'Camareros',
  'Cocineros',
  'Logística',
  'Limpiadores',
  'Metres',
  'Coordinadores',
];

class AdminEventScreen extends StatelessWidget {
  const AdminEventScreen({super.key});

  @override
  Widget build(BuildContext context) {
    const empresaId = AppConfig.empresaId;

    return Scaffold(
      backgroundColor: const Color(0xFFF3F4F6),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        title: const Text(
          'Eventos',
          style: TextStyle(
            color: Color(0xFF111827),
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: false,
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openEventForm(context: context),
        icon: const Icon(Icons.add),
        label: const Text('Nuevo evento'),
      ),
      body: StreamBuilder<List<Evento>>(
        stream: FirestoreService.instance.listenEventos(empresaId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting &&
              !snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            final error = snapshot.error;
            return Center(
              child: Text(
                'Error al cargar eventos:\n${error.runtimeType}\n$error',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.red),
              ),
            );
          }

          final eventos = snapshot.data ?? [];

          if (eventos.isEmpty) {
            return const Center(
              child: Text(
                'Todavía no hay eventos.\nPulsa en "Nuevo evento" para crear el primero.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Color(0xFF6B7280),
                ),
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
            itemCount: eventos.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final e = eventos[index];

              final rangoFecha =
                  '${_formatFechaCorta(e.fechaInicio)} · ${_formatHora(e.fechaInicio)} - ${_formatHora(e.fechaFin)}';

              final ubicacion = [
                if (e.ciudad.isNotEmpty) e.ciudad,
                if (e.direccion.isNotEmpty) e.direccion,
              ].join(' · ');

              final totalRoles =
                  e.rolesRequeridos.values.fold<int>(0, (s, v) => s + v);

              return Dismissible(
                key: ValueKey(e.id),
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
                      title: const Text('Eliminar evento'),
                      content: Text(
                        '¿Seguro que quieres eliminar el evento "${e.nombre}"?',
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
                    await FirestoreService.instance.borrarEvento(
                      empresaId,
                      e.id,
                    );
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content:
                            Text('Evento "${e.nombre}" eliminado correctamente'),
                      ),
                    );
                  }
                  return confirmed ?? false;
                },
                child: InkWell(
                  onTap: () => _openEventForm(context: context, evento: e),
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
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                e.nombre,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            _EstadoChip(estado: e.estado),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          rangoFecha,
                          style: const TextStyle(
                            fontSize: 13,
                            color: Color(0xFF4B5563),
                          ),
                        ),
                        if (ubicacion.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(
                            ubicacion,
                            style: const TextStyle(
                              fontSize: 13,
                              color: Color(0xFF6B7280),
                            ),
                          ),
                        ],
                        const SizedBox(height: 4),
                        Text(
                          'Trabajadores necesarios: $totalRoles',
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFF9CA3AF),
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
}

// ==========================
// FORMULARIO CREAR / EDITAR
// ==========================

class _RolCantidad {
  String rol;
  int cantidad;

  _RolCantidad({required this.rol, required this.cantidad});
}

Future<void> _openEventForm({
  required BuildContext context,
  Evento? evento,
}) async {
  final empresaId = AppConfig.empresaId;
  final isEditing = evento != null;

  final nombreController = TextEditingController(text: evento?.nombre ?? '');
  final tipoController = TextEditingController(text: evento?.tipo ?? '');
  final ciudadController = TextEditingController(text: evento?.ciudad ?? '');
  final direccionController =
      TextEditingController(text: evento?.direccion ?? '');

  DateTime inicio =
      evento?.fechaInicio ?? DateTime.now().add(const Duration(days: 1));
  DateTime fin = evento?.fechaFin ?? inicio.add(const Duration(hours: 4));
  String estado = _normalizeEstado(evento?.estado);

  // Roles iniciales desde el evento (mapa {rol: cantidad})
  List<_RolCantidad> roles = [];
  final rolesMap = evento?.rolesRequeridos ?? {};
  if (rolesMap.isNotEmpty) {
    roles = rolesMap.entries
        .map((e) => _RolCantidad(rol: e.key, cantidad: e.value))
        .toList();
  } else {
    // si no hay, empezamos con una fila por defecto
    roles = [
      _RolCantidad(rol: _roleOptions.first, cantidad: 1),
    ];
  }

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
            Future<void> pickInicio() async {
              final result = await _pickDateTime(context, inicio);
              if (result != null) {
                setState(() {
                  inicio = result;
                  if (!result.isBefore(fin)) {
                    fin = result.add(const Duration(hours: 4));
                  }
                });
              }
            }

            Future<void> pickFin() async {
              final result = await _pickDateTime(context, fin);
              if (result != null) {
                setState(() {
                  if (!result.isAfter(inicio)) {
                    fin = inicio.add(const Duration(hours: 1));
                  } else {
                    fin = result;
                  }
                });
              }
            }

            final totalTrabajadores =
                roles.fold<int>(0, (sum, r) => sum + (r.cantidad));

            return SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        isEditing ? 'Editar evento' : 'Nuevo evento',
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
                      labelText: 'Nombre del evento',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: tipoController,
                    decoration: const InputDecoration(
                      labelText: 'Tipo (boda, comunión, corporativo...)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _FechaHoraField(
                          label: 'Inicio',
                          value:
                              '${_formatFechaCorta(inicio)} · ${_formatHora(inicio)}',
                          onTap: pickInicio,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _FechaHoraField(
                          label: 'Fin',
                          value:
                              '${_formatFechaCorta(fin)} · ${_formatHora(fin)}',
                          onTap: pickFin,
                        ),
                      ),
                    ],
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
                    controller: direccionController,
                    decoration: const InputDecoration(
                      labelText: 'Dirección',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // ======== ROLES REQUERIDOS =========
                  const Text(
                    'Roles requeridos',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Column(
                    children: [
                      for (int i = 0; i < roles.length; i++)
                        _RolRow(
                          rolCantidad: roles[i],
                          onRolChanged: (newRol) {
                            setState(() {
                              roles[i].rol = newRol;
                            });
                          },
                          onCantidadChanged: (newCantidad) {
                            setState(() {
                              roles[i].cantidad =
                                  newCantidad < 0 ? 0 : newCantidad;
                            });
                          },
                          onRemove: roles.length == 1
                              ? null
                              : () {
                                  setState(() {
                                    roles.removeAt(i);
                                  });
                                },
                        ),
                      const SizedBox(height: 8),
                      TextButton.icon(
                        onPressed: () {
                          setState(() {
                            roles.add(
                              _RolCantidad(
                                rol: _roleOptions.first,
                                cantidad: 1,
                              ),
                            );
                          });
                        },
                        icon: const Icon(Icons.add),
                        label: const Text('Añadir rol'),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Total trabajadores necesarios: $totalTrabajadores',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF6B7280),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  const Text(
                    'Estado',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  RadioListTile<String>(
                    title: const Text('Activo'),
                    value: 'activo',
                    groupValue: estado,
                    onChanged: (value) {
                      if (value != null) {
                        setState(() => estado = value);
                      }
                    },
                    dense: true,
                  ),
                  RadioListTile<String>(
                    title: const Text('Borrador'),
                    value: 'borrador',
                    groupValue: estado,
                    onChanged: (value) {
                      if (value != null) {
                        setState(() => estado = value);
                      }
                    },
                    dense: true,
                  ),
                  RadioListTile<String>(
                    title: const Text('Cancelado'),
                    value: 'cancelado',
                    groupValue: estado,
                    onChanged: (value) {
                      if (value != null) {
                        setState(() => estado = value);
                      }
                    },
                    dense: true,
                  ),
                  RadioListTile<String>(
                    title: const Text('Finalizado'),
                    value: 'finalizado',
                    groupValue: estado,
                    onChanged: (value) {
                      if (value != null) {
                        setState(() => estado = value);
                      }
                    },
                    dense: true,
                  ),

                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () async {
                        final nombre = nombreController.text.trim();
                        final tipo = tipoController.text.trim();
                        final ciudad = ciudadController.text.trim();
                        final direccion = direccionController.text.trim();

                        if (nombre.isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'El nombre del evento es obligatorio',
                              ),
                            ),
                          );
                          return;
                        }

                        // Construimos mapa {rol: cantidad} limpio
                        final Map<String, int> rolesMap = {};
                        for (final r in roles) {
                          if (r.rol.isEmpty || r.cantidad <= 0) continue;
                          rolesMap[r.rol] =
                              (rolesMap[r.rol] ?? 0) + r.cantidad;
                        }

                        final totalTrabajadores =
                            rolesMap.values.fold<int>(0, (s, v) => s + v);

                        final nuevo = Evento(
                          id: evento?.id ?? '',
                          nombre: nombre,
                          tipo: tipo,
                          fechaInicio: inicio,
                          fechaFin: fin,
                          estado: estado,
                          rolesRequeridos: rolesMap,
                          cantidadRequeridaTrabajadores: totalTrabajadores,
                          ciudad: ciudad,
                          direccion: direccion,
                          creadoPor: evento?.creadoPor ?? 'admin',
                          creadoEn: evento?.creadoEn ?? DateTime.now(),
                        );

                        try {
                          if (isEditing) {
                            await FirestoreService.instance.actualizarEvento(
                              empresaId,
                              nuevo,
                            );
                          } else {
                            await FirestoreService.instance.crearEvento(
                              empresaId,
                              nuevo,
                            );
                          }

                          Navigator.of(context).pop();

                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                isEditing
                                    ? 'Evento actualizado'
                                    : 'Evento creado',
                              ),
                            ),
                          );
                        } catch (e) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                'Error al guardar el evento: $e',
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
                        isEditing ? 'Guardar cambios' : 'Crear evento',
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

String _normalizeEstado(String? raw) {
  const valid = ['activo', 'borrador', 'cancelado', 'finalizado'];
  if (raw == null) return 'activo';
  final lower = raw.toLowerCase();
  if (valid.contains(lower)) return lower;
  return 'activo';
}

class _RolRow extends StatelessWidget {
  final _RolCantidad rolCantidad;
  final ValueChanged<String> onRolChanged;
  final ValueChanged<int> onCantidadChanged;
  final VoidCallback? onRemove;

  const _RolRow({
    required this.rolCantidad,
    required this.onRolChanged,
    required this.onCantidadChanged,
    this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: DropdownButtonFormField<String>(
              value: _roleOptions.contains(rolCantidad.rol)
                  ? rolCantidad.rol
                  : _roleOptions.first,
              items: _roleOptions
                  .map(
                    (r) => DropdownMenuItem(
                      value: r,
                      child: Text(r),
                    ),
                  )
                  .toList(),
              onChanged: (value) {
                if (value != null) onRolChanged(value);
              },
              decoration: const InputDecoration(
                labelText: 'Rol',
                border: OutlineInputBorder(),
              ),
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 80,
            child: TextFormField(
              initialValue: rolCantidad.cantidad.toString(),
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Nº',
                border: OutlineInputBorder(),
              ),
              onChanged: (value) {
                final c = int.tryParse(value) ?? 0;
                onCantidadChanged(c);
              },
            ),
          ),
          if (onRemove != null) ...[
            const SizedBox(width: 4),
            IconButton(
              onPressed: onRemove,
              icon: const Icon(Icons.delete_outline),
              tooltip: 'Quitar rol',
            ),
          ],
        ],
      ),
    );
  }
}

class _FechaHoraField extends StatelessWidget {
  final String label;
  final String value;
  final VoidCallback onTap;

  const _FechaHoraField({
    required this.label,
    required this.value,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
        ),
        child: Text(
          value,
          style: const TextStyle(fontSize: 13),
        ),
      ),
    );
  }
}

class _EstadoChip extends StatelessWidget {
  final String estado;

  const _EstadoChip({required this.estado});

  @override
  Widget build(BuildContext context) {
    Color bg;
    Color fg;
    final e = estado.toLowerCase();

    switch (e) {
      case 'borrador':
        bg = const Color(0xFFE5E7EB);
        fg = const Color(0xFF4B5563);
        break;
      case 'cancelado':
        bg = const Color(0xFFFEF2F2);
        fg = const Color(0xFFB91C1C);
        break;
      case 'finalizado':
        bg = const Color(0xFFDCFCE7);
        fg = const Color(0xFF15803D);
        break;
      case 'activo':
      default:
        bg = const Color(0xFFE0F2FE);
        fg = const Color(0xFF0369A1);
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        e[0].toUpperCase() + e.substring(1),
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w500,
          color: fg,
        ),
      ),
    );
  }
}

String _formatFechaCorta(DateTime d) {
  final dia = d.day.toString().padLeft(2, '0');
  final mes = d.month.toString().padLeft(2, '0');
  final year = d.year.toString();
  return '$dia/$mes/$year';
}

String _formatHora(DateTime d) {
  final h = d.hour.toString().padLeft(2, '0');
  final m = d.minute.toString().padLeft(2, '0');
  return '$h:$m';
}

Future<DateTime?> _pickDateTime(
  BuildContext context,
  DateTime initial,
) async {
  final date = await showDatePicker(
    context: context,
    initialDate: initial,
    firstDate: DateTime(2020),
    lastDate: DateTime(2100),
  );
  if (date == null) return null;

  final time = await showTimePicker(
    context: context,
    initialTime: TimeOfDay.fromDateTime(initial),
  );
  if (time == null) return null;

  return DateTime(
    date.year,
    date.month,
    date.day,
    time.hour,
    time.minute,
  );
}
