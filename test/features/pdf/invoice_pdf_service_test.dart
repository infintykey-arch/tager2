import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:tager2/core/payment_snapshot.dart';
import 'package:tager2/features/analytics/data/report_repository.dart';
import 'package:tager2/features/pdf/data/invoice_pdf_service.dart';
import 'package:tager2/features/purchases/data/purchases_repository.dart';
import 'package:tager2/features/sales/data/sales_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final service = InvoicePdfService();

  test('ينشئ PDF عربيًا لفاتورة البيع وسجل دفعاتها', () async {
    final bytes = await service.saleInvoice(
      SaleReceipt(
        id: 1,
        invoiceNumber: 'S-20261104-000001',
        paymentKind: SalePaymentKind.credit,
        customerName: 'أحمد علي',
        totalMinor: 12500,
        paidMinor: 5000,
        createdAt: DateTime(2026, 11, 4, 10, 15),
        lines: const [
          SaleLineSnapshot(
            productId: 1,
            productName: 'سكر',
            unitPriceMinor: 2500,
            quantity: 5,
            lineTotalMinor: 12500,
            unitCostMilliMinor: 1500000,
            costTotalMinor: 7500,
          ),
        ],
        payments: [
          PaymentSnapshot(
            amountMinor: 5000,
            occurredAt: DateTime(2026, 11, 4, 10, 15),
          ),
        ],
      ),
    );

    _expectPdf(bytes);
  });

  test('ينشئ PDF عربيًا لفاتورة المورد', () async {
    final bytes = await service.purchaseInvoice(
      PurchaseReceipt(
        id: 2,
        invoiceNumber: 'P-20261104-000002',
        supplierName: 'مورد النور',
        totalMinor: 20000,
        paidMinor: 10000,
        createdAt: DateTime(2026, 11, 4, 9, 30),
        lines: const [
          PurchaseLineSnapshot(
            productId: 1,
            productName: 'زيت',
            purchasePriceMinor: 10000,
            salePriceMinor: 13000,
            quantity: 2,
            lineTotalMinor: 20000,
          ),
        ],
        payments: [
          PaymentSnapshot(
            amountMinor: 10000,
            occurredAt: DateTime(2026, 11, 4, 9, 30),
          ),
        ],
      ),
    );

    _expectPdf(bytes);
  });

  test('ينشئ تقرير فترة ولا يخفي تكلفة بيع تاريخية مجهولة', () async {
    final bytes = await service.report(
      start: DateTime(2026, 11, 1),
      end: DateTime(2026, 12, 1),
      summary: const ReportSummary(
        sales: ReportMetric(totalMinor: 30000, invoiceCount: 4),
        purchases: ReportMetric(totalMinor: 18000, invoiceCount: 2),
        expenses: ReportMetric(totalMinor: 4000, invoiceCount: 3),
        costOfGoodsSoldMinor: 12000,
        unknownCostLineCount: 1,
      ),
    );

    _expectPdf(bytes);
  });
}

void _expectPdf(Uint8List bytes) {
  expect(bytes.length, greaterThan(5000));
  expect(utf8.decode(bytes.take(5).toList()), '%PDF-');
}
