// TODO Implement this library.
import 'package:flutter/material.dart';

class WorkerAvailabilityScreen extends StatefulWidget {
  const WorkerAvailabilityScreen({super.key});

  @override
  State<WorkerAvailabilityScreen> createState() =>
      _WorkerAvailabilityScreenState();
}

class _WorkerAvailabilityScreenState extends State<WorkerAvailabilityScreen> {
  DateTime _focusedMonth = DateTime(2025, 11);
  final Set<DateTime> _unavailableDays = {
    DateTime(2025, 11, 13),
    DateTime(2025, 11, 15),
    DateTime(2025, 11, 20),
  };

  @override
  Widget build(BuildContext context) {
    final daysList = _unavailableDays.toList()
      ..sort((a, b) => a.compareTo(b));

    return SafeArea(
      child: Scaffold(
        backgroundColor: const Color(0xFFF3F4F6),
        body: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: const [
                  Icon(Icons.event_busy_outlined),
                  SizedBox(width: 8),
                  Text(
                    'Disponibilidad futura',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Calendario selección no disponible
              _Card(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Marca tus días no disponibles',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Selecciona en el calendario los días en los que NO estás disponible para trabajar',
                      style: TextStyle(
                        fontSize: 13,
                        color: Color(0xFF6B7280),
                      ),
                    ),
                    const SizedBox(height: 16),
                    _AvailabilityCalendar(
                      focusedMonth: _focusedMonth,
                      unavailableDays: _unavailableDays,
                      onPreviousMonth: () {
                        setState(() {
                          _focusedMonth = DateTime(
                              _focusedMonth.year, _focusedMonth.month - 1);
                        });
                      },
                      onNextMonth: () {
                        setState(() {
                          _focusedMonth = DateTime(
                              _focusedMonth.year, _focusedMonth.month + 1);
                        });
                      },
                      onToggleDay: (day) {
                        setState(() {
                          final normalized =
                              DateTime(day.year, day.month, day.day);
                          if (_unavailableDays
                              .any((d) => _isSameDate(d, normalized))) {
                            _unavailableDays.removeWhere(
                                (d) => _isSameDate(d, normalized));
                          } else {
                            _unavailableDays.add(normalized);
                          }
                        });
                      },
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // Lista de días marcados
              _Card(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Text(
                          'Días marcados como no disponible:',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFFE5E7EB),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            '${daysList.length}',
                            style: const TextStyle(fontSize: 12),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    ...daysList.map(
                      (d) => Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                _formatFullDateES(d),
                                style: const TextStyle(fontSize: 14),
                              ),
                            ),
                            TextButton(
                              onPressed: () {
                                setState(() {
                                  _unavailableDays
                                      .removeWhere((x) => _isSameDate(x, d));
                                });
                              },
                              child: const Text(
                                'Eliminar',
                                style: TextStyle(
                                  color: Color(0xFFDC2626),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () {
                          // TODO: guardar en backend
                        },
                        icon: const Icon(Icons.save_outlined, size: 18),
                        label: const Text('Guardar disponibilidad'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF111827),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(999),
                          ),
                        ),
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
  }

  bool _isSameDate(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  String _formatFullDateES(DateTime d) {
    const weekdays = [
      'lunes',
      'martes',
      'miércoles',
      'jueves',
      'viernes',
      'sábado',
      'domingo',
    ];
    const months = [
      'enero',
      'febrero',
      'marzo',
      'abril',
      'mayo',
      'junio',
      'julio',
      'agosto',
      'septiembre',
      'octubre',
      'noviembre',
      'diciembre',
    ];
    final wd = weekdays[d.weekday - 1];
    final m = months[d.month - 1];
    return '$wd, ${d.day} de $m de ${d.year}';
  }
}

class _AvailabilityCalendar extends StatelessWidget {
  final DateTime focusedMonth;
  final Set<DateTime> unavailableDays;
  final VoidCallback onPreviousMonth;
  final VoidCallback onNextMonth;
  final ValueChanged<DateTime> onToggleDay;

  const _AvailabilityCalendar({
    super.key,
    required this.focusedMonth,
    required this.unavailableDays,
    required this.onPreviousMonth,
    required this.onNextMonth,
    required this.onToggleDay,
  });

  bool _isSameDate(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  @override
  Widget build(BuildContext context) {
    final firstDayOfMonth = DateTime(focusedMonth.year, focusedMonth.month, 1);
    final int startWeekday = firstDayOfMonth.weekday; // 1=Mon...7=Sun
    final firstDisplayedDay =
        firstDayOfMonth.subtract(Duration(days: startWeekday));
    const totalCells = 42;

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            IconButton(
              visualDensity: VisualDensity.compact,
              icon: const Icon(Icons.chevron_left),
              onPressed: onPreviousMonth,
            ),
            Text(
              '${_monthES(focusedMonth.month)} ${focusedMonth.year}',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            IconButton(
              visualDensity: VisualDensity.compact,
              icon: const Icon(Icons.chevron_right),
              onPressed: onNextMonth,
            ),
          ],
        ),
        const SizedBox(height: 4),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: const [
            _WeekdayLabel('Su'),
            _WeekdayLabel('Mo'),
            _WeekdayLabel('Tu'),
            _WeekdayLabel('We'),
            _WeekdayLabel('Th'),
            _WeekdayLabel('Fr'),
            _WeekdayLabel('Sa'),
          ],
        ),
        const SizedBox(height: 4),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: totalCells,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 7,
            mainAxisSpacing: 4,
            crossAxisSpacing: 4,
          ),
          itemBuilder: (context, index) {
            final day = firstDisplayedDay.add(Duration(days: index));
            final isInMonth =
                day.month == focusedMonth.month && day.year == focusedMonth.year;
            final isUnavailable = unavailableDays
                .any((d) => _isSameDate(d, day));

            Color bg;
            Color text;

            if (!isInMonth) {
              bg = Colors.transparent;
              text = const Color(0xFFCBD5F5);
            } else if (isUnavailable) {
              bg = const Color(0xFFFEE2E2);
              text = const Color(0xFFB91C1C);
            } else {
              bg = Colors.transparent;
              text = const Color(0xFF111827);
            }

            return GestureDetector(
              onTap: isInMonth ? () => onToggleDay(day) : null,
              child: Container(
                decoration: BoxDecoration(
                  color: bg,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: Text(
                    '${day.day}',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: text,
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  String _monthES(int m) {
    const months = [
      'enero',
      'febrero',
      'marzo',
      'abril',
      'mayo',
      'junio',
      'julio',
      'agosto',
      'septiembre',
      'octubre',
      'noviembre',
      'diciembre'
    ];
    return months[m - 1];
  }
}

class _WeekdayLabel extends StatelessWidget {
  final String label;
  const _WeekdayLabel(this.label);

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Center(
        child: Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            color: Color(0xFF9CA3AF),
          ),
        ),
      ),
    );
  }
}

class _Card extends StatelessWidget {
  final Widget child;

  const _Card({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            blurRadius: 18,
            offset: const Offset(0, 8),
            color: Colors.black.withOpacity(0.04),
          ),
        ],
      ),
      child: child,
    );
  }
}
