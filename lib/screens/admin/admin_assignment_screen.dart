import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../config/app_config.dart';
import '../../core/services/firestore_service.dart';
import '../../models/evento.dart';
import '../../models/trabajador.dart';
import '../../models/disponibilidad_evento.dart';
import '../../widgets/event_map_card.dart';

enum ModoEnvio { roles, grupos, manual }

class _RoleGroup {
  final String id;
  String nombre;
  Set<String> roles;

  _RoleGroup({
    required this.id,
    required this.nombre,
    required this.roles,
  });
}

class AdminAssignmentScreen extends StatefulWidget {
  final Evento? initialEvento;

  const AdminAssignmentScreen({super.key, this.initialEvento});

  @override
  State<AdminAssignmentScreen> createState() => _AdminAssignmentScreenState();
}

class _AdminAssignmentScreenState extends State<AdminAssignmentScreen> {
  final String empresaId = AppConfig.empresaId;

  String? _selectedEventoId;

  /// ✅ Evento seleccionado (para mostrar mapa)
  Evento? _selectedEvento;

  /// ✅ Roles requeridos del evento seleccionado (rol -> cantidad)
  Map<String, int> _rolesRequeridosEvento = {};

  /// ✅ Rango del evento seleccionado (para validar indisponibilidad)
  DateTime? _eventoInicio;
  DateTime? _eventoFin;

  /// ✅ Cache para no consultar 1000 veces en modo manual
  final Map<String, bool> _noDispoCache = {};

  /// ✅ 3 modos
  ModoEnvio _modo = ModoEnvio.roles;

  /// Roles
  final Set<String> _rolesSeleccionados = {};

  /// Grupos (solo memoria)
  final List<_RoleGroup> _grupos = [];
  final Set<String> _gruposSeleccionados = {};

  /// Manual
  final Set<String> _trabajadoresSeleccionados = {};
  String _filtroNombre = "";

  @override
  void initState() {
    super.initState();
    _selectedEvento = widget.initialEvento;
    _selectedEventoId = widget.initialEvento?.id;
    _rolesRequeridosEvento =
        Map<String, int>.from(widget.initialEvento?.rolesRequeridos ?? {});
    _eventoInicio = widget.initialEvento?.fechaInicio;
    _eventoFin = widget.initialEvento?.fechaFin;
  }

  // Normalización robusta (minúsculas + sin tildes básicas)
  String _norm(String s) {
    var x = s.trim().toLowerCase();
    x = x
        .replaceAll('á', 'a')
        .replaceAll('à', 'a')
        .replaceAll('ä', 'a')
        .replaceAll('â', 'a')
        .replaceAll('é', 'e')
        .replaceAll('è', 'e')
        .replaceAll('ë', 'e')
        .replaceAll('ê', 'e')
        .replaceAll('í', 'i')
        .replaceAll('ì', 'i')
        .replaceAll('ï', 'i')
        .replaceAll('î', 'i')
        .replaceAll('ó', 'o')
        .replaceAll('ò', 'o')
        .replaceAll('ö', 'o')
        .replaceAll('ô', 'o')
        .replaceAll('ú', 'u')
        .replaceAll('ù', 'u')
        .replaceAll('ü', 'u')
        .replaceAll('û', 'u')
        .replaceAll('ñ', 'n');
    return x;
  }

  DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  String _dateId(DateTime d) =>
      "${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}";

  List<DateTime> _daysBetweenInclusive(DateTime start, DateTime end) {
    final s = _dateOnly(start);
    final e = _dateOnly(end);
    final days = <DateTime>[];
    var cur = s;
    while (!cur.isAfter(e)) {
      days.add(cur);
      cur = cur.add(const Duration(days: 1));
    }
    return days;
  }

  /// ✅ Manual: devuelve true si el trabajador está NO disponible en cualquier día del evento
  Future<bool> _isNoDisponibleParaEvento(Trabajador t) async {
    final ini = _eventoInicio;
    final fin = _eventoFin ?? _eventoInicio;
    if (ini == null || fin == null) return false;

    final dias = _daysBetweenInclusive(ini, fin);

    for (final day in dias) {
      final key = "${_selectedEventoId ?? 'NONE'}|${t.id}|${_dateId(day)}";
      final cached = _noDispoCache[key];
      if (cached != null) {
        if (cached) return true;
        continue;
      }

      final exists = await FirestoreService.instance.verificarIndisponibilidad(
        empresaId,
        t.id,
        day,
      );

      _noDispoCache[key] = exists;

      if (exists) return true;
    }

    return false;
  }

