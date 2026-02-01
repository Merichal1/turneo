import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:printing/printing.dart';

import '../../config/app_config.dart';
import '../../reports/admin_reports.dart';

class AdminPaymentsHistoryScreen extends StatefulWidget {
  const AdminPaymentsHistoryScreen({super.key});

  @override
  State<AdminPaymentsHistoryScreen> createState() => _AdminPaymentsHistoryScreenState();
}

class _AdminPaymentsHistoryScreenState extends State<AdminPaymentsHistoryScreen> {
  // ====== THEME ======
  static const Color _bg = Color(0xFFF8FAFC);
  static const Color _card = Colors.white;
  static const Color _border = Color(0xFFE5E7EB);
  static const Color _accent = Color(0xFF2563EB);
  static const Color _textMain = Color(0xFF0F172A);
  static const Color _textSecondary = Color(0xFF64748B);
  static const Color _ok = Color(0xFF10B981);
  static const Color _bad = Color(0xFFEF4444);
  static const Color _warn = Color(0xFFF59E0B);

  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // Buscador eventos (dialog)
  final TextEditingController _eventoSearchCtrl = TextEditingController();
  String _eventoSearchTerm = '';

  // Worker search (dialog)
  String _workerSearchTerm = '';

  // Search asistentes (tab pagos)
  final TextEditingController _searchCtrl = TextEditingController();
  String _searchTerm = '';

  int _tab = 0; // 0 pagos, 1 informes

  // Data selection
  String? _empresaId;
  String? _selectedEventoId;
  Map<String, dynamic>? _selectedEventoData;

  bool _isGenerating = false;

  DateTimeRange? _range;

  // Worker selection for report (global)
  String? _selectedWorkerId; // docId de /trabajadores/{docId}
  String? _selectedWorkerName;

  // extra para compatibilidad en informes
  String? _selectedWorkerUid;
  String? _selectedWorkerEmail;

