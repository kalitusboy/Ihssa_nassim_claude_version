# تطبيق التقارير المتقدمة v11.01 — السكن الريفي

نسخة مُحسّنة من v10.1 — **يمكن تثبيتها بجانب v10.1 دون حذفها** (applicationId
مختلف: `com.ihsa.nassim2026_v11_advanced`).

## الجديد في v11.01

1. **دعم كامل للعربية RTL في تقرير PDF**
   - كل النصوص تستخدم `pw.TextDirection.rtl` و `pw.Directionality`
   - الجداول تستخدم `tableDirection: rtl` و `headerDirection: rtl`
   - خط Cairo محمّل كخط أساسي + خط احتياطي

2. **ترتيب موحّد للبرامج عبر التطبيق**
   - شاشة الإحصائيات (`stats_screen`)، شاشة التقارير المتقدمة، وتقرير PDF
     جميعها تستخدم نفس الترتيب: `MIN(created_at) ASC, program ASC`
   - لا يوجد خلط في ترتيب البرامج بعد الآن

3. **إضافة مستفيد جديد** (`add_beneficiary_screen.dart`)
   - زر عائم (FAB) أخضر في الشاشة الرئيسية
   - يدعم اختيار برنامج موجود أو إنشاء برنامج جديد
   - فحص تلقائي للتكرار (الاسم + اللقب + تاريخ الميلاد + العنوان)

4. **تعديل تسمية برنامج**
   - متاح من شاشة الإحصائيات → أيقونة `edit_note` في شريط العنوان
   - يحدّث جميع السجلات للبرنامج دفعة واحدة

5. **بنية المشروع v11.01 مستقلة**
   - `applicationId = com.ihsa.nassim2026_v11_advanced`
   - اسم الحزمة على أندرويد: `تقارير متقدمة v11.01`
   - مجلد الإخراج: `Download/تقارير_متقدمة_v11/`

## البناء على أندرويد

```bash
flutter pub get
flutter build apk --release
```

## ملاحظات تقنية

- `database_service.renameProgram(oldName, newName)` — دالة جديدة
- `database_service.beneficiaryExists(...)` — للتحقق من التكرار
- `ProgramAdvanced` تحتوي الآن على: `done, inProgress, pillars, finishedNotOcc,
  occupied, elec, gas, water, sew, allNetworks, allFour`
- `Directionality(textDirection: TextDirection.rtl)` على مستوى MaterialApp
  لضمان RTL في كل الواجهة

— حميتي نسيم · الحوضان · 2026
