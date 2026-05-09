import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import '../models/beneficiary.dart';
import '../services/database_service.dart';

class SurveyScreen extends StatefulWidget {
  final Beneficiary beneficiary;
  const SurveyScreen({super.key, required this.beneficiary});

  @override
  State<SurveyScreen> createState() => _SurveyScreenState();
}

class _SurveyScreenState extends State<SurveyScreen> {
  final _db = DatabaseService();
  late Beneficiary _b;
  bool _e = false, _g = false, _w = false, _s = false, _saving = false;
  String _status = 'في طور الانجاز';
  File? _img;

  final _statuses = [
    'في طور الانجاز',
    'على مستوى الاعمدة',
    'منتهية غير مشغولة',
    'منتهية ومشغولة',
  ];

  @override
  void initState() {
    super.initState();
    _b = widget.beneficiary;
    _e = _b.electricity == 1;
    _g = _b.gas == 1;
    _w = _b.water == 1;
    _s = _b.sewage == 1;
    _status = _b.status;
  }

  // ── اختيار صورة من Windows (file_picker) ─────
  Future<void> _pickImage() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      allowMultiple: false,
      dialogTitle: 'اختر صورة المستفيد',
    );
    if (result != null && result.files.single.path != null) {
      setState(() => _img = File(result.files.single.path!));
    }
  }

  Future<File?> _moveToPermanentImageDir(File sourceFile, String imageFileName) async {
    try {
      final documentsDirectory = await getApplicationDocumentsDirectory();
      final imgDir = Directory(p.join(documentsDirectory.path, 'ihsaa2026', 'images'));
      if (!await imgDir.exists()) await imgDir.create(recursive: true);
      final permPath = p.join(imgDir.path, imageFileName);
      await sourceFile.copy(permPath);
      return File(permPath);
    } catch (e) {
      debugPrint('فشل نسخ الصورة: $e');
      return null;
    }
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      String? finalImagePath = _b.imagePath;
      String? finalImageFileName = _b.imageFileName;

      if (_img != null) {
        final genName = _b.generateImageFileName();
        final moved = await _moveToPermanentImageDir(_img!, genName);
        if (moved != null) {
          finalImagePath = moved.path;
          finalImageFileName = genName;
        }
      }

      final updated = _b.copyWith(
        done: 1,
        electricity: _e ? 1 : 0,
        gas: _g ? 1 : 0,
        water: _w ? 1 : 0,
        sewage: _s ? 1 : 0,
        status: _status,
        imagePath: finalImagePath,
        imageFileName: finalImageFileName,
        updatedAt: DateTime.now().add(const Duration(minutes: 1)),
      );
      await _db.updateBeneficiary(updated);
      if (mounted) {
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('✅ تم الحفظ'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('❌ فشل: $e'), backgroundColor: Colors.red),
      );
    }
    setState(() => _saving = false);
  }

  Future<void> _delete() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('حذف المستفيد'),
        content: Text('هل أنت متأكد من حذف "${_b.displayName}"؟ لا يمكن التراجع.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('إلغاء')),
          TextButton(
            onPressed: () => Navigator.pop(c, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('حذف'),
          ),
        ],
      ),
    );
    if (confirm == true) {
      setState(() => _saving = true);
      try {
        await _db.deleteBeneficiary(_b.id!);
        if (mounted) {
          Navigator.pop(context, true);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('🗑️ تم الحذف'), backgroundColor: Colors.red),
          );
        }
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('❌ فشل الحذف: $e'), backgroundColor: Colors.red),
        );
      }
      setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_saving) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      appBar: AppBar(
        title: Text('📝 ${_b.displayName}'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          TextButton.icon(
            onPressed: _delete,
            icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
            label: const Text('حذف', style: TextStyle(color: Colors.redAccent)),
          ),
          const SizedBox(width: 8),
          FilledButton.icon(
            onPressed: _save,
            icon: const Icon(Icons.save, size: 16),
            label: const Text('💾 حفظ وإتمام'),
            style: FilledButton.styleFrom(
              backgroundColor: Colors.green.shade700,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
          ),
          const SizedBox(width: 12),
        ],
      ),
      body: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── العمود الأيسر: بيانات المستفيد + الشبكات + الحالة ──
          Expanded(
            flex: 3,
            child: Scrollbar(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // بيانات المستفيد
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(children: [
                              Container(
                                width: 50, height: 50,
                                decoration: BoxDecoration(
                                  color: const Color(0xFF0D47A1).withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Icon(Icons.person_outline,
                                    color: Color(0xFF0D47A1), size: 28),
                              ),
                              const SizedBox(width: 14),
                              Expanded(child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(_b.displayName,
                                      style: const TextStyle(
                                          fontSize: 20, fontWeight: FontWeight.bold,
                                          color: Color(0xFF0D47A1))),
                                  if (_b.birthInfo.isNotEmpty)
                                    Text(_b.birthInfo,
                                        style: const TextStyle(color: Color(0xFF475569))),
                                ],
                              )),
                            ]),
                            const SizedBox(height: 16),
                            const Divider(),
                            const SizedBox(height: 12),
                            _InfoRow(Icons.folder_outlined, 'البرنامج', _b.program ?? 'عام', Colors.blue),
                            const SizedBox(height: 8),
                            _InfoRow(Icons.home_outlined, 'العنوان', _b.address ?? 'غير محدد', Colors.teal),
                            if (_b.birthDate != null && _b.birthDate!.isNotEmpty) ...[ 
                              const SizedBox(height: 8),
                              _InfoRow(Icons.cake_outlined, 'تاريخ الميلاد', _b.birthDate!, Colors.orange),
                            ],
                            if (_b.birthPlace != null && _b.birthPlace!.isNotEmpty) ...[ 
                              const SizedBox(height: 8),
                              _InfoRow(Icons.location_on_outlined, 'مكان الميلاد', _b.birthPlace!, Colors.orange),
                            ],
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),

                    // الربط بالشبكات
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('🔗 الربط بالشبكات',
                                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                            const SizedBox(height: 16),
                            Row(children: [
                              _NetworkChk(Icons.bolt, 'كهرباء', Colors.amber, _e,
                                  (v) => setState(() => _e = v!)),
                              _NetworkChk(Icons.local_fire_department, 'غاز', Colors.orange, _g,
                                  (v) => setState(() => _g = v!)),
                              _NetworkChk(Icons.water_drop, 'مياه', Colors.blue, _w,
                                  (v) => setState(() => _w = v!)),
                              _NetworkChk(Icons.cleaning_services, 'تطهير', Colors.green, _s,
                                  (v) => setState(() => _s = v!)),
                            ]),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),

                    // الحالة الفيزيائية
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('🏗️ الحالة الفيزيائية',
                                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                            const SizedBox(height: 16),
                            ..._statuses.map((s) {
                              final colors = {
                                'في طور الانجاز':    Colors.orange,
                                'على مستوى الاعمدة': Colors.blue,
                                'منتهية غير مشغولة': Colors.green.shade700,
                                'منتهية ومشغولة':    const Color(0xFF00897B),
                              };
                              final c = colors[s] ?? Colors.grey;
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(10),
                                  onTap: () => setState(() => _status = s),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(10),
                                      color: _status == s
                                          ? c.withValues(alpha: 0.12)
                                          : Colors.grey.shade50,
                                      border: Border.all(
                                        color: _status == s ? c : Colors.grey.shade200,
                                        width: _status == s ? 2 : 1,
                                      ),
                                    ),
                                    child: Row(children: [
                                      Icon(Icons.radio_button_checked,
                                          color: _status == s ? c : Colors.grey.shade300,
                                          size: 18),
                                      const SizedBox(width: 10),
                                      Text(s, style: TextStyle(
                                          color: _status == s ? c : Colors.grey.shade700,
                                          fontWeight: _status == s ? FontWeight.bold : FontWeight.normal)),
                                    ]),
                                  ),
                                ),
                              );
                            }),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          const VerticalDivider(width: 1),

          // ── العمود الأيمن: الصورة ──────────────
          Expanded(
            flex: 2,
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const Text('📷 صورة المستفيد',
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 16),
                          ElevatedButton.icon(
                            onPressed: _pickImage,
                            icon: const Icon(Icons.folder_open, size: 18),
                            label: const Text('اختيار صورة من الكمبيوتر'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF475569),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                          ),
                          const SizedBox(height: 16),
                          // عرض الصورة
                          Container(
                            constraints: const BoxConstraints(minHeight: 200, maxHeight: 400),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              color: Colors.grey.shade100,
                              border: Border.all(color: Colors.grey.shade200),
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: _img != null
                                  ? Image.file(_img!, fit: BoxFit.contain)
                                  : (_b.imagePath != null && _b.imagePath!.isNotEmpty &&
                                      File(_b.imagePath!).existsSync())
                                      ? Image.file(File(_b.imagePath!), fit: BoxFit.contain)
                                      : Column(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            Icon(Icons.image_outlined,
                                                size: 60, color: Colors.grey.shade300),
                                            const SizedBox(height: 8),
                                            Text('لا توجد صورة',
                                                style: TextStyle(color: Colors.grey.shade400)),
                                          ],
                                        ),
                            ),
                          ),
                          if (_img != null || (_b.imagePath != null && _b.imagePath!.isNotEmpty)) ...[ 
                            const SizedBox(height: 10),
                            Text(
                              _img != null
                                  ? 'صورة جديدة: ${p.basename(_img!.path)}'
                                  : 'صورة محفوظة: ${_b.imageFileName ?? ''}',
                              style: TextStyle(color: Colors.grey.shade500, fontSize: 11),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }


}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;
  const _InfoRow(this.icon, this.label, this.value, this.color);

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Icon(icon, size: 16, color: color),
      const SizedBox(width: 8),
      Text('$label: ', style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
      Expanded(child: Text(value,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
          overflow: TextOverflow.ellipsis)),
    ]);
  }
}

class _NetworkChk extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final bool value;
  final Function(bool?) onChanged;
  const _NetworkChk(this.icon, this.label, this.color, this.value, this.onChanged);

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: () => onChanged(!value),
        child: Container(
          margin: const EdgeInsets.all(4),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            color: value ? color.withValues(alpha: 0.12) : Colors.grey.shade50,
            border: Border.all(
              color: value ? color : Colors.grey.shade200,
              width: value ? 2 : 1,
            ),
          ),
          child: Column(children: [
            Icon(icon, color: value ? color : Colors.grey.shade300, size: 22),
            const SizedBox(height: 4),
            Text(label, style: TextStyle(
                fontSize: 12,
                color: value ? color : Colors.grey.shade500,
                fontWeight: value ? FontWeight.bold : FontWeight.normal)),
            if (value) Icon(Icons.check_circle, color: color, size: 14),
          ]),
        ),
      ),
    );
  }
}
