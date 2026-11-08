import 'dart:typed_data';

import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../analytics/data/report_repository.dart';
import '../../purchases/data/purchases_repository.dart';
import '../../sales/data/sales_repository.dart';

class InvoicePdfService {
  static const _fontAsset = 'assets/fonts/NotoSansArabic-Regular.ttf';
  static const _blue = PdfColor.fromInt(0xFF1859A9);
  static const _silver = PdfColor.fromInt(0xFF98A6B5);
  static const _line = PdfColor.fromInt(0xFFDCE3EA);

  Future<Uint8List> saleInvoice(SaleReceipt receipt) async {
    final fonts = await _loadFonts();
    final doc = _document(fonts);
    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(34),
        textDirection: pw.TextDirection.rtl,
        theme: _theme(fonts),
        header: (context) => _pageHeader('فاتورة بيع'),
        footer: _pageFooter,
        build: (context) => [
          _invoiceIdentity(receipt.invoiceNumber, receipt.createdAt),
          pw.SizedBox(height: 14),
          _infoLine('العميل', receipt.customerName ?? 'عميل نقدي'),
          _infoLine(
            'طريقة الدفع',
            receipt.paymentKind == SalePaymentKind.cash ? 'نقدي' : 'آجل',
          ),
          pw.SizedBox(height: 14),
          _lineTable(
            headers: const ['الإجمالي', 'سعر الوحدة', 'الكمية', 'الصنف'],
            rows: receipt.lines
                .map(
                  (line) => [
                    _money(line.lineTotalMinor),
                    _money(line.unitPriceMinor),
                    _quantity(line.quantity),
                    line.productName,
                  ],
                )
                .toList(growable: false),
          ),
          pw.SizedBox(height: 16),
          _totals(
            totalMinor: receipt.totalMinor,
            paidMinor: receipt.paidMinor,
            remainingMinor: receipt.remainingMinor,
          ),
          if (receipt.payments.isNotEmpty) ...[
            pw.SizedBox(height: 18),
            _sectionTitle('سجل الدفعات'),
            pw.SizedBox(height: 6),
            _lineTable(
              headers: const ['المبلغ', 'تاريخ الدفعة'],
              rows: receipt.payments
                  .map(
                    (payment) => [
                      _money(payment.amountMinor),
                      _dateTime(payment.occurredAt),
                    ],
                  )
                  .toList(growable: false),
            ),
          ],
        ],
      ),
    );
    return doc.save();
  }

  Future<Uint8List> purchaseInvoice(PurchaseReceipt receipt) async {
    final fonts = await _loadFonts();
    final doc = _document(fonts);
    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(34),
        textDirection: pw.TextDirection.rtl,
        theme: _theme(fonts),
        header: (context) => _pageHeader('فاتورة شراء'),
        footer: _pageFooter,
        build: (context) => [
          _invoiceIdentity(receipt.invoiceNumber, receipt.createdAt),
          pw.SizedBox(height: 14),
          _infoLine('المورد', receipt.supplierName),
          pw.SizedBox(height: 14),
          _lineTable(
            headers: const ['الإجمالي', 'سعر الوحدة', 'الكمية', 'الصنف'],
            rows: receipt.lines
                .map(
                  (line) => [
                    _money(line.lineTotalMinor),
                    _money(line.purchasePriceMinor),
                    _quantity(line.quantity),
                    line.productName,
                  ],
                )
                .toList(growable: false),
          ),
          pw.SizedBox(height: 16),
          _totals(
            totalMinor: receipt.totalMinor,
            paidMinor: receipt.paidMinor,
            remainingMinor: receipt.remainingMinor,
          ),
          if (receipt.payments.isNotEmpty) ...[
            pw.SizedBox(height: 18),
            _sectionTitle('سجل الدفعات'),
            pw.SizedBox(height: 6),
            _lineTable(
              headers: const ['المبلغ', 'تاريخ الدفعة'],
              rows: receipt.payments
                  .map(
                    (payment) => [
                      _money(payment.amountMinor),
                      _dateTime(payment.occurredAt),
                    ],
                  )
                  .toList(growable: false),
            ),
          ],
        ],
      ),
    );
    return doc.save();
  }

  Future<Uint8List> report({
    required DateTime start,
    required DateTime end,
    required ReportSummary summary,
    ReportCategory reportCategory = ReportCategory.overview,
  }) async {
    final fonts = await _loadFonts();
    final doc = _document(fonts);
    final salesRows = <List<String>>[
      [
        '${summary.sales.invoiceCount} فاتورة',
        _money(summary.sales.totalMinor),
        'المبيعات',
      ],
      [
        '—',
        summary.unknownCostLineCount == 0
            ? _money(summary.costOfGoodsSoldMinor)
            : 'غير متاحة',
        'تكلفة البضاعة المباعة',
      ],
      [
        summary.netProfitMinor == null ? 'غير متاح' : 'محسوب',
        summary.netProfitMinor == null
            ? 'غير متاح'
            : _money(summary.netProfitMinor!),
        'صافي الربح',
      ],
    ];
    final rows = switch (reportCategory) {
      ReportCategory.overview => [
        ...salesRows,
        [
          '${summary.purchases.invoiceCount} فاتورة',
          _money(summary.purchases.totalMinor),
          'المشتريات',
        ],
        ['—', _money(summary.expenses.totalMinor), 'المصروفات'],
        [
          '${summary.customerDebts.invoiceCount} عميل',
          _money(summary.customerDebts.totalMinor),
          'المستحق من العملاء',
        ],
        [
          '${summary.supplierDebts.invoiceCount} مورد',
          _money(summary.supplierDebts.totalMinor),
          'المستحق للموردين',
        ],
        [
          '${summary.inventory.productCount} صنف',
          _money(summary.inventory.retailValueMinor),
          'قيمة المخزون بسعر البيع',
        ],
      ],
      ReportCategory.sales => salesRows,
      ReportCategory.purchases => [
        [
          '${summary.purchases.invoiceCount} فاتورة',
          _money(summary.purchases.totalMinor),
          'المشتريات',
        ],
      ],
      ReportCategory.expenses => [
        [
          '${summary.expenses.invoiceCount} مصروف',
          _money(summary.expenses.totalMinor),
          'المصروفات',
        ],
      ],
      ReportCategory.debts => [
        [
          '${summary.customerDebts.invoiceCount} عميل',
          _money(summary.customerDebts.totalMinor),
          'المستحق من العملاء',
        ],
        [
          '${summary.supplierDebts.invoiceCount} مورد',
          _money(summary.supplierDebts.totalMinor),
          'المستحق للموردين',
        ],
      ],
      ReportCategory.inventory => [
        [
          '${summary.inventory.productCount} صنف',
          _money(summary.inventory.retailValueMinor),
          'قيمة المخزون بسعر البيع',
        ],
        ['${summary.inventory.lowStockCount} صنف', '—', 'على وشك النفاد'],
        ['${summary.inventory.missingStockCount} صنف', '—', 'أصناف ناقصة'],
      ],
    };
    final reportTitle = switch (reportCategory) {
      ReportCategory.overview => 'تقرير عام',
      ReportCategory.sales => 'تقرير المبيعات',
      ReportCategory.purchases => 'تقرير المشتريات',
      ReportCategory.expenses => 'تقرير المصروفات',
      ReportCategory.debts => 'تقرير الديون والتحصيلات',
      ReportCategory.inventory => 'تقرير المخزون',
    };
    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(34),
        textDirection: pw.TextDirection.rtl,
        theme: _theme(fonts),
        header: (context) => _pageHeader(reportTitle),
        footer: _pageFooter,
        build: (context) => [
          _infoLine(
            'الفترة',
            '${_date(start)} — ${_date(end.subtract(const Duration(days: 1)))}',
            valueDirection: pw.TextDirection.ltr,
          ),
          pw.SizedBox(height: 18),
          _lineTable(headers: const ['ملاحظات', 'القيمة', 'البند'], rows: rows),
          pw.SizedBox(height: 16),
          if ((reportCategory == ReportCategory.overview ||
                  reportCategory == ReportCategory.sales) &&
              summary.unknownCostLineCount > 0)
            _notice(
              'لا يمكن حساب صافي الربح بدقة: توجد '
              '${summary.unknownCostLineCount} سطور بيع بتكلفة تاريخية غير معروفة. '
              'لم تُقدَّر هذه التكاليف.',
            )
          else if (reportCategory == ReportCategory.overview ||
              reportCategory == ReportCategory.sales)
            _notice(
              'صافي الربح هنا = المبيعات − تكلفة البضاعة المباعة − المصروفات. '
              'إجمالي المشتريات معروض للمراجعة ولا يُطرح مرة ثانية.',
            ),
        ],
      ),
    );
    return doc.save();
  }

  Future<_PdfFonts> _loadFonts() async {
    final arabicData = await rootBundle.load(_fontAsset);
    final latinData = await rootBundle.load(
      'assets/fonts/LiberationSans-Regular.ttf',
    );
    return _PdfFonts(
      arabic: pw.Font.ttf(arabicData),
      latin: pw.Font.ttf(latinData),
    );
  }

  pw.Document _document(_PdfFonts fonts) => pw.Document(
    theme: _theme(fonts),
    compress: true,
    title: 'تاجر ٢',
    author: 'Tager 2 Local Edition',
  );

  pw.ThemeData _theme(_PdfFonts fonts) => pw.ThemeData.withFont(
    base: fonts.arabic,
    bold: fonts.arabic,
    fontFallback: [fonts.latin],
  );

  pw.Widget _pageHeader(String subtitle) => pw.Container(
    margin: const pw.EdgeInsets.only(bottom: 14),
    padding: const pw.EdgeInsets.only(bottom: 8),
    decoration: const pw.BoxDecoration(
      border: pw.Border(bottom: pw.BorderSide(color: _line, width: 0.8)),
    ),
    child: pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Text(subtitle, textDirection: pw.TextDirection.rtl),
        pw.Text(
          'تاجر ٢ · إدارة محلية',
          textDirection: pw.TextDirection.rtl,
          style: pw.TextStyle(
            fontSize: 14,
            color: _blue,
            fontWeight: pw.FontWeight.bold,
          ),
        ),
      ],
    ),
  );

  pw.Widget _pageFooter(pw.Context context) => pw.Container(
    alignment: pw.Alignment.center,
    margin: const pw.EdgeInsets.only(top: 12),
    padding: const pw.EdgeInsets.only(top: 8),
    decoration: const pw.BoxDecoration(
      border: pw.Border(top: pw.BorderSide(color: _line, width: 0.6)),
    ),
    child: pw.Text(
      'صفحة ${context.pageNumber} من ${context.pagesCount}',
      textDirection: pw.TextDirection.rtl,
      style: const pw.TextStyle(fontSize: 8, color: _silver),
    ),
  );

  pw.Widget _invoiceIdentity(String number, DateTime createdAt) => pw.Container(
    padding: const pw.EdgeInsets.all(12),
    decoration: pw.BoxDecoration(
      color: const PdfColor.fromInt(0xFFF3F6F9),
      borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
    ),
    child: pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        _labeledText(
          'التاريخ',
          _dateTime(createdAt),
          valueDirection: pw.TextDirection.ltr,
        ),
        _labeledText(
          'رقم الفاتورة',
          number,
          valueDirection: pw.TextDirection.ltr,
        ),
      ],
    ),
  );

  pw.Widget _labeledText(
    String label,
    String value, {
    pw.TextDirection valueDirection = pw.TextDirection.rtl,
  }) => pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      pw.Text(
        label,
        textDirection: pw.TextDirection.rtl,
        style: const pw.TextStyle(fontSize: 8, color: _silver),
      ),
      pw.SizedBox(height: 3),
      pw.Text(
        value,
        textDirection: valueDirection,
        style: pw.TextStyle(
          fontSize: 11,
          color: _blue,
          fontWeight: pw.FontWeight.bold,
        ),
      ),
    ],
  );

  pw.Widget _infoLine(
    String label,
    String value, {
    pw.TextDirection valueDirection = pw.TextDirection.rtl,
  }) => pw.Padding(
    padding: const pw.EdgeInsets.symmetric(vertical: 3),
    child: pw.Row(
      children: [
        pw.Expanded(child: pw.Text(value, textDirection: valueDirection)),
        pw.SizedBox(
          width: 90,
          child: pw.Text(
            label,
            textDirection: pw.TextDirection.rtl,
            style: pw.TextStyle(color: _silver, fontWeight: pw.FontWeight.bold),
          ),
        ),
      ],
    ),
  );

  pw.Widget _lineTable({
    required List<String> headers,
    required List<List<String>> rows,
  }) {
    final widths = headers.length == 4
        ? <int, pw.TableColumnWidth>{
            0: const pw.FixedColumnWidth(76),
            1: const pw.FixedColumnWidth(82),
            2: const pw.FixedColumnWidth(58),
            3: const pw.FlexColumnWidth(),
          }
        : <int, pw.TableColumnWidth>{
            0: const pw.FixedColumnWidth(100),
            1: const pw.FlexColumnWidth(),
          };
    return pw.Table(
      border: pw.TableBorder(
        horizontalInside: const pw.BorderSide(color: _line, width: 0.5),
        bottom: const pw.BorderSide(color: _line, width: 0.5),
      ),
      columnWidths: widths,
      children: [
        _tableRow(headers, header: true),
        for (final row in rows) _tableRow(row),
      ],
    );
  }

  pw.TableRow _tableRow(
    List<String> cells, {
    bool header = false,
  }) => pw.TableRow(
    decoration: header ? const pw.BoxDecoration(color: _blue) : null,
    children: [
      for (final cell in cells)
        pw.Padding(
          padding: const pw.EdgeInsets.symmetric(horizontal: 7, vertical: 8),
          child: pw.Text(
            cell,
            textDirection: pw.TextDirection.rtl,
            textAlign: pw.TextAlign.right,
            style: pw.TextStyle(
              fontSize: header ? 9 : 9.5,
              color: header ? PdfColors.white : PdfColors.black,
              fontWeight: header ? pw.FontWeight.bold : pw.FontWeight.normal,
            ),
          ),
        ),
    ],
  );

  pw.Widget _totals({
    required int totalMinor,
    required int paidMinor,
    required int remainingMinor,
  }) => pw.Container(
    alignment: pw.Alignment.centerLeft,
    child: pw.Container(
      width: 250,
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: _line),
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
      ),
      child: pw.Column(
        children: [
          _totalLine('إجمالي الفاتورة', totalMinor),
          _totalLine('إجمالي المدفوع', paidMinor),
          pw.Divider(color: _line),
          _totalLine('المتبقي', remainingMinor, emphasize: true),
        ],
      ),
    ),
  );

  pw.Widget _totalLine(
    String label,
    int amount, {
    bool emphasize = false,
  }) => pw.Padding(
    padding: const pw.EdgeInsets.symmetric(vertical: 3),
    child: pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Text(
          _money(amount),
          textDirection: pw.TextDirection.rtl,
          style: pw.TextStyle(
            fontSize: emphasize ? 11 : 9.5,
            color: emphasize ? _blue : PdfColors.black,
            fontWeight: emphasize ? pw.FontWeight.bold : pw.FontWeight.normal,
          ),
        ),
        pw.Text(
          label,
          textDirection: pw.TextDirection.rtl,
          style: pw.TextStyle(
            fontSize: emphasize ? 11 : 9.5,
            fontWeight: emphasize ? pw.FontWeight.bold : pw.FontWeight.normal,
          ),
        ),
      ],
    ),
  );

  pw.Widget _sectionTitle(String title) => pw.Text(
    title,
    textDirection: pw.TextDirection.rtl,
    style: pw.TextStyle(
      fontSize: 12,
      color: _blue,
      fontWeight: pw.FontWeight.bold,
    ),
  );

  pw.Widget _notice(String text) => pw.Container(
    padding: const pw.EdgeInsets.all(12),
    decoration: pw.BoxDecoration(
      color: const PdfColor.fromInt(0xFFF3F6F9),
      border: pw.Border(right: const pw.BorderSide(color: _silver, width: 3)),
    ),
    child: pw.Text(
      text,
      textDirection: pw.TextDirection.rtl,
      style: const pw.TextStyle(fontSize: 9, lineSpacing: 3),
    ),
  );

  String _money(int minor) => '${(minor / 100).toStringAsFixed(2)} ج.م';

  String _quantity(double quantity) {
    final fixed = quantity.toStringAsFixed(3);
    return fixed
        .replaceFirst(RegExp(r'\.0+$'), '')
        .replaceFirst(RegExp(r'(\.\d*?)0+$'), r'$1');
  }

  String _date(DateTime value) =>
      '${value.day.toString().padLeft(2, '0')}/'
      '${value.month.toString().padLeft(2, '0')}/${value.year}';

  String _dateTime(DateTime value) =>
      '${_date(value)} ${value.hour.toString().padLeft(2, '0')}:'
      '${value.minute.toString().padLeft(2, '0')}';
}

class _PdfFonts {
  const _PdfFonts({required this.arabic, required this.latin});

  final pw.Font arabic;
  final pw.Font latin;
}
