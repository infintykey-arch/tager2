import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tager2/features/analytics/data/report_repository.dart';
import 'package:tager2/features/analytics/presentation/analytics_page.dart';

void main() {
  testWidgets('يعرض ملخص التقرير وخيارات اليوم والشهر والفترة', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AnalyticsPage(repository: _SampleReportRepository()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('125.00 ج.م'), findsOneWidget);
    expect(find.text('48.00 ج.م'), findsOneWidget);
    expect(find.text('7.50 ج.م'), findsOneWidget);
    expect(find.text('30.00 ج.م'), findsOneWidget);
    expect(find.text('87.50 ج.م'), findsOneWidget);
    expect(find.text('صافي الربح'), findsOneWidget);
    expect(find.text('تصدير التقرير PDF'), findsOneWidget);
    expect(find.text('نوع التقرير'), findsOneWidget);
    await tester.tap(find.widgetWithText(ChoiceChip, 'شهري'));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<ChoiceChip>(find.widgetWithText(ChoiceChip, 'شهري'))
          .selected,
      isTrue,
    );
    await tester.scrollUntilVisible(
      find.text('كل الفواتير'),
      400,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('كل الفواتير'), findsOneWidget);
    expect(find.text('كاملة السداد'), findsOneWidget);
    expect(find.text('آجلة'), findsOneWidget);
  });

  testWidgets('لا يعرض ربحًا مخمّنًا عند وجود تكلفة مجهولة', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AnalyticsPage(
            repository: _SampleReportRepository(unknownCostLineCount: 1),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('غير متاحة'), findsOneWidget);
    expect(find.text('غير متاح'), findsOneWidget);
  });
}

class _SampleReportRepository implements ReportRepository {
  const _SampleReportRepository({this.unknownCostLineCount = 0});

  final int unknownCostLineCount;

  @override
  Future<ReportSummary> getSummary(DateTime start, DateTime end) async =>
      ReportSummary(
        sales: const ReportMetric(totalMinor: 12500, invoiceCount: 3),
        purchases: const ReportMetric(totalMinor: 4800, invoiceCount: 2),
        expenses: const ReportMetric(totalMinor: 750, invoiceCount: 1),
        costOfGoodsSoldMinor: 3000,
        unknownCostLineCount: unknownCostLineCount,
      );

  @override
  Future<List<ReportInvoice>> getInvoices(
    DateTime start,
    DateTime end, {
    int limit = 500,
  }) async => const [];
}
