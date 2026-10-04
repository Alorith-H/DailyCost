import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants.dart';
import '../../settings/application/settings_providers.dart';
import 'update_service.dart';

/// 更新流程阶段。
enum UpdatePhase {
  idle,
  checking,
  upToDate,
  available,
  downloading,
  readyToInstall,
  error,
}

/// 更新状态。
class UpdateState {
  const UpdateState({
    this.phase = UpdatePhase.idle,
    this.info,
    this.progress = 0,
    this.error,
  });

  final UpdatePhase phase;
  final UpdateInfo? info;

  /// 下载进度 0..1
  final double progress;
  final String? error;
}

final updateServiceProvider = Provider<UpdateService>((ref) => UpdateService());

/// 设备 ABI 列表（用于挑选安装包）。
final supportedAbisProvider = FutureProvider<List<String>>((ref) async {
  final android = await DeviceInfoPlugin().androidInfo;
  return android.supportedAbis;
});

/// 更新流程状态机。
class UpdateNotifier extends Notifier<UpdateState> {
  @override
  UpdateState build() => const UpdateState();

  /// 检查更新。[auto] 为 true 时发现新版本立即自动下载。
  Future<void> check({bool auto = false}) async {
    if (state.phase == UpdatePhase.downloading ||
        state.phase == UpdatePhase.checking) {
      return;
    }
    state = const UpdateState(phase: UpdatePhase.checking);
    try {
      final abis = await ref.read(supportedAbisProvider.future);
      final info = await ref.read(updateServiceProvider).checkForUpdate(
        currentVersion: kAppVersion,
        supportedAbis: abis,
      );
      if (info == null) {
        state = const UpdateState(phase: UpdatePhase.upToDate);
      } else {
        state = UpdateState(phase: UpdatePhase.available, info: info);
        if (auto && ref.read(settingsProvider).autoUpdateCheck) {
          await download();
        }
      }
    } catch (e) {
      state = UpdateState(phase: UpdatePhase.error, error: '$e');
    }
  }

  /// 下载安装包。
  Future<void> download() async {
    final info = state.info;
    if (info == null || state.phase == UpdatePhase.downloading) return;
    state = UpdateState(phase: UpdatePhase.downloading, info: info);
    try {
      final path = await ref.read(updateServiceProvider).download(
        info,
        onProgress: (p) {
          if (state.phase == UpdatePhase.downloading) {
            state = UpdateState(
              phase: UpdatePhase.downloading,
              info: info,
              progress: p,
            );
          }
        },
      );
      _apkPath = path;
      state = UpdateState(
        phase: UpdatePhase.readyToInstall,
        info: info,
        progress: 1,
      );
    } catch (e) {
      state = UpdateState(phase: UpdatePhase.error, info: info, error: '$e');
    }
  }

  String? _apkPath;

  /// 供测试注入已下载的安装包路径。
  void attachDownloaded(String path, UpdateInfo info) {
    _apkPath = path;
    state = UpdateState(phase: UpdatePhase.readyToInstall, info: info, progress: 1);
  }

  /// 调起系统安装器。
  Future<void> install() async {
    final path = _apkPath;
    if (path == null) return;
    try {
      await ref.read(updateServiceProvider).install(path);
    } catch (e) {
      state = UpdateState(
        phase: UpdatePhase.error,
        info: state.info,
        error: '调起安装失败：$e',
      );
    }
  }

  /// 回到初始态（忽略本次发现的版本）。
  void reset() {
    _apkPath = null;
    state = const UpdateState();
  }
}

final updateProvider = NotifierProvider<UpdateNotifier, UpdateState>(
  UpdateNotifier.new,
);
