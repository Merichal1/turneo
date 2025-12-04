import 'package:flutter/material.dart';

class AdminEventScreen extends StatefulWidget {
  const AdminEventScreen({super.key});

  @override
  State<AdminEventScreen> createState() => _AdminEventScreenState();
}

class _AdminEventScreenState extends State<AdminEventScreen> {
  String _calendarView = "Mes"; // Mes / Semana

  void _openEventDetail(EventDetailData data) {
    showGeneralDialog(
      context: context,
      barrierLabel: 'Detalle Evento',
      barrierDismissible: true,
      barrierColor: Colors.black54,
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (ctx, anim1, anim2) {
        return Align(
          alignment: Alignment.centerRight,
          child: FractionallySizedBox(
            widthFactor: 0.6,
            child: EventDetailPanel(data: data),
          ),
        );
      },
      transitionBuilder: (ctx, anim, secAnim, child) {
        final curved = CurvedAnimation(
          parent: anim,
          curve: Curves.easeOutCubic,
        );
        return SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(1, 0),
            end: Offset.zero,
          ).animate(curved),
          child: child,
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Título
            Text(
              'Gestión de Eventos',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 6),
            Text(
              'Calendario y planificación de eventos',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: const Color(0xFF6B7280),
                  ),
            ),
            const SizedBox(height: 24),

            // Botones acciones rápidas
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                _TopActionButton(
                  icon: Icons.add,
                  label: "Crear Evento",
                  primary: true,
                  onTap: () {
                    // TODO: navegar a crear evento
                  },
                ),
                const SizedBox(width: 12),
                _TopActionButton(
                  icon: Icons.send_outlined,
                  label: "Enviar Disponibilidad",
                  onTap: () {
                    // TODO: lógica de enviar disponibilidad
                  },
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Selector Mes / Semana
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                _CalendarSelector(
                  selected: _calendarView,
                  onChange: (v) {
                    setState(() => _calendarView = v);
                  },
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Calendario + Historial
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Calendario
                  const Expanded(
                    flex: 3,
                    child: _CalendarPlaceholder(),
                  ),
                  const SizedBox(width: 20),
                  // Historial
                  Expanded(
                    flex: 2,
                    child: EventHistory(
                      onEventTap: _openEventDetail,
                    ),
                  ),
                ],
              ),
            )
          ],
        ),
      ),
    );
  }
}

// ──────────────────────────────── MODELOS MOCKUP ─────────────────────────────

class EventDetailData {
  final String title;
  final String company;
  final String status; // Confirmado / Pendiente…
  final List<String> tags; // p.ej. ['Boda', 'Eventos Premium']
  final String dateText; // '2025-11-15 • 19:00 - 02:00'
  final String location;
  final String locationExtra; // 'Hotel Ritz, Madrid'
  final String staffSummary; // '10 Camareros • 2 Cocineros'
  final int accepted;
  final int pending;
  final int rejected;
  final List<WorkerStatus> workers;

  EventDetailData({
    required this.title,
    required this.company,
    required this.status,
    required this.tags,
    required this.dateText,
    required this.location,
    required this.locationExtra,
    required this.staffSummary,
    required this.accepted,
    required this.pending,
    required this.rejected,
    required this.workers,
  });
}

class WorkerStatus {
  final String name;
  final String role;
  final String status; // Aceptado / Pendiente / Rechazado

  WorkerStatus({
    required this.name,
    required this.role,
    required this.status,
  });
}

// ───────────────────────────────── Calendario (placeholder) ────────────────

class _CalendarPlaceholder extends StatelessWidget {
  const _CalendarPlaceholder();

  @override
  Widget build(BuildContext context) {
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
      child: const Center(
        child: Text(
          "📅 Calendario (mockup temporal)",
          style: TextStyle(
            fontSize: 18,
            color: Colors.grey,
          ),
        ),
      ),
    );
  }
}

// ───────────────────────────────── Historial de eventos ─────────────────────

class EventHistory extends StatelessWidget {
  final void Function(EventDetailData) onEventTap;

  const EventHistory({
    super.key,
    required this.onEventTap,
  });

