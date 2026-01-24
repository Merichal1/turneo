import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

class AdminReports {
  static final _fmtDate = DateFormat('dd/MM/yyyy');
  static final _fmtDateTime = DateFormat('dd/MM/yyyy HH:mm');

  /// Informe: Disponibilidad / Asignaciones (asistentes del evento + pagado)
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
      final rol = (data['trabajadorRol'] ?? '').toString();
      final pagado = data['pagado'] == true ? 'Sí' : 'No';
      final pagadoEn = _tsToDateTime(data['pagadoEn']);
      final pagadoEnTxt = pagadoEn == null ? '' : _fmtDateTime.format(pagadoEn);

      return <String>[nombre, rol, pagado, pagadoEnTxt];
    }).toList();

    rows.sort((a, b) => a[0].toLowerCase().compareTo(b[0].toLowerCase()));

    final doc = pw.Document();

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(24),
        build: (context) => [
          _titleBlock(
            title: 'Informe de disponibilidad y asignaciones',
            subtitle: nombreEvento,
            meta: [
              if (fechaInicio != null) 'Inicio: ${_fmtDate.format(fechaInicio)}',
              if (fechaFin != null) 'Fin: ${_fmtDate.format(fechaFin)}',
              'Asistentes: ${rows.length}',
            ],
          ),
          pw.SizedBox(height: 12),
          pw.Table.fromTextArray(
            headerDecoration: const pw.BoxDecoration(color: PdfColors.grey200),
            headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
            cellStyle: const pw.TextStyle(fontSize: 10),
            cellAlignment: pw.Alignment.centerLeft,
            headers: const ['Trabajador', 'Rol', 'Pagado', 'Pagado en'],
            data: rows,
            columnWidths: {
              0: const pw.FlexColumnWidth(3),
              1: const pw.FlexColumnWidth(2),
              2: const pw.FlexColumnWidth(1),
              3: const pw.FlexColumnWidth(2),
            },
          ),
          pw.SizedBox(height: 10),
          _footerNote(),
        ],
      ),
    );

    return doc.save();
  }

  /// Informe: Eventos (lista de eventos de la empresa)
  static Future<Uint8List> buildInformeEventos({
    required FirebaseFirestore db,
    required String empresaId,
    DateTimeRange? range,
  }) async {
    Query<Map<String, dynamic>> q = db
        .collection('empresas')
        .doc(empresaId)
        .collection('eventos');

    // ✅ Si hay rango, filtramos por fechaInicio
    if (range != null) {
      final start = DateTime(range.start.year, range.start.month, range.start.day);
      final end = DateTime(range.end.year, range.end.month, range.end.day, 23, 59, 59);

      q = q
          .where('fechaInicio', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
          .where('fechaInicio', isLessThanOrEqualTo: Timestamp.fromDate(end));
    }

    final eventosSnap = await q.orderBy('fechaInicio', descending: false).get();

    final rows = eventosSnap.docs.map((d) {
      final data = d.data();
      final nombre = (data['nombre'] ?? 'Evento').toString();

      final inicio = _tsToDate(data['fechaInicio']);
      final fin = _tsToDate(data['fechaFin']);
      final inicioTxt = inicio == null ? '' : _fmtDate.format(inicio);
      final finTxt = fin == null ? '' : _fmtDate.format(fin);

      // ✅ "Ciudad" como campo mostrado
      final ubicacion = (data['ubicacion'] is Map) ? (data['ubicacion'] as Map) : const {};
final ciudad = (ubicacion['Ciudad'] ??
        ubicacion['ciudad'] ??
        data['ciudad'] ??
        data['Ciudad'] ??
        '')
    .toString();


      return <String>[nombre, inicioTxt, finTxt, ciudad];
    }).toList();

    final doc = pw.Document();

    final rangoTxt = range == null
        ? 'Todos'
        : '${_fmtDate.format(range.start)} - ${_fmtDate.format(range.end)}';

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(24),
        build: (context) => [
          _titleBlock(
            title: 'Informe de eventos',
            subtitle: 'Empresa: $empresaId',
            meta: [
              'Rango: $rangoTxt',
              'Total eventos: ${rows.length}',
            ],
          ),
          pw.SizedBox(height: 12),
          pw.Table.fromTextArray(
            headerDecoration: const pw.BoxDecoration(color: PdfColors.grey200),
            headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
            cellStyle: const pw.TextStyle(fontSize: 10),
            cellAlignment: pw.Alignment.centerLeft,
            headers: const ['Evento', 'Inicio', 'Fin', 'Ciudad'],
            data: rows,
            columnWidths: {
              0: const pw.FlexColumnWidth(3),
              1: const pw.FlexColumnWidth(1.5),
              2: const pw.FlexColumnWidth(1.5),
              3: const pw.FlexColumnWidth(2),
            },
          ),
          pw.SizedBox(height: 10),
          _footerNote(),
        ],
      ),
    );

    return doc.save();
  }

  /// Informe: Actividad del trabajador (GLOBAL: todos los eventos donde exista disponibilidad con trabajadorId)
  static Future<Uint8List> buildActividadTrabajadorGlobal({
    required FirebaseFirestore db,
    required String empresaId,
    required String trabajadorId, // docId de /trabajadores/{id}
    required String trabajadorNombre,
  }) async {
    final eventosSnap = await db
        .collection('empresas')
        .doc(empresaId)
        .collection('eventos')
        .orderBy('fechaInicio', descending: false)
        .get();

    final rows = <List<String>>[];

    for (final ev in eventosSnap.docs) {
      final evData = ev.data();
      final eventoNombre = (evData['nombre'] ?? 'Evento').toString();
      final inicio = _tsToDate(evData['fechaInicio']);
      final fin = _tsToDate(evData['fechaFin']);

      final q = db
          .collection('empresas')
          .doc(empresaId)
          .collection('eventos')
          .doc(ev.id)
          .collection('disponibilidad');

      // ✅ ÚNICO filtro correcto
      final snap = await q
          .where('trabajadorId', isEqualTo: trabajadorId)
          .limit(1)
          .get();

      if (snap.docs.isEmpty) continue;

      final d = snap.docs.first.data();
      final rol = (d['trabajadorRol'] ?? '').toString();
      final asistio = d['asistio'] == true ? 'Sí' : 'No';
      final pagado = d['pagado'] == true ? 'Sí' : 'No';

      final pagadoEn = _tsToDateTime(d['pagadoEn']);
      final pagadoEnTxt = pagadoEn == null ? '' : _fmtDateTime.format(pagadoEn);

      rows.add([
        eventoNombre,
        inicio == null ? '' : _fmtDate.format(inicio),
        fin == null ? '' : _fmtDate.format(fin),
        rol,
        asistio,
        pagado,
        pagadoEnTxt,
      ]);
    }

    final doc = pw.Document();

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(24),
        build: (context) => [
          _titleBlock(
            title: 'Informe de actividad del trabajador',
            subtitle: trabajadorNombre,
            meta: [
              'Eventos encontrados: ${rows.length}',
            ],
          ),
          pw.SizedBox(height: 12),
          pw.Table.fromTextArray(
            headerDecoration: const pw.BoxDecoration(color: PdfColors.grey200),
            headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
            cellStyle: const pw.TextStyle(fontSize: 9),
            cellAlignment: pw.Alignment.centerLeft,
            headers: const [
              'Evento',
              'Inicio',
              'Fin',
              'Rol',
              'Asistió',
              'Pagado',
              'Pagado en'
            ],
            data: rows,
            columnWidths: {
              0: const pw.FlexColumnWidth(3),
              1: const pw.FlexColumnWidth(1.2),
              2: const pw.FlexColumnWidth(1.2),
              3: const pw.FlexColumnWidth(1.5),
              4: const pw.FlexColumnWidth(1),
              5: const pw.FlexColumnWidth(1),
              6: const pw.FlexColumnWidth(1.8),
            },
          ),
          pw.SizedBox(height: 10),
          _footerNote(),
        ],
      ),
    );

    return doc.save();
  }

  /// Informe: Actividad del trabajador (solo un evento)
  static Future<Uint8List> buildActividadTrabajadorEvento({
    required FirebaseFirestore db,
    required String empresaId,
    required String eventoId,
    required String trabajadorNombre,
  }) async {
    final eventoDoc = await db
        .collection('empresas')
        .doc(empresaId)
        .collection('eventos')
        .doc(eventoId)
        .get();

    final evento = eventoDoc.data() ?? {};
    final nombreEvento = (evento['nombre'] ?? 'Evento').toString();

    final q = await db
        .collection('empresas')
        .doc(empresaId)
        .collection('eventos')
        .doc(eventoId)
        .collection('disponibilidad')
        .where('asistio', isEqualTo: true)
        .where('trabajadorNombre', isEqualTo: trabajadorNombre)
        .limit(50)
        .get();

    final items = q.docs.map((d) {
      final data = d.data();
      final rol = (data['trabajadorRol'] ?? '').toString();
      final pagado = data['pagado'] == true;
      final pagadoEn = _tsToDateTime(data['pagadoEn']);
      return {
        'rol': rol,
        'pagado': pagado,
        'pagadoEn': pagadoEn,
      };
    }).toList();

    final doc = pw.Document();
    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(24),
        build: (context) => [
          _titleBlock(
            title: 'Informe de actividad del trabajador',
            subtitle: trabajadorNombre,
            meta: [
              'Evento: $nombreEvento',
              'Registros: ${items.length}',
            ],
          ),
          pw.SizedBox(height: 12),
          pw.Table.fromTextArray(
            headerDecoration: const pw.BoxDecoration(color: PdfColors.grey200),
            headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
            cellStyle: const pw.TextStyle(fontSize: 10),
            cellAlignment: pw.Alignment.centerLeft,
            headers: const ['Rol', 'Pagado', 'Pagado en'],
            data: items.map((e) {
              final dt = e['pagadoEn'] as DateTime?;
              return [
                (e['rol'] ?? '').toString(),
                (e['pagado'] == true) ? 'Sí' : 'No',
                dt == null ? '' : _fmtDateTime.format(dt),
              ];
            }).toList(),
            columnWidths: {
              0: const pw.FlexColumnWidth(3),
              1: const pw.FlexColumnWidth(1),
              2: const pw.FlexColumnWidth(2),
            },
          ),
          pw.SizedBox(height: 10),
          _footerNote(),
        ],
      ),
    );
    return doc.save();
  }

  static pw.Widget _titleBlock({
    required String title,
    required String subtitle,
    required List<String> meta,
  }) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(14),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey300),
        borderRadius: pw.BorderRadius.circular(10),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(title,
              style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 4),
          pw.Text(subtitle,
              style: pw.TextStyle(fontSize: 12, color: PdfColors.grey700)),
          pw.SizedBox(height: 8),
          pw.Wrap(
            spacing: 10,
            runSpacing: 4,
            children: meta.map((m) {
              return pw.Container(
                padding:
                    const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: pw.BoxDecoration(
                  color: PdfColors.grey100,
                  borderRadius: pw.BorderRadius.circular(20),
                ),
                child: pw.Text(m, style: const pw.TextStyle(fontSize: 9)),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  static pw.Widget _footerNote() {
    return pw.Text(
      'Generado automáticamente desde Turneo.',
      style: pw.TextStyle(fontSize: 9, color: PdfColors.grey600),
    );
  }

  static DateTime? _tsToDate(dynamic v) {
    if (v == null) return null;
    if (v is Timestamp) return v.toDate();
    if (v is DateTime) return v;
    return null;
  }

  static DateTime? _tsToDateTime(dynamic v) => _tsToDate(v);
}
