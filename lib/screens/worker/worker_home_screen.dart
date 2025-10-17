// lib/screens/worker/worker_home_screen.dart
import 'package:flutter/material.dart';

class WorkerHomeScreen extends StatefulWidget {
  const WorkerHomeScreen({super.key});
  @override
  State<WorkerHomeScreen> createState() => _WorkerHomeScreenState();
}

class _WorkerHomeScreenState extends State<WorkerHomeScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Turneo — Trabajador'),
        actions: [
          IconButton(
            onPressed: () => Navigator.pushNamed(context, '/worker/events'),
            icon: const Icon(Icons.calendar_month),
            tooltip: 'Calendario',
          ),
        ],
      ),
      body: const Center(child: Text('Panel del trabajador')),
    );
  }
}
