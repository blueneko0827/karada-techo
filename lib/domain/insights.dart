/// Rule-based weekly insights. Every message is general guidance worded so
/// it never reads as a diagnosis.
library;

import 'dart:math' as math;

import '../models/entry.dart';
import '../models/metric.dart';
import 'classify.dart';
import 'format.dart';
import 'records.dart';

class Insight {
  const Insight(this.level, this.title, this.body);

  final Level level;
  final String title;
  final String body;
}

const Map<Level, String> _bpTitles = {
  Level.ok: '朝の血圧は「正常血圧」の範囲です',
  Level.note: '朝の血圧は「正常高値血圧」の範囲です',
  Level.warn: '朝の血圧は「高値血圧」の範囲です',
  Level.alert: '朝の血圧が家庭血圧の目安（135/85）以上です',
};

List<Insight> buildInsights(List<Entry> all) {
  final out = <Insight>[];

  // Morning blood pressure, 7-day average vs 4 weeks earlier.
  final a = bpAvg(all, from: daysAgo(6), slot: BpSlot.morning);
  if (a != null && a.n >= 3) {
    final c = bpClass(a.sys, a.dia);
    final p = bpAvg(all, from: daysAgo(34), to: daysAgo(28), slot: BpSlot.morning);
    final b = StringBuffer('直近7日の朝の平均は ${a.sys}/${a.dia} mmHg です。');
    if (p != null && p.n >= 3) {
      final ds = a.sys - p.sys;
      if (ds <= -2) {
        b.write('4週間前（${p.sys}/${p.dia}）より下がっています。');
      } else if (ds >= 2) {
        b.write('4週間前（${p.sys}/${p.dia}）より上がっています。');
      } else {
        b.write('4週間前（${p.sys}/${p.dia}）とほぼ同じです。');
      }
    }
    b.write('日本高血圧学会による家庭血圧の分類をもとにした目安です。');
    if (c.level == Level.alert) b.write('この状態が続くときは、かかりつけ医に相談しましょう。');
    out.add(Insight(c.level, _bpTitles[c.level] ?? '朝の血圧', b.toString()));
  }

  // Weight over 30 days.
  final w = ofType(all, MetricType.weight, from: daysAgo(29));
  if (w.length >= 6) {
    final d = mean(w.sublist(w.length - 3).map((e) => e.value ?? 0))! -
        mean(w.take(3).map((e) => e.value ?? 0))!;
    final weeks = math.max(1.0, w.last.at.difference(w.first.at).inHours / (24 * 7));
    final pace = d.abs() / weeks;
    if (d <= -0.3) {
      out.add(Insight(
        pace > 1 ? Level.note : Level.ok,
        'この30日で体重が ${d.abs().toStringAsFixed(1)} kg 減りました',
        '1週間あたり約 ${pace.toStringAsFixed(1)} kg のペースです。'
            '${pace > 1 ? '変化が急なときは、食事量や体調もあわせて振り返ってみましょう。' : 'ゆるやかなペースで続いています。'}',
      ));
    } else if (d >= 0.5) {
      out.add(Insight(Level.note, 'この30日で体重が ${d.toStringAsFixed(1)} kg 増えました',
          '食事や活動量の変化に心当たりがあるか、記録のメモとあわせて振り返ってみましょう。'));
    } else {
      out.add(Insight(Level.ok, 'この30日、体重は安定しています', '30日間の変化は ${fmtDelta(d, 1, ' kg')} です。'));
    }
  }

  // Temperature at or above the fever guide.
  final fevers = ofType(all, MetricType.temp, from: daysAgo(29)).where((e) => (e.value ?? 0) >= 37.5).toList();
  if (fevers.isNotEmpty) {
    final lf = fevers.last;
    final after = ofType(all, MetricType.temp, from: lf.at.add(const Duration(milliseconds: 1)));
    final recovered = after.isNotEmpty && after.every((e) => (e.value ?? 0) < 37.5);
    out.add(Insight(
      recovered ? Level.note : Level.warn,
      '${fmtJP(lf.at)}に ${(lf.value ?? 0).toStringAsFixed(1)}℃ の記録があります',
      recovered
          ? 'その後の記録は平熱域に戻っています。体調の変化をメモしておくと、受診のときに役立ちます。'
          : '37.5℃以上は一般的な発熱の目安です。高い熱が続く、息苦しいなどのときは医療機関に相談しましょう。',
    ));
  }

  // Fasting glucose over 30 days.
  final g = ofType(all, MetricType.glucose, from: daysAgo(29))
      .where((e) => e.timing == GlucoseTiming.fasting)
      .toList();
  if (g.length >= 3) {
    final vs = g.map((e) => e.value ?? 0).toList();
    final mx = vs.reduce(math.max).round();
    final av = mean(vs)!.round();
    if (mx >= 126) {
      out.add(Insight(Level.warn, '空腹時の血糖値に高めの記録があります',
          'この30日の最高は $mx mg/dL です。健康診断の結果とあわせて、かかりつけ医に相談しましょう。'));
    } else if (mx >= 110) {
      out.add(Insight(Level.note, '空腹時の血糖値で、目安の110をこえた日があります',
          'この30日の平均は $av mg/dL、最高は $mx mg/dL です。前日の食事や測った時間もメモしておくと、傾向がつかみやすくなります。'));
    } else {
      out.add(Insight(Level.ok, '空腹時の血糖値は目安の範囲内です',
          'この30日の平均は $av mg/dL で、すべて110 mg/dL未満でした。'));
    }
  }

  // Measurement habit.
  if (all.isNotEmpty) {
    final from = daysAgo(13);
    final days = all.where((e) => !e.at.isBefore(from)).map((e) => dayKey(e.at)).toSet().length;
    out.add(Insight(
      days >= 10 ? Level.ok : Level.note,
      '直近14日のうち $days 日記録できています',
      days >= 10
          ? '測定が習慣になっています。同じ時間帯に測り続けると、変化がより見やすくなります。'
          : 'リマインダーを使うと、測り忘れを減らせます。設定から時間を変えられます。',
    ));
  }

  out.sort((x, y) => x.level.index.compareTo(y.level.index));
  return out;
}
