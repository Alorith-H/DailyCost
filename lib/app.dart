import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/routing/app_router.dart';
import 'core/theme/app_theme.dart';
import 'features/settings/application/settings_providers.dart';
import 'features/update/application/update_providers.dart';

/// 应用根组件：主题 + 中文本地化 + 路由 + 自动更新检查。
class DailyCostApp extends ConsumerWidget {
  const DailyCostApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp.router(
      title: '每日花费',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: ref.watch(themeModeProvider),
      locale: const Locale('zh', 'CN'),
      supportedLocales: const [Locale('zh', 'CN')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      routerConfig: ref.watch(routerProvider),
      builder: (context, child) => _UpdateAutoChecker(child: child),
    );
  }
}

/// 启动时自动检查更新（可在设置关闭）；发现新版本自动下载并提示安装。
class _UpdateAutoChecker extends ConsumerStatefulWidget {
  const _UpdateAutoChecker({this.child});

  final Widget? child;

  @override
  ConsumerState<_UpdateAutoChecker> createState() => _UpdateAutoCheckerState();
}

class _UpdateAutoCheckerState extends ConsumerState<_UpdateAutoChecker>
    with WidgetsBindingObserver {
  var _checkedOnce = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _maybeAutoCheck());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _maybeAutoCheck();
  }

  void _maybeAutoCheck() {
    if (_checkedOnce) return;
    if (!ref.read(settingsProvider).autoUpdateCheck) return;
    _checkedOnce = true;
    ref.read(updateProvider.notifier).check(auto: true);
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<UpdateState>(updateProvider, (previous, next) {
      final messenger = ScaffoldMessenger.maybeOf(context);
      if (next.phase == UpdatePhase.available && next.info != null) {
        // 自动流程：提示后 download() 会立即被 check(auto) 触发
        messenger?.showSnackBar(
          SnackBar(content: Text('发现新版本 v${next.info!.version}，正在下载…')),
        );
      } else if (next.phase == UpdatePhase.readyToInstall && next.info != null) {
        _promptInstall(next.info!.version);
      }
    });
    return widget.child ?? const SizedBox.shrink();
  }

  Future<void> _promptInstall(String version) async {
    final install = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('新版本 v$version 已下载'),
        content: const Text('立即安装更新？安装过程由系统完成。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('稍后'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('立即安装'),
          ),
        ],
      ),
    );
    if (install == true && mounted) {
      await ref.read(updateProvider.notifier).install();
    }
  }
}
