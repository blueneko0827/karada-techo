/// Queries and summaries over the in-memory list of entries.
/// The list is always kept sorted by time (oldest first).
library;

import 'dart:math' as math;

import '../models/entry.dart';
import '../models/metric.dart';
import '../models/settings.dart';
import 'chart_math.dart';
import 'classify.dart';
import 'format.dart';

List<Entry> ofType(List<Entry> all, MetricType type, {DateTime? from, DateTime? to}) {
  return all
      .where((e) =>
          e.type == type &&
          (from == null || !e.at.isBefore(from)) &&
          (to == null || !e.at.isAfter(to)))
      .toList();
}

Entry? latest(List<Entry> all, MetricType type) {
  for (var i = all.length - 1; i >= 0; i--) {
    if (all[i].type == type) return all[i];
  }
  return null;
}

class BpAvg {
  const BpAvg(this.sys, this.dia, this.n);

  final int sys;
  final int dia;
  final int n;
}

BpAvg? bpAvg(List<Entry> all, {DateTime? from, DateTime? to, BpSlot? slot}) {
  final es = ofType(all, MetricType.bp, from: from, to: to)
      .where((e) => slot == null || slotOf(e.at) == slot)
      .toList();
  if (es.isEmpty) return null;
  return BpAvg(
    mean(es.map((e) => e.sys ?? 0))!.round(),
    mean(es.map((e) => e.dia ?? 0))!.round(),
    es.length,
  );
}

/// Linear-regression slope in units per day.
double? slopePerDay(List<Entry> es) {
  if (es.length < 4) return null;
  final x0 = es.first.at;
  final xs = es.map((e) => e.at.difference(x0).inMinutes / 1440.0).toList();
  final ys = es.map((e) => e.value ?? 0).toList();
  final mx = mean(xs)!;
  final my = mean(ys)!;
  var a = 0.0;
  var b = 0.0;
  for (var i = 0; i < xs.length; i++) {
    a += (xs[i] - mx) * (ys[i] - my);
    b += (xs[i] - mx) * (xs[i] - mx);
  }
  return b == 0 ? null : a / b;
}

/// Consecutive days (ending today, or yesterday if nothing yet today) with a record.
int streak(List<Entry> all) {
  final days = all.map((e) => dayKey(e.at)).toSet();
  var d = startOfDay(DateTime.now());
  if (!days.contains(dayKey(d))) d = DateTime(d.year, d.month, d.day - 1);
  var s = 0;
  while (days.contains(dayKey(d))) {
    s++;
    d = DateTime(d.year, d.month, d.day - 1);
  }
  return s;
}

double? goalStart(List<Entry> all, MetricType type, Goals goals) {
  final stored = type == MetricType.weight ? goals.weightStart : goals.fatStart;
  if (stored != null) return stored;
  final es = ofType(all, type);
  return es.isEmpty ? null : es.first.value;
}

/// Points for the 14-day sparkline on the home cards.
List<ChartPoint> sparkPoints(List<Entry> all, MetricType type) {
  var es = ofType(all, type, from: daysAgo(13));
  if (type == MetricType.glucose) {
    final fasting = es.where((e) => e.timing == GlucoseTiming.fasting).toList();
    if (fasting.length >= 2) es = fasting;
  }
  if (type == MetricType.bp) {
    es = es.where((e) => slotOf(e.at) == BpSlot.morning).toList();
  }
  return es
      .map((e) => ChartPoint(e.at, type == MetricType.bp ? (e.sys ?? 0).toDouble() : (e.value ?? 0)))
      .toList();
}

// ---------------------------------------------------------------- summaries

class MetricSummary {
  const MetricSummary({required this.value, required this.sub, this.status});

  final String value;
  final String sub;
  final Status? status;
}

