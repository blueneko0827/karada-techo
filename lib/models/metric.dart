/// Metric definitions shared by the UI, storage and the doctor report.
/// Pure Dart (no Flutter imports) so it can be unit-tested quickly.
library;

enum MetricType { bp, weight, hr, temp, glucose, fat }

enum GlucoseTiming { fasting, after, other }

enum EntrySource { manual, watch, scale, device }

/// Home blood pressure is read separately for morning and evening (JSH guideline).
enum BpSlot { morning, evening, daytime }

class FieldSpec {
  const FieldSpec({
    required this.key,
    required this.label,
    required this.unit,
    required this.min,
    required this.max,
    this.decimals = 0,
    this.optional = false,
  });

  final String key;
  final String label;
  final String unit;
  final double min;
  final double max;
  final int decimals;
  final bool optional;
}

class MetricInfo {
  const MetricInfo({
    required this.label,
    required this.unit,
    required this.fields,
    required this.tip,
    this.decimals = 0,
    this.autoNote,
  });

  final String label;
  final String unit;
  final List<FieldSpec> fields;
  final String tip;
  final int decimals;
  final String? autoNote;
}

const Map<MetricType, MetricInfo> metrics = {
  MetricType.bp: MetricInfo(
    label: '血圧',
    unit: 'mmHg',
    tip: '朝は起床後1時間以内・排尿後・朝食や服薬の前に、晩は寝る前に。いすに座って1〜2分休んでから測りましょう。',
    autoNote: 'OMRON connect などの血圧計アプリがヘルスケアに書き込んだ値を取り込めます',
    fields: [
      FieldSpec(key: 'sys', label: '最高血圧（収縮期）', unit: 'mmHg', min: 60, max: 260),
      FieldSpec(key: 'dia', label: '最低血圧（拡張期）', unit: 'mmHg', min: 30, max: 160),
      FieldSpec(key: 'pulse', label: '脈拍', unit: '拍/分', min: 30, max: 220, optional: true),
    ],
  ),
  MetricType.weight: MetricInfo(
    label: '体重',
    unit: 'kg',
    decimals: 1,
    tip: '毎日同じ時間帯（朝の排尿後・朝食前など）に測ると、変化がわかりやすくなります。',
    autoNote: '体組成計・Apple ヘルスケア・Health Connect から自動で取り込めます',
    fields: [
      FieldSpec(key: 'v', label: '体重', unit: 'kg', min: 20, max: 250, decimals: 1),
    ],
  ),
  MetricType.hr: MetricInfo(
    label: '心拍数',
    unit: '拍/分',
    tip: '起きてすぐ、座って落ち着いた状態で測ります。運動の直後は避けましょう。',
    autoNote: 'スマートウォッチの安静時心拍数を自動で取り込めます',
    fields: [
      FieldSpec(key: 'v', label: '安静時の心拍数', unit: '拍/分', min: 30, max: 220),
    ],
  ),
  MetricType.temp: MetricInfo(
    label: '体温',
    unit: '℃',
    decimals: 1,
    tip: 'わきの下で測るときは、汗をふいてから体温計をしっかりはさみます。',
    fields: [
      FieldSpec(key: 'v', label: '体温', unit: '℃', min: 34, max: 42, decimals: 1),
    ],
  ),
  MetricType.glucose: MetricInfo(
    label: '血糖値',
    unit: 'mg/dL',
    tip: '空腹時と食後では目安が変わるため、測ったタイミングも記録します。',
    fields: [
      FieldSpec(key: 'v', label: '血糖値', unit: 'mg/dL', min: 20, max: 600),
    ],
  ),
  MetricType.fat: MetricInfo(
    label: '体脂肪率',
    unit: '%',
    decimals: 1,
    tip: '体の水分量で変わりやすいため、入浴や運動の直後は避けると比べやすくなります。',
    autoNote: '体組成計から自動で取り込めます',
    fields: [
      FieldSpec(key: 'v', label: '体脂肪率', unit: '%', min: 3, max: 70, decimals: 1),
    ],
  ),
};

MetricInfo infoOf(MetricType t) => metrics[t]!;

const Map<GlucoseTiming, String> glucoseTimingLabel = {
  GlucoseTiming.fasting: '空腹時',
  GlucoseTiming.after: '食後2時間',
  GlucoseTiming.other: 'その他',
};

const Map<EntrySource, String> sourceLabel = {
  EntrySource.manual: '手入力',
  EntrySource.watch: 'ウォッチ',
  EntrySource.scale: '体組成計',
  EntrySource.device: '連携',
};

const Map<BpSlot, String> slotLabel = {
  BpSlot.morning: '朝',
  BpSlot.evening: '晩',
  BpSlot.daytime: '日中',
};

BpSlot slotOf(DateTime t) {
  final h = t.hour;
  if (h >= 4 && h < 12) return BpSlot.morning;
  if (h >= 18 || h < 4) return BpSlot.evening;
  return BpSlot.daytime;
}
