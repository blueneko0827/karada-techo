import 'dart:math';

import 'metric.dart';

/// One measurement. Blood pressure uses [sys]/[dia]/[pulse]; every other
/// metric uses [value].
class Entry {
  const Entry({
    required this.id,
    required this.type,
    required this.at,
    required this.source,
    this.value,
    this.sys,
    this.dia,
    this.pulse,
    this.timing,
    this.note,
    this.externalId,
  });

  final String id;
  final MetricType type;
  final DateTime at;
  final EntrySource source;
  final double? value;
  final int? sys;
  final int? dia;
  final int? pulse;
  final GlucoseTiming? timing;
  final String? note;

  /// Identifier from Apple Health / Health Connect, used to skip duplicates.
  final String? externalId;

  Map<String, Object?> toMap() => {
        'id': id,
        'type': type.name,
        'at': at.millisecondsSinceEpoch,
        'value': value,
        'sys': sys,
        'dia': dia,
        'pulse': pulse,
        'timing': timing?.name,
        'source': source.name,
        'note': note,
        'external_id': externalId,
      };

  factory Entry.fromMap(Map<String, Object?> m) => Entry(
        id: m['id'] as String,
        type: MetricType.values.byName(m['type'] as String),
        at: DateTime.fromMillisecondsSinceEpoch(m['at'] as int),
        source: EntrySource.values.byName(m['source'] as String),
        value: (m['value'] as num?)?.toDouble(),
        sys: (m['sys'] as num?)?.toInt(),
        dia: (m['dia'] as num?)?.toInt(),
        pulse: (m['pulse'] as num?)?.toInt(),
        timing: m['timing'] == null
            ? null
            : GlucoseTiming.values.byName(m['timing'] as String),
        note: m['note'] as String?,
        externalId: m['external_id'] as String?,
      );
}

final Random _rng = Random();

String newId() =>
    '${DateTime.now().microsecondsSinceEpoch.toRadixString(36)}'
    '${_rng.nextInt(0x7fffffff).toRadixString(36)}';
