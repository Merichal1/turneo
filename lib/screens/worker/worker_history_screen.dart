// TODO Implement this library.
import 'package:flutter/material.dart';

class WorkerHistoryScreen extends StatefulWidget {
  const WorkerHistoryScreen({super.key});

  @override
  State<WorkerHistoryScreen> createState() => _WorkerHistoryScreenState();
}

class _WorkerHistoryScreenState extends State<WorkerHistoryScreen> {
  String _selectedFilter = 'Todos';

  final List<HistoryEvent> _events = [
    HistoryEvent(
      id: '1',
      title: 'Boda García – Martínez',
      date: '16 Nov 2025',
      time: '18:00 – 02:30',
      role: 'Camarero',
      location: 'Finca La Toscana',
      status: EventStatus.completed,
      extraInfo: '8h · 80€',
    ),
    HistoryEvent(
      id: '2',
      title: 'Cena corporativa Tech Summit',
      date: '17 Nov 2025',
      time: '20:00 – 00:00',
      role: 'Camarero',
      location: 'Hotel Barceló',
      status: EventStatus.upcoming,
      extraInfo: 'Confirmado',
    ),
    HistoryEvent(
      id: '3',
      title: 'Inauguración Galería de Arte',
      date: '10 Nov 2025',
      time: '17:00 – 22:00',
      role: 'Cocinero',
      location: 'Galería Ortega',
      status: EventStatus.completed,
      extraInfo: '5h · 65€',
    ),
    HistoryEvent(
      id: '4',
      title: 'Cocktail empresarial Deloitte',
      date: '5 Nov 2025',
      time: '19:00 – 23:30',
      role: 'Camarero',
      location: 'Torre Sevilla',
      status: EventStatus.rejected,
      extraInfo: 'Rechazado',
    ),
    HistoryEvent(
      id: '5',
      title: 'Fiesta privada',
      date: '30 Oct 2025',
      time: '21:00 – 03:00',
      role: 'Camarero',
      location: 'Casa del Río',
      status: EventStatus.cancelled,
      extraInfo: 'Cancelado por empresa',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final filtered = _events.where((e) {
      if (_selectedFilter == 'Todos') return true;

      final map = {
        'Completados': EventStatus.completed,
        'Rechazados': EventStatus.rejected,
        'Próximos': EventStatus.upcoming,
        'Cancelados': EventStatus.cancelled,
      };

      return e.status == map[_selectedFilter];
    }).toList();

    return SafeArea(
      child: Scaffold(
        backgroundColor: const Color(0xFFF3F4F6),
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 18, 16, 10),
              child: Row(
                children: const [
                  Icon(Icons.history, size: 24),
                  SizedBox(width: 8),
                  Text(
                    'Historial',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),

            // Filtros
            Padding(
              padding: const EdgeInsets.only(left: 16),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _filter('Todos'),
                    _filter('Completados'),
                    _filter('Rechazados'),
                    _filter('Próximos'),
                    _filter('Cancelados'),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 12),

            // Lista
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                itemCount: filtered.length,
                itemBuilder: (context, index) {
                  final e = filtered[index];
                  return _HistoryCard(event: e);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _filter(String label) {
    final selected = label == _selectedFilter;

    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.white : const Color(0xFF111827),
            fontWeight: FontWeight.w500,
          ),
        ),
        selected: selected,
        onSelected: (_) {
          setState(() => _selectedFilter = label);
        },
        selectedColor: const Color(0xFF111827),
        backgroundColor: Colors.white,
        side: const BorderSide(color: Color(0xFFE5E7EB)),
        labelPadding: const EdgeInsets.symmetric(horizontal: 14),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// MODEL
// ─────────────────────────────────────────────────────────────

enum EventStatus { completed, rejected, upcoming, cancelled }

class HistoryEvent {
  final String id;
  final String title;
  final String date;
  final String time;
  final String role;
  final String location;
  final EventStatus status;
  final String extraInfo;

  HistoryEvent({
    required this.id,
    required this.title,
    required this.date,
    required this.time,
    required this.role,
    required this.location,
    required this.status,
    required this.extraInfo,
  });
}

// ─────────────────────────────────────────────────────────────
// CARD WIDGET
// ─────────────────────────────────────────────────────────────

class _HistoryCard extends StatelessWidget {
  final HistoryEvent event;

  const _HistoryCard({required this.event});

  Color _statusColor(EventStatus s) {
    switch (s) {
      case EventStatus.completed:
        return const Color(0xFF10B981);
      case EventStatus.rejected:
        return const Color(0xFFEF4444);
      case EventStatus.upcoming:
        return const Color(0xFF3B82F6);
      case EventStatus.cancelled:
        return const Color(0xFFF59E0B);
    }
  }

  String _statusText(EventStatus s) {
    switch (s) {
      case EventStatus.completed:
        return "Completado";
      case EventStatus.rejected:
        return "Rechazado";
      case EventStatus.upcoming:
        return "Próximo";
      case EventStatus.cancelled:
        return "Cancelado";
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            blurRadius: 10,
            offset: const Offset(0, 4),
            color: Colors.black.withOpacity(0.05),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Título + estado
          Row(
            children: [
              Expanded(
                child: Text(
                  event.title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: _statusColor(event.status).withOpacity(0.12),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  _statusText(event.status),
                  style: TextStyle(
                    color: _statusColor(event.status),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 8),

          // Fecha + Hora
          Row(
            children: [
              const Icon(Icons.calendar_today_outlined, size: 16),
              const SizedBox(width: 6),
              Text(event.date),
              const SizedBox(width: 16),
              const Icon(Icons.schedule, size: 16),
              const SizedBox(width: 6),
              Text(event.time),
            ],
          ),

          const SizedBox(height: 10),

          // Rol
          Row(
            children: [
              const Icon(Icons.work_outline, size: 16),
              const SizedBox(width: 6),
              Text(event.role),
            ],
          ),

          const SizedBox(height: 10),

          // Ubicación
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.location_on_outlined, size: 16),
              const SizedBox(width: 6),
              Expanded(child: Text(event.location)),
            ],
          ),

          const SizedBox(height: 12),

          // Extra info
          Text(
            event.extraInfo,
            style: const TextStyle(
              fontSize: 13,
              color: Color(0xFF6B7280),
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
