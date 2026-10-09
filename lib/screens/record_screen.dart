import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/format.dart';
import '../domain/records.dart';
import '../models/entry.dart';
import '../models/metric.dart';
import '../state/providers.dart';
import '../theme/palette.dart';
import '../widgets/common.dart';
import 'settings_screen.dart';

class RecordScreen extends ConsumerStatefulWidget {
  const RecordScreen({super.key});

  @override
  ConsumerState<RecordScreen> createState() => _RecordScreenState();
}

class _RecordScreenState extends ConsumerState<RecordScreen> {
  final Map<String, TextEditingController> _controllers = {};
  final TextEditingController _note = TextEditingController();
  DateTime _at = DateTime.now();
  GlucoseTiming _timing = GlucoseTiming.fasting;
  String? _error;
  MetricType? _shownType;
  bool _saving = false;

  TextEditingController _c(String key) => _controllers.putIfAbsent(key, TextEditingController.new);

  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    _note.dispose();
    super.dispose();
  }

  void _resetFields() {
    for (final c in _controllers.values) {
      c.clear();
    }
    _note.clear();
    _at = DateTime.now();
    _error = null;
  }

  Future<void> _pickDate() async {
    final d = await showDatePicker(
      context: context,
      initialDate: _at,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
    );
    if (d == null || !mounted) return;
    setState(() => _at = DateTime(d.year, d.month, d.day, _at.hour, _at.minute));
  }

  Future<void> _pickTime() async {
    final t = await showTimePicker(context: context, initialTime: TimeOfDay.fromDateTime(_at));
    if (t == null || !mounted) return;
    setState(() => _at = DateTime(_at.year, _at.month, _at.day, t.hour, t.minute));
  }

  void _fail(String message) => setState(() => _error = message);

  Future<void> _save(MetricType type) async {
    if (_saving) return;
    final info = infoOf(type);
    final values = <String, double>{};
    for (final f in info.fields) {
      final raw = normalizeNum(_c(f.key).text);
      if (raw.isEmpty) {
        if (f.optional) continue;
        _fail('${f.label}を入力してください');
        return;
      }
      final v = double.tryParse(raw);
      if (v == null || v < f.min || v > f.max) {
        _fail('${f.label}は ${fmtNum(f.min, 0)}〜${fmtNum(f.max, 0)} ${f.unit} の範囲で入力してください');
        return;
      }
      values[f.key] = f.decimals > 0 ? (v * 10).round() / 10 : v.roundToDouble();
    }
    if (type == MetricType.bp && values['sys']! <= values['dia']!) {
      _fail('最高血圧には、最低血圧より大きい値を入力してください');
      return;
    }
    if (_at.isAfter(DateTime.now().add(const Duration(minutes: 1)))) {
      _fail('これから先の日時は記録できません');
      return;
    }
    final note = _note.text.trim();
    final entry = Entry(
      id: newId(),
      type: type,
      at: _at,
      source: EntrySource.manual,
      value: type == MetricType.bp ? null : values['v'],
      sys: values['sys']?.round(),
      dia: values['dia']?.round(),
      pulse: values['pulse']?.round(),
      timing: type == MetricType.glucose ? _timing : null,
      note: note.isEmpty ? null : (note.length > 200 ? note.substring(0, 200) : note),
    );

    final ctrl = ref.read(appProvider.notifier);
    final tabs = ref.read(tabProvider.notifier);
    final messenger = ScaffoldMessenger.of(context);
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final cleared = await ctrl.addEntry(entry);
      messenger.showSnackBar(SnackBar(
        behavior: SnackBarBehavior.floating,
        content: Text(cleared ? 'サンプルデータを消去して、${info.label}を記録しました' : '${info.label}を記録しました'),
      ));
      tabs.state = 0;
    } catch (e) {
      if (mounted) _fail('保存できませんでした。もう一度お試しください（$e）');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final type = ref.watch(recordTypeProvider);
    final entries = ref.watch(appProvider.select((s) => s.entries));
    final pal = context.pal;
    final info = infoOf(type);
    final last = latest(entries, type);

    if (_shownType != type) {
      _shownType = type;
      _resetFields();
    }

    String hint(FieldSpec f) {
      if (last == null) return '';
      final v = switch (f.key) {
        'sys' => last.sys?.toDouble(),
        'dia' => last.dia?.toDouble(),
        'pulse' => last.pulse?.toDouble(),
        _ => last.value,
      };
      return v == null ? '' : fmtNum(v, f.decimals);
    }

    Widget field(FieldSpec f) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text.rich(
              TextSpan(children: [
                TextSpan(text: f.label),
                if (f.optional) TextSpan(text: '（任意）', style: TextStyle(fontWeight: FontWeight.w400, color: pal.ink3)),
              ]),
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: pal.ink2),
            ),
            const SizedBox(height: 6),
            TextField(
              controller: _c(f.key),
              keyboardType: TextInputType.numberWithOptions(decimal: f.decimals > 0),
              style: numStyle(24, pal.ink),
              decoration: _inputDecoration(pal, hint: hint(f), suffix: f.unit),
            ),
          ],
        );

    final fields = info.fields.map(field).toList();

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 28),
      children: [
        Row(
          children: [
            Expanded(child: Text('記録する', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: pal.ink))),
            Text(last == null ? 'はじめての記録' : '前回 ${fmtMD(last.at)} ${fmtTime(last.at)}',
                style: TextStyle(fontSize: 12.5, color: pal.ink3)),
          ],
        ),
        const SizedBox(height: 10),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              for (final t in MetricType.values)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    showCheckmark: false,
                    avatar: Dot(pal.metric(t)),
                    label: Text(infoOf(t).label),
                    selected: t == type,
                    onSelected: (_) => ref.read(recordTypeProvider.notifier).state = t,
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        if (type == MetricType.bp) ...[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: fields[0]),
              const SizedBox(width: 10),
              Expanded(child: fields[1]),
            ],
          ),
          const SizedBox(height: 14),
          fields[2],
        ] else
          ...fields,
        if (type == MetricType.glucose) ...[
          const SizedBox(height: 14),
          Text('測ったタイミング', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: pal.ink2)),
          const SizedBox(height: 6),
          Seg<GlucoseTiming>(
            value: _timing,
            options: [for (final t in GlucoseTiming.values) (t, glucoseTimingLabel[t]!)],
            onChanged: (v) => setState(() => _timing = v),
          ),
        ],
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(child: _PickerTile(label: '日付', value: fmtJP(_at), onTap: _pickDate)),
            const SizedBox(width: 10),
            Expanded(child: _PickerTile(label: '時刻', value: fmtTime(_at), onTap: _pickTime)),
          ],
        ),
        const SizedBox(height: 14),
        Text('メモ（任意）', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: pal.ink2)),
        const SizedBox(height: 6),
        TextField(
          controller: _note,
          maxLength: 200,
          decoration: _inputDecoration(pal, hint: '体調、服薬、食事など'),
        ),
        const SizedBox(height: 6),
        TipBox(title: '測り方のポイント', child: Text(info.tip)),
        if (info.autoNote != null) ...[
          const SizedBox(height: 10),
          TipBox(
            title: '自動で記録',
            child: Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text('${info.autoNote}。'),
                InkWell(
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(builder: (_) => const SettingsScreen()),
                  ),
                  child: Text('連携の設定',
                      style: TextStyle(color: pal.accent, fontWeight: FontWeight.w700, decoration: TextDecoration.underline)),
                ),
              ],
            ),
          ),
        ],
        if (_error != null) ...[
          const SizedBox(height: 12),
          Text(_error!, style: TextStyle(color: pal.alert, fontWeight: FontWeight.w700, fontSize: 13)),
        ],
        const SizedBox(height: 16),
        SizedBox(
          height: 52,
          child: FilledButton(
            style: FilledButton.styleFrom(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
            onPressed: _saving ? null : () => _save(type),
            child: Text('${info.label}を保存', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          ),
        ),
      ],
    );
  }
}

InputDecoration _inputDecoration(Palette pal, {String hint = '', String? suffix}) => InputDecoration(
      hintText: hint.isEmpty ? null : hint,
      hintStyle: TextStyle(color: pal.ink3.withAlpha(140)),
      suffixText: suffix,
      suffixStyle: TextStyle(fontSize: 13, color: pal.ink3),
      filled: true,
      fillColor: pal.surface,
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: pal.line),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: pal.accent, width: 1.5),
      ),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
    );

class _PickerTile extends StatelessWidget {
  const _PickerTile({required this.label, required this.value, required this.onTap});

  final String label;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final pal = context.pal;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: pal.ink2)),
        const SizedBox(height: 6),
        Material(
          color: pal.surface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: pal.line)),
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
              child: Row(
                children: [
                  Expanded(child: Text(value, style: TextStyle(fontSize: 15, color: pal.ink))),
                  Icon(Icons.expand_more, size: 18, color: pal.ink3),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
