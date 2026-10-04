import 'package:daily_cost/domain/models/enums.dart';
import 'package:daily_cost/domain/models/item.dart';
import 'package:daily_cost/features/home/application/home_providers.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/pump_app.dart';

void main() {
  testWidgets('空首页显示引导与记一笔入口', (tester) async {
    await pumpApp(tester);

    expect(find.text('还没有记录'), findsOneWidget);
    expect(find.text('记一笔花销，看看它每天花你多少钱'), findsOneWidget);
    expect(find.text('记一笔'), findsWidgets); // 空状态按钮 + FAB
  });

  testWidgets('有记录时显示汇总大数字与卡片', (tester) async {
    final container = await pumpApp(tester);

    // 预置一条固定天数记录：¥300-30 残值，30 天 → 日均 ¥9
    await container.read(itemsProvider.notifier).addItem(
      ItemDraft(
        name: '咖啡机',
        price: 300,
        residual: 30,
        category: '数码',
        purchaseDate: DateTime.now(),
        usageDays: 30,
        calcMode: CalcMode.fixedDays,
        depreciation: DepreciationMethod.straightLine,
        note: '',
        tags: const ['厨房'],
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(find.text('还没有记录'), findsNothing);
    expect(find.text('今日日均总支出'), findsOneWidget);
    expect(find.text('¥9.00'), findsOneWidget); // 汇总大数字
    expect(find.text('¥9.00 /天'), findsOneWidget); // 卡片日均
    expect(find.text('咖啡机'), findsOneWidget);
    expect(find.text('在用 1 项'), findsOneWidget);
    expect(find.text('已用 1/30 天'), findsOneWidget);
    expect(find.text('厨房'), findsOneWidget);
  });
}
