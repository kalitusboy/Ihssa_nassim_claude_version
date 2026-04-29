import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:path/path.dart' as p;
import '../models/beneficiary.dart';
import '../services/database_service.dart';
import '../services/platform_service.dart';
import '../services/sync_service.dart';
import '../widgets/web_image.dart';

class SurveyScreen extends StatefulWidget {
  final Beneficiary beneficiary;
  const SurveyScreen({super.key, required this.beneficiary});

  @override
  State<SurveyScreen> createState() => _SurveyScreenState();
}

class _SurveyScreenState extends State<SurveyScreen> {
  final _dbService = DatabaseService();
  final _platform  = PlatformService();
  final _picker    = ImagePicker();

  late Beneficiary _b;
  bool   _e = false, _g = false, _w = false, _s = false;
  bool   _saving = false;
  String _status = 'في طور الانجاز';
  File?  _img;
  XFile? _webImg;

  final _statuses = [
    'في طور الانجاز',
    'على مستوى الاعمدة',
    'منتهية غير مشغولة',
    'منتهية ومشغولة',
  ];

  @override
  void initState() {
    super.initState();
    _b      = widget.beneficiary;
    _e      = _b.electricity == 1;
    _g      = _b.gas == 1;
    _w      = _b.water == 1;
    _s      = _b.sewage == 1;
    _status = _b.status;
  }

  // ── ضغط الصورة ─────────────────────────────
  Future<File?> _compressImage(File file) async {
    try {
      final dir        = await getTemporaryDirectory();
      final targetPath = '${dir.path}/${DateTime.now().millisecondsSinceEpoch}.jpg';
      final result     = await FlutterImageCompress.compressAndGetFile(
        file.absolute.path, targetPath,
        quality: 70, minWidth: 1024, minHeight: 1024,
      );
      return result != null ? File(result.path) : file;
    } catch (_) {
      return file;
    }
  }

  // ── نقل الصورة للمجلد الدائم ────────────────
  Future<File?> _moveToPermanentImageDir(File src, String name) async {
    final dir  = await SyncService().getImagesDir();
    final dest = p.join(dir.path, name);
    try {
      await src.copy(dest);
      return File(dest);
    } catch (_) {
      return null;
    }
  }

  // ── اختيار صورة ────────────────────────────
  Future<void> _pickImage(ImageSource src) async {
    final img = await _picker.pickImage(source: src, imageQuality: 70);
    if (img == null) return;
    if (kIsWeb) {
      setState(() => _webImg = img);
    } else {
      final original   = File(img.path);
      final compressed = await _compressImage(original);
      setState(() => _img = compressed ?? original);
    }
  }

  void _showPicker() {
    showModalBottomSheet(
      context: context,
      builder: (c) => SafeArea(
        child: Wrap(children: [
          ListTile(
            leading: const Icon(Icons.camera),
            title: const Text('كاميرا'),
            onTap: () { Navigator.pop(c); _pickImage(ImageSource.camera); },
          ),
          ListTile(
            leading: const Icon(Icons.photo_library),
            title: const Text('معرض الصور'),
            onTap: () { Navigator.pop(c); _pickImage(ImageSource.gallery); },
          ),
        ]),
      ),
    );
  }

  // ── حفظ ────────────────────────────────────
  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      String? finalImagePath     = _b.imagePath;
      String? finalImageFileName = _b.imageFileName;

      if (kIsWeb) {
        if (_webImg != null) {
          finalImageFileName = _b.generateImageFileName();
        }
      } else {
        if (_img != null) {
          final genName = _b.generateImageFileName();
          final moved   = await _moveToPermanentImageDir(_img!, genName);
          if (moved != null) {
            finalImagePath     = moved.path;
            finalImageFileName = genName;
          }
        } else if (_b.imagePath != null && _b.imagePath!.isNotEmpty) {
          final imgDir = await SyncService().getImagesDir();
          if (!_b.imagePath!.startsWith(imgDir.path)) {
            final oldFile = File(_b.imagePath!);
            if (await oldFile.exists()) {
              final moved = await _moveToPermanentImageDir(
                  oldFile,
                  _b.imageFileName ?? _b.generateImageFileName());
              if (moved != null) {
                finalImagePath     = moved.path;
                finalImageFileName = _b.imageFileName ?? _b.generateImageFileName();
              }
            }
          }
        }
      }

      final updated = _b.copyWith(
        done: 1,
        electricity: _e ? 1 : 0,
        gas:         _g ? 1 : 0,
        water:       _w ? 1 : 0,
        sewage:      _s ? 1 : 0,
        status:      _status,
        imagePath:      finalImagePath,
        imageFileName:  finalImageFileName,
        updatedAt: DateTime.now().add(const Duration(minutes: 1)),
      );

