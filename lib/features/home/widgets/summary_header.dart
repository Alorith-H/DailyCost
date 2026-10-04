import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../../domain/models/daily_summary.dart';

/// 首页汇总卡：今日日均总支出 + 环比 + 在用数。
class SummaryHeader extends StatelessWidget {
  const SummaryHeader({super.key, required this.summary});

  final DailySummary summary;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final brightness = theme.brightness;
    final up = summary.delta > 0;
    final flat = summary.delta == 0;
    final deltaColor = flat
        ? theme.colorScheme.onSurfaceVariant
        : up
            ? AppColors.expenseUp(brightness)
            : AppColors.expenseDown(brightness);
    final arrow = flat ? '→' : up ? '↑' : '↓';

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '今日日均总支出',
              style: theme.textTheme.titleSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 4),
            Text(money(summary.todayTotal), style: theme.textTheme.moneyHuge),
            const SizedBox(height: 12),
            Row(
              children: [
                Text(
                  summary.yesterdayTotal == 0
                      ? '较昨日 —'
                      : '较昨日 ${summary.delta >= 0 ? '+' : '-'}${money(summary.delta.abs())} '
                            '($arrow${percentSigned(summary.deltaPercent).replaceFirst(RegExp(r'^[+-]'), '')})',
                  style: theme.textTheme.bodyMedium?.copyWith(color: deltaColor),
                ),
                const Spacer(),
                Chip(
                  label: Text('在用 ${summary.activeCount} 项'),
                  visualDensity: VisualDensity.compact,
                  side: BorderSide.none,
                  backgroundColor: theme.colorScheme.surfaceContainerHighest
                      .withValues(alpha: 0.5),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
