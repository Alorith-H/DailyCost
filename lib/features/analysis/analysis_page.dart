import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../domain/models/budget.dart';
import '../../domain/models/enums.dart';
import '../../domain/models/item.dart';
import '../home/application/home_providers.dart';
import '../stats/application/stats_engine.dart';
import 'application/analysis_providers.dart';

/// 分析：统计 / 预算 / 订阅 三个页签。
class AnalysisPage extends StatelessWidget {
  const AnalysisPage({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('分析'),
          bottom: const TabBar(
            tabs: [
              Tab(text: '统计'),
              Tab(text: '预算'),
              Tab(text: '订阅'),
            ],
          ),
        ),
        body: const TabBarView(
          children: [_StatsTab(), _BudgetTab(), _SubscriptionTab()],
        ),
      ),
    );
  }
}

// ---------------- 统计 ----------------

class _StatsTab extends ConsumerStatefulWidget {
  const _StatsTab();

  @override
  ConsumerState<_StatsTab> createState() => _StatsTabState();
}

class _StatsTabState extends ConsumerState<_StatsTab> {
  var _trendDays = 30;

  @override
  Widget build(BuildContext context) {
    final trend = ref.watch(trendProvider(_trendDays));
    final shares = ref.watch(categorySharesProvider);
    final scatter = ref.watch(scatterPointsProvider);
    final tops = ref.watch(topListsProvider);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _title('日均总支出趋势'),
        Row(
          children: [
            for (final d in [30, 90])
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  label: Text('近 $d 天'),
                  selected: _trendDays == d,
                  onSelected: (_) => setState(() => _trendDays = d),
                ),
              ),
          ],
        ),
        const SizedBox(height: 8),
        SizedBox(height: 200, child: _TrendChart(points: trend)),
        const SizedBox(height: 24),
        _title('分类日均份额'),
        if (shares.isEmpty)
          const _EmptyHint('还没有在用记录')
        else
          _CategoryDonut(shares: shares),
        const SizedBox(height: 24),
        _title('花费热力图（近 12 周）'),
        _Heatmap(points: trend),
        const SizedBox(height: 4),
        Text(
          '颜色越深表示当天日均总支出越高',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 24),
        _title('价格 × 使用天数'),
        SizedBox(height: 220, child: _PriceScatter(points: scatter)),
        const SizedBox(height: 24),
        _title('TOP10 榜单'),
        _TopList(title: '最贵（总成本）', entries: tops.mostExpensive),
        _TopList(title: '最超值（日均最低的在用）', entries: tops.bestValue),
        _TopList(title: '最浪费（摊薄率最高）', entries: tops.mostWasteful),
        const SizedBox(height: 32),
      ],
    );
  }

  Widget _title(String text) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Text(text, style: Theme.of(context).textTheme.titleSmall),
  );
}

/// 趋势折线：单序列（标题即图例），2px 线，弱化网格。
class _TrendChart extends StatelessWidget {
  const _TrendChart({required this.points});

  final List<TrendPoint> points;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    if (points.isEmpty) return const _EmptyHint('暂无数据');
    final spots = [
      for (var i = 0; i < points.length; i++)
        FlSpot(i.toDouble(), points[i].total),
    ];
    final maxY = points.map((e) => e.total).fold<double>(0, math.max);

    return LineChart(
      LineChartData(
        minY: 0,
        maxY: maxY <= 0 ? 1 : maxY * 1.2,
        gridData: FlGridData(
          drawVerticalLine: false,
          getDrawingHorizontalLine: (v) => FlLine(
            color: scheme.outlineVariant.withValues(alpha: 0.4),
            strokeWidth: 1,
          ),
        ),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 24,
              getTitlesWidget: (v, meta) {
                final i = v.toInt();
                if (i < 0 || i >= points.length) return const SizedBox();
                // 仅首、中、尾三个刻度
                final isEdge = i == 0 ||
                    i == points.length - 1 ||
                    i == points.length ~/ 2;
                if (!isEdge) return const SizedBox();
                return Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    dateShort(points[i].date),
                    style: Theme.of(context).textTheme.labelSmall,
                  ),
                );
              },
            ),
          ),
        ),
        lineTouchData: LineTouchData(
          touchTooltipData: LineTouchTooltipData(
            getTooltipItems: (touched) => [
              for (final spot in touched)
                LineTooltipItem(
                  '${money(spot.y)} /天',
                  Theme.of(context).textTheme.labelMedium!,
                ),
            ],
          ),
        ),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: false,
            barWidth: 2,
            color: scheme.primary,
            dotData: const FlDotData(show: false),
            belowBarData: BarAreaData(
              show: true,
              color: scheme.primary.withValues(alpha: 0.08),
            ),
          ),
        ],
      ),
    );
  }
}