  @override
  Widget build(BuildContext context) {
    // Aquí definimos unos eventos mock para el historial + detalle
    final events = <EventDetailData>[
      EventDetailData(
        title: 'Boda Hotel Ritz',
        company: 'Eventos Premium',
        status: 'Confirmado',
        tags: ['Boda', 'Eventos Premium'],
        dateText: '2025-11-15 • 19:00 - 02:00',
        location: 'Hotel Ritz',
        locationExtra: 'Hotel Ritz, Madrid',
        staffSummary: '10 Camareros • 2 Cocineros',
        accepted: 4,
        pending: 1,
        rejected: 1,
        workers: [
          WorkerStatus(name: 'María García', role: 'Camarero', status: 'Aceptado'),
          WorkerStatus(name: 'Juan Pérez', role: 'Camarero', status: 'Aceptado'),
          WorkerStatus(name: 'Ana Martínez', role: 'Camarero', status: 'Pendiente'),
          WorkerStatus(name: 'Carlos Ruiz', role: 'Camarero', status: 'Rechazado'),
          WorkerStatus(name: 'Laura Sánchez', role: 'Cocinero', status: 'Aceptado'),
          WorkerStatus(name: 'Pedro López', role: 'Cocinero', status: 'Aceptado'),
        ],
      ),
      EventDetailData(
        title: 'Cena Corporativa',
        company: 'Tech Events',
        status: 'Pendiente',
        tags: ['Cena', 'Tech Summit Center'],
        dateText: '2025-11-18 • 20:00 - 01:00',
        location: 'Tech Summit Center',
        locationExtra: 'Tech Summit Center',
        staffSummary: '6 Camareros • 2 Cocineros',
        accepted: 2,
        pending: 3,
        rejected: 1,
        workers: [
          WorkerStatus(name: 'Ana Martínez', role: 'Cocinero', status: 'Aceptado'),
          WorkerStatus(name: 'Carlos Ruiz', role: 'Camarero', status: 'Aceptado'),
          WorkerStatus(name: 'Sofía Fernández', role: 'Cocinero', status: 'Pendiente'),
          WorkerStatus(name: 'Diego Torres', role: 'Camarero', status: 'Pendiente'),
          WorkerStatus(name: 'Pedro López', role: 'Camarero', status: 'Rechazado'),
        ],
      ),
      EventDetailData(
        title: 'Cóctel Inauguración',
        company: 'Arte y Cultura',
        status: 'Confirmado',
        tags: ['Cóctel', 'Galería Arte'],
        dateText: '2025-11-20 • 18:00 - 23:00',
        location: 'Galería Arte',
        locationExtra: 'Galería Arte',
        staffSummary: '5 Camareros • 1 Cocinero',
        accepted: 5,
        pending: 0,
        rejected: 0,
        workers: [
          WorkerStatus(name: 'Juan Pérez', role: 'Camarero', status: 'Aceptado'),
          WorkerStatus(name: 'Carlos Ruiz', role: 'Camarero', status: 'Aceptado'),
          WorkerStatus(name: 'Diego Torres', role: 'Camarero', status: 'Aceptado'),
          WorkerStatus(name: 'Laura Sánchez', role: 'Cocinero', status: 'Aceptado'),
          WorkerStatus(name: 'Pedro López', role: 'Camarero', status: 'Aceptado'),
        ],
      ),
      EventDetailData(
        title: 'Banquete Navidad',
        company: 'Empresa ABC',
        status: 'Confirmado',
        tags: ['Banquete', 'Empresa ABC'],
        dateText: '2025-11-22 • 21:00 - 03:00',
        location: 'Empresa ABC',
        locationExtra: 'Empresa ABC',
        staffSummary: '12 Camareros • 3 Cocineros',
        accepted: 10,
        pending: 3,
        rejected: 2,
        workers: [
          WorkerStatus(name: 'María García', role: 'Camarero', status: 'Aceptado'),
          WorkerStatus(name: 'Juan Pérez', role: 'Camarero', status: 'Aceptado'),
          WorkerStatus(name: 'Ana Martínez', role: 'Cocinero', status: 'Aceptado'),
        ],
      ),
      EventDetailData(
        title: 'Conferencia Tech',
        company: 'Tech Events',
        status: 'Pendiente',
        tags: ['Conferencia', 'Centro Convenciones'],
        dateText: '2025-11-25 • 09:00 - 18:00',
        location: 'Centro Convenciones',
        locationExtra: 'Centro Convenciones',
        staffSummary: '8 Camareros • 4 Cocineros',
        accepted: 3,
        pending: 6,
        rejected: 1,
        workers: [
          WorkerStatus(name: 'Carlos Ruiz', role: 'Camarero', status: 'Pendiente'),
        ],
      ),
    ];

    return Container(
      padding: const EdgeInsets.all(18),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Historial de Eventos',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: ListView.builder(
              itemCount: events.length,
              itemBuilder: (context, index) {
                final e = events[index];
                return HistoryItem(
                  title: e.title,
                  dateText: e.dateText.split('•').first.trim(), // solo fecha
                  location: e.locationExtra,
                  workersSummary: e.staffSummary,
                  status: e.status,
                  onTap: () => onEventTap(e),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class HistoryItem extends StatelessWidget {
  final String title;
  final String dateText;
  final String location;
  final String workersSummary;
  final String status;
  final VoidCallback onTap;

  const HistoryItem({
    super.key,
    required this.title,
    required this.dateText,
    required this.location,
    required this.workersSummary,
    required this.status,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isConfirmed = status.toLowerCase() == "confirmado";

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    "$dateText   •   $location   •   $workersSummary",
                    style: const TextStyle(
                      color: Color(0xFF6B7280),
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: isConfirmed ? Colors.black : Colors.grey.shade300,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                status,
                style: TextStyle(
                  color: isConfirmed ? Colors.white : Colors.black,
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ────────────────────────────── Panel detalle de evento ─────────────────────

class EventDetailPanel extends StatelessWidget {
  final EventDetailData data;

  const EventDetailPanel({super.key, required this.data});

  Color _statusColor(String status) {
    final lower = status.toLowerCase();
    if (lower == 'confirmado') return const Color(0xFF16A34A);
    if (lower == 'pendiente') return const Color(0xFFF97316);
    if (lower == 'rechazado') return const Color(0xFFDC2626);
    return const Color(0xFF6B7280);
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: SafeArea(
        child: Align(
          alignment: Alignment.centerRight,
          child: Container(
            margin: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFF9FAFB),
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  blurRadius: 24,
                  offset: const Offset(-8, 8),
                  color: Colors.black.withOpacity(0.1),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: Scaffold(
                backgroundColor: const Color(0xFFF9FAFB),
                body: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Cabecera
                    Padding(
                      padding: const EdgeInsets.fromLTRB(24, 20, 16, 16),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  data.title,
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleLarge
                                      ?.copyWith(
                                        fontWeight: FontWeight.bold,
                                      ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  data.company,
                                  style: const TextStyle(
                                    color: Color(0xFF6B7280),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Wrap(
                                  spacing: 6,
                                  runSpacing: 4,
                                  children: [
                                    _chip(
                                      label: data.status,
                                      bg: _statusColor(data.status)
                                          .withOpacity(0.1),
                                      fg: _statusColor(data.status),
                                    ),
                                    ...data.tags.map(
                                      (t) => _chip(
                                        label: t,
                                        bg: const Color(0xFFE5E7EB),
                                        fg: const Color(0xFF111827),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            onPressed: () => Navigator.of(context).pop(),
                            icon: const Icon(Icons.close),
                          ),
                        ],
                      ),
                    ),

                    const Divider(height: 1),

                    Expanded(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Primera fila de tarjetas
                            Row(
                              children: [
                                Expanded(
                                  child: _InfoCard(
                                    title: 'Fecha y Hora',
                                    lines: [
                                      data.dateText,
                                    ],
                                    icon: Icons.access_time,
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: _InfoCard(
                                    title: 'Ubicación',
                                    lines: [
                                      data.location,
                                      data.locationExtra,
                                    ],
                                    icon: Icons.location_on_outlined,
                                    trailing: TextButton(
                                      onPressed: () {
                                        // TODO: abrir mapa
                                      },
                                      child: const Text('Ver en mapa'),
                                    ),
                                  ),
                                ),
                              ],
                            ),

                            const SizedBox(height: 16),

                            // Segunda fila de tarjetas
                            Row(
                              children: [
                                Expanded(
                                  child: _InfoCard(
                                    title: 'Personal Necesario',
                                    lines: [
                                      data.staffSummary,
                                    ],
                                    icon: Icons.group_outlined,
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: _InfoCard(
                                    title: 'Estado Respuestas',
                                    lines: [
                                      '${data.accepted} Aceptados',
                                      '${data.pending} Pendientes',
                                      '${data.rejected} Rechazados',
                                    ],
                                    icon: Icons.check_circle_outline,
                                  ),
                                ),
                              ],
                            ),

                            const SizedBox(height: 16),

                            // Botones de acción
                            Row(
                              children: [
                                ElevatedButton.icon(
                                  onPressed: () {
                                    // TODO: reenviar disponibilidad
                                  },
                                  icon: const Icon(Icons.send),
                                  label: const Text('Enviar Disponibilidad'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF111827),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(999),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                OutlinedButton.icon(
                                  onPressed: () {
                                    // TODO: editar evento
                                  },
                                  icon: const Icon(Icons.edit_outlined),
                                  label: const Text('Editar'),
                                  style: OutlinedButton.styleFrom(
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(999),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                OutlinedButton.icon(
                                  onPressed: () {
                                    // TODO: ver mapa
                                  },
                                  icon:
                                      const Icon(Icons.map_outlined, size: 18),
                                  label: const Text('Ver mapa'),
                                  style: OutlinedButton.styleFrom(
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(999),
                                    ),
                                  ),
                                ),
                              ],
                            ),

                            const SizedBox(height: 24),

                            // Lista de trabajadores convocados
                            Text(
                              'Trabajadores Convocados',
                              style: Theme.of(context)
                                  .textTheme
                                  .titleMedium
                                  ?.copyWith(fontWeight: FontWeight.w600),
                            ),
                            const SizedBox(height: 12),

                            Container(
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
                              child: ListView.separated(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                itemCount: data.workers.length,
                                separatorBuilder: (_, __) =>
                                    const Divider(height: 1),
                                itemBuilder: (context, index) {
                                  final w = data.workers[index];
                                  return ListTile(
                                    contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 4,
                                    ),
                                    leading: CircleAvatar(
                                      radius: 18,
                                      child: Text(
                                        w.name.isNotEmpty
                                            ? w.name[0]
                                            : '?',
                                      ),
                                    ),
                                    title: Text(w.name),
                                    subtitle: Text(w.role),
                                    trailing: _statusPill(w.status),
                                  );
                                },
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _chip({
    required String label,
    required Color bg,
    required Color fg,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: fg,
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Widget _statusPill(String status) {
    final color = _statusColor(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        status,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  final String title;
  final List<String> lines;
  final IconData icon;
  final Widget? trailing;

  const _InfoCard({
    required this.title,
    required this.lines,
    required this.icon,
    this.trailing,
  });

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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 20, color: const Color(0xFF6B7280)),
              const SizedBox(width: 8),
              Text(
                title,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
              ),
              const Spacer(),
              if (trailing != null) trailing!,
            ],
          ),
          const SizedBox(height: 10),
          ...lines.map(
            (l) => Padding(
              padding: const EdgeInsets.only(bottom: 2),
              child: Text(
                l,
                style: const TextStyle(
                  color: Color(0xFF111827),
                  fontSize: 13,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ───────────────────────────────── Selector Mes / Semana ────────────────────

class _CalendarSelector extends StatelessWidget {
  final String selected;
  final Function(String) onChange;

  const _CalendarSelector({
    required this.selected,
    required this.onChange,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFFF3F4F6),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          _selectorButton("Mes"),
          _selectorButton("Semana"),
        ],
      ),
    );
  }

  Widget _selectorButton(String v) {
    final bool isActive = selected == v;
    return InkWell(
      onTap: () => onChange(v),
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isActive ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(
          v,
          style: TextStyle(
            fontWeight: FontWeight.w500,
            color: isActive ? Colors.black : Colors.grey[600],
          ),
        ),
      ),
    );
  }
}

// ───────────────────────────────── Botones superiores ───────────────────────

class _TopActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool primary;
  final VoidCallback onTap;

  const _TopActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.primary = false,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
        decoration: BoxDecoration(
          color: primary ? Colors.black : Colors.white,
          border: Border.all(
            color: primary ? Colors.transparent : const Color(0xFFE5E7EB),
          ),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 18,
              color: primary ? Colors.white : Colors.black,
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: primary ? Colors.white : Colors.black,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
