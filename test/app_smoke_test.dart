import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/pump_app.dart';

void main() {
  testWidgets('应用启动到首页壳：三分支底部导航可切换', (tester) async {
    await pumpApp(tester);

    // 底部导航三分支
    expect(find.text('首页'), findsOneWidget);
    expect(find.text('试算器'), findsOneWidget);
    expect(find.text('设置'), findsOneWidget);

    // 切到试算器
    await tester.tap(find.text('试算器'));
    await tester.pumpAndSettle();
    expect(find.text('输入价格开始试算'), findsOneWidget);

    // 切到设置
    await tester.tap(find.text('设置'));
    await tester.pumpAndSettle();
    expect(find.text('外观'), findsOneWidget);
    expect(find.text('咖啡单价'), findsOneWidget);

    // 切回首页（空库显示引导）
    await tester.tap(find.text('首页'));
    await tester.pumpAndSettle();
    expect(find.text('还没有记录'), findsOneWidget);
  });

  testWidgets('试算器联动咖啡单价', (tester) async {
    await pumpApp(tester);

    await tester.tap(find.text('试算器'));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.widgetWithText(TextField, '价格'),
      '150',
    );
    await tester.pump();

    // 150 / (30天) = 5.00/天；默认咖啡 ¥15 → 0.33 杯/天；总价 ≈ 10 杯
    expect(find.text('¥5.00 /天'), findsOneWidget);
    expect(find.text('≈ 0.33 杯咖啡 / 天'), findsOneWidget);
    expect(find.textContaining('这笔钱 ≈ 10 杯咖啡'), findsOneWidget);
  });
}