  @override
  void initState() {
    super.initState();

    _empresaId = AppConfig.empresaId;

    _searchCtrl.addListener(() {
      setState(() => _searchTerm = _searchCtrl.text.trim().toLowerCase());
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _eventoSearchCtrl.dispose();
    super.dispose();
  }

  // ===========================
  // BUILD
  // ===========================
  @override
  Widget build(BuildContext context) {
    if (_empresaId == null) {
      return const Scaffold(
        backgroundColor: _bg,
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: _bg,
      body: CustomScrollView(
        slivers: [
          _buildSliverAppBar(),
          SliverToBoxAdapter(child: _buildTopControls()),
          if (_tab == 0) ...[
            _buildAsistentesGrid(),
          ] else ...[
            SliverToBoxAdapter(child: _buildReportsAndAnalytics()),
          ],
          const SliverPadding(padding: EdgeInsets.only(bottom: 36)),
        ],
      ),
    );
  }

  // ===========================
  // APP BAR
  // ===========================
  Widget _buildSliverAppBar() {
    return SliverAppBar(
      expandedHeight: 118,
      floating: true,
      pinned: true,
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.white,
      elevation: 0,
      flexibleSpace: FlexibleSpaceBar(
        titlePadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: const [
            Text(
              'Gestión de Pagos e Informes',
              style: TextStyle(
                color: _textMain,
                fontWeight: FontWeight.w900,
                fontSize: 18,
              ),
            ),
            SizedBox(height: 2),
            Text(
              'Pagos claros • Informes profesionales • Rendimiento',
              style: TextStyle(
                color: _textSecondary,
                fontWeight: FontWeight.w600,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ===========================
  // TOP CONTROLS
  // ===========================
  Widget _buildTopControls() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
      child: Column(
        children: [
          _CardShell(
            child: Column(
              children: [
                _buildEventoSelector(),
                const SizedBox(height: 12),
                _buildTabs(),
                const SizedBox(height: 12),
                if (_tab == 0) _buildSearchBar(),
              ],
            ),
          ),
          const SizedBox(height: 12),
          if (_selectedEventoId == null)
            _HintBanner(
              icon: Icons.info_outline,
              text: 'Selecciona un evento para ver pagos e informes.',
            ),
        ],
      ),
    );
  }

  // ---------- Evento selector ----------
  Widget _buildEventoSelector() {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _db
          .collection('empresas')
          .doc(_empresaId)
          .collection('eventos')
          .orderBy('fechaInicio', descending: true)
          .snapshots(),
      builder: (context, snap) {
        if (!snap.hasData) return const LinearProgressIndicator(minHeight: 2);

        final docs = snap.data!.docs;
        final selectedEventName = (_selectedEventoData?['nombre'] ?? 'Seleccionar evento').toString();

        return InkWell(
          onTap: () => _showEventoSearchDialog(context, docs),
          child: InputDecorator(
            decoration: _inputStyle('Evento', Icons.event_outlined),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    selectedEventName,
                    style: TextStyle(
                      color: _selectedEventoId == null ? _textSecondary : _textMain,
                      fontWeight: FontWeight.w600,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const Icon(Icons.arrow_drop_down, color: _textSecondary),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showEventoSearchDialog(
    BuildContext context,
    List<QueryDocumentSnapshot<Map<String, dynamic>>> allDocs,
  ) {
    _eventoSearchTerm = '';
    _eventoSearchCtrl.text = '';

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final filteredDocs = allDocs.where((doc) {
              final name = (doc.data()['nombre'] ?? '').toString().toLowerCase();
              return name.contains(_eventoSearchTerm.toLowerCase());
            }).toList();

            return AlertDialog(
              title: const Text("Buscar Evento", style: TextStyle(fontWeight: FontWeight.w900)),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
              content: SizedBox(
                width: double.maxFinite,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: _eventoSearchCtrl,
                      decoration: _inputStyle('Nombre del evento...', Icons.search),
                      onChanged: (value) => setDialogState(() => _eventoSearchTerm = value),
                    ),
                    const SizedBox(height: 15),
                    ConstrainedBox(
                      constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.45),
                      child: ListView.builder(
                        shrinkWrap: true,
                        itemCount: filteredDocs.length,
                        itemBuilder: (context, i) {
                          final data = filteredDocs[i].data();
                          final ts = data['fechaInicio'];
                          final dt = ts is Timestamp ? ts.toDate() : null;
                          return ListTile(
                            title: Text(
                              (data['nombre'] ?? 'Sin nombre').toString(),
                              style: const TextStyle(fontWeight: FontWeight.w700),
                            ),
                            subtitle: Text(dt == null ? '' : DateFormat('dd/MM/yyyy').format(dt)),
                            onTap: () {
                              setState(() {
                                _selectedEventoId = filteredDocs[i].id;
                                _selectedEventoData = data;
                              });
                              Navigator.pop(context);
                            },
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildTabs() {
    return LayoutBuilder(
      builder: (context, c) {
        final isNarrow = c.maxWidth < 520;
        return Row(
          children: [
            Expanded(
              child: _TabChip(
                selected: _tab == 0,
                label: 'Pagos',
                icon: Icons.payments_outlined,
                compact: isNarrow,
                onTap: () => setState(() => _tab = 0),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _TabChip(
                selected: _tab == 1,
                label: 'Informes y rendimiento',
                icon: Icons.insights_outlined,
                compact: isNarrow,
                onTap: () => setState(() => _tab = 1),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildSearchBar() {
    return TextField(
      controller: _searchCtrl,
      decoration: _inputStyle('Buscar trabajador...', Icons.search).copyWith(
        hintText: 'Escribe un nombre…',
      ),
    );
  }

  // ===========================
  // TAB 0: PAGOS (grid)
  // ===========================
  SliverToBoxAdapter _buildEmptyPaymentsHint() {
    return const SliverToBoxAdapter(
      child: Padding(
        padding: EdgeInsets.all(24),
        child: Center(
          child: Text(
            'Selecciona un evento para gestionar pagos.',
            style: TextStyle(color: _textSecondary, fontWeight: FontWeight.w700),
          ),
        ),
      ),
    );
  }

  Widget _buildAsistentesGrid() {
    if (_selectedEventoId == null) return _buildEmptyPaymentsHint();

    final stream = _db
        .collection('empresas')
        .doc(_empresaId)
        .collection('eventos')
        .doc(_selectedEventoId)
        .collection('disponibilidad')
        .where('asistio', isEqualTo: true)
        .snapshots();

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: stream,
      builder: (context, snap) {
        if (!snap.hasData) {
          return const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.only(top: 18),
              child: Center(child: CircularProgressIndicator()),
            ),
          );
        }

        final docs = snap.data!.docs;

        final filtered = docs.where((d) {
          final name = (d.data()['trabajadorNombre'] ?? '').toString().toLowerCase();
          return name.contains(_searchTerm);
        }).toList();

        final pagados = docs.where((d) => d.data()['pagado'] == true).length;
        final pendientes = docs.length - pagados;

        return SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          sliver: SliverList(
            delegate: SliverChildListDelegate([
              _CardShell(
                child: LayoutBuilder(
                  builder: (context, c) {
                    final isWide = c.maxWidth > 720;
                    return isWide
                        ? Row(
                            children: [
                              Expanded(child: _KpiTile(title: 'Asistentes', value: '${docs.length}', icon: Icons.group_outlined)),
                              const SizedBox(width: 10),
                              Expanded(child: _KpiTile(title: 'Pagados', value: '$pagados', icon: Icons.check_circle_outline, color: _ok)),
                              const SizedBox(width: 10),
                              Expanded(child: _KpiTile(title: 'Pendientes', value: '$pendientes', icon: Icons.priority_high, color: _warn)),
                            ],
                          )
                        : Column(
                            children: [
                              Row(
                                children: [
                                  Expanded(child: _KpiTile(title: 'Asistentes', value: '${docs.length}', icon: Icons.group_outlined)),
                                  const SizedBox(width: 10),
                                  Expanded(child: _KpiTile(title: 'Pagados', value: '$pagados', icon: Icons.check_circle_outline, color: _ok)),
                                ],
                              ),
                              const SizedBox(height: 10),
                              _KpiTile(title: 'Pendientes', value: '$pendientes', icon: Icons.priority_high, color: _warn),
                            ],
                          );
                  },
                ),
              ),
              const SizedBox(height: 12),
              if (filtered.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(20),
                  child: Center(child: Text('No hay resultados', style: TextStyle(color: _textSecondary))),
                )
              else
                LayoutBuilder(
                  builder: (context, c) {
                    final w = c.maxWidth;
                    final crossAxisCount = w >= 980 ? 3 : (w >= 680 ? 2 : 1);
                    const tileHeight = 96.0;

                    return GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: filtered.length,
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: crossAxisCount,
                        mainAxisExtent: tileHeight,
                        mainAxisSpacing: 10,
                        crossAxisSpacing: 10,
                      ),
                      itemBuilder: (context, i) {
                        final data = filtered[i].data();
                        return _WorkerPaymentTile(
                          nombre: (data['trabajadorNombre'] ?? 'N/A').toString(),
                          rol: (data['trabajadorRol'] ?? 'Staff').toString(),
                          pagado: data['pagado'] == true,
                          onToggle: (val) => _updatePaymentStatus(filtered[i].id, val),
                        );
                      },
                    );
                  },
                ),
            ]),
          ),
        );
      },
    );
  }

  // ===========================
  // TAB 1: INFORMES + ANALYTICS
  // ===========================
  Widget _buildReportsAndAnalytics() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Column(
        children: [
          _CardShell(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Informes',
                  style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: _textMain),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Genera PDFs con diseño pro. Elige evento, rango o trabajador.',
                  style: TextStyle(color: _textSecondary, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 14),

                LayoutBuilder(
                  builder: (context, c) {
                    final isWide = c.maxWidth >= 860;
                    final children = <Widget>[
                      _ReportButton(
                        label: 'Informe del evento (pagos)',
                        icon: Icons.picture_as_pdf_outlined,
                        loading: _isGenerating,
                        onTap: _selectedEventoId == null ? null : _exportEventoPdf,
                      ),
                      _ReportButton(
                        label: 'Informe de eventos (rango)',
                        icon: Icons.event_note_outlined,
                        loading: _isGenerating,
                        onTap: _exportEventosPdfWithRange,
                      ),
                      _ReportButton(
                        label: 'Actividad trabajador (global)',
                        icon: Icons.person_outline,
                        loading: _isGenerating,
                        onTap: _exportActividadTrabajadorGlobal,
                      ),
                    ];

                    if (isWide) {
                      return Row(
                        children: [
                          Expanded(child: children[0]),
                          const SizedBox(width: 10),
                          Expanded(child: children[1]),
                          const SizedBox(width: 10),
                          Expanded(child: children[2]),
                        ],
                      );
                    }

                    return Column(
                      children: [
                        children[0],
                        const SizedBox(height: 10),
                        children[1],
                        const SizedBox(height: 10),
                        children[2],
                      ],
                    );
                  },
                ),

                const SizedBox(height: 14),
                _buildReportSelectors(),
              ],
            ),
          ),
          const SizedBox(height: 12),
          if (_selectedEventoId != null) _buildAnalyticsDashboard(),
        ],
      ),
    );
  }

  Widget _buildReportSelectors() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                icon: const Icon(Icons.date_range_outlined),
                label: Text(
                  _range == null
                      ? 'Elegir rango de fechas'
                      : '${DateFormat('dd/MM/yyyy').format(_range!.start)} - ${DateFormat('dd/MM/yyyy').format(_range!.end)}',
                  overflow: TextOverflow.ellipsis,
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: _accent,
                  side: const BorderSide(color: _border),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
                ),
                onPressed: () async {
                  final now = DateTime.now();
                  final picked = await showDateRangePicker(
                    context: context,
                    firstDate: DateTime(now.year - 3, 1, 1),
                    lastDate: DateTime(now.year + 1, 12, 31),
                    initialDateRange: _range ??
                        DateTimeRange(
                          start: DateTime(now.year, now.month, 1),
                          end: DateTime(now.year, now.month, now.day),
                        ),
                  );
                  if (picked != null) setState(() => _range = picked);
                },
              ),
            ),
            const SizedBox(width: 10),
            if (_range != null)
              IconButton(
                tooltip: 'Limpiar rango',
                onPressed: () => setState(() => _range = null),
                icon: const Icon(Icons.close, color: _textSecondary),
              ),
          ],
        ),
        const SizedBox(height: 10),

        // ✅ IMPORTANTE: sin orderBy para no "perder" docs que no tengan nombre_lower
        StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: _db
              .collection('empresas')
              .doc(_empresaId)
              .collection('trabajadores')
              .snapshots(),
          builder: (context, snap) {
            if (!snap.hasData) return const LinearProgressIndicator(minHeight: 2);
            final docs = snap.data!.docs;

            final displayText = (_selectedWorkerName != null && _selectedWorkerName!.isNotEmpty)
                ? _selectedWorkerName!
                : 'Seleccionar trabajador (para informe global)';

            return InkWell(
              onTap: () => _showWorkerSearchDialog(context, docs),
              child: InputDecorator(
                decoration: _inputStyle('Trabajador', Icons.person_outline),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        displayText,
                        style: TextStyle(
                          color: _selectedWorkerId == null ? _textSecondary : _textMain,
                          fontWeight: FontWeight.w600,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const Icon(Icons.arrow_drop_down, color: _textSecondary),
                  ],
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  // ===========================
  // ANALYTICS
  // ===========================
  Widget _buildAnalyticsDashboard() {
    final stream = _db
        .collection('empresas')
        .doc(_empresaId)
        .collection('eventos')
        .doc(_selectedEventoId)
        .collection('disponibilidad')
        .where('asistio', isEqualTo: true)
        .snapshots();

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: stream,
      builder: (context, snap) {
        if (!snap.hasData || snap.data!.docs.isEmpty) {
          return _HintBanner(
            icon: Icons.bar_chart_outlined,
            text: 'Este evento no tiene asistentes marcados como “asistió”.',
          );
        }

        final docs = snap.data!.docs;
        final total = docs.length;
        final paid = docs.where((d) => d.data()['pagado'] == true).length;
        final pending = total - paid;

        final roleCounts = <String, int>{};
        for (final d in docs) {
          final r = (d.data()['trabajadorRol'] ?? 'Staff').toString().trim();
          roleCounts[r] = (roleCounts[r] ?? 0) + 1;
        }
        final sortedRoles = roleCounts.entries.toList()..sort((a, b) => b.value.compareTo(a.value));

        final now = DateTime.now();
        final days = List.generate(14, (i) {
          final dt = DateTime(now.year, now.month, now.day).subtract(Duration(days: 13 - i));
          return dt;
        });

        final paidByDay = <DateTime, int>{for (final d in days) d: 0};
        for (final doc in docs) {
          final data = doc.data();
          if (data['pagado'] != true) continue;
          final ts = data['pagadoEn'];
          if (ts is Timestamp) {
            final dt = ts.toDate();
            final day = DateTime(dt.year, dt.month, dt.day);
            if (paidByDay.containsKey(day)) {
              paidByDay[day] = (paidByDay[day] ?? 0) + 1;
            }
          }
        }

        final seriesSpots = <FlSpot>[];
        for (int i = 0; i < days.length; i++) {
          final d = days[i];
          seriesSpots.add(FlSpot(i.toDouble(), (paidByDay[d] ?? 0).toDouble()));
        }

        return Column(
          children: [
            _CardShell(
              child: LayoutBuilder(
                builder: (context, c) {
                  final isWide = c.maxWidth >= 900;
                  return isWide
                      ? Row(
                          children: [
                            Expanded(child: _KpiTile(title: 'Asistentes', value: '$total', icon: Icons.group_outlined)),
                            const SizedBox(width: 10),
                            Expanded(child: _KpiTile(title: 'Pagados', value: '$paid', icon: Icons.check_circle_outline, color: _ok)),
                            const SizedBox(width: 10),
                            Expanded(child: _KpiTile(title: 'Pendientes', value: '$pending', icon: Icons.priority_high, color: _warn)),
                            const SizedBox(width: 10),
                            Expanded(
                              child: _KpiTile(
                                title: 'Tasa de pago',
                                value: total == 0 ? '0%' : '${((paid / total) * 100).round()}%',
                                icon: Icons.percent,
                                color: _accent,
                              ),
                            ),
                          ],
                        )
                      : Column(
                          children: [
                            Row(
                              children: [
                                Expanded(child: _KpiTile(title: 'Asistentes', value: '$total', icon: Icons.group_outlined)),
                                const SizedBox(width: 10),
                                Expanded(child: _KpiTile(title: 'Pagados', value: '$paid', icon: Icons.check_circle_outline, color: _ok)),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                Expanded(child: _KpiTile(title: 'Pendientes', value: '$pending', icon: Icons.priority_high, color: _warn)),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: _KpiTile(
                                    title: 'Tasa de pago',
                                    value: total == 0 ? '0%' : '${((paid / total) * 100).round()}%',
                                    icon: Icons.percent,
                                    color: _accent,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        );
                },
              ),
            ),
            const SizedBox(height: 12),
            LayoutBuilder(
              builder: (context, c) {
                final isWide = c.maxWidth >= 900;
                if (isWide) {
                  return Row(
                    children: [
                      Expanded(child: _buildDonutPaid(paid: paid, pending: pending)),
                      const SizedBox(width: 12),
                      Expanded(child: _buildLinePaidSeries(seriesSpots)),
                      const SizedBox(width: 12),
                      Expanded(child: _buildRolesBar(sortedRoles, total)),
                    ],
                  );
                }

                return Column(
                  children: [
                    _buildDonutPaid(paid: paid, pending: pending),
                    const SizedBox(height: 12),
                    _buildLinePaidSeries(seriesSpots),
                    const SizedBox(height: 12),
                    _buildRolesBar(sortedRoles, total),
                  ],
                );
              },
            ),
          ],
        );
      },
    );
  }

  Widget _buildDonutPaid({required int paid, required int pending}) {
    final total = paid + pending;
    final sections = total == 0
        ? <PieChartSectionData>[]
        : [
            PieChartSectionData(value: paid.toDouble(), title: '', color: _ok, radius: 26),
            PieChartSectionData(value: pending.toDouble(), title: '', color: _bad, radius: 26),
          ];

    return _CardShell(
      child: SizedBox(
        height: 220,
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Estado de pagos', style: TextStyle(fontWeight: FontWeight.w900, color: _textMain)),
                  const SizedBox(height: 6),
                  Text('Pagados vs pendientes', style: TextStyle(color: _textSecondary, fontWeight: FontWeight.w600)),
                  const Spacer(),
                  _LegendDot(color: _ok, label: 'Pagados: $paid'),
                  const SizedBox(height: 8),
                  _LegendDot(color: _bad, label: 'Pendientes: $pending'),
                  const SizedBox(height: 14),
                  _MiniProgress(
                    value: total == 0 ? 0 : (paid / total),
                    label: total == 0 ? '0%' : '${((paid / total) * 100).round()}%',
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            SizedBox(
              width: 120,
              height: 120,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  PieChart(PieChartData(centerSpaceRadius: 44, sectionsSpace: 2, sections: sections)),
                  Text(
                    total == 0 ? '—' : '${((paid / total) * 100).round()}%',
                    style: const TextStyle(fontWeight: FontWeight.w900, color: _textMain),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLinePaidSeries(List<FlSpot> spots) {
    return _CardShell(
      child: SizedBox(
        height: 220,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Pagos recientes', style: TextStyle(fontWeight: FontWeight.w900, color: _textMain)),
            const SizedBox(height: 6),
            Text('Últimos 14 días', style: TextStyle(color: _textSecondary, fontWeight: FontWeight.w600)),
            const SizedBox(height: 12),
            Expanded(
              child: LineChart(
                LineChartData(
                  gridData: FlGridData(show: false),
                  titlesData: FlTitlesData(show: false),
                  borderData: FlBorderData(show: false),
                  lineBarsData: [
                    LineChartBarData(
                      spots: spots,
                      isCurved: true,
                      dotData: FlDotData(show: false),
                      belowBarData: BarAreaData(show: true),
                      barWidth: 3,
                    ),
                  ],
                  minY: 0,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRolesBar(List<MapEntry<String, int>> roles, int total) {
    final top = roles.take(5).toList();
    return _CardShell(
      child: SizedBox(
        height: 220,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Distribución de roles', style: TextStyle(fontWeight: FontWeight.w900, color: _textMain)),
            const SizedBox(height: 6),
            Text('Top 5 roles del evento', style: TextStyle(color: _textSecondary, fontWeight: FontWeight.w600)),
            const SizedBox(height: 12),
            Expanded(
              child: ListView.separated(
                itemCount: top.length,
                physics: const NeverScrollableScrollPhysics(),
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (context, i) {
                  final e = top[i];
                  final v = total == 0 ? 0 : (e.value / total);
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              e.key,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontWeight: FontWeight.w800, color: _textMain),
                            ),
                          ),
                          Text('${e.value}', style: const TextStyle(fontWeight: FontWeight.w900, color: _textSecondary)),
                        ],
                      ),
                      const SizedBox(height: 6),
                      LinearProgressIndicator(
                        value: v.toDouble(),
                        minHeight: 8,
                        backgroundColor: const Color(0xFFEFF6FF),
                        valueColor: const AlwaysStoppedAnimation(_accent),
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ===========================
  // ACTIONS
  // ===========================
  Future<void> _updatePaymentStatus(String docId, bool status) async {
    if (_empresaId == null || _selectedEventoId == null) return;

    await _db
        .collection('empresas')
        .doc(_empresaId)
        .collection('eventos')
        .doc(_selectedEventoId)
        .collection('disponibilidad')
        .doc(docId)
        .update({
      'pagado': status,
      'pagadoEn': status ? FieldValue.serverTimestamp() : null,
    });
  }

  void _showWorkerSearchDialog(
    BuildContext context,
    List<QueryDocumentSnapshot<Map<String, dynamic>>> allDocs,
  ) {
    _workerSearchTerm = '';

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            String displayName(Map<String, dynamic> data, String docId) {
              final nombre = (data['nombre'] ?? '').toString().trim();
              final apellidos = (data['apellidos'] ?? '').toString().trim();
              final full = '$nombre $apellidos'.trim();
              if (full.isNotEmpty) return full;

              final email = (data['email'] ?? '').toString().trim();
              if (email.isNotEmpty) return 'Sin nombre • $email';

              final uid = (data['uid'] ?? data['authUid'] ?? data['userId'] ?? '').toString().trim();
              if (uid.isNotEmpty) {
                final cut = uid.substring(0, uid.length > 6 ? 6 : uid.length);
                return 'Sin nombre • uid:$cut';
              }

              return 'Sin nombre • id:$docId';
            }

            bool matchesSearch(String shown, Map<String, dynamic> data, String docId) {
              final q = _workerSearchTerm.trim().toLowerCase();
              if (q.isEmpty) return true;

              final nombre = (data['nombre'] ?? '').toString().toLowerCase();
              final apellidos = (data['apellidos'] ?? '').toString().toLowerCase();
              final email = (data['email'] ?? '').toString().toLowerCase();
              final uid = (data['uid'] ?? data['authUid'] ?? data['userId'] ?? '').toString().toLowerCase();

              return shown.toLowerCase().contains(q) ||
                  nombre.contains(q) ||
                  apellidos.contains(q) ||
                  email.contains(q) ||
                  uid.contains(q) ||
                  docId.toLowerCase().contains(q);
            }

            final filtered = allDocs.where((doc) {
              final data = doc.data();
              final shown = displayName(data, doc.id);
              return matchesSearch(shown, data, doc.id);
            }).toList()
              ..sort((a, b) {
                final sa = displayName(a.data(), a.id).toLowerCase();
                final sb = displayName(b.data(), b.id).toLowerCase();
                return sa.compareTo(sb);
              });

            return AlertDialog(
              title: const Text("Buscar Trabajador", style: TextStyle(fontWeight: FontWeight.w900)),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
              content: SizedBox(
                width: MediaQuery.of(context).size.width * 0.86,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      decoration: _inputStyle('Nombre, email o id...', Icons.search),
                      onChanged: (value) => setDialogState(() => _workerSearchTerm = value),
                    ),
                    const SizedBox(height: 15),
                    ConstrainedBox(
                      constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.55),
                      child: filtered.isEmpty
                          ? const Padding(
                              padding: EdgeInsets.all(20),
                              child: Text("No se encontraron resultados"),
                            )
                          : ListView.builder(
                              shrinkWrap: true,
                              itemCount: filtered.length,
                              itemBuilder: (context, i) {
                                final doc = filtered[i];
                                final data = doc.data();

                                final shown = displayName(data, doc.id);
                                final nombre = (data['nombre'] ?? '').toString().trim();
                                final letter = (nombre.isNotEmpty ? nombre[0] : '•').toUpperCase();

                                return ListTile(
                                  leading: CircleAvatar(
                                    backgroundColor: _accent.withOpacity(0.1),
                                    child: Text(
                                      letter,
                                      style: const TextStyle(color: _accent, fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                  title: Text(shown, style: const TextStyle(fontWeight: FontWeight.w700)),
                                  subtitle: Text('docId: ${doc.id}', style: const TextStyle(fontSize: 12)),
                                  onTap: () {
                                    setState(() {
                                      _selectedWorkerId = doc.id;
                                      _selectedWorkerName = shown;

                                      _selectedWorkerUid =
                                          (data['uid'] ?? data['authUid'] ?? data['userId'] ?? '').toString().trim();
                                      _selectedWorkerEmail = (data['email'] ?? '').toString().trim();

                                      _workerSearchTerm = '';
                                    });
                                    Navigator.pop(context);
                                  },
                                );
                              },
                            ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _exportEventoPdf() async {
    if (_empresaId == null || _selectedEventoId == null) return;

    setState(() => _isGenerating = true);
    try {
      final bytes = await AdminReports.buildDisponibilidadYAsignaciones(
        db: _db,
        empresaId: _empresaId!,
        eventoId: _selectedEventoId!,
      );
      await Printing.layoutPdf(onLayout: (_) => bytes);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _isGenerating = false);
    }
  }

  Future<void> _exportEventosPdfWithRange() async {
    if (_empresaId == null) return;

    setState(() => _isGenerating = true);
    try {
      final bytes = await AdminReports.buildInformeEventos(
        db: _db,
        empresaId: _empresaId!,
        range: _range,
      );
      await Printing.layoutPdf(onLayout: (_) => bytes);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _isGenerating = false);
    }
  }

  Future<void> _exportActividadTrabajadorGlobal() async {
    if (_empresaId == null) return;

    if (_selectedWorkerId == null || (_selectedWorkerName ?? '').trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Selecciona un trabajador primero.')),
      );
      return;
    }

    setState(() => _isGenerating = true);
    try {
      // ✅ firma nueva (docId + uid + email opcional)
      final bytes = await AdminReports.buildActividadTrabajadorGlobal(
        db: _db,
        empresaId: _empresaId!,
        trabajadorDocId: _selectedWorkerId!,
        trabajadorNombre: _selectedWorkerName!,
        trabajadorUid: _selectedWorkerUid,
        trabajadorEmail: _selectedWorkerEmail,
      );
      await Printing.layoutPdf(onLayout: (_) => bytes);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _isGenerating = false);
    }
  }

  // ===========================
  // UI HELPERS
  // ===========================
  InputDecoration _inputStyle(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon, color: _accent),
      filled: true,
      fillColor: Colors.white,
      isDense: true,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: _border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: _accent, width: 2),
      ),
    );
  }
}

// ===========================
// WIDGETS
// ===========================

class _CardShell extends StatelessWidget {
  final Widget child;
  const _CardShell({required this.child});

  static const Color _border = Color(0xFFE5E7EB);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: _border),
        boxShadow: const [
          BoxShadow(
            color: Color(0x14000000),
            blurRadius: 22,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _TabChip extends StatelessWidget {
  final bool selected;
  final String label;
  final IconData icon;
  final bool compact;
  final VoidCallback onTap;

  const _TabChip({
    required this.selected,
    required this.label,
    required this.icon,
    required this.compact,
    required this.onTap,
  });

  static const Color _accent = Color(0xFF2563EB);
  static const Color _textMain = Color(0xFF0F172A);
  static const Color _border = Color(0xFFE5E7EB);

  @override
  Widget build(BuildContext context) {
    final bg = selected ? const Color(0xFFEFF6FF) : Colors.white;
    final br = selected ? Colors.transparent : _border;
    final ic = selected ? _accent : const Color(0xFF64748B);
    final tx = selected ? _textMain : const Color(0xFF64748B);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 12, vertical: compact ? 10 : 12),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: br),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 18, color: ic),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: tx, fontWeight: FontWeight.w900, fontSize: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HintBanner extends StatelessWidget {
  final IconData icon;
  final String text;
  const _HintBanner({required this.icon, required this.text});

  static const Color _border = Color(0xFFE5E7EB);
  static const Color _textSecondary = Color(0xFF64748B);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      margin: const EdgeInsets.only(top: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _border),
      ),
      child: Row(
        children: [
          Icon(icon, color: _textSecondary),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(color: _textSecondary, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}

class _KpiTile extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color? color;

  const _KpiTile({
    required this.title,
    required this.value,
    required this.icon,
    this.color,
  });

  static const Color _textMain = Color(0xFF0F172A);
  static const Color _textSecondary = Color(0xFF64748B);

  @override
  Widget build(BuildContext context) {
    final c = color ?? const Color(0xFF2563EB);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: c.withOpacity(0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: c, size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(color: _textSecondary, fontWeight: FontWeight.w700, fontSize: 12)),
                const SizedBox(height: 2),
                Text(value, style: const TextStyle(color: _textMain, fontWeight: FontWeight.w900, fontSize: 16)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _LegendDot extends StatelessWidget {
  final Color color;
  final String label;
  const _LegendDot({required this.color, required this.label});

  static const Color _textMain = Color(0xFF0F172A);

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            label,
            style: const TextStyle(color: _textMain, fontWeight: FontWeight.w800),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

class _MiniProgress extends StatelessWidget {
  final double value;
  final String label;
  const _MiniProgress({required this.value, required this.label});

  static const Color _accent = Color(0xFF2563EB);

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: LinearProgressIndicator(
            value: value.clamp(0, 1),
            minHeight: 8,
            backgroundColor: const Color(0xFFEFF6FF),
            valueColor: const AlwaysStoppedAnimation(_accent),
            borderRadius: BorderRadius.circular(999),
          ),
        ),
        const SizedBox(width: 10),
        Text(label, style: const TextStyle(fontWeight: FontWeight.w900)),
      ],
    );
  }
}

class _WorkerPaymentTile extends StatelessWidget {
  final String nombre;
  final String rol;
  final bool pagado;
  final Function(bool) onToggle;

  const _WorkerPaymentTile({
    required this.nombre,
    required this.rol,
    required this.pagado,
    required this.onToggle,
  });

  static const Color _textMain = Color(0xFF0F172A);
  static const Color _textSecondary = Color(0xFF64748B);
  static const Color _ok = Color(0xFF10B981);
  static const Color _warn = Color(0xFFF59E0B);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 10, 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: pagado ? _ok.withOpacity(0.35) : const Color(0xFFE5E7EB)),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: pagado ? _ok.withOpacity(0.12) : _warn.withOpacity(0.12),
            child: Icon(pagado ? Icons.check : Icons.priority_high, color: pagado ? _ok : _warn, size: 16),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  nombre,
                  style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13, color: _textMain),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  rol,
                  style: const TextStyle(color: _textSecondary, fontWeight: FontWeight.w700, fontSize: 11),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          Switch.adaptive(
            value: pagado,
            activeColor: _ok,
            onChanged: onToggle,
          ),
        ],
      ),
    );
  }
}

class _ReportButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool loading;
  final VoidCallback? onTap;

  const _ReportButton({
    required this.label,
    required this.icon,
    required this.loading,
    required this.onTap,
  });

  static const Color _accent = Color(0xFF2563EB);

  @override
  Widget build(BuildContext context) {
    final disabled = onTap == null || loading;

    return ElevatedButton.icon(
      onPressed: disabled ? null : onTap,
      icon: loading
          ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
          : Icon(icon, size: 18),
      label: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
      style: ElevatedButton.styleFrom(
        backgroundColor: _accent,
        foregroundColor: Colors.white,
        disabledBackgroundColor: _accent.withOpacity(0.35),
        disabledForegroundColor: Colors.white,
        elevation: 0,
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    );
  }
}
