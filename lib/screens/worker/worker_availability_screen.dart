import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';

import '../../config/app_config.dart';
import '../../core/services/firestore_service.dart';
import '../../models/evento.dart';
import '../../models/disponibilidad_evento.dart';
import '../../widgets/worker_event_details_sheet.dart';

class WorkerAvailabilityScreen extends StatefulWidget {
  const WorkerAvailabilityScreen({super.key});

  @override
  State<WorkerAvailabilityScreen> createState() => _WorkerAvailabilityScreenState();
}

class _WorkerAvailabilityScreenState extends State<WorkerAvailabilityScreen> {
  DateTime _focusedDay = DateTime.now();
  DateTime _selectedDay = DateTime.now();

  final Set<String> _optimisticAdd = {};
  final Set<String> _optimisticRemove = {};

  DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  String _dateId(DateTime d) =>
      "${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}";

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    const empresaId = AppConfig.empresaId;

    if (user == null) {
      return const Scaffold(body: Center(child: Text('Inicia sesión')));
    }

    final bool isWideScreen = MediaQuery.of(context).size.width > 900;
    final double dynamicRowHeight = isWideScreen ? (MediaQuery.of(context).size.height * 0.10) : 52.0;

    return Scaffold(
      backgroundColor: const Color(0xFFF3F4F6),
      appBar: AppBar(
        title: const Text("Mi calendario", style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: StreamBuilder<List<Evento>>(
        stream: FirestoreService.instance.listenEventos(empresaId),
        builder: (context, eventosSnap) {
          if (!eventosSnap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final eventos = eventosSnap.data!;

          return StreamBuilder<List<DisponibilidadEvento>>(
            stream: FirestoreService.instance.listenSolicitudesDisponibilidadTrabajador(user.uid),
            builder: (context, dispoSnap) {
              if (!dispoSnap.hasData) {
                return const Center(child: CircularProgressIndicator());
              }

              final solicitudes = dispoSnap.data!;
              final Set<String> assignedEventIds = solicitudes
                  .where((s) => s.asignado == true)
                  .map((s) => s.eventoId)
                  .toSet();

              final assignedEvents = eventos.where((e) => assignedEventIds.contains(e.id)).toList();

              // Precalcular "día -> nº asignaciones"
              final Map<String, int> assignedCountByDay = {};
              for (final e in assignedEvents) {
                final id = _dateId(e.fechaInicio);
                assignedCountByDay[id] = (assignedCountByDay[id] ?? 0) + 1;
              }

              return StreamBuilder<List<DateTime>>(
                stream: FirestoreService.instance.listenIndisponibilidadTrabajador(
                  empresaId,
                  user.uid,
                ),
                builder: (context, indispoSnap) {
                  if (!indispoSnap.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final Set<String> snapshotUnavailable =
                      indispoSnap.data!.map((d) => _dateId(d)).toSet();

                  final Set<String> unavailable = {...snapshotUnavailable, ..._optimisticAdd}
                    ..removeAll(_optimisticRemove);

                  final String selectedId = _dateId(_selectedDay);
                  final bool selectedIsUnavailable = unavailable.contains(selectedId);

                  final selectedAssignedEvents = assignedEvents
                      .where((e) => isSameDay(e.fechaInicio, _selectedDay))
                      .toList()
                    ..sort((a, b) => a.fechaInicio.compareTo(b.fechaInicio));

                  final bool isPast = _dateOnly(_selectedDay).isBefore(_dateOnly(DateTime.now()));
                  final bool canToggleNoDisponible = selectedAssignedEvents.isEmpty && !isPast;

                  return Column(
                    children: [
                      // Leyenda
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                        child: Row(
                          children: [
                            _LegendDot(color: const Color(0xFF6366F1)),
                            const SizedBox(width: 6),
                            const Text("Asignado", style: TextStyle(fontSize: 12)),
                            const SizedBox(width: 16),
                            _LegendDot(color: Colors.red),
                            const SizedBox(width: 6),
                            const Text("No disponible", style: TextStyle(fontSize: 12)),
                          ],
                        ),
                      ),

                      // Calendario
                      Container(
                        margin: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(18),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.05),
                              blurRadius: 16,
                              offset: const Offset(0, 6),
                            )
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(18),
                          child: TableCalendar(
                            locale: 'es_ES',
                            firstDay: DateTime.utc(2020, 1, 1),
                            lastDay: DateTime.utc(2030, 12, 31),
                            focusedDay: _focusedDay,
                            startingDayOfWeek: StartingDayOfWeek.monday,
                            selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
                            onDaySelected: (sel, foc) => setState(() {
                              _selectedDay = sel;
                              _focusedDay = foc;
                            }),
                            onPageChanged: (foc) => setState(() => _focusedDay = foc),
                            rowHeight: dynamicRowHeight,
                            daysOfWeekHeight: 44,
                            calendarStyle: const CalendarStyle(
                              markersMaxCount: 1,
                              selectedDecoration: BoxDecoration(
                                color: Color(0xFF6366F1),
                                shape: BoxShape.circle,
                              ),
                              todayDecoration: BoxDecoration(
                                color: Color(0xFFEEF2FF),
                                shape: BoxShape.circle,
                              ),
                              todayTextStyle: TextStyle(
                                color: Color(0xFF6366F1),
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            headerStyle: const HeaderStyle(
                              formatButtonVisible: false,
                              titleCentered: true,
                              titleTextStyle: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                            ),
                            calendarBuilders: CalendarBuilders(
                              markerBuilder: (context, day, events) {
                                final dayId = _dateId(day);
                                final bool hasAssigned = (assignedCountByDay[dayId] ?? 0) > 0;
                                final bool hasUnavailable = unavailable.contains(dayId);

                                if (!hasAssigned && !hasUnavailable) return null;

                                return Align(
                                  alignment: Alignment.bottomCenter,
                                  child: Padding(
                                    padding: const EdgeInsets.only(bottom: 6),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        if (hasAssigned)
                                          Container(
                                            width: 7,
                                            height: 7,
                                            margin: const EdgeInsets.symmetric(horizontal: 2),
                                            decoration: const BoxDecoration(
                                              color: Color(0xFF6366F1),
                                              shape: BoxShape.circle,
                                            ),
                                          ),
                                        if (hasUnavailable)
                                          Container(
                                            width: 7,
                                            height: 7,
                                            margin: const EdgeInsets.symmetric(horizontal: 2),
                                            decoration: const BoxDecoration(
                                              color: Colors.red,
                                              shape: BoxShape.circle,
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        ),
                      ),

                      // Toggle "No disponible"
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: SwitchListTile(
                            title: const Text(
                              "Marcar día como NO disponible",
                              style: TextStyle(fontWeight: FontWeight.w600),
                            ),
                            subtitle: Text(
                              isPast
                                  ? "No puedes modificar días pasados."
                                  : (selectedAssignedEvents.isNotEmpty
                                      ? "Tienes asignación este día. No se puede marcar como no disponible."
                                      : "Si lo marcas, el admin verá que no puedes trabajar este día."),
                            ),
                            value: selectedIsUnavailable,
                            onChanged: canToggleNoDisponible
                                ? (v) async {
                                    final id = _dateId(_selectedDay);

                                    setState(() {
                                      if (v) {
                                        _optimisticAdd.add(id);
                                        _optimisticRemove.remove(id);
                                      } else {
                                        _optimisticRemove.add(id);
                                        _optimisticAdd.remove(id);
                                      }
                                    });

                                    await FirestoreService.instance.setDiaNoDisponible(
                                      empresaId,
                                      user.uid,
                                      _dateOnly(_selectedDay),
                                      v,
                                    );
                                  }
                                : null,
                          ),
                        ),
                      ),

                      // Lista de asignaciones del día seleccionado
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(18),
                            ),
                            child: selectedAssignedEvents.isEmpty
                                ? Center(
                                    child: Text(
                                      "Sin asignaciones para el ${DateFormat('dd/MM/yyyy').format(_selectedDay)}",
                                      style: const TextStyle(color: Color(0xFF6B7280)),
                                    ),
                                  )
                                : ListView.separated(
                                    padding: const EdgeInsets.all(12),
                                    itemCount: selectedAssignedEvents.length,
                                    separatorBuilder: (_, __) => const Divider(height: 18),
                                    itemBuilder: (context, i) {
                                      final e = selectedAssignedEvents[i];
                                      final hora = DateFormat('HH:mm').format(e.fechaInicio);
                                      final fecha = DateFormat('dd/MM/yyyy').format(e.fechaInicio);

                                      return ListTile(
                                        // ✅ ESTE ERA EL FALLO: AHORA SÍ ABRE
                                        onTap: () => WorkerEventDetailsSheet.open(context, e),

                                        leading: const CircleAvatar(
                                          backgroundColor: Color(0xFFEEF2FF),
                                          child: Icon(Icons.event, color: Color(0xFF6366F1)),
                                        ),
                                        title: Text(
                                          e.nombre,
                                          style: const TextStyle(fontWeight: FontWeight.w700),
                                        ),
                                        subtitle: Text("$fecha · $hora\n${e.ciudad} - ${e.direccion}"),
                                      );
                                    },
                                  ),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}

class _LegendDot extends StatelessWidget {
  final Color color;
  const _LegendDot({required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 10,
      height: 10,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}
