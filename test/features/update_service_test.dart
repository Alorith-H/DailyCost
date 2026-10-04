import 'package:daily_cost/features/update/application/update_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('compareVersions', () {
    test('大小比较', () {
      expect(compareVersions('0.2.0', '0.1.0'), 1);
      expect(compareVersions('0.1.0', '0.2.0'), -1);
      expect(compareVersions('1.0.0', '1.0.0'), 0);
      expect(compareVersions('v0.10.0', 'v0.9.0'), 1);
      expect(compareVersions('0.1.9', '0.2.0'), -1);
    });

    test('容错：v 前缀、预发布后缀、段数不齐、非数字', () {
      expect(compareVersions('v1.2.3', '1.2.3'), 0);
      expect(compareVersions('1.2.3-beta.1', '1.2.3'), 0);
      expect(compareVersions('1.2.3+4', '1.2.3'), 0);
      expect(compareVersions('1.2', '1.2.0'), 0);
      expect(compareVersions('1.2.0', '1.2'), 0);
      expect(compareVersions('abc', '0.0.0'), 0);
    });
  });

  group('pickReleaseAsset', () {
    List<dynamic> assets(List<String> names) => [
      for (final n in names)
        {
          'name': n,
          'browser_download_url': 'https://example.com/$n',
          'size': 100,
        },
    ];

    test('按 ABI 优先精确匹配', () {
      final picked = pickReleaseAsset(
        assets([
          'DailyCost-v0.2.0-universal.apk',
          'DailyCost-v0.2.0-arm64-v8a.apk',
          'DailyCost-v0.2.0-armeabi-v7a.apk',
        ]),
        ['arm64-v8a', 'armeabi-v7a'],
      );
      expect(picked!.assetName, 'DailyCost-v0.2.0-arm64-v8a.apk');
    });

    test('无匹配 ABI 回退 universal', () {
      final picked = pickReleaseAsset(
        assets([
          'DailyCost-v0.2.0-arm64-v8a.apk',
          'DailyCost-v0.2.0-universal.apk',
        ]),
        ['x86_64'],
      );
      expect(picked!.assetName, 'DailyCost-v0.2.0-universal.apk');
    });

    test('无 universal 回退第一个 apk；非 apk 忽略', () {
      final picked = pickReleaseAsset(
        assets([
          'notes.txt',
          'DailyCost-v0.2.0-arm64-v8a.apk',
          'map.map',
        ]),
        ['x86_64'],
      );
      expect(picked!.assetName, 'DailyCost-v0.2.0-arm64-v8a.apk');
    });

    test('无 apk 资产返回 null', () {
      expect(pickReleaseAsset(assets(['notes.txt']), ['arm64-v8a']), isNull);
    });
  });

  group('parseLatestRelease', () {
    Map<String, dynamic> release({
      String tag = 'v0.2.0',
      String body = '更新内容',
      List<String> apkNames = const ['DailyCost-v0.2.0-arm64-v8a.apk'],
    }) => {
      'tag_name': tag,
      'body': body,
      'assets': [
        for (final n in apkNames)
          {
            'name': n,
            'browser_download_url': 'https://example.com/$n',
            'size': 123,
          },
      ],
    };

    test('有新版本 → 返回 UpdateInfo', () {
      final info = parseLatestRelease(
        release(),
        currentVersion: '0.1.0',
        supportedAbis: ['arm64-v8a'],
      );
      expect(info, isNotNull);
      expect(info!.version, '0.2.0');
      expect(info.releaseNotes, '更新内容');
      expect(info.assetName, 'DailyCost-v0.2.0-arm64-v8a.apk');
      expect(info.sizeBytes, 123);
    });

    test('同版本 / 更旧 → null', () {
      expect(
        parseLatestRelease(
          release(tag: 'v0.1.0'),
          currentVersion: '0.1.0',
          supportedAbis: ['arm64-v8a'],
        ),
        isNull,
      );
      expect(
        parseLatestRelease(
          release(tag: 'v0.0.9'),
          currentVersion: '0.1.0',
          supportedAbis: ['arm64-v8a'],
        ),
        isNull,
      );
    });

    test('tag 缺失 / 无 apk → null', () {
      expect(
        parseLatestRelease(
          release(tag: ''),
          currentVersion: '0.1.0',
          supportedAbis: ['arm64-v8a'],
        ),
        isNull,
      );
      expect(
        parseLatestRelease(
          release(apkNames: ['notes.txt']),
          currentVersion: '0.1.0',
          supportedAbis: ['arm64-v8a'],
        ),
        isNull,
      );
    });
  });
}
