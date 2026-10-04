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
import '../../domain/calc/calc_engine.dart';
import '../../domain/models/calc_inputs.dart';
import '../../domain/models/enums.dart';
import '../../domain/models/item.dart';
import '../home/application/home_providers.dart';
import '../settings/application/settings_providers.dart';
import 'application/export_service.dart';
import 'application/import_service.dart';

final exportServiceProvider = Provider<ExportService>((ref) => ExportService());
final importServiceProvider = Provider<ImportService>((ref) => ImportService());

// ── 报告聚合 ──────────────────────────────────────────────────────

enum ReportPeriod { all, year, month, week }

enum ReportGroup { monthly, daily }

/// 时间范围内每天的价格均分 → 实际每日花费。
/// 不是按购买日期过滤，而是"这段时间内正在花钱的商品"。
DateTime _periodStart(ReportPeriod period) {
  final now = DateTime.now();
  switch (period) {
    case ReportPeriod.week:
      return DateTime(now.year, now.month, now.day)
          .subtract(Duration(days: now.weekday - 1));
    case ReportPeriod.month:
      return DateTime(now.year, now.month, 1);
    case ReportPeriod.year:
      return DateTime(now.year, 1, 1);
    case ReportPeriod.all:
      // 从最早购买日期开始
      return DateTime(2000, 1, 1);
  }
}

DateTime _periodEnd(ReportPeriod period) {
  final now = DateTime.now();
  switch (period) {
    case ReportPeriod.week:
      return DateTime(now.year, now.month, now.day)
          .subtract(Duration(days: now.weekday - 1))
          .add(const Duration(days: 6));
    case ReportPeriod.month:
      return DateTime(now.year, now.month + 1, 0);
    case ReportPeriod.year:
      return DateTime(now.year, 12, 31);
    case ReportPeriod.all:
      return now;
  }
}

/// 每个商品在时间范围内的每日均分累计总额。
/// 正确算法：每天实际花费 = 当天剩余价值 − 次日剩余价值（真实摊薄额），
/// 而不是累加"当前均分率"（那会导致调和级数溢出）。
({List<({String name, double total, int days})> items, double total, int totalDays})
    aggregateItemCosts(List<Item> items, ReportPeriod period) {
  final start = _periodStart(period);
  final end = _periodEnd(period);
  final today = DateTime.now();
  final safeEnd = end.isAfter(today) ? today : end;

  final totals = <String, double>{};
  final dayCount = <String, int>{};
  var grandTotal = 0.0;
  var dayIdx = 0;

  for (var day = DateTime(start.year, start.month, start.day);
      !day.isAfter(safeEnd);
      day = day.add(const Duration(days: 1))) {
    dayIdx++;
    for (final it in items) {
      final c = it.toCalcInputs();
      final r = calculate(c, today: day);
      if (r.status != ItemStatus.inUse) continue;
      // 每天实际花费 = 当天剩余价值 − 次日剩余价值
      final dayCost = _dailyDepreciation(c, day);
      totals[it.name] = (totals[it.name] ?? 0) + dayCost;
      dayCount[it.name] = (dayCount[it.name] ?? 0) + 1;
      grandTotal += dayCost;
    }
  }

  final list = totals.entries
      .map((e) => (
            name: e.key,
            total: e.value,
            days: dayCount[e.key] ?? 0,
          ))
      .toList()
    ..sort((a, b) => b.total.compareTo(a.total));

  return (items: list, total: grandTotal, totalDays: dayIdx);
}

/// 按日聚合：每天总花费 + 各商品明细。
List<({DateTime date, double total, List<({String name, double cost})> items})>
    aggregateDailyCosts(List<Item> items, ReportPeriod period) {
  final start = _periodStart(period);
  final end = _periodEnd(period);
  final today = DateTime.now();
  final safeEnd = end.isAfter(today) ? today : end;

  final result = <({DateTime date, double total, List<({String name, double cost})> items})>[];

  for (var day = DateTime(start.year, start.month, start.day);
      !day.isAfter(safeEnd);
      day = day.add(const Duration(days: 1))) {
    final dayItems = <({String name, double cost})>[];
    var dayTotal = 0.0;
    for (final it in items) {
      final c = it.toCalcInputs();
      final r = calculate(c, today: day);
      if (r.status != ItemStatus.inUse) continue;
      final dayCost = _dailyDepreciation(c, day);
      dayItems.add((name: it.name, cost: dayCost));
      dayTotal += dayCost;
    }
    if (dayItems.isNotEmpty) {
      result.add((date: day, total: dayTotal, items: dayItems));
    }
  }
  return result;
}

