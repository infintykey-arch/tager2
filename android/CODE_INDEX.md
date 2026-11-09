# فهرس Android

**المجلد:** `android/` — إعداد بناء وتشغيل Flutter على Android والملفات الأصلية اللازمة.

- [`app/build.gradle.kts`](app/build.gradle.kts) — إعداد وحدة التطبيق، الهوية، الاعتماديات، وإعدادات بناء/توقيع Android. راجع تعليمات README قبل تعديل التوقيع.
- [`app/src/main/AndroidManifest.xml`](app/src/main/AndroidManifest.xml) — تعريف التطبيق وخصائص/صلاحيات Android.
- [`app/src/main/kotlin/com/infintykey/tager2/MainActivity.kt`](app/src/main/kotlin/com/infintykey/tager2/MainActivity.kt) — نقطة نشاط Flutter الأصلية.
- [`app/src/main/kotlin/com/infintykey/tager2/Tager2Application.kt`](app/src/main/kotlin/com/infintykey/tager2/Tager2Application.kt) — صنف تطبيق Android الأصلي إن احتاج بدء التطبيق تهيئة خاصة.
- `app/src/main/res/` — موارد الإطلاق والألوان والثيم وأيقونات Android.
- `build.gradle.kts`, `settings.gradle.kts`, `gradle.properties`, و`gradle/wrapper/` — إعداد Gradle العام والـ wrapper.

غالبية واجهات المنتج ومنطق ميزاته موجودة في `lib/` وليس هنا؛ عدّل ملفات Android فقط للتكامل أو البناء الخاص بالمنصة.
