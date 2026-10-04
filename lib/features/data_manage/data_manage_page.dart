import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../domain/models/item.dart';
import '../home/application/home_providers.dart';
import '../settings/application/settings_providers.dart';
import 'application/export_service.dart';
import 'application/import_service.dart';

final exportServiceProvider = Provider<ExportService>((ref) => ExportService());
final importServiceProvider = Provider<ImportService>((ref) => ImportService());

/// 数据管理：导出 / 导入 / 备份 / 恢复 / 撤销重做 / 回收站。
class DataManagePage extends ConsumerStatefulWidget {
  const DataManagePage({super.key});

  @override
  ConsumerState<DataManagePage> createState() => _DataManagePageState();
}

class _DataManagePageState extends ConsumerState<DataManagePage> {
  final _reportKey = GlobalKey();
  var _busy = false;

  Future<void> _run(String label, Future<void> Function() action) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await action();
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('$label成功')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('$label失败：$e')));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  List<Item> get _items => ref.read(itemsProvider).value ?? const [];

  @override
  Widget build(BuildContext context) {
    final undo = ref.watch(undoServiceProvider);
    final settings = ref.watch(settingsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('数据管理')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _section('报告预览（可导出图片 / PDF）'),
          RepaintBoundary(
            key: _reportKey,
            child: _ReportCard(items: _items, coffeeYuan: settings.coffeePriceYuan),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _busy
                      ? null
                      : () => _run('导出图片', _exportImage),
                  icon: const Icon(Icons.image_outlined),
                  label: const Text('导出图片'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _busy ? null : () => _run('导出 PDF', _exportPdf),
                  icon: const Icon(Icons.picture_as_pdf_outlined),
                  label: const Text('导出 PDF'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          _section('导出数据'),
          ListTile(
            leading: const Icon(Icons.table_chart_outlined),
            title: const Text('导出 CSV'),
            subtitle: const Text('记录明细，可用表格软件打开'),
            trailing: const Icon(Icons.chevron_right),
            onTap: _busy ? null : () => _run('导出 CSV', _exportCsv),
          ),
          ListTile(
            leading: const Icon(Icons.data_object_outlined),
            title: const Text('导出 JSON'),
            subtitle: const Text('完整数据（含设置），用于迁移'),
            trailing: const Icon(Icons.chevron_right),
            onTap: _busy ? null : () => _run('导出 JSON', _exportJson),
          ),
          const SizedBox(height: 24),
          _section('导入数据'),
          ListTile(
            leading: const Icon(Icons.upload_file_outlined),
            title: const Text('导入 CSV'),
            subtitle: const Text('按导出格式逐条新增记录'),
            trailing: const Icon(Icons.chevron_right),
            onTap: _busy ? null : () => _run('导入 CSV', _importCsv),
          ),
          const SizedBox(height: 24),
          _section('备份与恢复'),
          ListTile(
            leading: const Icon(Icons.archive_outlined),
            title: const Text('立即备份'),
            subtitle: const Text('打包数据库与照片为 zip'),
            trailing: const Icon(Icons.chevron_right),
            onTap: _busy ? null : () => _run('备份', _backup),
          ),
          ListTile(
            leading: const Icon(Icons.restore_outlined),
            title: const Text('从备份恢复'),
            subtitle: const Text('覆盖当前数据（请先备份）'),
            trailing: const Icon(Icons.chevron_right),
            onTap: _busy ? null : _restore,
          ),
          const SizedBox(height: 24),
          _section('操作记录'),
          ListTile(
            leading: const Icon(Icons.undo),
            title: Text(undo.canUndo ? '撤销「${undo.undoLabel}」' : '没有可撤销的操作'),
            enabled: undo.canUndo && !_busy,
            onTap: () => _run('撤销', () => ref.read(undoServiceProvider).undo()),
          ),
          ListTile(
            leading: const Icon(Icons.redo),
            title: Text(undo.canRedo ? '重做「${undo.redoLabel}」' : '没有可重做的操作'),
            enabled: undo.canRedo && !_busy,
            onTap: () => _run('重做', () => ref.read(undoServiceProvider).redo()),
          ),
          const SizedBox(height: 24),
          _section('回收站'),
          ListTile(
            leading: const Icon(Icons.delete_sweep_outlined),
            title: const Text('回收站'),
            subtitle: const Text('删除的记录保留 30 天，可恢复'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.pushNamed('recycleBin'),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _section(String title) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Text(title, style: Theme.of(context).textTheme.titleSmall),
  );

  Future<void> _exportCsv() async {
    final path = p.join((await getTemporaryDirectory()).path, 'DailyCost-记录.csv');
    // 带 BOM，Excel 直接双击打开不乱码
    await File(path).writeAsBytes([
      0xEF, 0xBB, 0xBF,
      ...utf8.encode(ref.read(exportServiceProvider).csv(_items)),
    ]);
    await ref.read(exportServiceProvider).shareFile(path, subject: 'DailyCost 记录 CSV');
  }

  Future<void> _exportJson() async {
    final path = p.join((await getTemporaryDirectory()).path, 'DailyCost-数据.json');
    await File(path).writeAsString(ref.read(exportServiceProvider).json(
      _items,
      ref.read(settingsProvider),
    ));
    await ref.read(exportServiceProvider).shareFile(path, subject: 'DailyCost 数据 JSON');
  }

  Future<void> _exportImage() async {
    final path = await ref
        .read(exportServiceProvider)
        .capturePng(_reportKey, name: 'DailyCost-报告.png');
    await ref.read(exportServiceProvider).shareFile(path, subject: 'DailyCost 报告');
  }

  Future<void> _exportPdf() async {
    final pngPath = await ref.read(exportServiceProvider).capturePng(_reportKey);
    final bytes = await File(pngPath).readAsBytes();
    final path = await ref.read(exportServiceProvider).imageToPdf(bytes);
    await ref.read(exportServiceProvider).shareFile(path, subject: 'DailyCost 报告 PDF');
  }

  Future<void> _backup() async {
    final docs = await getApplicationDocumentsDirectory();
    final path = await ref.read(exportServiceProvider).backupZip(
      dbPath: p.join(docs.path, 'dailycost.db'),
      photosDirPath: p.join(docs.path, 'photos'),
    );
    await ref.read(exportServiceProvider).shareFile(path, subject: 'DailyCost 备份');
  }

  Future<void> _restore() async {
    final picked = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['zip'],
    );
    final zipPath = picked.isEmpty ? null : picked.single.path;
    if (zipPath == null) return;
    if (!mounted) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('从备份恢复？'),
        content: const Text('当前数据将被备份内容覆盖，且无法撤销。恢复完成后需重启应用生效。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('恢复'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    await _run('恢复', () async {
      final docs = await getApplicationDocumentsDirectory();
      await ref.read(importServiceProvider).restoreBackup(
        zipPath: zipPath,
        dbPath: p.join(docs.path, 'dailycost.db'),
        photosDirPath: p.join(docs.path, 'photos'),
      );
    });
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('恢复完成，重启应用后生效')),
    );
  }

  Future<void> _importCsv() async {
    final picked = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['csv'],
    );
    final path = picked.isEmpty ? null : picked.single.path;
    if (path == null) return;
    final content = await File(path).readAsString();
    final result = await ref.read(importServiceProvider).importCsv(
      content,
      (draft) => ref.read(itemsProvider.notifier).addItem(draft),
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('导入 ${result.imported} 条，跳过 ${result.skipped} 条')),
    );
  }
}

/// 报告卡片：汇总 + 明细（导出图片/PDF 的内容）。
class _ReportCard extends StatelessWidget {
  const _ReportCard({required this.items, required this.coffeeYuan});

  final List<Item> items;
  final double coffeeYuan;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final now = DateTime.now();
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('DailyCost · 消费报告', style: theme.textTheme.titleLarge),
            const SizedBox(height: 4),
            Text(dateLong(now), style: theme.textTheme.bodySmall),
            const Divider(height: 24),
            Text('共 ${items.length} 条记录', style: theme.textTheme.bodyMedium),
            const SizedBox(height: 12),
            for (final item in items.take(20))
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        item.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Text(
                      money(item.price),
                      style: theme.textTheme.moneyInline,
                    ),
                  ],
                ),
              ),
            if (items.length > 20)
              Text('…… 共 ${items.length} 条', style: theme.textTheme.bodySmall),
            const Divider(height: 24),
            Text(
              '由 DailyCost 生成 · 让每一笔钱被看见',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