/// 分类环形图：固定色序 + 表面 2px 缝隙；图例文字用墨色。
class _CategoryDonut extends StatelessWidget {
  const _CategoryDonut({required this.shares});

  final List<CategoryShare> shares;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final brightness = theme.brightness;
    final total = shares.fold<double>(0, (s, e) => s + e.total);

    return Row(
      children: [
        SizedBox(
          width: 150,
          height: 150,
          child: PieChart(
            PieChartData(
              sectionsSpace: 2,
              centerSpaceRadius: 40,
              sections: [
                for (final s in shares)
                  PieChartSectionData(
                    value: s.total,
                    color: AppColors.category(s.category, brightness),
                    radius: 48,
                    title: total > 0
                        ? '${(s.total / total * 100).toStringAsFixed(0)}%'
                        : '',
                    titleStyle: theme.textTheme.labelSmall?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final s in shares)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  child: Row(
                    children: [
                      Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          color: AppColors.category(s.category, brightness),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(child: Text(s.category)),
                      Text(money(s.total), style: theme.textTheme.moneyInline),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

/// 热力图：12 周网格，单色相顺序色阶（浅→深）。
class _Heatmap extends StatelessWidget {
  const _Heatmap({required this.points});

  final List<TrendPoint> points;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final ramp = brightness == Brightness.dark
        ? AppColors.heatDark
        : AppColors.heatLight;
    if (points.isEmpty) return const _EmptyHint('暂无数据');

    final maxTotal = points.map((e) => e.total).fold<double>(0, math.max);
    // 对齐到周（含未来空格，显示 12 列）
    final today = points.last.date;
    final firstDay = today.subtract(Duration(days: 7 * 12 - 1));
    final byDate = {for (final p in points) p.date: p.total};

    return Wrap(
      spacing: 3,
      runSpacing: 3,
      children: [
        for (var i = 0; i < 7 * 12; i++)
          () {
            final day = firstDay.add(Duration(days: i));
            final value = byDate[day];
            final level = value == null || maxTotal <= 0
                ? 0
                : ((value / maxTotal) * (ramp.length - 1)).round();
            final isFuture = day.isAfter(today);
            return Tooltip(
              message: value == null
                  ? ''
                  : '${dateShort(day)} ${money(value)}/天',
              child: Container(
                width: 14,
                height: 14,
                decoration: BoxDecoration(
                  color: isFuture
                      ? Theme.of(context).colorScheme.surfaceContainerHighest
                      : ramp[level],
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            );
          }(),
      ],
    );
  }
}

/// 散点：单序列（标题说明含义），点色统一。
class _PriceScatter extends StatelessWidget {
  const _PriceScatter({required this.points});

  final List<ScatterPoint> points;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    if (points.isEmpty) return const _EmptyHint('暂无数据');
    final maxX = points.map((e) => e.x).fold<double>(0, math.max);
    final maxY = points.map((e) => e.y).fold<double>(0, math.max);

    return ScatterChart(
      ScatterChartData(
        minX: 0,
        minY: 0,
        maxX: maxX <= 0 ? 1 : maxX * 1.1,
        maxY: maxY <= 0 ? 1 : maxY * 1.15,
        gridData: FlGridData(
          drawVerticalLine: false,
          getDrawingHorizontalLine: (v) => FlLine(
            color: scheme.outlineVariant.withValues(alpha: 0.4),
            strokeWidth: 1,
          ),
        ),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: AxisTitles(
            axisNameWidget: Text(
              '使用天数 →',
              style: Theme.of(context).textTheme.labelSmall,
            ),
            sideTitles: const SideTitles(showTitles: false),
          ),
        ),
        scatterSpots: [
          for (final p in points)
            ScatterSpot(
              p.x,
              p.y,
              dotPainter: FlDotCirclePainter(radius: 6, color: scheme.primary),
            ),
        ],
      ),
    );
  }
}

/// 榜单：文字列表（数据即表格，兼作对比度补偿）。
class _TopList extends StatelessWidget {
  const _TopList({required this.title, required this.entries});

  final String title;
  final List<TopEntry> entries;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: theme.textTheme.bodyMedium),
          const SizedBox(height: 4),
          if (entries.isEmpty)
            const _EmptyHint('暂无数据')
          else
            for (var i = 0; i < entries.length; i++)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Row(
                  children: [
                    SizedBox(
                      width: 22,
                      child: Text(
                        '${i + 1}',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                    Expanded(child: Text(entries[i].name)),
                    Text(
                      money(entries[i].value),
                      style: theme.textTheme.moneyInline,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      entries[i].detail,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
        ],
      ),
    );
  }
}

class _EmptyHint extends StatelessWidget {
  const _EmptyHint(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 16),
    child: Text(
      text,
      style: Theme.of(context).textTheme.bodySmall?.copyWith(
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
    ),
  );
}

// ---------------- 预算 ----------------

class _BudgetTab extends ConsumerWidget {
  const _BudgetTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statuses = ref.watch(budgetStatusProvider);
    final score = ref.watch(healthScoreProvider);
    final power = ref.watch(purchasingPowerProvider);
    final theme = Theme.of(context);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                SizedBox(
                  width: 72,
                  height: 72,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      CircularProgressIndicator(
                        value: score / 100,
                        strokeWidth: 8,
                        backgroundColor: theme.colorScheme.surfaceContainerHighest,
                      ),
                      Center(
                        child: Text(
                          score.toStringAsFixed(0),
                          style: theme.textTheme.moneyInline,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('财务健康评分', style: theme.textTheme.titleSmall),
                      const SizedBox(height: 4),
                      Text(
                        '按预算执行情况计算：超支按比例扣分，全部留有余量加分',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        if (power != null) ...[
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('购买力分析', style: theme.textTheme.titleSmall),
                  const SizedBox(height: 8),
                  Text('日预算 ${money(power.dailyPower)}'),
                  Text('≈ 月消费力 ${money(power.monthlyPower)} · 年消费力 ${money(power.yearlyPower)}'),
                  Text('可负担单品：1 年期 ${money(power.affordableOneYearItem)} · 3 年期 ${money(power.affordableThreeYearItem)}'),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
        ],
        Row(
          children: [
            Text('预算列表', style: theme.textTheme.titleSmall),
            const Spacer(),
            TextButton.icon(
              onPressed: () => _editBudget(context, ref, null),
              icon: const Icon(Icons.add),
              label: const Text('新增'),
            ),
          ],
        ),
        if (statuses.isEmpty)
          const _EmptyHint('还没有设置预算，点右上角「新增」')
        else
          for (final s in statuses)
            Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                title: Text(
                  '${s.budget.category ?? '总预算'} · ${s.budget.period.labelZh}',
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 6),
                    LinearProgressIndicator(
                      value: s.ratio.clamp(0.0, 1.0),
                      minHeight: 6,
                      borderRadius: BorderRadius.circular(3),
                      color: s.over
                          ? theme.colorScheme.error
                          : theme.colorScheme.primary,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '${money(s.spent)} / ${money(s.limit)}'
                      '${s.over ? ' · 已超支' : ''}',
                    ),
                  ],
                ),
                trailing: PopupMenuButton<String>(
                  onSelected: (v) {
                    if (v == 'edit') _editBudget(context, ref, s.budget);
                    if (v == 'del') {
                      ref.read(budgetsProvider.notifier).remove(s.budget.id);
                    }
                  },
                  itemBuilder: (_) => const [
                    PopupMenuItem(value: 'edit', child: Text('编辑')),
                    PopupMenuItem(value: 'del', child: Text('删除')),
                  ],
                ),
              ),
            ),
        const SizedBox(height: 32),
      ],
    );
  }

  Future<void> _editBudget(
    BuildContext context,
    WidgetRef ref,
    Budget? existing,
  ) async {
    final amount = TextEditingController(
      text: existing == null ? '' : existing.amount.toStringAsFixed(0),
    );
    var period = existing?.period ?? BudgetPeriod.monthly;
    String? category = existing?.category;

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: Text(existing == null ? '新增预算' : '编辑预算'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<BudgetPeriod>(
                initialValue: period,
                decoration: const InputDecoration(labelText: '周期'),
                items: [
                  for (final p in BudgetPeriod.values)
                    DropdownMenuItem(value: p, child: Text(p.labelZh)),
                ],
                onChanged: (v) => setState(() => period = v ?? period),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String?>(
                initialValue: category,
                decoration: const InputDecoration(labelText: '分类（不选=总预算）'),
                items: [
                  const DropdownMenuItem(value: null, child: Text('总预算')),
                  for (final c in kCategories)
                    DropdownMenuItem(value: c, child: Text(c)),
                ],
                onChanged: (v) => setState(() => category = v),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: amount,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: '额度',
                  prefixText: '¥ ',
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('保存'),
            ),
          ],
        ),
      ),
    );
    if (ok != true) return;
    final value = double.tryParse(amount.text.trim()) ?? 0;
    if (value <= 0) return;
    await ref.read(budgetsProvider.notifier).save(
      BudgetDraft(period: period, category: category, amount: value),
    );
  }
}

// ---------------- 订阅 ----------------

class _SubscriptionTab extends ConsumerWidget {
  const _SubscriptionTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final subs = ref.watch(subscriptionItemsProvider);
    final results = ref.watch(calcResultsProvider);
    final theme = Theme.of(context);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text('续费管理', style: theme.textTheme.titleSmall),
        const SizedBox(height: 8),
        if (subs.isEmpty)
          const _EmptyHint('还没有订阅记录（计算方式选「订阅周期」即出现在这里）')
        else
          for (final it in subs)
            Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                title: Text(it.name),
                subtitle: Text(
                  '${it.cycleUnit == null ? '每月' : switch (it.cycleUnit!) {
                    CycleUnit.weekly => '每周',
                    CycleUnit.monthly => '每月',
                    CycleUnit.yearly => '每年',
                  }} × ${it.cycleLength ?? 1}'
                  ' · 日均 ${money(results[it.id]?.dailyCost ?? 0)}'
                  ' · 下次续费 ${dateShort(_nextRenewal(it))}',
                ),
              ),
            ),
        const SizedBox(height: 24),
        Text('订阅 vs 买断对比', style: theme.textTheme.titleSmall),
        const SizedBox(height: 8),
        const _SubVsBuyout(),
        const SizedBox(height: 32),
      ],
    );
  }

  static DateTime _nextRenewal(Item it) {
    final cycleDays = (it.cycleLength ?? 1) *
        switch (it.cycleUnit ?? CycleUnit.monthly) {
          CycleUnit.weekly => 7,
          CycleUnit.monthly => 30,
          CycleUnit.yearly => 365,
        };
    var next = it.purchaseDate;
    final today = DateTime.now();
    while (!next.isAfter(today)) {
      next = next.add(Duration(days: cycleDays));
    }
    return next;
  }
}

