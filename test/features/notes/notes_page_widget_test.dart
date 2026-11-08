import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tager2/data/local/app_database.dart';
import 'package:tager2/features/notes/data/notes_repository.dart';
import 'package:tager2/features/notes/presentation/notes_page.dart';

void main() {
  testWidgets('يضيف الملاحظة ويعرضها للقراءة ثم يسمح بتعديلها وحذفها', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    final repository = DriftNotesRepository(database);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: NotesPage(repository: repository)),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      find.text('لا توجد ملاحظات بعد. أنشئ أول ملاحظة من الزر أدناه.'),
      findsOneWidget,
    );

    await tester.tap(find.text('ملاحظة جديدة'));
    await tester.pumpAndSettle();
    final editorFields = find.descendant(
      of: find.byType(AlertDialog),
      matching: find.byType(TextField),
    );
    await tester.enterText(editorFields.at(0), 'مواعيد الموردين');
    await tester.enterText(editorFields.at(1), 'الاتصال بالمورد يوم الخميس');
    await tester.tap(find.widgetWithText(FilledButton, 'حفظ'));
    await tester.pumpAndSettle();
    expect(find.text('مواعيد الموردين'), findsOneWidget);

    await tester.tap(find.text('مواعيد الموردين'));
    await tester.pumpAndSettle();
    expect(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.text('الاتصال بالمورد يوم الخميس'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.byType(TextField),
      ),
      findsNothing,
    );

    await tester.tap(find.widgetWithText(FilledButton, 'تعديل'));
    await tester.pumpAndSettle();
    final editFields = find.descendant(
      of: find.byType(AlertDialog),
      matching: find.byType(TextField),
    );
    await tester.enterText(editFields.at(1), 'تم تحديث موعد الاتصال');
    await tester.tap(find.widgetWithText(FilledButton, 'حفظ'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('مواعيد الموردين'));
    await tester.pumpAndSettle();
    expect(find.text('تم تحديث موعد الاتصال'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.byType(TextField),
      ),
      findsNothing,
    );
    await tester.tap(find.widgetWithText(TextButton, 'إغلاق'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('إجراءات الملاحظة'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('حذف الملاحظة'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'حذف'));
    await tester.pumpAndSettle();
    expect(await repository.getNotes(), isEmpty);
    await tester.pumpAndSettle();
    expect(
      find.text('لا توجد ملاحظات بعد. أنشئ أول ملاحظة من الزر أدناه.'),
      findsOneWidget,
    );
  });
}
