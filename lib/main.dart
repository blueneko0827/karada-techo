import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'data/database.dart';
import 'data/repository.dart';
import 'domain/sample_data.dart';
import 'services/notification_service.dart';
import 'state/providers.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final repo = Repository(await AppDatabase.open());
  final settings = await repo.loadSettings();
  var entries = await repo.loadEntries();

  // Sample data is regenerated on each launch so its dates stay current.
  if (settings.isSample) {
    await repo.clearEntries();
    entries = generateSampleEntries();
    await repo.insertEntries(entries);
  }

  await NotificationService.init();
  if (settings.onboarded) {
    await NotificationService.schedule(settings.reminders);
  }

  runApp(
    ProviderScope(
      overrides: [
        repositoryProvider.overrideWithValue(repo),
        initialStateProvider.overrideWithValue(AppState(entries: entries, settings: settings)),
      ],
      child: const KaradaApp(),
    ),
  );
}