/// 订阅 vs 买断对比小计算器。
class _SubVsBuyout extends ConsumerStatefulWidget {
  const _SubVsBuyout();

  @override
  ConsumerState<_SubVsBuyout> createState() => _SubVsBuyoutState();
}

class _SubVsBuyoutState extends ConsumerState<_SubVsBuyout> {
  final _subFee = TextEditingController();
  final _buyoutPrice = TextEditingController();
  final _months = TextEditingController(text: '36');

  @override
  void dispose() {
    _subFee.dispose();
    _buyoutPrice.dispose();
    _months.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final fee = double.tryParse(_subFee.text.trim()) ?? 0;
    final buyout = double.tryParse(_buyoutPrice.text.trim()) ?? 0;
    final months = int.tryParse(_months.text.trim()) ?? 0;
    final totalSub = fee * months;
    final cheaper = buyout <= 0 || totalSub <= 0
        ? null
        : (buyout < totalSub ? '买断更划算' : '订阅更划算');

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _subFee,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      labelText: '订阅月费',
                      prefixText: '¥ ',
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _buyoutPrice,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      labelText: '买断价',
                      prefixText: '¥ ',
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _months,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: '计划用（月）'),
                    onChanged: (_) => setState(() {}),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (cheaper != null)
              Text(
                '$cheaper：订阅共 ${money(totalSub)} vs 买断 ${money(buyout)}'
                '（差 ${money((totalSub - buyout).abs())}）',
              )
            else
              const Text('输入月费与买断价开始对比'),
          ],
        ),
      ),
    );
  }
}
