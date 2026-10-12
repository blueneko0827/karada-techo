/// Reference-range classification. These are general guideline ranges used
/// for display only — never a diagnosis.
///
/// * Home blood pressure: Japanese Society of Hypertension (JSH) 2019
///   正常 <115/<75 · 正常高値 115–124/<75 · 高値 125–134 or 75–84 · ≥135/85
/// * BMI: Japan Society for the Study of Obesity (18.5 · 25)
/// * Fasting glucose: Japan Diabetes Society (110 · 126 mg/dL); 2h after meal 140
/// * Fever guide: 37.5 ℃
library;

import '../models/entry.dart';
import '../models/metric.dart';

/// Display level, in order of increasing concern. `plain` = no judgement.
enum Level { ok, note, warn, alert, plain }

class Status {
  const Status(this.level, this.label);

  final Level level;
  final String label;
}

Status bpClass(int sys, int dia) {
  if (sys >= 135 || dia >= 85) return const Status(Level.alert, '目安超え');
  if (sys >= 125 || dia >= 75) return const Status(Level.warn, '高値血圧');
  if (sys >= 115) return const Status(Level.note, '正常高値');
  return const Status(Level.ok, '正常血圧');
}

Status bmiClass(double bmi) {
  if (bmi < 18.5) return const Status(Level.warn, '低体重');
  if (bmi < 25) return const Status(Level.ok, '普通体重');
  return const Status(Level.warn, 'BMI 25以上');
}

Status hrClass(double v) => (v >= 50 && v <= 100)
    ? const Status(Level.ok, '目安内')
    : const Status(Level.warn, '目安外');

Status tempClass(double v) {
  if (v >= 37.5) return const Status(Level.warn, '発熱の目安');
  if (v < 35.5) return const Status(Level.note, '低め');
  return const Status(Level.ok, '平熱域');
}

Status glucoseClass(double v, GlucoseTiming? timing) {
  if (timing == GlucoseTiming.fasting) {
    if (v < 100) return const Status(Level.ok, '正常域');
    if (v < 110) return const Status(Level.note, '正常高値');
    if (v < 126) return const Status(Level.warn, 'やや高め');
    return const Status(Level.alert, '高め');
  }
  if (timing == GlucoseTiming.after) {
    if (v < 140) return const Status(Level.ok, '目安内');
    if (v < 200) return const Status(Level.warn, 'やや高め');
    return const Status(Level.alert, '高め');
  }
  return const Status(Level.plain, '記録');
}

/// Classifies one entry, or returns null for metrics without a reference range.
Status? classify(Entry e) {
  switch (e.type) {
    case MetricType.bp:
      return bpClass(e.sys ?? 0, e.dia ?? 0);
    case MetricType.glucose:
      return glucoseClass(e.value ?? 0, e.timing);
    case MetricType.temp:
      return tempClass(e.value ?? 0);
    case MetricType.hr:
      return hrClass(e.value ?? 0);
    case MetricType.weight:
    case MetricType.fat:
      return null;
  }
}
