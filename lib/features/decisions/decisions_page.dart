import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/utils/formatters.dart';
import '../../domain/models/enums.dart';
import '../../domain/models/item.dart';
import '../home/application/home_providers.dart';
import '../lifecycle/application/lifecycle_engine.dart';
import 'application/decision_engine.dart';

/// 购物决策：待购清单（冷静期）+ 对比 + 决策计算器。
class DecisionsPage extends ConsumerStatefulWidget {
  const DecisionsPage({super.key});

  @override
  ConsumerState<DecisionsPage> createState() => _DecisionsPageState();
}

class _DecisionsPageState extends ConsumerState<DecisionsPage> {
  final _selected = <int>{};

  @override
  Widget build(BuildContext context) {
    final wishlist = ref.watch(wishlistItemsProvider);
    final results = ref.watch(calcResultsProvider);
    final theme = Theme.of(context);
    final today = DateTime.now();

    return Scaffold(
      appBar: AppBar(title: const Text('购物决策')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('待购清单', style: theme.textTheme.titleSmall),
          const SizedBox(height: 8),
          if (wishlist.isEmpty)
            const _Hint(
              '待购清单是空的。记一笔时把状态设为「想买 / 待购」就会出现在这里，'
              '并开始冷静期倒计时。',
            )
          else
            for (final item in wishlist)
              Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: CheckboxListTile(
                  value: _selected.contains(item.id),
                  onChanged: (v) => setState(() {
                    v == true
                        ? _selected.add(item.id)
                        : _selected.remove(item.id);
                  }),
                  title: Text(item.name),
                  subtitle: Text(
                    '${money(item.price)} · 日均约 ${money(results[item.id]?.dailyCost ?? 0)}'
                    '${_cooldownText(item, today)}',
                  ),
                  secondary: PopupMenuButton<String>(
                    onSelected: (v) => _act(v, item),
                    itemBuilder: (_) => const [
                      PopupMenuItem(value: 'start', child: Text('转为使用中')),
                      PopupMenuItem(value: 'edit', child: Text('编辑')),
                      PopupMenuItem(value: 'del', child: Text('删除')),
                    ],
                  ),
                ),
              ),
          if (_selected.length >= 2) ...[
            const SizedBox(height: 8),
            _CompareTable(
              items: [for (final it in wishlist) if (_selected.contains(it.id)) it],
            ),
          ],
          const SizedBox(height: 24),
          Text('决策计算器', style: theme.textTheme.titleSmall),
          const SizedBox(height: 8),
          const _BuyVsRentCalculator(),
          const SizedBox(height: 12),
          const _FullVsInstallmentCalculator(),
          const SizedBox(height: 12),
          const _NewVsUsedCalculator(),
          const SizedBox(height: 12),
          const _SensitivityCalculator(),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  String _cooldownText(Item item, DateTime today) {
    final left = cooldownDaysLeft(
      cooldownUntil: item.cooldownUntil,
      today: today,
    );
    if (left == null) return '';
    if (left > 0) return ' · 冷静期还剩 $left 天';
    if (left == 0) return ' · 冷静期今天结束';
    return ' · 冷静期已结束';
  }

  Future<void> _act(String action, Item item) async {
    final notifier = ref.read(itemsProvider.notifier);
    switch (action) {
      case 'start':
        await notifier.updateItem(item.copyWith(lifecycle: ItemLifecycle.inUse));
      case 'edit':
        context.pushNamed('itemEdit', pathParameters: {'id': '${item.id}'});
      case 'del':
        await notifier.softDelete(item.id);
    }
  }
}

/// 多物品对比表。
class _CompareTable extends StatelessWidget {
  const _CompareTable({required this.items});

  final List<Item> items;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('对比（最多 4 件）', style: theme.textTheme.bodySmall),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                headingRowHeight: 32,
                dataRowMinHeight: 32,
                dataRowMaxHeight: 40,
                columns: [
                  const DataColumn(label: Text('')),
                  for (final it in items.take(4))
                    DataColumn(label: Text(it.name)),
                ],
                rows: [
                  DataRow(cells: [
                    const DataCell(Text('价格')),
                    for (final it in items.take(4))
                      DataCell(Text(money(it.price))),
                  ]),
                  DataRow(cells: [
                    const DataCell(Text('总成本')),
                    for (final it in items.take(4))
                      DataCell(Text(money(it.tcoTotal))),
                  ]),
                  DataRow(cells: [
                    const DataCell(Text('日均')),
                    for (final it in items.take(4))
                      DataCell(Text('${money(it.price / (it.usageDays ?? 30))}/天')),
                  ]),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Hint extends StatelessWidget {
  const _Hint(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Text(
    text,
    style: Theme.of(context).textTheme.bodySmall?.copyWith(
      color: Theme.of(context).colorScheme.onSurfaceVariant,
      height: 1.6,
    ),
  );
}

/// 计算器通用外壳。
class _CalcCard extends StatelessWidget {
  const _CalcCard({required this.title, required this.fields, required this.result});

  final String title;
  final List<Widget> fields;
  final Widget result;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 8),
          Wrap(spacing: 12, runSpacing: 8, children: fields),
          const SizedBox(height: 10),
          result,
        ],
      ),
    ),
  );
}

