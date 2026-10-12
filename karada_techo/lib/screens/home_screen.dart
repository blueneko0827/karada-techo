import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/format.dart';
import '../domain/insights.dart';
import '../domain/records.dart';
import '../models/entry.dart';
import '../models/metric.dart';
import '../models/settings.dart';
import '../state/providers.dart';
import '../theme/palette.dart';
import '../widgets/charts.dart';
import '../widgets/common.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final st = ref.watch(appProvider);
    final all = st.entries;
    final s = st.settings;
    final pal = context.pal;

    final now = DateTime.now();
    final h = now.hour;
    final greet = h < 4 ? 'こんばんは' : (h < 11 ? 'おはようございます' : (h < 18 ? 'こんにちは' : 'こんばんは'));
    final name = s.profile.name.isEmpty ? '' : '${s.profile.name}さん、';
    final t0 = startOfDay(now);

    final checks = [
      for (final r in s.reminders.where((r) => r.enabled))
        (r, firstWhereOr<Entry>(ofType(all, r.type, from: t0), (e) => r.slot == null || slotOf(e.at) == r.slot)),
    ];
    final doneCount = checks.where((c) => c.$2 != null).length;
    final streakDays = streak(all);
    final bpMorning = ofType(all, MetricType.bp, from: daysAgo(29)).where((e) => slotOf(e.at) == BpSlot.morning).toList();
    final insights = buildInsights(all);

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('$name$greet', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: pal.ink)),
                  const SizedBox(height: 2),
                  Text(fmtJP(now), style: TextStyle(fontSize: 13.5, color: pal.ink2)),
                ],
              ),
            ),
            if (streakDays > 0)
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text('$streakDays', style: numStyle(26, pal.goldInk)),
                  const SizedBox(width: 4),
                  Text('日連続で記録', style: TextStyle(fontSize: 12.5, color: pal.ink2)),
                ],
              ),
          ],
        ),
        const SizedBox(height: 20),
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SectionHeader(title: '今日の測定', aux: '$doneCount / ${checks.length}'),
              if (checks.isEmpty)
                Text('リマインダーがオフになっています。設定から測定の時間を登録できます。',
                    style: TextStyle(fontSize: 13, color: pal.ink3))
              else ...[
                ClipRRect(
                  borderRadius: BorderRadius.circular(99),
                  child: LinearProgressIndicator(
                    value: doneCount / checks.length,
                    minHeight: 6,
                    backgroundColor: pal.surface2,
                    color: pal.ok,
                  ),
                ),
                const SizedBox(height: 6),
                for (var i = 0; i < checks.length; i++)
                  _CheckRow(reminder: checks[i].$1, done: checks[i].$2, showDivider: i > 0),
              ],
            ],
          ),
        ),
        const SizedBox(height: 22),
        const SectionHeader(title: '最新の値', aux: 'タップで推移を表示'),
        for (var i = 0; i < MetricType.values.length; i += 2)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(child: MetricCard(type: MetricType.values[i])),
                  const SizedBox(width: 10),
                  Expanded(child: MetricCard(type: MetricType.values[i + 1])),
                ],
              ),
            ),
          ),
        if (bpMorning.isNotEmpty) ...[
          const SizedBox(height: 12),
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SectionHeader(title: '朝の血圧の分類', aux: '直近30日・${bpMorning.length}回'),
                PieBlock(groups: groupsOf(bpMorning, MetricType.bp), semanticLabel: '朝の血圧の分類（直近30日）'),
                const SizedBox(height: 10),
                Text('日本高血圧学会の家庭血圧の分類で、1回ずつの測定値を振り分けた割合です。',
                    style: TextStyle(fontSize: 12, color: pal.ink3)),
              ],
            ),
          ),
        ],
        const SizedBox(height: 22),
        const SectionHeader(title: '今週の気づき'),
        if (insights.isEmpty)
          AppCard(
            child: Text('記録が増えると、ここに傾向や気づきが表示されます。',
                textAlign: TextAlign.center, style: TextStyle(color: pal.ink3)),
          )
        else
          for (final ins in insights)
            Padding(padding: const EdgeInsets.only(bottom: 10), child: _InsightCard(ins)),
        Padding(
          padding: const EdgeInsets.fromLTRB(2, 6, 2, 0),
          child: Text(disclaimerText, style: TextStyle(fontSize: 11.5, color: pal.ink3, height: 1.55)),
        ),
      ],
    );
  }
}

