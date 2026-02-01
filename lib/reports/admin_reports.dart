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

  // ====== ESTILO MINIMAL (BLANCO, PROFESIONAL) ======
  static const PdfColor _text = PdfColor.fromInt(0xFF111827);
  static const PdfColor _muted = PdfColor.fromInt(0xFF6B7280);
  static const PdfColor _border = PdfColor.fromInt(0xFFE5E7EB);
  static const PdfColor _rowAlt = PdfColor.fromInt(0xFFF9FAFB);

  static const PdfColor _tableHeadBg = PdfColor.fromInt(0xFFF3F4F6);
  static const PdfColor _tableHeadText = PdfColor.fromInt(0xFF111827);

  // Márgenes estándar
  static const pw.EdgeInsets _margin = pw.EdgeInsets.fromLTRB(28, 28, 28, 28);

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

    final doc = pw.Document(
      author: 'Turneo',
      title: 'Asistencias y pagos',
      subject: nombreEvento,
    );

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: _margin,
        // SIN header/footer
        build: (context) => [
          // SOLO información (si quieres 0 texto, borra estas 2 líneas)
          _tinyTitle('Asistencias y pagos — $nombreEvento'),
          pw.SizedBox(height: 10),

          _tableAsistencias(rows),
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

    final doc = pw.Document(
      author: 'Turneo',
      title: 'Listado de eventos',
      subject: 'Empresa $empresaId',
    );

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: _margin,
        // SIN header/footer
        build: (context) => [
          // SOLO información (si quieres 0 texto, borra estas 2 líneas)
          _tinyTitle('Listado de eventos — $rangoTxt'),
          pw.SizedBox(height: 10),

          _tableEventos(eventos),
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

    final doc = pw.Document(
      author: 'Turneo',
      title: 'Actividad del trabajador',
      subject: trabajadorNombre,
    );

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: _margin,
        // SIN header/footer
        build: (context) => [
          // SOLO información (si quieres 0 texto, borra estas 2 líneas)
          _tinyTitle('Actividad del trabajador — $trabajadorNombre'),
          pw.SizedBox(height: 10),

          rows.isEmpty
              ? _emptyText('No se han encontrado registros.')
              : _tableActividad(rows),
        ],
      ),
    );

    return doc.save();
  }

  // =====================================================
  // COMPONENTES MINIMAL (SOLO TEXTO/TABLA)
  // =====================================================

  static pw.Widget _tinyTitle(String text) {
    return pw.Text(
      text,
      style: pw.TextStyle(
        fontSize: 11,
        fontWeight: pw.FontWeight.bold,
        color: _text,
      ),
    );
  }

  static pw.Widget _emptyText(String text) {
    return pw.Text(
      text,
      style: pw.TextStyle(fontSize: 10, color: _muted),
    );
  }

  // =====================================================
  // TABLAS
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
      colFlex: const [32, 18, 10, 20],
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
      colFlex: const [34, 14, 14, 18],
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
      colFlex: const [30, 12, 12, 16, 10, 10, 20],
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
        decoration: pw.BoxDecoration(
          color: bg ?? PdfColors.white,
          border: header
              ? pw.Border(bottom: const pw.BorderSide(color: _border, width: 1))
              : null,
        ),
        child: pw.Text(
          text,
          maxLines: 2,
          overflow: pw.TextOverflow.clip,
          style: pw.TextStyle(
            fontSize: fontSize,
            color: header ? _tableHeadText : _text,
            fontWeight: header ? pw.FontWeight.bold : pw.FontWeight.normal,
          ),
        ),
      );
    }

    final headerRow = pw.TableRow(
      children: List.generate(headers.length, (i) {
        return cell(headers[i], bg: _tableHeadBg, header: true);
      }),
    );

    final rows = <pw.TableRow>[headerRow];

    for (int r = 0; r < data.length; r++) {
      final bg = (r % 2 == 0) ? PdfColors.white : _rowAlt;

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
        borderRadius: pw.BorderRadius.circular(8),
      ),
      child: pw.ClipRRect(
        horizontalRadius: 8,
        verticalRadius: 8,
        child: pw.Table(
          border: pw.TableBorder.symmetric(
            inside: pw.BorderSide(color: _border, width: 0.6),
          ),
          columnWidths: {
            for (int i = 0; i < colFlex.length; i++)
              i: pw.FlexColumnWidth(colFlex[i].toDouble()),
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
