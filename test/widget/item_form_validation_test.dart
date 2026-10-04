import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/pump_app.dart';

/// 表单很长（ListView 懒加载），放大画布让整表单可见，
/// 避免拖拽手势被中间的 TextField 吸收。
void _useTallSurface(WidgetTester tester) {
  tester.view.physicalSize = const Size(1080, 2600);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
}

void main() {
  testWidgets('空表单保存显示必填校验', (tester) async {
    _useTallSurface(tester);
    await pumpApp(tester);

    // 从空状态进入「记一笔」
    await tester.tap(find.text('记一笔').first);
    await tester.pumpAndSettle();

    expect(find.text('记一笔'), findsOneWidget); // AppBar 标题

    await tester.tap(find.text('保存'));
    await tester.pump();

    expect(find.text('请输入名称'), findsOneWidget);
    expect(find.text('请输入价格'), findsOneWidget);
    expect(find.text('请输入使用天数'), findsOneWidget);
  });

  testWidgets('fixedDays 实时预览随输入更新', (tester) async {
    _useTallSurface(tester);
    await pumpApp(tester);

    await tester.tap(find.text('记一笔').first);
    await tester.pumpAndSettle();

    // 初始无价格：日均 ¥0.00（空天数被引擎钳为 1）
    expect(find.text('日均 ¥0.00'), findsOneWidget);
    expect(find.text('共 1 天'), findsOneWidget);

    await tester.enterText(
      find.widgetWithText(TextFormField, '名称'),
      '烤箱',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, '价格'),
      '300',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, '残值'),
      '30',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, '使用天数'),
      '30',
    );
    await tester.pump();

    // (300-30)/30 = 9.00
    expect(find.text('日均 ¥9.00'), findsOneWidget);
    expect(find.text('共 30 天'), findsOneWidget);
  });
}