Widget _numField(
  TextEditingController c,
  String label, {
  required VoidCallback onChanged,
  String prefix = '¥ ',
  bool integer = false,
}) =>
    SizedBox(
      width: 120,
      child: TextField(
        controller: c,
        keyboardType: integer
            ? TextInputType.number
            : const TextInputType.numberWithOptions(decimal: true),
        decoration: InputDecoration(labelText: label, prefixText: prefix),
        onChanged: (_) => onChanged(),
      ),
    );

class _BuyVsRentCalculator extends ConsumerStatefulWidget {
  const _BuyVsRentCalculator();

  @override
  ConsumerState<_BuyVsRentCalculator> createState() =>
      _BuyVsRentCalculatorState();
}

class _BuyVsRentCalculatorState extends ConsumerState<_BuyVsRentCalculator> {
  final _price = TextEditingController();
  final _residual = TextEditingController(text: '0');
  final _rent = TextEditingController();
  final _months = TextEditingController(text: '12');

  @override
  void dispose() {
    for (final c in [_price, _residual, _rent, _months]) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final r = buyVsRent(
      buyPrice: double.tryParse(_price.text) ?? 0,
      residual: double.tryParse(_residual.text) ?? 0,
      rentPerMonth: double.tryParse(_rent.text) ?? 0,
      months: int.tryParse(_months.text) ?? 12,
    );
    final active = _price.text.isNotEmpty && _rent.text.isNotEmpty;

    return _CalcCard(
      title: '买 vs 租',
      fields: [
        _numField(_price, '买断价', onChanged: () => setState(() {})),
        _numField(_residual, '残值', onChanged: () => setState(() {})),
        _numField(_rent, '月租金', onChanged: () => setState(() {})),
        _numField(_months, '用（月）',
            onChanged: () => setState(() {}),
            prefix: '',
            integer: true),
      ],
      result: Text(
        !active
            ? '输入买断价与月租金开始对比'
            : r.buyCheaper
                ? '买断更划算：净支出 ${money(r.buyTotal)} vs 租金共 ${money(r.rentTotal)}'
                : '租更划算：租金共 ${money(r.rentTotal)} vs 买断净支出 ${money(r.buyTotal)}',
      ),
    );
  }
}

class _FullVsInstallmentCalculator extends ConsumerStatefulWidget {
  const _FullVsInstallmentCalculator();

  @override
  ConsumerState<_FullVsInstallmentCalculator> createState() =>
      _FullVsInstallmentCalculatorState();
}

