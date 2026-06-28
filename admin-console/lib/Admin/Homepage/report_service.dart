// report_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:pdf/pdf.dart';

class ReportService {
  static Future<void> generateSingleAssessmentPdf(
    String docId,
    Map<String, dynamic> data, {
    Map<String, String>? questionBank,
  }) async {
    final pdf = pw.Document();
    final name = data['farmer_name'] ?? 'Unknown';
    final email = data['farmer_email'] ?? '';
    final submittedAt = data['submitted_at'] as Timestamp?;
    final submittedText = submittedAt != null
        ? DateFormat.yMMMd().add_jm().format(submittedAt.toDate())
        : 'Not submitted';
    final answers = (data['answers'] ?? {}) as Map<String, dynamic>;

    // group by section
    final Map<String, Map<String, dynamic>> grouped = {};
    for (final e in answers.entries) {
      final k = e.key.toString();
      final section = k.isNotEmpty ? k[0].toUpperCase() : '?';
      grouped.putIfAbsent(section, () => {});
      grouped[section]![k] = e.value;
    }

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        build: (context) {
          final List<pw.Widget> widgets = [];

          widgets.add(
            pw.Header(
              level: 0,
              child: pw.Text(
                'MangoMind - Farmer Assessment',
                style: pw.TextStyle(fontSize: 20),
              ),
            ),
          );
          widgets.add(pw.SizedBox(height: 6));
          widgets.add(pw.Text('Name: $name'));
          widgets.add(pw.Text('Email: $email'));
          widgets.add(pw.Text('Submitted: $submittedText'));
          widgets.add(pw.SizedBox(height: 10));
          widgets.add(pw.Divider());
          widgets.add(pw.SizedBox(height: 8));

          final sortedSections = grouped.keys.toList()..sort();
          for (final s in sortedSections) {
            widgets.add(
              pw.Text(
                'Section $s',
                style: pw.TextStyle(
                  fontWeight: pw.FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            );
            widgets.add(pw.SizedBox(height: 6));
            final qmap = grouped[s]!;
            final sortedQ = qmap.keys.toList()..sort();
            for (final q in sortedQ) {
              final answer = qmap[q]?.toString() ?? '-';
              final qText = (questionBank != null && questionBank[q] != null)
                  ? questionBank[q]
                  : q;
              widgets.add(pw.SizedBox(height: 6));
              widgets.add(
                pw.Text(
                  qText!,
                  style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                ),
              );
              widgets.add(pw.SizedBox(height: 4));
              widgets.add(
                pw.Container(
                  padding: const pw.EdgeInsets.all(8),
                  decoration: pw.BoxDecoration(
                    border: pw.Border.all(color: PdfColors.grey300),
                    borderRadius: pw.BorderRadius.circular(6),
                  ),
                  child: pw.Text(answer),
                ),
              );
            }
            widgets.add(pw.SizedBox(height: 10));
          }

          widgets.add(pw.SizedBox(height: 12));
          widgets.add(
            pw.Text(
              'Generated: ${DateFormat.yMMMMd().add_jm().format(DateTime.now())}',
              style: pw.TextStyle(fontSize: 9, color: PdfColors.grey),
            ),
          );

          return widgets;
        },
      ),
    );

    final bytes = await pdf.save();
    await Printing.layoutPdf(onLayout: (format) async => bytes);
  }

