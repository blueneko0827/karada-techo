import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/classify.dart';
import '../domain/format.dart';
import '../domain/records.dart';
import '../models/entry.dart';
import '../models/metric.dart';
import '../models/settings.dart';
import '../state/providers.dart';
import '../theme/palette.dart';
import '../widgets/common.dart';

class GoalsScreen extends ConsumerWidget {
  const GoalsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final st = ref.watch(appProvider);
    final pal = context.pal;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 28),
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(child: Text('目標', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: pal.ink))),
            Text('数字は自分のペースで設定できます', style: TextStyle(fontSize: 12.5, color: pal.ink3)),
          ],
        ),
        const SizedBox(height: 12),
        _ValueGoalCard(type: MetricType.weight, entries: st.entries, goals: st.settings.goals),
        const SizedBox(height: 12),
        _BpGoalCard(entries: st.entries, goals: st.settings.goals),
        const SizedBox(height: 12),
        _HabitCard(entries: st.entries, goals: st.settings.goals),
        const SizedBox(height: 12),
        _ValueGoalCard(type: MetricType.fat, entries: st.entries, goals: st.settings.goals),
      ],
    );
  }
}

const Status _achieved = Status(Level.ok, '達成');

class _GoalBar extends StatelessWidget {
  const _GoalBar(this.progress);

  final double progress;

  @override
  Widget build(BuildContext context) {
    final pal = context.pal;
    return ClipRRect(
      borderRadius: BorderRadius.circular(99),
      child: LinearProgressIndicator(
        value: progress.clamp(0.0, 1.0),
        minHeight: 10,
        backgroundColor: pal.surface2,
        color: pal.gold,
      ),
    );
  }
}

class _ValueGoalCard extends ConsumerWidget {
  const _ValueGoalCard({required this.type, required this.entries, required this.goals});

  final MetricType type;
  final List<Entry> entries;
  final Goals goals;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pal = context.pal;
    final info = infoOf(type);
    final current = latest(entries, type)?.value;
    final target = type == MetricType.weight ? goals.weightTarget : goals.fatTarget;
    final start = goalStart(entries, type, goals);

    Widget editButton() => TextButton.icon(
          icon: const Icon(Icons.edit_outlined, size: 16),
          label: const Text('目標を変更'),
          onPressed: () async {
            final ctrl = ref.read(appProvider.notifier);
            final v = await numberDialog(
              context,
              title: '${info.label}の目標',
              unit: info.unit,
              min: type == MetricType.weight ? 20 : 3,
              max: type == MetricType.weight ? 250 : 70,
              initial: target,
            );
            if (v != null) await ctrl.setValueGoal(type, (v * 10).round() / 10);
          },
        );

    if (current == null || start == null) {
      return AppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${info.label}の目標', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: pal.ink)),
            const SizedBox(height: 6),
            Text('目標 ${target.toStringAsFixed(1)} ${info.unit}。${info.label}を記録すると進み具合が表示されます。',
                style: TextStyle(fontSize: 13, color: pal.ink3)),
            Align(alignment: Alignment.centerRight, child: editButton()),
          ],
        ),
      );
    }

    final span = target - start;
    final progress = span == 0 ? 1.0 : (current - start) / span;
    final remaining = target - current;
    final done = span == 0 || (span < 0 ? current <= target : current >= target);

    String? pace;
    if (done) {
      pace = '目標に到達しています。この調子で続けましょう。';
    } else {
      final slope = slopePerDay(ofType(entries, type, from: daysAgo(27)));
      if (slope != null) {
        final toward = (remaining < 0 && slope < 0) || (remaining > 0 && slope > 0);
        if (toward && slope.abs() > 0.002) {
          final weeks = ((remaining / slope).abs() / 7).ceil();
          pace = weeks <= 52 ? 'この4週間のペースが続くと、あと約$weeks週間で目標に届く見込みです。' : 'この4週間は変化がゆるやかです。';
        } else {
          pace = 'この4週間は、目標とは逆の方向か横ばいで推移しています。';
        }
      }
    }

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text('${info.label}の目標',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: pal.ink)),
              ),
              done
                  ? const StatusChip(_achieved, gold: true)
                  : StatusChip(Status(Level.plain, 'あと ${remaining.abs().toStringAsFixed(1)} ${info.unit}')),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            crossAxisAlignment: WrapCrossAlignment.end,
            spacing: 6,
            children: [
              Text(current.toStringAsFixed(1), style: numStyle(30, pal.ink)),
              Padding(
                padding: const EdgeInsets.only(bottom: 3),
                child: Text('${info.unit} → 目標 ${target.toStringAsFixed(1)} ${info.unit}',
                    style: TextStyle(fontSize: 13, color: pal.ink3)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _GoalBar(progress),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(child: Text('開始 ${start.toStringAsFixed(1)} ${info.unit}', style: TextStyle(fontSize: 12.5, color: pal.ink3))),
              Text('${(progress.clamp(0.0, 1.0) * 100).round()}%', style: numStyle(13, pal.ink2)),
            ],
          ),
          if (pace != null) ...[
            const SizedBox(height: 10),
            Text(pace, style: TextStyle(fontSize: 13, color: pal.ink2)),
          ],
          Align(alignment: Alignment.centerRight, child: editButton()),
        ],
      ),
    );
  }
}

class _BpGoalCard extends ConsumerWidget {
  const _BpGoalCard({required this.entries, required this.goals});

