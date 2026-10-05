import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../../domain/calc/calc_engine.dart';
import '../../../domain/models/calc_result.dart';
import '../../../domain/models/enums.dart';
import '../../../domain/models/item.dart';

/// 在用物品卡片：日均价突出 + 进度条 + 状态。
class ItemCard extends StatelessWidget {
  const ItemCard({
    super.key,
    required this.item,
    required this.result,
    required this.onTap,
    required this.onDelete,
  });

  final Item item;
  final CalcResult result;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  /// 价格行文案：TCO/分期/币种信息优先。
  String get _costLabel {
    final buffer = StringBuffer();
    buffer.write(
      item.extraCostsTotal > 0
          ? 'TCO ${money(item.tcoTotal)}'
          : '总价 ${money(item.price)}',
    );
    buffer.write(' · 残值 ${money(item.residual)}');
    if (item.currency != 'CNY') buffer.write(' · ${item.currency}');
    return buffer.toString();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 8, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      item.name,
                      style: theme.textTheme.titleMedium,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  _CategoryChip(item.category),
                  const SizedBox(width: 8),
                  _StatusBadge(result.status),
                  if (item.lifecycle != ItemLifecycle.inUse)
                    Padding(
                      padding: const EdgeInsets.only(left: 4),
                      child: _LifecycleBadge(item.lifecycle),
                    ),
                  PopupMenuButton<String>(
                    onSelected: (v) {
                      if (v == 'delete') onDelete();
                    },
                    itemBuilder: (_) => const [
                      PopupMenuItem(value: 'delete', child: Text('删除')),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${money(result.dailyCost)} /天',
                    style: theme.textTheme.moneyMedium,
                  ),
                  const Spacer(),
                  Flexible(
                    child: Text(
                      _costLabel,
                      textAlign: TextAlign.right,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _ProgressRow(item: item, result: result),
              if (item.tags.isNotEmpty) ...[
                const SizedBox(height: 10),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: [
                    for (final tag in item.tags)
                      InputChip(
                        label: Text(tag, style: theme.textTheme.labelSmall),
                        onSelected: null,
                        visualDensity: VisualDensity.compact,
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _ProgressRow extends StatelessWidget {
  const _ProgressRow({required this.item, required this.result});

  final Item item;
  final CalcResult result;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final labelStyle = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );

    // 模式相关的文案与进度条
    final Widget bar = LinearProgressIndicator(
      value: result.progress ?? 0,
      minHeight: 6,
      borderRadius: BorderRadius.circular(3),
    );

    switch (item.calcMode) {
      case CalcMode.fixedDays:
      case CalcMode.endDate:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            bar,
            const SizedBox(height: 6),
            Text(
              '已用 ${result.elapsedDays.toInt()}/${result.totalDays?.toInt() ?? 0} 天',
              style: labelStyle,
            ),
          ],
        );
      case CalcMode.actualDays:
        return Text('已使用 ${result.elapsedDays.toInt()} 天', style: labelStyle);
      case CalcMode.subscription:
        final cycleDays = cycleDaysFor(
          item.cycleUnit ?? CycleUnit.monthly,
          item.cycleLength ?? 1,
        );
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            bar,
            const SizedBox(height: 6),
            Text(
              '本周期第 ${result.elapsedDays.toInt()}/$cycleDays 天',
              style: labelStyle,
            ),
          ],
        );
      case CalcMode.perUse:
        return Text('单次 ${money(result.costPerUse ?? 0)}', style: labelStyle);
      case CalcMode.perHour:
        return Text('单小时 ${money(result.costPerHour ?? 0)}', style: labelStyle);
    }
  }
}

class _CategoryChip extends StatelessWidget {
  const _CategoryChip(this.category);

  final String category;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: theme.colorScheme.secondaryContainer.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(category, style: theme.textTheme.labelSmall),
    );
  }
}

class _LifecycleBadge extends StatelessWidget {
  const _LifecycleBadge(this.lifecycle);

  final ItemLifecycle lifecycle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: theme.colorScheme.tertiaryContainer.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        lifecycle.labelZh,
        style: theme.textTheme.labelSmall?.copyWith(
          color: theme.colorScheme.onTertiaryContainer,
        ),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge(this.status);

  final ItemStatus status;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final (label, color) = switch (status) {
      ItemStatus.notStarted => ('未开始', theme.colorScheme.outline),
      ItemStatus.inUse => ('在用', theme.colorScheme.primary),
      ItemStatus.expired => ('已到期', theme.colorScheme.onSurfaceVariant),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        border: Border.all(color: color.withValues(alpha: 0.6)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: theme.textTheme.labelSmall?.copyWith(color: color),
      ),
    );
  }
}
