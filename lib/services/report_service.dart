import 'dart:convert';
import 'dart:io';
import 'package:archive/archive.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
// v11.01

/// بيانات المحضر — مطابقة لصورة الـ PV المرسلة
/// ولاية المدية / دائرة تابلاط / بلدية الحوضان / رقم 2026/001
class ReportData {
  // ── بيانات الترويسة ────────────────────────────
  final String wilaya;          // ولاية المدية
  final String daira;           // دائرة تابلاط
  final String baladia;         // بلدية الحوضان
  final String reportNumber;    // 2026/001
  final String date;            // الثلاثاء 28 أفريل 2026
  final String place;           // مكان التحرير

  // ── أعضاء اللجنة (3 أعضاء حسب صورة الـ PV) ──
  final String member1Name;     // حمزي إيمان – رئيس فرع السكن للدائرة
  final String member1Role;
  final String member2Name;     // قادة سالم – المكلف بالبناء الريفي/الدائرة
  final String member2Role;
  final String member3Name;     // حميتي نسيم – المكلف بالبناء الريفي/البلدية
  final String member3Role;

  // ── معلومات البرنامج ───────────────────────────
  final String program;         // برنامج 2023/2000
  final int    quota;           // الحصة (40)
  final int    occupied;        // عدد السكنات المشغولة (المنتهية المشغولة)
  final int    elecCount;       // المربوطة بالكهرباء
  final int    gasCount;        // المربوطة بالغاز
  final int    waterCount;      // المربوطة بالماء
  final int    fullyConnected;  // المربوطة بكل الشبكات (إضافي للتقرير المتقدم)

  // ── تفاصيل إضافية للتقرير الموسّع ──────────────
  final int    inProgress;
  final int    pillars;
  final int    finishedNotOccupied;
  final int    sewCount;

  const ReportData({
    required this.wilaya,
    required this.daira,
    required this.baladia,
    required this.reportNumber,
    required this.date,
    required this.place,
    required this.member1Name,
    required this.member1Role,
    required this.member2Name,
    required this.member2Role,
    required this.member3Name,
    required this.member3Role,
    required this.program,
    required this.quota,
    required this.occupied,
    required this.elecCount,
    required this.gasCount,
    required this.waterCount,
    required this.fullyConnected,
    this.inProgress          = 0,
    this.pillars             = 0,
    this.finishedNotOccupied = 0,
    this.sewCount            = 0,
  });
}

/// خدمة إنشاء المحاضر بصيغة Word (.docx) — مطابقة لصورة الـ PV
class ReportService {
  static final ReportService _i = ReportService._();
  factory ReportService() => _i;
  ReportService._();

  // ──────────────────────────────────────────────
  // إنشاء ملف DOCX وحفظه
  // ──────────────────────────────────────────────
  Future<String> generateDocx(ReportData d) async {
    final archive = Archive();

    void addXml(String path, String content) {
      final bytes = _utf8(content);
      archive.addFile(ArchiveFile(path, bytes.length, bytes));
    }

    addXml('[Content_Types].xml', _contentTypes());
    addXml('_rels/.rels',          _rootRels());
    addXml('word/document.xml',    _buildDocument(d));
    addXml('word/_rels/document.xml.rels', _documentRels());
    addXml('word/styles.xml',      _styles());
    addXml('word/settings.xml',    _settings());

    final bytes = ZipEncoder().encode(archive)!;
    final dl = await _outputDir();

    final safeProg = d.program
        .replaceAll(RegExp(r'[\\/:*?"<>|]'), '_')
        .replaceAll(' ', '_');
    final fname = 'محضر_${safeProg}_${d.reportNumber.replaceAll('/', '-')}.docx';
    final file = File(p.join(dl.path, fname));
    await file.writeAsBytes(bytes);
    return file.path;
  }

  // ★ v11.01: مجلد الإخراج (داعم لأندرويد وويندوز)
  Future<Directory> _outputDir() async {
    if (Platform.isAndroid) {
      final dl = Directory('/storage/emulated/0/Download/محاضر_الإحصاء');
      if (!await dl.exists()) {
        try { await dl.create(recursive: true); } catch (_) {}
      }
      if (await dl.exists()) return dl;
    }
    final docs = await getApplicationDocumentsDirectory();
    final out = Directory(p.join(docs.path, 'محاضر_الإحصاء'));
    if (!await out.exists()) await out.create(recursive: true);
    return out;
  }

