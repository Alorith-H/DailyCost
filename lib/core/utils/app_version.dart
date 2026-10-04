import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../constants.dart';

/// 真实安装版本号（读自平台 versionName）。
///
/// 版本单一来源是 pubspec 的 version；[kAppVersion] 仅作测试/异常兜底，
/// 避免再出现「常量与 pubspec 不一致」的漂移。
final appVersionProvider = FutureProvider<String>((ref) async {
  try {
    final info = await PackageInfo.fromPlatform();
    return info.version;
  } catch (_) {
    return kAppVersion;
  }
});
