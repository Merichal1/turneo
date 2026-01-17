import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

/// Pantalla de "Gestión": lista trabajadores que han asistido a un evento
/// y permite marcar si están pagados o no.
///
/// ✅ Multiempresa: todo cuelga de /empresas/{empresaId}/...
/// ✅ Fuente de verdad: subcolección /eventos/{eventoId}/disponibilidad
///    - asistio: bool
///    - pagado: bool
///    - trabajadorNombre: string
///    - trabajadorRol: string
///
/// Si en tu BD la asistencia/pagos están en otra colección, lo adaptamos.
class AdminGestionScreen extends StatefulWidget {
  const AdminGestionScreen({super.key});

  @override
  State<AdminGestionScreen> createState() => _AdminGestionScreenState();
}

class _AdminGestionScreenState extends State<AdminGestionScreen> {
  final _db = FirebaseFirestore.instance;

  String? _empresaId;
  String? _selectedEventoId;

  @override
  void initState() {
    super.initState();
    _loadEmpresaId();
  }

  Future<void> _loadEmpresaId() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final userDoc = await _db.collection('users').doc(user.uid).get();
    final empresaId = userDoc.data()?['empresaId'] as String?;

    if (!mounted) return;
    setState(() => _empresaId = empresaId);
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> _eventosStream(String empresaId) {
    return _db
        .collection('empresas')
        .doc(empresaId)
        .collection('eventos')
        .orderBy('fechaInicio', descending: true)
        .snapshots();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> _asistentesStream({
    required String empresaId,
    required String eventoId,
  }) {
    // Dentro del evento => respeta separación por empresa sin collectionGroup
    return _db
        .collection('empresas')
        .doc(empresaId)
        .collection('eventos')
        .doc(eventoId)
        .collection('disponibilidad')
        .where('asistio', isEqualTo: true)
        .snapshots();
  }

  Future<void> _setPagado({
    required String empresaId,
    required String eventoId,
    required String disponibilidadId,
    required bool pagado,
  }) async {
    await _db
        .collection('empresas')
        .doc(empresaId)
        .collection('eventos')
        .doc(eventoId)
        .collection('disponibilidad')
        .doc(disponibilidadId)
        .set(
      {
        'pagado': pagado,
        'pagadoEn': pagado ? FieldValue.serverTimestamp() : null,
      },
      SetOptions(merge: true),
    );
  }

  @override
  Widget build(BuildContext context) {
    final empresaId = _empresaId;

    if (empresaId == null) {
      return const Center(child: CircularProgressIndicator());
    }

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.tune),
              const SizedBox(width: 8),
              Text(
                'Gestión de pagos',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Selector de evento
          StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: _eventosStream(empresaId),
            builder: (context, snap) {
              if (snap.hasError) {
                return _errorBox('Error cargando eventos: ${snap.error}');
              }
              if (!snap.hasData) {
                return const LinearProgressIndicator();
              }

              final docs = snap.data!.docs;
              if (docs.isEmpty) {
                return _infoBox('No hay eventos todavía.');
              }

              // Autoselección del primer evento
              _selectedEventoId ??= docs.first.id;

              return DropdownButtonFormField<String>(
                value: _selectedEventoId,
                decoration: const InputDecoration(
                  labelText: 'Evento',
                  border: OutlineInputBorder(),
                ),
                items: docs.map((d) {
                  final data = d.data();
                  final titulo =
                      (data['titulo'] ?? data['nombre'] ?? 'Evento') as String;
                  final fechaTxt = _formatMaybeTimestamp(data['fechaInicio']);
                  return DropdownMenuItem(
                    value: d.id,
                    child: Text(
                      '$titulo${fechaTxt.isEmpty ? '' : ' • $fechaTxt'}',
                      overflow: TextOverflow.ellipsis,
                    ),
                  );
                }).toList(),
                onChanged: (v) => setState(() => _selectedEventoId = v),
              );
            },
          ),

          const SizedBox(height: 16),

          Expanded(
            child: _selectedEventoId == null
                ? _infoBox('Selecciona un evento para ver asistentes.')
                : StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                    stream: _asistentesStream(
                      empresaId: empresaId,
                      eventoId: _selectedEventoId!,
                    ),
                    builder: (context, snap) {
                      if (snap.hasError) {
                        return _errorBox('Error cargando asistentes: ${snap.error}');
                      }
                      if (!snap.hasData) {
                        return const Center(child: CircularProgressIndicator());
                      }

                      final docs = snap.data!.docs;
                      if (docs.isEmpty) {
                        return _infoBox(
                          'Todavía no hay trabajadores con "asistio = true" en este evento.',
                        );
                      }

                      return ListView.separated(
                        itemCount: docs.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (context, i) {
                          final d = docs[i];
                          final data = d.data();

                          final nombre =
                              (data['trabajadorNombre'] ?? 'Trabajador') as String;
                          final rol = (data['trabajadorRol'] ?? '') as String;
                          final pagado = (data['pagado'] == true);

                          return Card(
                            child: ListTile(
                              leading: CircleAvatar(
                                child: Text(
                                  nombre.isNotEmpty
                                      ? nombre.trim()[0].toUpperCase()
                                      : 'T',
                                ),
                              ),
                              title: Text(nombre),
                              subtitle: rol.isEmpty ? null : Text(rol),
                              trailing: SizedBox(
                                width: 160,
                                child: DropdownButtonFormField<bool>(
                                  value: pagado,
                                  decoration: const InputDecoration(
                                    isDense: true,
                                    border: OutlineInputBorder(),
                                  ),
                                  items: const [
                                    DropdownMenuItem(
                                      value: false,
                                      child: Text('No pagado'),
                                    ),
                                    DropdownMenuItem(
                                      value: true,
                                      child: Text('Pagado'),
                                    ),
                                  ],
                                  onChanged: (v) async {
                                    if (v == null) return;
                                    try {
                                      await _setPagado(
                                        empresaId: empresaId,
                                        eventoId: _selectedEventoId!,
                                        disponibilidadId: d.id,
                                        pagado: v,
                                      );
                                    } catch (e) {
                                      if (!mounted) return;
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          content: Text('No se pudo actualizar: $e'),
                                        ),
                                      );
                                    }
                                  },
                                ),
                              ),
                            ),
                          );
                        },
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  static String _formatMaybeTimestamp(dynamic value) {
    if (value is Timestamp) {
      final d = value.toDate();
      final dd = d.day.toString().padLeft(2, '0');
      final mm = d.month.toString().padLeft(2, '0');
      return '$dd/$mm/${d.year}';
    }
    return '';
  }

  Widget _infoBox(String text) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.04),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(text),
    );
  }

  Widget _errorBox(String text) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.red.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(text),
    );
  }
}