      await _platform.update(updated);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('✅ تم الحفظ'),
              backgroundColor: Colors.green),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('❌ $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  // ── حذف ────────────────────────────────────
  Future<void> _delete() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('تأكيد الحذف'),
        content: Text(
            'هل أنت متأكد من حذف "${_b.displayName}"؟ لا يمكن التراجع.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(c, false),
              child: const Text('إلغاء')),
          TextButton(
              onPressed: () => Navigator.pop(c, true),
              child: const Text('حذف',
                  style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (confirm != true) return;

    setState(() => _saving = true);
    try {
      await _platform.delete(_b.id!);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('🗑️ تم الحذف'),
              backgroundColor: Colors.orange),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('❌ $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Widget _chk(String label, bool val, ValueChanged<bool?> onChanged) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Checkbox(value: val, onChanged: onChanged,
          fillColor: WidgetStateProperty.resolveWith(
              (s) => s.contains(WidgetState.selected)
                  ? const Color(0xFF0D47A1) : null)),
      Text(label),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      appBar: AppBar(title: const Text('📝 إتمام بيانات المستفيد')),

      // ── أزرار ثابتة في الأسفل ────────────────
      bottomNavigationBar: _saving
          ? null
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 6, 12, 8),
                child: Row(children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.arrow_forward_ios, size: 16),
                      label: const Text('رجوع'),
                      style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF94A3B8),
                          padding: const EdgeInsets.symmetric(vertical: 13)),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _delete,
                      icon: const Icon(Icons.delete_outline, size: 16),
                      label: const Text('حذف'),
                      style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          padding: const EdgeInsets.symmetric(vertical: 13)),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton.icon(
                      onPressed: _save,
                      icon: const Icon(Icons.save_outlined, size: 16),
                      label: const Text('💾 حفظ'),
                      style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 13)),
                    ),
                  ),
                ]),
              ),
            ),

      body: _saving
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [

                  // ── معلومات المستفيد ───────────
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(18),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(_b.displayName,
                              style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF0D47A1))),
                          if (_b.birthInfo.isNotEmpty)
                            Text(_b.birthInfo,
                                style: const TextStyle(
                                    color: Color(0xFF475569))),
                          Text(
                            'العنوان: ${_b.address} | البرنامج: ${_b.program}',
                            style:
                                const TextStyle(color: Color(0xFF475569)),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 18),

                  // ── الشبكات ────────────────────
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(18),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('🔗 الربط بالشبكات:',
                              style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold)),
                          Wrap(spacing: 16, children: [
                            _chk('كهرباء', _e,
                                (v) => setState(() => _e = v!)),
                            _chk('غاز', _g,
                                (v) => setState(() => _g = v!)),
                            _chk('مياه', _w,
                                (v) => setState(() => _w = v!)),
                            _chk('تطهير', _s,
                                (v) => setState(() => _s = v!)),
                          ]),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 18),

                  // ── الحالة الفيزيائية ──────────
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(18),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('🏗️ الحالة الفيزيائية:',
                              style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold)),
                          DropdownButtonFormField<String>(
                            value: _status,
                            items: _statuses
                                .map((s) => DropdownMenuItem(
                                    value: s, child: Text(s)))
                                .toList(),
                            onChanged: (v) =>
                                setState(() => _status = v!),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 18),

                  // ── الصورة ─────────────────────
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(18),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('📷 الصورة:',
                              style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold)),
                          ElevatedButton.icon(
                            onPressed: _showPicker,
                            icon: const Icon(Icons.camera),
                            label: const Text('التقاط صورة'),
                            style: ElevatedButton.styleFrom(
                                backgroundColor:
                                    const Color(0xFF475569)),
                          ),
                          if (_img != null ||
                              _webImg != null ||
                              _b.imagePath != null)
                            Container(
                              margin: const EdgeInsets.only(top: 16),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(12),
                                boxShadow: const [
                                  BoxShadow(
                                      color: Colors.black12,
                                      blurRadius: 8)
                                ],
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: kIsWeb
                                    ? (_webImg != null
                                        ? Image.network(_webImg!.path,
                                            height: 200,
                                            fit: BoxFit.cover)
                                        : BeneficiaryImage(
                                            imagePath: _b.imagePath,
                                            imageFileName:
                                                _b.imageFileName,
                                            height: 200,
                                            fit: BoxFit.cover))
                                    : (_img != null
                                        ? Image.file(_img!,
                                            height: 200,
                                            fit: BoxFit.cover)
                                        : Image.file(
                                            File(_b.imagePath!),
                                            height: 200,
                                            fit: BoxFit.cover)),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 8),
                ],
              ),
            ),
    );
  }
}
