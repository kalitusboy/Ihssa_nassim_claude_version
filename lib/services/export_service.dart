import 'dart:io';
import 'package:archive/archive.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:open_file/open_file.dart';
import 'package:file_picker/file_picker.dart';
import 'database_service.dart';

class ExportService {
  final DatabaseService _dbService = DatabaseService();

  // ── مسار البيانات على Windows ──────────────────
  Future<Directory> get _dataDir async {
    final docs = await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(docs.path, 'ihsaa2026'));
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  // ── تصدير JSON ────────────────────────────────
  Future<void> exportFullDatabase() async {
    try {
      final jsonString = await _dbService.exportToJson();
      final dir = await _dataDir;
      final fileName = 'ihsa_backup_${DateTime.now().millisecondsSinceEpoch}.json';
      final filePath = p.join(dir.path, fileName);
      await File(filePath).writeAsString(jsonString);
      await OpenFile.open(filePath);
    } catch (e) {
      throw Exception('فشل تصدير قاعدة البيانات: $e');
    }
  }

  // ── تصدير الصور ZIP ───────────────────────────
  Future<void> exportImagesAsZip() async {
    try {
      final beneficiaries = await _dbService.getCompletedBeneficiaries();
      final withImages = beneficiaries.where((b) {
        if (b.imagePath == null) return false;
        return File(b.imagePath!).existsSync();
      }).toList();

      if (withImages.isEmpty) throw Exception('لا توجد صور للتصدير');

      final archive = Archive();
      for (final b in withImages) {
        final file = File(b.imagePath!);
        if (await file.exists()) {
          final bytes = await file.readAsBytes();
          final name = b.imageFileName ?? p.basename(b.imagePath!);
          archive.addFile(ArchiveFile(name, bytes.length, bytes));
        }
      }

      final zipBytes = ZipEncoder().encode(archive);
      if (zipBytes == null) throw Exception('فشل إنشاء ملف ZIP');

      final dir = await _dataDir;
      final zipPath = p.join(dir.path, 'ihsa_images_${DateTime.now().millisecondsSinceEpoch}.zip');
      await File(zipPath).writeAsBytes(zipBytes);
      await OpenFile.open(zipPath);
    } catch (e) {
      throw Exception('فشل تصدير الصور: $e');
    }
  }

  // ── دمج قواعد البيانات ────────────────────────
  Future<Map<String, dynamic>> mergeDatabases() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'],
        allowMultiple: true,
        dialogTitle: 'اختر ملفات JSON لدمجها',
      );

      if (result == null || result.files.isEmpty) {
        return {'imported': 0, 'updated': 0, 'skipped': 0};
      }

      final jsonFiles = result.files
          .where((f) => f.path != null)
          .map((f) => File(f.path!))
          .toList();

      final stats = await _dbService.mergeFromJsonFiles(jsonFiles);
      return {
        'imported': stats['imported'] ?? 0,
        'updated': 0,
        'skipped': stats['duplicates'] ?? 0,
      };
    } catch (e) {
      throw Exception('فشل الدمج: $e');
    }
  }
}
