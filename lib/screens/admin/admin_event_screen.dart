import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:intl/intl.dart';

import '../../config/app_config.dart';
import '../../core/services/firestore_service.dart';
import '../../models/evento.dart';
import 'admin_assignment_screen.dart';
import '../../widgets/place_autocomplete_field.dart';
import '../../widgets/event_map_card.dart';
import '../../core/services/places_service.dart';

/// ✅ Pon tu key de Places por dart-define:
/// flutter run --dart-define=GOOGLE_PLACES_API_KEY=TU_KEY
const String kPlacesApiKey = String.fromEnvironment('GOOGLE_PLACES_API_KEY');

class AdminEventScreen extends StatefulWidget {
  const AdminEventScreen({super.key});

  @override
  State<AdminEventScreen> createState() => _AdminEventScreenState();
}

class _AdminEventScreenState extends State<AdminEventScreen> {
  // 🎨 Turneo style (igual que login)
  static const Color _bg = Color(0xFFF6F8FC);
  static const Color _card = Colors.white;
  static const Color _border = Color(0xFFE5E7EB);
  static const Color _textDark = Color(0xFF111827);
  static const Color _textGrey = Color(0xFF6B7280);
  static const Color _blue = Color(0xFF2563EB);

  DateTime _focusedDay = DateTime.now();
  DateTime _selectedDay = DateTime.now();
  bool _verTodos = false;
  String _searchQuery = ""; // <--- AÑADIR ESTA LÍNEA

