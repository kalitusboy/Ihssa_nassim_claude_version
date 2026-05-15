// شاشة المزامنة — نسخة Windows (بدون QR Scanner، بدون Mobile)
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/sync_server.dart';
import '../services/sync_client.dart';
import 'setup_screen.dart';

class SyncScreen extends StatefulWidget {
  const SyncScreen({super.key});

  @override
  State<SyncScreen> createState() => _SyncScreenState();
}

class _SyncScreenState extends State<SyncScreen> {
  final _server = SyncServer();
  final _client = SyncClient();

  String _role = '';
  String _password = '';
  String _adminIp = '';

  bool _serverRunning = false;
  String? _serverIp;
  bool _syncing = false;
  String _progress = '';
  String _lastSync = 'لم تتم بعد';
  _MsgType _msgType = _MsgType.info;

  @override
  void initState() {
    super.initState();
    _serverRunning = _server.isRunning;
    _serverIp = _server.localIp;
    _loadConfig();
  }

  Future<void> _loadConfig() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _role = prefs.getString('device_role') ?? 'admin';
      _password = prefs.getString('sync_password') ?? '';
      _adminIp = prefs.getString('admin_ip') ?? '';
      _lastSync = prefs.getString('last_sync') ?? 'لم تتم بعد';
    });
    _client.configure(ip: _adminIp, password: _password);
  }

  String get _qrData => 'nhsync://$_serverIp:8080?pw=${Uri.encodeComponent(_password)}';

  Future<void> _toggleServer() async {
    if (_serverRunning) {
      await _server.stop();
      setState(() {
        _serverRunning = false;
        _serverIp = null;
        _progress = 'السيرفر متوقف.';
        _msgType = _MsgType.warn;
      });
    } else {
      setState(() => _progress = '⏳ جاري تشغيل السيرفر...');
      final ip = await _server.start(password: _password);
      setState(() {
        _serverRunning = ip != null;
        _serverIp = ip;
        _msgType = ip != null ? _MsgType.ok : _MsgType.err;
        _progress = ip != null
            ? 'السيرفر يعمل ✅ — IP: $ip:8080'
            : 'تعذر الحصول على IP — تأكد من الشبكة';
      });
    }
  }

  Future<void> _download() async {
    setState(() { _syncing = true; _msgType = _MsgType.info; _progress = ''; });
    final result = await _client.downloadFromServer(
      onProgress: (msg) => setState(() => _progress = msg),
    );
    if (result.success) {
      final prefs = await SharedPreferences.getInstance();
      final now = DateTime.now().toString().substring(0, 16);
      await prefs.setString('last_sync', now);
      setState(() {
        _lastSync = now;
        _msgType = _MsgType.ok;
        _progress = '✅ تمت المزامنة: ${result.added} مضاف · ${result.updated} محدث';
      });
    } else {
      setState(() {
        _msgType = _MsgType.err;
        _progress = '❌ ${result.error}';
      });
    }
    setState(() => _syncing = false);
  }

  void _resetSetup() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('إعادة الإعداد'),
        content: const Text('هل تريد إعادة ضبط الإعداد؟'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('إلغاء')),
          TextButton(
            onPressed: () => Navigator.pop(c, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('إعادة الإعداد'),
          ),
        ],
      ),
    );
    if (confirm == true) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('setup_done', false);
      if (!mounted) return;
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const SetupScreen()));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      appBar: AppBar(title: const Text('📡 مزامنة WiFi')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── العمود الأيسر: الإعدادات والتحكم ──
            Expanded(
              flex: 3,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // معلومات الجهاز
                  Card(child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      const Text('ℹ️ معلومات الجهاز',
                          style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 12),
                      _InfoRow('الدور', _role == 'admin' ? '👨‍💼 مدير' : '👤 عون'),
                      _InfoRow('آخر مزامنة', _lastSync),
                      if (_serverRunning && _serverIp != null)
                        _InfoRow('IP الكمبيوتر', '$_serverIp:8080',
                            copyable: true),
                      const SizedBox(height: 12),
                      TextButton.icon(
                        onPressed: _resetSetup,
                        icon: const Icon(Icons.settings_backup_restore, size: 16),
                        label: const Text('إعادة الإعداد'),
                        style: TextButton.styleFrom(foregroundColor: Colors.orange),
                      ),
                    ]),
                  )),

                  const SizedBox(height: 16),

                  // تحكم المدير
                  if (_role == 'admin') ...[
                    Card(child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                        const Text('🖥️ السيرفر (كمبيوتر المدير)',
                            style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 12),
                        ElevatedButton.icon(
                          onPressed: _toggleServer,
                          icon: Icon(_serverRunning ? Icons.stop : Icons.play_arrow, size: 18),
                          label: Text(_serverRunning ? 'إيقاف السيرفر' : '▶ تشغيل السيرفر'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _serverRunning ? Colors.red.shade700 : Colors.green.shade700,
                            minimumSize: const Size.fromHeight(48),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'الأعوان يتصلون بنفس الشبكة WiFi ويُدخلون IP هذا الكمبيوتر',
                          style: TextStyle(color: Colors.grey.shade500, fontSize: 11),
                        ),
                      ]),
                    )),
                  ],

                  // تحكم العون
                  if (_role == 'agent') ...[
                    Card(child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                        const Text('📤 رفع البيانات للمدير',
                            style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 12),
                        ElevatedButton.icon(
                          onPressed: _syncing ? null : _download,
                          icon: _syncing
                              ? const SizedBox(width: 16, height: 16,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                              : const Icon(Icons.sync, size: 18),
                          label: Text(_syncing ? 'جاري المزامنة...' : '⬆ مزامنة مع المدير'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF0D47A1),
                            minimumSize: const Size.fromHeight(48),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text('IP المدير: $_adminIp',
                            style: TextStyle(color: Colors.grey.shade500, fontSize: 12)),
                      ]),
                    )),
                  ],

                  const SizedBox(height: 16),

                  // رسالة الحالة
                  if (_progress.isNotEmpty)
                    Card(child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(children: [
                        Icon(
                          _msgType == _MsgType.ok ? Icons.check_circle
                            : _msgType == _MsgType.err ? Icons.error
                            : Icons.info_outline,
                          color: _msgType == _MsgType.ok ? Colors.green
                            : _msgType == _MsgType.err ? Colors.red
                            : Colors.blue,
                          size: 20,
                        ),
                        const SizedBox(width: 10),
                        Expanded(child: Text(_progress)),
                      ]),
                    )),
                ],
              ),
            ),

            const SizedBox(width: 24),

            // ── العمود الأيمن: QR Code ──
            if (_role == 'admin' && _serverRunning && _serverIp != null)
              SizedBox(
                width: 260,
                child: Card(child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('📱 QR للهواتف',
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      Text('امسح بهاتف العون', style: TextStyle(color: Colors.grey.shade500, fontSize: 11)),
                      const SizedBox(height: 16),
                      QrImageView(
                        data: _qrData,
                        version: QrVersions.auto,
                        size: 200,
                        backgroundColor: Colors.white,
                      ),
                      const SizedBox(height: 12),
                      Text('$_serverIp:8080',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                      const SizedBox(height: 8),
                      OutlinedButton.icon(
                        onPressed: () {
                          Clipboard.setData(ClipboardData(text: '$_serverIp:8080'));
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('✅ تم النسخ'), duration: Duration(seconds: 2)),
                          );
                        },
                        icon: const Icon(Icons.copy, size: 14),
                        label: const Text('نسخ IP', style: TextStyle(fontSize: 12)),
                      ),
                    ],
                  ),
                )),
              ),
          ],
        ),
      ),
    );
  }
}

enum _MsgType { info, ok, warn, err }

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  final bool copyable;
  const _InfoRow(this.label, this.value, {this.copyable = false});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(children: [
        Text('$label: ', style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
        Expanded(child: Text(value,
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13))),
        if (copyable)
          IconButton(
            icon: const Icon(Icons.copy, size: 14),
            onPressed: () {
              Clipboard.setData(ClipboardData(text: value));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('تم النسخ'), duration: Duration(seconds: 2)),
              );
            },
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            visualDensity: VisualDensity.compact,
          ),
      ]),
    );
  }
}
