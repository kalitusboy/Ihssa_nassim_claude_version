import 'package:flutter/material.dart';
import '../models/beneficiary.dart';
import '../services/database_service.dart';

class AddBeneficiaryScreen extends StatefulWidget {
  // isDialog: true عند الفتح داخل Dialog (Windows)
  final bool isDialog;
  const AddBeneficiaryScreen({super.key, this.isDialog = false});

  @override
  State<AddBeneficiaryScreen> createState() => _AddBeneficiaryScreenState();
}

class _AddBeneficiaryScreenState extends State<AddBeneficiaryScreen> {
  final _db   = DatabaseService();
  final _form = GlobalKey<FormState>();

  final _firstName  = TextEditingController();
  final _lastName   = TextEditingController();
  final _birthDate  = TextEditingController();
  final _birthPlace = TextEditingController();
  final _address    = TextEditingController();
  final _newProgram = TextEditingController();

  String? _selectedProgram;
  List<String> _programs = [];
  bool _addingNewProgram = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _loadPrograms();
  }

  Future<void> _loadPrograms() async {
    final p = await _db.getPrograms();
    setState(() {
      _programs = p;
      if (p.isNotEmpty) _selectedProgram = p.first;
    });
  }

  @override
  void dispose() {
    for (final c in [_firstName, _lastName, _birthDate, _birthPlace, _address, _newProgram]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _pickBirthDate() async {
    final d = await showDatePicker(
      context: context,
      initialDate: DateTime(1980, 1, 1),
      firstDate: DateTime(1920),
      lastDate: DateTime.now(),
      locale: const Locale('ar'),
    );
    if (d != null) {
      _birthDate.text = '${d.year}-${d.month.toString().padLeft(2, '0')}-'
          '${d.day.toString().padLeft(2, '0')}';
    }
  }

  Future<void> _save() async {
    if (!(_form.currentState?.validate() ?? false)) return;

    final program = _addingNewProgram
        ? _newProgram.text.trim()
        : (_selectedProgram ?? 'عام');

    if (program.isEmpty) {
      _snack('⚠️ اختر برنامجاً أو أدخل برنامجاً جديداً', false);
      return;
    }

    setState(() => _saving = true);
    try {
      final dup = await _db.beneficiaryExists(
        firstName: _firstName.text.trim(),
        lastName:  _lastName.text.trim(),
        birthDate: _birthDate.text.trim().isEmpty ? null : _birthDate.text.trim(),
        address:   _address.text.trim().isEmpty   ? null : _address.text.trim(),
      );
      if (dup) {
        _snack('⚠️ يوجد مستفيد بنفس البيانات مسبقاً', false);
        setState(() => _saving = false);
        return;
      }

      final b = Beneficiary(
        firstName:   _firstName.text.trim(),
        lastName:    _lastName.text.trim(),
        name: '${_firstName.text.trim()} ${_lastName.text.trim()}'.trim(),
        birthDate:   _birthDate.text.trim().isEmpty  ? null : _birthDate.text.trim(),
        birthPlace:  _birthPlace.text.trim().isEmpty ? null : _birthPlace.text.trim(),
        address:     _address.text.trim().isEmpty    ? null : _address.text.trim(),
        program:     program,
        done:        0,
        electricity: 0, gas: 0, water: 0, sewage: 0,
        status: 'في طور الانجاز',
      );
      await _db.insertBeneficiary(b);
      if (!mounted) return;
      _snack('✅ تمت إضافة المستفيد', true);
      if (widget.isDialog) {
        Navigator.pop(context, true);
      } else {
        Navigator.pop(context, true);
      }
    } catch (e) {
      _snack('❌ فشل الإضافة: $e', false);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _snack(String msg, bool ok) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(msg),
        backgroundColor: ok ? Colors.green : Colors.red,
        behavior: SnackBarBehavior.floating,
      ));

  Widget _field(TextEditingController c, String label, IconData icon,
      {bool required = false, VoidCallback? onTap, bool readOnly = false}) {
    return TextFormField(
      controller: c,
      readOnly: readOnly,
      onTap: onTap,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, size: 18),
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      ),
      validator: required
          ? (v) => (v == null || v.trim().isEmpty) ? 'هذا الحقل مطلوب' : null
          : null,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      appBar: AppBar(
        title: const Text('➕ إضافة مستفيد جديد'),
        centerTitle: true,
        leading: widget.isDialog
            ? IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.pop(context),
              )
            : null,
      ),
      body: _saving
          ? const Center(child: CircularProgressIndicator())
          : Scrollbar(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 560),
                    child: Form(
                      key: _form,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _section('👤 البيانات الشخصية', Colors.indigo),
                          Row(children: [
                            Expanded(child: _field(_firstName, 'الاسم', Icons.person, required: true)),
                            const SizedBox(width: 12),
                            Expanded(child: _field(_lastName, 'اللقب', Icons.person_outline, required: true)),
                          ]),
                          const SizedBox(height: 10),
                          Row(children: [
                            Expanded(child: _field(_birthDate, 'تاريخ الميلاد',
                                Icons.cake, readOnly: true, onTap: _pickBirthDate)),
                            const SizedBox(width: 12),
                            Expanded(child: _field(_birthPlace, 'مكان الميلاد', Icons.location_on_outlined)),
                          ]),

                          _section('🏠 بيانات السكن', Colors.teal),
                          _field(_address, 'العنوان / الدوار', Icons.home_outlined, required: true),

                          _section('🏗️ البرنامج', Colors.deepPurple),
                          if (!_addingNewProgram) ...[ 
                            DropdownButtonFormField<String>(
                              value: _selectedProgram,
                              decoration: const InputDecoration(
                                labelText: 'اختر البرنامج',
                                prefixIcon: Icon(Icons.folder_outlined, size: 18),
                                isDense: true,
                              ),
                              items: _programs
                                  .map((pp) => DropdownMenuItem(value: pp, child: Text(pp)))
                                  .toList(),
                              onChanged: (v) => setState(() => _selectedProgram = v),
                            ),
                            const SizedBox(height: 8),
                            OutlinedButton.icon(
                              onPressed: () => setState(() => _addingNewProgram = true),
                              icon: const Icon(Icons.add, size: 18),
                              label: const Text('إضافة برنامج جديد'),
                            ),
                          ] else ...[ 
                            _field(_newProgram, 'تسمية البرنامج الجديد',
                                Icons.create_new_folder_outlined, required: true),
                            const SizedBox(height: 6),
                            TextButton.icon(
                              onPressed: () => setState(() => _addingNewProgram = false),
                              icon: const Icon(Icons.close, size: 18),
                              label: const Text('إلغاء — اختيار من الموجود'),
                            ),
                          ],

                          const SizedBox(height: 28),
                          ElevatedButton.icon(
                            onPressed: _save,
                            icon: const Icon(Icons.save, size: 18),
                            label: const Text('💾 حفظ المستفيد',
                                style: TextStyle(fontSize: 15)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF1A237E),
                              minimumSize: const Size.fromHeight(52),
                            ),
                          ),
                          const SizedBox(height: 10),
                          OutlinedButton.icon(
                            onPressed: () => Navigator.pop(context),
                            icon: const Icon(Icons.close),
                            label: const Text('إلغاء'),
                            style: OutlinedButton.styleFrom(
                              minimumSize: const Size.fromHeight(46),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
    );
  }

  Widget _section(String title, Color color) => Padding(
        padding: const EdgeInsets.only(top: 18, bottom: 10),
        child: Row(children: [
          Container(width: 4, height: 18, color: color),
          const SizedBox(width: 8),
          Text(title, style: TextStyle(fontWeight: FontWeight.bold, color: color, fontSize: 14)),
        ]),
      );
}