MetricSummary? summarize(List<Entry> all, MetricType type, Profile profile) {
  final l = latest(all, type);
  if (l == null) return null;
  final weekAgo = daysAgo(6);
  final twoWeeksAgo = daysAgo(13);
  double? avg(DateTime from, [DateTime? to]) =>
      mean(ofType(all, type, from: from, to: to).map((e) => e.value ?? 0));

  switch (type) {
    case MetricType.bp:
      final a = bpAvg(all, from: weekAgo, slot: BpSlot.morning);
      if (a != null) {
        return MetricSummary(
          value: '${l.sys}/${l.dia}',
          sub: '朝7日平均 ${a.sys}/${a.dia}',
          status: bpClass(a.sys, a.dia),
        );
      }
      return MetricSummary(
        value: '${l.sys}/${l.dia}',
        sub: '${fmtMD(l.at)} ${fmtTime(l.at)}',
        status: bpClass(l.sys ?? 0, l.dia ?? 0),
      );
    case MetricType.weight:
      final parts = <String>[];
      Status? status;
      if (profile.heightCm >= 100) {
        final m = profile.heightCm / 100;
        final bmi = (l.value ?? 0) / (m * m);
        status = bmiClass(bmi);
        parts.add('BMI ${bmi.toStringAsFixed(1)}');
      }
      final a = avg(weekAgo);
      final b = avg(twoWeeksAgo, weekAgo.subtract(const Duration(milliseconds: 1)));
      if (a != null && b != null) parts.add('前週比 ${fmtDelta(a - b, 1)}');
      return MetricSummary(
        value: (l.value ?? 0).toStringAsFixed(1),
        sub: parts.isEmpty ? fmtMD(l.at) : parts.join(' · '),
        status: status,
      );
    case MetricType.hr:
      return MetricSummary(
        value: (l.value ?? 0).round().toString(),
        sub: '安静時 · ${sourceLabel[l.source] ?? ''}',
        status: hrClass(l.value ?? 0),
      );
    case MetricType.temp:
      return MetricSummary(
        value: (l.value ?? 0).toStringAsFixed(1),
        sub: '${fmtMD(l.at)} ${fmtTime(l.at)}',
        status: tempClass(l.value ?? 0),
      );
    case MetricType.glucose:
      return MetricSummary(
        value: (l.value ?? 0).round().toString(),
        sub: '${glucoseTimingLabel[l.timing] ?? 'その他'} · ${fmtMD(l.at)}',
        status: glucoseClass(l.value ?? 0, l.timing),
      );
    case MetricType.fat:
      final es = ofType(all, MetricType.fat, from: daysAgo(29));
      var sub = fmtMD(l.at);
      if (es.length >= 4) {
        final d = mean(es.sublist(es.length - 3).map((e) => e.value ?? 0))! -
            mean(es.take(3).map((e) => e.value ?? 0))!;
        sub = '30日で ${fmtDelta(d, 1, ' pt')}';
      }
      return MetricSummary(value: (l.value ?? 0).toStringAsFixed(1), sub: sub);
  }
}

// ---------------------------------------------------------------- pie groups

class PieGroup {
  PieGroup(this.level, this.label);

  final Level level;
  final String label;
  int n = 0;
}

/// Counts readings per reference category. Blood pressure always lists all
/// four JSH categories so that empty ones show as 0%.
List<PieGroup> groupsOf(List<Entry> es, MetricType type) {
  final map = <String, PieGroup>{};
  if (type == MetricType.bp) {
    for (final g in [
      PieGroup(Level.ok, '正常血圧'),
      PieGroup(Level.note, '正常高値'),
      PieGroup(Level.warn, '高値血圧'),
      PieGroup(Level.alert, '目安超え'),
    ]) {
      map['${g.level.name}|${g.label}'] = g;
    }
  }
  for (final e in es) {
    final s = classify(e);
    if (s == null) continue;
    final key = '${s.level.name}|${s.label}';
    map.putIfAbsent(key, () => PieGroup(s.level, s.label)).n++;
  }
  final list = map.values.toList()
    ..sort((a, b) => a.level.index.compareTo(b.level.index));
  return list;
}

// ---------------------------------------------------------------- report

class ReportRow {
  const ReportRow(this.label, this.unit, this.avg, this.max, this.min, this.n);

  final String label;
  final String unit;
  final String avg;
  final String max;
  final String min;
  final int n;
}

class ReportData {
  const ReportData(this.from, this.rows, this.changes);

  final DateTime from;
  final List<ReportRow> rows;
  final List<String> changes;
}

