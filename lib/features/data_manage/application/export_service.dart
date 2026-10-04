/// 导出与备份：CSV / JSON / 图片 / PDF（图嵌 PDF）/ 全量备份 zip。
///
/// PDF 采用「Flutter 渲染成图再嵌 PDF」，避免嵌入 CJK 字体（保持安装包精简）。
library;

import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:archive/archive.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';

import '../../../domain/models/app_settings.dart';
import '../../../domain/models/item.dart';
import 'csv_codec.dart';

class ExportService {
  /// CSV 文本（含成本/标签）。
  String csv(List<Item> items) => itemsToCsv(items);

  /// 全量 JSON（记录 + 设置），供备份与迁移。
  String json(List<Item> items, AppSettings settings) {
    return '''
{
  "app": "dailycost",
  "format": 1,
  "exported_at": "${DateTime.now().toIso8601String()}",
  "settings": {
    "theme_mode": "${settings.themeMode.settingsValue}",
    "coffee_price_fen": ${settings.coffeePriceFen},
    "fx_rates": ${_fxJson(settings.fxRates)}
  },
  "items": [
${items.map(_itemJson).join(',\n')}
  ]
}
''';
  }

  String _fxJson(Map<String, double> rates) {
    final entries = rates.entries.map((e) => '"${e.key}": ${e.value}').join(', ');
    return '{$entries}';
  }

  String _itemJson(Item it) {
    final costs = it.extraCosts
        .map((c) =>
            '{"category": "${c.category}", "amount": ${c.amount}, "note": "${_escape(c.note)}"}')
        .join(', ');
    return '''    {
      "name": "${_escape(it.name)}",
      "price": ${it.price},
      "residual": ${it.residual},
      "currency": "${it.currency}",
      "category": "${it.category}",
      "purchase_date": "${it.purchaseDate.toIso8601String().substring(0, 10)}",
      "calc_mode": "${it.calcMode.name}",
      "depreciation": "${it.depreciation.name}",
      "usage_days": ${it.usageDays ?? 'null'},
      "end_date": ${it.endDate == null ? 'null' : '"${it.endDate!.toIso8601String().substring(0, 10)}"'},
      "total_uses": ${it.totalUses ?? 'null'},
      "uses_per_day": ${it.usesPerDay ?? 'null'},
      "total_hours": ${it.totalHours ?? 'null'},
      "hours_per_day": ${it.hoursPerDay ?? 'null'},
      "cycle_unit": ${it.cycleUnit == null ? 'null' : '"${it.cycleUnit!.name}"'},
      "cycle_length": ${it.cycleLength ?? 'null'},
      "apr_percent": ${it.aprPercent ?? 'null'},
      "installment_months": ${it.installmentMonths ?? 'null'},
      "note": "${_escape(it.note)}",
      "tags": [${it.tags.map((t) => '"${_escape(t)}"').join(', ')}],
      "costs": [$costs]
    }''';
  }

  String _escape(String s) =>
      s.replaceAll('\\', '\\\\').replaceAll('"', '\\"').replaceAll('\n', '\\n');

  /// 把 [boundary] 区域截成 PNG，返回文件路径。
  Future<String> capturePng(GlobalKey boundary, {String? name}) async {
    final context = boundary.currentContext;
    if (context == null) throw StateError('截图目标尚未渲染');
    final boundaryObj = context.findRenderObject() as RenderRepaintBoundary;
    final image = await boundaryObj.toImage(pixelRatio: 3);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    if (bytes == null) throw StateError('截图编码失败');
    final dir = await getTemporaryDirectory();
    final path = p.join(
      dir.path,
      name ?? 'dailycost_${DateTime.now().millisecondsSinceEpoch}.png',
    );
    await File(path).writeAsBytes(bytes.buffer.asUint8List());
    return path;
  }

  /// 把图片嵌入 A4 PDF（中文内容已在图片里渲染好）。
  Future<String> imageToPdf(List<int> pngBytes, {String? name}) async {
    final doc = pw.Document();
    final image = pw.MemoryImage(Uint8List.fromList(pngBytes));
    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(24),
        build: (context) => pw.Center(
          child: pw.Image(image, fit: pw.BoxFit.contain),
        ),
      ),
    );
    final dir = await getTemporaryDirectory();
    final path = p.join(
      dir.path,
      name ?? 'dailycost_${DateTime.now().millisecondsSinceEpoch}.pdf',
    );
    await File(path).writeAsBytes(await doc.save());
    return path;
  }

  /// 全量备份 zip：数据库文件 + 照片 + 清单。
  Future<String> backupZip({
    required String dbPath,
    required String photosDirPath,
  }) async {
    final archive = Archive();
    final dbFile = File(dbPath);
    if (await dbFile.exists()) {
      archive.addFile(ArchiveFile(
        'dailycost.db',
        await dbFile.length(),
        await dbFile.readAsBytes(),
      ));
    }
    final photosDir = Directory(photosDirPath);
    if (await photosDir.exists()) {
      await for (final entity in photosDir.list()) {
        if (entity is! File) continue;
        final bytes = await entity.readAsBytes();
        archive.addFile(ArchiveFile(
          'photos/${p.basename(entity.path)}',
          bytes.length,
          bytes,
        ));
      }
    }
    archive.addFile(ArchiveFile(
      'manifest.json',
      0,
      '{"app": "dailycost", "format": 1, "created_at": "${DateTime.now().toIso8601String()}"}'
          .codeUnits,
    ));

    final dir = await getTemporaryDirectory();
    final path = p.join(
      dir.path,
      'DailyCost-备份-${_dateSlug(DateTime.now())}.zip',
    );
    await File(path).writeAsBytes(ZipEncoder().encode(archive));
    return path;
  }

  /// 分享单个文件。
  Future<void> shareFile(String path, {String? subject}) {
    return SharePlus.instance.share(
      ShareParams(files: [XFile(path)], subject: subject),
    );
  }

  static String _dateSlug(DateTime d) =>
      '${d.year}${d.month.toString().padLeft(2, '0')}${d.day.toString().padLeft(2, '0')}';
}
