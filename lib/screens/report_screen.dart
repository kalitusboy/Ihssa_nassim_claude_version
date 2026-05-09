// شاشة محضر المعاينة — مطابقة لصورة الـ PV
// (ولاية المدية / دائرة تابلاط / بلدية الحوضان / 2026/001)
// + 3 أعضاء لجنة بأسمائهم + جدول 7 أعمدة (المشغولة + كهرباء/غاز/ماء)
import 'package:flutter/material.dart';
import 'package:open_file/open_file.dart';
import '../services/database_service.dart';
import '../services/report_service.dart';

class ReportScreen extends StatefulWidget {
  const ReportScreen({super.key});

  @override
  State<ReportScreen> createState() => _ReportScreenState();
}

class _ReportScreenState extends State<ReportScreen> {
  final _db = DatabaseService();
  final _rs = ReportService();
  final _form = GlobalKey<FormState>();

  // ── حقول الإدخال (افتراضيات مطابقة لصورة الـ PV) ──
  final _wilayaCtrl  = TextEditingController(text: 'المدية');
  final _dairaCtrl   = TextEditingController(text: 'تابلاط');
  final _baladiaCtrl = TextEditingController(text: 'الحوضان');
  final _placeCtrl   = TextEditingController(text: 'الحوضان');
  final _numCtrl     = TextEditingController(text: '2026/001');

  // أعضاء اللجنة (الأسماء الافتراضية مطابقة للصورة)
  final _m1NameCtrl = TextEditingController(text: 'حمزي إيمان');
  final _m1RoleCtrl = TextEditingController(text: 'رئيسة فرع السكن للدائرة');
  final _m2NameCtrl = TextEditingController(text: 'قاعدة سالم');
  final _m2RoleCtrl = TextEditingController(text: 'المكلف بالبناء الريفي على مستوى البلدية');
  final _m3NameCtrl = TextEditingController(text: 'حميتي نسيم');
  final _m3RoleCtrl = TextEditingController(text: 'المكلف بالبناء الريفي على مستوى البلدية');

  // قيم الإحصاء (تُملأ تلقائيًا عند اختيار البرنامج، وقابلة للتعديل اليدوي)
  final _quotaCtrl    = TextEditingController(text: '40');
  final _occupiedCtrl = TextEditingController(text: '5');
  final _elecCtrl     = TextEditingController(text: '5');
  final _gasCtrl      = TextEditingController(text: '5');
  final _waterCtrl    = TextEditingController(text: '4');

  String? _selectedProgram;
  List<String> _programs = [];
  DateTime _date = DateTime(2026, 4, 28); // الثلاثاء 28 أفريل 2026

  bool _generating = false;
  bool _exportingZip = false;
  String _msg = '';
  bool _msgOk = true;

  @override
  void initState() {
    super.initState();
    _loadPrograms();
  }

  @override
  void dispose() {
    for (final c in [
      _wilayaCtrl, _dairaCtrl, _baladiaCtrl, _placeCtrl, _numCtrl,
      _m1NameCtrl, _m1RoleCtrl, _m2NameCtrl, _m2RoleCtrl, _m3NameCtrl, _m3RoleCtrl,
      _quotaCtrl, _occupiedCtrl, _elecCtrl, _gasCtrl, _waterCtrl,
    ]) { c.dispose(); }
    super.dispose();
  }

  Future<void> _loadPrograms() async {
    final p = await _db.getPrograms();
    setState(() {
      _programs = p;
      if (p.isNotEmpty && _selectedProgram == null) {
        _selectedProgram = p.firstWhere(
          (x) => x.contains('2023') || x.contains('2000'),
          orElse: () => p.first,
        );
        _autoFill();
      }
    });
  }

  Future<void> _autoFill() async {
    if (_selectedProgram == null) return;
    final s = await _db.getReportStats(_selectedProgram!);
    final db = await _db.database;
    final occ = (await db.rawQuery('''
      SELECT
        SUM(CASE WHEN done=1 AND status='منتهية ومشغولة' AND electricity=1 THEN 1 ELSE 0 END) AS e,
        SUM(CASE WHEN done=1 AND status='منتهية ومشغولة' AND gas=1         THEN 1 ELSE 0 END) AS g,
        SUM(CASE WHEN done=1 AND status='منتهية ومشغولة' AND water=1       THEN 1 ELSE 0 END) AS w
      FROM beneficiaries WHERE program = ?
    ''', [_selectedProgram!])).first;
    setState(() {
      _quotaCtrl.text    = '${s['quota']             as int? ?? 0}';
      _occupiedCtrl.text = '${s['finished_occupied'] as int? ?? 0}';
      _elecCtrl.text     = '${occ['e']               as int? ?? 0}';
      _gasCtrl.text      = '${occ['g']               as int? ?? 0}';
      _waterCtrl.text    = '${occ['w']               as int? ?? 0}';
    });
  }

