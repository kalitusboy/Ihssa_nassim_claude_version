// ═══════════════════════════════════════════════════════════════════
// خدمة التقارير المتقدمة v11.01
// ─────────────────────────────────────────────────────────────────
// ★ دعم كامل للعربية RTL في تقرير PDF (Right-To-Left)
// ★ ترتيب البرامج موحَّد مع شاشة الإحصائيات العامة (stats_screen)
//   عبر MIN(created_at) ثم program ASC
// ★ يعمل على Android و Windows (Flutter Desktop)
// ═══════════════════════════════════════════════════════════════════
import 'dart:io';
import 'package:archive/archive.dart';
import 'package:excel/excel.dart';
import 'package:open_file/open_file.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:flutter/services.dart' show rootBundle;
import 'database_service.dart';
import '../models/beneficiary.dart';

// ─────────────────────────────────────────────────────────────────
// نموذج بيانات البرنامج (مطابق لأعمدة شاشة الإحصائيات العامة)
// ─────────────────────────────────────────────────────────────────
class ProgramAdvanced {
  final String program;
  final int quota;            // الحصة (إجمالي السجلات)
  final int done;             // المحصاة (done=1)
  final int inProgress;       // في طور الانجاز
  final int pillars;          // على مستوى الاعمدة
  final int finishedNotOcc;   // منتهية غير مشغولة
  final int occupied;         // منتهية ومشغولة
  final int elec;             // كهرباء (للمنتهية المشغولة)
  final int gas;              // غاز
  final int water;            // ماء
  final int sew;              // تطهير
  final int allNetworks;      // كل الشبكات (كهرباء+غاز+ماء)
  final int allFour;          // الأربعة معاً

  // أعمدة "كل الحالات" — مطابقة تماماً لشاشة الإحصائيات
  final int elecAll;
  final int gasAll;
  final int waterAll;
  final int sewAll;

  ProgramAdvanced({
    required this.program,
    required this.quota,
    required this.done,
    required this.inProgress,
    required this.pillars,
    required this.finishedNotOcc,
    required this.occupied,
    required this.elec,
    required this.gas,
    required this.water,
    required this.sew,
    required this.allNetworks,
    required this.allFour,
    required this.elecAll,
    required this.gasAll,
    required this.waterAll,
    required this.sewAll,
  });
}

class AdvancedReportService {
  static final AdvancedReportService _i = AdvancedReportService._();
  factory AdvancedReportService() => _i;
  AdvancedReportService._();

  final _db = DatabaseService();

