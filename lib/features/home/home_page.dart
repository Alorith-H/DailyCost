import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/utils/formatters.dart';
import '../../data/providers.dart';
import '../../domain/models/item.dart';
import 'application/home_providers.dart';
import 'widgets/empty_home.dart';
import 'widgets/item_card.dart';
import 'widgets/summary_header.dart';

/// 首页：今日日均总支出 + 在用物品列表。
class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key});

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // 回到前台时重算「今天」（跨零点后 actualDays/环比会变化）
    if (state == AppLifecycleState.resumed) {
      ref.invalidate(todayProvider);
    }
  }

  @override
  Widget build(BuildContext context) {
    final itemsAsync = ref.watch(itemsProvider);
    final summary = ref.watch(dailySummaryProvider);
    final results = ref.watch(calcResultsProvider);
    final today = ref.watch(todayProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('每日花费'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(20),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Padding(
              padding: const EdgeInsets.only(left: 16, bottom: 8),
              child: Text(
                dateWithWeekday(today),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _onAdd,
        icon: const Icon(Icons.add),
        label: const Text('记一笔'),
      ),
      body: itemsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('加载失败：$e')),
        data: (items) {
          if (items.isEmpty) {
            return EmptyHome(onAdd: _onAdd);
          }
          final sorted = [...items]..sort((a, b) {
            final da = results[a.id]?.dailyCost ?? 0;
            final db = results[b.id]?.dailyCost ?? 0;
            final byCost = db.compareTo(da);
            if (byCost != 0) return byCost;
            return b.purchaseDate.compareTo(a.purchaseDate);
          });
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 88),
            children: [
              SummaryHeader(summary: summary),
              const SizedBox(height: 12),
              for (final item in sorted) ...[
                ItemCard(
                  item: item,
                  result: results[item.id]!,
                  onTap: () => _onEdit(item),
                  onDelete: () => _onDelete(item),
                ),
                const SizedBox(height: 12),
              ],
            ],
          );
        },
      ),
    );
  }

  void _onAdd() => context.pushNamed('itemCreate');

  void _onEdit(Item item) =>
      context.pushNamed('itemEdit', pathParameters: {'id': '${item.id}'});

  Future<void> _onDelete(Item item) async {
    await ref.read(itemsProvider.notifier).softDelete(item.id);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('已删除「${item.name}」'),
        action: SnackBarAction(
          label: '撤销',
          onPressed: () => ref.read(itemsProvider.notifier).restore(item.id),
        ),
      ),
    );
  }
}
