import 'dart:async';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:printing/printing.dart';
import 'package:intl/intl.dart';

import '../../reports/admin_reports.dart';

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

  final FirebaseFirestore _db = FirebaseFirestore.instance;

  String? _empresaId;
  String? _selectedEventoId;
  String? _error;

  final TextEditingController _eventSearchCtrl = TextEditingController();
  String _eventSearch = '';

  // ============================
  // ✅ PDF state
  // ============================
  bool _generatingPdf = false;

  // ============================
  // ✅ NUEVO: filtros
  // ============================
  DateTimeRange? _eventsRange; // filtro informe eventos
  String? _selectedWorkerId; // docId/uid del trabajador
  String? _selectedWorkerName; // nombre del trabajador

  @override
  void initState() {
    super.initState();

    _eventSearchCtrl.addListener(() {
      if (!mounted) return;
      setState(() => _eventSearch = _eventSearchCtrl.text.trim().toLowerCase());
    });

    _resolveEmpresaIdRobusto();
  }

  @override
  void dispose() {
    _eventSearchCtrl.dispose();
    super.dispose();
  }

  // ============================
  // ✅ generar + compartir/descargar PDF
  // ============================
  Future<void> _downloadPdf({
    required String filename,
    required Future<Uint8List> Function() buildBytes,
  }) async {
    if (_generatingPdf) return;

    setState(() => _generatingPdf = true);
    try {
      final bytes = await buildBytes();

      if (kIsWeb) {
        // ✅ WEB: abre diálogo del navegador (Imprimir / Guardar como PDF)
        await Printing.layoutPdf(onLayout: (_) async => bytes);
      } else {
        // ✅ ANDROID / iOS: compartir/guardar
        await Printing.sharePdf(bytes: bytes, filename: filename);
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error generando PDF: $e')),
      );
    } finally {
      if (mounted) setState(() => _generatingPdf = false);
    }
  }

  // ============================
  // ✅ helpers de rango fechas (Eventos)
  // ============================
  DateTimeRange _thisWeekRange() {
    final now = DateTime.now();
    final monday = now.subtract(Duration(days: now.weekday - 1));
    final start = DateTime(monday.year, monday.month, monday.day);
    final end = start.add(const Duration(days: 6));
    return DateTimeRange(start: start, end: end);
  }

  DateTimeRange _thisMonthRange() {
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, 1);
    final end = DateTime(now.year, now.month + 1, 0);
    return DateTimeRange(start: start, end: end);
  }

  DateTimeRange _last30DaysRange() {
    final now = DateTime.now();
    final end = DateTime(now.year, now.month, now.day);
    final start = end.subtract(const Duration(days: 30));
    return DateTimeRange(start: start, end: end);
  }

  String _rangeLabel() {
    if (_eventsRange == null) return 'Todos';
    final f = DateFormat('dd/MM/yyyy');
    return '${f.format(_eventsRange!.start)} - ${f.format(_eventsRange!.end)}';
  }

  Future<void> _pickCustomRange() async {
    final now = DateTime.now();
    final initial = _eventsRange ?? DateTimeRange(start: now, end: now);
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(now.year + 2),
      initialDateRange: initial,
    );
    if (picked == null) return;
    if (!mounted) return;
    setState(() => _eventsRange = picked);
  }

  // ============================
  // ✅ RESOLVER EMPRESA ID (ROBUSTO)
  // ============================
  Future<void> _resolveEmpresaIdRobusto() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      final email = user?.email?.trim().toLowerCase();

      final empresaId = await _resolveEmpresaIdViaCollectionGroup(email!)
          .timeout(const Duration(seconds: 8));

      if (!mounted) return;
      setState(() => _empresaId = empresaId);
    } on TimeoutException {
      if (!mounted) return;
      setState(() => _error = 'Tiempo de espera agotado detectando empresa. Reintenta.');
    } on FirebaseException catch (e) {
      if (e.code == 'failed-precondition') {
        try {
          final user = FirebaseAuth.instance.currentUser;
          final email = user?.email?.trim().toLowerCase();
          if (email == null || email.isEmpty) rethrow;

          final empresaId = await _resolveEmpresaIdEscaneandoEmpresas(email)
              .timeout(const Duration(seconds: 12));

          if (!mounted) return;
          setState(() => _empresaId = empresaId);
          return;
        } catch (e2) {
          if (!mounted) return;
          setState(() => _error = 'Error detectando empresa (fallback): $e2');
          return;
        }
      }

      if (!mounted) return;
      setState(() => _error = 'Error detectando empresa del admin: ${e.message ?? e.code}');
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = 'Error detectando empresa del admin: $e');
    }
  }

  Future<String> _resolveEmpresaIdViaCollectionGroup(String email) async {
    final snap = await _db
        .collectionGroup('Administradores')
        .where('Email', isEqualTo: email)
        .limit(1)
        .get();

    if (snap.docs.isEmpty) {
      throw Exception('Tu email no está en Administradores de ninguna empresa.');
    }

    final adminDoc = snap.docs.first;
    final empresaDoc = adminDoc.reference.parent.parent;
    final empresaId = empresaDoc?.id;

    if (empresaId == null || empresaId.isEmpty) {
      throw Exception('No se pudo detectar la empresa del administrador.');
    }

    return empresaId;
  }

  Future<String> _resolveEmpresaIdEscaneandoEmpresas(String email) async {
    final empresasSnap = await _db.collection('empresas').get();

    for (final emp in empresasSnap.docs) {
      final adminsSnap = await _db
          .collection('empresas')
          .doc(emp.id)
          .collection('Administradores')
          .where('Email', isEqualTo: email)
          .limit(1)
          .get();

      if (adminsSnap.docs.isNotEmpty) {
        return emp.id;
      }
    }

    throw Exception('Tu email no está en Administradores de ninguna empresa.');
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
      return Scaffold(
        backgroundColor: _bg,
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              _error!,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: _textDark,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
      );
    }

    final empresaId = _empresaId;
    if (empresaId == null) {
      return const Scaffold(
        backgroundColor: _bg,
        body: Center(child: CircularProgressIndicator()),
      );
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
                  if (!snap.hasData) return const LinearProgressIndicator();

                  final docs = snap.data!.docs;
                  if (docs.isEmpty) return const Text('No hay eventos.');

                  final filtered = _eventSearch.isEmpty
                      ? docs
                      : docs.where((d) {
                          final nombre = (d.data()['nombre'] ?? '')
                              .toString()
                              .toLowerCase();
                          return nombre.contains(_eventSearch);
                        }).toList();

                  String? safeSelected = _selectedEventoId;
                  final exists =
                      safeSelected != null && filtered.any((d) => d.id == safeSelected);

                  if (!exists) {
                    safeSelected = filtered.isNotEmpty ? filtered.first.id : null;
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (!mounted) return;
                      if (_selectedEventoId != safeSelected) {
                        setState(() => _selectedEventoId = safeSelected);
                      }
                    });
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

                      DropdownButtonFormField<String>(
                        value: safeSelected,
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
                          style: TextStyle(
                            color: _textGrey,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ],
                  );
                },
              ),
            ),

            const SizedBox(height: 14),

            // ============================
            // ✅ CARD INFORMES con filtros
            // ============================
            if (_selectedEventoId != null) ...[
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
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Informes',
                      style: TextStyle(
                        color: _textDark,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 10),

                    // ✅ Filtro de fechas para informe de eventos
                    Row(
                      children: [
                        const Text(
                          'Eventos:',
                          style: TextStyle(
                            color: _textGrey,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF9FAFB),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: _border),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.date_range, size: 18, color: _textGrey),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    _rangeLabel(),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w800,
                                      color: _textDark,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        PopupMenuButton<String>(
                          tooltip: 'Filtrar',
                          onSelected: (v) async {
                            if (v == 'todos') setState(() => _eventsRange = null);
                            if (v == 'semana') setState(() => _eventsRange = _thisWeekRange());
                            if (v == 'mes') setState(() => _eventsRange = _thisMonthRange());
                            if (v == '30') setState(() => _eventsRange = _last30DaysRange());
                            if (v == 'custom') await _pickCustomRange();
                          },
                          itemBuilder: (context) => const [
                            PopupMenuItem(value: 'todos', child: Text('Todos')),
                            PopupMenuItem(value: 'semana', child: Text('Esta semana')),
                            PopupMenuItem(value: 'mes', child: Text('Este mes')),
                            PopupMenuItem(value: '30', child: Text('Últimos 30 días')),
                            PopupMenuItem(value: 'custom', child: Text('Rango personalizado')),
                          ],
                          child: Container(
                            height: 44,
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: _border),
                            ),
                            child: const Row(
                              children: [
                                Icon(Icons.tune, size: 18, color: _blue),
                                SizedBox(width: 8),
                                Text('Filtro', style: TextStyle(fontWeight: FontWeight.w800)),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 12),

                    // ✅ Selector de trabajador para actividad global
                    StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                      stream: _db
                          .collection('empresas')
                          .doc(empresaId)
                          .collection('trabajadores')
                          .orderBy('nombre', descending: false)
                          .snapshots(),
                      builder: (context, snapW) {
                        if (!snapW.hasData) {
                          return const LinearProgressIndicator();
                        }

                        final wdocs = snapW.data!.docs;
                        if (wdocs.isEmpty) {
                          return const Text(
                            'No hay trabajadores.',
                            style: TextStyle(
                              color: _textGrey,
                              fontWeight: FontWeight.w700,
                            ),
                          );
                        }

                        // Mantener selección válida
                        final exists = _selectedWorkerId != null &&
                            wdocs.any((d) => d.id == _selectedWorkerId);

                        if (!exists) {
                          final first = wdocs.first;
                          final data = first.data();
                          final name = (data['nombre'] ??
                                  data['fullName'] ??
                                  data['email'] ??
                                  'Trabajador')
                              .toString();

                          WidgetsBinding.instance.addPostFrameCallback((_) {
                            if (!mounted) return;
                            setState(() {
                              _selectedWorkerId = first.id;
                              _selectedWorkerName = name;
                            });
                          });
                        }

                        return DropdownButtonFormField<String>(
                          value: _selectedWorkerId,
                          decoration: InputDecoration(
                            isDense: true,
                            labelText: 'Trabajador (para actividad)',
                            labelStyle: const TextStyle(color: _textGrey),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          items: wdocs.map((d) {
                            final data = d.data();
                            final name = (data['nombre'] ??
                                    data['fullName'] ??
                                    data['email'] ??
                                    'Trabajador')
                                .toString();
                            return DropdownMenuItem(
                              value: d.id,
                              child: Text(
                                name,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontWeight: FontWeight.w700),
                              ),
                            );
                          }).toList(),
                          onChanged: (v) {
                            if (v == null) return;
                            final doc = wdocs.firstWhere((e) => e.id == v);
                            final data = doc.data();
                            final name = (data['nombre'] ??
                                    data['fullName'] ??
                                    data['email'] ??
                                    'Trabajador')
                                .toString();
                            setState(() {
                              _selectedWorkerId = v;
                              _selectedWorkerName = name;
                            });
                          },
                        );
                      },
                    ),

                    const SizedBox(height: 12),

                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        _ReportButton(
                          loading: _generatingPdf,
                          icon: Icons.assignment_turned_in_outlined,
                          label: 'Disponibilidad',
                          onTap: () async {
                            final eventoId = _selectedEventoId!;
                            final file = 'informe_disponibilidad_$eventoId.pdf';

                            await _downloadPdf(
                              filename: file,
                              buildBytes: () => AdminReports.buildDisponibilidadYAsignaciones(
                                db: _db,
                                empresaId: empresaId,
                                eventoId: eventoId,
                              ),
                            );
                          },
                        ),
                        _ReportButton(
                          loading: _generatingPdf,
                          icon: Icons.event_note_outlined,
                          label: 'Eventos',
                          onTap: () async {
                            final file = 'informe_eventos_$empresaId.pdf';

                            await _downloadPdf(
                              filename: file,
                              buildBytes: () => AdminReports.buildInformeEventos(
                                db: _db,
                                empresaId: empresaId,
                                range: _eventsRange,
                              ),
                            );
                          },
                        ),
                        _ReportButton(
                          loading: _generatingPdf,
                          icon: Icons.person_outline,
                          label: 'Actividad',
                          onTap: () async {
                            final workerId = _selectedWorkerId;
                            final workerName = _selectedWorkerName;

                            if (workerId == null || workerName == null || workerName.isEmpty) {
                              if (!mounted) return;
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Selecciona un trabajador.')),
                              );
                              return;
                            }

                            final safeName = workerName.replaceAll(
                              RegExp(r'[^a-zA-Z0-9_-]+'),
                              '_',
                            );
                            final file = 'actividad_${safeName}.pdf';

                            await _downloadPdf(
                              filename: file,
                              buildBytes: () => AdminReports.buildActividadTrabajadorGlobal(
                                db: _db,
                                empresaId: empresaId,
                                trabajadorId: workerId,
                                trabajadorNombre: workerName,
                              ),
                            );
                          },
                        ),
                      ],
                    ),

                    if (_generatingPdf) ...[
                      const SizedBox(height: 12),
                      const LinearProgressIndicator(),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 14),
            ],

            // ====== GRID ASISTENTES ======
            Expanded(
              child: (_selectedEventoId == null)
                  ? const Center(
                      child: Text(
                        'Selecciona un evento.',
                        style: TextStyle(
                          color: _textGrey,
                          fontWeight: FontWeight.w600,
                        ),
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
                              'No hay trabajadores seleccionados con asistencia para este evento',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: _textGrey,
                                fontWeight: FontWeight.w600,
                              ),
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
    final second =
        parts.length > 1 && parts[1].isNotEmpty ? parts[1][0].toUpperCase() : '';
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

// ============================
// ✅ BOTÓN REUTILIZABLE DE INFORME
// ============================
class _ReportButton extends StatelessWidget {
  final bool loading;
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _ReportButton({
    required this.loading,
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    const border = Color(0xFFE5E7EB);
    const blue = Color(0xFF2563EB);
    const textDark = Color(0xFF111827);

    return SizedBox(
      height: 44,
      child: OutlinedButton.icon(
        onPressed: loading ? null : onTap,
        icon: Icon(icon, size: 18, color: loading ? Colors.grey : blue),
        label: Text(
          label,
          style: TextStyle(
            fontWeight: FontWeight.w800,
            color: loading ? Colors.grey : textDark,
          ),
        ),
        style: OutlinedButton.styleFrom(
          side: const BorderSide(color: border),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          backgroundColor: Colors.white,
        ),
      ),
    );
  }
}
