import 'package:flutter/foundation.dart' show defaultTargetPlatform;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/format.dart';
import '../services/health_sync_service.dart';
import '../services/notification_service.dart';
import '../state/providers.dart';
import '../theme/palette.dart';
import '../widgets/common.dart';
import '../widgets/logo.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  bool _syncing = false;

  String get _healthName =>
      defaultTargetPlatform == TargetPlatform.iOS ? 'Apple ヘルスケア' : 'Health Connect';

  Future<void> _sync() async {
    if (!mounted) return;
    final ctrl = ref.read(appProvider.notifier);
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _syncing = true);
    try {
      final n = await ctrl.syncHealth();
      messenger.showSnackBar(SnackBar(
        behavior: SnackBarBehavior.floating,
        content: Text(n == 0 ? '新しい測定値はありませんでした' : '$n件の測定値を取り込みました'),
      ));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('$_healthNameから読み込めませんでした：$e')));
    } finally {
      if (mounted) setState(() => _syncing = false);
    }
  }

  Future<void> _toggleHealth(bool on) async {
    final ctrl = ref.read(appProvider.notifier);
    final messenger = ScaffoldMessenger.of(context);
    if (!on) {
      await ctrl.setHealthEnabled(false);
      return;
    }
    final access = await HealthSyncService.instance.requestAccess();
    if (access == HealthAccess.unavailable) {
      messenger.showSnackBar(SnackBar(
        content: const Text('Health Connect が見つかりません。Play ストアからインストールしてください。'),
        action: SnackBarAction(
          label: 'インストール',
          onPressed: HealthSyncService.instance.installHealthConnect,
        ),
      ));
      return;
    }
    if (access == HealthAccess.denied) {
      messenger.showSnackBar(SnackBar(
        content: Text('$_healthNameへのアクセスが許可されませんでした。端末の設定から許可を変更できます。'),
      ));
      return;
    }
    await ctrl.setHealthEnabled(true);
    if (!mounted) return;
    await _sync();
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(appProvider.select((st) => st.settings));
    final ctrl = ref.read(appProvider.notifier);
    final pal = context.pal;

    Widget group(String title, List<Widget> children) => Padding(
          padding: const EdgeInsets.only(bottom: 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(4, 0, 0, 8),
                child: Text(title,
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: 1.2, color: pal.ink3)),
              ),
              AppCard(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Column(children: children),
              ),
            ],
          ),
        );

    return Scaffold(
      backgroundColor: pal.paper,
      appBar: AppBar(
        title: const Text('設定'),
        backgroundColor: pal.paper,
        surfaceTintColor: Colors.transparent,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          group('プロフィール', [
            ListTile(
              title: const Text('お名前'),
              subtitle: const Text('レポートに表示されます'),
              trailing: Text(s.profile.name.isEmpty ? '未設定' : s.profile.name, style: TextStyle(color: pal.ink2)),
              onTap: () async {
                final v = await textDialog(context, title: 'お名前', initial: s.profile.name);
                if (v != null) await ctrl.setProfile(s.profile.copyWith(name: v));
              },
            ),
            ListTile(
              title: const Text('身長'),
              subtitle: const Text('BMIの計算に使います'),
              trailing: Text('${fmtNum(s.profile.heightCm, 1)} cm', style: numStyle(15, pal.ink2)),
              onTap: () async {
                final v = await numberDialog(context,
                    title: '身長', unit: 'cm', min: 100, max: 230, initial: s.profile.heightCm);
                if (v != null) await ctrl.setProfile(s.profile.copyWith(heightCm: (v * 10).round() / 10));
              },
            ),
          ]),
          group('リマインダー', [
            for (final r in s.reminders)
              ListTile(
                leading: Switch(
                  value: r.enabled,
                  onChanged: (v) async {
                    if (v) await NotificationService.requestPermission();
                    await ctrl.updateReminder(r.copyWith(enabled: v));
                  },
                ),
                title: Text(r.label),
                subtitle: const Text('毎日'),
                trailing: TextButton(
                  onPressed: () async {
                    final t = await showTimePicker(
                      context: context,
                      initialTime: TimeOfDay(hour: r.hour, minute: r.minute),
                    );
                    if (t != null) await ctrl.updateReminder(r.copyWith(hour: t.hour, minute: t.minute));
                  },
                  child: Text(r.timeLabel, style: numStyle(16, pal.accent)),
                ),
              ),
          ]),
          group('機器との連携', [
            SwitchListTile(
              value: s.healthEnabled,
              onChanged: _syncing ? null : _toggleHealth,
              title: Text(_healthName),
              subtitle: Text(
                'スマートウォッチや体重計、血圧計アプリが書き込んだ値を読み込みます（読み取りのみ）'
                '${s.healthEnabled && s.lastSync != null ? '\n最終同期 ${fmtMD(s.lastSync!)} ${fmtTime(s.lastSync!)}' : ''}',
              ),
            ),
            if (s.healthEnabled)
              ListTile(
                leading: _syncing
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.sync),
                title: const Text('今すぐ同期'),
                onTap: _syncing ? null : _sync,
              ),
          ]),
          group('データ', [
            const ListTile(
              title: Text('保存場所'),
              subtitle: Text('記録はこの端末の中だけに保存されます。アカウント登録は不要です。'),
            ),
            ListTile(
              title: const Text('サンプルデータを表示'),
              subtitle: const Text('12週間分の例で、すべての画面を試せます'),
              onTap: () async {
                final ok = await confirmDialog(
                  context,
                  title: 'サンプルデータを表示しますか？',
                  body: '現在の記録は削除され、サンプルデータに置き換わります。',
                  action: '表示する',
                  destructive: true,
                );
                if (ok) await ctrl.loadSample();
              },
            ),
            ListTile(
              title: Text('すべての記録を消去', style: TextStyle(color: pal.alert)),
              subtitle: const Text('この操作は取り消せません'),
              onTap: () async {
                final ok = await confirmDialog(
                  context,
                  title: 'すべての記録を消去しますか？',
                  body: 'この端末に保存された測定記録をすべて削除します。この操作は取り消せません。',
                  action: '消去する',
                  destructive: true,
                );
                if (ok) await ctrl.clearAll();
              },
            ),
          ]),
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const AppLogo(size: 36),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'からだ手帖 0.1.0\n$disclaimerText',
                    style: TextStyle(fontSize: 12, color: pal.ink3, height: 1.6),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