  Future<void> _pickDate() async {
    final d = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2024),
      lastDate: DateTime(2030),
      locale: const Locale('ar'),
    );
    if (d != null) setState(() => _date = d);
  }

  String get _dateAr {
    const days   = ['الاثنين','الثلاثاء','الأربعاء','الخميس','الجمعة','السبت','الأحد'];
    const months = ['جانفي','فيفري','مارس','أفريل','ماي','جوان',
                    'جويلية','أوت','سبتمبر','أكتوبر','نوفمبر','ديسمبر'];
    return '${days[_date.weekday - 1]} ${_date.day} ${months[_date.month - 1]} ${_date.year}';
  }

  int _toInt(TextEditingController c) =>
      int.tryParse(c.text.trim()) ?? 0;

  // ── توليد المحضر DOCX ─────────────────────────
  Future<void> _generate() async {
    if (!(_form.currentState?.validate() ?? false)) return;
    if (_selectedProgram == null) {
      _showMsg('اختر البرنامج أولاً', false); return;
    }
    setState(() => _generating = true);
    try {
      final data = ReportData(
        wilaya:       _wilayaCtrl.text.trim(),
        daira:        _dairaCtrl.text.trim(),
        baladia:      _baladiaCtrl.text.trim(),
        reportNumber: _numCtrl.text.trim(),
        date:         _dateAr,
        place:        _placeCtrl.text.trim(),
        member1Name:  _m1NameCtrl.text.trim(),
        member1Role:  _m1RoleCtrl.text.trim(),
        member2Name:  _m2NameCtrl.text.trim(),
        member2Role:  _m2RoleCtrl.text.trim(),
        member3Name:  _m3NameCtrl.text.trim(),
        member3Role:  _m3RoleCtrl.text.trim(),
        program:      _selectedProgram!,
        quota:        _toInt(_quotaCtrl),
        occupied:     _toInt(_occupiedCtrl),
        elecCount:    _toInt(_elecCtrl),
        gasCount:     _toInt(_gasCtrl),
        waterCount:   _toInt(_waterCtrl),
        fullyConnected: 0,
      );
      final path = await _rs.generateDocx(data);
      _showMsg('✅ تم الحفظ في Download/محاضر_الإحصاء', true);
      await OpenFile.open(path);
    } catch (e) {
      _showMsg('❌ خطأ: $e', false);
    } finally {
      setState(() => _generating = false);
    }
  }

  // ── تصدير صور المنتهية المشغولة فقط ───────────
  Future<void> _exportPhotos() async {
    if (_selectedProgram == null) {
      _showMsg('اختر البرنامج أولاً', false); return;
    }
    setState(() => _exportingZip = true);
    try {
      // استخدام منطق "المنتهية ومشغولة فقط"
      final db = await _db.database;
      final rows = await db.query('beneficiaries',
          columns: ['image_file_name', 'image_path', 'first_name', 'last_name'],
          where: "program=? AND done=1 AND status='منتهية ومشغولة' "
                 "AND image_file_name IS NOT NULL AND image_file_name != ''",
          whereArgs: [_selectedProgram!]);
      final images = rows.map((r) => {
        'name': (r['image_file_name'] ?? '').toString(),
        'path': (r['image_path']      ?? '').toString(),
      }).toList();
      if (images.isEmpty) {
        _showMsg('لا توجد صور منتهية مشغولة لهذا البرنامج', false);
        setState(() => _exportingZip = false);
        return;
      }
      final path = await _rs.exportPhotosZip(_selectedProgram!, images);
      _showMsg('✅ تم تصدير ${images.length} صورة (منتهية مشغولة)', true);
      await OpenFile.open(path);
    } catch (e) {
      _showMsg('❌ $e', false);
    } finally {
      setState(() => _exportingZip = false);
    }
  }

  void _showMsg(String msg, bool ok) =>
      setState(() { _msg = msg; _msgOk = ok; });

  // ── حقل إدخال ─────────────────────────────────
  Widget _field(TextEditingController ctrl, String label, IconData icon,
      {bool required = true, TextInputType? keyboard}) {
    return TextFormField(
      controller: ctrl,
      keyboardType: keyboard,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, size: 18),
        isDense: true,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      ),
      validator: required
          ? (v) => (v == null || v.trim().isEmpty) ? 'مطلوب' : null
          : null,
    );
  }

  Widget _section(String title, Color color) => Padding(
        padding: const EdgeInsets.only(top: 14, bottom: 8),
        child: Row(children: [
          Container(width: 4, height: 18, color: color),
          const SizedBox(width: 8),
          Text(title, style: TextStyle(fontWeight: FontWeight.bold,
              color: color, fontSize: 14)),
        ]),
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('📄 محضر المعاينة (مطابق للـ PV)'),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(16, 12, 16,
            MediaQuery.of(context).viewInsets.bottom + 80),
        child: Form(
          key: _form,
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [

            // ── الموقع
            _section('📍 بيانات الموقع', Colors.indigo),
            _field(_wilayaCtrl,  'الولاية',  Icons.location_city),
            const SizedBox(height: 8),
            _field(_dairaCtrl,   'الدائرة',  Icons.map_outlined),
            const SizedBox(height: 8),
            _field(_baladiaCtrl, 'البلدية',  Icons.location_on_outlined),

            // ── بيانات المحضر
            _section('📋 بيانات المحضر', Colors.teal),
            _field(_numCtrl, 'رقم المحضر', Icons.tag),
            const SizedBox(height: 8),
            InkWell(
              onTap: _pickDate,
              borderRadius: BorderRadius.circular(12),
              child: InputDecorator(
                decoration: const InputDecoration(
                  labelText: 'تاريخ المحضر',
                  prefixIcon: Icon(Icons.calendar_today, size: 18),
                  isDense: true,
                  contentPadding:
                      EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                ),
                child: Text(_dateAr,
                    style: const TextStyle(fontSize: 14)),
              ),
            ),
            const SizedBox(height: 8),
            _field(_placeCtrl, 'مكان التحرير', Icons.place_outlined),

            // ── أعضاء اللجنة الثلاثة
            _section('👥 أعضاء اللجنة', Colors.deepPurple),
            _field(_m1NameCtrl, 'العضو 1: الاسم واللقب', Icons.person),
            const SizedBox(height: 6),
            _field(_m1RoleCtrl, 'العضو 1: الصفة', Icons.work_outline),
            const SizedBox(height: 10),
            _field(_m2NameCtrl, 'العضو 2: الاسم واللقب', Icons.person),
            const SizedBox(height: 6),
            _field(_m2RoleCtrl, 'العضو 2: الصفة', Icons.work_outline),
            const SizedBox(height: 10),
            _field(_m3NameCtrl, 'العضو 3: الاسم واللقب', Icons.person),
            const SizedBox(height: 6),
            _field(_m3RoleCtrl, 'العضو 3: الصفة', Icons.work_outline),

            // ── البرنامج
            _section('🏗️ البرنامج', Colors.orange.shade800),
            DropdownButtonFormField<String>(
              value: _selectedProgram,
              decoration: const InputDecoration(
                labelText: 'اختر البرنامج',
                prefixIcon: Icon(Icons.folder_outlined, size: 18),
                isDense: true,
              ),
              items: _programs
                  .map((p) => DropdownMenuItem(value: p, child: Text(p)))
                  .toList(),
              onChanged: (v) {
                setState(() => _selectedProgram = v);
                _autoFill();
              },
              validator: (v) => v == null ? 'اختر برنامجاً' : null,
            ),

            // ── أرقام الجدول (قابلة للتعديل اليدوي)
            _section('🔢 أرقام جدول معلومات البرنامج', Colors.green.shade800),
            Row(children: [
              Expanded(child: _field(_quotaCtrl, 'الحصة', Icons.confirmation_number,
                  keyboard: TextInputType.number)),
              const SizedBox(width: 8),
              Expanded(child: _field(_occupiedCtrl, 'عدد المشغولة', Icons.home,
                  keyboard: TextInputType.number)),
            ]),
            const SizedBox(height: 8),
            Row(children: [
              Expanded(child: _field(_elecCtrl, 'كهرباء', Icons.bolt,
                  keyboard: TextInputType.number)),
              const SizedBox(width: 8),
              Expanded(child: _field(_gasCtrl, 'غاز', Icons.local_fire_department,
                  keyboard: TextInputType.number)),
              const SizedBox(width: 8),
              Expanded(child: _field(_waterCtrl, 'ماء', Icons.water_drop,
                  keyboard: TextInputType.number)),
            ]),

            const SizedBox(height: 18),

            // ── أزرار
            ElevatedButton.icon(
              onPressed: _generating ? null : _generate,
              icon: _generating
                  ? const SizedBox(width: 16, height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2,
                          color: Colors.white))
                  : const Icon(Icons.description),
              label: Text(_generating ? 'جاري التوليد...' : '📄 توليد المحضر Word'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1A237E),
                minimumSize: const Size.fromHeight(48),
              ),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: _exportingZip ? null : _exportPhotos,
              icon: _exportingZip
                  ? const SizedBox(width: 16, height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.image),
              label: Text(_exportingZip
                  ? 'جاري التصدير...'
                  : '🖼️ تصدير صور المنتهية المشغولة (ZIP)'),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(46),
              ),
            ),

            if (_msg.isNotEmpty) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: (_msgOk ? Colors.green : Colors.red).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: _msgOk ? Colors.green : Colors.red),
                ),
                child: Text(_msg,
                    style: TextStyle(
                        color: _msgOk ? Colors.green.shade800 : Colors.red.shade800,
                        fontWeight: FontWeight.bold)),
              ),
            ],
          ]),
        ),
      ),
    );
  }
}
