import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants.dart';
import '../../domain/models/enums.dart';
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
