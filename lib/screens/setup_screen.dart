// شاشة الإعداد الأولي — نسخة Windows (بدون QR Scanner)
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'home_screen.dart';

class SetupScreen extends StatefulWidget {
  const SetupScreen({super.key});

  @override
  State<SetupScreen> createState() => _SetupScreenState();
}

class _SetupScreenState extends State<SetupScreen> {
  static const _defaultIp = '192.168.1.1';

  final _passCtrl = TextEditingController();
  final _ipCtrl   = TextEditingController(text: _defaultIp);
  String? _role;
  bool _saving = false;
  bool _showPass = false;

  @override
  void dispose() {
    _passCtrl.dispose();
    _ipCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_role == null) { _snack('اختر نوع الجهاز أولاً'); return; }
    if (_passCtrl.text.trim().length < 4) {
      _snack('كلمة المرور يجب أن تكون 4 أحرف على الأقل'); return;
    }
    if (_role == 'agent' && _ipCtrl.text.trim().isEmpty) {
      _snack('أدخل IP الخادم (كمبيوتر المدير)'); return;
    }

    setState(() => _saving = true);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('device_role', _role!);
    await prefs.setString('sync_password', _passCtrl.text.trim());
    await prefs.setString('admin_ip',
        _role == 'admin' ? _defaultIp : _ipCtrl.text.trim());
    await prefs.setBool('setup_done', true);

    if (!mounted) return;
    Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const HomeScreen()));
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: Colors.orange),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      body: Center(
        child: SizedBox(
          width: 500,
          child: Card(
            elevation: 8,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            child: Padding(
              padding: const EdgeInsets.all(36),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // ترويسة
                  const Icon(Icons.home_work_outlined,
                      color: Color(0xFF0D47A1), size: 50),
                  const SizedBox(height: 12),
                  const Text(
                    'إحصاء السكن الريفي 2026',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF0D47A1)),
                  ),
                  const Text(
                    'نسيم — الحوضان',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Color(0xFF64748B)),
                  ),
                  const SizedBox(height: 32),

                  // نوع الجهاز
                  const Text('نوع الجهاز:',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 10),
                  Row(children: [
                    Expanded(child: _RoleCard(
                      icon: Icons.admin_panel_settings_outlined,
                      title: 'مدير',
                      subtitle: 'يستقبل بيانات الأعوان',
                      selected: _role == 'admin',
                      onTap: () => setState(() => _role = 'admin'),
                    )),
                    const SizedBox(width: 12),
                    Expanded(child: _RoleCard(
                      icon: Icons.person_outlined,
                      title: 'عون',
                      subtitle: 'يرسل البيانات للمدير',
                      selected: _role == 'agent',
                      onTap: () => setState(() => _role = 'agent'),
                    )),
                  ]),

                  const SizedBox(height: 20),

                  // كلمة المرور
                  TextField(
                    controller: _passCtrl,
                    obscureText: !_showPass,
                    decoration: InputDecoration(
                      labelText: 'كلمة المرور (مشتركة بين جميع الأجهزة)',
                      prefixIcon: const Icon(Icons.lock_outline, size: 18),
                      suffixIcon: IconButton(
                        icon: Icon(_showPass ? Icons.visibility_off : Icons.visibility, size: 18),
                        onPressed: () => setState(() => _showPass = !_showPass),
                      ),
                    ),
                  ),

                  // IP — للعون فقط
                  if (_role == 'agent') ...[
                    const SizedBox(height: 14),
                    TextField(
                      controller: _ipCtrl,
                      decoration: const InputDecoration(
                        labelText: 'عنوان IP لكمبيوتر المدير (الشبكة المحلية)',
                        prefixIcon: Icon(Icons.computer, size: 18),
                        hintText: 'مثال: 192.168.1.100',
                      ),
                      keyboardType: TextInputType.url,
                    ),
                    Padding(
                      padding: const EdgeInsets.only(top: 6, right: 4),
                      child: Text(
                        'يمكنك معرفة IP الكمبيوتر من: ipconfig في CMD',
                        style: TextStyle(color: Colors.grey.shade500, fontSize: 11),
                      ),
                    ),
                  ],

                  const SizedBox(height: 28),

                  if (_saving)
                    const Center(child: CircularProgressIndicator())
                  else
                    ElevatedButton.icon(
                      onPressed: _save,
                      icon: const Icon(Icons.check_circle_outline),
                      label: const Text('بدء التطبيق',
                          style: TextStyle(fontSize: 16)),
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size.fromHeight(52),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _RoleCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;
  const _RoleCard({
    required this.icon, required this.title, required this.subtitle,
    required this.selected, required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: selected
              ? const Color(0xFF0D47A1).withValues(alpha: 0.08)
              : Colors.grey.shade50,
          border: Border.all(
            color: selected ? const Color(0xFF0D47A1) : Colors.grey.shade200,
            width: selected ? 2 : 1,
          ),
        ),
        child: Column(children: [
          Icon(icon,
              color: selected ? const Color(0xFF0D47A1) : Colors.grey,
              size: 26),
          const SizedBox(height: 6),
          Text(title,
              style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: selected ? const Color(0xFF0D47A1) : Colors.grey.shade700)),
          Text(subtitle,
              style: TextStyle(fontSize: 10, color: Colors.grey.shade500),
              textAlign: TextAlign.center),
        ]),
      ),
    );
  }
}