/// 某商品某天的真实摊薄花费 = 当天剩余价值 − 次日剩余价值。
/// 不依赖 dailyCost（那是运行均分率，累加会溢出）。
double _dailyDepreciation(CalcInputs c, DateTime day) {
  final r = calculate(c, today: day);
  if (r.status != ItemStatus.inUse) return 0;

  // 对于 actualDays（开放式），totalDays 未知，用已用天数估算
  double totalDays;
  if (r.totalDays != null) {
    totalDays = r.totalDays!;
  } else {
    totalDays = r.elapsedDays.clamp(1, double.infinity);
  }

  final price = c.price.clamp(0, double.infinity);
  final residual = c.residual.clamp(0, price);
  final effectiveCost = price + (c.tcoExtra > 0 ? c.tcoExtra : 0);
  final clampedResidual = residual.clamp(0, effectiveCost);

  // 直线折旧：每天摊薄 = (总成本 − 残值) / 总天数
  final daily = (effectiveCost - clampedResidual) / totalDays;
  return daily.clamp(0, double.infinity);
}

// ── 数据管理页面 ──────────────────────────────────────────────────

class DataManagePage extends ConsumerStatefulWidget {
  const DataManagePage({super.key});

  @override
  ConsumerState<DataManagePage> createState() => _DataManagePageState();
}

class _DataManagePageState extends ConsumerState<DataManagePage> {
  final _reportKey = GlobalKey();
  var _busy = false;
  var _period = ReportPeriod.month;
  var _group = ReportGroup.monthly;

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

