import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'dart:io' show File, Platform;
import 'package:flutter/services.dart' show Uint8List, rootBundle;
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:media_store_plus/media_store_plus.dart';
import 'package:flutter_file_dialog/flutter_file_dialog.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'package:printing/printing.dart';

class ReportsPage extends StatefulWidget {
  final String? farmId;
  final String? logoAssetPath;
  const ReportsPage({
    super.key,
    this.farmId,
    this.logoAssetPath = 'assets/logo.png',
  });

  @override
  State<ReportsPage> createState() => _ReportsPageState();
}

enum RangePreset { last7, thisMonth, custom }

class _ReportsPageState extends State<ReportsPage> {
  List<_Farm> _farms = [];
  bool _loadingFarms = true;
  int reloads = 0;
  String? _farmId;

  RangePreset _preset = RangePreset.last7;
  DateTimeRange? _customRange;

  bool _loadingData = false;

  // Raw rows
  List<Map<String, dynamic>> _yields = [];
  List<Map<String, dynamic>> _irrigs = [];
  List<Map<String, dynamic>> _obs = [];

  // Summaries
  num _totalKg = 0;
  int _irrigCount = 0;
  num _irrigLiters = 0;
  int _obsCount = 0;

  final _fmt = DateFormat('yyyy-MM-dd');

  @override
  void initState() {
    super.initState();
    _initFarms();
  }

  // Classify Firestore/Network errors into human messages
  String _niceError(Object e) {
    final s = e.toString();
    if (s.contains('permission-denied')) {
      return 'Permission denied when reading Firestore.\nCheck your security rules for this user/farm.';
    }
    if (s.contains('FAILED_PRECONDITION') && s.contains('index')) {
      return 'Firestore requires an index for this query.\nOpen the Firebase console → Firestore Indexes and add the suggested index.';
    }
    if (s.contains('network') ||
        s.contains('grpc') ||
        s.contains('UNAVAILABLE')) {
      return 'Network issue while contacting Firestore.\nCheck internet connection.';
    }
    if (s.contains('deadline-exceeded') || s.contains('timeout')) {
      return 'The query timed out.\nServer might be slow or offline. Try again.';
    }
    return 'Load failed: $e';
  }

