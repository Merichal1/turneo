import 'dart:async';

import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:intl/intl.dart';

import '../../config/app_config.dart';
import '../../core/services/firestore_service.dart';
import '../../models/evento.dart';
import 'admin_assignment_screen.dart';
import '../../widgets/place_autocomplete_field.dart';

/// ✅ Pon tu key de Places por dart-define:
/// flutter run --dart-define=GOOGLE_PLACES_API_KEY=TU_KEY
const String kPlacesApiKey = String.fromEnvironment('GOOGLE_PLACES_API_KEY');

class AdminEventScreen extends StatefulWidget {
  const AdminEventScreen({super.key});

  @override
  State<AdminEventScreen> createState() => _AdminEventScreenState();
}

class _AdminEventScreenState extends State<AdminEventScreen> {
  DateTime _focusedDay = DateTime.now();
  DateTime _selectedDay = DateTime.now();
  bool _verTodos = false;

  @override
  Widget build(BuildContext context) {
    const empresaId = AppConfig.empresaId;
    final bool isWideScreen = MediaQuery.of(context).size.width > 900;

    final double dynamicRowHeight =
        isWideScreen ? (MediaQuery.of(context).size.height * 0.11) : 52.0;

    return Scaffold(
      backgroundColor: const Color(0xFFF3F4F6),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        title: const Text(
          'Gestión de Eventos',
          style: TextStyle(color: Color(0xFF111827), fontWeight: FontWeight.bold),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Text(
                  _verTodos ? "Historial" : "Próximos",
                  style: const TextStyle(color: Colors.grey, fontSize: 13),
                ),
                Switch(
                  value: _verTodos,
                  activeColor: const Color(0xFF6366F1),
                  onChanged: (val) => setState(() => _verTodos = val),
                ),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openEventForm(context: context),
        backgroundColor: const Color(0xFF111827),
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('Nuevo Evento', style: TextStyle(color: Colors.white)),
      ),
      body: StreamBuilder<List<Evento>>(
        stream: FirestoreService.instance.listenEventos(empresaId),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

          List<Evento> todosLosEventos = snapshot.data!;
          List<Evento> filtrados = _verTodos
              ? (List.from(todosLosEventos)
                ..sort((a, b) => b.fechaInicio.compareTo(a.fechaInicio)))
              : todosLosEventos
                  .where((e) => e.fechaInicio.isAfter(DateTime.now().subtract(const Duration(days: 1))))
                  .toList();

          final eventosDelDia =
              filtrados.where((e) => isSameDay(e.fechaInicio, _selectedDay)).toList();

          return Flex(
            direction: isWideScreen ? Axis.horizontal : Axis.vertical,
            children: [
              Expanded(
                flex: isWideScreen ? 3 : 0,
                child: Container(
                  margin: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 20)],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: TableCalendar(
                      locale: 'es_ES',
                      firstDay: DateTime.utc(2020, 1, 1),
                      lastDay: DateTime.utc(2030, 12, 31),
                      focusedDay: _focusedDay,
                      startingDayOfWeek: StartingDayOfWeek.monday,
                      selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
                      eventLoader: (day) =>
                          filtrados.where((e) => isSameDay(e.fechaInicio, day)).toList(),
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
                                color: Color(0xFF6366F1),
                                shape: BoxShape.circle,
                              ),
                            ),
                          );
                        },
                      ),
                      rowHeight: dynamicRowHeight,
                      daysOfWeekHeight: 50,
                      onDaySelected: (sel, foc) => setState(() {
                        _selectedDay = sel;
                        _focusedDay = foc;
                      }),
                      onPageChanged: (focusedDay) => setState(() => _focusedDay = focusedDay),
                      calendarStyle: const CalendarStyle(
                        markersMaxCount: 1,
                        selectedDecoration:
                            BoxDecoration(color: Color(0xFF6366F1), shape: BoxShape.circle),
                        todayDecoration:
                            BoxDecoration(color: Color(0xFFEEF2FF), shape: BoxShape.circle),
                        defaultTextStyle: TextStyle(fontSize: 18),
                        weekendTextStyle: TextStyle(fontSize: 18, color: Colors.red),
                        selectedTextStyle: TextStyle(
                          fontSize: 18,
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                        todayTextStyle: TextStyle(
                          color: Color(0xFF6366F1),
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                        cellMargin: EdgeInsets.all(4),
                      ),
                      headerStyle: const HeaderStyle(
                        formatButtonVisible: false,
                        titleCentered: true,
                        titleTextStyle: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                        headerPadding: EdgeInsets.symmetric(vertical: 20),
                      ),
                      daysOfWeekStyle: const DaysOfWeekStyle(
                        weekdayStyle: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                        weekendStyle:
                            TextStyle(fontWeight: FontWeight.bold, color: Colors.red, fontSize: 16),
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

  Widget _buildEventSideList(List<Evento> delDia, List<Evento> filtrados, String empresaId) {
    final listaAMostrar = _verTodos ? filtrados : delDia;

    return Container(
      margin: const EdgeInsets.fromLTRB(0, 16, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 8, bottom: 12),
            child: Text(
              _verTodos ? "Historial Completo" : "Eventos del ${_formatFechaCorta(_selectedDay)}",
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(
            child: listaAMostrar.isEmpty
                ? const Center(child: Text("No hay eventos registrados", style: TextStyle(color: Colors.grey)))
                : ListView.builder(
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
                          decoration: BoxDecoration(color: Colors.red, borderRadius: BorderRadius.circular(12)),
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
    return await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("¿Eliminar evento?"),
        content: Text("Esta acción eliminará '${e.nombre}' permanentemente."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("CANCELAR")),
          TextButton(
            onPressed: () async {
              await FirestoreService.instance.borrarEvento(empresaId, e.id);
              if (mounted) Navigator.pop(ctx, true);
            },
            child: const Text("ELIMINAR", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  Widget _buildEventCard(Evento e) {
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        title: Text(e.nombre, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text('${DateFormat('dd/MM HH:mm').format(e.fechaInicio)}\n${e.ciudad}'),
        trailing: Wrap(
          spacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            _EstadoChip(estado: e.estado),
            IconButton(
              icon: const Icon(Icons.group_add_outlined, color: Color(0xFF6366F1)),
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => AdminAssignmentScreen(initialEvento: e)),
              ),
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

  // ✅ Roles con contadores (- / +)
  final Map<String, int> roles = Map<String, int>.from(evento?.rolesRequeridos ?? {});

  // ✅ si no hay roles aún, inicializamos los tuyos
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
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
    builder: (context) => StatefulBuilder(
      builder: (context, setMState) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom + 16,
          left: 24, right: 24, top: 24,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(isEditing ? 'Editar Evento' : 'Nuevo Evento',
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 20),

              TextField(
                controller: nombreCtrl,
                decoration: const InputDecoration(labelText: "Nombre del evento", border: OutlineInputBorder()),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: tipoCtrl,
                decoration: const InputDecoration(labelText: "Tipo", border: OutlineInputBorder()),
              ),
              const SizedBox(height: 12),

              Row(
                children: [
                  Expanded(
                    child: ListTile(
                      title: const Text("Inicio", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                      subtitle: Text(DateFormat('dd/MM/yy HH:mm').format(inicio)),
                      onTap: () async {
                        final picked = await _pickDateTime(context, inicio);
                        if (picked != null) setMState(() => inicio = picked);
                      },
                    ),
                  ),
                  Expanded(
                    child: ListTile(
                      title: const Text("Fin", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                      subtitle: Text(DateFormat('dd/MM/yy HH:mm').format(fin)),
                      onTap: () async {
                        final picked = await _pickDateTime(context, fin);
                        if (picked != null) setMState(() => fin = picked);
                      },
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 12),
              TextField(
                controller: ciudadCtrl,
                decoration: const InputDecoration(labelText: "Ciudad", border: OutlineInputBorder()),
              ),
              const SizedBox(height: 12),
              PlaceAutocompleteField(
                apiKey: kPlacesApiKey,
                controller: direccionCtrl,
                labelText: "Dirección (Google)",
                hintText: "Escribe y elige una sugerencia…",
                onPlaceSelected: (sel) {
                  setMState(() {
                    direccionCtrl.text = sel.addressText;

                    // Rellena ciudad si viene en el detalle
                    if ((sel.city ?? '').trim().isNotEmpty) {
                      ciudadCtrl.text = sel.city!.trim();
                    }

                    // Guarda coords para el evento
                    pickedLat = sel.lat;
                    pickedLng = sel.lng;
                  });
                },
              ),


              const SizedBox(height: 16),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  "Personal requerido (roles)",
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Colors.grey.shade700),
                ),
              ),
              const SizedBox(height: 10),

              // ✅ lista roles con - / + manteniendo diseño simple
              ...(() {
                final keys = roles.keys.toList()..sort();
                return keys.map((r) {
                  final v = roles[r] ?? 0;
                  return Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            r,
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ),
                        IconButton(
                          onPressed: () => setMState(() => dec(r)),
                          icon: const Icon(Icons.remove_circle_outline),
                        ),
                        Text("$v", style: const TextStyle(fontWeight: FontWeight.w800)),
                        IconButton(
                          onPressed: () => setMState(() => inc(r)),
                          icon: const Icon(Icons.add_circle_outline),
                        ),
                      ],
                    ),
                  );
                }).toList();
              })(),

              // ✅ añadir rol nuevo
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: newRoleCtrl,
                      decoration: const InputDecoration(
                        labelText: "Añadir rol (opcional)",
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  ElevatedButton(
                    onPressed: () {
                      final r = newRoleCtrl.text.trim();
                      if (r.isEmpty) return;
                      setMState(() {
                        roles.putIfAbsent(r, () => 1);
                        newRoleCtrl.clear();
                      });
                    },
                    child: const Text("Añadir"),
                  )
                ],
              ),

              const SizedBox(height: 10),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  "Total: ${totalRoles()} trabajadores",
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),

              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: estado,
                decoration: const InputDecoration(labelText: "Estado", border: OutlineInputBorder()),
                items: ['borrador', 'activo', 'finalizado', 'cancelado']
                    .map((s) => DropdownMenuItem(value: s, child: Text(s.toUpperCase())))
                    .toList(),
                onChanged: (val) => setMState(() => estado = val!),
              ),

              const SizedBox(height: 24),
              Row(
                children: [
                  if (isEditing) ...[
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () async {
                          final res = await _confirmarBorrado(evento!, empresaId);
                          if (res == true && mounted) Navigator.pop(context);
                        },
                        style: OutlinedButton.styleFrom(foregroundColor: Colors.red),
                        child: const Text("ELIMINAR"),
                      ),
                    ),
                    const SizedBox(width: 12),
                  ],
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF6366F1),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.all(16),
                      ),
                      onPressed: () async {
                        if (nombreCtrl.text.trim().isEmpty) return;

                        // ✅ limpiamos roles con 0 para no ensuciar
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
                          cantidadRequeridaTrabajadores: cleanRoles.values.fold(0, (s, v) => s + v),
                          creadoPor: evento?.creadoPor ?? 'admin',
                          creadoEn: evento?.creadoEn ?? DateTime.now(),
                          // lat/lng NO los forzamos aquí: el EventMapCard los autogenera y cachea si faltan
                          lat: evento?.lat,
                          lng: evento?.lng,
                        );

                        if (isEditing) {
                          await FirestoreService.instance.actualizarEvento(empresaId, nuevo);
                        } else {
                          await FirestoreService.instance.crearEvento(empresaId, nuevo);
                        }
                        Navigator.pop(context);
                      },
                      child: Text(isEditing ? "GUARDAR" : "CREAR"),
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

  @override
  Widget build(BuildContext context) {
    Color color = Colors.blue;
    if (estado == 'finalizado') color = Colors.green;
    if (estado == 'cancelado') color = Colors.red;
    if (estado == 'borrador') color = Colors.grey;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(20)),
      child: Text(
        estado.toUpperCase(),
        style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold),
      ),
    );
  }
}