  static Future<void> generateSummaryPdf({
    Map<String, String>? questionBank,
    String collectionName = 'assessments',
  }) async {
    final coll = FirebaseFirestore.instance.collection(collectionName);
    final snapshot = await coll.get();
    final docs = snapshot.docs;

    final pdf = pw.Document();

    // --- Cover / Title page ---
    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (context) {
          return pw.Container(
            padding: const pw.EdgeInsets.all(40),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.center,
              mainAxisAlignment: pw.MainAxisAlignment.center,
              children: [
                pw.Container(
                  width: 96,
                  height: 96,
                  decoration: pw.BoxDecoration(
                    color: PdfColors.green400,
                    borderRadius: pw.BorderRadius.circular(12),
                  ),
                  child: pw.Center(
                    child: pw.Text(
                      'SI',
                      style: pw.TextStyle(
                        color: PdfColors.white,
                        fontSize: 36,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                pw.SizedBox(height: 22),
                pw.Text(
                  'SWEET INSIGHTS',
                  style: pw.TextStyle(
                    fontSize: 22,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.SizedBox(height: 8),
                pw.Text(
                  'Assessments Summary',
                  style: pw.TextStyle(fontSize: 16, color: PdfColors.grey600),
                ),
                pw.SizedBox(height: 18),
                pw.Divider(),
                pw.SizedBox(height: 14),
                pw.Text(
                  'Total submissions: ${docs.length}',
                  style: pw.TextStyle(fontSize: 12),
                ),
                pw.SizedBox(height: 6),
                pw.Text(
                  'Generated: ${DateFormat.yMMMMd().add_jm().format(DateTime.now())}',
                  style: pw.TextStyle(fontSize: 10, color: PdfColors.grey),
                ),
              ],
            ),
          );
        },
      ),
    );

    if (docs.isEmpty) {
      // Simple "no data" page (we already added cover page)
      pdf.addPage(
        pw.Page(
          build: (context) =>
              pw.Center(child: pw.Text('No assessment data available.')),
        ),
      );
      final bytes = await pdf.save();
      await Printing.layoutPdf(onLayout: (format) async => bytes);
      return;
    }

    // --- Aggregate frequencies across all docs ---
    final Map<String, Map<String, int>> freq = {};
    for (final d in docs) {
      final ans = (d.data()['answers'] ?? {}) as Map<String, dynamic>;
      for (final e in ans.entries) {
        final q = e.key.toString();
        final val = (e.value ?? '').toString();
        freq.putIfAbsent(q, () => {});
        freq[q]![val] = (freq[q]![val] ?? 0) + 1;
      }
    }

    final sortedQuestions = freq.keys.toList()..sort();

    // --- Content pages: for each question show options, counts, percent, and bar ---
    const double barMaxWidth = 140.0; // bar width in PDF units
    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.symmetric(horizontal: 28, vertical: 24),
        build: (context) {
          final List<pw.Widget> widgets = [];

          widgets.add(
            pw.Header(
              level: 0,
              child: pw.Text(
                'Detailed Summary',
                style: pw.TextStyle(
                  fontSize: 18,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
            ),
          );
          widgets.add(pw.SizedBox(height: 8));
          widgets.add(
            pw.Text(
              'Total submissions: ${docs.length}',
              style: pw.TextStyle(fontSize: 11),
            ),
          );
          widgets.add(pw.SizedBox(height: 12));

          for (final q in sortedQuestions) {
            final map = freq[q]!;
            final total = map.values.fold<int>(0, (p, n) => p + n);
            final qText = (questionBank != null && questionBank.containsKey(q))
                ? questionBank[q]!
                : q;

            widgets.add(pw.SizedBox(height: 8));
            widgets.add(
              pw.Text(
                qText,
                style: pw.TextStyle(
                  fontSize: 12,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
            );
            widgets.add(pw.SizedBox(height: 6));

            // Option rows
            // Sort entries by count descending for nicer display
            final entries = map.entries.toList()
              ..sort((a, b) => b.value.compareTo(a.value));

            for (final e in entries) {
              final count = e.value;
              final percent = total > 0 ? (100 * count / total) : 0.0;
              final barWidth = (percent / 100) * barMaxWidth;

              widgets.add(
                pw.Container(
                  margin: const pw.EdgeInsets.only(bottom: 6),
                  child: pw.Row(
                    crossAxisAlignment: pw.CrossAxisAlignment.center,
                    children: [
                      // Option text (left)
                      pw.Expanded(
                        flex: 6,
                        child: pw.Text(
                          e.key,
                          style: pw.TextStyle(fontSize: 10),
                        ),
                      ),

                      // Count (middle)
                      pw.Expanded(
                        flex: 1,
                        child: pw.Text(
                          count.toString(),
                          textAlign: pw.TextAlign.right,
                          style: pw.TextStyle(fontSize: 10),
                        ),
                      ),

                      pw.SizedBox(width: 8),

                      // Percent text
                      pw.Container(
                        width: 60,
                        child: pw.Text(
                          '${percent.toStringAsFixed(1)}%',
                          textAlign: pw.TextAlign.right,
                          style: pw.TextStyle(fontSize: 10),
                        ),
                      ),

                      pw.SizedBox(width: 8),

                      // Bar visualization
                      pw.Container(
                        width: barMaxWidth,
                        height: 8,
                        decoration: pw.BoxDecoration(
                          border: pw.Border.all(color: PdfColors.grey300),
                          borderRadius: pw.BorderRadius.circular(6),
                        ),
                        child: pw.Stack(
                          children: [
                            // background empty
                            pw.Positioned(
                              left: 0,
                              top: 0,
                              bottom: 0,
                              child: pw.Container(
                                width: barMaxWidth,
                                height: 8,
                                color: PdfColors.white,
                              ),
                            ),
                            // filled bar
                            if (barWidth > 0)
                              pw.Positioned(
                                left: 0,
                                top: 0,
                                bottom: 0,
                                child: pw.Container(
                                  width: barWidth,
                                  height: 8,
                                  decoration: pw.BoxDecoration(
                                    color: PdfColors.green300,
                                    borderRadius: pw.BorderRadius.circular(6),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }

            widgets.add(pw.Divider());
          }

          widgets.add(pw.SizedBox(height: 12));
          widgets.add(
            pw.Align(
              alignment: pw.Alignment.centerRight,
              child: pw.Text(
                'Generated: ${DateFormat.yMMMMd().add_jm().format(DateTime.now())}',
                style: pw.TextStyle(fontSize: 9, color: PdfColors.grey),
              ),
            ),
          );

          return widgets;
        },
      ),
    );

    final bytes = await pdf.save();
    await Printing.layoutPdf(onLayout: (format) async => bytes);
  }
}
