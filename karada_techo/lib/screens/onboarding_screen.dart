import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/notification_service.dart';
import '../state/providers.dart';
import '../theme/palette.dart';
import '../widgets/common.dart';
import '../widgets/logo.dart';

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  bool _busy = false;

  Future<void> _start({required bool sample}) async {
    if (_busy) return;
    setState(() => _busy = true);
    final ctrl = ref.read(appProvider.notifier);
    await NotificationService.requestPermission();
    await ctrl.finishOnboarding(sample: sample);
  }

  @override
  Widget build(BuildContext context) {
    final pal = context.pal;
    Widget feature(IconData icon, Color color, String text) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(color: color.withAlpha(30), borderRadius: BorderRadius.circular(10)),
                child: Icon(icon, size: 20, color: color),
              ),
              const SizedBox(width: 12),
              Expanded(child: Text(text, style: TextStyle(fontSize: 14, color: pal.ink, height: 1.5))),
            ],
          ),
        );

    return Scaffold(
      backgroundColor: pal.paper,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, c) => SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: c.maxHeight - 32),
              child: IntrinsicHeight(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Spacer(),
                    const Center(child: AppLogo(size: 92)),
                    const SizedBox(height: 18),
                    Text('からだ手帖',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 30, fontWeight: FontWeight.w700, color: pal.ink, letterSpacing: 2)),
                    const SizedBox(height: 8),
                    Text('毎日の測定を記録して、からだの変化をわかりやすく。',
                        textAlign: TextAlign.center, style: TextStyle(fontSize: 14.5, color: pal.ink2)),
                    const SizedBox(height: 28),
                    feature(Icons.edit_note, pal.accent, '体重・血圧・心拍数・体温・血糖値・体脂肪率をかんたんに記録'),
                    feature(Icons.pie_chart_outline, pal.ok, 'グラフと内訳で、変化と傾向がひと目でわかる'),
                    feature(Icons.flag_outlined, pal.gold, '目標とリマインダーで、測定を習慣に'),
                    feature(Icons.description_outlined, pal.mBp, '受診のときに見せられるレポートを作成'),
                    const Spacer(),
                    const SizedBox(height: 20),
                    const TipBox(
                      title: 'ご利用の前に',
                      child: Text('記録はこの端末の中だけに保存されます。表示される目安や気づきは一般的な情報で、医学的な診断ではありません。'),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      height: 52,
                      child: FilledButton(
                        onPressed: _busy ? null : () => _start(sample: false),
                        child: const Text('はじめる', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                      ),
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      height: 48,
                      child: OutlinedButton(
                        onPressed: _busy ? null : () => _start(sample: true),
                        child: const Text('サンプルデータで試してみる'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