class _FullVsInstallmentCalculatorState
    extends ConsumerState<_FullVsInstallmentCalculator> {
  final _price = TextEditingController();
  final _apr = TextEditingController(text: '0');
  final _months = TextEditingController(text: '12');

  @override
  void dispose() {
    for (final c in [_price, _apr, _months]) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final r = fullVsInstallment(
      price: double.tryParse(_price.text) ?? 0,
      aprPercent: double.tryParse(_apr.text) ?? 0,
      months: int.tryParse(_months.text) ?? 12,
    );
    final active = _price.text.isNotEmpty;

    return _CalcCard(
      title: '全款 vs 分期（等额本息）',
      fields: [
        _numField(_price, '价格', onChanged: () => setState(() {})),
        _numField(_apr, '年利率 %',
            onChanged: () => setState(() {}),
            prefix: ''),
        _numField(_months, '期数（月）',
            onChanged: () => setState(() {}),
            prefix: '',
            integer: true),
      ],
      result: Text(
        !active
            ? '输入价格开始对比'
            : r.interestCost <= 0
                ? '零利息分期与全款相同：${money(r.fullPrice)}（月供 ${money(r.monthlyPayment)}）'
                : '分期总额 ${money(r.totalPaid)}（利息 ${money(r.interestCost)}，月供 ${money(r.monthlyPayment)}）'
                      ' vs 全款 ${money(r.fullPrice)}',
      ),
    );
  }
}

class _NewVsUsedCalculator extends ConsumerStatefulWidget {
  const _NewVsUsedCalculator();

  @override
  ConsumerState<_NewVsUsedCalculator> createState() =>
      _NewVsUsedCalculatorState();
}

class _NewVsUsedCalculatorState extends ConsumerState<_NewVsUsedCalculator> {
  final _newPrice = TextEditingController();
  final _usedPrice = TextEditingController();
  final _newDays = TextEditingController(text: '365');
  final _usedDays = TextEditingController(text: '180');

  @override
  void dispose() {
    for (final c in [_newPrice, _usedPrice, _newDays, _usedDays]) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final r = newVsUsed(
      newPrice: double.tryParse(_newPrice.text) ?? 0,
      usedPrice: double.tryParse(_usedPrice.text) ?? 0,
      newDays: double.tryParse(_newDays.text) ?? 365,
      usedDays: double.tryParse(_usedDays.text) ?? 180,
    );
    final active = _newPrice.text.isNotEmpty && _usedPrice.text.isNotEmpty;

    return _CalcCard(
      title: '新品 vs 二手（日均对比）',
      fields: [
        _numField(_newPrice, '新品价', onChanged: () => setState(() {})),
        _numField(_usedPrice, '二手价', onChanged: () => setState(() {})),
        _numField(_newDays, '新品用（天）',
            onChanged: () => setState(() {}),
            prefix: '',
            integer: true),
        _numField(_usedDays, '二手用（天）',
            onChanged: () => setState(() {}),
            prefix: '',
            integer: true),
      ],
      result: Text(
        !active
            ? '输入两个价格开始对比'
            : r.usedCheaper
                ? '二手更划算：${money(r.dailyUsed)}/天 vs 新品 ${money(r.dailyNew)}/天'
                : '新品更划算：${money(r.dailyNew)}/天 vs 二手 ${money(r.dailyUsed)}/天',
      ),
    );
  }
}

class _SensitivityCalculator extends ConsumerStatefulWidget {
  const _SensitivityCalculator();

  @override
  ConsumerState<_SensitivityCalculator> createState() =>
      _SensitivityCalculatorState();
}

class _SensitivityCalculatorState
    extends ConsumerState<_SensitivityCalculator> {
  final _cost = TextEditingController();

  @override
  void dispose() {
    _cost.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final points = sensitivity(
      effectiveCost: double.tryParse(_cost.text) ?? 0,
    );
    final active = _cost.text.isNotEmpty;

    return _CalcCard(
      title: '年限敏感性：用得越久越便宜',
      fields: [
        _numField(_cost, '总成本', onChanged: () => setState(() {})),
      ],
      result: !active
          ? const Text('输入总成本，看不同使用年限的日均')
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final p in points)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Text(
                      '${p.days} 天（${(p.days / 365).toStringAsFixed(1)} 年）→ ${money(p.daily)}/天',
                    ),
                  ),
              ],
            ),
    );
  }
}
