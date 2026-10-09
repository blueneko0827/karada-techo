import 'metric.dart';

class Profile {
  const Profile({this.name = '', this.heightCm = 170});

  final String name;
  final double heightCm;

  Profile copyWith({String? name, double? heightCm}) =>
      Profile(name: name ?? this.name, heightCm: heightCm ?? this.heightCm);

  Map<String, dynamic> toJson() => {'name': name, 'heightCm': heightCm};

  factory Profile.fromJson(Map<String, dynamic> j) => Profile(
        name: (j['name'] as String?) ?? '',
        heightCm: (j['heightCm'] as num?)?.toDouble() ?? 170,
      );
}

class Goals {
  const Goals({
    this.weightTarget = 70,
    this.weightStart,
    this.fatTarget = 22.5,
    this.fatStart,
    this.bpSys = 125,
    this.bpDia = 80,
    this.habitDays = 6,
  });

  final double weightTarget;
  final double? weightStart;
  final double fatTarget;
  final double? fatStart;
  final int bpSys;
  final int bpDia;

  /// Days per week the user wants to measure morning blood pressure.
  final int habitDays;

  Goals copyWith({
    double? weightTarget,
    double? fatTarget,
    int? bpSys,
    int? bpDia,
    int? habitDays,
  }) =>
      Goals(
        weightTarget: weightTarget ?? this.weightTarget,
        weightStart: weightStart,
        fatTarget: fatTarget ?? this.fatTarget,
        fatStart: fatStart,
        bpSys: bpSys ?? this.bpSys,
        bpDia: bpDia ?? this.bpDia,
        habitDays: habitDays ?? this.habitDays,
      );

  /// Returns a copy with explicit start values (null = use first recorded value).
  Goals withStarts({double? weight, double? fat}) => Goals(
        weightTarget: weightTarget,
        weightStart: weight,
        fatTarget: fatTarget,
        fatStart: fat,
        bpSys: bpSys,
        bpDia: bpDia,
        habitDays: habitDays,
      );

  Map<String, dynamic> toJson() => {
        'weightTarget': weightTarget,
        'weightStart': weightStart,
        'fatTarget': fatTarget,
        'fatStart': fatStart,
        'bpSys': bpSys,
        'bpDia': bpDia,
        'habitDays': habitDays,
      };

  factory Goals.fromJson(Map<String, dynamic> j) => Goals(
        weightTarget: (j['weightTarget'] as num?)?.toDouble() ?? 70,
        weightStart: (j['weightStart'] as num?)?.toDouble(),
        fatTarget: (j['fatTarget'] as num?)?.toDouble() ?? 22.5,
        fatStart: (j['fatStart'] as num?)?.toDouble(),
        bpSys: (j['bpSys'] as num?)?.toInt() ?? 125,
        bpDia: (j['bpDia'] as num?)?.toInt() ?? 80,
        habitDays: (j['habitDays'] as num?)?.toInt() ?? 6,
      );
}

class Reminder {
  const Reminder({
    required this.id,
    required this.label,
    required this.type,
    required this.hour,
    required this.minute,
    this.slot,
    this.enabled = true,
  });

  final String id;
  final String label;
  final MetricType type;
  final BpSlot? slot;
  final int hour;
  final int minute;
  final bool enabled;

  String get timeLabel =>
      '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';

  Reminder copyWith({int? hour, int? minute, bool? enabled}) => Reminder(
        id: id,
        label: label,
        type: type,
        slot: slot,
        hour: hour ?? this.hour,
        minute: minute ?? this.minute,
        enabled: enabled ?? this.enabled,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'label': label,
        'type': type.name,
        'slot': slot?.name,
        'hour': hour,
        'minute': minute,
        'enabled': enabled,
      };