    return Scaffold(
      appBar: AppBar(title: const Text('数据管理')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _section('报告预览（可导出图片 / PDF）'),
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                const Text('时间范围', style: TextStyle(fontSize: 13)),
                const SizedBox(width: 8),
                Expanded(
                  child: SegmentedButton<ReportPeriod>(
                    segments: const [
                      ButtonSegment(value: ReportPeriod.all, label: Text('全部', style: TextStyle(fontSize: 11))),
                      ButtonSegment(value: ReportPeriod.year, label: Text('今年', style: TextStyle(fontSize: 11))),
                      ButtonSegment(value: ReportPeriod.month, label: Text('本月', style: TextStyle(fontSize: 11))),
                      ButtonSegment(value: ReportPeriod.week, label: Text('本周', style: TextStyle(fontSize: 11))),
                    ],
                    selected: {_period},
                    onSelectionChanged: (s) => setState(() => _period = s.first),
                    showSelectedIcon: false,
                    style: const ButtonStyle(visualDensity: VisualDensity.compact),
                  ),
                ),
              ],
            ),
          ),
          RepaintBoundary(
            key: _reportKey,
            child: _ReportCard(
              items: _items,
              period: _period,
              group: _group,
              periodLabel: switch (_period) {
                ReportPeriod.all => '全部',
                ReportPeriod.year => '今年',
                ReportPeriod.month => '本月',
                ReportPeriod.week => '本周',
              },
              onGroupChanged: (g) => setState(() => _group = g),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _busy ? null : () => _run('导出图片', _exportImage),
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
            onTap: _restore,
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
    final zipPath = await ref.read(exportServiceProvider).backupZip(
          dbPath: p.join(docs.path, 'dailycost.db'),
          photosDirPath: p.join(docs.path, 'photos'),
        );
    await ref.read(exportServiceProvider).shareFile(zipPath, subject: 'DailyCost 备份');
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

// ── 报告卡片 ──────────────────────────────────────────────────────

class _ReportCard extends StatelessWidget {
  const _ReportCard({
    required this.items,
    required this.period,
    required this.group,
    required this.periodLabel,
    required this.onGroupChanged,
  });

  final List<Item> items;
  final ReportPeriod period;
  final ReportGroup group;
  final String periodLabel;
  final ValueChanged<ReportGroup> onGroupChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final agg = aggregateItemCosts(items, period);
    final now = DateTime.now();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('DailyCost · 消费报告', style: theme.textTheme.titleLarge),
            const SizedBox(height: 2),
            Text(dateLong(now), style: theme.textTheme.bodySmall),
            const SizedBox(height: 4),
            Text('范围：$periodLabel · ${agg.totalDays} 天', style: theme.textTheme.bodySmall),
            const Divider(height: 16),

            // ── 总计 ──
            Row(
              children: [
                Text('每日均分累计'),
                const Spacer(),
                Text(
                  money(agg.total),
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // ── 分组切换 ──
            Row(
              children: [
                Text(
                  group == ReportGroup.monthly ? '按商品汇总' : '按日明细',
                  style: theme.textTheme.titleSmall,
                ),
                const Spacer(),
                SegmentedButton<ReportGroup>(
                  segments: const [
                    ButtonSegment(value: ReportGroup.monthly, label: Text('汇总', style: TextStyle(fontSize: 11))),
                    ButtonSegment(value: ReportGroup.daily, label: Text('每日', style: TextStyle(fontSize: 11))),
                  ],
                  selected: {group},
                  onSelectionChanged: (s) => onGroupChanged(s.first),
                  showSelectedIcon: false,
                  style: const ButtonStyle(visualDensity: VisualDensity.compact),
                ),
              ],
            ),
            const SizedBox(height: 8),

            if (group == ReportGroup.monthly)
              _buildItemSummary(theme, agg)
            else
              _buildDailyDetail(theme, items, period),

            const Divider(height: 16),
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

  /// 按商品汇总：每件商品在时间段内的累计日均花费。
  Widget _buildItemSummary(
    ThemeData theme,
    ({List<({String name, double total, int days})> items, double total, int totalDays}) agg,
  ) {
    return Column(
      children: [
        // 表头
        Row(
          children: [
            Expanded(flex: 3, child: Text('商品', style: theme.textTheme.bodySmall)),
            Expanded(flex: 2, child: Align(
              alignment: Alignment.centerRight,
              child: Text('天数', style: theme.textTheme.bodySmall),
            )),
            Expanded(flex: 3, child: Align(
              alignment: Alignment.centerRight,
              child: Text('累计花费', style: theme.textTheme.bodySmall),
            )),
          ],
        ),
        const SizedBox(height: 4),
        for (final e in agg.items)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 3),
            child: Row(
              children: [
                Expanded(
                  flex: 3,
                  child: Text(e.name, maxLines: 1, overflow: TextOverflow.ellipsis),
                ),
                Expanded(
                  flex: 2,
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: Text('${e.days}', style: theme.textTheme.bodySmall),
                  ),
                ),
                Expanded(
                  flex: 3,
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: Text(money(e.total), style: theme.textTheme.moneyInline),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  /// 按日明细：每天各商品的日均花费。
  Widget _buildDailyDetail(ThemeData theme, List<Item> items, ReportPeriod period) {
    final daily = aggregateDailyCosts(items, period);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final day in daily) ...[
          // 日期 + 当日总计
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 3, horizontal: 6),
            color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.3),
            child: Row(
              children: [
                Text(
                  '${day.date.month}月${day.date.day}日',
                  style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                Text(
                  '${money(day.total)}  ·  ${day.items.length} 项',
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
          ),
          // 各商品明细
          for (final item in day.items)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 2, horizontal: 10),
              child: Row(
                children: [
                  Expanded(
                    child: Text(item.name, maxLines: 1, overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall),
                  ),
                  Text(money(item.cost), style: theme.textTheme.moneyInline?.copyWith(fontSize: 11)),
                ],
              ),
            ),
        ],
      ],
    );
  }
}
