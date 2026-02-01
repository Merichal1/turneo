import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart' show DateTimeRange;
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

class AdminReports {
  // ====== FORMATOS ======
  static final _fmtDate = DateFormat('dd/MM/yyyy', 'es_ES');
  static final _fmtDateTime = DateFormat('dd/MM/yyyy HH:mm', 'es_ES');

  // =====================================================
  // PALETA FORMAL (MONOCROMO + ACENTO MUY DISCRETO)
  // =====================================================
  // Acento corporativo (muy contenido)
  static const PdfColor _accent = PdfColor.fromInt(0xFF1F2A37); // gris-azulado (sobrio)
  static const PdfColor _accentSoft = PdfColor.fromInt(0xFFF3F4F6); // gris muy suave

  // Texto
  static const PdfColor _text = PdfColor.fromInt(0xFF111827);
  static const PdfColor _muted = PdfColor.fromInt(0xFF6B7280);

  // Superficies / Bordes
  static const PdfColor _border = PdfColor.fromInt(0xFFE5E7EB);
  static const PdfColor _bg = PdfColor.fromInt(0xFFFFFFFF);
  static const PdfColor _bgSoft = PdfColor.fromInt(0xFFF9FAFB);

  // Estados (sin colores chillones)
  static const PdfColor _stateOk = PdfColor.fromInt(0xFF111827); // mismo tono sobrio
  static const PdfColor _stateWarn = PdfColor.fromInt(0xFF374151);
  static const PdfColor _stateBad = PdfColor.fromInt(0xFF4B5563);

