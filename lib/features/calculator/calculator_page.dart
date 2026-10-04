import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../settings/application/settings_providers.dart';
import 'application/calculator_controller.dart';

/// 试算器：价格 + 时长 → 即时日均 + 趣味对比。
class CalculatorPage extends ConsumerStatefulWidget {
  const CalculatorPage({super.key});

  @override
  ConsumerState<CalculatorPage> createState() => _CalculatorPageState();
}

class _CalculatorPageState extends ConsumerState<CalculatorPage> {
  final _price = TextEditingController();
  final _duration = TextEditingController(text: '1');
  String _unit = '月';

  @override
  void dispose() {
    _price.dispose();
    _duration.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final coffeePrice = ref.watch(coffeePriceProvider);
    final result = computeCalculator(
      priceText: _price.text,
      durationText: _duration.text,
      durationUnit: _unit,
      coffeePriceYuan: coffeePrice,
    );

    return Scaffold(
      appBar: AppBar(title: const Text('试算器')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  TextField(
                    controller: _price,
                    autofocus: true,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    style: theme.textTheme.headlineMedium?.copyWith(
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                    decoration: const InputDecoration(
                      labelText: '价格',
                      prefixText: '¥ ',
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _duration,
                          keyboardType:
                              const TextInputType.numberWithOptions(decimal: true),
                          decoration: const InputDecoration(labelText: '时长'),
                          onChanged: (_) => setState(() {}),
                        ),
                      ),
                      const SizedBox(width: 12),
                      DropdownButton<String>(
                        value: _unit,
                        underline: const SizedBox.shrink(),
                        items: [
                          for (final u in kDurationUnitDays.keys)
                            DropdownMenuItem(value: u, child: Text(u)),
                        ],
                        onChanged: (v) =>
                            setState(() => _unit = v ?? '月'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    result.dailyCost == null
                        ? '¥ — /天'
                        : '${money(result.dailyCost!)} /天',
                    style: theme.textTheme.moneyHuge,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    result.coffeePerDay == null
                        ? '输入价格开始试算'
                        : '≈ ${result.coffeePerDay!.toStringAsFixed(2)} 杯咖啡 / 天',
                    style: theme.textTheme.bodyLarge,
                  ),
                  if (result.coffeeTotal != null) ...[
                    const SizedBox(height: 8),
                    InkWell(
                      onTap: () => context.goNamed('settings'),
                      child: Text(
                        '这笔钱 ≈ ${result.coffeeTotal!.toStringAsFixed(0)} 杯咖啡'
                        '（按 ${money(coffeePrice)}/杯）',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.primary,
                          decoration: TextDecoration.underline,
                          decorationColor: theme.colorScheme.primary,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