  /// ✅ Filtra y quita trabajadores que han marcado "NO DISPONIBLE" para cualquiera
  /// de los días del evento (inicio..fin).
  Future<_FiltroIndispoResult> _filtrarPorIndisponibilidad({
    required List<Trabajador> candidatos,
    required DateTime eventoInicio,
    required DateTime eventoFin,
  }) async {
    final fechasEvento = _daysBetweenInclusive(eventoInicio, eventoFin);

    final checks = await Future.wait(candidatos.map((t) async {
      bool noDispo = false;

      for (final f in fechasEvento) {
        final exists =
            await FirestoreService.instance.verificarIndisponibilidad(
          empresaId,
          t.id,
          f,
        );
        if (exists) {
          noDispo = true;
          break;
        }
      }

      return MapEntry(t, noDispo);
    }));

    final disponibles = <Trabajador>[];
    final bloqueados = <Trabajador>[];

    for (final entry in checks) {
      if (entry.value == true) {
        bloqueados.add(entry.key);
      } else {
        disponibles.add(entry.key);
      }
    }

    return _FiltroIndispoResult(disponibles: disponibles, bloqueados: bloqueados);
  }

  /// ✅ Aplica límite por rol según lo requerido en el evento:
  /// si hay 200 camareros y el evento pide 14, selecciona máximo 14.
  List<Trabajador> _limitarPorRolesRequeridos({
    required List<Trabajador> candidatos,
    required Set<String> rolesSeleccionados,
  }) {
    final remaining = <String, int>{};

    for (final r in rolesSeleccionados) {
      final keyExact = _rolesRequeridosEvento.keys.firstWhere(
        (k) => _norm(k) == _norm(r),
        orElse: () => r,
      );
      remaining[keyExact] = (_rolesRequeridosEvento[keyExact] ?? 0);
    }

    for (final r in rolesSeleccionados) {
      final keyExact = remaining.keys.firstWhere(
        (k) => _norm(k) == _norm(r),
        orElse: () => r,
      );
      remaining[keyExact] =
          remaining[keyExact] == 0 ? 999999 : remaining[keyExact]!;
    }

    final list = List<Trabajador>.from(candidatos);
    list.shuffle();

    final result = <Trabajador>[];

    for (final t in list) {
      final rolT = (t.puesto ?? 'Sin Rol').trim();
      final key = remaining.keys.firstWhere(
        (k) => _norm(k) == _norm(rolT),
        orElse: () => '',
      );
      if (key.isEmpty) continue;

      final req = remaining[key] ?? 0;
      if (req > 0) {
        result.add(t);
        remaining[key] = req - 1;
      }
    }

    return result;
  }

  Future<void> _enviarSolicitudes(
      List<Trabajador> todos, List<String> rolesDisponibles) async {
    if (_selectedEventoId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Selecciona un evento primero")),
      );
      return;
    }

    try {
      final todosEventos =
          await FirestoreService.instance.listenEventos(empresaId).first;
      final eventoActual =
          todosEventos.firstWhere((e) => e.id == _selectedEventoId);

      _eventoInicio = eventoActual.fechaInicio;
      _eventoFin = eventoActual.fechaFin;
      _noDispoCache.clear();

      List<Trabajador> candidatos = [];
      Set<String> rolesModo = {};

      if (_modo == ModoEnvio.roles) {
        if (_rolesSeleccionados.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Selecciona al menos un rol")),
          );
          return;
        }

        rolesModo = _rolesSeleccionados.toSet();

        candidatos = todos.where((t) {
          final rolTrabajador = _norm(t.puesto ?? 'Sin Rol');
          return rolesModo.any((r) => _norm(r) == rolTrabajador);
        }).toList();
      }

      if (_modo == ModoEnvio.grupos) {
        if (_gruposSeleccionados.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Selecciona al menos un grupo")),
          );
          return;
        }

        final Set<String> unionRoles = {};
        for (final gid in _gruposSeleccionados) {
          final g = _grupos.firstWhere(
            (x) => x.id == gid,
            orElse: () => _RoleGroup(id: gid, nombre: gid, roles: {}),
          );
          unionRoles.addAll(g.roles);
        }