  @override
  Widget build(BuildContext context) {
    const empresaId = AppConfig.empresaId;
    final bool isWideScreen = MediaQuery.of(context).size.width > 900;

    final double dynamicRowHeight =
        isWideScreen ? (MediaQuery.of(context).size.height * 0.11) : 52.0;

    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _bg,
        elevation: 0,
        surfaceTintColor: _bg,
        title: const Text(
          'Gestión de Eventos',
          style: TextStyle(
            color: _textDark,
            fontWeight: FontWeight.w900,
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 14),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: _border),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x14000000),
                    blurRadius: 16,
                    offset: Offset(0, 8),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Text(
                    _verTodos ? "Historial" : "Historial",
                    style: const TextStyle(
                      color: _textGrey,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Switch(
                    value: _verTodos,
                    activeColor: _blue,
                    onChanged: (val) => setState(() => _verTodos = val),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openEventForm(context: context),
        backgroundColor: _blue,
        foregroundColor: Colors.white,
        elevation: 8,
        icon: const Icon(Icons.add),
        label: const Text(
          'Nuevo Evento',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      body: StreamBuilder<List<Evento>>(
        stream: FirestoreService.instance.listenEventos(empresaId),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

      List<Evento> todosLosEventos = snapshot.data!;

      // 1. Primero aplicamos el filtro de fecha (Historial o Hoy)
      List<Evento> filtrados = _verTodos
          ? (List.from(todosLosEventos)
            ..sort((a, b) => b.fechaInicio.compareTo(a.fechaInicio)))
          : todosLosEventos
              .where((e) => e.fechaInicio.isAfter(
                  DateTime.now().subtract(const Duration(days: 1))))
              .toList();

      // 2. Aplicamos el filtro de búsqueda por nombre si hay texto escrito
      if (_searchQuery.isNotEmpty) {
        filtrados = filtrados
            .where((e) => e.nombre.toLowerCase().contains(_searchQuery.toLowerCase()))
            .toList();
      }

      // Eventos para marcar el calendario
      final eventosDelDia = filtrados
          .where((e) => isSameDay(e.fechaInicio, _selectedDay))
          .toList();

          return Flex(
            direction: isWideScreen ? Axis.horizontal : Axis.vertical,
            children: [
              Expanded(
                flex: isWideScreen ? 3 : 0,
                child: Container(
                  margin: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: _card,
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
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(22),
                    child: TableCalendar(
                      locale: 'es_ES',
                      firstDay: DateTime.utc(2020, 1, 1),
                      lastDay: DateTime.utc(2030, 12, 31),
                      focusedDay: _focusedDay,
                      startingDayOfWeek: StartingDayOfWeek.monday,
                      selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
                      eventLoader: (day) => filtrados
                          .where((e) => isSameDay(e.fechaInicio, day))
                          .toList(),
                      calendarBuilders: CalendarBuilders(
                        markerBuilder: (context, day, events) {
                          if (events.isEmpty) return null;
                          return Align(
                            alignment: Alignment.bottomCenter,
                            child: Container(
                              width: 7,
                              height: 7,
                              margin: const EdgeInsets.only(bottom: 6),
                              decoration: const BoxDecoration(
                                color: _blue,
                                shape: BoxShape.circle,
                              ),
                            ),
                          );
                        },
                      ),
                      rowHeight: dynamicRowHeight,
                      daysOfWeekHeight: 42,
                      onDaySelected: (sel, foc) => setState(() {
                        _selectedDay = sel;
                        _focusedDay = foc;
                      }),
                      onPageChanged: (focusedDay) =>
                          setState(() => _focusedDay = focusedDay),
                      calendarStyle: const CalendarStyle(
                        markersMaxCount: 1,
                        selectedDecoration: BoxDecoration(
                          color: _blue,
                          shape: BoxShape.circle,
                        ),
                        todayDecoration: BoxDecoration(
                          color: Color(0xFFEFF6FF),
                          shape: BoxShape.circle,
                        ),
                        defaultTextStyle: TextStyle(
                          fontSize: 16,
                          color: _textDark,
                          fontWeight: FontWeight.w600,
                        ),
                        weekendTextStyle: TextStyle(
                          fontSize: 16,
                          color:  Color.fromARGB(255, 239, 35, 35),
                          fontWeight: FontWeight.w600,
                        ),
                        selectedTextStyle: TextStyle(
                          fontSize: 16,
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                        ),
                        todayTextStyle: TextStyle(
                          color: _blue,
                          fontWeight: FontWeight.w900,
                          fontSize: 16,
                        ),
                        cellMargin: EdgeInsets.all(4),
                      ),
                      headerStyle: const HeaderStyle(
                        formatButtonVisible: false,
                        titleCentered: true,
                        titleTextStyle: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          color: _textDark,
                        ),
                        headerPadding: EdgeInsets.symmetric(vertical: 18),
                        leftChevronIcon: Icon(Icons.chevron_left, color: _textGrey),
                        rightChevronIcon:
                            Icon(Icons.chevron_right, color: _textGrey),
                      ),
                      daysOfWeekStyle: const DaysOfWeekStyle(
                        weekdayStyle: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 13,
                          color: _textGrey,
                        ),
                        weekendStyle: TextStyle(
                          fontWeight: FontWeight.w800,
                          color:  Color.fromARGB(255, 239, 35, 35),
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              Expanded(
                flex: isWideScreen ? 2 : 1,
                child: _buildEventSideList(eventosDelDia, filtrados, empresaId),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildEventSideList(
    List<Evento> delDia,
    List<Evento> filtrados,
    String empresaId,
  ) {
    final listaAMostrar = _verTodos ? filtrados : delDia;

    return Container(
      margin: const EdgeInsets.fromLTRB(0, 16, 16, 16),
      decoration: BoxDecoration(
        color: _card,
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
            child: Text(
              _verTodos
                  ? "Historial Completo"
                  : "Eventos del ${_formatFechaCorta(_selectedDay)}",
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w900,
                color: _textDark,
              ),
            ),
          ),
          if (_verTodos)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: TextField(
                onChanged: (value) => setState(() => _searchQuery = value),
                decoration: InputDecoration(
                  hintText: "Buscar evento por nombre...",
                  prefixIcon: const Icon(Icons.search, size: 20),
                  filled: true,
                  fillColor: _bg,
                  contentPadding: const EdgeInsets.symmetric(vertical: 0),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
          const Divider(height: 1),
          Expanded(
            child: listaAMostrar.isEmpty
                ? const Center(
                    child: Text(
                      "No hay eventos registrados",
                      style: TextStyle(color: _textGrey, fontWeight: FontWeight.w600),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: listaAMostrar.length,
                    itemBuilder: (context, i) {
                      final e = listaAMostrar[i];
                      return Dismissible(
                        key: Key(e.id),
                        direction: DismissDirection.endToStart,
                        confirmDismiss: (direction) => _confirmarBorrado(e, empresaId),
                        background: Container(
                          alignment: Alignment.centerRight,
                          padding: const EdgeInsets.only(right: 20),
                          decoration: BoxDecoration(
                            color: const Color.fromARGB(255, 239, 35, 35),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: const Icon(Icons.delete, color: Colors.white),
                        ),
                        child: _buildEventCard(e),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Future<bool?> _confirmarBorrado(Evento e, String empresaId) async {
    return await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text("¿Eliminar evento?"),
        content: Text("Esta acción eliminará '${e.nombre}' permanentemente."),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text("CANCELAR"),
          ),
          TextButton(
            onPressed: () async {
              await FirestoreService.instance.borrarEvento(empresaId, e.id);
              if (mounted) Navigator.pop(ctx, true);
            },
            child: const Text("ELIMINAR", style: TextStyle(color: Color(0xFFB91C1C))),
          ),
        ],
      ),
    );
  }

  Future<void> _openAsistenciaSheet(String empresaId, Evento evento) async {
    final db = FirebaseFirestore.instance;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (_) {
        return Padding(
          padding: const EdgeInsets.all(16),
          child: SizedBox(
            height: MediaQuery.of(context).size.height * 0.75,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Asistencia • ${evento.nombre}',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    color: _textDark,
                  ),
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                    stream: db
                        .collection('empresas')
                        .doc(empresaId)
                        .collection('eventos')
                        .doc(evento.id)
                        .collection('disponibilidad')
                        .where('asignado', isEqualTo: true)
                        .snapshots(),
                    builder: (context, snap) {
                      if (!snap.hasData) {
                        return const Center(child: CircularProgressIndicator());
                      }

                      final docs = snap.data!.docs;
                      if (docs.isEmpty) {
                        return const Center(
                          child: Text('No hay trabajadores asignados todavía.'),
                        );
                      }

                      return ListView.builder(
                        itemCount: docs.length,
                        itemBuilder: (context, i) {
                          final doc = docs[i];
                          final data = doc.data();

                          final nombre =
                              (data['trabajadorNombre'] ?? 'Trabajador') as String;
                          final rol = (data['trabajadorRol'] ?? '') as String;
                          final asistio = data['asistio'] == true;

                          return Container(
                            margin: const EdgeInsets.only(bottom: 10),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: _border),
                            ),
                            child: ListTile(
                              title: Text(
                                nombre,
                                style: const TextStyle(fontWeight: FontWeight.w800),
                              ),
                              subtitle: rol.isEmpty
                                  ? null
                                  : Text(rol, style: const TextStyle(color: _textGrey)),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Text(
                                    'Asistió',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: _textGrey,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Switch(
                                    value: asistio,
                                    activeColor: _blue,
                                    onChanged: (v) async {
                                      await db
                                          .collection('empresas')
                                          .doc(empresaId)
                                          .collection('eventos')
                                          .doc(evento.id)
                                          .collection('disponibilidad')
                                          .doc(doc.id)
                                          .set(
                                        {
                                          'asistio': v,
                                          'asistioEn':
                                              v ? FieldValue.serverTimestamp() : null,
                                        },
                                        SetOptions(merge: true),
                                      );
                                    },
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildEventCard(Evento e) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _border),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0F000000),
            blurRadius: 18,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        title: Text(
          e.nombre,
          style: const TextStyle(
            fontWeight: FontWeight.w900,
            color: _textDark,
          ),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Text(
            '${DateFormat('dd/MM HH:mm').format(e.fechaInicio)}\n${e.ciudad}',
            style: const TextStyle(color: _textGrey, fontWeight: FontWeight.w600),
          ),
        ),
        trailing: Wrap(
          spacing: 6,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            _EstadoChip(estado: e.estado),
            IconButton(
              tooltip: 'Asignar personal',
              icon: const Icon(Icons.group_add_outlined, color: _blue),
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => AdminAssignmentScreen(initialEvento: e)),
              ),
            ),
            IconButton(
              tooltip: 'Marcar asistencia',
              icon: const Icon(Icons.fact_check_outlined, color: Color(0xFF10B981)),
              onPressed: () => _openAsistenciaSheet(AppConfig.empresaId, e),
            ),
          ],
        ),
        onTap: () => _openEventForm(context: context, evento: e),
      ),
    );
  }

  Future<void> _openEventForm({required BuildContext context, Evento? evento}) async {
    const empresaId = AppConfig.empresaId;
    final isEditing = evento != null;

    final nombreCtrl = TextEditingController(text: evento?.nombre ?? '');
    final tipoCtrl = TextEditingController(text: evento?.tipo ?? '');
    final ciudadCtrl = TextEditingController(text: evento?.ciudad ?? '');
    final direccionCtrl = TextEditingController(text: evento?.direccion ?? '');
    double? pickedLat = evento?.lat;
    double? pickedLng = evento?.lng;

    DateTime inicio = evento?.fechaInicio ?? DateTime.now().add(const Duration(days: 1));
    DateTime fin = evento?.fechaFin ?? inicio.add(const Duration(hours: 4));
    String estado = evento?.estado ?? 'activo';

    final Map<String, int> roles = Map<String, int>.from(evento?.rolesRequeridos ?? {});
    const presetRoles = ['camarero', 'cocinero', 'metre', 'limpiador', 'logistica'];
    for (final r in presetRoles) {
      roles.putIfAbsent(r, () => 0);
    }

    int totalRoles() => roles.values.fold<int>(0, (s, v) => s + v);

    void inc(String r) => roles[r] = (roles[r] ?? 0) + 1;
    void dec(String r) => roles[r] = ((roles[r] ?? 0) - 1).clamp(0, 999999);

    final newRoleCtrl = TextEditingController();

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (context) => StatefulBuilder(
        builder: (context, setMState) => Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom + 16,
            left: 24,
            right: 24,
            top: 24,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  isEditing ? 'Editar Evento' : 'Nuevo Evento',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    color: _textDark,
                  ),
                ),
                const SizedBox(height: 18),

                _TurneoTextField(
                  controller: nombreCtrl,
                  label: "Nombre del evento",
                ),
                const SizedBox(height: 12),
                _TurneoTextField(
                  controller: tipoCtrl,
                  label: "Tipo",
                ),
                const SizedBox(height: 12),

                Row(
                  children: [
                    Expanded(
                      child: _TurneoPickerTile(
                        title: "Inicio",
                        value: DateFormat('dd/MM/yy HH:mm').format(inicio),
                        onTap: () async {
                          final picked = await _pickDateTime(context, inicio);
                          if (picked != null) setMState(() => inicio = picked);
                        },
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _TurneoPickerTile(
                        title: "Fin",
                        value: DateFormat('dd/MM/yy HH:mm').format(fin),
                        onTap: () async {
                          final picked = await _pickDateTime(context, fin);
                          if (picked != null) setMState(() => fin = picked);
                        },
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 12),
                _TurneoTextField(
                  controller: ciudadCtrl,
                  label: "Ciudad",
                ),
                const SizedBox(height: 12),

                // ✅ NO cambiamos funcionalidad: usamos tu widget
                PlaceAutocompleteField(
                  controller: direccionCtrl,
                  onPlaceSelected: (sel) {
                    setMState(() {
                      direccionCtrl.text = sel.addressText;
                      if ((sel.city ?? '').isNotEmpty) ciudadCtrl.text = sel.city!;
                      pickedLat = sel.lat;
                      pickedLng = sel.lng;
                    });
                  },
                ),

                const SizedBox(height: 12),

                EventMapCard(
                  key: ValueKey(
                    '${pickedLat ?? ''}_${pickedLng ?? ''}_${direccionCtrl.text}_${ciudadCtrl.text}',
                  ),
                  evento: Evento(
                    id: evento?.id ?? '',
                    nombre: nombreCtrl.text.trim(),
                    tipo: tipoCtrl.text.trim(),
                    fechaInicio: inicio,
                    fechaFin: fin,
                    estado: estado,
                    ciudad: ciudadCtrl.text.trim(),
                    direccion: direccionCtrl.text.trim(),
                    rolesRequeridos: const {},
                    cantidadRequeridaTrabajadores: 0,
                    creadoPor: evento?.creadoPor ?? 'admin',
                    creadoEn: evento?.creadoEn ?? DateTime.now(),
                    lat: pickedLat,
                    lng: pickedLng,
                  ),
                ),

                const SizedBox(height: 14),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    "Personal requerido (roles)",
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w900,
                      color: Colors.grey.shade700,
                    ),
                  ),
                ),
                const SizedBox(height: 10),

                ...(() {
                  final keys = roles.keys.toList()..sort();
                  return keys.map((r) {
                    final v = roles[r] ?? 0;
                    return Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: _border),
                        color: Colors.white,
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              r,
                              style: const TextStyle(
                                fontWeight: FontWeight.w900,
                                color: _textDark,
                              ),
                            ),
                          ),
                          IconButton(
                            onPressed: () => setMState(() => dec(r)),
                            icon: const Icon(Icons.remove_circle_outline, color: _textGrey),
                          ),
                          Text(
                            "$v",
                            style: const TextStyle(
                              fontWeight: FontWeight.w900,
                              color: _textDark,
                            ),
                          ),
                          IconButton(
                            onPressed: () => setMState(() => inc(r)),
                            icon: const Icon(Icons.add_circle_outline, color: _blue),
                          ),
                        ],
                      ),
                    );
                  }).toList();
                })(),

                Row(
                  children: [
                    Expanded(
                      child: _TurneoTextField(
                        controller: newRoleCtrl,
                        label: "Añadir rol (opcional)",
                      ),
                    ),
                    const SizedBox(width: 10),
                    SizedBox(
                      height: 50,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _blue,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        onPressed: () {
                          final r = newRoleCtrl.text.trim();
                          if (r.isEmpty) return;
                          setMState(() {
                            roles.putIfAbsent(r, () => 1);
                            newRoleCtrl.clear();
                          });
                        },
                        child: const Text("Añadir", style: TextStyle(fontWeight: FontWeight.w900)),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 10),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    "Total: ${totalRoles()} trabajadores",
                    style: const TextStyle(fontWeight: FontWeight.w900, color: _textDark),
                  ),
                ),

                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: estado,
                  decoration: InputDecoration(
                    labelText: "Estado",
                    filled: true,
                    fillColor: const Color(0xFFF9FAFB),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(color: _border),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(color: _blue, width: 2),
                    ),
                  ),
                  items: ['borrador', 'activo', 'finalizado', 'cancelado']
                      .map((s) => DropdownMenuItem(value: s, child: Text(s.toUpperCase())))
                      .toList(),
                  onChanged: (val) => setMState(() => estado = val!),
                ),

                const SizedBox(height: 22),
                Row(
                  children: [
                    if (isEditing) ...[
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () async {
                            final res = await _confirmarBorrado(evento!, empresaId);
                            if (res == true && mounted) Navigator.pop(context);
                          },
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color.fromARGB(255, 239, 35, 35),
                            side: const BorderSide(color: Color(0xFFFCA5A5)),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                          child: const Text("ELIMINAR", style: TextStyle(fontWeight: FontWeight.w900)),
                        ),
                      ),
                      const SizedBox(width: 12),
                    ],
                    Expanded(
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _blue,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        onPressed: () async {
                          if (nombreCtrl.text.trim().isEmpty) return;

                          final cleanRoles = <String, int>{};
                          roles.forEach((k, v) {
                            if (v > 0) cleanRoles[k] = v;
                          });

                          if (cleanRoles.isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text("Añade al menos 1 trabajador en algún rol")),
                            );
                            return;
                          }

                          if ((pickedLat == null || pickedLng == null) &&
                              direccionCtrl.text.trim().isNotEmpty) {
                            try {
                              final geo = await PlacesService().geocodeAddress(
                                address:
                                    '${direccionCtrl.text.trim()}, ${ciudadCtrl.text.trim()}',
                              );

                              setMState(() {
                                pickedLat = geo.lat;
                                pickedLng = geo.lng;
                                direccionCtrl.text =
                                    geo.formattedAddress ?? direccionCtrl.text;
                              });
                            } catch (_) {}
                          }

                          if (pickedLat == null || pickedLng == null) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  "Selecciona una sugerencia de Google o escribe una dirección válida para obtener coordenadas.",
                                ),
                              ),
                            );
                            return;
                          }

                          final nuevo = Evento(
                            id: evento?.id ?? '',
                            nombre: nombreCtrl.text.trim(),
                            tipo: tipoCtrl.text.trim(),
                            fechaInicio: inicio,
                            fechaFin: fin,
                            estado: estado,
                            ciudad: ciudadCtrl.text.trim(),
                            direccion: direccionCtrl.text.trim(),
                            rolesRequeridos: cleanRoles,
                            cantidadRequeridaTrabajadores:
                                cleanRoles.values.fold(0, (s, v) => s + v),
                            creadoPor: evento?.creadoPor ?? 'admin',
                            creadoEn: evento?.creadoEn ?? DateTime.now(),
                            lat: pickedLat,
                            lng: pickedLng,
                          );

                          if (isEditing) {
                            await FirestoreService.instance.actualizarEvento(empresaId, nuevo);
                          } else {
                            await FirestoreService.instance.crearEvento(empresaId, nuevo);
                          }
                          Navigator.pop(context);
                        },
                        child: Text(
                          isEditing ? "GUARDAR" : "CREAR",
                          style: const TextStyle(fontWeight: FontWeight.w900),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<DateTime?> _pickDateTime(BuildContext context, DateTime initial) async {
    final date = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
      locale: const Locale('es', 'ES'),
    );
    if (date == null) return null;

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initial),
    );
    if (time == null) return null;

    return DateTime(date.year, date.month, date.day, time.hour, time.minute);
  }

  String _formatFechaCorta(DateTime d) => DateFormat('dd/MM/yyyy').format(d);

  String _rolesToText(Object? rawRoles) {
    if (rawRoles is List) return rawRoles.map((e) => e.toString()).join(', ');
    if (rawRoles is Map) return rawRoles.keys.map((e) => e.toString()).join(', ');
    return '';
  }
}

class _EstadoChip extends StatelessWidget {
  final String estado;
  const _EstadoChip({required this.estado});

  static const Color _blue = Color(0xFF2563EB);

  @override
  Widget build(BuildContext context) {
    Color color = _blue;
    if (estado == 'finalizado') color = const Color(0xFF10B981);
    if (estado == 'cancelado') color = const Color.fromARGB(255, 239, 35, 35);
    if (estado == 'borrador') color = const Color(0xFF6B7280);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        estado.toUpperCase(),
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w900,
          letterSpacing: 0.4,
        ),
      ),
    );
  }
}

class _TurneoTextField extends StatelessWidget {
  final TextEditingController controller;
  final String label;

  const _TurneoTextField({
    required this.controller,
    required this.label,
  });

  static const Color _border = Color(0xFFE5E7EB);
  static const Color _blue = Color(0xFF2563EB);

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        filled: true,
        fillColor: const Color(0xFFF9FAFB),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: _border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: _blue, width: 2),
        ),
      ),
    );
  }
}

class _TurneoPickerTile extends StatelessWidget {
  final String title;
  final String value;
  final VoidCallback onTap;

  const _TurneoPickerTile({
    required this.title,
    required this.value,
    required this.onTap,
  });

  static const Color _border = Color(0xFFE5E7EB);
  static const Color _textGrey = Color(0xFF6B7280);
  static const Color _textDark = Color(0xFF111827);

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xFFF9FAFB),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w900,
                color: _textGrey,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              value,
              style: const TextStyle(
                fontWeight: FontWeight.w800,
                color: _textDark,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
