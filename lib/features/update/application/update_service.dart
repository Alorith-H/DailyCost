/// 应用内更新：检测 GitHub 最新 Release 并下载安装包。
///
/// 网络访问严格限定为 GitHub 更新源（api.github.com / objects.github.com），
/// 无任何统计或数据上传。
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// 发现的可更新版本信息。
class UpdateInfo {
  const UpdateInfo({
    required this.version,
    required this.releaseNotes,
    required this.assetName,
    required this.downloadUrl,
    required this.sizeBytes,
  });

  /// 版本号（不带 v 前缀，如 0.2.0）
  final String version;

  /// 更新说明（Release body）
  final String releaseNotes;

  /// 安装包资产名
  final String assetName;

  /// 下载地址
  final String downloadUrl;

  /// 安装包大小（字节）
  final int sizeBytes;
}

/// 版本比较：a > b → 1，相等 → 0，a < b → -1。
/// 非数字段按 0 处理，段数不齐补 0。
int compareVersions(String a, String b) {
  List<int> parse(String v) {
    final core = v.trim().replaceFirst(RegExp(r'^[vV]'), '').split(RegExp(r'[-+]')).first;
    return core.split('.').map((s) => int.tryParse(s) ?? 0).toList();
  }

  final pa = parse(a);
  final pb = parse(b);
  final len = pa.length > pb.length ? pa.length : pb.length;
  for (var i = 0; i < len; i++) {
    final x = i < pa.length ? pa[i] : 0;
    final y = i < pb.length ? pb[i] : 0;
    if (x != y) return x > y ? 1 : -1;
  }
  return 0;
}

/// 从 Release 资产列表挑出适配本机 ABI 的安装包。
///
/// 优先精确匹配 ABI（arm64-v8a / armeabi-v7a / x86_64），其次 universal，再次第一个 .apk。
({String assetName, String downloadUrl, int sizeBytes})? pickReleaseAsset(
  List<dynamic> assets,
  List<String> supportedAbis,
) {
  final apks = assets
      .whereType<Map<String, dynamic>>()
      .where((a) => (a['name'] as String? ?? '').toLowerCase().endsWith('.apk'))
      .toList();
  if (apks.isEmpty) return null;

  Map<String, dynamic>? pick(bool Function(String name) match) {
    for (final a in apks) {
      if (match(a['name'] as String)) return a;
    }
    return null;
  }

  Map<String, dynamic>? chosen;
  for (final abi in supportedAbis) {
    chosen = pick((n) => n.contains(abi));
    if (chosen != null) break;
  }
  chosen ??= pick((n) => n.contains('universal'));
  chosen ??= apks.first;

  return (
    assetName: chosen['name'] as String,
    downloadUrl: chosen['browser_download_url'] as String,
    sizeBytes: (chosen['size'] as num?)?.toInt() ?? 0,
  );
}

/// 解析 GitHub `releases/latest` 响应。
/// 当最新版本不比 [currentVersion] 新时返回 null。
UpdateInfo? parseLatestRelease(
  Map<String, dynamic> json, {
  required String currentVersion,
  required List<String> supportedAbis,
}) {
  final version = (json['tag_name'] as String? ?? '')
      .replaceFirst(RegExp(r'^[vV]'), '');
  if (version.isEmpty) return null;
  if (compareVersions(version, currentVersion) <= 0) return null;

  final asset = pickReleaseAsset(json['assets'] as List<dynamic>? ?? const [], supportedAbis);
  if (asset == null) return null;

  return UpdateInfo(
    version: version,
    releaseNotes: json['body'] as String? ?? '',
    assetName: asset.assetName,
    downloadUrl: asset.downloadUrl,
    sizeBytes: asset.sizeBytes,
  );
}

/// GitHub 更新服务。
class UpdateService {
  UpdateService({HttpClient? client}) : _client = client ?? HttpClient();

  static const _owner = 'Alorith-H';
  static const _repo = 'DailyCost';
  static const _latestUrl =
      'https://api.github.com/repos/$_owner/$_repo/releases/latest';

  final HttpClient _client;

  /// 检查更新；无新版本返回 null。
  Future<UpdateInfo?> checkForUpdate({
    required String currentVersion,
    required List<String> supportedAbis,
  }) async {
    final request = await _client.getUrl(Uri.parse(_latestUrl));
    request.headers.set(HttpHeaders.userAgentHeader, 'DailyCost/$currentVersion');
    request.headers.set(HttpHeaders.acceptHeader, 'application/vnd.github+json');
    final response = await request.close();
    if (response.statusCode != 200) {
      throw HttpException('检查更新失败（HTTP ${response.statusCode}）');
    }
    final body = await response.transform(utf8.decoder).join();
    final json = jsonDecode(body) as Map<String, dynamic>;
    return parseLatestRelease(
      json,
      currentVersion: currentVersion,
      supportedAbis: supportedAbis,
    );
  }

  /// 下载安装包到临时目录，返回本地路径。[onProgress] 回传 0..1。
  Future<String> download(
    UpdateInfo info, {
    void Function(double progress)? onProgress,
  }) async {
    final dir = await getTemporaryDirectory();
    final path = p.join(dir.path, 'DailyCost-v${info.version}.apk');

    final request = await _client.getUrl(Uri.parse(info.downloadUrl));
    final response = await request.close();
    if (response.statusCode != 200) {
      throw HttpException('下载失败（HTTP ${response.statusCode}）');
    }
    final total = response.contentLength > 0
        ? response.contentLength
        : (info.sizeBytes > 0 ? info.sizeBytes : 1);
    final file = File(path);
    final sink = file.openWrite();
    var received = 0;
    try {
      await for (final chunk in response) {
        sink.add(chunk);
        received += chunk.length;
        onProgress?.call((received / total).clamp(0.0, 1.0));
      }
    } finally {
      await sink.flush();
      await sink.close();
    }
    return path;
  }

  /// 调起系统安装器（自实现平台通道：FileProvider + ACTION_VIEW）。
  Future<void> install(String apkPath) async {
    if (!Platform.isAndroid) {
      throw UnsupportedError('应用内更新仅支持 Android');
    }
    await const MethodChannel('dailycost/installer')
        .invokeMethod('installApk', {'path': apkPath});
  }
}