        if (unionRoles.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text("Los grupos seleccionados no contienen roles")),
          );
          return;
        }

        rolesModo = unionRoles;

        candidatos = todos.where((t) {
          final rolTrabajador = _norm(t.puesto ?? 'Sin Rol');
          return rolesModo.any((r) => _norm(r) == rolTrabajador);
        }).toList();
      }

      if (_modo == ModoEnvio.manual) {
        if (_trabajadoresSeleccionados.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Selecciona al menos un trabajador")),
          );
          return;
        }
        candidatos =
            todos.where((t) => _trabajadoresSeleccionados.contains(t.id)).toList();
      }

      final seen = <String>{};
      candidatos = candidatos.where((t) => seen.add(t.id)).toList();

      if (candidatos.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("No hay trabajadores candidatos")),
        );
        return;
      }

      final filtro = await _filtrarPorIndisponibilidad(
        candidatos: candidatos,
        eventoInicio: eventoActual.fechaInicio,
        eventoFin: eventoActual.fechaFin,
      );

      final bloqueados = filtro.bloqueados;
      var disponibles = filtro.disponibles;

      if (_modo == ModoEnvio.roles || _modo == ModoEnvio.grupos) {
        disponibles = _limitarPorRolesRequeridos(
          candidatos: disponibles,
          rolesSeleccionados: rolesModo,
        );
      }

      if (_modo == ModoEnvio.manual && bloqueados.isNotEmpty) {
        setState(() {
          for (final b in bloqueados) {
            _trabajadoresSeleccionados.remove(b.id);
          }
        });
      }

      if (disponibles.isEmpty) {
        const msg =
            "No se enviaron solicitudes: todos los candidatos marcaron NO disponible.";
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text(msg)));
        return;
      }

      await FirestoreService.instance.crearSolicitudesDisponibilidadParaEvento(
        empresaId: empresaId,
        eventoId: _selectedEventoId!,
        trabajadores: disponibles,
      );

      final batch = FirebaseFirestore.instance.batch();
      for (final t in disponibles) {
        final notifRef = FirebaseFirestore.instance
            .collection('empresas')
            .doc(empresaId)
            .collection('notificaciones')
            .doc();

        batch.set(notifRef, {
          'titulo': 'Nueva solicitud: ${eventoActual.nombre}',
          'body':
              'Se solicita tu disponibilidad para el día ${DateFormat('dd/MM').format(eventoActual.fechaInicio)}',
          'tag': 'Eventos',
          'dirigidoA': t.id,
          'creadoEn': FieldValue.serverTimestamp(),
          'leido': false,
        });
      }
      await batch.commit();

      if (!mounted) return;

      final msg = (bloqueados.isNotEmpty)
          ? "Enviadas a ${disponibles.length}. Omitidos ${bloqueados.length} por NO disponible."
          : "Solicitudes enviadas a ${disponibles.length} trabajadores.";

      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error al procesar el envío: $e")),
      );
    }
  }

  void _ensureGrupoTodos(List<String> rolesDisponibles) {
    final existingIndex = _grupos.indexWhere((g) => g.id == 'ALL');
    if (existingIndex == -1) {
      _grupos.insert(
        0,
        _RoleGroup(id: 'ALL', nombre: 'Todos', roles: rolesDisponibles.toSet()),
      );
    } else {
      _grupos[existingIndex].roles = rolesDisponibles.toSet();
      _grupos[existingIndex].nombre = 'Todos';
      if (existingIndex != 0) {
        final g = _grupos.removeAt(existingIndex);
        _grupos.insert(0, g);
      }
    }
  }

  Future<void> _openCrearGrupoDialog(List<String> rolesDisponibles) async {
    final nameCtrl = TextEditingController();
    final Set<String> rolesTmp = {};

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setMState) => Padding(
            padding: EdgeInsets.only(
              left: 16,
              right: 16,
              top: 16,
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    "Crear grupo",
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),

                  /// ✅ AQUÍ ES TextField (NO Places)
                  TextField(
                    controller: nameCtrl,
                    decoration: const InputDecoration(
                      labelText: "Nombre del grupo",
                      border: OutlineInputBorder(),
                    ),
                  ),

                  const SizedBox(height: 12),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      "Selecciona roles",
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey.shade700,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: rolesDisponibles.map((r) {
                      final selected = rolesTmp.contains(r);
                      return FilterChip(
                        label: Text(r),
                        selected: selected,
                        onSelected: (v) => setMState(() {
                          if (v) {
                            rolesTmp.add(r);
                          } else {
                            rolesTmp.remove(r);
                          }
                        }),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(ctx),
                          child: const Text("CANCELAR"),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () {
                            final nombre = nameCtrl.text.trim();
                            if (nombre.isEmpty || rolesTmp.isEmpty) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    "Pon nombre y selecciona al menos 1 rol",
                                  ),
                                ),
                              );
                              return;
                            }

                            setState(() {
                              final id = DateTime.now()
                                  .millisecondsSinceEpoch
                                  .toString();
                              _grupos.add(
                                _RoleGroup(
                                  id: id,
                                  nombre: nombre,
                                  roles: rolesTmp.toSet(),
                                ),
                              );
                            });

                            Navigator.pop(ctx);
                          },
                          child: const Text("GUARDAR"),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _setModo(ModoEnvio m) {
    setState(() {
      _modo = m;
      if (m != ModoEnvio.roles) _rolesSeleccionados.clear();
      if (m != ModoEnvio.grupos) _gruposSeleccionados.clear();
      if (m != ModoEnvio.manual) _trabajadoresSeleccionados.clear();
      _filtroNombre = "";
    });
  }

  Future<void> _seleccionarFiltradosSoloDisponibles(
      List<Trabajador> trabajadoresFiltrados) async {
    final ids = <String>{};

    for (final t in trabajadoresFiltrados) {
      final noDisponible = await _isNoDisponibleParaEvento(t);
      if (!noDisponible) ids.add(t.id);
    }

    if (!mounted) return;
    setState(() {
      _trabajadoresSeleccionados.addAll(ids);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3F4F6),
      appBar: AppBar(
        title: const Text('Asignación de Personal'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0.5,
      ),
      body: Column(
        children: [
          _buildSelector(),

          /// ✅ MAPA DEL EVENTO (si hay evento seleccionado)
          if (_selectedEvento != null) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: EventMapCard(evento: _selectedEvento!),
            ),
            const SizedBox(height: 12),
          ],

          const Divider(height: 1),
          _buildPanelEnvio(),
          const Divider(height: 1),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Text(
              "RESPUESTAS DE DISPONIBILIDAD",
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: Colors.grey,
              ),
            ),
          ),
          Expanded(child: _buildListaRespuestas()),
        ],
      ),
    );
  }

  Widget _buildSelector() {
    return StreamBuilder<List<Evento>>(
      stream: FirestoreService.instance.listenEventos(empresaId),
      builder: (context, snap) {
        if (!snap.hasData) return const LinearProgressIndicator();

        final eventosActivos =
            snap.data!.where((e) => e.estado != 'cancelado').toList();

        if (_selectedEventoId == null && eventosActivos.isNotEmpty) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            setState(() {
              final ev = eventosActivos.first;
              _selectedEventoId = ev.id;
              _selectedEvento = ev;
              _rolesRequeridosEvento = Map<String, int>.from(ev.rolesRequeridos);
              _eventoInicio = ev.fechaInicio;
              _eventoFin = ev.fechaFin;

              _rolesSeleccionados.clear();
              _gruposSeleccionados.clear();
              _trabajadoresSeleccionados.clear();
              _filtroNombre = "";
              _noDispoCache.clear();
            });
          });
        }

        return Container(
          color: Colors.white,
          padding: const EdgeInsets.all(16),
          child: DropdownButtonFormField<String>(
            value: _selectedEventoId,
            decoration: const InputDecoration(
              labelText: "Seleccionar Evento",
              border: OutlineInputBorder(),
            ),
            items: eventosActivos
                .map((e) => DropdownMenuItem(value: e.id, child: Text(e.nombre)))
                .toList(),
            onChanged: (v) {
              if (v == null) return;
              final ev = eventosActivos.firstWhere((e) => e.id == v);
              setState(() {
                _selectedEventoId = v;
                _selectedEvento = ev;
                _rolesRequeridosEvento = Map<String, int>.from(ev.rolesRequeridos);
                _eventoInicio = ev.fechaInicio;
                _eventoFin = ev.fechaFin;

                _rolesSeleccionados.clear();
                _gruposSeleccionados.clear();
                _trabajadoresSeleccionados.clear();
                _filtroNombre = "";
                _noDispoCache.clear();
              });
            },
          ),
        );
      },
    );
  }

  Widget _buildPanelEnvio() {
    return StreamBuilder<List<Trabajador>>(
      stream: FirestoreService.instance.listenTrabajadores(empresaId),
      builder: (context, snap) {
        if (!snap.hasData) return const SizedBox();
        final trabajadores = snap.data!;

        final rolesDisponibles = _rolesRequeridosEvento.keys.toList()..sort();

        if (rolesDisponibles.isEmpty) {
          return Container(
            color: Colors.white,
            padding: const EdgeInsets.all(16),
            child: const Text(
              "Este evento no tiene roles definidos. Edita el evento y añade cantidades por rol.",
              style: TextStyle(color: Colors.red),
            ),
          );
        }

        _ensureGrupoTodos(rolesDisponibles);

        final trabajadoresFiltrados = trabajadores
            .where((t) => t.nombre.toLowerCase().contains(_filtroNombre.toLowerCase()))
            .toList()
          ..sort((a, b) => a.nombre.compareTo(b.nombre));

        return Container(
          color: Colors.white,
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Row(
                children: [
                  ChoiceChip(
                    label: const Text("Roles"),
                    selected: _modo == ModoEnvio.roles,
                    onSelected: (_) => _setModo(ModoEnvio.roles),
                  ),
                  const SizedBox(width: 8),
                  ChoiceChip(
                    label: const Text("Grupos"),
                    selected: _modo == ModoEnvio.grupos,
                    onSelected: (_) => _setModo(ModoEnvio.grupos),
                  ),
                  const SizedBox(width: 8),
                  ChoiceChip(
                    label: const Text("Manual"),
                    selected: _modo == ModoEnvio.manual,
                    onSelected: (_) => _setModo(ModoEnvio.manual),
                  ),
                  const Spacer(),
                  ElevatedButton.icon(
                    onPressed: () => _enviarSolicitudes(trabajadores, rolesDisponibles),
                    icon: const Icon(Icons.send),
                    label: const Text("ENVIAR"),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              if (_modo == ModoEnvio.roles) ...[
                Row(
                  children: [
                    ActionChip(
                      label: const Text("Todos los roles"),
                      onPressed: () => setState(() {
                        _rolesSeleccionados
                          ..clear()
                          ..addAll(rolesDisponibles);
                      }),
                    ),
                    const SizedBox(width: 8),
                    ActionChip(
                      label: const Text("Limpiar"),
                      onPressed: () => setState(() => _rolesSeleccionados.clear()),
                    ),
                    const Spacer(),
                    Text(
                      "${_rolesSeleccionados.length}/${rolesDisponibles.length}",
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  children: rolesDisponibles.map((r) {
                    final req = _rolesRequeridosEvento[r] ?? 0;
                    return FilterChip(
                      label: Text("$r ($req)"),
                      selected: _rolesSeleccionados.contains(r),
                      onSelected: (v) => setState(() {
                        if (v) {
                          _rolesSeleccionados.add(r);
                        } else {
                          _rolesSeleccionados.remove(r);
                        }
                      }),
                    );
                  }).toList(),
                ),
              ],

              if (_modo == ModoEnvio.grupos) ...[
                Row(
                  children: [
                    OutlinedButton.icon(
                      onPressed: () => _openCrearGrupoDialog(rolesDisponibles),
                      icon: const Icon(Icons.add),
                      label: const Text("Crear grupo"),
                    ),
                    const SizedBox(width: 8),
                    TextButton(
                      onPressed: () => setState(() {
                        _gruposSeleccionados
                          ..clear()
                          ..add('ALL');
                      }),
                      child: const Text("Seleccionar: Todos"),
                    ),
                    const Spacer(),
                    TextButton(
                      onPressed: () => setState(() => _gruposSeleccionados.clear()),
                      child: const Text("Limpiar"),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  children: _grupos.map((g) {
                    final selected = _gruposSeleccionados.contains(g.id);
                    return FilterChip(
                      label: Text(g.nombre),
                      selected: selected,
                      onSelected: (v) => setState(() {
                        if (v) {
                          _gruposSeleccionados.add(g.id);
                        } else {
                          _gruposSeleccionados.remove(g.id);
                        }
                      }),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 8),
                Builder(
                  builder: (_) {
                    final Set<String> unionRoles = {};
                    for (final gid in _gruposSeleccionados) {
                      final g = _grupos.firstWhere(
                        (x) => x.id == gid,
                        orElse: () => _RoleGroup(id: gid, nombre: gid, roles: {}),
                      );
                      unionRoles.addAll(g.roles);
                    }
                    final rolesTxt = unionRoles.toList()..sort();
                    return Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        "Roles incluidos: ${rolesTxt.isEmpty ? '—' : rolesTxt.join(', ')}",
                        style: const TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                    );
                  },
                ),
              ],

              if (_modo == ModoEnvio.manual) ...[
                /// ✅ AQUÍ ES TextField (NO Places)
                TextField(
                  decoration: const InputDecoration(
                    hintText: "Buscar por nombre...",
                    prefixIcon: Icon(Icons.search),
                  ),
                  onChanged: (v) => setState(() => _filtroNombre = v),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    TextButton(
                      onPressed: () =>
                          _seleccionarFiltradosSoloDisponibles(trabajadoresFiltrados),
                      child: const Text("Seleccionar filtrados"),
                    ),
                    TextButton(
                      onPressed: () => setState(() => _trabajadoresSeleccionados.clear()),
                      child: const Text("Limpiar"),
                    ),
                    const Spacer(),
                    Text(
                      "${_trabajadoresSeleccionados.length} seleccionados",
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ],
                ),
                SizedBox(
                  height: 220,
                  child: ListView.builder(
                    itemCount: trabajadoresFiltrados.length,
                    itemBuilder: (context, i) {
                      final t = trabajadoresFiltrados[i];

                      return FutureBuilder<bool>(
                        future: _isNoDisponibleParaEvento(t),
                        builder: (context, snapNo) {
                          final noDisponible = snapNo.data == true;
                          final selected = _trabajadoresSeleccionados.contains(t.id);

                          return CheckboxListTile(
                            dense: true,
                            value: noDisponible ? false : selected,
                            title: Text(
                              t.nombre,
                              style: TextStyle(
                                color: noDisponible ? Colors.grey : null,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            subtitle: Text(
                              noDisponible ? "NO DISPONIBLE" : (t.puesto ?? 'Sin Rol'),
                              style: TextStyle(color: noDisponible ? Colors.red : null),
                            ),
                            onChanged: noDisponible
                                ? null
                                : (v) => setState(() {
                                      if (v == true) {
                                        _trabajadoresSeleccionados.add(t.id);
                                      } else {
                                        _trabajadoresSeleccionados.remove(t.id);
                                      }
                                    }),
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildListaRespuestas() {
    if (_selectedEventoId == null) {
      return const Center(child: Text("Selecciona un evento para ver respuestas"));
    }

    return StreamBuilder<List<DisponibilidadEvento>>(
      stream: FirestoreService.instance.listenDisponibilidadEvento(
        empresaId,
        _selectedEventoId!,
      ),
      builder: (context, snap) {
        if (!snap.hasData) return const Center(child: CircularProgressIndicator());
        final lista = snap.data!;
        if (lista.isEmpty) return const Center(child: Text("No hay solicitudes enviadas aún"));

        return ListView.builder(
          itemCount: lista.length,
          itemBuilder: (context, i) {
            final d = lista[i];

            return ListTile(
              leading: Icon(
                d.estado == 'aceptado'
                    ? Icons.check_circle
                    : d.estado == 'rechazado'
                        ? Icons.cancel
                        : Icons.help,
                color: d.estado == 'aceptado'
                    ? Colors.green
                    : d.estado == 'rechazado'
                        ? Colors.red
                        : Colors.orange,
              ),
              title: Text(d.trabajadorNombre),
              subtitle: Text(d.estado.toUpperCase()),
              trailing: d.asignado
                  ? const Text(
                      "ASIGNADO",
                      style: TextStyle(color: Colors.blue, fontWeight: FontWeight.bold),
                    )
                  : d.estado == 'aceptado'
                      ? ElevatedButton(
                          onPressed: () => FirestoreService.instance.marcarTrabajadorAsignado(
                            empresaId: empresaId,
                            eventoId: _selectedEventoId!,
                            disponibilidadId: d.id,
                            asignado: true,
                          ),
                          child: const Text("Asignar"),
                        )
                      : null,
            );
          },
        );
      },
    );
  }
}

class _FiltroIndispoResult {
  final List<Trabajador> disponibles;
  final List<Trabajador> bloqueados;

  _FiltroIndispoResult({
    required this.disponibles,
    required this.bloqueados,
  });
}