class _CheckRow extends ConsumerWidget {
  const _CheckRow({required this.reminder, required this.done, required this.showDivider});

  final Reminder reminder;
  final Entry? done;
  final bool showDivider;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pal = context.pal;
    final d = done;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        border: showDivider ? Border(top: BorderSide(color: pal.line)) : null,
      ),
      child: Row(
        children: [
          Container(
            width: 22,
            height: 22,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: d != null ? pal.ok : null,
              border: Border.all(color: d != null ? pal.ok : pal.line, width: 2),
            ),
            child: d != null ? Icon(Icons.check, size: 14, color: pal.surface) : null,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(reminder.label, style: TextStyle(fontWeight: FontWeight.w500, color: pal.ink)),
                Text(d != null ? '記録済み' : 'リマインダー ${reminder.timeLabel}',
                    style: TextStyle(fontSize: 12.5, color: pal.ink3)),
              ],
            ),
          ),
          if (d != null)
            Text(fmtTime(d.at), style: numStyle(13, pal.ok, weight: FontWeight.w700))
          else
            OutlinedButton(
              style: OutlinedButton.styleFrom(
                visualDensity: VisualDensity.compact,
                side: BorderSide(color: pal.line),
                shape: const StadiumBorder(),
              ),
              onPressed: () {
                ref.read(recordTypeProvider.notifier).state = reminder.type;
                ref.read(tabProvider.notifier).state = 2;
              },
              child: const Text('記録する'),
            ),
        ],
      ),
    );
  }
}

class MetricCard extends ConsumerWidget {
  const MetricCard({super.key, required this.type});

  final MetricType type;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final st = ref.watch(appProvider);
    final pal = context.pal;
    final info = infoOf(type);
    final color = pal.metric(type);
    final summary = summarize(st.entries, type, st.settings.profile);

    return AppCard(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
      onTap: () {
        ref.read(trendTypeProvider.notifier).state = type;
        ref.read(tabProvider.notifier).state = 1;
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Dot(color),
              const SizedBox(width: 6),
              Expanded(
                child: Text(info.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: pal.ink2)),
              ),
              if (summary?.status != null) StatusChip(summary!.status!),
            ],
          ),
          if (summary == null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 18),
              child: Text('まだ記録がありません', style: TextStyle(fontSize: 12.5, color: pal.ink3)),
            )
          else ...[
            const SizedBox(height: 6),
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Flexible(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(summary.value, style: numStyle(28, pal.ink)),
                  ),
                ),
                const SizedBox(width: 4),
                Text(info.unit, style: TextStyle(fontSize: 11.5, color: pal.ink3)),
              ],
            ),
            const SizedBox(height: 4),
            Sparkline(points: sparkPoints(st.entries, type), color: color),
            const SizedBox(height: 2),
            Text(summary.sub, style: TextStyle(fontSize: 11.5, color: pal.ink3, height: 1.4)),
          ],
        ],
      ),
    );
  }
}

class _InsightCard extends StatelessWidget {
  const _InsightCard(this.insight);

  final Insight insight;

  @override
  Widget build(BuildContext context) {
    final pal = context.pal;
    final icon = switch (insight.level.name) {
      'ok' => Icons.check,
      'note' => Icons.info_outline,
      _ => Icons.priority_high,
    };
    return AppCard(
      padding: const EdgeInsets.all(14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(color: pal.levelSoft(insight.level), shape: BoxShape.circle),
            child: Icon(icon, size: 16, color: pal.level(insight.level)),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(insight.title, style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700, color: pal.ink)),
                const SizedBox(height: 4),
                Text(insight.body, style: TextStyle(fontSize: 13, color: pal.ink2, height: 1.55)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