  final List<Entry> entries;
  final Goals goals;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pal = context.pal;
    final a = bpAvg(entries, from: daysAgo(6), slot: BpSlot.morning);
    final done = a != null && a.sys < goals.bpSys && a.dia < goals.bpDia;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text('朝の血圧の目標', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: pal.ink)),
              ),
              if (a != null)
                done
                    ? const StatusChip(_achieved, gold: true)
                    : const StatusChip(Status(Level.plain, '取り組み中')),
            ],
          ),
          const SizedBox(height: 10),
          if (a == null)
            Text('朝の血圧を記録すると、7日平均と比べられます。目標 ${goals.bpSys}/${goals.bpDia} mmHg 未満。',
                style: TextStyle(fontSize: 13, color: pal.ink3))
          else ...[
            Wrap(
              crossAxisAlignment: WrapCrossAlignment.end,
              spacing: 6,
              children: [
                Text('${a.sys}/${a.dia}', style: numStyle(30, pal.ink)),
                Padding(
                  padding: const EdgeInsets.only(bottom: 3),
                  child: Text('mmHg（7日平均）→ 目標 ${goals.bpSys}/${goals.bpDia} 未満',
                      style: TextStyle(fontSize: 13, color: pal.ink3)),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              done
                  ? '7日平均が目標を下回っています。'
                  : '目標まで、最高血圧はあと ${(a.sys - goals.bpSys + 1).clamp(0, 999)}、'
                      '最低血圧はあと ${(a.dia - goals.bpDia + 1).clamp(0, 999)} mmHg です。',
              style: TextStyle(fontSize: 13, color: pal.ink2),
            ),
          ],
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              icon: const Icon(Icons.edit_outlined, size: 16),
              label: const Text('目標を変更'),
              onPressed: () async {
                final ctrl = ref.read(appProvider.notifier);
                final result = await _bpGoalDialog(context, goals.bpSys, goals.bpDia);
                if (result != null) {
                  await ctrl.setGoals(goals.copyWith(bpSys: result.$1, bpDia: result.$2));
                }
              },
            ),
          ),
        ],
      ),
    );
  }
}

Future<(int, int)?> _bpGoalDialog(BuildContext context, int sys, int dia) {
  final sc = TextEditingController(text: '$sys');
  final dc = TextEditingController(text: '$dia');
  String? error;
  return showDialog<(int, int)>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setInner) => AlertDialog(
        title: const Text('朝の血圧の目標'),
        content: Row(
          children: [
            Expanded(
              child: TextField(
                controller: sc,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: '最高'),
              ),
            ),
            const Padding(padding: EdgeInsets.symmetric(horizontal: 8), child: Text('/')),
            Expanded(
              child: TextField(
                controller: dc,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(labelText: '最低', errorText: error, suffixText: 'mmHg'),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('やめる')),
          FilledButton(
            onPressed: () {
              final s = int.tryParse(normalizeNum(sc.text));
              final d = int.tryParse(normalizeNum(dc.text));
              if (s == null || d == null || s < 90 || s > 180 || d < 50 || d > 110 || s <= d) {
                setInner(() => error = '90〜180 / 50〜110');
                return;
              }
              Navigator.pop(ctx, (s, d));
            },
            child: const Text('保存'),
          ),
        ],
      ),
    ),
  );
}

class _HabitCard extends ConsumerWidget {
  const _HabitCard({required this.entries, required this.goals});

  final List<Entry> entries;
  final Goals goals;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pal = context.pal;
    final today = startOfDay(DateTime.now());
    final days = [
      for (var i = 6; i >= 0; i--) DateTime(today.year, today.month, today.day - i),
    ];
    bool measured(DateTime d) {
      final next = DateTime(d.year, d.month, d.day + 1);
      return entries.any((e) =>
          e.type == MetricType.bp && !e.at.isBefore(d) && e.at.isBefore(next) && slotOf(e.at) == BpSlot.morning);
    }

    final hits = days.where(measured).length;
    final done = hits >= goals.habitDays;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text('測定の習慣', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: pal.ink))),
              done
                  ? const StatusChip(_achieved, gold: true)
                  : StatusChip(Status(Level.plain, '$hits / ${goals.habitDays}日')),
            ],
          ),
          const SizedBox(height: 6),
          Text('朝の血圧を、1週間に${goals.habitDays}日測る', style: TextStyle(fontSize: 13, color: pal.ink2)),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              for (final d in days)
                Column(
                  children: [
                    Container(
                      width: 30,
                      height: 30,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: measured(d) ? pal.mBp : null,
                        border: Border.all(
                          color: d == today ? pal.accent : (measured(d) ? pal.mBp : pal.line),
                          width: 2,
                        ),
                      ),
                      child: measured(d) ? Icon(Icons.check, size: 15, color: pal.surface) : null,
                    ),
                    const SizedBox(height: 4),
                    Text(weekdayJp(d), style: TextStyle(fontSize: 11, color: pal.ink3)),
                  ],
                ),
            ],
          ),
          const SizedBox(height: 12),
          Text('目標の日数', style: TextStyle(fontSize: 12.5, color: pal.ink3)),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            children: [
              for (final n in [3, 4, 5, 6, 7])
                ChoiceChip(
                  label: Text('$n日'),
                  selected: goals.habitDays == n,
                  onSelected: (_) => ref.read(appProvider.notifier).setGoals(goals.copyWith(habitDays: n)),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
