import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/utils/formatters.dart';
import '../../data/providers.dart';
import '../../domain/models/item.dart';
import '../home/application/home_providers.dart';

/// 回收站：软删除记录保留 30 天，可恢复或彻底删除。
class RecycleBinPage extends ConsumerStatefulWidget {
  const RecycleBinPage({super.key});

  @override
  ConsumerState<RecycleBinPage> createState() => _RecycleBinPageState();
}

class _RecycleBinPageState extends ConsumerState<RecycleBinPage> {
  List<Item> _deleted = [];
  var _loading = true;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    setState(() => _loading = true);
    final all = await ref.read(itemRepositoryProvider).findAll(includeDeleted: true);
    if (!mounted) return;
    setState(() {
      _deleted = all.where((e) => e.deletedAt != null).toList()
        ..sort((a, b) => b.deletedAt!.compareTo(a.deletedAt!));
      _loading = false;
    });
  }

  int _daysLeft(Item item) {
    final purgeAt = item.deletedAt!.add(const Duration(days: 30));
    return purgeAt.difference(DateTime.now()).inDays;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('回收站')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _deleted.isEmpty
              ? const Center(child: Text('回收站是空的'))
              : RefreshIndicator(
                  onRefresh: _reload,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _deleted.length,
                    itemBuilder: (context, index) {
                      final item = _deleted[index];
                      return Card(
                        child: ListTile(
                          title: Text(item.name),
                          subtitle: Text(
                            '${money(item.price)} · ${_daysLeft(item)} 天后自动清除',
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              TextButton(
                                onPressed: () async {
                                  await ref
                                      .read(itemsProvider.notifier)
                                      .restore(item.id);
                                  await _reload();
                                },
                                child: const Text('恢复'),
                              ),
                              TextButton(
                                onPressed: () => _purge(item),
                                child: const Text('彻底删除'),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
    );
  }

  Future<void> _purge(Item item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('彻底删除？'),
        content: Text('「${item.name}」将无法恢复。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    // 软删除记录的硬删除：直接用仓储的 purge（按时间）不够精确，
    // 这里用 restore+softDelete 之外的方式——执行 SQL 级删除。
    await ref.read(itemRepositoryProvider).hardDelete(item.id);
    await _reload();
  }
}
