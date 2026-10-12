import 'dart:math';

import '../models/entry.dart';
import '../models/metric.dart';
import 'format.dart';

/// 12 weeks of plausible readings so a new user can try every screen.
/// Clearly flagged in the UI and replaced as soon as the user records.
List<Entry> generateSampleEntries({DateTime? now}) {
  final current = now ?? DateTime.now();
  final rnd = Random(20261009);
  double nz() => (rnd.nextDouble() + rnd.nextDouble() + rnd.nextDouble() - 1.5) / 1.5;
  double r1(double x) => (x * 10).round() / 10;

  const days = 84;
  final today = startOfDay(current);
  final out = <Entry>[];
  var seq = 0;

  void add(MetricType type, DateTime at, EntrySource source,
      {double? value, int? sys, int? dia, int? pulse, GlucoseTiming? timing, String? note}) {
    if (at.isAfter(current)) return;
    out.add(Entry(
      id: 'sample-${seq++}',
      type: type,
      at: at,
      source: source,
      value: value,
      sys: sys,
      dia: dia,
      pulse: pulse,
      timing: timing,
      note: note,
    ));
  }

  for (var i = 0; i < days; i++) {
    final day = DateTime(today.year, today.month, today.day - (days - 1 - i));
    final t = i / (days - 1);
    final isToday = i == days - 1;
    DateTime at(int h, int m) => DateTime(day.year, day.month, day.day, h, m);

    if (rnd.nextDouble() > 0.1 || isToday) {
      add(MetricType.weight, at(7, 5), EntrySource.scale, value: r1(73.4 - 2.4 * t + nz() * 0.35));
      add(MetricType.fat, at(7, 5), EntrySource.scale, value: r1(25.2 - 1.7 * t + nz() * 0.4));
    }
    if (rnd.nextDouble() > 0.08 || isToday) {
      final spike = rnd.nextDouble() < 0.1 ? 12 : 0;
      add(MetricType.bp, at(6, 46 + rnd.nextInt(12)), EntrySource.manual,
          sys: (132 - 12 * t + nz() * 20 + spike).round(),
          dia: (80 - 7 * t + nz() * 12).round(),
          pulse: (71 - 3 * t + nz() * 4).round());
    }
    if (!isToday && rnd.nextDouble() > 0.3) {
      add(MetricType.bp, at(21, 15 + rnd.nextInt(30)), EntrySource.manual,
          sys: (124 - 8 * t + nz() * 18).round(),
          dia: (75 - 5 * t + nz() * 10).round(),
          pulse: (66 + nz() * 4).round());
    }
    add(MetricType.hr, at(8, 0), EntrySource.watch, value: (67 - 3 * t + nz() * 3).roundToDouble());

    final fever = i == days - 21;
    final afterFever = i == days - 20;
    if (rnd.nextDouble() > 0.35 || isToday || fever || afterFever) {
      var tv = r1(36.45 + nz() * 0.18);
      if (fever) tv = 37.6;
      if (afterFever) tv = 37.1;
      add(MetricType.temp, at(7, 0), EntrySource.manual, value: tv, note: fever ? 'のどの痛みあり。早めに就寝' : null);
    }
    if (i % 3 == 0) {
      add(MetricType.glucose, at(7, 15), EntrySource.manual,
          value: (106 - 8 * t + nz() * 5).roundToDouble(), timing: GlucoseTiming.fasting);
    }
    if (i % 7 == 2) {
      add(MetricType.glucose, at(13, 30), EntrySource.manual,
          value: (134 - 6 * t + nz() * 10).roundToDouble(), timing: GlucoseTiming.after);
    }
  }
  out.sort((a, b) => a.at.compareTo(b.at));
  return out;
}
