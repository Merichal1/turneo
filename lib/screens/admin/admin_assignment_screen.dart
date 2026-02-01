import 'package:flutter/material.dart';
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
  // 🎨 Turneo Style Config
  static const Color _bg = Color(0xFFF6F8FC);
  static const Color _card = Colors.white;
  static const Color _border = Color(0xFFE5E7EB);
  static const Color _textDark = Color(0xFF111827);
  static const Color _textGrey = Color(0xFF6B7280);
  static const Color _blue = Color(0xFF2563EB);

  final String empresaId = AppConfig.empresaId;

  String? _selectedEventoId;
  Evento? _selectedEvento;
  Map<String, int> _rolesRequeridosEvento = {};

  DateTime? _eventoInicio;
  DateTime? _eventoFin;

  final Map<String, bool> _noDispoCache = {};
  ModoEnvio _modo = ModoEnvio.roles;

  final Set<String> _rolesSeleccionados = {};
  final List<_RoleGroup> _grupos = [];
  final Set<String> _gruposSeleccionados = {};
  final Set<String> _trabajadoresSeleccionados = {};
  String _filtroNombre = "";

  bool _autoAsignando = false;

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

  // --- NORMALIZACIÓN ---
  String _norm(String s) {
    var x = s.trim().toLowerCase();
    return x.replaceAllMapped(RegExp(r'[áàäâéèëêíìïîóòöôúùüûñ]'), (match) {
      switch (match.group(0)) {
        case 'á':
        case 'à':
        case 'ä':
        case 'â':
          return 'a';
        case 'é':
        case 'è':
        case 'ë':
        case 'ê':
          return 'e';
        case 'í':
        case 'ì':
        case 'ï':
        case 'î':
          return 'i';
        case 'ó':
        case 'ò':
        case 'ö':
        case 'ô':
          return 'o';
        case 'ú':
        case 'ù':
        case 'ü':
        case 'û':
          return 'u';
        case 'ñ':
          return 'n';
        default:
          return match.group(0)!;
      }
    });
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

  Future<bool> _isNoDisponibleParaEvento(Trabajador t) async {
    final ini = _eventoInicio;
    final fin = _eventoFin ?? _eventoInicio;
    if (ini == null || fin == null) return false;

    final dias = _daysBetweenInclusive(ini, fin);

    for (final day in dias) {
      final key = "${_selectedEventoId ?? 'NONE'}|${t.id}|${_dateId(day)}";
      if (_noDispoCache[key] != null) return _noDispoCache[key]!;

      final exists = await FirestoreService.instance
          .verificarIndisponibilidad(empresaId, t.id, day);

      _noDispoCache[key] = exists;
      if (exists) return true;
    }
    return false;
  }

  String _cleanError(Object e) {
    final s = e.toString();
    return s.replaceFirst('Exception: ', '').trim();
  }

  void _showMsg(String m) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

  // ==========================
  // ENVIAR SOLICITUDES
  // ==========================
  Future<void> _enviarSolicitudes(
      List<Trabajador> todos, List<String> rolesDisponibles) async {
    if (_selectedEventoId == null) {
      _showMsg("Selecciona un evento primero");
      return;
    }

    // si ya está completo, ni enviar
    if (_rolesRequeridosEvento.isNotEmpty) {
      final dispoActual = await FirestoreService.instance
          .listenDisponibilidadEvento(empresaId, _selectedEventoId!)
          .first;
      final pendientesRol = _calcPendientesPorRol(dispoActual);
      final libresTot = _plazasLibresTotales(pendientesRol);
      if (libresTot == 0) {
        _showMsg("El evento ya está completo. No se pueden enviar más solicitudes.");
        return;
      }
    }

    try {
      List<Trabajador> candidatos = [];
      Set<String> rolesModo = {};

      if (_modo == ModoEnvio.roles) {
        if (_rolesSeleccionados.isEmpty) {
          _showMsg("Selecciona al menos un rol");
          return;
        }
        rolesModo = _rolesSeleccionados.toSet();
        candidatos = todos
            .where((t) =>
                rolesModo.any((r) => _norm(r) == _norm(t.puesto ?? 'Sin Rol')))
            .toList();
      } else if (_modo == ModoEnvio.grupos) {
        if (_gruposSeleccionados.isEmpty) {
          _showMsg("Selecciona al menos un grupo");
          return;
        }
        for (final gid in _gruposSeleccionados) {
          final g = _grupos.firstWhere(
            (x) => x.id == gid,
            orElse: () => _RoleGroup(id: gid, nombre: gid, roles: {}),
          );
          rolesModo.addAll(g.roles);
        }
        candidatos = todos
            .where((t) =>
                rolesModo.any((r) => _norm(r) == _norm(t.puesto ?? 'Sin Rol')))
            .toList();
      } else {
        if (_trabajadoresSeleccionados.isEmpty) {
          _showMsg("Selecciona al menos un trabajador");
          return;
        }
        candidatos =
            todos.where((t) => _trabajadoresSeleccionados.contains(t.id)).toList();
      }

      if (candidatos.isEmpty) {
        _showMsg("No hay trabajadores candidatos");
        return;
      }

      // filtro por indisponibilidad (días)
      final checks = await Future.wait(candidatos.map((t) async {
        final noD = await _isNoDisponibleParaEvento(t);
        return MapEntry(t, noD);
      }));

      final disponibles =
          checks.where((e) => !e.value).map((e) => e.key).toList();

      if (disponibles.isEmpty) {
        _showMsg("Ningún candidato está disponible en esas fechas.");
        return;
      }

      // el service ahora filtra además por conflicto horario (ocupación)
      final res = await FirestoreService.instance.crearSolicitudesDisponibilidadParaEvento(
  empresaId: empresaId,
  eventoId: _selectedEventoId!,
  trabajadores: disponibles,
);

if (res.creadas > 0) {
  _showMsg("Solicitudes enviadas: ${res.creadas}");
}

if (res.descartadasPorConflicto > 0) {
  _showMsg(
    "⚠️ ${res.descartadasPorConflicto} trabajador(es) ya están asignados a otro evento en ese horario. No se les envió solicitud.",
  );
}

// opcional: también avisar por indisponibles
if (res.descartadasPorIndisponible > 0) {
  _showMsg(
    "ℹ️ ${res.descartadasPorIndisponible} trabajador(es) estaban marcados como NO disponibles. No se les envió solicitud.",
  );
}

    } catch (e) {
      _showMsg("Error al enviar: ${_cleanError(e)}");
    }
  }

  // ==========================
  // AUTO ASIGNAR
  // ==========================
  Future<void> _autoAsignar() async {
    if (_autoAsignando) return;

    if (_selectedEventoId == null || _rolesRequeridosEvento.isEmpty) {
      _showMsg("Selecciona un evento con roles requeridos.");
      return;
    }

    setState(() => _autoAsignando = true);

    try {
      // si completo -> no
      final dispoActual = await FirestoreService.instance
          .listenDisponibilidadEvento(empresaId, _selectedEventoId!)
          .first;
      final pendientesRol = _calcPendientesPorRol(dispoActual);
      final libresTot = _plazasLibresTotales(pendientesRol);
      if (libresTot == 0) {
        _showMsg("El evento ya está completo. No se puede auto-asignar.");
        return;
      }

      final res = await FirestoreService.instance.autoAsignarEvento(
        empresaId: empresaId,
        eventoId: _selectedEventoId!,
        rolesRequeridos: _rolesRequeridosEvento,
      );

      final total = res.values.fold<int>(0, (a, b) => a + b);

      if (total == 0) {
        _showMsg("No había plazas libres o no hay aceptados sin asignar.");
      } else {
        final detalle = res.entries
            .where((e) => e.value > 0)
            .map((e) => "${e.key}: ${e.value}")
            .join(" · ");
        _showMsg("Auto-asignación completada: $total asignados. $detalle");
      }
    } catch (e) {
      _showMsg("Error en auto-asignación: ${_cleanError(e)}");
    } finally {
      if (mounted) setState(() => _autoAsignando = false);
    }
  }

  // ==========================
  // CALCULOS POR ROL
  // ==========================
  Map<String, int> _contarAsignadosPorRol(List<DisponibilidadEvento> lista) {
    final Map<String, int> out = {};
    for (final d in lista) {
      if (d.asignado == true) {
        final rol = (d.trabajadorRol ?? '').trim();
        if (rol.isEmpty) continue;
        out[rol] = (out[rol] ?? 0) + 1;
      }
    }
    return out;
  }

  Map<String, int> _calcPendientesPorRol(List<DisponibilidadEvento> lista) {
    final asignados = _contarAsignadosPorRol(lista);
    final Map<String, int> pendientes = {};
    for (final e in _rolesRequeridosEvento.entries) {
      final rol = e.key;
      final req = e.value;
      final ya = asignados[rol] ?? 0;
      final faltan = req - ya;
      pendientes[rol] = faltan < 0 ? 0 : faltan;
    }
    return pendientes;
  }

  int _plazasLibresTotales(Map<String, int> pendientesPorRol) {
    return pendientesPorRol.values.fold<int>(0, (a, b) => a + b);
  }

  // --- INTERFAZ ---

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _bg,
        elevation: 0,
        title: const Text(
          'Asignación de Personal',
          style: TextStyle(color: _textDark, fontWeight: FontWeight.w900),
        ),
      ),
      body: Column(
        children: [
          _buildSelectorCard(),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                if (_selectedEvento != null) ...[
                  Theme(
                    data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                    child: ExpansionTile(
                      title: const Text(
                        "MAPA Y UBICACIÓN",
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w900,
                          color: _textGrey,
                        ),
                      ),
                      leading: const Icon(Icons.map_outlined, size: 20, color: _blue),
                      children: [
                        EventMapCard(evento: _selectedEvento!),
                        const SizedBox(height: 16)
                      ],
                    ),
                  ),
                  const Divider(color: _border),

                  const SizedBox(height: 8),
                  _buildHeaderSection("RESPUESTAS DE DISPONIBILIDAD"),
                  _buildListaRespuestas(),
                  const SizedBox(height: 24),
                  const Divider(color: _border),
                ],

                const SizedBox(height: 8),
                Theme(
                  data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                  child: ExpansionTile(
                    initiallyExpanded: _trabajadoresSeleccionados.isEmpty,
                    title: const Text(
                      "ENVIAR NUEVAS SOLICITUDES",
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                        color: _textGrey,
                      ),
                    ),
                    leading: const Icon(Icons.send_outlined, size: 20, color: _blue),
                    subtitle: Text(
                      _getResumenSeleccion(),
                      style: const TextStyle(
                        fontSize: 11,
                        color: _blue,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    children: [
                      _buildPanelEnvio(),
                      const SizedBox(height: 40),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _getResumenSeleccion() {
    if (_modo == ModoEnvio.roles) return "${_rolesSeleccionados.length} roles marcados";
    if (_modo == ModoEnvio.grupos) return "${_gruposSeleccionados.length} grupos marcados";
    return "${_trabajadoresSeleccionados.length} seleccionados manualmente";
  }

  Widget _buildHeaderSection(String title) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 12, left: 4),
        child: Text(
          title,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w900,
            color: _textGrey,
            letterSpacing: 0.8,
          ),
        ),
      ),
    );
  }

  Widget _buildSelectorCard() {
    return StreamBuilder<List<Evento>>(
      stream: FirestoreService.instance.listenEventos(empresaId),
      builder: (context, snap) {
        if (!snap.hasData) return const LinearProgressIndicator();
        final eventos = snap.data!.where((e) => e.estado != 'cancelado').toList();

        return Container(
          margin: const EdgeInsets.all(16),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: _card,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: _border),
            boxShadow: const [
              BoxShadow(color: Color(0x0A000000), blurRadius: 20, offset: Offset(0, 8))
            ],
          ),
          child: DropdownButtonFormField<String>(
            value: _selectedEventoId,
            style: const TextStyle(color: _textDark, fontWeight: FontWeight.w700),
            decoration: InputDecoration(
              labelText: "Evento",
              prefixIcon: const Icon(Icons.event_note, color: _blue),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide.none,
              ),
              filled: true,
              fillColor: _bg,
            ),
            items: eventos
                .map((e) => DropdownMenuItem(value: e.id, child: Text(e.nombre)))
                .toList(),
            onChanged: (v) {
              if (v == null) return;
              final ev = eventos.firstWhere((e) => e.id == v);
              setState(() {
                _selectedEventoId = v;
                _selectedEvento = ev;
                _rolesRequeridosEvento = Map<String, int>.from(ev.rolesRequeridos);
                _eventoInicio = ev.fechaInicio;
                _eventoFin = ev.fechaFin;
                _noDispoCache.clear();

                // limpiar selecciones
                _rolesSeleccionados.clear();
                _gruposSeleccionados.clear();
                _trabajadoresSeleccionados.clear();
                _filtroNombre = "";
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
        _ensureGrupoTodos(rolesDisponibles);

        return Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: _card,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: _border),
            boxShadow: const [
              BoxShadow(color: Color(0x0A000000), blurRadius: 20, offset: Offset(0, 8))
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildModoToggle(),
              const SizedBox(height: 20),
              if (_modo == ModoEnvio.roles) _buildRolesSection(rolesDisponibles),
              if (_modo == ModoEnvio.grupos) _buildGruposSection(rolesDisponibles),
              if (_modo == ModoEnvio.manual) _buildManualSection(trabajadores),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _blue,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    elevation: 0,
                  ),
                  onPressed: () => _enviarSolicitudes(trabajadores, rolesDisponibles),
                  icon: const Icon(Icons.send_rounded, size: 18),
                  label: const Text(
                    "ENVIAR SOLICITUDES",
                    style: TextStyle(fontWeight: FontWeight.w900),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildModoToggle() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(color: _bg, borderRadius: BorderRadius.circular(14)),
      child: Row(
        children: ModoEnvio.values.map((m) {
          final isSel = _modo == m;
          return Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _modo = m),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: isSel ? Colors.white : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: isSel
                      ? [const BoxShadow(color: Color(0x14000000), blurRadius: 8)]
                      : [],
                ),
                child: Center(
                  child: Text(
                    m.name.toUpperCase(),
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: isSel ? FontWeight.w900 : FontWeight.w700,
                      color: isSel ? _blue : _textGrey,
                    ),
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildRolesSection(List<String> roles) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: roles.map((r) {
        final sel = _rolesSeleccionados.contains(r);
        return FilterChip(
          label: Text("$r (${_rolesRequeridosEvento[r]})"),
          selected: sel,
          onSelected: (v) => setState(() => v ? _rolesSeleccionados.add(r) : _rolesSeleccionados.remove(r)),
          backgroundColor: Colors.white,
          selectedColor: _blue.withOpacity(0.1),
          checkmarkColor: _blue,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          labelStyle: TextStyle(
            color: sel ? _blue : _textDark,
            fontWeight: sel ? FontWeight.w800 : FontWeight.w600,
            fontSize: 12,
          ),
        );
      }).toList(),
    );
  }

  Widget _buildManualSection(List<Trabajador> todos) {
    final filtrados = todos
        .where((t) =>
            _norm(t.nombre).contains(_norm(_filtroNombre)) ||
            _norm(t.apellidos ?? '').contains(_norm(_filtroNombre)))
        .toList();

    return Column(
      children: [
        TextField(
          onChanged: (v) => setState(() => _filtroNombre = v),
          decoration: InputDecoration(
            hintText: "Buscar entre ${todos.length} trabajadores...",
            prefixIcon: const Icon(Icons.search, color: _blue),
            suffixIcon: _filtroNombre.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear),
                    onPressed: () => setState(() => _filtroNombre = ""))
                : null,
            filled: true,
            fillColor: _bg,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide.none,
            ),
          ),
        ),
        const SizedBox(height: 12),
        ConstrainedBox(
          constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.4),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: _border),
              color: Colors.white,
            ),
            child: ListView.separated(
              shrinkWrap: true,
              itemCount: filtrados.length,
              separatorBuilder: (_, __) => const Divider(height: 1, indent: 50),
              itemBuilder: (ctx, i) {
                final t = filtrados[i];
                final sel = _trabajadoresSeleccionados.contains(t.id);
                return CheckboxListTile(
                  value: sel,
                  activeColor: _blue,
                  onChanged: (v) => setState(() => v!
                      ? _trabajadoresSeleccionados.add(t.id)
                      : _trabajadoresSeleccionados.remove(t.id)),
                  title: Text(
                    "${t.nombre} ${t.apellidos ?? ''}",
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                  subtitle: Text(
                    "${t.puesto} • ${t.aniosExperiencia ?? 0} años exp.",
                    style: const TextStyle(fontSize: 11),
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  // ==========================
  // LISTA RESPUESTAS (con bloqueo por roles y evento completo)
  // ==========================
  Widget _buildListaRespuestas() {
    if (_selectedEventoId == null) return const SizedBox();

    return StreamBuilder<List<DisponibilidadEvento>>(
      stream: FirestoreService.instance.listenDisponibilidadEvento(
        empresaId,
        _selectedEventoId!,
      ),
      builder: (context, snap) {
        if (!snap.hasData) return const Center(child: CircularProgressIndicator());
        final lista = snap.data!;
        if (lista.isEmpty) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 20),
            child: Text("Sin solicitudes enviadas"),
          );
        }

        final pendientesPorRol = _calcPendientesPorRol(lista);
        final plazasLibresTotales = _plazasLibresTotales(pendientesPorRol);

        final aceptadosSinAsignar =
            lista.where((d) => d.estado == 'aceptado' && d.asignado != true).length;

        final eventoCompleto = plazasLibresTotales == 0;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ====== RESUMEN POR ROLES ======
            Container(
              padding: const EdgeInsets.only(bottom: 10),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: _border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "PENDIENTES POR ROL",
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                        color: _textGrey,
                        letterSpacing: 0.6,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _rolesRequeridosEvento.entries.map((e) {
                        final rol = e.key;
                        final req = e.value;
                        final pend = pendientesPorRol[rol] ?? 0;
                        final done = req - pend;

                        final color = pend == 0
                            ? const Color(0xFF10B981)
                            : const Color(0xFFF59E0B);

                        return Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                          decoration: BoxDecoration(
                            color: color.withOpacity(0.10),
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(color: color.withOpacity(0.25)),
                          ),
                          child: Text(
                            "$rol: $done/$req (faltan $pend)",
                            style: TextStyle(
                              color: color,
                              fontWeight: FontWeight.w900,
                              fontSize: 11,
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      eventoCompleto
                          ? "✅ Evento completo: todos los roles cubiertos"
                          : "Quedan $plazasLibresTotales plazas por cubrir · $aceptadosSinAsignar aceptados sin asignar",
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: eventoCompleto ? const Color(0xFF10B981) : _textDark,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // ====== BOTÓN AUTO-ASIGNAR ======
            Container(
              padding: const EdgeInsets.only(bottom: 10),
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: _blue,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                onPressed: (_autoAsignando || aceptadosSinAsignar == 0 || eventoCompleto)
                    ? null
                    : _autoAsignar,
                icon: _autoAsignando
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.auto_fix_high_rounded, size: 18),
                label: Text(
                  _autoAsignando
                      ? "AUTO-ASIGNANDO..."
                      : eventoCompleto
                          ? "EVENTO COMPLETO"
                          : "ASIGNACIÓN AUTOMÁTICA ($aceptadosSinAsignar pendientes)",
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
              ),
            ),

            // ====== LISTA ======
            Container(
              constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.45),
              child: ListView.separated(
                shrinkWrap: true,
                physics: const ClampingScrollPhysics(),
                itemCount: lista.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (ctx, i) {
                  final d = lista[i];
                  final rol = (d.trabajadorRol ?? '').trim();
                  final plazasRol = pendientesPorRol[rol] ?? 0;

                  final puedeAsignarEste =
                      !eventoCompleto &&
                      d.estado == 'aceptado' &&
                      d.asignado != true &&
                      rol.isNotEmpty &&
                      plazasRol > 0;

                  return Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: _border),
                    ),
                    child: ListTile(
                      dense: true,
                      title: Text(
                        d.trabajadorNombre,
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          color: _textDark,
                          fontSize: 13,
                        ),
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 2),
                          Text(
                            rol.isEmpty ? "Sin rol" : rol,
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: _textGrey,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            d.estado.toUpperCase(),
                            style: TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 9,
                              color: _getEstadoColor(d.estado),
                            ),
                          ),
                        ],
                      ),
                      trailing: d.asignado == true
                          ? const _Badge(text: "ASIGNADO", color: _blue)
                          : d.estado == 'aceptado'
                              ? ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: _blue,
                                    foregroundColor: Colors.white,
                                    elevation: 0,
                                    padding: const EdgeInsets.symmetric(horizontal: 12),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                  ),
                                  onPressed: puedeAsignarEste
                                      ? () async {
                                          try {
                                            await FirestoreService.instance
                                                .marcarTrabajadorAsignado(
                                              empresaId: empresaId,
                                              eventoId: _selectedEventoId!,
                                              disponibilidadId: d.id,
                                              asignado: true,
                                            );
                                          } catch (e) {
                                            _showMsg(_cleanError(e));
                                          }
                                        }
                                      : null,
                                  child: Text(
                                    eventoCompleto
                                        ? "COMPLETO"
                                        : (rol.isNotEmpty && plazasRol == 0)
                                            ? "ROL CUBIERTO"
                                            : "ASIGNAR",
                                    style: const TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                )
                              : null,
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }

  void _ensureGrupoTodos(List<String> roles) {
    if (!_grupos.any((g) => g.id == 'ALL')) {
      _grupos.insert(
        0,
        _RoleGroup(id: 'ALL', nombre: 'Todos los Roles', roles: roles.toSet()),
      );
    }
  }

  Widget _buildGruposSection(List<String> roles) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ElevatedButton(
          onPressed: () => _openCrearGrupoDialog(roles),
          style: ElevatedButton.styleFrom(
            backgroundColor: _bg,
            foregroundColor: _blue,
            elevation: 0,
          ),
          child: const Text("+ Crear Grupo Personalizado"),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          children: _grupos
              .map((g) => FilterChip(
                    label: Text(g.nombre),
                    selected: _gruposSeleccionados.contains(g.id),
                    onSelected: (v) => setState(() => v
                        ? _gruposSeleccionados.add(g.id)
                        : _gruposSeleccionados.remove(g.id)),
                  ))
              .toList(),
        ),
      ],
    );
  }

  Future<void> _openCrearGrupoDialog(List<String> roles) async {
    final nameCtrl = TextEditingController();
    final Set<String> tmpRoles = {};

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setM) => Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
            left: 24,
            right: 24,
            top: 24,
          ),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Text(
              "Crear Grupo",
              style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: nameCtrl,
              decoration: const InputDecoration(labelText: "Nombre"),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              children: roles
                  .map((r) => FilterChip(
                        label: Text(r),
                        selected: tmpRoles.contains(r),
                        onSelected: (v) => setM(() => v ? tmpRoles.add(r) : tmpRoles.remove(r)),
                      ))
                  .toList(),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                if (nameCtrl.text.isEmpty) return;
                setState(() => _grupos.add(_RoleGroup(
                      id: DateTime.now().toIso8601String(),
                      nombre: nameCtrl.text,
                      roles: tmpRoles,
                    )));
                Navigator.pop(ctx);
              },
              child: const Text("GUARDAR"),
            )
          ]),
        ),
      ),
    );
  }

  Color _getEstadoColor(String e) {
    if (e == 'aceptado') return const Color(0xFF10B981);
    if (e == 'rechazado') return const Color(0xFFEF4444);
    if (e == 'asignado') return _blue;
    return const Color(0xFFF59E0B);
  }
}

class _Badge extends StatelessWidget {
  final String text;
  final Color color;
  const _Badge({required this.text, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w900),
      ),
    );
  }
}
