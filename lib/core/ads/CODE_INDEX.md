# فهرس مكونات الإعلانات

**المجلد:** `lib/core/ads/` — تحميل الإعدادات وتهيئة وحدات الإعلانات وعرضها ضمن واجهات التطبيق.

- [`ad_config.dart`](ad_config.dart) — قراءة/تفسير إعدادات وحدات الإعلانات من ملف الأصول مع مراعاة المنصة.
- [`startup_ads_initializer.dart`](startup_ads_initializer.dart) — تهيئة الإعلانات بطريقة آمنة بعد أول إطار/حسب نقطة استدعائه.
- [`app_open_ad_service.dart`](app_open_ad_service.dart) — إدارة إعلان فتح التطبيق والاستجابة لدورة حياة التطبيق.
- [`banner_ad_slot.dart`](banner_ad_slot.dart) — عنصر واجهة لموضع إعلان بانر.
- [`native_ad_card.dart`](native_ad_card.dart) — عنصر واجهة لبطاقة إعلان أصلي.

إعداد الوحدات مركزي؛ لا تضف معرفات أو أنواع وحدات جديدة في مواضع متفرقة.
