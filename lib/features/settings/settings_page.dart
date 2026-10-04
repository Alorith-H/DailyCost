import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants.dart';
import '../../domain/models/enums.dart';
import '../update/application/update_providers.dart';
import 'application/settings_providers.dart';

/// 设置页：外观 / 试算 / 关于。
class SettingsPage extends ConsumerStatefulWidget {
  const SettingsPage({super.key});

  @override
  ConsumerState<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends ConsumerState<SettingsPage> {
  late final TextEditingController _coffeeController;

  @override
  void initState() {
    super.initState();
    final coffee = ref.read(settingsProvider).coffeePriceYuan;
    _coffeeController = TextEditingController(text: coffee.toStringAsFixed(2));
  }

  @override
  void dispose() {
    _coffeeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('设置')),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: [
          _SectionHeader('外观'),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: SegmentedButton<ThemePref>(
              segments: const [
                ButtonSegment(value: ThemePref.system, label: Text('跟随系统')),
                ButtonSegment(value: ThemePref.light, label: Text('浅色')),
                ButtonSegment(value: ThemePref.dark, label: Text('深色')),
              ],
              selected: {settings.themeMode},
              onSelectionChanged: (selection) =>
                  ref.read(settingsProvider.notifier).setThemeMode(selection.first),
            ),
          ),
          _SectionHeader('试算'),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: _coffeeController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    labelText: '咖啡单价',
                    prefixText: '¥ ',
                  ),
                  onChanged: (text) {
                    final yuan = double.tryParse(text);
                    if (yuan != null && yuan >= 0) {
                      ref
                          .read(settingsProvider.notifier)
                          .setCoffeePriceFen((yuan * 100).round());
                    }
                  },
                ),
                const SizedBox(height: 8),
                Text(
                  '用于试算器的「≈ N 杯咖啡」',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          _SectionHeader('更新'),
          SwitchListTile(
            title: const Text('自动检查更新'),
            subtitle: Text(
              '启动时检查 GitHub 新版本；这是本应用唯一的联网行为',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
            value: settings.autoUpdateCheck,
            onChanged: (v) =>
                ref.read(settingsProvider.notifier).setAutoUpdateCheck(v),
          ),
          _UpdateTile(),
          _SectionHeader('关于'),
          ListTile(
            title: const Text('版本'),
            trailing: Text(kAppVersion, style: TextStyle(color: scheme.onSurfaceVariant)),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            child: Text(
              '全部数据仅保存在本机，无账号、无网络、无上传。\n'
              '提醒、统计、导出等能力将在后续版本提供。',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
                height: 1.6,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.title);

  final String title;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 24, 16, 12),
    child: Text(
      title,
      style: Theme.of(context).textTheme.titleSmall?.copyWith(
        color: Theme.of(context).colorScheme.primary,
        fontWeight: FontWeight.w600,
      ),
    ),
  );
}

/// 「检查更新」入口 + 状态展示。
class _UpdateTile extends ConsumerWidget {
  const _UpdateTile();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final update = ref.watch(updateProvider);
    final scheme = Theme.of(context).colorScheme;
    final notifier = ref.read(updateProvider.notifier);

    String subtitle;
    Widget? trailing;
    switch (update.phase) {
      case UpdatePhase.idle:
        subtitle = '从 GitHub 检查新版本';
        trailing = TextButton(
          onPressed: () => notifier.check(),
          child: const Text('检查更新'),
        );
      case UpdatePhase.checking:
        subtitle = '正在检查…';
        trailing = const SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(strokeWidth: 2),
        );
      case UpdatePhase.upToDate:
        subtitle = '已是最新版本（v$kAppVersion）';
        trailing = TextButton(
          onPressed: () => notifier.check(),
          child: const Text('再查一次'),
        );
      case UpdatePhase.available:
        subtitle = '发现新版本 v${update.info?.version}';
        trailing = FilledButton(
          onPressed: () => notifier.download(),
          child: const Text('下载'),
        );
      case UpdatePhase.downloading:
        subtitle =
            '正在下载 v${update.info?.version}（${(update.progress * 100).toStringAsFixed(0)}%）';
        trailing = SizedBox(
          width: 64,
          child: LinearProgressIndicator(value: update.progress),
        );
      case UpdatePhase.readyToInstall:
        subtitle = 'v${update.info?.version} 已下载完成';
        trailing = FilledButton(
          onPressed: () => notifier.install(),
          child: const Text('立即安装'),
        );
      case UpdatePhase.error:
        subtitle = '检查失败：${update.error}';
        trailing = TextButton(
          onPressed: () => notifier.check(),
          child: const Text('重试'),
        );
    }

    return Column(
      children: [
        ListTile(
          title: const Text('检查更新'),
          subtitle: Text(
            subtitle,
            style: TextStyle(color: scheme.onSurfaceVariant),
          ),
          trailing: trailing,
        ),
        if (update.phase == UpdatePhase.readyToInstall &&
            (update.info?.releaseNotes.isNotEmpty ?? false))
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Text(
              update.info!.releaseNotes,
              maxLines: 4,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
      ],
    );
  }
}