  Future<String?> _previewAndDownload() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) {
          return Scaffold(
            appBar: AppBar(title: const Text('Preview PDF')),
            body: PdfPreview(
              build: (format) => _buildPdf(),
              allowSharing: false,
              allowPrinting: false,
              canChangePageFormat: false,
              canChangeOrientation: false,
              canDebug: false,
              actions: [
                PdfPreviewAction(
                  icon: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: const [
                      Icon(Icons.download),
                      SizedBox(width: 6),
                      Text(
                        "Download PDF",
                        style: TextStyle(fontSize: 16, color: Colors.white),
                      ),
                    ],
                  ),
                  onPressed: (context, build, pageFormat) async {
                    try {
                      final bytes = await _buildPdf();
                      final fileName =
                          'FarmReport_${DateFormat('yyyyMMdd_HHmm').format(DateTime.now())}.pdf';

                      final tmpDir = await getTemporaryDirectory();
                      final tmpPath = '${tmpDir.path}/$fileName';
                      final tmpFile = File(tmpPath);
                      await tmpFile.writeAsBytes(bytes, flush: true);

                      if (Platform.isAndroid) {
                        final ms = MediaStore();
                        await ms.saveFile(
                          tempFilePath: tmpPath,
                          dirType: DirType.download,
                          dirName: DirName.download,
                          relativePath: 'FarmReports',
                        );

                        if (await tmpFile.exists()) {
                          await tmpFile.delete();
                        }
                      }

                      await FlutterFileDialog.saveFile(
                        params: SaveFileDialogParams(
                          data: bytes,
                          fileName: fileName,
                        ),
                      );

                      if (mounted) {
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Saved: $fileName')),
                        );
                      }
                    } catch (e) {
                      throw Error();
                    }
                  },
                ),
              ],
            ),
          );
        },
      ),
    );
    return null;
  }

  // 10s timeout wrapper so we never spin forever
  Future<T> _withTimeout<T>(
    Future<T> fut, {
    Duration d = const Duration(seconds: 10),
  }) {
    return fut.timeout(d);
  }

  // Validate the selected farm before querying
  bool get _hasFarm => _farmId != null && _farmId!.isNotEmpty;

  Future<void> _initFarms() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      setState(() {
        _loadingFarms = false;
        _farmId = null;
      });
      _showSnack('You are not logged in.');
      return;
    }

    try {
      // get farms owned by user
      final q = await FirebaseFirestore.instance
          .collection('farms')
          .where('ownerUid', isEqualTo: uid)
          .get();

      final items = q.docs.map((d) {
        final data = d.data();
        final name = (data['name'] ?? data['farmName'] ?? 'Untitled Farm')
            .toString();
        return _Farm(d.id, name);
      }).toList();

      // sort by name for a nicer list (optional)
      items.sort(
        (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
      );

      String? selected;
      if (widget.farmId != null && widget.farmId!.isNotEmpty) {
        selected = items.any((f) => f.id == widget.farmId)
            ? widget.farmId
            : null;
      }
      selected ??= items.isNotEmpty ? items.first.id : null;

      setState(() {
        _farms = items;
        _farmId = selected;
        _loadingFarms = false;
      });

      if (_farmId != null) {
        _loadData();
      }
    } catch (e) {
      setState(() {
        _farms = [];
        _farmId = null;
        _loadingFarms = false;
      });
      _showSnack('Failed to load farms: $e');
    }
  }

  DateTimeRange _currentRange() {
    final now = DateTime.now();
    if (_preset == RangePreset.last7) {
      final start = DateTime(
        now.year,
        now.month,
        now.day,
      ).subtract(const Duration(days: 6));
      final end = DateTime(now.year, now.month, now.day, 23, 59, 59);
      return DateTimeRange(start: start, end: end);
    }
    if (_preset == RangePreset.thisMonth) {
      final start = DateTime(now.year, now.month, 1);
      final end = DateTime(now.year, now.month + 1, 0, 23, 59, 59);
      return DateTimeRange(start: start, end: end);
    }
    return _customRange ??
        DateTimeRange(
          start: DateTime(now.year, now.month, now.day),
          end: DateTime(now.year, now.month, now.day, 23, 59, 59),
        );
  }

  Future<void> _pickCustomRange() async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 5),
      lastDate: DateTime(now.year + 1),
      initialDateRange: _customRange ?? _currentRange(),
    );
    if (picked != null) {
      setState(() {
        _preset = RangePreset.custom;
        _customRange = DateTimeRange(
          start: DateTime(
            picked.start.year,
            picked.start.month,
            picked.start.day,
          ),
          end: DateTime(
            picked.end.year,
            picked.end.month,
            picked.end.day,
            23,
            59,
            59,
          ),
        );
      });
      _loadData();
    }
  }

  Future<void> _loadData() async {
    // If there’s no selected farm, clear state and exit early.
    if (!_hasFarm || _farmId == null) {
      setState(() {
        _yields = [];
        _irrigs = [];
        _obs = [];
        _totalKg = 0;
        _irrigCount = 0;
        _irrigLiters = 0;
        _obsCount = 0;
        _loadingData = false;
      });
      return;
    }

    // Optional: track reload attempts
    reloads++;
    setState(() => _loadingData = true);

    // Date range (assumes _currentRange() returns DateTimeRange)
    final range = _currentRange();

    DateTime _startOfDay(DateTime d) => DateTime(d.year, d.month, d.day);
    DateTime _nextDay(DateTime d) =>
        DateTime(d.year, d.month, d.day).add(const Duration(days: 1));

    final start = _startOfDay(range.start);
    final endExclusive = _nextDay(range.end);

    // Farm doc ref
    final farmRef = FirebaseFirestore.instance.collection('farms').doc(_farmId);

    try {
      // Build queries for farm subcollections
      final yieldsQ = farmRef
          .collection('yields')
          .where(
            'date',
            isGreaterThanOrEqualTo: Timestamp.fromDate(range.start),
          )
          .where('date', isLessThanOrEqualTo: Timestamp.fromDate(range.end))
          .orderBy('date', descending: true);

      final irrigsQ = farmRef
          .collection('irrigations')
          .where(
            'date',
            isGreaterThanOrEqualTo: Timestamp.fromDate(range.start),
          )
          .where('date', isLessThanOrEqualTo: Timestamp.fromDate(range.end))
          .orderBy('date', descending: true);

      final obsQ = farmRef
          .collection('observations')
          .where(
            'observedAt',
            isGreaterThanOrEqualTo: Timestamp.fromDate(start),
          )
          .where('observedAt', isLessThan: Timestamp.fromDate(endExclusive))
          .orderBy('observedAt', descending: true);

      // Run all three in parallel (with your timeout wrapper)
      final results = await Future.wait([
        _withTimeout(yieldsQ.get()),
        _withTimeout(irrigsQ.get()),
        _withTimeout(obsQ.get()),
      ]);

      // Extract docs
      final yDocs = results[0].docs;
      final rDocs = results[1].docs;
      final oDocs = results[2].docs;

      final yields = yDocs.map((d) => {'id': d.id, ...d.data()}).toList();
      final irrigs = rDocs.map((d) => {'id': d.id, ...d.data()}).toList();
      final obs = oDocs.map((d) {
        final data = d.data();
        return {
          'id': d.id,
          ...data,
          'date': data['observedAt'],
          'category': data['category'] ?? data['type'],
        };
      }).toList();

      num sumKg = 0;
      for (final m in yields) {
        sumKg += _num(m['weightKg']);
      }

      num sumLiters = 0;
      for (final m in irrigs) {
        sumLiters += _num(m['waterLiters']);
      }

      if (!mounted) return;

      setState(() {
        _yields = yields;
        _irrigs = irrigs;
        _obs = obs;

        _totalKg = sumKg;
        _irrigCount = irrigs.length;
        _irrigLiters = sumLiters;
        _obsCount = obs.length;
      });

      if (yields.isEmpty && irrigs.isEmpty && obs.isEmpty && reloads >= 2) {
        _showSnack(
          'No records found between ${_fmt.format(range.start)} → ${_fmt.format(range.end)}.',
        );
      }
    } catch (e) {
      _showSnack(_niceError(e));
    } finally {
      if (mounted) setState(() => _loadingData = false);
    }
  }

  String _farmNameById(String? id) {
    final f = _farms.firstWhere(
      (x) => x.id == id,
      orElse: () => _Farm(id ?? '—', '—'),
    );
    return f.name;
  }

  num _num(dynamic v) {
    if (v is num) return v;
    return 0;
  }

  DateTime? _date(dynamic v) {
    if (v is Timestamp) return v.toDate();
    if (v is DateTime) return v;
    return null;
  }

  // --------------------- PDF (with logo) ---------------------
  Future<pw.MemoryImage?> _loadLogo() async {
    final p = widget.logoAssetPath;
    if (p == null || p.isEmpty) return null;
    try {
      final data = await rootBundle.load(p);
      return pw.MemoryImage(data.buffer.asUint8List());
    } catch (_) {
      return null;
    }
  }

  Future<Uint8List> _buildPdf() async {
    final range = _currentRange();
    final doc = pw.Document();
    final logo = await _loadLogo();

    pw.Table _table(List<String> headers, List<List<String>> rows) {
      return pw.TableHelper.fromTextArray(
        headers: headers,
        data: rows,
        headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
        headerDecoration: const pw.BoxDecoration(color: PdfColors.grey300),
        cellAlignment: pw.Alignment.center,
        cellPadding: const pw.EdgeInsets.symmetric(vertical: 4, horizontal: 6),
        border: null,
      );
    }

    final yRows = _yields
        .map(
          (y) => [
            _fmt.format(_date(y['date']) ?? DateTime(1970)),
            _num(y['weightKg']).toString(),
            (y['type'] ?? '').toString(),
            (y['notes'] ?? 'None').toString(),
          ],
        )
        .toList();

    final rRows = _irrigs
        .map(
          (r) => [
            _fmt.format(_date(r['date']) ?? DateTime(1970)),
            (r['method'] ?? '').toString(),
            _num(r['waterLiters']).toString(),
            (r['notes'] ?? 'None').toString(),
          ],
        )
        .toList();

    final oRows = _obs
        .map(
          (o) => [
            _fmt.format(_date(o['date']) ?? DateTime(1970)),
            (o['category'] ?? '').toString(),
            (o['severity'] ?? '').toString(),
            (o['note'] ?? o['notes'] ?? 'None').toString(),
          ],
        )
        .toList();

    doc.addPage(
      pw.MultiPage(
        pageTheme: const pw.PageTheme(margin: pw.EdgeInsets.all(24)),
        header: (ctx) => pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.center,
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            if (logo != null) pw.Image(logo, width: 56, height: 56),
            pw.Spacer(),
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.end,
              children: [
                pw.Text(
                  'Farm Report',
                  style: pw.TextStyle(
                    fontSize: 18,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.Text('Farm: ${_farmNameById(_farmId)}'),
                pw.Text('Farm ID: ${_farmId ?? "—"}'),
                pw.Text(
                  'Range: ${_fmt.format(range.start)} - ${_fmt.format(range.end)}',
                ),
              ],
            ),
          ],
        ),
        build: (ctx) => [
          pw.SizedBox(height: 8),
          pw.Container(
            padding: const pw.EdgeInsets.all(10),
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: PdfColors.grey400),
              borderRadius: pw.BorderRadius.circular(6),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  'Summary',
                  style: pw.TextStyle(
                    fontSize: 14,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.SizedBox(height: 6),
                _kv('Total Yield (kg)', '$_totalKg'),
                _kv('Irrigations (count)', '$_irrigCount'),
                _kv('Irrigation Liters (sum)', '$_irrigLiters'),
                _kv('Observations (count)', '$_obsCount'),
              ],
            ),
          ),
          pw.SizedBox(height: 14),
          pw.Text(
            'Yields',
            style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
          ),
          _table(['Date', 'Kg', 'Variety', 'Notes'], yRows),
          pw.SizedBox(height: 10),
          pw.Text(
            'Irrigations',
            style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
          ),
          _table(['Date', 'Method', 'Liters', 'Notes'], rRows),
          pw.SizedBox(height: 10),
          pw.Text(
            'Observations',
            style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
          ),
          _table(['Date', 'Category', 'Severity', 'Note'], oRows),
        ],
        footer: (ctx) => pw.Align(
          alignment: pw.Alignment.centerRight,
          child: pw.Text(
            'Generated: ${DateFormat('yyyy-MM-dd HH:mm').format(DateTime.now())}',
            style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700),
          ),
        ),
      ),
    );

    return doc.save();
  }

  pw.Widget _kv(String k, String v) => pw.Row(
    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
    children: [
      pw.Text(k, style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
      pw.Text(v),
    ],
  );

  // --------------------- UI ---------------------
  @override
  Widget build(BuildContext context) {
    final range = _currentRange();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Reports'),
        actions: [
          IconButton(
            tooltip: 'Preview & Download PDF',
            onPressed: (_farmId != null && !_loadingData)
                ? () async {
                    try {
                      await _previewAndDownload();
                    } catch (e) {
                      if (!mounted) return;
                      _showSnack('Failed to save PDF: $e');
                    }
                  }
                : null,
            icon: const Icon(Icons.picture_as_pdf),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _initFarms,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _farmPicker(),
            if (_loadingFarms) ...[
              const ListTile(
                leading: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                title: Text('Loading farms…'),
              ),
              const SizedBox(height: 12),
            ],
            const SizedBox(height: 12),
            _rangeChips(range),
            const SizedBox(height: 12),
            _summaryCards(),
            const SizedBox(height: 16),
            _section(
              title: 'Yields (${_yields.length})',
              child: _simpleList(
                _yields,
                (m) => [
                  _fmt.format(_date(m['date']) ?? DateTime(1970)),
                  '${_num(m["weightKg"])} kg',
                  (m['type'] ?? '').toString(),
                ],
              ),
            ),
            const SizedBox(height: 12),
            _section(
              title: 'Irrigations (${_irrigs.length})',
              child: _simpleList(
                _irrigs,
                (m) => [
                  _fmt.format(_date(m['date']) ?? DateTime(1970)),
                  (m['method'] ?? '').toString(),
                  _num(m['waterLiters']) > 0
                      ? '${_num(m["waterLiters"])} L'
                      : '',
                ],
              ),
            ),
            const SizedBox(height: 12),
            _section(
              title: 'Observations (${_obs.length})',
              child: _simpleList(
                _obs,
                (m) => [
                  _fmt.format(_date(m['date']) ?? DateTime(1970)),
                  (m['category'] ?? '').toString(),
                  (m['severity'] ?? '').toString(),
                ],
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _farmPicker() {
    if (_loadingFarms) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Row(
            children: [
              SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              SizedBox(width: 12),
              Text('Loading farms...'),
            ],
          ),
        ),
      );
    }

    if (_farms.isEmpty) {
      return Card(
        child: ListTile(
          leading: const Icon(Icons.agriculture),
          title: const Text('No farms found'),
          subtitle: const Text('Add a farm first, then come back here.'),
        ),
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: DropdownButtonFormField<String>(
          value: _farmId,
          decoration: const InputDecoration(
            labelText: 'Choose farm',
            prefixIcon: Icon(Icons.agriculture),
            border: OutlineInputBorder(),
          ),
          isExpanded: true,
          items: _farms
              .map((f) => DropdownMenuItem(value: f.id, child: Text(f.name)))
              .toList(),
          onChanged: (val) async {
            if (val == null) return;
            setState(() {
              _farmId = val;
            });
            await _loadData(); // reload data for the selected farm
          },
        ),
      ),
    );
  }

  Widget _rangeChips(DateTimeRange range) {
    String label(RangePreset p) {
      switch (p) {
        case RangePreset.last7:
          return 'Last 7 days';
        case RangePreset.thisMonth:
          return 'This month';
        case RangePreset.custom:
          return 'Custom';
      }
    }

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        ChoiceChip(
          label: Text(label(RangePreset.last7)),
          selected: _preset == RangePreset.last7,
          onSelected: (v) {
            setState(() => _preset = RangePreset.last7);
            _loadData();
          },
        ),
        ChoiceChip(
          label: Text(label(RangePreset.thisMonth)),
          selected: _preset == RangePreset.thisMonth,
          onSelected: (v) {
            setState(() => _preset = RangePreset.thisMonth);
            _loadData();
          },
        ),
        ActionChip(
          label: Text(
            _preset == RangePreset.custom
                ? 'Custom: ${_fmt.format(range.start)} → ${_fmt.format(range.end)}'
                : 'Pick custom range',
          ),
          onPressed: _pickCustomRange,
        ),
      ],
    );
  }

  Widget _summaryCards() {
    return Column(
      children: [
        _metricCard('Total Yield', '$_totalKg kg', Icons.scale),

        const SizedBox(width: 8),

        _metricCard(
          'Irrigations',
          '$_irrigCount (${_irrigLiters > 0 ? "${_irrigLiters} L" : "count"})',
          Icons.opacity,
        ),

        const SizedBox(width: 8),

        _metricCard('Observations', '$_obsCount', Icons.remove_red_eye),
      ],
    );
  }

  Widget _metricCard(String title, String value, IconData icon) {
    return Card(
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            CircleAvatar(radius: 18, child: Icon(icon, size: 18)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 2),
                  Text(value, style: const TextStyle(fontSize: 16)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _section({
  required String title,
  required Widget child,
}) {
  return _ExpandableCard(
    title: title,
    child: child,
  );
}


  Widget _simpleList(
    List<Map<String, dynamic>> rows,
    List<String> Function(Map<String, dynamic>) toCells,
  ) {
    if (_loadingData) {
      return const Padding(
        padding: EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 12),
            Text('Fetching records…'),
          ],
        ),
      );
    }

    if (rows.isEmpty) return _empty('No records in this range.');
    final tiles = rows.map((m) => toCells(m)).toList();
    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: tiles.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (_, i) {
        final cells = tiles[i];
        return ListTile(
          dense: true,
          leading: const Icon(Icons.event_note),
          title: Text(cells.first),
          subtitle: cells.length > 1
              ? Text(cells.skip(1).where((e) => e.isNotEmpty).join(' • '))
              : null,
        );
      },
    );
  }

  Widget _empty(String msg) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Center(
        child: Text(msg, style: const TextStyle(color: Colors.black54)),
      ),
    );
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }
}

