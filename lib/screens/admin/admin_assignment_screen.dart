import 'package:flutter/material.dart';

import '../../config/app_config.dart';
import '../../core/services/firestore_service.dart';
import '../../models/evento.dart';
import '../../models/trabajador.dart';
import '../../models/disponibilidad_evento.dart';

class AdminAssignmentScreen extends StatefulWidget {
  final Evento? initialEvento;

  const AdminAssignmentScreen({
    super.key,
    this.initialEvento,
  });

  @override
  State<AdminAssignmentScreen> createState() => _AdminAssignmentScreenState();
}

class _AdminAssignmentScreenState extends State<AdminAssignmentScreen> {
  final String empresaId = AppConfig.empresaId;

  /// Guardamos solo el ID del evento seleccionado
  String? _selectedEventoId;

  @override
  void initState() {
    super.initState();
    _selectedEventoId = widget.initialEvento?.id;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3F4F6),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        title: const Text(
          'Asignación de personal',
          style: TextStyle(
            color: Color(0xFF111827),
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: Column(
        children: [
          const SizedBox(height: 12),

          // =================== SELECTOR DE EVENTO ===================
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: StreamBuilder<List<Evento>>(
              stream: FirestoreService.instance.listenEventos(empresaId),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting &&
                    !snapshot.hasData) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(16),
                      child: CircularProgressIndicator(),
                    ),
                  );
                }

                final eventos = (snapshot.data ?? [])
                    .where((e) => e.estado.toLowerCase() == 'activo')
                    .toList()
                  ..sort((a, b) => a.fechaInicio.compareTo(b.fechaInicio));

                if (eventos.isEmpty) {
                  return const Card(
                    child: Padding(
                      padding: EdgeInsets.all(16),
                      child: Text(
                        'No hay eventos activos.\n'
                        'Crea un evento y márcalo como "Activo" para poder asignar personal.',
                        textAlign: TextAlign.center,
                      ),
                    ),
                  );
                }

                // Aseguramos que _selectedEventoId siempre apunte a uno de la lista
                if (_selectedEventoId == null) {
                  _selectedEventoId = eventos.first.id;
                } else {
                  final existe = eventos.any((e) => e.id == _selectedEventoId);
                  if (!existe) {
                    _selectedEventoId = eventos.first.id;
                  }
                }

                final selectedEvento = eventos.firstWhere(
                  (e) => e.id == _selectedEventoId,
                  orElse: () => eventos.first,
                );

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Selecciona evento',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF374151),
                      ),
                    ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      value: _selectedEventoId,
                      items: eventos
                          .map(
                            (e) => DropdownMenuItem<String>(
                              value: e.id,
                              child: Text(
                                '${e.nombre} · ${_formatFechaCorta(e.fechaInicio)}',
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          )
                          .toList(),
                      onChanged: (value) {
                        setState(() {
                          _selectedEventoId = value;
                        });
                      },
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Sección de enviar solicitudes usando el evento seleccionado
                    _EnviarSolicitudesSection(
                      empresaId: empresaId,
                      evento: selectedEvento,
                    ),

                    const SizedBox(height: 8),

                    // La lista de disponibilidad va en el Expanded de abajo
                  ],
                );
              },
            ),
          ),

          // =================== LISTA DE DISPONIBILIDAD ===================
          Expanded(
            child: StreamBuilder<List<Evento>>(
              stream: FirestoreService.instance.listenEventos(empresaId),
              builder: (context, snapshot) {
                final eventos = (snapshot.data ?? [])
                    .where((e) => e.estado.toLowerCase() == 'activo')
                    .toList()
                  ..sort((a, b) => a.fechaInicio.compareTo(b.fechaInicio));

                if (eventos.isEmpty || _selectedEventoId == null) {
                  return const SizedBox.shrink();
                }

                final selectedEvento = eventos.firstWhere(
                  (e) => e.id == _selectedEventoId,
                  orElse: () => eventos.first,
                );

                return _DisponibilidadList(
                  empresaId: empresaId,
                  evento: selectedEvento,
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ================= SUBWIDGET: Enviar solicitudes =================

class _EnviarSolicitudesSection extends StatelessWidget {
  final String empresaId;
  final Evento evento;

  const _EnviarSolicitudesSection({
    required this.empresaId,
    required this.evento,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Trabajador>>(
      stream: FirestoreService.instance.listenTrabajadores(empresaId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(8),
              child: CircularProgressIndicator(),
            ),
          );
        }

        final trabajadores = snapshot.data ?? [];

        if (trabajadores.isEmpty) {
          return const Card(
            child: Padding(
              padding: EdgeInsets.all(12),
              child: Text(
                'No hay trabajadores registrados en la empresa.',
              ),
            ),
          );
        }

        return Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Evento: ${evento.nombre}\n'
                    'Enviar solicitud de disponibilidad a ${trabajadores.length} trabajadores.',
                    style: const TextStyle(
                      fontSize: 13,
                      color: Color(0xFF374151),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  onPressed: () async {
                    try {
                      await FirestoreService.instance
                          .crearSolicitudesDisponibilidadParaEvento(
                        empresaId: empresaId,
                        eventoId: evento.id,
                        trabajadores: trabajadores,
                      );

                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Solicitudes de disponibilidad enviadas',
                            ),
                          ),
                        );
                      }
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              'Error al enviar solicitudes: $e',
                            ),
                          ),
                        );
                      }
                    }
                  },
                  icon: const Icon(Icons.send_outlined),
                  label: const Text('Enviar'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ================= SUBWIDGET: Lista de disponibilidad =================

class _DisponibilidadList extends StatelessWidget {
  final String empresaId;
  final Evento evento;

  const _DisponibilidadList({
    required this.empresaId,
    required this.evento,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<DisponibilidadEvento>>(
      stream: FirestoreService.instance.listenDisponibilidadEvento(
        empresaId,
        evento.id,
      ),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final lista = snapshot.data ?? [];

        if (lista.isEmpty) {
          return const Center(
            child: Text(
              'Aún no se han enviado solicitudes de disponibilidad\n'
              'o no hay respuestas para este evento.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Color(0xFF6B7280),
              ),
            ),
          );
        }

        // Resumen rápido
        final total = lista.length;
        final aceptados =
            lista.where((d) => d.estado == 'aceptado').length;
        final rechazados =
            lista.where((d) => d.estado == 'rechazado').length;
        final pendientes =
            lista.where((d) => d.estado == 'pendiente').length;
        final asignados = lista.where((d) => d.asignado).length;

        return Column(
          children: [
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Row(
                children: [
                  _ResumenChip(
                    label: 'Total',
                    value: total,
                    colorBg: const Color(0xFFE5E7EB),
                    colorText: const Color(0xFF111827),
                  ),
                  const SizedBox(width: 8),
                  _ResumenChip(
                    label: 'Pendientes',
                    value: pendientes,
                    colorBg: const Color(0xFFFDE68A),
                    colorText: const Color(0xFF92400E),
                  ),
                  const SizedBox(width: 8),
                  _ResumenChip(
                    label: 'Aceptados',
                    value: aceptados,
                    colorBg: const Color(0xFFDCFCE7),
                    colorText: const Color(0xFF166534),
                  ),
                  const SizedBox(width: 8),
                  _ResumenChip(
                    label: 'Asignados',
                    value: asignados,
                    colorBg: const Color(0xFFDBEAFE),
                    colorText: const Color(0xFF1D4ED8),
                  ),
                  const Spacer(),
                  _ResumenChip(
                    label: 'Rechazados',
                    value: rechazados,
                    colorBg: const Color(0xFFFEF2F2),
                    colorText: const Color(0xFFB91C1C),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 4),
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                itemCount: lista.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  final d = lista[index];

                  return Card(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment:
                                  CrossAxisAlignment.start,
                              children: [
                                Text(
                                  d.trabajadorNombre,
                                  style: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                if (d.trabajadorRol.isNotEmpty) ...[
                                  const SizedBox(height: 2),
                                  Text(
                                    d.trabajadorRol,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: Color(0xFF6B7280),
                                    ),
                                  ),
                                ],
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    _EstadoDisponibilidadChip(
                                      estado: d.estado,
                                      asignado: d.asignado,
                                    ),
                                    if (d.asignado) ...[
                                      const SizedBox(width: 8),
                                      const Text(
                                        'Asignado a este evento',
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: Color(0xFF10B981),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          if (d.estado == 'aceptado' && !d.asignado)
                            ElevatedButton(
                              onPressed: () async {
                                await FirestoreService.instance
                                    .marcarTrabajadorAsignado(
                                  empresaId: empresaId,
                                  eventoId: evento.id,
                                  disponibilidadId: d.id,
                                  asignado: true,
                                );

                                if (context.mounted) {
                                  ScaffoldMessenger.of(context)
                                      .showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        'Trabajador asignado a "${evento.nombre}"',
                                      ),
                                    ),
                                  );
                                }
                              },
                              child: const Text('Asignar'),
                            ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }
}

class _ResumenChip extends StatelessWidget {
  final String label;
  final int value;
  final Color colorBg;
  final Color colorText;

  const _ResumenChip({
    required this.label,
    required this.value,
    required this.colorBg,
    required this.colorText,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding:
          const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: colorBg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        children: [
          Text(
            '$label: ',
            style: TextStyle(
              fontSize: 11,
              color: colorText.withOpacity(0.8),
              fontWeight: FontWeight.w500,
            ),
          ),
          Text(
            '$value',
            style: TextStyle(
              fontSize: 11,
              color: colorText,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _EstadoDisponibilidadChip extends StatelessWidget {
  final String estado;
  final bool asignado;

  const _EstadoDisponibilidadChip({
    required this.estado,
    required this.asignado,
  });

  @override
  Widget build(BuildContext context) {
    Color bg;
    Color fg;
    String label = estado;

    switch (estado) {
      case 'aceptado':
        bg = const Color(0xFFDCFCE7);
        fg = const Color(0xFF15803D);
        label = 'Disponible';
        break;
      case 'rechazado':
        bg = const Color(0xFFFEF2F2);
        fg = const Color(0xFFB91C1C);
        label = 'No disponible';
        break;
      case 'pendiente':
      default:
        bg = const Color(0xFFE5E7EB);
        fg = const Color(0xFF4B5563);
        label = 'Pendiente';
        break;
    }

    if (asignado) {
      bg = const Color(0xFFDBEAFE);
      fg = const Color(0xFF1D4ED8);
      label = 'Asignado';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w500,
          color: fg,
        ),
      ),
    );
  }
}

String _formatFechaCorta(DateTime d) {
  final dia = d.day.toString().padLeft(2, '0');
  final mes = d.month.toString().padLeft(2, '0');
  final year = d.year.toString();
  return '$dia/$mes/$year';
}