  // ──────────────────────────────────────────────
  // تصدير صور برنامج كـ ZIP
  // ──────────────────────────────────────────────
  Future<String> exportPhotosZip(
      String program, List<Map<String, String>> images) async {
    final archive = Archive();
    int count = 0;

    for (final img in images) {
      final path = img['path'] ?? '';
      final name = img['name'] ?? '';
      if (path.isEmpty || name.isEmpty) continue;
      final file = File(path);
      if (!await file.exists()) continue;
      final bytes = await file.readAsBytes();
      archive.addFile(ArchiveFile(name, bytes.length, bytes));
      count++;
    }

    if (count == 0) throw Exception('لا توجد صور للتصدير');

    final zipBytes = ZipEncoder().encode(archive)!;
    final dl = await _outputDir();

    final safeProg = program
        .replaceAll(RegExp(r'[\\/:*?"<>|]'), '_')
        .replaceAll(' ', '_');
    final fname = 'صور_المنتهية_المشغولة_${safeProg}_$count.zip';
    final file = File(p.join(dl.path, fname));
    await file.writeAsBytes(zipBytes);
    return file.path;
  }

  // ──────────────────────────────────────────────
  // بناء document.xml — النسخة المعدلة حسب الطلب
  // ──────────────────────────────────────────────
  String _buildDocument(ReportData d) {
    return '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<w:document xmlns:wpc="http://schemas.microsoft.com/office/word/2010/wordprocessingCanvas"
  xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"
  xmlns:w14="http://schemas.microsoft.com/office/word/2010/wordml"
  xmlns:wp="http://schemas.openxmlformats.org/drawingml/2006/wordprocessingDrawing"
  xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships">
<w:body>

<!-- ═══════════════ الترويسة العلوية ═══════════════ -->
<w:p>
  <w:pPr><w:jc w:val="center"/><w:spacing w:before="0" w:after="200"/></w:pPr>
  <w:r><w:rPr><w:b/><w:sz w:val="36"/><w:rtl/><w:u w:val="single"/></w:rPr>
    <w:t>الجمهورية الجزائرية الديمقراطية الشعبية</w:t>
  </w:r>
</w:p>

<!-- ولاية / دائرة / بلدية / رقم — على اليمين -->
<w:p><w:pPr><w:jc w:val="right"/></w:pPr>
  <w:r><w:rPr><w:b/><w:sz w:val="28"/><w:rtl/></w:rPr>
    <w:t xml:space="preserve">ولاية: ${_x(d.wilaya)}</w:t></w:r></w:p>
<w:p><w:pPr><w:jc w:val="right"/></w:pPr>
  <w:r><w:rPr><w:b/><w:sz w:val="28"/><w:rtl/></w:rPr>
    <w:t xml:space="preserve">دائرة: ${_x(d.daira)}</w:t></w:r></w:p>
<w:p><w:pPr><w:jc w:val="right"/></w:pPr>
  <w:r><w:rPr><w:b/><w:sz w:val="28"/><w:rtl/></w:rPr>
    <w:t xml:space="preserve">بلدية: ${_x(d.baladia)}</w:t></w:r></w:p>
<w:p><w:pPr><w:jc w:val="right"/><w:spacing w:after="200"/></w:pPr>
  <w:r><w:rPr><w:b/><w:sz w:val="22"/><w:rtl/><w:u w:val="single"/></w:rPr>
    <w:t xml:space="preserve">رقم: ${_x(d.reportNumber)}</w:t></w:r></w:p>

<!-- ═══════════════ العنوان ═══════════════ -->
<w:p>
  <w:pPr><w:jc w:val="center"/><w:spacing w:before="200" w:after="200"/></w:pPr>
  <w:r><w:rPr><w:b/><w:sz w:val="28"/><w:rtl/></w:rPr>
    <w:t>محضر معاينة ميدانية و إحصاء للسكن الريفي</w:t>
  </w:r>
</w:p>

<!-- ═══════════════ ديباجة اللجنة ═══════════════ -->
<w:p>
  <w:pPr><w:jc w:val="right"/><w:spacing w:before="200" w:after="120"/></w:pPr>
  <w:r><w:rPr><w:sz w:val="28"/><w:rtl/></w:rPr>
    <w:t xml:space="preserve">في يوم ${_x(d.date)} ، قامت اللجنة المكلفة بإحصاء و متابعة السكن الريفي ، و المشكلة من :</w:t>
  </w:r>
</w:p>

<w:p><w:pPr><w:jc w:val="right"/><w:ind w:right="720"/></w:pPr>
  <w:r><w:rPr><w:sz w:val="28"/><w:rtl/></w:rPr>
    <w:t xml:space="preserve">- السيد(ة) : ${_x(d.member1Name)} ${_x(d.member1Role)}</w:t></w:r></w:p>
<w:p><w:pPr><w:jc w:val="right"/><w:ind w:right="720"/></w:pPr>
  <w:r><w:rPr><w:sz w:val="28"/><w:rtl/></w:rPr>
    <w:t xml:space="preserve">- السيد(ة) : ${_x(d.member2Name)} ${_x(d.member2Role)}</w:t></w:r></w:p>
<w:p><w:pPr><w:jc w:val="right"/><w:ind w:right="720"/><w:spacing w:after="200"/></w:pPr>
  <w:r><w:rPr><w:sz w:val="28"/><w:rtl/></w:rPr>
    <w:t xml:space="preserve">- السيد(ة) : ${_x(d.member3Name)} ${_x(d.member3Role)}</w:t></w:r></w:p>

<w:p>
  <w:pPr><w:jc w:val="right"/><w:spacing w:before="120" w:after="120"/></w:pPr>
  <w:r><w:rPr><w:sz w:val="28"/><w:rtl/></w:rPr>
    <w:t xml:space="preserve">بتنفيذ معاينة ميدانية و إحصاء شامل للسكنات الريفية ضمن برنامج : </w:t>
  </w:r>
  <w:r><w:rPr><w:b/><w:sz w:val="22"/><w:rtl/></w:rPr>
    <w:t>${_x(d.program)}</w:t></w:r>
</w:p>

<w:p>
  <w:pPr><w:jc w:val="right"/><w:spacing w:before="0" w:after="240"/></w:pPr>
  <w:r><w:rPr><w:sz w:val="28"/><w:rtl/></w:rPr>
    <w:t>بعد إتمام عملية المعاينة و الجرد الدقيق ، خلصت اللجنة إلى ما يلي :</w:t>
  </w:r>
</w:p>

<!-- ═══════════════ أولا : معلومات البرنامج ═══════════════ -->
<w:p>
  <w:pPr><w:jc w:val="right"/><w:spacing w:before="120" w:after="120"/></w:pPr>
  <w:r><w:rPr><w:b/><w:sz w:val="28"/><w:rtl/><w:u w:val="single"/></w:rPr>
    <w:t>أولا : معلومات البرنامج</w:t>
  </w:r>
</w:p>

<!-- جدول 7 أعمدة -->
<w:tbl>
  <w:tblPr>
    <w:tblW w:w="9500" w:type="dxa"/>
    <w:jc w:val="center"/>
    <w:bidiVisual/>
    <w:tblBorders>
      <w:top    w:val="single" w:sz="6" w:color="000000"/>
      <w:left   w:val="single" w:sz="6" w:color="000000"/>
      <w:bottom w:val="single" w:sz="6" w:color="000000"/>
      <w:right  w:val="single" w:sz="6" w:color="000000"/>
      <w:insideH w:val="single" w:sz="6" w:color="000000"/>
      <w:insideV w:val="single" w:sz="6" w:color="000000"/>
    </w:tblBorders>
  </w:tblPr>
  <w:tblGrid>
    <w:gridCol w:w="1300"/><w:gridCol w:w="1700"/><w:gridCol w:w="900"/>
    <w:gridCol w:w="1400"/><w:gridCol w:w="1400"/><w:gridCol w:w="1400"/>
    <w:gridCol w:w="1400"/>
  </w:tblGrid>
  <w:tr>
    ${_th('البلدية', 1300)}
    ${_th('تعيين البرنامج', 1700)}
    ${_th('الحصة', 900)}
    ${_th('عدد السكنات المشغولة', 1400)}
    ${_th('عدد السكنات المربوطة بالكهرباء', 1400)}
    ${_th('عدد السكنات المربوطة بالغاز', 1400)}
    ${_th('عدد السكنات المربوطة بالماء', 1400)}
  </w:tr>
  <w:tr>
    ${_td(_x(d.baladia), 1300, bold: true)}
    ${_td(_x(d.program), 1700, bold: true)}
    ${_td(d.quota.toString(), 900)}
    ${_td(d.occupied.toString(), 1400)}
    ${_td(d.elecCount.toString(), 1400)}
    ${_td(d.gasCount.toString(), 1400)}
    ${_td(d.waterCount.toString(), 1400)}
  </w:tr>
</w:tbl>

<!-- ═══════════════ ثانيا : المرفقات ═══════════════ -->
<w:p>
  <w:pPr><w:jc w:val="right"/><w:spacing w:before="320" w:after="120"/></w:pPr>
  <w:r><w:rPr><w:b/><w:sz w:val="28"/><w:rtl/><w:u w:val="single"/></w:rPr>
    <w:t>ثانيا : المرفقات</w:t>
  </w:r>
</w:p>

<!-- التعديل: (cd) صغيرة -->
<w:p>
  <w:pPr><w:jc w:val="right"/><w:spacing w:before="0" w:after="80"/></w:pPr>
  <w:r><w:rPr><w:sz w:val="22"/><w:rtl/></w:rPr>
    <w:t xml:space="preserve"> :قرص مضغوط يتضمن  </w:t>
  </w:r>
</w:p>

<w:p>
  <w:pPr><w:jc w:val="right"/><w:ind w:right="720"/><w:spacing w:before="0" w:after="60"/></w:pPr>
  <w:r><w:rPr><w:sz w:val="22"/><w:rtl/></w:rPr>
    <w:t>• جدول بياني تفصيلي يحتوي على القائمة الاسمية للمستفيدين ، الحالة الفيزيائية لكل سكن ، ووضعية الربط بالشبكات .</w:t>
  </w:r>
</w:p>
<w:p>
  <w:pPr><w:jc w:val="right"/><w:ind w:right="720"/><w:spacing w:before="0" w:after="200"/></w:pPr>
  <w:r><w:rPr><w:sz w:val="22"/><w:rtl/></w:rPr>
    <w:t>• صور توثق وضعية البنايات .</w:t>
  </w:r>
</w:p>

<!-- ═══════════════ خاتمة ═══════════════ -->
<w:p>
  <w:pPr><w:jc w:val="center"/><w:spacing w:before="240" w:after="120"/></w:pPr>
  <w:r><w:rPr><w:sz w:val="28"/><w:rtl/></w:rPr>
    <w:t>اقفل المحضر في نفس اليوم و الشهر و السنة المذكورين أعلاه .</w:t>
  </w:r>
</w:p>

<!-- خط مستقيم قصير -->
<w:p>
  <w:pPr><w:jc w:val="center"/><w:spacing w:before="0" w:after="200"/></w:pPr>
  <w:r><w:rPr><w:sz w:val="28"/><w:rtl/></w:rPr>
    <w:t>______</w:t>
  </w:r>
</w:p>

<!-- جدول التوقيعات -->
<w:tbl>
  <w:tblPr>
    <w:tblW w:w="9500" w:type="dxa"/>
    <w:jc w:val="center"/>
    <w:bidiVisual/>
    <w:tblBorders>
      <w:top w:val="none"/><w:left w:val="none"/>
      <w:bottom w:val="none"/><w:right w:val="none"/>
      <w:insideH w:val="none"/><w:insideV w:val="none"/>
    </w:tblBorders>
  </w:tblPr>
  <w:tblGrid>
    <w:gridCol w:w="3166"/><w:gridCol w:w="3167"/><w:gridCol w:w="3167"/>
  </w:tblGrid>
  <w:tr>
    ${_thNB('رئيس(ة) فرع السكن')}
    ${_thNB('المكلف(ة) بالبناء الريفي للدائرة')}
    ${_thNB('المكلف(ة) بالبناء الريفي للبلدية')}
  </w:tr>
  <w:tr><w:trPr><w:trHeight w:val="900"/></w:trPr>
    ${_tdNB('………………………………')}
    ${_tdNB('………………………………')}
    ${_tdNB('………………………………')}
  </w:tr>
</w:tbl>

<w:sectPr>
  <w:pgSz w:w="11906" w:h="16838"/>
  <w:pgMar w:top="1134" w:right="1134" w:bottom="1134" w:left="1134"/>
  <w:bidi/>
</w:sectPr>
</w:body>
</w:document>''';
  }

  // ── دوال مساعدة لبناء خلايا الجدول ─────────────
  String _th(String text, int w) => '''
<w:tc>
  <w:tcPr><w:tcW w:w="$w" w:type="dxa"/>
    <w:shd w:val="clear" w:color="auto" w:fill="DDDDDD"/>
    <w:vAlign w:val="center"/>
  </w:tcPr>
  <w:p><w:pPr><w:jc w:val="center"/></w:pPr>
    <w:r><w:rPr><w:b/><w:sz w:val="20"/><w:rtl/></w:rPr><w:t xml:space="preserve">${_x(text)}</w:t></w:r>
  </w:p>
</w:tc>''';

  String _td(String text, int w, {bool bold = false}) => '''
<w:tc>
  <w:tcPr><w:tcW w:w="$w" w:type="dxa"/>
    <w:vAlign w:val="center"/>
  </w:tcPr>
  <w:p><w:pPr><w:jc w:val="center"/></w:pPr>
    <w:r><w:rPr>${bold ? '<w:b/>' : ''}<w:sz w:val="22"/><w:rtl/></w:rPr><w:t xml:space="preserve">$text</w:t></w:r>
  </w:p>
</w:tc>''';

  String _thNB(String text) => '''
<w:tc>
  <w:tcPr><w:tcW w:w="3167" w:type="dxa"/></w:tcPr>
  <w:p><w:pPr><w:jc w:val="center"/></w:pPr>
    <w:r><w:rPr><w:b/><w:sz w:val="20"/><w:rtl/></w:rPr><w:t xml:space="preserve">${_x(text)}</w:t></w:r>
  </w:p>
</w:tc>''';

  String _tdNB(String text) => '''
<w:tc>
  <w:tcPr><w:tcW w:w="3167" w:type="dxa"/></w:tcPr>
  <w:p><w:pPr><w:jc w:val="center"/></w:pPr>
    <w:r><w:rPr><w:sz w:val="20"/><w:rtl/></w:rPr><w:t xml:space="preserve">$text</w:t></w:r>
  </w:p>
</w:tc>''';

  // ── XML escaping & utf8 ─────────────────────────
  String _x(String s) =>
      s.replaceAll('&', '&amp;').replaceAll('<', '&lt;').replaceAll('>', '&gt;');
  List<int> _utf8(String s) => utf8.encode(s);

  // ── ملفات DOCX الداعمة ──────────────────────────
  String _contentTypes() => '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">
  <Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>
  <Default Extension="xml" ContentType="application/xml"/>
  <Override PartName="/word/document.xml"
    ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml"/>
  <Override PartName="/word/styles.xml"
    ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.styles+xml"/>
  <Override PartName="/word/settings.xml"
    ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.settings+xml"/>
</Types>''';

  String _rootRels() => '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
  <Relationship Id="rId1"
    Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument"
    Target="word/document.xml"/>
</Relationships>''';

  String _documentRels() => '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
  <Relationship Id="rId1"
    Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/styles"
    Target="styles.xml"/>
  <Relationship Id="rId2"
    Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/settings"
    Target="settings.xml"/>
</Relationships>''';

  String _styles() => '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<w:styles xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">
  <w:docDefaults>
    <w:rPrDefault><w:rPr>
      <w:rFonts w:ascii="Arabic Typesetting" w:hAnsi="Arabic Typesetting" w:cs="Arabic Typesetting"/>
      <w:sz w:val="22"/><w:szCs w:val="22"/><w:lang w:bidi="ar-DZ"/>
    </w:rPr></w:rPrDefault>
    <w:pPrDefault><w:pPr>
      <w:bidi/><w:spacing w:after="120" w:line="276" w:lineRule="auto"/>
    </w:pPr></w:pPrDefault>
  </w:docDefaults>
</w:styles>''';

  String _settings() => '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<w:settings xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">
  <w:zoom w:percent="100"/>
  <w:defaultTabStop w:val="720"/>
  <w:characterSpacingControl w:val="doNotCompress"/>
  <w:themeFontLang w:val="en-US" w:bidi="ar-DZ"/>
</w:settings>''';
}
