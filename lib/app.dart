import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'screens/home_shell.dart';
import 'screens/onboarding_screen.dart';
import 'state/providers.dart';
import 'theme/palette.dart';

class KaradaApp extends ConsumerWidget {
  const KaradaApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final onboarded = ref.watch(appProvider.select((s) => s.settings.onboarded));
    return MaterialApp(
      title: 'からだ手帖',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(Brightness.light),
      darkTheme: buildTheme(Brightness.dark),
      locale: const Locale('ja', 'JP'),
      supportedLocales: const [Locale('ja', 'JP')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: onboarded ? const _HealthAutoSync(child: HomeShell()) : const OnboardingScreen(),
    );
  }
}

/// Pulls new watch / scale / monitor readings each time the app opens,
/// and again whenever it returns to the foreground.
class _HealthAutoSync extends ConsumerStatefulWidget {
  const _HealthAutoSync({required this.child});

  final Widget child;

  @override
  ConsumerState<_HealthAutoSync> createState() => _HealthAutoSyncState();
}

class _HealthAutoSyncState extends ConsumerState<_HealthAutoSync> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _sync());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _sync();
  }

  Future<void> _sync() async {
    if (!mounted || !ref.read(appProvider).settings.healthEnabled) return;
    try {
      await ref.read(appProvider.notifier).syncHealth();
    } catch (e) {
      debugPrint('Background health sync failed: $e');
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