class _Farm {
  final String id;
  final String name;
  _Farm(this.id, this.name);
}

class _ExpandableCard extends StatefulWidget {
  final String title;
  final Widget child;

  const _ExpandableCard({
    super.key,
    required this.title,
    required this.child,
  });

  @override
  State<_ExpandableCard> createState() => _ExpandableCardState();
}

class _ExpandableCardState extends State<_ExpandableCard>
    with SingleTickerProviderStateMixin {
  bool _expanded = true;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          // ---------------- HEADER ----------------
          InkWell(
            onTap: () => setState(() => _expanded = !_expanded),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                children: [
                  Text(
                    widget.title,
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Spacer(),
                  AnimatedRotation(
                    turns: _expanded ? 0.5 : 0,
                    duration: const Duration(milliseconds: 200),
                    child: const Icon(Icons.keyboard_arrow_down, size: 28),
                  ),
                ],
              ),
            ),
          ),

          // ---------------- EXPANDED CONTENT ----------------
          AnimatedCrossFade(
            firstChild: const SizedBox(), // Closed
            secondChild: Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              child: Column(
                children: [
                  widget.child,
                  const SizedBox(height: 15),

                  // ---------------- BOTTOM CLOSE BUTTON ----------------
                  TextButton.icon(
                    onPressed: () => setState(() => _expanded = false),
                    icon: const Icon(Icons.keyboard_arrow_up),
                    label: const Text(
                      "Collapse",
                      style: TextStyle(fontSize: 14),
                    ),
                  ),
                ],
              ),
            ),
            crossFadeState: _expanded
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 200),
          ),
        ],
      ),
    );
  }
}

