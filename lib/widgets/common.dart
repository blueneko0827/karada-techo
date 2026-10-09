import 'package:flutter/material.dart';

import '../domain/classify.dart';
import '../domain/format.dart';
import '../theme/palette.dart';

TextStyle numStyle(double size, Color color, {FontWeight weight = FontWeight.w600}) => TextStyle(
      fontSize: size,
      color: color,
      fontWeight: weight,
      height: 1.1,
      fontFeatures: const [FontFeature.tabularFigures()],
    );

class AppCard extends StatelessWidget {
  const AppCard({super.key, required this.child, this.padding = const EdgeInsets.all(16), this.onTap});

  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final pal = context.pal;
    final radius = BorderRadius.circular(16);
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: radius,
        boxShadow: [
          BoxShadow(color: Colors.black.withAlpha(10), blurRadius: 2, offset: const Offset(0, 1)),
          BoxShadow(color: Colors.black.withAlpha(12), blurRadius: 20, offset: const Offset(0, 6)),
        ],
      ),
      child: Material(
        color: pal.surface,
        borderRadius: radius,
        child: InkWell(
          borderRadius: radius,
          onTap: onTap,
          child: Padding(padding: padding, child: child),
        ),
      ),
    );
  }
}

class SectionHeader extends StatelessWidget {
  const SectionHeader({super.key, required this.title, this.aux});

  final String title;
  final String? aux;

  @override
  Widget build(BuildContext context) {
    final pal = context.pal;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Text(title, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: pal.ink)),
          ),
          if (aux != null) Text(aux!, style: TextStyle(fontSize: 12.5, color: pal.ink3)),
        ],
      ),
    );
  }
}

class StatusChip extends StatelessWidget {
  const StatusChip(this.status, {super.key, this.gold = false});

  final Status status;
  final bool gold;

  @override
  Widget build(BuildContext context) {
    final pal = context.pal;
    final bg = gold ? pal.goldSoft : pal.levelSoft(status.level);
    final fg = gold ? pal.goldInk : pal.level(status.level);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(99)),
      child: Text(status.label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: fg)),
    );
  }
}

class Dot extends StatelessWidget {
  const Dot(this.color, {super.key, this.size = 8});

  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      );
}

class TipBox extends StatelessWidget {
  const TipBox({super.key, required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final pal = context.pal;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(color: pal.surface2, borderRadius: BorderRadius.circular(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: pal.ink)),
          const SizedBox(height: 2),
          DefaultTextStyle.merge(style: TextStyle(fontSize: 12.5, color: pal.ink2, height: 1.5), child: child),
        ],
      ),
    );
  }
}

/// Segmented control filling the width.
class Seg<T> extends StatelessWidget {
  const Seg({super.key, required this.value, required this.options, required this.onChanged});

  final T value;
  final List<(T, String)> options;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) => SizedBox(
        width: double.infinity,
        child: SegmentedButton<T>(
          showSelectedIcon: false,
          style: const ButtonStyle(visualDensity: VisualDensity.compact),
          segments: [for (final o in options) ButtonSegment<T>(value: o.$1, label: Text(o.$2))],
          selected: {value},
          onSelectionChanged: (s) => onChanged(s.first),
        ),
      );
}

const String disclaimerText =
    '表示される内容は、記録された値と一般的な目安にもとづく情報です。医学的な診断ではありません。気になる症状があるときは医療機関に相談してください。';

void showSnack(BuildContext context, String message) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
  );
}

Future<bool> confirmDialog(
  BuildContext context, {
  required String title,
  required String body,
  required String action,
  bool destructive = false,
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: Text(body),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('やめる')),
        FilledButton(
          style: destructive ? FilledButton.styleFrom(backgroundColor: ctx.pal.alert) : null,
          onPressed: () => Navigator.pop(ctx, true),
          child: Text(action),
        ),
      ],
    ),
  );
  return result ?? false;
}

Future<double?> numberDialog(
  BuildContext context, {
  required String title,
  required String unit,
  required double min,
  required double max,
  double? initial,
  int decimals = 1,
}) {
  final controller = TextEditingController(text: initial == null ? '' : fmtNum(initial, decimals));
  String? error;
  return showDialog<double>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setInner) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: TextInputType.numberWithOptions(decimal: decimals > 0),
          decoration: InputDecoration(suffixText: unit, errorText: error),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('やめる')),
          FilledButton(
            onPressed: () {
              final v = double.tryParse(normalizeNum(controller.text));
              if (v == null || v < min || v > max) {
                setInner(() => error = '${fmtNum(min, 0)}〜${fmtNum(max, 0)} の範囲で入力してください');
                return;
              }
              Navigator.pop(ctx, v);
            },
            child: const Text('保存'),
          ),
        ],
      ),
    ),
  );
}

Future<String?> textDialog(BuildContext context, {required String title, String initial = '', int maxLength = 20}) {
  final controller = TextEditingController(text: initial);
  return showDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: TextField(controller: controller, autofocus: true, maxLength: maxLength),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('やめる')),
        FilledButton(onPressed: () => Navigator.pop(ctx, controller.text.trim()), child: const Text('保存')),
      ],
    ),
  );
}
