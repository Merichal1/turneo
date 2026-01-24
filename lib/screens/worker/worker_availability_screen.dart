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
  State<WorkerAvailabilityScreen> createState() =>
      _WorkerAvailabilityScreenState();
}

class _WorkerAvailabilityScreenState extends State<WorkerAvailabilityScreen> {
  // ====== THEME (igual admin/login) ======
  static const Color _bg = Color(0xFFF6F8FC);
  static const Color _card = Colors.white;
  static const Color _border = Color(0xFFE5E7EB);
  static const Color _textDark = Color(0xFF111827);
  static const Color _textGrey = Color(0xFF6B7280);
  static const Color _blue = Color(0xFF2563EB);
  static const Color _indigo = Color(0xFF6366F1);

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
    final double dynamicRowHeight =
        isWideScreen ? (MediaQuery.of(context).size.height * 0.10) : 52.0;

    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        title: const Text(
          "Mi calendario",
          style: TextStyle(
            fontWeight: FontWeight.w800,
            color: _textDark,
          ),
        ),
        centerTitle: false,
        iconTheme: const IconThemeData(color: _textDark),
      ),
      body: StreamBuilder<List<Evento>>(
        stream: FirestoreService.instance.listenEventos(empresaId),
        builder: (context, eventosSnap) {
          if (!eventosSnap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final eventos = eventosSnap.data!;

          return StreamBuilder<List<DisponibilidadEvento>>(
            stream: FirestoreService.instance
                .listenSolicitudesDisponibilidadTrabajador(user.uid),
            builder: (context, dispoSnap) {
              if (!dispoSnap.hasData) {
                return const Center(child: CircularProgressIndicator());
              }

              final solicitudes = dispoSnap.data!;
              final Set<String> assignedEventIds = solicitudes
                  .where((s) => s.asignado == true)
                  .map((s) => s.eventoId)
                  .toSet();

              final assignedEvents =
                  eventos.where((e) => assignedEventIds.contains(e.id)).toList();

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

                  final Set<String> unavailable = {
                    ...snapshotUnavailable,
                    ..._optimisticAdd
                  }..removeAll(_optimisticRemove);

                  final String selectedId = _dateId(_selectedDay);
                  final bool selectedIsUnavailable = unavailable.contains(selectedId);

                  final selectedAssignedEvents = assignedEvents
                      .where((e) => isSameDay(e.fechaInicio, _selectedDay))
                      .toList()
                    ..sort((a, b) => a.fechaInicio.compareTo(b.fechaInicio));

                  final bool isPast =
                      _dateOnly(_selectedDay).isBefore(_dateOnly(DateTime.now()));
                  final bool canToggleNoDisponible =
                      selectedAssignedEvents.isEmpty && !isPast;

                  final selectedPretty =
                      DateFormat('EEEE, d MMM', 'es_ES').format(_selectedDay);

                  return ListView(
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
                    children: [
                      // ===== Header Card =====
                      _Card(
                        child: Row(
                          children: [
                            Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                color: const Color(0xFFEFF6FF),
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: const Icon(Icons.calendar_month,
                                  color: _blue, size: 22),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    selectedPretty[0].toUpperCase() +
                                        selectedPretty.substring(1),
                                    style: const TextStyle(
                                      color: _textDark,
                                      fontWeight: FontWeight.w900,
                                      fontSize: 16,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    selectedAssignedEvents.isEmpty
                                        ? 'Sin asignaciones hoy'
                                        : '${selectedAssignedEvents.length} asignación(es) hoy',
                                    style: const TextStyle(
                                      color: _textGrey,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            _Pill(
                              text: selectedIsUnavailable
                                  ? 'No disponible'
                                  : 'Disponible',
                              bg: selectedIsUnavailable
                                  ? const Color(0xFFFEE2E2)
                                  : const Color(0xFFDCFCE7),
                              fg: selectedIsUnavailable
                                  ? const Color(0xFFB91C1C)
                                  : const Color(0xFF15803D),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 12),

                      // ===== Leyenda =====
                      _Card(
                        child: Row(
                          children: const [
                            _LegendDot(color: _indigo),
                            SizedBox(width: 6),
                            Text(
                              "Asignado",
                              style: TextStyle(
                                fontSize: 12,
                                color: _textDark,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            SizedBox(width: 16),
                            _LegendDot(color: Colors.red),
                            SizedBox(width: 6),
                            Text(
                              "No disponible",
                              style: TextStyle(
                                fontSize: 12,
                                color: _textDark,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 12),

                      // ===== Calendario =====
                      _Card(
                        padding: const EdgeInsets.all(0),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(18),
                          child: TableCalendar(
                            locale: 'es_ES',
                            firstDay: DateTime.utc(2020, 1, 1),
                            lastDay: DateTime.utc(2030, 12, 31),
                            focusedDay: _focusedDay,
                            startingDayOfWeek: StartingDayOfWeek.monday,
                            selectedDayPredicate: (day) =>
                                isSameDay(_selectedDay, day),
                            onDaySelected: (sel, foc) => setState(() {
                              _selectedDay = sel;
                              _focusedDay = foc;
                            }),
                            onPageChanged: (foc) =>
                                setState(() => _focusedDay = foc),
                            rowHeight: dynamicRowHeight,
                            daysOfWeekHeight: 44,
                            calendarStyle: const CalendarStyle(
                              markersMaxCount: 1,
                              selectedDecoration: BoxDecoration(
                                color: _indigo,
                                shape: BoxShape.circle,
                              ),
                              todayDecoration: BoxDecoration(
                                color: Color(0xFFEEF2FF),
                                shape: BoxShape.circle,
                              ),
                              todayTextStyle: TextStyle(
                                color: _indigo,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            headerStyle: const HeaderStyle(
                              formatButtonVisible: false,
                              titleCentered: true,
                              titleTextStyle: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w900,
                                color: _textDark,
                              ),
                              leftChevronIcon: Icon(Icons.chevron_left,
                                  color: _textDark),
                              rightChevronIcon: Icon(Icons.chevron_right,
                                  color: _textDark),
                            ),
                            calendarBuilders: CalendarBuilders(
                              markerBuilder: (context, day, events) {
                                final dayId = _dateId(day);
                                final bool hasAssigned =
                                    (assignedCountByDay[dayId] ?? 0) > 0;
                                final bool hasUnavailable =
                                    unavailable.contains(dayId);

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
                                            margin: const EdgeInsets.symmetric(
                                                horizontal: 2),
                                            decoration: const BoxDecoration(
                                              color: _indigo,
                                              shape: BoxShape.circle,
                                            ),
                                          ),
                                        if (hasUnavailable)
                                          Container(
                                            width: 7,
                                            height: 7,
                                            margin: const EdgeInsets.symmetric(
                                                horizontal: 2),
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

                      const SizedBox(height: 12),

                      // ===== Toggle No Disponible =====
                      _Card(
                        child: SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          title: const Text(
                            "Marcar día como NO disponible",
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              color: _textDark,
                            ),
                          ),
                          subtitle: Text(
                            isPast
                                ? "No puedes modificar días pasados."
                                : (selectedAssignedEvents.isNotEmpty
                                    ? "Tienes asignación este día. No se puede marcar como no disponible."
                                    : "Si lo marcas, el admin verá que no puedes trabajar este día."),
                            style: const TextStyle(
                              color: _textGrey,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          value: selectedIsUnavailable,
                          activeColor: _blue,
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

                      const SizedBox(height: 12),

                      // ===== Asignaciones =====
                      _Card(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Asignaciones del día',
                              style: TextStyle(
                                color: _textDark,
                                fontWeight: FontWeight.w900,
                                fontSize: 14,
                              ),
                            ),
                            const SizedBox(height: 10),

                            if (selectedAssignedEvents.isEmpty)
                              Padding(
                                padding: const EdgeInsets.symmetric(vertical: 18),
                                child: Center(
                                  child: Text(
                                    "Sin asignaciones para el ${DateFormat('dd/MM/yyyy').format(_selectedDay)}",
                                    style: const TextStyle(
                                      color: _textGrey,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              )
                            else
                              ListView.separated(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                itemCount: selectedAssignedEvents.length,
                                separatorBuilder: (_, __) =>
                                    const SizedBox(height: 10),
                                itemBuilder: (context, i) {
                                  final e = selectedAssignedEvents[i];
                                  final hora =
                                      DateFormat('HH:mm').format(e.fechaInicio);
                                  final fecha =
                                      DateFormat('dd/MM/yyyy').format(e.fechaInicio);

                                  return _AssignmentCard(
                                    title: e.nombre,
                                    subtitle: "$fecha · $hora\n${e.ciudad} - ${e.direccion}",
                                    onTap: () =>
                                        WorkerEventDetailsSheet.open(context, e),
                                  );
                                },
                              ),
                          ],
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

// ===== Widgets estilo admin =====

class _Card extends StatelessWidget {
  final Widget child;
  final EdgeInsets padding;

  static const Color _card = Colors.white;
  static const Color _border = Color(0xFFE5E7EB);

  const _Card({
    required this.child,
    this.padding = const EdgeInsets.all(14),
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _border),
        boxShadow: const [
          BoxShadow(
            color: Color(0x14000000),
            blurRadius: 24,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _AssignmentCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  static const Color _textDark = Color(0xFF111827);
  static const Color _textGrey = Color(0xFF6B7280);
  static const Color _blue = Color(0xFF2563EB);

  const _AssignmentCard({
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  String _initials(String s) {
    final parts = s.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty) return '?';
    final a = parts[0].isNotEmpty ? parts[0][0].toUpperCase() : '';
    final b = parts.length > 1 && parts[1].isNotEmpty ? parts[1][0].toUpperCase() : '';
    final res = (a + b).trim();
    return res.isEmpty ? '?' : res;
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFFF9FAFB),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: const Color(0xFFEFF6FF),
                child: Text(
                  _initials(title),
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    color: _textDark,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: _textDark,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: _textGrey,
                        fontWeight: FontWeight.w600,
                        height: 1.25,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Icon(Icons.chevron_right, color: _blue),
            ],
          ),
        ),
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  final String text;
  final Color bg;
  final Color fg;

  const _Pill({required this.text, required this.bg, required this.fg});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: fg,
          fontWeight: FontWeight.w900,
          fontSize: 11,
        ),
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