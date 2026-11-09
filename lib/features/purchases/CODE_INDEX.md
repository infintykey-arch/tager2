# فهرس ميزة المشتريات

**المجلد:** `lib/features/purchases/`

**الدور:** تسجيل فواتير الشراء وبنودها ومدفوعاتها، وتحديث بيانات المخزون والتكلفة من خلال المستودع.

## الملفات

- [`data/purchases_repository.dart`](data/purchases_repository.dart) — نماذج الفاتورة وبنودها ونتائجها وعمليات الحفظ والسداد وحسابات تكلفة الشراء.
- [`presentation/purchase_invoice_sheet.dart`](presentation/purchase_invoice_sheet.dart) — واجهة إعداد فاتورة شراء وبنودها، وربط استيراد الفاتورة بخدمة OCR.
- [`presentation/invoice_import_review_sheet.dart`](presentation/invoice_import_review_sheet.dart) — تحليل الصفوف المستوردة وعرضها للمراجعة والتعديل قبل إنشاء بنود الشراء.

## من أين أبدأ التعديل؟

- تغيير الشاشة أو التفاعل: ابدأ من مجلد `presentation/` في هذه الوحدة.
- تغيير القراءة أو الكتابة أو تكامل المنصة: ابدأ من مجلد `data/` في هذه الوحدة.

قبل التعديل، راجع الاختبارات المرتبطة بالميزة في [`test/features/`](../../../test/features/) ثم أضف/حدّث اختبارًا للسلوك الذي تغيّر.
