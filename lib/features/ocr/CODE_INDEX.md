# فهرس ميزة قراءة الفواتير OCR

**المجلد:** `lib/features/ocr/`

**الدور:** توفير خدمة تعرّف نصي تعمل محليًا مع تطبيقات منفصلة للمنصات المدعومة، وربطها بواجهة موحدة.

## الملفات

- [`data/invoice_ocr_service.dart`](data/invoice_ocr_service.dart) — واجهة خدمة OCR المشتركة وتوجيه الاستدعاءات إلى تنفيذ المنصة.
- [`data/invoice_ocr_platform_io.dart`](data/invoice_ocr_platform_io.dart) — تنفيذ التعرف على الصور وملفات PDF للمنصات الأصلية عبر إضافة Tesseract.
- [`data/invoice_ocr_platform_web.dart`](data/invoice_ocr_platform_web.dart) — تنفيذ التعرف على الويب عبر الجسر البرمجي وموارد الويب المحلية.
- [`data/invoice_ocr_platform_stub.dart`](data/invoice_ocr_platform_stub.dart) — تنفيذ بديل للمنصات غير المدعومة لتقديم سلوك واضح بدل اعتماد تنفيذ غير متاح.

## من أين أبدأ التعديل؟

- تغيير القراءة أو الكتابة أو تكامل المنصة: ابدأ من مجلد `data/` في هذه الوحدة.

قبل التعديل، راجع الاختبارات المرتبطة بالميزة في [`test/features/`](../../../test/features/) ثم أضف/حدّث اختبارًا للسلوك الذي تغيّر.
