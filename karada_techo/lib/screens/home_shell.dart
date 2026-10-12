import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/format.dart';
import '../state/providers.dart';
import '../theme/palette.dart';
import '../widgets/common.dart';
import '../widgets/logo.dart';
import 'goals_screen.dart';
import 'home_screen.dart';
import 'record_screen.dart';
import 'report_screen.dart';
import 'settings_screen.dart';
import 'trend_screen.dart';

class HomeShell extends ConsumerWidget {
  const HomeShell({super.key});

  static const List<Widget> _pages = [
    HomeScreen(),
    TrendScreen(),
    RecordScreen(),
    GoalsScreen(),
    ReportScreen(),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tab = ref.watch(tabProvider);
    final isSample = ref.watch(appProvider.select((s) => s.settings.isSample));
    final pal = context.pal;

    return Scaffold(
      backgroundColor: pal.paper,
      appBar: AppBar(
        backgroundColor: pal.paper,
        surfaceTintColor: Colors.transparent,
        scrolledUnderElevation: 0,
        titleSpacing: 16,
        title: Row(
          children: [
            const AppLogo(size: 30),
            const SizedBox(width: 9),
            Text('からだ手帖',
                style: TextStyle(fontSize: 19, fontWeight: FontWeight.w700, color: pal.ink, letterSpacing: 0.6)),
            const SizedBox(width: 10),
            Flexible(
              child: Text(fmtJP(DateTime.now()),
                  overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12.5, color: pal.ink3)),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: '設定',
            icon: Icon(Icons.settings_outlined, color: pal.ink2),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const SettingsScreen()),
            ),
          ),
          const SizedBox(width: 6),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Divider(height: 1, thickness: 1, color: pal.line),
        ),
      ),
      body: Column(
        children: [
          if (isSample) const SampleBanner(),
          Expanded(child: _pages[tab]),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: tab,
        backgroundColor: pal.surface,
        indicatorColor: pal.accentSoft,
        onDestinationSelected: (i) => ref.read(tabProvider.notifier).state = i,
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home), label: 'ホーム'),
          NavigationDestination(icon: Icon(Icons.show_chart), label: '推移'),
          NavigationDestination(
              icon: Icon(Icons.add_circle_outline), selectedIcon: Icon(Icons.add_circle), label: '記録'),
          NavigationDestination(
              icon: Icon(Icons.track_changes_outlined), selectedIcon: Icon(Icons.track_changes), label: '目標'),
          NavigationDestination(
              icon: Icon(Icons.description_outlined), selectedIcon: Icon(Icons.description), label: 'レポート'),
        ],
      ),
    );
  }
}

class SampleBanner extends ConsumerWidget {
  const SampleBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pal = context.pal;
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      padding: const EdgeInsets.fromLTRB(14, 2, 4, 2),
      decoration: BoxDecoration(color: pal.accentSoft, borderRadius: BorderRadius.circular(12)),
      child: Row(
        children: [
          Expanded(child: Text('サンプルデータを表示中です', style: TextStyle(fontSize: 13, color: pal.ink))),
          TextButton(
            onPressed: () async {
              final ctrl = ref.read(appProvider.notifier);
              final tabs = ref.read(tabProvider.notifier);
              final ok = await confirmDialog(
                context,
                title: '自分のデータで始めますか？',
                body: 'サンプルデータを消去して、空の状態から記録を始めます。',
                action: 'はじめる',
              );
              if (!ok) return;
              tabs.state = 2;
              await ctrl.clearAll();
            },
            child: const Text('自分のデータで始める'),
          ),
        ],
      ),
    );
  }
}
