import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:printing/printing.dart';

import '../domain/chart_math.dart';
import '../domain/format.dart';
import '../domain/records.dart';
import '../models/metric.dart';
import '../services/report_pdf.dart';
import '../state/providers.dart';
import '../theme/palette.dart';
import '../widgets/charts.dart';
import '../widgets/common.dart';
import '../widgets/logo.dart';

class ReportScreen extends ConsumerStatefulWidget {
  const ReportScreen({super.key});

  @override
  ConsumerState<ReportScreen> createState() => _ReportScreenState();
}

class _ReportScreenState extends ConsumerState<ReportScreen> {
  int _days = 30;
  bool _busy = false;
  late final TextEditingController _note;
  late final AppController _ctrl;
  Timer? _noteTimer;

  @override
  void initState() {
    super.initState();
    _ctrl = ref.read(appProvider.notifier);
    _note = TextEditingController(text: ref.read(appProvider).settings.reportNote);
  }

  @override
  void dispose() {
    if (_noteTimer?.isActive ?? false) {
      _noteTimer!.cancel();
      // Providers can't change while the tree is being torn down; save right after.
      final text = _note.text;
      Future.microtask(() => _ctrl.setReportNote(text));
    }
    _note.dispose();
    super.dispose();
  }

  /// Saves the doctor note half a second after typing stops.
  void _onNoteChanged(String v) {
    _noteTimer?.cancel();
    _noteTimer = Timer(const Duration(milliseconds: 500), () => _ctrl.setReportNote(v));
  }

