import 'package:flutter/material.dart';

import '../../config/app_config.dart';
import '../../core/services/firestore_service.dart';
import '../../models/evento.dart';

class WorkerEventsScreen extends StatefulWidget {
  const WorkerEventsScreen({super.key});

  @override
  State<WorkerEventsScreen> createState() => _WorkerEventsScreenState();
}

class _WorkerEventsScreenState extends State<WorkerEventsScreen> {
  DateTime _focusedMonth = DateUtils.dateOnly(DateTime.now());
  DateTime _selectedDate = DateUtils.dateOnly(DateTime.now());

  @override
  Widget build(BuildContext context) {
    const empresaId = AppConfig.empresaId;

    return SafeArea(
      child: Scaffold(
        backgroundColor: const Color(0xFFF3F4F6),
        body: StreamBuilder<List<Evento>>(
          stream: FirestoreService.instance.listenEventos(
            empresaId,
            // Opcional: solo eventos "activos"
            estado: 'activo',
          ),
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

            final eventosDelMes = eventos.where((e) {
              return e.fechaInicio.year == _focusedMonth.year &&
                  e.fechaInicio.month == _focusedMonth.month;
            }).toList();

            final eventosEnDiaSeleccionado = eventos.where((e) {
              return _isSameDate(e.fechaInicio, _selectedDate);
            }).toList()
              ..sort((a, b) => a.fechaInicio.compareTo(b.fechaInicio));

            return SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Título
                  Row(
                    children: const [
                      Icon(Icons.event_note_outlined, size: 24),
                      SizedBox(width: 8),
                      Text(
                        'Mi calendario',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Revisa tus próximos eventos del mes',
                    style: TextStyle(
                      color: Color(0xFF6B7280),
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Selector de mes
                  _buildMonthSelector(),

                  const SizedBox(height: 12),

                  // Calendario compacto
                  _buildCalendar(
                    eventosDelMes: eventosDelMes,
                  ),

                  const SizedBox(height: 20),

                  // Lista de eventos del día seleccionado
                  Row(
                    children: [
                      const Icon(
                        Icons.today_outlined,
                        size: 20,
                        color: Color(0xFF4B5563),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Eventos para el ${_formatFechaLarga(_selectedDate)}',
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  if (eventosEnDiaSeleccionado.isEmpty)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            blurRadius: 12,
                            offset: const Offset(0, 6),
                            color: Colors.black.withOpacity(0.03),
                          ),
                        ],
                      ),
                      child: const Text(
                        'No tienes eventos asignados este día.\n'
                        'Cuando tu empresa te asigne uno, aparecerá aquí.',
                        style: TextStyle(
                          fontSize: 13,
                          color: Color(0xFF6B7280),
                        ),
                      ),
                    )
                  else
                    Column(
                      children: [
                        for (final e in eventosEnDiaSeleccionado)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: _buildEventCard(e),
                          ),
                      ],
                    ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  // ==========================
  // CABECERA: MES + BOTONES
  // ==========================

  Widget _buildMonthSelector() {
    final meses = [
      'Enero',
      'Febrero',
      'Marzo',
      'Abril',
      'Mayo',
      'Junio',
      'Julio',
      'Agosto',
      'Septiembre',
      'Octubre',
      'Noviembre',
      'Diciembre',
    ];

    final monthName = meses[_focusedMonth.month - 1];

    return Row(
      children: [
        IconButton(
          onPressed: () {
            setState(() {
              _focusedMonth = DateTime(
                _focusedMonth.year,
                _focusedMonth.month - 1,
              );
              _selectedDate = DateUtils.dateOnly(_focusedMonth);
            });
          },
          icon: const Icon(Icons.chevron_left),
        ),
        Expanded(
          child: Center(
            child: Text(
              '$monthName ${_focusedMonth.year}',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
        IconButton(
          onPressed: () {
            setState(() {
              _focusedMonth = DateTime(
                _focusedMonth.year,
                _focusedMonth.month + 1,
              );
              _selectedDate = DateUtils.dateOnly(_focusedMonth);
            });
          },
          icon: const Icon(Icons.chevron_right),
        ),
      ],
    );
  }

  // ==========================
  // CALENDARIO MENSUAL SIMPLE
  // ==========================

  Widget _buildCalendar({
    required List<Evento> eventosDelMes,
  }) {
    final firstDayOfMonth = DateTime(_focusedMonth.year, _focusedMonth.month, 1);
    final lastDayOfMonth =
        DateTime(_focusedMonth.year, _focusedMonth.month + 1, 0);

    // Lunes = 1, Domingo = 7 → ajustamos para empezar en lunes
    final startingWeekday = (firstDayOfMonth.weekday + 6) % 7;

    final daysInMonth = lastDayOfMonth.day;

    final List<Widget> dayWidgets = [];

    // Encabezado de días
    const nombresDias = ['L', 'M', 'X', 'J', 'V', 'S', 'D'];
    dayWidgets.addAll(
      nombresDias
          .map(
            (d) => Center(
              child: Text(
                d,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF9CA3AF),
                ),
              ),
            ),
          )
          .toList(),
    );

    // Huecos vacíos antes del día 1
    for (int i = 0; i < startingWeekday; i++) {
      dayWidgets.add(const SizedBox.shrink());
    }

    // Días del mes
    for (int day = 1; day <= daysInMonth; day++) {
      final date = DateTime(_focusedMonth.year, _focusedMonth.month, day);
      final isSelected = _isSameDate(date, _selectedDate);

      final hasEvent = eventosDelMes.any(
        (e) => _isSameDate(e.fechaInicio, date),
      );

      dayWidgets.add(
        GestureDetector(
          onTap: () {
            setState(() {
              _selectedDate = DateUtils.dateOnly(date);
            });
          },
          child: Container(
            margin: const EdgeInsets.all(2),
            decoration: BoxDecoration(
              color: isSelected ? const Color(0xFF2563EB) : Colors.white,
              borderRadius: BorderRadius.circular(999),
              border: hasEvent
                  ? Border.all(
                      color: isSelected
                          ? Colors.white
                          : const Color(0xFF2563EB),
                      width: 1.6,
                    )
                  : Border.all(
                      color: const Color(0xFFE5E7EB),
                    ),
            ),
            child: Center(
              child: Text(
                '$day',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight:
                      isSelected ? FontWeight.w600 : FontWeight.normal,
                  color: isSelected ? Colors.white : const Color(0xFF111827),
                ),
              ),
            ),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
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
      child: GridView.count(
        crossAxisCount: 7,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        children: dayWidgets,
      ),
    );
  }

  // ==========================
  // CARD DE EVENTO
  // ==========================

  Widget _buildEventCard(Evento e) {
    final rangoHora =
        '${_formatHora(e.fechaInicio)} - ${_formatHora(e.fechaFin)}';

    final ubicacion = [
      if (e.ciudad.isNotEmpty) e.ciudad,
      if (e.direccion.isNotEmpty) e.direccion,
    ].join(' · ');

    final diasRestantes =
        DateUtils.dateOnly(e.fechaInicio).difference(DateUtils.dateOnly(DateTime.now())).inDays;

    String diasText;
    if (diasRestantes < 0) {
      diasText = 'Evento pasado';
    } else if (diasRestantes == 0) {
      diasText = 'Hoy';
    } else if (diasRestantes == 1) {
      diasText = 'Mañana';
    } else {
      diasText = 'En $diasRestantes días';
    }

    return Container(
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
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Título y estado
          Row(
            children: [
              Expanded(
                child: Text(
                  e.nombre,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              _EstadoChip(estado: e.estado),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              const Icon(Icons.access_time, size: 16, color: Color(0xFF6B7280)),
              const SizedBox(width: 6),
              Text(
                rangoHora,
                style: const TextStyle(
                  fontSize: 13,
                  color: Color(0xFF4B5563),
                ),
              ),
            ],
          ),
          if (ubicacion.isNotEmpty) ...[
            const SizedBox(height: 4),
            Row(
              children: [
                const Icon(Icons.place_outlined,
                    size: 16, color: Color(0xFF6B7280)),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    ubicacion,
                    style: const TextStyle(
                      fontSize: 13,
                      color: Color(0xFF4B5563),
                    ),
                  ),
                ),
              ],
            ),
          ],
          if (e.tipo.isNotEmpty) ...[
            const SizedBox(height: 4),
            Row(
              children: [
                const Icon(Icons.style_outlined,
                    size: 16, color: Color(0xFF9CA3AF)),
                const SizedBox(width: 6),
                Text(
                  e.tipo,
                  style: const TextStyle(
                    fontSize: 13,
                    color: Color(0xFF6B7280),
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 8),
          Row(
            children: [
              Chip(
                label: Text(
                  diasText,
                  style: const TextStyle(fontSize: 12),
                ),
                backgroundColor: const Color(0xFFE0F2FE),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              const SizedBox(width: 8),
              if (e.cantidadRequeridaTrabajadores > 0)
                Chip(
                  label: Text(
                    '${e.cantidadRequeridaTrabajadores} trabajadores necesarios',
                    style: const TextStyle(fontSize: 12),
                  ),
                  backgroundColor: const Color(0xFFF3F4F6),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  // ==========================
  // HELPERS
  // ==========================

  bool _isSameDate(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  String _formatFechaLarga(DateTime d) {
    final dias = [
      'lunes',
      'martes',
      'miércoles',
      'jueves',
      'viernes',
      'sábado',
      'domingo',
    ];
    final meses = [
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

    final weekdayName = dias[d.weekday - 1];
    final monthName = meses[d.month - 1];

    return '$weekdayName ${d.day} de $monthName';
  }

  String _formatHora(DateTime d) {
    final h = d.hour.toString().padLeft(2, '0');
    final m = d.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }
}

class _EstadoChip extends StatelessWidget {
  final String estado;

  const _EstadoChip({required this.estado});

  @override
  Widget build(BuildContext context) {
    Color bg;
    Color fg;

    switch (estado) {
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
        estado,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w500,
          color: fg,
        ),
      ),
    );
  }
}
