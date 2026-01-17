import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class AdminPaymentsHistoryScreen extends StatefulWidget {
  const AdminPaymentsHistoryScreen({super.key});

  @override
  State<AdminPaymentsHistoryScreen> createState() =>
      _AdminPaymentsHistoryScreenState();
}

class _AdminPaymentsHistoryScreenState extends State<AdminPaymentsHistoryScreen> {
  // ====== THEME (Turneo / Login) ======
  static const Color _bg = Color(0xFFF6F8FC);
  static const Color _card = Colors.white;
  static const Color _border = Color(0xFFE5E7EB);
  static const Color _textDark = Color(0xFF111827);
  static const Color _textGrey = Color(0xFF6B7280);
  static const Color _blue = Color(0xFF2563EB);

  final _db = FirebaseFirestore.instance;

  String? _empresaId;
  String? _selectedEventoId;
  String? _error;

  final TextEditingController _eventSearchCtrl = TextEditingController();
  String _eventSearch = '';

  @override
  void initState() {
    super.initState();
    _loadEmpresaIdForAdmin();
    _eventSearchCtrl.addListener(() {
      setState(() => _eventSearch = _eventSearchCtrl.text.trim().toLowerCase());
    });
  }

  @override
  void dispose() {
    _eventSearchCtrl.dispose();
    super.dispose();
  }

  /// ✅ Basado en TU BD:
  /// Busca en empresas/*/Administradores where Email == email_logueado
  /// Si encuentra, esa empresa es la del admin.
  Future<void> _loadEmpresaIdForAdmin() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      final email = user?.email?.trim().toLowerCase();

      if (user == null || email == null || email.isEmpty) {
        setState(() => _error = 'No hay usuario logueado (o no tiene email).');
        return;
      }

      final empresas = await _db.collection('empresas').get();

      for (final emp in empresas.docs) {
        final adminsSnap = await _db
            .collection('empresas')
            .doc(emp.id)
            .collection('Administradores')
            .where('Email', isEqualTo: email)
            .limit(1)
            .get();

        if (adminsSnap.docs.isNotEmpty) {
          setState(() => _empresaId = emp.id);
          return;
        }
      }

