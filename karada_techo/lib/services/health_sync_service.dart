import 'package:flutter/foundation.dart';
import 'package:health/health.dart';

import '../models/entry.dart';
import '../models/metric.dart';

enum HealthAccess { granted, denied, unavailable }

/// Reads measurements from Apple Health (iOS) or Health Connect (Android).
/// Smartwatches, scales and blood-pressure monitor apps that write to those
/// stores (Apple Watch, Galaxy Watch, Withings, OMRON connect …) are covered
/// without a separate integration per brand. Read-only.
class HealthSyncService {
  HealthSyncService._();

  static final HealthSyncService instance = HealthSyncService._();

  final Health _health = Health();
  bool _configured = false;

  static const List<HealthDataType> types = [
    HealthDataType.WEIGHT,
    HealthDataType.BODY_FAT_PERCENTAGE,
    HealthDataType.RESTING_HEART_RATE,
    HealthDataType.BLOOD_PRESSURE_SYSTOLIC,
    HealthDataType.BLOOD_PRESSURE_DIASTOLIC,
    HealthDataType.BODY_TEMPERATURE,
    HealthDataType.BLOOD_GLUCOSE,
  ];

  Future<void> _ensureConfigured() async {
    if (_configured) return;
    await _health.configure();
    _configured = true;
  }

  Future<HealthAccess> requestAccess() async {
    try {
      await _ensureConfigured();
      if (defaultTargetPlatform == TargetPlatform.android) {
        final status = await _health.getHealthConnectSdkStatus();
        if (status != HealthConnectSdkStatus.sdkAvailable) return HealthAccess.unavailable;
      }
      final granted = await _health.requestAuthorization(
        types,
        permissions: types.map((_) => HealthDataAccess.READ).toList(),
      );
      if (!granted) return HealthAccess.denied;
      if (defaultTargetPlatform == TargetPlatform.android) {
        // Without this, Health Connect only returns the last 30 days.
        try {
          if (await _health.isHealthDataHistoryAvailable() &&
              !await _health.isHealthDataHistoryAuthorized()) {
            await _health.requestHealthDataHistoryAuthorization();
          }
        } catch (e) {
          debugPrint('History permission not granted: $e');
        }
      }
      return HealthAccess.granted;
    } catch (e) {
      debugPrint('Health authorization failed: $e');
      return HealthAccess.denied;
    }
  }

  /// Opens the Play Store page for Health Connect (Android 13 and older).
  Future<void> installHealthConnect() async {
    try {
      await _ensureConfigured();
      await _health.installHealthConnect();
    } catch (e) {
      debugPrint('Could not open Health Connect install page: $e');
    }
  }

  Future<List<Entry>> fetch(DateTime since) async {
    await _ensureConfigured();
    var points = await _health.getHealthDataFromTypes(
      types: types,
      startTime: since,
      endTime: DateTime.now(),
    );
    points = _health.removeDuplicates(points);

    final out = <Entry>[];
    final systolic = <int, HealthDataPoint>{};
    final diastolic = <int, HealthDataPoint>{};

    Entry single(HealthDataPoint p, MetricType type, double v, EntrySource source) => Entry(
          id: newId(),
          type: type,
          at: p.dateFrom,
          source: source,
          value: v,
          timing: type == MetricType.glucose ? GlucoseTiming.other : null,
          externalId: 'hc:${p.uuid}',
        );

    for (final p in points) {
      final v = _numeric(p);
      if (v == null) continue;
      switch (p.type) {
        case HealthDataType.WEIGHT:
          out.add(single(p, MetricType.weight, _r1(v), EntrySource.scale));
        case HealthDataType.BODY_FAT_PERCENTAGE:
          // HealthKit reports a fraction (0.23); Health Connect a percentage (23).
          out.add(single(p, MetricType.fat, _r1(v <= 1 ? v * 100 : v), EntrySource.scale));
        case HealthDataType.RESTING_HEART_RATE:
          out.add(single(p, MetricType.hr, v.roundToDouble(), EntrySource.watch));
        case HealthDataType.BODY_TEMPERATURE:
          out.add(single(p, MetricType.temp, _r1(v), EntrySource.device));
        case HealthDataType.BLOOD_GLUCOSE:
          out.add(single(p, MetricType.glucose, v.roundToDouble(), EntrySource.device));
        case HealthDataType.BLOOD_PRESSURE_SYSTOLIC:
          systolic[p.dateFrom.millisecondsSinceEpoch] = p;
        case HealthDataType.BLOOD_PRESSURE_DIASTOLIC:
          diastolic[p.dateFrom.millisecondsSinceEpoch] = p;
        default:
          break;
      }
    }

    // Blood pressure arrives as two separate samples sharing a timestamp.
    for (final entry in systolic.entries) {
      final d = diastolic[entry.key];
      final s = entry.value;
      final sv = _numeric(s);
      final dv = d == null ? null : _numeric(d);
      if (sv == null || dv == null) continue;
      out.add(Entry(
        id: newId(),
        type: MetricType.bp,
        at: s.dateFrom,
        source: EntrySource.device,
        sys: sv.round(),
        dia: dv.round(),
        externalId: 'hc:bp:${s.uuid}',
      ));
    }
    return out;
  }

  static double? _numeric(HealthDataPoint p) {
    final value = p.value;
    if (value is NumericHealthValue) return value.numericValue.toDouble();
    return null;
  }

  static double _r1(double v) => (v * 10).round() / 10;
}