  factory Reminder.fromJson(Map<String, dynamic> j) => Reminder(
        id: j['id'] as String,
        label: j['label'] as String,
        type: MetricType.values.byName(j['type'] as String),
        slot: j['slot'] == null ? null : BpSlot.values.byName(j['slot'] as String),
        hour: (j['hour'] as num).toInt(),
        minute: (j['minute'] as num).toInt(),
        enabled: (j['enabled'] as bool?) ?? true,
      );
}

const List<Reminder> defaultReminders = [
  Reminder(id: 'r1', label: '朝の血圧', type: MetricType.bp, slot: BpSlot.morning, hour: 7, minute: 0),
  Reminder(id: 'r2', label: '晩の血圧', type: MetricType.bp, slot: BpSlot.evening, hour: 21, minute: 0),
  Reminder(id: 'r3', label: '体重・体脂肪率', type: MetricType.weight, hour: 7, minute: 10),
  Reminder(id: 'r4', label: '体温', type: MetricType.temp, hour: 7, minute: 0, enabled: false),
  Reminder(id: 'r5', label: '空腹時の血糖値', type: MetricType.glucose, hour: 7, minute: 15, enabled: false),
];

class AppSettings {
  const AppSettings({
    required this.profile,
    required this.goals,
    required this.reminders,
    this.healthEnabled = false,
    this.lastSync,
    this.isSample = false,
    this.onboarded = false,
    this.reportNote = '',
  });

  factory AppSettings.initial() => const AppSettings(
        profile: Profile(),
        goals: Goals(),
        reminders: defaultReminders,
      );

  final Profile profile;
  final Goals goals;
  final List<Reminder> reminders;
  final bool healthEnabled;
  final DateTime? lastSync;
  final bool isSample;
  final bool onboarded;
  final String reportNote;

  AppSettings copyWith({
    Profile? profile,
    Goals? goals,
    List<Reminder>? reminders,
    bool? healthEnabled,
    DateTime? lastSync,
    bool resetLastSync = false,
    bool? isSample,
    bool? onboarded,
    String? reportNote,
  }) =>
      AppSettings(
        profile: profile ?? this.profile,
        goals: goals ?? this.goals,
        reminders: reminders ?? this.reminders,
        healthEnabled: healthEnabled ?? this.healthEnabled,
        lastSync: resetLastSync ? null : (lastSync ?? this.lastSync),
        isSample: isSample ?? this.isSample,
        onboarded: onboarded ?? this.onboarded,
        reportNote: reportNote ?? this.reportNote,
      );

  Map<String, dynamic> toJson() => {
        'profile': profile.toJson(),
        'goals': goals.toJson(),
        'reminders': reminders.map((r) => r.toJson()).toList(),
        'healthEnabled': healthEnabled,
        'lastSync': lastSync?.millisecondsSinceEpoch,
        'isSample': isSample,
        'onboarded': onboarded,
        'reportNote': reportNote,
      };

  factory AppSettings.fromJson(Map<String, dynamic> j) {
    final rawReminders = j['reminders'] as List<dynamic>?;
    final lastSync = (j['lastSync'] as num?)?.toInt();
    return AppSettings(
      profile: j['profile'] is Map
          ? Profile.fromJson(Map<String, dynamic>.from(j['profile'] as Map))
          : const Profile(),
      goals: j['goals'] is Map
          ? Goals.fromJson(Map<String, dynamic>.from(j['goals'] as Map))
          : const Goals(),
      reminders: rawReminders == null
          ? defaultReminders
          : rawReminders
              .map((e) => Reminder.fromJson(Map<String, dynamic>.from(e as Map)))
              .toList(),
      healthEnabled: (j['healthEnabled'] as bool?) ?? false,
      lastSync: lastSync == null ? null : DateTime.fromMillisecondsSinceEpoch(lastSync),
      isSample: (j['isSample'] as bool?) ?? false,
      onboarded: (j['onboarded'] as bool?) ?? false,
      reportNote: (j['reportNote'] as String?) ?? '',
    );
  }
}