ReportData buildReportData(List<Entry> all, int days) {
  final from = daysAgo(days - 1);
  final rows = <ReportRow>[];
  final changes = <String>[];

  void bpRow(String label, BpSlot slot) {
    final es = ofType(all, MetricType.bp, from: from).where((e) => slotOf(e.at) == slot).toList();
    if (es.isEmpty) return;
    final hi = es.reduce((x, y) => (y.sys ?? 0) > (x.sys ?? 0) ? y : x);
    final lo = es.reduce((x, y) => (y.sys ?? 0) < (x.sys ?? 0) ? y : x);
    rows.add(ReportRow(
      label,
      'mmHg',
      '${mean(es.map((e) => e.sys ?? 0))!.round()}/${mean(es.map((e) => e.dia ?? 0))!.round()}',
      '${hi.sys}/${hi.dia}',
      '${lo.sys}/${lo.dia}',
      es.length,
    ));
  }

  bpRow('血圧（朝）', BpSlot.morning);
  bpRow('血圧（晩）', BpSlot.evening);

  final pulses = ofType(all, MetricType.bp, from: from)
      .where((e) => e.pulse != null)
      .map((e) => e.pulse!)
      .toList();
  if (pulses.isNotEmpty) {
    rows.add(ReportRow('脈拍（血圧計）', '拍/分', '${mean(pulses)!.round()}',
        '${pulses.reduce(math.max)}', '${pulses.reduce(math.min)}', pulses.length));
  }

  void valueRow(String label, MetricType type, [bool Function(Entry)? filter]) {
    final info = infoOf(type);
    final es = ofType(all, type, from: from).where(filter ?? ((Entry _) => true)).toList();
    if (es.isEmpty) return;
    final vs = es.map((e) => e.value ?? 0).toList();
    String f(double v) => fmtNum(v, info.decimals);
    rows.add(ReportRow(label, info.unit, f(mean(vs)!), f(vs.reduce(math.max)),
        f(vs.reduce(math.min)), es.length));
    if ((type == MetricType.weight || type == MetricType.fat) && es.length >= 2) {
      changes.add('${info.label}：${f(vs.first)} → ${f(vs.last)} ${info.unit}'
          '（${fmtDelta(vs.last - vs.first, 1)}）');
    }
  }

  valueRow('心拍数（安静時）', MetricType.hr);
  valueRow('体重', MetricType.weight);
  valueRow('体脂肪率', MetricType.fat);
  valueRow('体温', MetricType.temp);
  valueRow('血糖値（空腹時）', MetricType.glucose, (e) => e.timing == GlucoseTiming.fasting);
  valueRow('血糖値（食後2時間）', MetricType.glucose, (e) => e.timing == GlucoseTiming.after);
  valueRow('血糖値（タイミング不明）', MetricType.glucose,
      (e) => e.timing == null || e.timing == GlucoseTiming.other);

  final fevers = ofType(all, MetricType.temp, from: from).where((e) => (e.value ?? 0) >= 37.5);
  if (fevers.isNotEmpty) {
    changes.add('37.5℃以上の記録：'
        '${fevers.map((e) => '${fmtMD(e.at)} ${(e.value ?? 0).toStringAsFixed(1)}℃').join('、')}');
  }
  return ReportData(from, rows, changes);
}

String reportText(List<Entry> all, AppSettings s, int days) {
  final d = buildReportData(all, days);
  final now = DateTime.now();
  final lines = <String>[
    '健康記録レポート（からだ手帖）',
    if (s.profile.name.isNotEmpty) '氏名：${s.profile.name}',
    '期間：${fmtYMD(d.from)}〜${fmtYMD(now)}（$days日間）',
    '',
    for (final r in d.rows) '${r.label}　平均 ${r.avg} ${r.unit}（最高 ${r.max}・最低 ${r.min}・${r.n}回）',
    if (d.changes.isNotEmpty) '',
    ...d.changes,
    if (s.reportNote.trim().isNotEmpty) ...['', '医師に伝えたいこと：', s.reportNote.trim()],
    '',
    '※自宅で測定・記録した値のまとめです。診断を目的としたものではありません。',
  ];
  return lines.join('\n');
}
