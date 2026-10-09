import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/chart_math.dart';
import '../domain/classify.dart';
import '../domain/format.dart';
import '../domain/records.dart';
import '../models/entry.dart';
import '../models/metric.dart';
import '../state/providers.dart';
import '../theme/palette.dart';
import '../widgets/charts.dart';
import '../widgets/common.dart';

class TrendScreen extends ConsumerStatefulWidget {
  const TrendScreen({super.key});

  @override
  ConsumerState<TrendScreen> createState() => _TrendScreenState();
}

class _TrendScreenState extends ConsumerState<TrendScreen> {
  int _range = 30;
  String _slot = 'all'; // all | morning | evening
  String? _timingChoice; // fasting | after | all — null until the user picks one

  @override
  Widget build(BuildContext context) {
    final st = ref.watch(appProvider);
    final type = ref.watch(trendTypeProvider);
    final info = infoOf(type);
    final pal = context.pal;
    final color = pal.metric(type);
    final from = daysAgo(_range - 1);
    final now = DateTime.now();
    // Readings imported from Health have no meal timing, so default to "all" when the
    // latest reading has none; otherwise start on fasting, which has a clear guideline.
    final timingSel = _timingChoice ??
        (latest(st.entries, MetricType.glucose)?.timing == GlucoseTiming.other ? 'all' : 'fasting');

    var es = ofType(st.entries, type, from: from);
    if (type == MetricType.bp && _slot != 'all') {
      final slot = BpSlot.values.byName(_slot);
      es = es.where((e) => slotOf(e.at) == slot).toList();
    }
    if (type == MetricType.glucose && timingSel != 'all') {
      final timing = GlucoseTiming.values.byName(timingSel);
      es = es.where((e) => e.timing == timing).toList();
    }

    String fmtV(double v) => fmtNum(v, info.decimals);
    final diaColor = Color.lerp(pal.mBp, pal.ink3, 0.45)!;
    late final List<ChartSeries> series;
    var refs = <ChartRef>[];
    var refNote = '';
    var stats = <(String, String)>[];
    Widget? readDefault;
    late final Widget Function(int) readPoint;

    Widget readRow(String left, String value, String unit) => Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Expanded(child: Text(left, style: TextStyle(fontSize: 12.5, color: pal.ink2), overflow: TextOverflow.ellipsis)),
            Text(value, style: numStyle(17, pal.ink)),
            const SizedBox(width: 4),
            Text(unit, style: TextStyle(fontSize: 12, color: pal.ink3)),
          ],
        );

    if (type == MetricType.bp) {
      series = [
        ChartSeries(pal.mBp, [for (final e in es) ChartPoint(e.at, (e.sys ?? 0).toDouble())]),
        ChartSeries(diaColor, [for (final e in es) ChartPoint(e.at, (e.dia ?? 0).toDouble())]),
      ];
      refs = const [ChartRef(135, '135'), ChartRef(85, '85')];
      refNote = '点線は家庭血圧の目安（135/85 mmHg）。日本高血圧学会の分類では、家庭血圧 115/75 mmHg 未満が正常血圧です。';
      if (es.isNotEmpty) {
        final avgS = mean(es.map((e) => e.sys ?? 0))!.round();
        final avgD = mean(es.map((e) => e.dia ?? 0))!.round();
        final hi = es.reduce((x, y) => (y.sys ?? 0) > (x.sys ?? 0) ? y : x);
        final lo = es.reduce((x, y) => (y.sys ?? 0) < (x.sys ?? 0) ? y : x);
        stats = [('平均', '$avgS/$avgD'), ('最高', '${hi.sys}/${hi.dia}'), ('最低', '${lo.sys}/${lo.dia}'), ('回数', '${es.length}')];
        readDefault = readRow('期間の平均', '$avgS/$avgD', 'mmHg');
      }
      readPoint = (i) {
        final e = es[i];
        return readRow('${fmtJP(e.at)} ${fmtTime(e.at)}・${slotLabel[slotOf(e.at)]}', '${e.sys}/${e.dia}', 'mmHg');
      };
    } else {
      series = [ChartSeries(color, [for (final e in es) ChartPoint(e.at, e.value ?? 0)])];
      final goals = st.settings.goals;
      switch (type) {
        case MetricType.weight:
          refs = [ChartRef(goals.weightTarget, '目標 ${goals.weightTarget.toStringAsFixed(1)}', pal.gold)];
          final hgt = st.settings.profile.heightCm;
          if (hgt >= 100) {
            final m2 = (hgt / 100) * (hgt / 100);
            refNote = '身長 ${fmtNum(hgt, 0)} cm の場合、BMI 18.5〜25 未満（普通体重）にあたる体重は '
                '${(18.5 * m2).toStringAsFixed(1)}〜${(25 * m2).toStringAsFixed(1)} kg 未満です（日本肥満学会の基準）。';
          }
        case MetricType.fat:
          refs = [ChartRef(goals.fatTarget, '目標 ${goals.fatTarget.toStringAsFixed(1)}', pal.gold)];
        case MetricType.temp:
          refs = const [ChartRef(37.5, '37.5 発熱の目安')];
          refNote = '37.5℃以上が一般的な発熱の目安です。平熱には個人差があります。';
        case MetricType.glucose:
          if (timingSel == 'fasting') {
            refs = const [ChartRef(110, '110')];
            refNote = '点線は空腹時血糖の目安（110 mg/dL 未満、日本糖尿病学会の正常型）。';
          } else if (timingSel == 'after') {
            refs = const [ChartRef(140, '140')];
            refNote = '点線は食後2時間血糖の目安（140 mg/dL 未満）。';
          } else {
            refNote = '空腹時と食後では目安が異なります。タイミングを選ぶと目安線が表示されます。';
          }
        case MetricType.hr:
          refNote = '安静時の心拍数は、一般に 50〜100 拍/分が目安とされています。';
        case MetricType.bp:
          break;
      }
      if (es.isNotEmpty) {
        final vs = es.map((e) => e.value ?? 0).toList();
        final av = mean(vs)!;
        final change = vs.length >= 4
            ? mean(vs.sublist(vs.length - 3))! - mean(vs.take(3))!
            : vs.last - vs.first;
        stats = [
          ('平均', fmtV(av)),
          ('最高', fmtV(vs.reduce((a, b) => a > b ? a : b))),
          ('最低', fmtV(vs.reduce((a, b) => a < b ? a : b))),
          ('変化', fmtDelta(change, info.decimals)),
        ];
        readDefault = readRow('期間の平均', fmtV(av), info.unit);
      }
      readPoint = (i) {
        final e = es[i];
        final timing = e.timing == null ? '' : '・${glucoseTimingLabel[e.timing]}';
        return readRow('${fmtJP(e.at)} ${fmtTime(e.at)}$timing', fmtV(e.value ?? 0), info.unit);
      };
    }

    final hasPie = const [MetricType.bp, MetricType.glucose, MetricType.temp, MetricType.hr].contains(type);
    final list = es.reversed.take(40).toList();

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 28),
      children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              for (final t in MetricType.values)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    showCheckmark: false,
                    avatar: Dot(pal.metric(t)),
                    label: Text(infoOf(t).label),
                    selected: t == type,
                    onSelected: (_) => ref.read(trendTypeProvider.notifier).state = t,
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        Seg<int>(
          value: _range,
          options: const [(7, '7日'), (30, '30日'), (90, '90日')],
          onChanged: (v) => setState(() => _range = v),
        ),
        if (type == MetricType.bp) ...[
          const SizedBox(height: 8),
          Seg<String>(
            value: _slot,
            options: const [('all', 'すべて'), ('morning', '朝'), ('evening', '晩')],
            onChanged: (v) => setState(() => _slot = v),
          ),
        ],
        if (type == MetricType.glucose) ...[
          const SizedBox(height: 8),
          Seg<String>(
            value: timingSel,
            options: const [('fasting', '空腹時'), ('after', '食後2時間'), ('all', 'すべて')],
            onChanged: (v) => setState(() => _timingChoice = v),
          ),
        ],
        const SizedBox(height: 14),
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TrendChart(
                series: series,
                refs: refs,
                x0: from,
                x1: now,
                readout: es.isEmpty ? null : readPoint,
                readoutDefault: readDefault,
              ),
              if (type == MetricType.bp)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Wrap(
                    spacing: 14,
                    children: [
                      _LegendSwatch(color: pal.mBp, label: '最高血圧'),
                      _LegendSwatch(color: diaColor, label: '最低血圧'),
                      _LegendSwatch(color: pal.ink3, label: '目安', dashed: true),
                    ],
                  ),
                ),
              if (stats.isNotEmpty) ...[
                const SizedBox(height: 12),
                Divider(height: 1, color: pal.line),
                const SizedBox(height: 10),
                Row(
                  children: [
                    for (final s in stats)
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(s.$1, style: TextStyle(fontSize: 11, color: pal.ink3)),
                            const SizedBox(height: 2),
                            FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: Alignment.centerLeft,
                              child: Text(s.$2, style: numStyle(18, pal.ink)),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ],
              if (refNote.isNotEmpty) ...[
                const SizedBox(height: 10),
                Text(refNote, style: TextStyle(fontSize: 12, color: pal.ink3, height: 1.5)),
              ],
            ],
          ),
        ),
        if (hasPie && es.isNotEmpty) ...[
          const SizedBox(height: 14),
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SectionHeader(title: '分類の内訳', aux: '$_range日・${es.length}回'),
                PieBlock(groups: groupsOf(es, type), semanticLabel: '${info.label}の分類の内訳'),
              ],
            ),
          ),
        ],
        const SizedBox(height: 14),
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SectionHeader(title: '記録一覧', aux: '${es.length}件${es.length > 40 ? '（新しい40件）' : ''}'),
              if (list.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 20),
                  child: Column(
                    children: [
                      Text('この期間の記録はまだありません', style: TextStyle(color: pal.ink3)),
                      const SizedBox(height: 10),
                      OutlinedButton(
                        onPressed: () {
                          ref.read(recordTypeProvider.notifier).state = type;
                          ref.read(tabProvider.notifier).state = 2;
                        },
                        child: Text('${info.label}を記録する'),
                      ),
                    ],
                  ),
                )
              else
                for (var i = 0; i < list.length; i++) _EntryRow(entry: list[i], showDivider: i > 0),
            ],
          ),
        ),
      ],
    );
  }
}