  // ════════════════════════════════════════════════════════════════
  // ① حساب الإحصائيات لكل برنامج — بنفس ترتيب شاشة الإحصائيات
  // ════════════════════════════════════════════════════════════════
  Future<List<ProgramAdvanced>> computePerProgram() async {
   final db = await _db.database;
   final rows = await db.rawQuery('''
    SELECT
      program,
      COUNT(*) AS quota,
      SUM(CASE WHEN done=1 THEN 1 ELSE 0 END) AS done,
      SUM(CASE WHEN done=1 AND status='في طور الانجاز'    THEN 1 ELSE 0 END) AS in_progress,
      SUM(CASE WHEN done=1 AND status='على مستوى الاعمدة' THEN 1 ELSE 0 END) AS pillars,
      SUM(CASE WHEN done=1 AND status='منتهية غير مشغولة' THEN 1 ELSE 0 END) AS fin_not_occ,
      SUM(CASE WHEN done=1 AND status='منتهية ومشغولة'    THEN 1 ELSE 0 END) AS occupied,

      SUM(CASE WHEN done=1 AND status='منتهية ومشغولة' AND electricity=1 THEN 1 ELSE 0 END) AS elec,
      SUM(CASE WHEN done=1 AND status='منتهية ومشغولة' AND gas=1         THEN 1 ELSE 0 END) AS gas,
      SUM(CASE WHEN done=1 AND status='منتهية ومشغولة' AND water=1       THEN 1 ELSE 0 END) AS water,
      SUM(CASE WHEN done=1 AND status='منتهية ومشغولة' AND sewage=1      THEN 1 ELSE 0 END) AS sew,

      SUM(CASE WHEN done=1 AND electricity=1 THEN 1 ELSE 0 END) AS elec_all,
      SUM(CASE WHEN done=1 AND gas=1         THEN 1 ELSE 0 END) AS gas_all,
      SUM(CASE WHEN done=1 AND water=1       THEN 1 ELSE 0 END) AS water_all,
      SUM(CASE WHEN done=1 AND sewage=1      THEN 1 ELSE 0 END) AS sew_all,

      SUM(CASE WHEN done=1 AND status='منتهية ومشغولة'
               AND electricity=1 AND gas=1 AND water=1
              THEN 1 ELSE 0 END) AS all3,
      SUM(CASE WHEN done=1 AND status='منتهية ومشغولة'
               AND electricity=1 AND gas=1 AND water=1 AND sewage=1
              THEN 1 ELSE 0 END) AS all4,

      MAX(id) AS max_id   -- ★ بدلاً من MIN(created_at)
     FROM beneficiaries
     WHERE program IS NOT NULL AND program != ''
     GROUP BY program
     ORDER BY max_id DESC    -- ★ ترتيب مطابق لـ correct_stats_screen
   ''');
  // ... باقي الكود كما هو

    return rows.map((r) => ProgramAdvanced(
      program:        (r['program']     ?? '').toString(),
      quota:          (r['quota']        as int? ?? 0),
      done:           (r['done']         as int? ?? 0),
      inProgress:     (r['in_progress']  as int? ?? 0),
      pillars:        (r['pillars']      as int? ?? 0),
      finishedNotOcc: (r['fin_not_occ']  as int? ?? 0),
      occupied:       (r['occupied']     as int? ?? 0),
      elec:           (r['elec']         as int? ?? 0),
      gas:            (r['gas']          as int? ?? 0),
      water:          (r['water']        as int? ?? 0),
      sew:            (r['sew']          as int? ?? 0),
      elecAll:        (r['elec_all']     as int? ?? 0),
      gasAll:         (r['gas_all']      as int? ?? 0),
      waterAll:       (r['water_all']    as int? ?? 0),
      sewAll:         (r['sew_all']      as int? ?? 0),
      allNetworks:    (r['all3']         as int? ?? 0),
      allFour:        (r['all4']         as int? ?? 0),
    )).toList();
  }

  // ════════════════════════════════════════════════════════════════
  // ② قائمة المنتهية المشغولة (لبرنامج واحد أو الكل)
  // ════════════════════════════════════════════════════════════════
  Future<List<Beneficiary>> getOccupiedFinishedList({String? program}) async {
    final db = await _db.database;
    final where = StringBuffer("done=1 AND status='منتهية ومشغولة'");
    final args = <Object?>[];
    if (program != null && program.isNotEmpty) {
      where.write(' AND program = ?');
      args.add(program);
    }
    final maps = await db.query('beneficiaries',
        where: where.toString(),
        whereArgs: args,
        orderBy: 'last_name, first_name');
    return maps.map(Beneficiary.fromMap).toList();
  }

