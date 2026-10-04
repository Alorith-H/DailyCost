import 'package:flutter/material.dart';

/// 首页空状态。
class EmptyHome extends StatelessWidget {
  const EmptyHome({super.key, required this.onAdd});

  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.savings_outlined,
              size: 96,
              color: theme.colorScheme.outline,
            ),
            const SizedBox(height: 16),
            Text('还没有记录', style: theme.textTheme.titleLarge),
            const SizedBox(height: 8),
            Text(
              '记一笔花销，看看它每天花你多少钱',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: onAdd,
              icon: const Icon(Icons.add),
              label: const Text('记一笔'),
            ),
          ],
        ),
      ),
    );
  }
}
