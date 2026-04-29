import 'package:flutter/foundation.dart';
import '../models/beneficiary.dart';
import 'api_service.dart';
import 'database_service.dart';

/// واجهة موحّدة — تختار تلقائياً:
///   kIsWeb == true  → ApiService  (HTTP → Python)
///   kIsWeb == false → DatabaseService (SQLite)
class PlatformService {
  static final PlatformService _i = PlatformService._();
  factory PlatformService() => _i;
  PlatformService._();

  final _api = ApiService();
  final _db  = DatabaseService();

  bool get isWeb => kIsWeb;

  // ─────────────────────────────────────────────
  // Beneficiaries
  // ─────────────────────────────────────────────

  Future<List<Beneficiary>> search({
    required int doneValue,
    String query = '',
    String? address,
    int limit = 100,
    int offset = 0,
  }) {
    if (isWeb) {
      return _api.search(
          doneValue: doneValue,
          query: query,
          address: address,
          limit: limit,
          offset: offset);
    }
    return _db.searchBeneficiaries(
        doneValue: doneValue,
        query: query,
        address: address,
        limit: limit,
        offset: offset);
  }

  Future<int> insert(Beneficiary b) =>
      isWeb ? _api.insert(b) : _db.insertBeneficiary(b);

  Future<void> update(Beneficiary b) =>
      isWeb ? _api.update(b) : _db.updateBeneficiary(b).then((_) {});

  Future<void> delete(int id) =>
      isWeb ? _api.delete(id) : _db.deleteBeneficiary(id).then((_) {});

  Future<int> insertMany(List<Beneficiary> list) =>
      isWeb ? _api.insertMany(list) : _db.insertBeneficiaries(list).then((_) => list.length);

  // ─────────────────────────────────────────────
  // Filters
  // ─────────────────────────────────────────────

  Future<List<String>> getAddresses() =>
      isWeb ? _api.getAddresses() : _db.getDistinctAddresses();

  Future<List<String>> getPrograms() =>
      isWeb ? _api.getPrograms() : _db.getPrograms();

  // ─────────────────────────────────────────────
  // Statistics
  // ─────────────────────────────────────────────

  Future<Map<String, dynamic>> getDashboardStats() =>
      isWeb ? _api.getDashboardStats() : _db.getDashboardStats();

  Future<Map<String, dynamic>> getAdvancedStats() =>
      isWeb ? _api.getAdvancedStats() : _db.getAdvancedStats();

  Future<Map<String, dynamic>> getReportStats(String program) =>
      isWeb ? _api.getReportStats(program) : _db.getReportStats(program);

  // ─────────────────────────────────────────────
  // Export
  // ─────────────────────────────────────────────

  /// على الويب → رابط تنزيل مباشر
  /// على الهاتف → null (يستخدم ExcelService)
  String? exportCsvUrl()      => isWeb ? _api.exportCsvUrl()      : null;
  String? exportStatsCsvUrl() => isWeb ? _api.exportStatsCsvUrl() : null;
  String? exportPhotosZipUrl(String program) =>
      isWeb ? _api.exportPhotosZipUrl(program) : null;

  /// رابط صورة على الويب (من السيرفر)
  String? imageUrl(String? name) {
    if (!isWeb || name == null || name.isEmpty) return null;
    return _api.imageUrl(name);
  }
}
