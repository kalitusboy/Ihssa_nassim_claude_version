import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/beneficiary.dart';

/// خدمة الـ API — تُستخدم على الويب بدل SQLite
/// تتصل بسيرفر Python Flask
class ApiService {
  static final ApiService _i = ApiService._();
  factory ApiService() => _i;
  ApiService._();

  // على الويب: نفس الـ origin تلقائياً (localhost:8080)
  // على الهاتف: IP المدير
  String _base = '';
  String _password = '';

  void configure({String base = '', String password = ''}) {
    _base = base;
    _password = password;
  }

  // على الويب يستخدم نفس الـ host تلقائياً
  String get _url {
    if (kIsWeb) {
      // نفس الـ origin
      final uri = Uri.base;
      return '${uri.scheme}://${uri.host}:${uri.port}';
    }
    return _base;
  }

  Map<String, String> get _headers => {
    'Content-Type': 'application/json; charset=utf-8',
    'x-password': _password,
  };

  Future<Map<String, dynamic>> _get(String path,
      {Map<String, String>? params}) async {
    var uri = Uri.parse('$_url/api$path');
    if (params != null && params.isNotEmpty) {
      uri = uri.replace(queryParameters: params);
    }
    final res = await http.get(uri, headers: _headers)
        .timeout(const Duration(seconds: 30));
    return jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> _post(String path, Object body) async {
    final res = await http
        .post(Uri.parse('$_url/api$path'),
            headers: _headers, body: jsonEncode(body))
        .timeout(const Duration(minutes: 3));
    return jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> _put(String path, Object body) async {
    final res = await http
        .put(Uri.parse('$_url/api$path'),
            headers: _headers, body: jsonEncode(body))
        .timeout(const Duration(seconds: 30));
    return jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> _delete(String path) async {
    final res = await http
        .delete(Uri.parse('$_url/api$path'), headers: _headers)
        .timeout(const Duration(seconds: 30));
    return jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
  }

  // ─────────────────────────────────────────────
  // Beneficiaries
  // ─────────────────────────────────────────────

  Future<List<Beneficiary>> search({
    required int doneValue,
    String query = '',
    String? address,
    int limit = 100,
    int offset = 0,
  }) async {
    final params = <String, String>{
      'done':   doneValue.toString(),
      'limit':  limit.toString(),
      'offset': offset.toString(),
      if (query.isNotEmpty) 'q': query,
      if (address != null && address.isNotEmpty) 'address': address,
    };
    final res = await _get('/beneficiaries', params: params);
    final list = (res['data'] as List? ?? []).cast<Map<String, dynamic>>();
    return list.map(Beneficiary.fromMap).toList();
  }

  Future<int> insert(Beneficiary b) async {
    final res = await _post('/beneficiaries', b.toMap());
    return res['id'] as int? ?? 0;
  }

  Future<void> update(Beneficiary b) async {
    await _put('/beneficiaries/${b.id}', b.toMap());
  }

  Future<void> delete(int id) async {
    await _delete('/beneficiaries/$id');
  }

  Future<int> insertMany(List<Beneficiary> list) async {
    final res =
        await _post('/beneficiaries/batch', list.map((b) => b.toMap()).toList());
    return res['inserted'] as int? ?? 0;
  }

  // ─────────────────────────────────────────────
  // Filters
  // ─────────────────────────────────────────────

  Future<List<String>> getAddresses() async {
    final res = await _get('/addresses');
    return (res['data'] as List? ?? []).cast<String>();
  }

  Future<List<String>> getPrograms() async {
    final res = await _get('/programs');
    return (res['data'] as List? ?? []).cast<String>();
  }

  // ─────────────────────────────────────────────
  // Statistics
  // ─────────────────────────────────────────────

  Future<Map<String, dynamic>> getDashboardStats() async {
    final res = await _get('/stats/dashboard');
    return res['data'] as Map<String, dynamic>? ?? {};
  }

  Future<Map<String, dynamic>> getAdvancedStats() async {
    final res = await _get('/stats/advanced');
    return res['data'] as Map<String, dynamic>? ?? {};
  }

  Future<Map<String, dynamic>> getReportStats(String program) async {
    final encoded = Uri.encodeComponent(program);
    final res     = await _get('/stats/report/$encoded');
    return res['data'] as Map<String, dynamic>? ?? {};
  }

  // ─────────────────────────────────────────────
  // Images
  // ─────────────────────────────────────────────

  Future<Set<String>> getServerImageNames() async {
    final res = await _get('/images/list');
    return Set<String>.from((res['filenames'] as List? ?? []).cast<String>());
  }

  String imageUrl(String name) => '$_url/api/images/$name?password=$_password';

  // ─────────────────────────────────────────────
  // Export (تنزيل مباشر من المتصفح)
  // ─────────────────────────────────────────────

  String exportCsvUrl() => '$_url/api/export/csv?password=$_password';
  String exportStatsCsvUrl() => '$_url/api/export/stats/csv?password=$_password';
  String exportPhotosZipUrl(String program) =>
      '$_url/api/images/zip/${Uri.encodeComponent(program)}?password=$_password';

  // ─────────────────────────────────────────────
  // Sync (من الهاتف للسيرفر)
  // ─────────────────────────────────────────────

  Future<Map<String, dynamic>> sync(List<Map<String, dynamic>> records) async {
    return _post('/sync', {'records': records});
  }

  // ─────────────────────────────────────────────
  // Auth
  // ─────────────────────────────────────────────

  Future<bool> ping() async {
    try {
      final res = await http
          .get(Uri.parse('$_url/api/ping'), headers: _headers)
          .timeout(const Duration(seconds: 5));
      return res.statusCode == 200;
    } catch (_) {
      return false;
    }
  }
}