  // =========================
  // INFORME 1: ASISTENCIAS + PAGOS (EVENTO)
  // =========================
  static Future<Uint8List> buildDisponibilidadYAsignaciones({
    required FirebaseFirestore db,
    required String empresaId,
    required String eventoId,
  }) async {
    final eventoDoc = await db
        .collection('empresas')
        .doc(empresaId)
        .collection('eventos')
        .doc(eventoId)
        .get();

    final evento = eventoDoc.data() ?? {};
    final nombreEvento = (evento['nombre'] ?? 'Evento').toString();

    final fechaInicio = _tsToDate(evento['fechaInicio']);
    final fechaFin = _tsToDate(evento['fechaFin']);

    final asistidosSnap = await db
        .collection('empresas')
        .doc(empresaId)
        .collection('eventos')
        .doc(eventoId)
        .collection('disponibilidad')
        .where('asistio', isEqualTo: true)
        .get();

    final rows = asistidosSnap.docs.map((d) {
      final data = d.data();
      final nombre = (data['trabajadorNombre'] ?? 'Trabajador').toString();
      final rol = (data['trabajadorRol'] ?? '').toString().trim();

      final pagadoBool = data['pagado'] == true;
      final pagadoTxt = pagadoBool ? 'Sí' : 'No';

      final pagadoEn = _tsToDateTime(data['pagadoEn']);
      final pagadoEnTxt = pagadoEn == null ? '' : _fmtDateTime.format(pagadoEn);

      return _RowAsistencia(
        nombre: nombre,
        rol: rol,
        pagado: pagadoBool,
        pagadoTxt: pagadoTxt,
        pagadoEnTxt: pagadoEnTxt,
      );
    }).toList()
      ..sort((a, b) => a.nombre.toLowerCase().compareTo(b.nombre.toLowerCase()));

    final total = rows.length;
    final paid = rows.where((r) => r.pagado).length;
    final pending = total - paid;
    final rate = total == 0 ? 0 : (paid / total);

    // Distribución por roles (top)
    final roleCounts = <String, int>{};
    for (final r in rows) {
      final key = r.rol.isEmpty ? 'Sin rol' : r.rol;
      roleCounts[key] = (roleCounts[key] ?? 0) + 1;
    }
    final topRoles = roleCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final topRoleBars = topRoles.take(8).map((e) => _BarItem(label: e.key, value: e.value)).toList();

    final doc = pw.Document(
      author: 'Turneo',
      title: 'Informe de pagos y asistencias',
      subject: nombreEvento,
    );

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.fromLTRB(28, 28, 28, 28),
        header: (ctx) => _headerFormal(
          title: 'Informe de pagos y asistencias',
          subtitle: nombreEvento,
        ),
        footer: (ctx) => _footerFormal(ctx),
        build: (context) => [
          _metaStrip(meta: [
            if (fechaInicio != null) _kv('Inicio', _fmtDate.format(fechaInicio)),
            if (fechaFin != null) _kv('Fin', _fmtDate.format(fechaFin)),
            _kv('Asistentes', '$total'),
            _kv('Pagados', '$paid'),
            _kv('Pendientes', '$pending'),
          ]),
          pw.SizedBox(height: 14),

          _sectionTitleFormal('Resumen ejecutivo'),
          pw.SizedBox(height: 10),
          _kpiRow([
            _kpiCardFormal('Asistentes', '$total'),
            _kpiCardFormal('Pagados', '$paid'),
            _kpiCardFormal('Pendientes', '$pending'),
            _kpiCardFormal('Tasa de pago', '${(rate * 100).round()}%'),
          ]),
          pw.SizedBox(height: 14),

          _sectionTitleFormal('Indicador: Pagados vs Pendientes'),
          pw.SizedBox(height: 8),
          _barCompareFormal(
            leftLabel: 'Pagados',
            leftValue: paid,
            rightLabel: 'Pendientes',
            rightValue: pending,
          ),
          pw.SizedBox(height: 14),

          _sectionTitleFormal('Distribución por roles (Top)'),
          pw.SizedBox(height: 8),
          topRoleBars.isEmpty
              ? _emptyBox('No hay roles suficientes para graficar.')
              : _barListFormal(items: topRoleBars),
          pw.SizedBox(height: 14),

          _sectionTitleFormal('Detalle de asistentes'),
          pw.SizedBox(height: 10),
          _tableAsistencias(rows),
          pw.SizedBox(height: 10),

          _note('Documento generado automáticamente desde Turneo.'),
        ],
      ),
    );

    return doc.save();
  }

  // =========================
  // INFORME 2: LISTADO DE EVENTOS (RANGO)
  // =========================
  static Future<Uint8List> buildInformeEventos({
    required FirebaseFirestore db,
    required String empresaId,
    DateTimeRange? range,
  }) async {
    Query<Map<String, dynamic>> q = db
        .collection('empresas')
        .doc(empresaId)
        .collection('eventos');

    String rangoTxt = 'Todos';
    if (range != null) {
      final start = DateTime(range.start.year, range.start.month, range.start.day);
      final end = DateTime(range.end.year, range.end.month, range.end.day, 23, 59, 59);

      rangoTxt = '${_fmtDate.format(range.start)} - ${_fmtDate.format(range.end)}';

      q = q
          .where('fechaInicio', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
          .where('fechaInicio', isLessThanOrEqualTo: Timestamp.fromDate(end));
    }

    final eventosSnap = await q.orderBy('fechaInicio', descending: false).get();

    final eventos = eventosSnap.docs.map((d) {
      final data = d.data();
      final nombre = (data['nombre'] ?? 'Evento').toString();

      final inicio = _tsToDate(data['fechaInicio']);
      final fin = _tsToDate(data['fechaFin']);

      final ubicacion = (data['ubicacion'] is Map) ? (data['ubicacion'] as Map) : const {};
      final ciudad = (ubicacion['Ciudad'] ??
              ubicacion['ciudad'] ??
              data['ciudad'] ??
              data['Ciudad'] ??
              '')
          .toString();

      return _EventoRow(nombre: nombre, inicio: inicio, fin: fin, ciudad: ciudad);
    }).toList();

    final total = eventos.length;

    // Eventos por mes (gráfica)
    final byMonth = <String, int>{};
    for (final e in eventos) {
      final d = e.inicio;
      if (d == null) continue;
      final key = '${d.year}-${d.month.toString().padLeft(2, '0')}';
      byMonth[key] = (byMonth[key] ?? 0) + 1;
    }
    final monthBars = byMonth.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));
    final barItems = monthBars.take(12).map((e) {
      final parts = e.key.split('-');
      final yy = parts.isNotEmpty ? parts[0] : '????';
      final mm = parts.length > 1 ? parts[1] : '??';
      return _BarItem(label: '$mm/$yy', value: e.value);
    }).toList();

    final doc = pw.Document(
      author: 'Turneo',
      title: 'Informe corporativo de eventos',
      subject: 'Empresa $empresaId',
    );

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.fromLTRB(28, 28, 28, 28),
        header: (ctx) => _headerFormal(
          title: 'Informe corporativo de eventos',
          subtitle: 'Empresa: $empresaId',
        ),
        footer: (ctx) => _footerFormal(ctx),
        build: (context) => [
          _metaStrip(meta: [
            _kv('Rango', rangoTxt),
            _kv('Total eventos', '$total'),
          ]),
          pw.SizedBox(height: 14),

          _sectionTitleFormal('Eventos por mes'),
          pw.SizedBox(height: 8),
          barItems.isEmpty
              ? _emptyBox('No hay datos suficientes para graficar.')
              : _barListFormal(items: barItems),
          pw.SizedBox(height: 14),

          _sectionTitleFormal('Listado de eventos'),
          pw.SizedBox(height: 10),
          _tableEventos(eventos),
          pw.SizedBox(height: 10),

          _note('Documento generado automáticamente desde Turneo.'),
        ],
      ),
    );

    return doc.save();
  }

  // =========================
  // INFORME 3: ACTIVIDAD TRABAJADOR (GLOBAL)
  // =========================
  static Future<Uint8List> buildActividadTrabajadorGlobal({
    required FirebaseFirestore db,
    required String empresaId,
    required String trabajadorDocId,
    required String trabajadorNombre,
    String? trabajadorUid,
    String? trabajadorEmail,
  }) async {
    final eventosSnap = await db
        .collection('empresas')
        .doc(empresaId)
        .collection('eventos')
        .orderBy('fechaInicio', descending: false)
        .get();

    final rows = <_ActividadRow>[];

    Future<Map<String, dynamic>?> _tryQuery(
      CollectionReference<Map<String, dynamic>> col,
      String field,
      String value,
    ) async {
      if (value.trim().isEmpty) return null;
      final snap = await col.where(field, isEqualTo: value.trim()).limit(1).get();
      if (snap.docs.isEmpty) return null;
      return snap.docs.first.data();
    }

    for (final ev in eventosSnap.docs) {
      final evData = ev.data();
      final eventoNombre = (evData['nombre'] ?? 'Evento').toString();
      final inicio = _tsToDate(evData['fechaInicio']);
      final fin = _tsToDate(evData['fechaFin']);

      final col = db
          .collection('empresas')
          .doc(empresaId)
          .collection('eventos')
          .doc(ev.id)
          .collection('disponibilidad');

      Map<String, dynamic>? d;

      d ??= await _tryQuery(col, 'trabajadorDocId', trabajadorDocId);
      d ??= await _tryQuery(col, 'trabajadorId', trabajadorDocId);

      final uid = (trabajadorUid ?? '').trim();
      if (uid.isNotEmpty) {
        d ??= await _tryQuery(col, 'trabajadorUid', uid);
        d ??= await _tryQuery(col, 'uid', uid);
        d ??= await _tryQuery(col, 'authUid', uid);
        d ??= await _tryQuery(col, 'userId', uid);
        d ??= await _tryQuery(col, 'trabajadorId', uid);
      }

      final email = (trabajadorEmail ?? '').trim();
      if (email.isNotEmpty) {
        d ??= await _tryQuery(col, 'trabajadorEmail', email);
        d ??= await _tryQuery(col, 'email', email);
      }

      if (d == null) continue;

      final rol = (d['trabajadorRol'] ?? '').toString();
      final asistio = d['asistio'] == true;
      final pagado = d['pagado'] == true;

      final pagadoEn = _tsToDateTime(d['pagadoEn']);
      final pagadoEnTxt = pagadoEn == null ? '' : _fmtDateTime.format(pagadoEn);

      rows.add(_ActividadRow(
        evento: eventoNombre,
        inicio: inicio,
        fin: fin,
        rol: rol,
        asistio: asistio,
        pagado: pagado,
        pagadoEnTxt: pagadoEnTxt,
      ));
    }

    final total = rows.length;
    final asistidos = rows.where((r) => r.asistio).length;
    final noAsistio = total - asistidos;
    final pendientes = rows.where((r) => r.asistio && !r.pagado).length;

    final doc = pw.Document(
      author: 'Turneo',
      title: 'Informe de actividad del trabajador',
      subject: trabajadorNombre,
    );

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.fromLTRB(28, 28, 28, 28),
        header: (ctx) => _headerFormal(
          title: 'Informe de actividad del trabajador',
          subtitle: trabajadorNombre,
        ),
        footer: (ctx) => _footerFormal(ctx),
        build: (context) => [
          _metaStrip(meta: [
            _kv('Empresa', empresaId),
            _kv('Eventos encontrados', '$total'),
            _kv('Asistió', '$asistidos'),
            _kv('No asistió', '$noAsistio'),
            _kv('Pendientes (asistió)', '$pendientes'),
          ]),
          pw.SizedBox(height: 14),

          _sectionTitleFormal('Resumen ejecutivo'),
          pw.SizedBox(height: 10),
          _kpiRow([
            _kpiCardFormal('Eventos', '$total'),
            _kpiCardFormal('Asistió', '$asistidos'),
            _kpiCardFormal('No asistió', '$noAsistio'),
            _kpiCardFormal('Pendientes', '$pendientes'),
          ]),
          pw.SizedBox(height: 14),

          _sectionTitleFormal('Indicador: Asistió vs No asistió'),
          pw.SizedBox(height: 8),
          _barCompareFormal(
            leftLabel: 'Asistió',
            leftValue: asistidos,
            rightLabel: 'No asistió',
            rightValue: noAsistio,
          ),
          pw.SizedBox(height: 14),

          _sectionTitleFormal('Detalle de actividad'),
          pw.SizedBox(height: 10),
          rows.isEmpty ? _emptyBox('No se han encontrado registros para este trabajador.') : _tableActividad(rows),
          pw.SizedBox(height: 10),

          _note('Documento generado automáticamente desde Turneo.'),
        ],
      ),
    );

    return doc.save();
  }

  // =====================================================
  // COMPONENTES FORMALES
  // =====================================================

  static pw.Widget _headerFormal({required String title, required String subtitle}) {
    return pw.Container(
      padding: const pw.EdgeInsets.only(bottom: 10),
      decoration: const pw.BoxDecoration(
        border: pw.Border(bottom: pw.BorderSide(color: _border, width: 1)),
      ),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          // “Marca” sobria (sin bloque azul)
          pw.Container(
            width: 38,
            height: 38,
            decoration: pw.BoxDecoration(
              color: _text,
              borderRadius: pw.BorderRadius.circular(10),
            ),
            child: pw.Center(
              child: pw.Text(
                'T',
                style: pw.TextStyle(
                  color: PdfColors.white,
                  fontWeight: pw.FontWeight.bold,
                  fontSize: 18,
                ),
              ),
            ),
          ),
          pw.SizedBox(width: 12),
          pw.Expanded(
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  title,
                  style: pw.TextStyle(
                    fontSize: 14,
                    color: _text,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.SizedBox(height: 2),
                pw.Text(subtitle, style: pw.TextStyle(fontSize: 10, color: _muted)),
              ],
            ),
          ),
          pw.Container(
            padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: pw.BoxDecoration(
              color: _bgSoft,
              borderRadius: pw.BorderRadius.circular(999),
              border: pw.Border.all(color: _border),
            ),
            child: pw.Text(
              _fmtDateTime.format(DateTime.now()),
              style: pw.TextStyle(fontSize: 9, color: _muted),
            ),
          ),
        ],
      ),
    );
  }

  static pw.Widget _footerFormal(pw.Context ctx) {
    return pw.Container(
      padding: const pw.EdgeInsets.only(top: 10),
      decoration: const pw.BoxDecoration(
        border: pw.Border(top: pw.BorderSide(color: _border, width: 1)),
      ),
      child: pw.Row(
        children: [
          pw.Text('Turneo • Documentación interna', style: pw.TextStyle(fontSize: 9, color: _muted)),
          pw.Spacer(),
          pw.Text('Página ${ctx.pageNumber} de ${ctx.pagesCount}', style: pw.TextStyle(fontSize: 9, color: _muted)),
        ],
      ),
    );
  }

  static pw.Widget _sectionTitleFormal(String text) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: pw.BoxDecoration(
        color: _bgSoft,
        borderRadius: pw.BorderRadius.circular(12),
        border: pw.Border.all(color: _border),
      ),
      child: pw.Row(
        children: [
          // acento mínimo (barra fina gris-azulada)
          pw.Container(
            width: 4,
            height: 16,
            decoration: pw.BoxDecoration(
              color: _accent,
              borderRadius: pw.BorderRadius.circular(999),
            ),
          ),
          pw.SizedBox(width: 10),
          pw.Text(
            text,
            style: pw.TextStyle(
              fontSize: 11,
              color: _text,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  static pw.Widget _metaStrip({required List<pw.Widget> meta}) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        color: _bg,
        borderRadius: pw.BorderRadius.circular(12),
        border: pw.Border.all(color: _border),
      ),
      child: pw.Wrap(spacing: 10, runSpacing: 8, children: meta),
    );
  }

  static pw.Widget _kv(String k, String v) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: pw.BoxDecoration(
        color: _bgSoft,
        borderRadius: pw.BorderRadius.circular(999),
        border: pw.Border.all(color: _border),
      ),
      child: pw.RichText(
        text: pw.TextSpan(
          children: [
            pw.TextSpan(text: '$k: ', style: pw.TextStyle(fontSize: 9, color: _muted, fontWeight: pw.FontWeight.bold)),
            pw.TextSpan(text: v, style: pw.TextStyle(fontSize: 9, color: _text)),
          ],
        ),
      ),
    );
  }

  static pw.Widget _kpiRow(List<pw.Widget> cards) {
    return pw.Wrap(
      spacing: 10,
      runSpacing: 10,
      children: cards.map((c) => pw.SizedBox(width: 130, child: c)).toList(),
    );
  }

  static pw.Widget _kpiCardFormal(String label, String value) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        color: _bg,
        borderRadius: pw.BorderRadius.circular(12),
        border: pw.Border.all(color: _border),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Row(
            children: [
              pw.Container(
                width: 10,
                height: 10,
                decoration: pw.BoxDecoration(color: _accent, shape: pw.BoxShape.circle),
              ),
              pw.Spacer(),
              pw.Container(
                width: 26,
                height: 18,
                decoration: pw.BoxDecoration(
                  color: _accentSoft,
                  borderRadius: pw.BorderRadius.circular(6),
                  border: pw.Border.all(color: _border),
                ),
              ),
            ],
          ),
          pw.SizedBox(height: 8),
          pw.Text(label, style: pw.TextStyle(fontSize: 9, color: _muted, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 3),
          pw.Text(value, style: pw.TextStyle(fontSize: 14, color: _text, fontWeight: pw.FontWeight.bold)),
        ],
      ),
    );
  }

  static pw.Widget _note(String text) => pw.Text(text, style: pw.TextStyle(fontSize: 9, color: _muted));

  static pw.Widget _emptyBox(String text) {
    return pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.all(14),
      decoration: pw.BoxDecoration(
        color: _bgSoft,
        borderRadius: pw.BorderRadius.circular(12),
        border: pw.Border.all(color: _border),
      ),
      child: pw.Text(text, style: pw.TextStyle(fontSize: 10, color: _muted)),
    );
  }

  // =====================================================
  // “GRÁFICAS” FORMALES (en gris)
  // =====================================================

  static pw.Widget _barCompareFormal({
    required String leftLabel,
    required int leftValue,
    required String rightLabel,
    required int rightValue,
  }) {
    final maxV = leftValue > rightValue ? leftValue : rightValue;
    final denom = maxV <= 0 ? 1 : maxV;

    return pw.Container(
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        color: _bg,
        borderRadius: pw.BorderRadius.circular(12),
        border: pw.Border.all(color: _border),
      ),
      child: pw.Column(
        children: [
          _barLineFormal(label: leftLabel, value: leftValue, max: denom),
          pw.SizedBox(height: 10),
          _barLineFormal(label: rightLabel, value: rightValue, max: denom),
        ],
      ),
    );
  }

  static pw.Widget _barLineFormal({
    required String label,
    required int value,
    required int max,
  }) {
    final v = value < 0 ? 0 : value;
    final m = max <= 0 ? 1 : max;
    final fillFlex = ((v / m) * 1000).round().clamp(0, 1000);
    final emptyFlex = 1000 - fillFlex;

    return pw.Row(
      children: [
        pw.SizedBox(
          width: 110,
          child: pw.Text(label, style: pw.TextStyle(fontSize: 10, color: _text, fontWeight: pw.FontWeight.bold)),
        ),
        pw.Expanded(
          child: pw.Container(
            height: 10,
            decoration: pw.BoxDecoration(
              color: _bgSoft,
              borderRadius: pw.BorderRadius.circular(999),
              border: pw.Border.all(color: _border),
            ),
            child: pw.Row(
              children: [
                pw.Expanded(
                  flex: fillFlex,
                  child: pw.Container(
                    height: 10,
                    decoration: pw.BoxDecoration(
                      color: _stateOk,
                      borderRadius: pw.BorderRadius.circular(999),
                    ),
                  ),
                ),
                pw.Expanded(flex: emptyFlex, child: pw.SizedBox()),
              ],
            ),
          ),
        ),
        pw.SizedBox(width: 10),
        pw.SizedBox(
          width: 40,
          child: pw.Text('$value', textAlign: pw.TextAlign.right, style: pw.TextStyle(fontSize: 10, color: _muted)),
        ),
      ],
    );
  }

  static pw.Widget _barListFormal({
    required List<_BarItem> items,
  }) {
    final maxV = items.map((e) => e.value).fold<int>(0, (p, c) => c > p ? c : p);
    final denom = maxV <= 0 ? 1 : maxV;

    return pw.Container(
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        color: _bg,
        borderRadius: pw.BorderRadius.circular(12),
        border: pw.Border.all(color: _border),
      ),
      child: pw.Column(
        children: items.map((e) {
          final v = e.value < 0 ? 0 : e.value;
          final fillFlex = ((v / denom) * 1000).round().clamp(0, 1000);
          final emptyFlex = 1000 - fillFlex;

          return pw.Padding(
            padding: const pw.EdgeInsets.symmetric(vertical: 6),
            child: pw.Row(
              children: [
                pw.SizedBox(
                  width: 140,
                  child: pw.Text(
                    e.label,
                    maxLines: 1,
                    overflow: pw.TextOverflow.clip,
                    style: pw.TextStyle(fontSize: 9, color: _text, fontWeight: pw.FontWeight.bold),
                  ),
                ),
                pw.Expanded(
                  child: pw.Container(
                    height: 8,
                    decoration: pw.BoxDecoration(
                      color: _bgSoft,
                      borderRadius: pw.BorderRadius.circular(999),
                      border: pw.Border.all(color: _border),
                    ),
                    child: pw.Row(
                      children: [
                        pw.Expanded(
                          flex: fillFlex,
                          child: pw.Container(
                            height: 8,
                            decoration: pw.BoxDecoration(
                              color: _stateWarn,
                              borderRadius: pw.BorderRadius.circular(999),
                            ),
                          ),
                        ),
                        pw.Expanded(flex: emptyFlex, child: pw.SizedBox()),
                      ],
                    ),
                  ),
                ),
                pw.SizedBox(width: 10),
                pw.Text('${e.value}', style: pw.TextStyle(fontSize: 9, color: _muted)),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  // =====================================================
  // TABLAS (FORMAL)
  // =====================================================

  static pw.Widget _tableAsistencias(List<_RowAsistencia> rows) {
    final data = rows.map((r) => [
          r.nombre,
          r.rol.isEmpty ? '—' : r.rol,
          r.pagadoTxt,
          r.pagadoEnTxt,
        ]).toList();

    return _table(
      headers: const ['Trabajador', 'Rol', 'Pagado', 'Pagado en'],
      data: data,
      colFlex: const [32, 20, 10, 20],
      fontSize: 10,
    );
  }

  static pw.Widget _tableEventos(List<_EventoRow> eventos) {
    final data = eventos.map((e) {
      final inicioTxt = e.inicio == null ? '' : _fmtDate.format(e.inicio!);
      final finTxt = e.fin == null ? '' : _fmtDate.format(e.fin!);
      return [
        e.nombre,
        inicioTxt,
        finTxt,
        e.ciudad.isEmpty ? '—' : e.ciudad,
      ];
    }).toList();

    return _table(
      headers: const ['Evento', 'Inicio', 'Fin', 'Ciudad'],
      data: data,
      colFlex: const [32, 14, 14, 20],
      fontSize: 10,
    );
  }

  static pw.Widget _tableActividad(List<_ActividadRow> rows) {
    final data = rows.map((r) {
      final iniTxt = r.inicio == null ? '' : _fmtDate.format(r.inicio!);
      final finTxt = r.fin == null ? '' : _fmtDate.format(r.fin!);
      return [
        r.evento,
        iniTxt,
        finTxt,
        r.rol.isEmpty ? '—' : r.rol,
        r.asistio ? 'Sí' : 'No',
        r.pagado ? 'Sí' : 'No',
        r.pagadoEnTxt,
      ];
    }).toList();

    return _table(
      headers: const ['Evento', 'Inicio', 'Fin', 'Rol', 'Asistió', 'Pagado', 'Pagado en'],
      data: data,
      colFlex: const [32, 12, 12, 16, 10, 10, 20],
      fontSize: 9,
    );
  }

  static pw.Widget _table({
    required List<String> headers,
    required List<List<String>> data,
    required List<int> colFlex,
    required double fontSize,
  }) {
    pw.Widget cell(
      String text, {
      PdfColor? bg,
      bool header = false,
      pw.Alignment align = pw.Alignment.centerLeft,
    }) {
      return pw.Container(
        alignment: align,
        padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: pw.BoxDecoration(color: bg ?? _bg),
        child: pw.Text(
          text,
          style: pw.TextStyle(
            fontSize: fontSize,
            color: header ? PdfColors.white : _text,
            fontWeight: header ? pw.FontWeight.bold : pw.FontWeight.normal,
          ),
        ),
      );
    }

    final headerRow = pw.TableRow(
      children: List.generate(headers.length, (i) {
        return cell(headers[i], bg: _text, header: true);
      }),
    );

    final rows = <pw.TableRow>[headerRow];

    for (int r = 0; r < data.length; r++) {
      final bg = (r % 2 == 0) ? _bg : _bgSoft;

      rows.add(
        pw.TableRow(
          children: List.generate(headers.length, (c) {
            final txt = (c < data[r].length) ? data[r][c] : '';
            return cell(txt, bg: bg);
          }),
        ),
      );
    }

    return pw.Container(
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: _border, width: 0.8),
        borderRadius: pw.BorderRadius.circular(10),
      ),
      child: pw.ClipRRect(
        horizontalRadius: 10,
        verticalRadius: 10,
        child: pw.Table(
          border: pw.TableBorder.symmetric(
            inside: pw.BorderSide(color: _border, width: 0.6),
          ),
          columnWidths: {
            for (int i = 0; i < colFlex.length; i++) i: pw.FlexColumnWidth(colFlex[i].toDouble()),
          },
          children: rows,
        ),
      ),
    );
  }

  // =========================
  // TIMESTAMP HELPERS
  // =========================
  static DateTime? _tsToDate(dynamic v) {
    if (v == null) return null;
    if (v is Timestamp) return v.toDate();
    if (v is DateTime) return v;
    return null;
  }

  static DateTime? _tsToDateTime(dynamic v) => _tsToDate(v);
}

// =========================
// MODELOS INTERNOS
// =========================
class _RowAsistencia {
  final String nombre;
  final String rol;
  final bool pagado;
  final String pagadoTxt;
  final String pagadoEnTxt;

  _RowAsistencia({
    required this.nombre,
    required this.rol,
    required this.pagado,
    required this.pagadoTxt,
    required this.pagadoEnTxt,
  });
}

class _EventoRow {
  final String nombre;
  final DateTime? inicio;
  final DateTime? fin;
  final String ciudad;

  _EventoRow({
    required this.nombre,
    required this.inicio,
    required this.fin,
    required this.ciudad,
  });
}

class _ActividadRow {
  final String evento;
  final DateTime? inicio;
  final DateTime? fin;
  final String rol;
  final bool asistio;
  final bool pagado;
  final String pagadoEnTxt;

  _ActividadRow({
    required this.evento,
    required this.inicio,
    required this.fin,
    required this.rol,
    required this.asistio,
    required this.pagado,
    required this.pagadoEnTxt,
  });
}

class _BarItem {
  final String label;
  final int value;
  _BarItem({required this.label, required this.value});
}
