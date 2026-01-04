import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/evento.dart';
import 'event_map_card.dart';

class WorkerEventDetailsSheet {
  static Future<void> open(BuildContext context, Evento e) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetCtx) => Padding(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 16,
          bottom: MediaQuery.of(sheetCtx).padding.bottom + 16,
        ),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  Expanded(
                    child: Text(
                      e.nombre,
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(sheetCtx).pop(),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),

              const SizedBox(height: 6),
              Text(
                (e.tipo.trim().isEmpty) ? "Evento" : e.tipo,
                style: const TextStyle(color: Colors.grey),
              ),

              const SizedBox(height: 12),

              // Fechas
              _InfoRow(
                icon: Icons.calendar_today_outlined,
                label: "Inicio",
                value: DateFormat('dd/MM/yyyy HH:mm').format(e.fechaInicio),
              ),
              const SizedBox(height: 6),
              _InfoRow(
                icon: Icons.schedule_outlined,
                label: "Fin",
                value: DateFormat('dd/MM/yyyy HH:mm').format(e.fechaFin),
              ),

              const SizedBox(height: 12),

              // Dirección
              _InfoRow(
                icon: Icons.location_on_outlined,
                label: "Dirección",
                value: _address(e),
              ),

              const SizedBox(height: 12),

              // Mapa (incluye botón "Abrir en Google Maps")
              EventMapCard(evento: e),

              const SizedBox(height: 18),
            ],
          ),
        ),
      ),
    );
  }

  static String _address(Evento e) {
    final parts = <String>[];
    if (e.direccion.trim().isNotEmpty) parts.add(e.direccion.trim());
    if (e.ciudad.trim().isNotEmpty) parts.add(e.ciudad.trim());
    return parts.isEmpty ? "—" : parts.join(', ');
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: const Color(0xFF6B7280)),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280))),
              const SizedBox(height: 2),
              Text(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      ],
    );
  }
}