class _LegendSwatch extends StatelessWidget {
  const _LegendSwatch({required this.color, required this.label, this.dashed = false});

  final Color color;
  final String label;
  final bool dashed;

  @override
  Widget build(BuildContext context) {
    final pal = context.pal;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        dashed
            ? Row(children: [
                for (var i = 0; i < 3; i++)
                  Container(width: 3, height: 2, margin: const EdgeInsets.only(right: 2), color: color),
              ])
            : Container(width: 14, height: 3, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2))),
        const SizedBox(width: 6),
        Text(label, style: TextStyle(fontSize: 12, color: pal.ink2)),
      ],
    );
  }
}

class _EntryRow extends ConsumerWidget {
  const _EntryRow({required this.entry, required this.showDivider});

  final Entry entry;
  final bool showDivider;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pal = context.pal;
    final e = entry;
    final info = infoOf(e.type);
    final value = e.type == MetricType.bp ? '${e.sys}/${e.dia}' : fmtNum(e.value ?? 0, info.decimals);
    final tags = <String>[
      if (e.type == MetricType.bp) slotLabel[slotOf(e.at)]!,
      if (e.pulse != null) '脈拍 ${e.pulse}',
      if (e.timing != null) glucoseTimingLabel[e.timing]!,
      sourceLabel[e.source]!,
    ];
    final status = e.type == MetricType.temp || e.type == MetricType.glucose ? classify(e) : null;
    final showStatus = status != null && status.level != Level.ok && status.level != Level.plain;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(border: showDivider ? Border(top: BorderSide(color: pal.line)) : null),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(
            width: 78,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${fmtMD(e.at)}（${weekdayJp(e.at)}）', style: TextStyle(fontSize: 13, color: pal.ink2)),
                Text(fmtTime(e.at), style: TextStyle(fontSize: 12, color: pal.ink3)),
              ],
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 6,
                  children: [
                    Text(value, style: numStyle(19, pal.ink)),
                    Text(info.unit, style: TextStyle(fontSize: 11, color: pal.ink3)),
                    if (showStatus) StatusChip(status!),
                  ],
                ),
                const SizedBox(height: 3),
                Wrap(
                  spacing: 4,
                  runSpacing: 4,
                  children: [
                    for (final t in tags) StatusChip(Status(Level.plain, t)),
                  ],
                ),
                if (e.note != null) ...[
                  const SizedBox(height: 3),
                  Text(e.note!, style: TextStyle(fontSize: 12, color: pal.ink2)),
                ],
              ],
            ),
          ),
          IconButton(
            tooltip: '削除',
            icon: Icon(Icons.delete_outline, color: pal.ink3, size: 20),
            onPressed: () async {
              final ctrl = ref.read(appProvider.notifier);
              final ok = await confirmDialog(
                context,
                title: 'この記録を削除しますか？',
                body: '${fmtJP(e.at)} ${fmtTime(e.at)} の${info.label}（$value ${info.unit}）を削除します。',
                action: '削除する',
                destructive: true,
              );
              if (ok) await ctrl.deleteEntry(e.id);
            },
          ),
        ],
      ),
    );
  }
}
