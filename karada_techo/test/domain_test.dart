import 'package:flutter_test/flutter_test.dart';
import 'package:karada_techo/domain/chart_math.dart';
import 'package:karada_techo/domain/classify.dart';
import 'package:karada_techo/domain/format.dart';
import 'package:karada_techo/domain/insights.dart';
import 'package:karada_techo/domain/records.dart';
import 'package:karada_techo/domain/sample_data.dart';
import 'package:karada_techo/models/entry.dart';
import 'package:karada_techo/models/metric.dart';
import 'package:karada_techo/models/settings.dart';

void main() {
  group('home blood pressure (JSH 2019)', () {
    test('categories', () {
      expect(bpClass(114, 74).level, Level.ok);
      expect(bpClass(118, 70).level, Level.note);
      expect(bpClass(126, 70).level, Level.warn);
      expect(bpClass(120, 78).level, Level.warn);
      expect(bpClass(135, 80).level, Level.alert);
      expect(bpClass(120, 85).level, Level.alert);
    });
  });

  group('glucose', () {
    test('fasting', () {
      expect(glucoseClass(95, GlucoseTiming.fasting).level, Level.ok);
      expect(glucoseClass(105, GlucoseTiming.fasting).level, Level.note);
      expect(glucoseClass(115, GlucoseTiming.fasting).level, Level.warn);
      expect(glucoseClass(130, GlucoseTiming.fasting).level, Level.alert);
    });
    test('after meal and unknown timing', () {
      expect(glucoseClass(135, GlucoseTiming.after).level, Level.ok);
      expect(glucoseClass(150, GlucoseTiming.after).level, Level.warn);
      expect(glucoseClass(150, GlucoseTiming.other).level, Level.plain);
    });
  });

  test('BMI and temperature', () {
    expect(bmiClass(18).level, Level.warn);
    expect(bmiClass(22).level, Level.ok);
    expect(bmiClass(26).level, Level.warn);
    expect(tempClass(36.5).level, Level.ok);
    expect(tempClass(37.5).level, Level.warn);
  });

  test('nice ticks cover the range with round steps', () {
    final t = niceTicks(71.2, 73.9, 4);
    expect(t.lo <= 71.2, isTrue);
    expect(t.hi >= 73.9, isTrue);
    expect(t.step, closeTo(0.5, 1e-9));
  });

  test('pie groups always list all four BP categories', () {
    final now = DateTime.now();
    final es = [
      Entry(id: 'a', type: MetricType.bp, at: now, source: EntrySource.manual, sys: 112, dia: 70),
      Entry(id: 'b', type: MetricType.bp, at: now, source: EntrySource.manual, sys: 128, dia: 80),
    ];
    final g = groupsOf(es, MetricType.bp);
    expect(g.length, 4);
    expect(g.map((x) => x.n).toList(), [1, 0, 1, 0]);
  });

  test('normalizeNum converts full-width input', () {
    expect(normalizeNum('１２０'), '120');
    expect(normalizeNum('７０．５'), '70.5');
  });

  test('sample data is sorted, recent and produces insights and a report', () {
    final es = generateSampleEntries();
    expect(es, isNotEmpty);
    for (var i = 1; i < es.length; i++) {
      expect(es[i - 1].at.isAfter(es[i].at), isFalse);
    }
    expect(buildInsights(es), isNotEmpty);
    final report = buildReportData(es, 30);
    expect(report.rows.any((r) => r.label == '血圧（朝）'), isTrue);
    expect(summarize(es, MetricType.weight, const Profile()), isNotNull);
  });

  test('settings survive a JSON round trip', () {
    final s = AppSettings.initial().copyWith(
      profile: const Profile(name: '山田', heightCm: 165),
      onboarded: true,
      lastSync: DateTime(2026, 10, 9, 8),
    );
    final back = AppSettings.fromJson(s.toJson());
    expect(back.profile.name, '山田');
    expect(back.profile.heightCm, 165);
    expect(back.onboarded, isTrue);
    expect(back.reminders.length, s.reminders.length);
    expect(back.lastSync, DateTime(2026, 10, 9, 8));
  });
}
