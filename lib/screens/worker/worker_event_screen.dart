// lib/screens/worker/worker_event_screen.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class WorkerEventScreen extends StatelessWidget {
  const WorkerEventScreen({super.key});

  Duration _remainingTo(DateTime date) => date.difference(DateTime.now());

  @override
  Widget build(BuildContext context) {
    final events = [
      {
        'name': 'Evento A',
        'date': DateTime.now().add(const Duration(hours: 26)),
        'location': 'Córdoba',
      },
      {
        'name': 'Evento B',
        'date': DateTime.now().add(const Duration(days: 2, hours: 3)),
        'location': 'Sevilla',
      },
    ];

    return Scaffold(
      appBar: AppBar(title: const Text('Mis eventos')),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: events.length,
        itemBuilder: (_, i) {
          final e = events[i];
          final date = e['date'] as DateTime;
          final remaining = _remainingTo(date);
          final countdown =
              '${remaining.inDays}d ${remaining.inHours.remainder(24)}h ${remaining.inMinutes.remainder(60)}m';
          final formattedDate =
              DateFormat('EEE d MMM, HH:mm', 'es_ES').format(date);

          return Card(
            margin: const EdgeInsets.symmetric(vertical: 8),
            child: ListTile(
              leading: const Icon(Icons.event_available),
              title: Text(e['name'] as String),
              subtitle: Text(
                '📅 $formattedDate\n📍 ${e['location']}\n⏳ $countdown',
              ),
              isThreeLine: true,
            ),
          );
        },
      ),
    );
  }
}
