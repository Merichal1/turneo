import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../config/app_config.dart';
import '../../core/services/firestore_service.dart';

class AdminNotificacionesScreen extends StatefulWidget {
  const AdminNotificacionesScreen({super.key});

  @override
  State<AdminNotificacionesScreen> createState() =>
      _AdminNotificacionesScreenState();
}

class _AdminNotificacionesScreenState extends State<AdminNotificacionesScreen> {
  final String _empresaId = AppConfig.empresaId;

  String _filtro = 'Todas';
  final List<String> _chips = const [
    'Todas',
    'Sistema',
    'Usuarios',
    'Eventos',
  ];

  @override
  Widget build(BuildContext context) {
    final notifsQuery = FirestoreService.instance
        .notificacionesRef(_empresaId)
        .orderBy('creadoEn', descending: true);

    return Scaffold(
      backgroundColor: const Color(0xFFF3F4F6),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        title: const Text(
          'Notificaciones (Admin)',
          style: TextStyle(
            color: Color(0xFF111827),
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _abrirCrearNotificacion,
        icon: const Icon(Icons.add),
        label: const Text('Nueva notificación'),
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: notifsQuery.snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting &&
              !snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Text(
                'Error al cargar notificaciones:\n${snapshot.error}',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.red),
              ),
            );
          }

          final docs = snapshot.data?.docs ?? [];

          // Pasamos los docs a modelo interno
          final all = docs.map((doc) {
            final data = doc.data();
            final ts = data['creadoEn'] as Timestamp?;
            return _Notif(
              id: doc.id,
              title: (data['titulo'] as String?) ?? '',
              body: (data['body'] as String?) ?? '',
              tag: (data['tag'] as String?) ?? 'Sistema',
              createdAt: ts?.toDate() ?? DateTime.now(),
            );
          }).toList();

          final items = _filtrar(all);

          return RefreshIndicator(
            onRefresh: () async {
              // El stream ya refresca solo; esto solo hace el "efecto"
              await Future<void>.delayed(const Duration(milliseconds: 400));
            },
            child: Column(
              children: [
                // ====== Chips de filtro ======
                SizedBox(
                  height: 56,
                  child: ListView.separated(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    scrollDirection: Axis.horizontal,
                    separatorBuilder: (_, __) => const SizedBox(width: 8),
                    itemCount: _chips.length,
                    itemBuilder: (context, i) {
                      final label = _chips[i];
                      final selected = _filtro == label;
                      return ChoiceChip(
                        label: Text(label),
                        selected: selected,
                        onSelected: (_) =>
                            setState(() => _filtro = label),
                      );
                    },
                  ),
                ),
                const Divider(height: 1),

                // ====== Lista agrupada por fecha ======
                Expanded(
                  child: items.isEmpty
                      ? const _EmptyState(
                          title: 'Sin notificaciones',
                          subtitle:
                              'Pulsa en "Nueva notificación" para enviar una.',
                          icon: Icons.notifications_off_outlined,
                        )
                      : ListView.builder(
                          physics:
                              const AlwaysScrollableScrollPhysics(),
                          itemCount: items.length,
                          itemBuilder: (context, index) {
                            final n = items[index];
                            final showHeader = index == 0 ||
                                !_isSameDay(
                                  items[index - 1].createdAt,
                                  n.createdAt,
                                );

                            return Column(
                              crossAxisAlignment:
                                  CrossAxisAlignment.start,
                              children: [
                                if (showHeader)
                                  Padding(
                                    padding:
                                        const EdgeInsets.fromLTRB(
                                      16,
                                      16,
                                      16,
                                      4,
                                    ),
                                    child: Text(
                                      _formatDayLabel(n.createdAt),
                                      style: const TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                        color: Color(0xFF6B7280),
                                      ),
                                    ),
                                  ),
                                Dismissible(
                                  key: ValueKey(n.id),
                                  direction:
                                      DismissDirection.endToStart,
                                  background: _swipeBg(
                                    Colors.red,
                                    Icons.delete_outline,
                                    'Borrar',
                                  ),
                                  confirmDismiss: (dir) async {
                                    if (dir ==
                                        DismissDirection.endToStart) {
                                      await FirestoreService.instance
                                          .notificacionesRef(
                                              _empresaId)
                                          .doc(n.id)
                                          .delete();
                                      return true;
                                    }
                                    return false;
                                  },
                                  child: ListTile(
                                    tileColor: Colors.white,
                                    contentPadding:
                                        const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 8,
                                    ),
                                    leading: const Icon(
                                      Icons.notifications_active,
                                      color: Color(0xFF4F46E5),
                                    ),
                                    title: Text(
                                      n.title,
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleMedium
                                          ?.copyWith(
                                            fontWeight:
                                                FontWeight.w600,
                                          ),
                                    ),
                                    subtitle: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        const SizedBox(height: 4),
                                        Text(
                                          n.body,
                                          style: const TextStyle(
                                            fontSize: 13,
                                            color: Color(0xFF4B5563),
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          _formatTime(n.createdAt),
                                          style: const TextStyle(
                                            fontSize: 11,
                                            color: Color(0xFF9CA3AF),
                                          ),
                                        ),
                                      ],
                                    ),
                                    trailing: Text(
                                      n.tag,
                                      style: Theme.of(context)
                                          .textTheme
                                          .labelMedium
                                          ?.copyWith(
                                            color:
                                                const Color(0xFF4B5563),
                                          ),
                                    ),
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  // ========= Filtro por tipo =========
  List<_Notif> _filtrar(List<_Notif> all) {
    if (_filtro == 'Todas') return all;
    return all.where((n) => n.tag == _filtro).toList();
  }

  // ========= Crear nueva notificación =========
  Future<void> _abrirCrearNotificacion() async {
    final tituloCtrl = TextEditingController();
    final bodyCtrl = TextEditingController();
    String tag = 'Eventos';

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom + 16,
            left: 16,
            right: 16,
            top: 16,
          ),
          child: StatefulBuilder(
            builder: (context, setModalState) {
              return SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Text(
                          'Nueva notificación',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const Spacer(),
                        IconButton(
                          onPressed: () =>
                              Navigator.of(context).pop(),
                          icon: const Icon(Icons.close),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: tituloCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Título',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: bodyCtrl,
                      maxLines: 4,
                      decoration: const InputDecoration(
                        labelText: 'Mensaje',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: tag,
                      decoration: const InputDecoration(
                        labelText: 'Tipo',
                        border: OutlineInputBorder(),
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: 'Sistema',
                          child: Text('Sistema'),
                        ),
                        DropdownMenuItem(
                          value: 'Usuarios',
                          child: Text('Usuarios'),
                        ),
                        DropdownMenuItem(
                          value: 'Eventos',
                          child: Text('Eventos'),
                        ),
                      ],
                      onChanged: (value) {
                        if (value != null) {
                          setModalState(() => tag = value);
                        }
                      },
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () async {
                          final titulo =
                              tituloCtrl.text.trim();
                          final body =
                              bodyCtrl.text.trim();

                          if (titulo.isEmpty || body.isEmpty) {
                            ScaffoldMessenger.of(context)
                                .showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Título y mensaje son obligatorios',
                                ),
                              ),
                            );
                            return;
                          }

                          try {
                            await FirestoreService.instance
                                .notificacionesRef(_empresaId)
                                .add({
                              'titulo': titulo,
                              'body': body,
                              'tag': tag,
                              'creadoEn':
                                  FieldValue.serverTimestamp(),
                            });

                            if (context.mounted) {
                              Navigator.of(context).pop();
                              ScaffoldMessenger.of(context)
                                  .showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'Notificación enviada y registrada',
                                  ),
                                ),
                              );
                            }
                          } catch (e) {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context)
                                  .showSnackBar(
                                SnackBar(
                                  content: Text(
                                    'Error al enviar: $e',
                                  ),
                                ),
                              );
                            }
                          }
                        },
                        icon: const Icon(Icons.send_outlined),
                        label: const Text('Enviar'),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }

  // ========= helpers de fecha/hora =========

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year &&
        a.month == b.month &&
        a.day == b.day;
  }

  String _formatDayLabel(DateTime d) {
    final now = DateTime.now();
    final hoy = DateTime(now.year, now.month, now.day);
    final dia = DateTime(d.year, d.month, d.day);

    if (_isSameDay(hoy, dia)) return 'Hoy';
    if (_isSameDay(
        hoy.subtract(const Duration(days: 1)), dia)) {
      return 'Ayer';
    }
    final dd = d.day.toString().padLeft(2, '0');
    final mm = d.month.toString().padLeft(2, '0');
    return '$dd/$mm/${d.year}';
  }

  String _formatTime(DateTime d) {
    final hh = d.hour.toString().padLeft(2, '0');
    final mm = d.minute.toString().padLeft(2, '0');
    return '$hh:$mm';
  }

  Widget _swipeBg(Color c, IconData i, String text) {
    return Container(
      alignment: Alignment.centerRight,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      color: c.withOpacity(0.15),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Text(text),
          const SizedBox(width: 8),
          Icon(i),
        ],
      ),
    );
  }
}

// ================== MODELO LOCAL ==================

class _Notif {
  final String id;
  final String title;
  final String body;
  final String tag;
  final DateTime createdAt;

  _Notif({
    required this.id,
    required this.title,
    required this.body,
    required this.tag,
    required this.createdAt,
  });
}

/// Pequeño estado vacío reutilizable
class _EmptyState extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;

  const _EmptyState({
    required this.title,
    required this.subtitle,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 64, color: const Color(0xFF9CA3AF)),
            const SizedBox(height: 12),
            Text(
              title,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Color(0xFF6B7280)),
            ),
          ],
        ),
      ),
    );
  }
}
