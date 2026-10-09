import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/repository.dart';
import '../domain/format.dart';
import '../domain/records.dart';
import '../domain/sample_data.dart';
import '../models/entry.dart';
import '../models/metric.dart';
import '../models/settings.dart';
import '../services/health_sync_service.dart';
import '../services/notification_service.dart';

class AppState {
  const AppState({required this.entries, required this.settings});

  /// Always sorted oldest → newest.
  final List<Entry> entries;
  final AppSettings settings;

  AppState copyWith({List<Entry>? entries, AppSettings? settings}) =>
      AppState(entries: entries ?? this.entries, settings: settings ?? this.settings);
}

/// Both are overridden in main() once the database is open.
final repositoryProvider = Provider<Repository>((ref) => throw UnimplementedError());
final initialStateProvider = Provider<AppState>((ref) => throw UnimplementedError());

final appProvider = NotifierProvider<AppController, AppState>(AppController.new);

/// UI navigation state.
final tabProvider = StateProvider<int>((ref) => 0);
final trendTypeProvider = StateProvider<MetricType>((ref) => MetricType.bp);
final recordTypeProvider = StateProvider<MetricType>((ref) => MetricType.bp);

List<Entry> _sorted(List<Entry> xs) => xs..sort((a, b) => a.at.compareTo(b.at));

class AppController extends Notifier<AppState> {
  Repository get _repo => ref.read(repositoryProvider);

  @override
  AppState build() => ref.read(initialStateProvider);

  Future<void> _saveSettings(AppSettings s) async {
    state = state.copyWith(settings: s);
    await _repo.saveSettings(s);
  }

  /// Sample data is removed the moment real data arrives. Returns true if it was.
  Future<bool> _leaveSample() async {
    if (!state.settings.isSample) return false;
    await _repo.clearEntries();
    state = state.copyWith(entries: const []);
    await _saveSettings(state.settings.copyWith(
      isSample: false,
      goals: state.settings.goals.withStarts(),
      resetLastSync: true,
    ));
    return true;
  }

  Future<bool> addEntry(Entry e) async {
    final cleared = await _leaveSample();
    await _repo.insertEntry(e);
    state = state.copyWith(entries: _sorted([...state.entries, e]));
    return cleared;
  }

  Future<void> deleteEntry(String id) async {
    await _repo.deleteEntry(id);
    state = state.copyWith(entries: state.entries.where((e) => e.id != id).toList());
  }

  Future<void> loadSample() async {
    await _repo.clearEntries();
    final es = generateSampleEntries();
    await _repo.insertEntries(es);
    state = state.copyWith(entries: es);
    await _saveSettings(state.settings.copyWith(
      isSample: true,
      goals: state.settings.goals.withStarts(),
      resetLastSync: true,
    ));
  }

  /// Deletes every record. Health readings come back on the next sync.
  Future<void> clearAll() async {
    await _repo.clearEntries();
    state = state.copyWith(entries: const []);
    await _saveSettings(state.settings.copyWith(
      isSample: false,
      goals: state.settings.goals.withStarts(),
      resetLastSync: true,
    ));
  }

  Future<void> finishOnboarding({required bool sample}) async {
    if (sample) await loadSample();
    await _saveSettings(state.settings.copyWith(onboarded: true));
    await NotificationService.schedule(state.settings.reminders);
  }

  Future<void> setProfile(Profile p) => _saveSettings(state.settings.copyWith(profile: p));

  Future<void> setGoals(Goals g) => _saveSettings(state.settings.copyWith(goals: g));

  /// Changing a weight / body-fat target restarts progress from today's value.
  Future<void> setValueGoal(MetricType type, double target) {
    final g = state.settings.goals;
    final current = latest(state.entries, type)?.value;
    final next = type == MetricType.weight
        ? g.copyWith(weightTarget: target).withStarts(weight: current, fat: g.fatStart)
        : g.copyWith(fatTarget: target).withStarts(weight: g.weightStart, fat: current);
    return setGoals(next);
  }

  Future<void> updateReminder(Reminder r) async {
    final list = [for (final x in state.settings.reminders) x.id == r.id ? r : x];
    await _saveSettings(state.settings.copyWith(reminders: list));
    await NotificationService.schedule(list);
  }

  Future<void> setReportNote(String v) => _saveSettings(state.settings.copyWith(reportNote: v));

  Future<void> setHealthEnabled(bool v) => _saveSettings(state.settings.copyWith(healthEnabled: v));

  Future<int>? _inFlightSync;

  /// Pulls new readings from Apple Health / Health Connect. Returns how many were added.
  /// Concurrent callers share one sync, so readings are never added twice.
  Future<int> syncHealth() =>
      _inFlightSync ??= _syncHealth().whenComplete(() => _inFlightSync = null);

  Future<int> _syncHealth() async {
    final since = state.settings.lastSync?.subtract(const Duration(days: 1)) ?? daysAgo(90);
    final fetched = await HealthSyncService.instance.fetch(since);
    final known = state.entries.map((e) => e.externalId).whereType<String>().toSet();
    final fresh = <Entry>[];
    for (final e in fetched) {
      final id = e.externalId;
      if (id != null && known.add(id)) fresh.add(e);
    }
    if (fresh.isNotEmpty) {
      // Real readings replace the sample data, but an empty sync leaves it alone.
      await _leaveSample();
      await _repo.insertEntries(fresh);
      state = state.copyWith(entries: _sorted([...state.entries, ...fresh]));
    }
    await _saveSettings(state.settings.copyWith(lastSync: DateTime.now()));
    return fresh.length;
  }
}
