import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tager2/features/calculator/presentation/calculator_page.dart';

void main() {
  testWidgets('ينفذ الجمع ويعرض خطأ القسمة على صفر بوضوح', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: CalculatorPage())),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(FilledButton, '8'));
    await tester.tap(find.widgetWithText(FilledButton, '+'));
    await tester.tap(find.widgetWithText(FilledButton, '5'));
    await tester.tap(find.widgetWithText(FilledButton, '='));
    await tester.pumpAndSettle();
    expect(find.text('13'), findsNWidgets(2));

    await tester.tap(find.widgetWithText(FilledButton, 'مسح'));
    await tester.tap(find.widgetWithText(FilledButton, '7'));
    await tester.tap(find.widgetWithText(FilledButton, '÷'));
    await tester.tap(find.widgetWithText(FilledButton, '0'));
    await tester.tap(find.widgetWithText(FilledButton, '='));
    await tester.pumpAndSettle();
    expect(find.text('لا يمكن القسمة على صفر.'), findsOneWidget);
  });
}