  // ════════════════════════════════════════════════════════════════
  // ③ تصدير قائمة المنتهية المشغولة → Excel
  // ════════════════════════════════════════════════════════════════
  Future<String> exportOccupiedListExcel({String? program}) async {
    final list = await getOccupiedFinishedList(program: program);
    if (list.isEmpty) throw Exception('لا توجد سكنات منتهية ومشغولة');

    final excel = Excel.createExcel();
    final sheet = excel['المنتهية_المشغولة'];
    const headers = [
      'الرقم', 'الإسم واللقب', 'تاريخ الميلاد', 'مكان الميلاد',
      'العنوان', 'البرنامج',
      'كهرباء', 'غاز', 'مياه', 'تطهير',
      'كل الشبكات', 'الحالة',
    ];
    for (var i = 0; i < headers.length; i++) {
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0))
          .value = TextCellValue(headers[i]);
    }
    for (var i = 0; i < list.length; i++) {
      final b = list[i];
      final row = i + 1;
      void cell(int c, dynamic v) => sheet
          .cell(CellIndex.indexByColumnRow(columnIndex: c, rowIndex: row))
          .value = (v is int ? IntCellValue(v) : TextCellValue(v.toString()));
      cell(0, i + 1);
      cell(1, b.displayName);
      cell(2, b.birthDate ?? '');
      cell(3, b.birthPlace ?? '');
      cell(4, b.address ?? '');
      cell(5, b.program ?? '');
      cell(6, b.electricity);
      cell(7, b.gas);
      cell(8, b.water);
      cell(9, b.sewage);
      cell(10, (b.electricity == 1 && b.gas == 1 && b.water == 1) ? 1 : 0);
      cell(11, b.status);
    }

    final outDir = await _outputDir();
    final safe = (program ?? 'الكل').replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
    final ts   = DateTime.now().millisecondsSinceEpoch;
    final path = p.join(outDir.path, 'منتهية_مشغولة_${safe}_$ts.xlsx');
    await File(path).writeAsBytes(excel.encode()!);
    await OpenFile.open(path);
    return path;
  }

  // ════════════════════════════════════════════════════════════════
  // ④ تصدير صور المنتهية المشغولة → ZIP
  // ════════════════════════════════════════════════════════════════
  Future<String> exportOccupiedFinishedPhotosZip({String? program}) async {
    final db = await _db.database;
    final where = StringBuffer(
        "done=1 AND status='منتهية ومشغولة' "
        "AND image_file_name IS NOT NULL AND image_file_name != ''");
    final args = <Object?>[];
    if (program != null && program.isNotEmpty) {
      where.write(' AND program = ?');
      args.add(program);
    }
    final rows = await db.query('beneficiaries',
        columns: ['image_file_name', 'image_path', 'first_name', 'last_name', 'program'],
        where: where.toString(), whereArgs: args);
    if (rows.isEmpty) throw Exception('لا توجد صور للمنتهية المشغولة');

    final archive = Archive();
    int n = 0;
    for (final r in rows) {
      final path = (r['image_path'] ?? '').toString();
      final name = (r['image_file_name'] ?? '').toString();
      if (path.isEmpty || name.isEmpty) continue;
      final f = File(path);
      if (!await f.exists()) continue;
      final bytes = await f.readAsBytes();
      final prog = (r['program'] ?? 'عام').toString().replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
      final fn   = (r['first_name'] ?? '').toString().trim();
      final ln   = (r['last_name']  ?? '').toString().trim();
      final ext  = p.extension(name).isEmpty ? '.jpg' : p.extension(name);
      final entry = '$prog/${ln}_${fn}_$name'.replaceAll(' ', '_');
      archive.addFile(ArchiveFile(
          entry.endsWith(ext) ? entry : '$entry$ext',
          bytes.length, bytes));
      n++;
    }
    if (n == 0) throw Exception('لا توجد صور صالحة للتصدير');

    final outDir = await _outputDir();
    final safe = (program ?? 'الكل').replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
    final ts   = DateTime.now().millisecondsSinceEpoch;
    final fp   = p.join(outDir.path, 'صور_منتهية_مشغولة_${safe}_$n_$ts.zip');
    final bytes = ZipEncoder().encode(archive)!;
    await File(fp).writeAsBytes(bytes);
    return fp;
  }

  // ════════════════════════════════════════════════════════════════
  // ⑤ توليد تقرير PDF — RTL كامل + ترتيب موحَّد
  // ────────────────────────────────────────────────────────────────
  // المفتاح الأساسي لدعم العربية بشكل صحيح في مكتبة pdf:
  //   1) تحميل خط Cairo TTF كخط أساسي + bold + fontFallback
  //   2) ضبط textDirection=rtl على Page و على كل Text/Table
  //   3) لفّ كل قسم بـ pw.Directionality(textDirection: rtl, child: ...)
  //   4) tableDirection و headerDirection = rtl لكل جدول
  //   5) إبقاء الأرقام بـ TextDirection.ltr لتظهر صحيحة
  // ════════════════════════════════════════════════════════════════
  Future<String> exportAdvancedPdf({
    required String wilaya,
    required String daira,
    required String baladia,
    required String reportNumber,
    required String dateAr,
  }) async {
    // البرامج مرتّبة بنفس ترتيب شاشة الإحصائيات
    final stats = await computePerProgram();

    // ── تحميل خطوط Cairo (تدعم العربية بشكل كامل) ──────────────
    final cairoReg  = pw.Font.ttf(
        await rootBundle.load('assets/fonts/Cairo-Regular.ttf'));
    final cairoBold = pw.Font.ttf(
        await rootBundle.load('assets/fonts/Cairo-Bold.ttf'));

    // ★ مهم جداً: fontFallback يضمن عدم ظهور صناديق فارغة لأي حرف
    final theme = pw.ThemeData.withFont(
      base: cairoReg,
      bold: cairoBold,
      fontFallback: [cairoReg, cairoBold],
    );

    final pdf = pw.Document(
      theme: theme,
      title: 'تقرير إحصائي متقدم',
      author: 'تطبيق التقارير المتقدمة v11.01',
    );

    // ── أنماط النصوص العربية (RTL) ─────────────────────────────
    pw.TextStyle arBold(double size, {PdfColor? color}) => pw.TextStyle(
          font: cairoBold,
          fontFallback: [cairoBold, cairoReg],
          fontSize: size,
          fontWeight: pw.FontWeight.bold,
          color: color ?? PdfColors.black,
        );

    pw.TextStyle arReg(double size, {PdfColor? color}) => pw.TextStyle(
          font: cairoReg,
          fontFallback: [cairoReg, cairoBold],
          fontSize: size,
          color: color ?? PdfColors.black,
        );

    // ── دالة مساعدة: نص عربي مع ضمان RTL ───────────────────────
    pw.Widget arText(String text,
        {pw.TextStyle? style, pw.TextAlign align = pw.TextAlign.right}) {
      return pw.Directionality(
        textDirection: pw.TextDirection.rtl,
        child: pw.Text(
          text,
          textDirection: pw.TextDirection.rtl,
          textAlign: align,
          style: style ?? arReg(11),
        ),
      );
    }

    // ── دالة مساعدة: نص بأرقام (LTR) داخل سياق RTL ─────────────
    pw.Widget numText(String text, {pw.TextStyle? style}) => pw.Text(
          text,
          textDirection: pw.TextDirection.ltr,
          textAlign: pw.TextAlign.center,
          style: style ?? arBold(12),
        );

    // ── KPI Card ────────────────────────────────────────────────
    pw.Widget kpi(String label, int value, PdfColor color) {
      return pw.Container(
        padding: const pw.EdgeInsets.symmetric(vertical: 8, horizontal: 6),
        decoration: pw.BoxDecoration(
          color: color,
          borderRadius: pw.BorderRadius.circular(8),
        ),
        child: pw.Column(children: [
          pw.Text(
            '$value',
            textDirection: pw.TextDirection.ltr,
            style: arBold(18, color: PdfColors.white),
          ),
          pw.SizedBox(height: 3),
          pw.Directionality(
            textDirection: pw.TextDirection.rtl,
            child: pw.Text(
              label,
              textDirection: pw.TextDirection.rtl,
              textAlign: pw.TextAlign.center,
              style: arReg(9, color: PdfColors.white),
            ),
          ),
        ]),
      );
    }

    // ── حساب الإجماليات ────────────────────────────────────────
    final totalQuota   = stats.fold<int>(0, (s, e) => s + e.quota);
    final totalDone    = stats.fold<int>(0, (s, e) => s + e.done);
    final totalInProg  = stats.fold<int>(0, (s, e) => s + e.inProgress);
    final totalPill    = stats.fold<int>(0, (s, e) => s + e.pillars);
    final totalFinNO   = stats.fold<int>(0, (s, e) => s + e.finishedNotOcc);
    final totalOcc     = stats.fold<int>(0, (s, e) => s + e.occupied);
    final totalElecAll = stats.fold<int>(0, (s, e) => s + e.elecAll);
    final totalGasAll  = stats.fold<int>(0, (s, e) => s + e.gasAll);
    final totalWatAll  = stats.fold<int>(0, (s, e) => s + e.waterAll);
    final totalSewAll  = stats.fold<int>(0, (s, e) => s + e.sewAll);
    final totalElec    = stats.fold<int>(0, (s, e) => s + e.elec);
    final totalGas     = stats.fold<int>(0, (s, e) => s + e.gas);
    final totalWater   = stats.fold<int>(0, (s, e) => s + e.water);
    final totalSew     = stats.fold<int>(0, (s, e) => s + e.sew);
    final totalAll3    = stats.fold<int>(0, (s, e) => s + e.allNetworks);

    final totalProgPct = totalQuota > 0
        ? '${(totalDone / totalQuota * 100).round()}%'
        : '0%';

    // ════════════════════════════════════════════════════════════
    // بناء صفحات PDF — كل المحتوى داخل Directionality(rtl)
    // ════════════════════════════════════════════════════════════
    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.fromLTRB(28, 28, 28, 28),
        textDirection: pw.TextDirection.rtl, // ★ RTL على مستوى الصفحة
        theme: theme,

        // ── الترويسة (Header) ─────────────────────────────────
        header: (ctx) => pw.Directionality(
          textDirection: pw.TextDirection.rtl,
          child: pw.Container(
            alignment: pw.Alignment.center,
            margin: const pw.EdgeInsets.only(bottom: 6),
            child: ctx.pageNumber == 1
                ? pw.SizedBox.shrink()
                : pw.Text(
                    'تقرير إحصائي متقدم — السكن الريفي',
                    textDirection: pw.TextDirection.rtl,
                    style: arBold(10, color: PdfColors.indigo900),
                  ),
          ),
        ),

        // ── الذيل (Footer) ────────────────────────────────────
        footer: (ctx) => pw.Directionality(
          textDirection: pw.TextDirection.rtl,
          child: pw.Container(
            alignment: pw.Alignment.center,
            margin: const pw.EdgeInsets.only(top: 6),
            child: pw.Text(
              'تطبيق التقارير المتقدمة v11.01 — صفحة ${ctx.pageNumber}/${ctx.pagesCount}',
              textDirection: pw.TextDirection.rtl,
              style: arReg(9, color: PdfColors.grey700),
            ),
          ),
        ),

        // ── محتوى الصفحات ─────────────────────────────────────
        build: (ctx) => [
          // ════════ ترويسة المؤسسة ════════
          pw.Directionality(
            textDirection: pw.TextDirection.rtl,
            child: pw.Center(
              child: pw.Text(
                'الجمهورية الجزائرية الديمقراطية الشعبية',
                textDirection: pw.TextDirection.rtl,
                style: arBold(14).copyWith(
                    decoration: pw.TextDecoration.underline),
              ),
            ),
          ),
          pw.SizedBox(height: 10),

          // ════════ بيانات الموقع (يمين) + رقم المحضر (يسار) ════════
          pw.Directionality(
            textDirection: pw.TextDirection.rtl,
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                // يمين الصفحة (في RTL يعني start)
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    arText('ولاية: $wilaya',  style: arBold(11)),
                    arText('دائرة: $daira',   style: arBold(11)),
                    arText('بلدية: $baladia', style: arBold(11)),
                  ],
                ),
                // يسار الصفحة (في RTL يعني end)
                arText('رقم: $reportNumber', style: arBold(11)),
              ],
            ),
          ),

          pw.Divider(color: PdfColors.indigo900, thickness: 1),
          pw.SizedBox(height: 6),

          // ════════ عنوان التقرير ════════
          pw.Directionality(
            textDirection: pw.TextDirection.rtl,
            child: pw.Center(
              child: pw.Text(
                'تقرير إحصائي متقدم — السكن الريفي',
                textDirection: pw.TextDirection.rtl,
                style: arBold(18, color: PdfColors.indigo900),
              ),
            ),
          ),
          pw.SizedBox(height: 4),
          pw.Directionality(
            textDirection: pw.TextDirection.rtl,
            child: pw.Center(
              child: pw.Text(
                'بتاريخ: $dateAr',
                textDirection: pw.TextDirection.rtl,
                style: arReg(11, color: PdfColors.grey800),
              ),
            ),
          ),

          pw.SizedBox(height: 14),

          // ════════ مؤشرات KPI (صف 1) ════════
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceEvenly,
            children: [
              pw.Expanded(child: kpi('إجمالي الحصة', totalQuota, PdfColors.indigo700)),
              pw.SizedBox(width: 6),
              pw.Expanded(child: kpi('المحصاة',       totalDone,  PdfColors.blue700)),
              pw.SizedBox(width: 6),
              pw.Expanded(child: kpi('منتهية ومشغولة', totalOcc,  PdfColors.teal700)),
              pw.SizedBox(width: 6),
              pw.Expanded(child: kpi('بكل الشبكات',    totalAll3, PdfColors.green800)),
            ],
          ),
          pw.SizedBox(height: 8),

          // ════════ مؤشرات KPI (صف 2) ════════
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceEvenly,
            children: [
              pw.Expanded(child: kpi('كهرباء', totalElec,  PdfColors.amber800)),
              pw.SizedBox(width: 6),
              pw.Expanded(child: kpi('غاز',     totalGas,   PdfColors.orange800)),
              pw.SizedBox(width: 6),
              pw.Expanded(child: kpi('ماء',     totalWater, PdfColors.blue700)),
              pw.SizedBox(width: 6),
              pw.Expanded(child: kpi('تطهير',  totalSew,   PdfColors.brown600)),
            ],
          ),

          pw.SizedBox(height: 18),

          // ════════════════════════════════════════════════════
          // الجدول ① — الإحصائيات العامة (مطابق لشاشة الإحصائيات)
          // الترتيب: نفس ترتيب البرامج في stats_screen
          // ════════════════════════════════════════════════════
          pw.Directionality(
            textDirection: pw.TextDirection.rtl,
            child: pw.Container(
              padding: const pw.EdgeInsets.symmetric(vertical: 4),
              decoration: const pw.BoxDecoration(
                border: pw.Border(
                  right: pw.BorderSide(color: PdfColors.indigo900, width: 3),
                ),
              ),
              child: pw.Padding(
                padding: const pw.EdgeInsets.only(right: 8),
                child: pw.Text(
                  '① الإحصائيات العامة',
                  textDirection: pw.TextDirection.rtl,
                  style: arBold(13, color: PdfColors.indigo900),
                ),
              ),
            ),
          ),
          pw.SizedBox(height: 6),

          pw.Directionality(
            textDirection: pw.TextDirection.rtl,
            child: pw.TableHelper.fromTextArray(
              headerStyle: arBold(8, color: PdfColors.white),
              headerDecoration: const pw.BoxDecoration(color: PdfColors.indigo900),
              cellStyle: arReg(8),
              cellAlignment: pw.Alignment.center,
              cellAlignments: {0: pw.Alignment.centerRight},
              headerAlignment: pw.Alignment.center,
              headerDirection: pw.TextDirection.rtl,
              tableDirection: pw.TextDirection.rtl,
              border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.5),
              cellHeight: 22,
              headers: const [
                'البرنامج',
                'الحصة',
                'محصاة',
                'نسبة %',
                'في طور الانجاز',
                'على مستوى الاعمدة',
                'منتهية غير مشغولة',
                'منتهية ومشغولة',
                'كهرباء (كل الحالات)',
                'غاز (كل الحالات)',
                'مياه (كل الحالات)',
                'تطهير (كل الحالات)',
              ],
              data: [
                for (final r in stats)
                  [
                    r.program,
                    r.quota,
                    r.done,
                    r.quota > 0 ? '${(r.done / r.quota * 100).round()}%' : '0%',
                    r.inProgress,
                    r.pillars,
                    r.finishedNotOcc,
                    r.occupied,
                    r.elecAll,
                    r.gasAll,
                    r.waterAll,
                    r.sewAll,
                  ],
                // صف الإجمالي
                [
                  'الإجمالي',
                  totalQuota,
                  totalDone,
                  totalProgPct,
                  totalInProg,
                  totalPill,
                  totalFinNO,
                  totalOcc,
                  totalElecAll,
                  totalGasAll,
                  totalWatAll,
                  totalSewAll,
                ],
              ],
              rowDecoration: const pw.BoxDecoration(
                border: pw.Border(
                  bottom: pw.BorderSide(color: PdfColors.grey300, width: 0.3),
                ),
              ),
              oddRowDecoration: const pw.BoxDecoration(color: PdfColors.grey100),
            ),
          ),

          pw.SizedBox(height: 18),

          // ════════════════════════════════════════════════════
          // الجدول ② — تفصيل الربط بالشبكات (للمنتهية المشغولة)
          // نفس ترتيب البرامج تماماً
          // ════════════════════════════════════════════════════
          pw.Directionality(
            textDirection: pw.TextDirection.rtl,
            child: pw.Container(
              padding: const pw.EdgeInsets.symmetric(vertical: 4),
              decoration: const pw.BoxDecoration(
                border: pw.Border(
                  right: pw.BorderSide(color: PdfColors.teal700, width: 3),
                ),
              ),
              child: pw.Padding(
                padding: const pw.EdgeInsets.only(right: 8),
                child: pw.Text(
                  '② تحليل الربط بالشبكات (المنازل المنتهية والمشغولة)',
                  textDirection: pw.TextDirection.rtl,
                  style: arBold(13, color: PdfColors.teal800),
                ),
              ),
            ),
          ),
          pw.SizedBox(height: 6),

          pw.Directionality(
            textDirection: pw.TextDirection.rtl,
            child: pw.TableHelper.fromTextArray(
              headerStyle: arBold(9, color: PdfColors.white),
              headerDecoration: const pw.BoxDecoration(color: PdfColors.teal700),
              cellStyle: arReg(9),
              cellAlignment: pw.Alignment.center,
              cellAlignments: {0: pw.Alignment.centerRight},
              headerAlignment: pw.Alignment.center,
              headerDirection: pw.TextDirection.rtl,
              tableDirection: pw.TextDirection.rtl,
              border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.5),
              cellHeight: 22,
              headers: const [
                'البرنامج',
                'الحصة',
                'محصاة',
                'نسبة %',
                'منتهية ومشغولة',
                'كهرباء',
                'غاز',
                'مياه',
                'تطهير',
                'كل الشبكات',
              ],
              data: [
                for (final r in stats)
                  [
                    r.program,
                    r.quota,
                    r.done,
                    r.quota > 0 ? '${(r.done / r.quota * 100).round()}%' : '0%',
                    r.occupied,
                    r.elec,
                    r.gas,
                    r.water,
                    r.sew,
                    r.allNetworks,
                  ],
                // صف الإجمالي
                [
                  'الإجمالي',
                  totalQuota,
                  totalDone,
                  totalProgPct,
                  totalOcc,
                  totalElec,
                  totalGas,
                  totalWater,
                  totalSew,
                  totalAll3,
                ],
              ],
              oddRowDecoration: const pw.BoxDecoration(color: PdfColors.grey100),
            ),
          ),

          pw.SizedBox(height: 20),

          // ════════ ملاحظات ════════
          pw.Directionality(
            textDirection: pw.TextDirection.rtl,
            child: pw.Text(
              'ملاحظات:',
              textDirection: pw.TextDirection.rtl,
              style: arBold(12, color: PdfColors.indigo900),
            ),
          ),
          pw.SizedBox(height: 4),
          _bullet(arText, 'الجدول ① مطابق تماماً لجدول "الإحصائيات العامة" في شاشة الإحصائيات (نفس الأعمدة ونفس ترتيب البرامج).'),
          _bullet(arText, 'الجدول ② يخصّ تحليل الربط بالشبكات للسكنات المنتهية والمشغولة فقط.'),
          _bullet(arText, 'عمود "كل الشبكات" = مربوطة بالكهرباء والغاز والماء معاً.'),
          _bullet(arText, 'المصدر: قاعدة بيانات تطبيق إحصاء السكن الريفي v11.01.'),
        ],
      ),
    );

    // ── حفظ الملف ──────────────────────────────────────────────
    final outDir = await _outputDir();
    final ts = DateTime.now().millisecondsSinceEpoch;
    final fp = p.join(outDir.path,
        'تقرير_متقدم_${reportNumber.replaceAll('/', '-')}_$ts.pdf');
    await File(fp).writeAsBytes(await pdf.save());
    try { await OpenFile.open(fp); } catch (_) {}
    return fp;
  }

  // ── دالة مساعدة لعرض نقطة (Bullet) عربية ─────────────────────
  pw.Widget _bullet(
      pw.Widget Function(String, {pw.TextStyle? style, pw.TextAlign align}) arText,
      String text) {
    return pw.Directionality(
      textDirection: pw.TextDirection.rtl,
      child: pw.Padding(
        padding: const pw.EdgeInsets.only(right: 12, top: 2, bottom: 2),
        child: pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text('• ',
                textDirection: pw.TextDirection.rtl,
                style: pw.TextStyle(fontSize: 11, color: PdfColors.indigo900)),
            pw.Expanded(child: arText(text)),
          ],
        ),
      ),
    );
  }

  // ════════════════════════════════════════════════════════════════
  // مجلد الإخراج (يعمل على Android و Windows)
  // ════════════════════════════════════════════════════════════════
  Future<Directory> _outputDir() async {
    if (Platform.isAndroid) {
      final dl = Directory('/storage/emulated/0/Download/تقارير_متقدمة_v11');
      try {
        if (!await dl.exists()) await dl.create(recursive: true);
        if (await dl.exists()) return dl;
      } catch (_) {}
    }
    // Windows / macOS / Linux / iOS / fallback
    final docs = await getApplicationDocumentsDirectory();
    final outDir = Directory(p.join(docs.path, 'تقارير_متقدمة_v11'));
    if (!await outDir.exists()) await outDir.create(recursive: true);
    return outDir;
  }
}
