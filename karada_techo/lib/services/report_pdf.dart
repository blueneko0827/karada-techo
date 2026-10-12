import 'dart:typed_data';

import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../domain/chart_math.dart';
import '../domain/format.dart';
import '../domain/records.dart';
import '../models/entry.dart';
import '../models/metric.dart';
import '../models/settings.dart';
import 'svg_charts.dart';

/// Thrown when assets/fonts/NotoSansJP-Regular.ttf has not been added.
class ReportFontMissing implements Exception {
  const ReportFontMissing();
}

const String reportFontAsset = 'assets/fonts/NotoSansJP-Regular.ttf';

Future<Uint8List> buildReportPdf({
  required List<Entry> entries,
  required AppSettings settings,
  required int days,
}) async {
  final pw.Font font;
  try {
    font = pw.Font.ttf(await rootBundle.load(reportFontAsset));
  } catch (_) {
    throw const ReportFontMissing();
  }

  final data = buildReportData(entries, days);
  final now = DateTime.now();
  final ink = PdfColor.fromHex('#13201A');
  final muted = PdfColor.fromHex('#6A7C72');
  final line = PdfColor.fromHex('#D1DCD5');
  final band = PdfColor.fromHex('#E6EDE8');

  final bpMorning = ofType(entries, MetricType.bp, from: data.from)
      .where((e) => slotOf(e.at) == BpSlot.morning)
      .toList();
  final weights = ofType(entries, MetricType.weight, from: data.from);
  final groups = groupsOf(bpMorning, MetricType.bp);
  final total = groups.fold<int>(0, (s, g) => s + g.n);

  pw.TextStyle st(double size, [PdfColor? color]) => pw.TextStyle(fontSize: size, color: color ?? ink);
  pw.Widget heading(String t) => pw.Padding(
        padding: const pw.EdgeInsets.only(top: 16, bottom: 6),
        child: pw.Text(t, style: st(11.5)),
      );

  final doc = pw.Document(
    theme: pw.ThemeData.withFont(base: font, bold: font),
    title: '健康記録レポート',
    author: 'からだ手帖',
  );

  doc.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.fromLTRB(40, 40, 40, 40),
      build: (context) => [
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.center,
          children: [
            pw.SvgImage(svg: logoSvg(), width: 30, height: 30),
            pw.SizedBox(width: 10),
            pw.Expanded(child: pw.Text('健康記録レポート', style: st(20))),
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.end,
              children: [
                pw.Text(settings.profile.name.isEmpty ? '氏名：' : '${settings.profile.name} 様', style: st(10)),
                pw.Text('作成日 ${fmtYMD(now)}', style: st(9, muted)),
              ],
            ),
          ],
        ),
        pw.Divider(color: ink, thickness: 1.5),
        pw.Text('対象期間：${fmtYMD(data.from)} 〜 ${fmtYMD(now)}（$days日間）・家庭で測定した値', style: st(9.5, muted)),
        pw.SizedBox(height: 10),
        if (data.rows.isEmpty)
          pw.Text('この期間の記録はありません。', style: st(10, muted))
        else
          pw.TableHelper.fromTextArray(
            headers: ['項目', '平均', '最高', '最低', '回数'],
            data: [
              for (final r in data.rows) ['${r.label}（${r.unit}）', r.avg, r.max, r.min, '${r.n}'],
            ],
            headerStyle: st(9, muted),
            cellStyle: st(10),
            headerDecoration: pw.BoxDecoration(color: band),
            cellAlignments: const {
              0: pw.Alignment.centerLeft,
              1: pw.Alignment.centerRight,
              2: pw.Alignment.centerRight,
              3: pw.Alignment.centerRight,
              4: pw.Alignment.centerRight,
            },
            headerAlignments: const {
              0: pw.Alignment.centerLeft,
              1: pw.Alignment.centerRight,
              2: pw.Alignment.centerRight,
              3: pw.Alignment.centerRight,
              4: pw.Alignment.centerRight,
            },
            border: pw.TableBorder(
              horizontalInside: pw.BorderSide(color: line, width: 0.5),
              bottom: pw.BorderSide(color: line, width: 0.5),
            ),
            cellPadding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 5),
          ),
        if (data.changes.isNotEmpty) pw.SizedBox(height: 8),
        for (final c in data.changes) pw.Text(c, style: st(9.5, muted)),
        if (total > 0) ...[
          heading('朝の血圧の分類（家庭血圧・${bpMorning.length}回）'),
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.center,
            children: [
              pw.SvgImage(svg: pieSvg(groups, 120), width: 110, height: 110),
              pw.SizedBox(width: 20),
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    for (final g in groups)
                      pw.Padding(
                        padding: const pw.EdgeInsets.symmetric(vertical: 3),
                        child: pw.Row(children: [
                          pw.Container(width: 9, height: 9, color: PdfColor.fromHex(pdfPieColors[g.level]!)),
                          pw.SizedBox(width: 8),
                          pw.Expanded(child: pw.Text(g.label, style: st(10))),
                          pw.SizedBox(width: 40, child: pw.Text('${g.n}回', style: st(9.5, muted), textAlign: pw.TextAlign.right)),
                          pw.SizedBox(width: 44, child: pw.Text('${(g.n / total * 100).round()}%', style: st(10.5), textAlign: pw.TextAlign.right)),
                        ]),
                      ),
                    pw.SizedBox(height: 4),
                    pw.Text('日本高血圧学会の家庭血圧の分類による内訳', style: st(8.5, muted)),
                  ],
                ),
              ),
            ],
          ),
        ],
        if (bpMorning.length >= 2) ...[
          heading('朝の血圧の推移（点線は家庭血圧の目安 135/85）'),
          pw.SvgImage(
            svg: lineSvg(
              series: [
                SvgSeries('#B8323F', [for (final e in bpMorning) ChartPoint(e.at, (e.sys ?? 0).toDouble())]),
                SvgSeries('#C4747C', [for (final e in bpMorning) ChartPoint(e.at, (e.dia ?? 0).toDouble())]),
              ],
              refs: const [SvgRef(135, '135'), SvgRef(85, '85')],
              x0: data.from,
              x1: now,
            ),
          ),
        ],
        if (weights.length >= 2) ...[
          heading('体重の推移'),
          pw.SvgImage(
            svg: lineSvg(
              series: [
                SvgSeries('#1F4E8C', [for (final e in weights) ChartPoint(e.at, e.value ?? 0)]),
              ],
              x0: data.from,
              x1: now,
              h: 140,
            ),
          ),
        ],
        heading('医師に伝えたいこと'),
        pw.Container(
          width: double.infinity,
          padding: const pw.EdgeInsets.all(8),
          decoration: pw.BoxDecoration(border: pw.Border.all(color: line, width: 0.8)),
          child: pw.Text(settings.reportNote.trim().isEmpty ? '（記入なし）' : settings.reportNote.trim(), style: st(10)),
        ),
        pw.SizedBox(height: 14),
        pw.Text(
          '血圧（最高・最低）は収縮期／拡張期の値です。本レポートは利用者が自宅で測定・記録した値をまとめたもので、'
          '診断を目的としたものではありません。',
          style: st(8.5, muted),
        ),
      ],
    ),
  );
  return doc.save();
}