  Future<void> _makePdf({required bool share}) async {
    if (_noteTimer?.isActive ?? false) {
      _noteTimer!.cancel();
      await _ctrl.setReportNote(_note.text);
      if (!mounted) return;
    }
    final st = ref.read(appProvider);
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _busy = true);
    try {
      final bytes = await buildReportPdf(entries: st.entries, settings: st.settings, days: _days);
      final name = 'karada-techo-report-${dayKey(DateTime.now())}.pdf';
      if (share) {
        await Printing.sharePdf(bytes: bytes, filename: name);
      } else {
        await Printing.layoutPdf(onLayout: (_) async => bytes, name: name);
      }
    } on ReportFontMissing {
      messenger.showSnackBar(const SnackBar(
        content: Text('PDF用の日本語フォントが見つかりません。assets/fonts/NotoSansJP-Regular.ttf を追加してください。'),
      ));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('PDFを作成できませんでした：$e')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _copyText() async {
    if (_noteTimer?.isActive ?? false) {
      _noteTimer!.cancel();
      await _ctrl.setReportNote(_note.text);
      if (!mounted) return;
    }
    final st = ref.read(appProvider);
    final messenger = ScaffoldMessenger.of(context);
    await Clipboard.setData(ClipboardData(text: reportText(st.entries, st.settings, _days)));
    messenger.showSnackBar(const SnackBar(content: Text('レポートの要約をコピーしました'), behavior: SnackBarBehavior.floating));
  }

  @override
  Widget build(BuildContext context) {
    final st = ref.watch(appProvider);
    final pal = context.pal;
    final data = buildReportData(st.entries, _days);
    final now = DateTime.now();
    final bpMorning = ofType(st.entries, MetricType.bp, from: data.from)
        .where((e) => slotOf(e.at) == BpSlot.morning)
        .toList();
    final weights = ofType(st.entries, MetricType.weight, from: data.from);
    final diaColor = Color.lerp(pal.mBp, pal.ink3, 0.45)!;
    final head = TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: pal.ink);
    final cell = numStyle(14, pal.ink, weight: FontWeight.w500);

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 28),
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(child: Text('受診用レポート', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: pal.ink))),
            Text('医師や看護師に見せる用', style: TextStyle(fontSize: 12.5, color: pal.ink3)),
          ],
        ),
        const SizedBox(height: 10),
        Seg<int>(
          value: _days,
          options: const [(14, '2週間'), (30, '1か月'), (90, '3か月')],
          onChanged: (v) => setState(() => _days = v),
        ),
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.fromLTRB(18, 20, 18, 18),
          decoration: BoxDecoration(
            color: pal.surface,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: pal.line),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const AppLogo(size: 32),
                  const SizedBox(width: 9),
                  Expanded(child: Text('健康記録レポート', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: pal.ink))),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(st.settings.profile.name.isEmpty ? '氏名：未設定' : '${st.settings.profile.name} 様',
                          style: TextStyle(fontSize: 12, color: pal.ink2)),
                      Text('作成日 ${fmtYMD(now)}', style: TextStyle(fontSize: 12, color: pal.ink3)),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Divider(height: 2, thickness: 2, color: pal.ink),
              const SizedBox(height: 10),
              Text('対象期間：${fmtYMD(data.from)} 〜 ${fmtYMD(now)}（$_days日間）・家庭で測定した値',
                  style: TextStyle(fontSize: 12.5, color: pal.ink2)),
              const SizedBox(height: 12),
              if (data.rows.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  child: Text('この期間の記録はまだありません。', textAlign: TextAlign.center, style: TextStyle(color: pal.ink3)),
                )
              else
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: ConstrainedBox(
                    constraints: BoxConstraints(minWidth: MediaQuery.sizeOf(context).width - 68),
                    child: DataTable(
                      headingRowHeight: 32,
                      dataRowMinHeight: 34,
                      dataRowMaxHeight: 44,
                      horizontalMargin: 4,
                      columnSpacing: 14,
                      headingTextStyle: TextStyle(fontSize: 11, color: pal.ink3),
                      columns: const [
                        DataColumn(label: Text('項目')),
                        DataColumn(label: Text('平均'), numeric: true),
                        DataColumn(label: Text('最高'), numeric: true),
                        DataColumn(label: Text('最低'), numeric: true),
                        DataColumn(label: Text('回数'), numeric: true),
                      ],
                      rows: [
                        for (final r in data.rows)
                          DataRow(cells: [
                            DataCell(Text.rich(TextSpan(children: [
                              TextSpan(text: r.label, style: TextStyle(fontSize: 12.5, color: pal.ink)),
                              TextSpan(text: ' ${r.unit}', style: TextStyle(fontSize: 10, color: pal.ink3)),
                            ]))),
                            DataCell(Text(r.avg, style: cell)),
                            DataCell(Text(r.max, style: cell)),
                            DataCell(Text(r.min, style: cell)),
                            DataCell(Text('${r.n}', style: cell)),
                          ]),
                      ],
                    ),
                  ),
                ),
              if (data.changes.isNotEmpty) ...[
                const SizedBox(height: 8),
                for (final c in data.changes) Text(c, style: TextStyle(fontSize: 12.5, color: pal.ink2, height: 1.6)),
              ],
              if (bpMorning.isNotEmpty) ...[
                const SizedBox(height: 18),
                Text('朝の血圧の分類（家庭血圧・${bpMorning.length}回）', style: head),
                const SizedBox(height: 8),
                PieBlock(groups: groupsOf(bpMorning, MetricType.bp), semanticLabel: '朝の血圧の分類', size: 116),
              ],
              if (bpMorning.length >= 2) ...[
                const SizedBox(height: 18),
                Text('朝の血圧の推移', style: head),
                const SizedBox(height: 6),
                TrendChart(
                  height: 170,
                  x0: data.from,
                  x1: now,
                  refs: const [ChartRef(135, '135'), ChartRef(85, '85')],
                  series: [
                    ChartSeries(pal.mBp, [for (final e in bpMorning) ChartPoint(e.at, (e.sys ?? 0).toDouble())]),
                    ChartSeries(diaColor, [for (final e in bpMorning) ChartPoint(e.at, (e.dia ?? 0).toDouble())]),
                  ],
                ),
              ],
              if (weights.length >= 2) ...[
                const SizedBox(height: 18),
                Text('体重の推移', style: head),
                const SizedBox(height: 6),
                TrendChart(
                  height: 140,
                  x0: data.from,
                  x1: now,
                  series: [ChartSeries(pal.mWeight, [for (final e in weights) ChartPoint(e.at, e.value ?? 0)])],
                ),
              ],
              const SizedBox(height: 18),
              Text('医師に伝えたいこと', style: head),
              const SizedBox(height: 6),
              TextField(
                controller: _note,
                minLines: 3,
                maxLines: 6,
                maxLength: 500,
                onChanged: _onNoteChanged,
                decoration: InputDecoration(
                  hintText: '例：朝に頭が重い日がある。9月下旬に発熱。',
                  hintStyle: TextStyle(color: pal.ink3),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: pal.line),
                  ),
                ),
              ),
              Divider(color: pal.line),
              Text(
                '血圧（最高・最低）は収縮期／拡張期の値です。本レポートは利用者が自宅で測定・記録した値をまとめたもので、診断を目的としたものではありません。',
                style: TextStyle(fontSize: 11, color: pal.ink3, height: 1.5),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              child: FilledButton.icon(
                onPressed: _busy ? null : () => _makePdf(share: false),
                icon: _busy
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.picture_as_pdf_outlined),
                label: const Text('PDFを作成・印刷'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _busy ? null : () => _makePdf(share: true),
                icon: const Icon(Icons.ios_share),
                label: const Text('共有する'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: _copyText,
            icon: const Icon(Icons.copy_outlined, size: 18),
            label: const Text('要約をテキストでコピー'),
          ),
        ),
      ],
    );
  }
}