      setState(() => _error = 'Tu email no está en Administradores de ninguna empresa.');
    } catch (e) {
      setState(() => _error = 'Error detectando empresa del admin: $e');
    }
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> _eventosStream(String empresaId) {
    return _db
        .collection('empresas')
        .doc(empresaId)
        .collection('eventos')
        .orderBy('fechaInicio', descending: false)
        .snapshots();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> _asistidosStream({
    required String empresaId,
    required String eventoId,
  }) {
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
        'pagadoEn': pagado ? FieldValue.serverTimestamp() : FieldValue.delete(),
      },
      SetOptions(merge: true),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text(_error!, textAlign: TextAlign.center),
        ),
      );
    }

    final empresaId = _empresaId;
    if (empresaId == null) {
      return const Center(child: CircularProgressIndicator());
    }

    return Scaffold(
      backgroundColor: _bg,
      body: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Gestión',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w900,
                color: _textDark,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Marca pagos de asistentes por evento',
              style: TextStyle(
                color: _textGrey,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 14),

            // ====== EVENT SELECTOR CARD ======
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: _card,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: _border),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x14000000),
                    blurRadius: 24,
                    offset: Offset(0, 10),
                  ),
                ],
              ),
              child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: _eventosStream(empresaId),
                builder: (context, snap) {
                  if (snap.hasError) {
                    return Text('Error cargando eventos: ${snap.error}');
                  }
                  if (!snap.hasData) {
                    return const LinearProgressIndicator();
                  }

                  final docs = snap.data!.docs;
                  if (docs.isEmpty) return const Text('No hay eventos.');

                  // Filtrado por nombre (buscador)
                  final filtered = _eventSearch.isEmpty
                      ? docs
                      : docs.where((d) {
                          final nombre =
                              (d.data()['nombre'] ?? '').toString().toLowerCase();
                          return nombre.contains(_eventSearch);
                        }).toList();

                  // Si no hay seleccionado, el primero del conjunto filtrado
                  if ((_selectedEventoId == null ||
                          !docs.any((d) => d.id == _selectedEventoId)) &&
                      docs.isNotEmpty) {
                    _selectedEventoId = docs.first.id;
                  }
                  if (_eventSearch.isNotEmpty &&
                      filtered.isNotEmpty &&
                      !filtered.any((d) => d.id == _selectedEventoId)) {
                    _selectedEventoId = filtered.first.id;
                  }

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Evento',
                        style: TextStyle(
                          color: _textDark,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 10),

                      // Buscador evento
                      TextField(
                        controller: _eventSearchCtrl,
                        decoration: InputDecoration(
                          isDense: true,
                          hintText: 'Buscar evento por nombre...',
                          prefixIcon: const Icon(Icons.search, size: 18),
                          filled: true,
                          fillColor: const Color(0xFFF9FAFB),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: _border),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: _border),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: _blue, width: 2),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 12,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Dropdown filtrado
                      DropdownButtonFormField<String>(
                        value: _selectedEventoId,
                        decoration: InputDecoration(
                          isDense: true,
                          labelText: 'Selecciona un evento',
                          labelStyle: const TextStyle(color: _textGrey),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        items: filtered.map((d) {
                          final data = d.data();
                          final nombre = (data['nombre'] ?? 'Evento') as String;
                          return DropdownMenuItem(
                            value: d.id,
                            child: Text(
                              nombre,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontWeight: FontWeight.w700),
                            ),
                          );
                        }).toList(),
                        onChanged: (v) => setState(() => _selectedEventoId = v),
                      ),

                      if (_eventSearch.isNotEmpty && filtered.isEmpty) ...[
                        const SizedBox(height: 10),
                        const Text(
                          'No hay eventos que coincidan con la búsqueda.',
                          style: TextStyle(color: _textGrey, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ],
                  );
                },
              ),
            ),

            const SizedBox(height: 14),

            // ====== GRID ASISTENTES ======
            Expanded(
              child: _selectedEventoId == null
                  ? const Center(
                      child: Text(
                        'Selecciona un evento.',
                        style: TextStyle(color: _textGrey, fontWeight: FontWeight.w600),
                      ),
                    )
                  : StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                      stream: _asistidosStream(
                        empresaId: empresaId,
                        eventoId: _selectedEventoId!,
                      ),
                      builder: (context, snap) {
                        if (snap.hasError) {
                          return Center(
                            child: Text('Error cargando asistentes: ${snap.error}'),
                          );
                        }
                        if (!snap.hasData) {
                          return const Center(child: CircularProgressIndicator());
                        }

                        final docs = snap.data!.docs;
                        if (docs.isEmpty) {
                          return const Center(
                            child: Text(
                              'No hay trabajadores con "asistio = true" en este evento.',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: _textGrey, fontWeight: FontWeight.w600),
                            ),
                          );
                        }

                        return LayoutBuilder(
                          builder: (context, c) {
                            final w = c.maxWidth;

                            int cols = 1;
                            if (w >= 1100) cols = 4;
                            else if (w >= 850) cols = 3;
                            else if (w >= 600) cols = 2;

                            return GridView.builder(
                              padding: const EdgeInsets.only(top: 2),
                              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: cols,
                                crossAxisSpacing: 12,
                                mainAxisSpacing: 12,
                                childAspectRatio: cols == 1 ? 3.1 : 2.6,
                              ),
                              itemCount: docs.length,
                              itemBuilder: (context, i) {
                                final doc = docs[i];
                                final data = doc.data();

                                final nombre =
                                    (data['trabajadorNombre'] ?? 'Trabajador') as String;
                                final rol = (data['trabajadorRol'] ?? '') as String;
                                final pagado = data['pagado'] == true;

                                return _PaymentWorkerCard(
                                  nombre: nombre,
                                  rol: rol,
                                  pagado: pagado,
                                  onChanged: (v) async {
                                    await _setPagado(
                                      empresaId: empresaId,
                                      eventoId: _selectedEventoId!,
                                      disponibilidadId: doc.id,
                                      pagado: v,
                                    );
                                  },
                                );
                              },
                            );
                          },
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PaymentWorkerCard extends StatelessWidget {
  static const Color _card = Colors.white;
  static const Color _border = Color(0xFFE5E7EB);
  static const Color _textDark = Color(0xFF111827);
  static const Color _textGrey = Color(0xFF6B7280);
  static const Color _blue = Color(0xFF2563EB);

  final String nombre;
  final String rol;
  final bool pagado;
  final ValueChanged<bool> onChanged;

  const _PaymentWorkerCard({
    required this.nombre,
    required this.rol,
    required this.pagado,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final initials = _initials(nombre);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _border),
        boxShadow: const [
          BoxShadow(
            color: Color(0x12000000),
            blurRadius: 16,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 22,
            backgroundColor: const Color(0xFFEFF6FF),
            child: Text(
              initials,
              style: const TextStyle(
                fontWeight: FontWeight.w900,
                color: _textDark,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  nombre,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    color: _textDark,
                  ),
                ),
                const SizedBox(height: 4),
                if (rol.isNotEmpty)
                  Text(
                    rol,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: _textGrey,
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                    ),
                  ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    _PaidChip(pagado: pagado),
                    const Spacer(),
                    SizedBox(
                      width: 140,
                      child: DropdownButtonFormField<bool>(
                        value: pagado,
                        decoration: InputDecoration(
                          isDense: true,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 10,
                          ),
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
                        onChanged: (v) {
                          if (v == null) return;
                          onChanged(v);
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static String _initials(String nombreCompleto) {
    final parts = nombreCompleto.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty) return '?';
    final first = parts.first.isNotEmpty ? parts.first[0].toUpperCase() : '';
    final second = parts.length > 1 && parts[1].isNotEmpty ? parts[1][0].toUpperCase() : '';
    final res = (first + second).trim();
    return res.isEmpty ? '?' : res;
  }
}

class _PaidChip extends StatelessWidget {
  final bool pagado;

  const _PaidChip({required this.pagado});

  @override
  Widget build(BuildContext context) {
    final bg = pagado ? const Color(0xFFDCFCE7) : const Color(0xFFFEE2E2);
    final fg = pagado ? const Color(0xFF15803D) : const Color(0xFFB91C1C);
    final text = pagado ? 'Pagado' : 'No pagado';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          color: fg,
        ),
      ),
    );
  }
}
