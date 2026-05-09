import 'dart:async';
import 'package:flutter/material.dart';
import '../models/beneficiary.dart';
import '../services/database_service.dart';
import '../services/excel_service.dart';
import '../services/export_service.dart';
import '../widgets/beneficiary_card.dart';
import 'add_beneficiary_screen.dart';
import 'admin_merge_screen.dart';
import 'advanced_stats_screen.dart';
import 'advanced_v10_screen.dart';
import 'report_screen.dart';
import 'stats_screen.dart';
import 'survey_screen.dart';
import 'sync_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  static const int _pageSize = 100;

  final _db            = DatabaseService();
  final _excelService  = ExcelService();
  final _exportService = ExportService();
  final _stream        = StreamController<List<Beneficiary>>.broadcast();
  final _searchCtrl    = TextEditingController();
  final _scrollCtrl    = ScrollController();

  late TabController _tabs;

  List<String>      _addresses    = [];
  List<Beneficiary> _results      = [];
  String            _search       = '';
  String?           _selectedAddr;
  bool              _loading      = false;
  bool              _loadingMore  = false;
  bool              _hasMore      = true;
  int               _offset       = 0;
  int               _tab          = 0;
  int               _reqSeq       = 0;
  Timer?            _debounce;
  Map<String, dynamic>? _dash;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this)
      ..addListener(() {
        if (_tabs.indexIsChanging || _tab == _tabs.index) return;
        setState(() => _tab = _tabs.index);
        _reload();
      });
    _scrollCtrl.addListener(_onScroll);
    _init();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchCtrl.dispose();
    _scrollCtrl.dispose();
    _tabs.dispose();
    _stream.close();
    super.dispose();
  }

  Future<void> _init() async {
    await _loadAddresses();
    await _reload();
    _loadDash();
  }

  Future<void> _loadDash() async {
    final d = await _db.getDashboardStats();
    if (mounted) setState(() => _dash = d);
  }

  Future<void> _loadAddresses() async {
    final a = await _db.getDistinctAddresses();
    if (!mounted) return;
    setState(() {
      _addresses = a;
      if (_selectedAddr != null && !a.contains(_selectedAddr)) {
        _selectedAddr = null;
      }
    });
  }

  void _onScroll() {
    if (!_scrollCtrl.hasClients || _loading || _loadingMore || !_hasMore) return;
    final p = _scrollCtrl.position;
    if (p.pixels >= p.maxScrollExtent - 400) _loadMore();
  }

  Future<void> _reload() async {
    _debounce?.cancel();
    _offset = 0;
    _hasMore = true;
    _results = [];
    _stream.add(const []);
    await _loadMore(reset: true);
    _loadDash();
  }

  Future<void> _loadMore({bool reset = false}) async {
    if ((_loading || _loadingMore) && !reset) return;
    if (!reset && !_hasMore) return;
    final id = ++_reqSeq;
    if (mounted) setState(() => reset ? _loading = true : _loadingMore = true);
    try {
      final res = await _db.searchBeneficiaries(
        doneValue: _tab == 0 ? 0 : 1,
        query: _search,
        address: _selectedAddr,
        limit: _pageSize,
        offset: reset ? 0 : _offset,
      );
      if (!mounted || id != _reqSeq) return;
      _results = reset ? res : [..._results, ...res];
      _offset  = _results.length;
      _hasMore = res.length == _pageSize;
      _stream.add(List.unmodifiable(_results));
    } catch (e) {
      if (mounted && id == _reqSeq) _snack('❌ $e', false);
    } finally {
      if (mounted && id == _reqSeq) {
        setState(() { _loading = false; _loadingMore = false; });
      }
    }
  }

  Future<void> _reloadAll() async {
    await _loadAddresses();
    await _reload();
  }

  void _onSearch(String v) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () {
      if (!mounted) return;
      final n = v.trim();
      if (_search == n) return;
      setState(() => _search = n);
      _reload();
    });
  }

  Future<void> _importExcel() async {
    setState(() => _loading = true);
    try {
      final list = await _excelService.importFromExcel();
      if (list.isNotEmpty) {
        await _db.insertBeneficiaries(list);
        _snack('✅ تم استيراد ${list.length} مستفيد', true);
        await _reloadAll();
      } else {
        _snack('⚠️ لم يُستورد أي بيان، تأكد من تنسيق الأعمدة', false);
      }
    } catch (e) {
      _snack('❌ فشل الاستيراد: $e', false);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _merge() async {
    setState(() => _loading = true);
    try {
      final r = await _exportService.mergeDatabases();
      _snack('✅ ${r['imported']} جديد · ${r['updated']} محدث · ${r['skipped']} محصاة', true);
      await _reloadAll();
    } catch (e) {
      _snack('❌ $e', false);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _exportExcel() async {
    setState(() => _loading = true);
    try {
      final list = await _db.getCompletedBeneficiaries();
      if (list.isEmpty) { _snack('⚠️ لا توجد حالات محصاة', false); return; }
      final path = await _excelService.exportToExcel(beneficiaries: list, openAfterSave: true);
      if (path != null) _snack('✅ ${path.split('\\').last}', true);
    } catch (e) {
      _snack('❌ $e', false);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _snack(String msg, bool ok) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: const TextStyle(fontFamily: 'Cairo')),
      backgroundColor: ok ? Colors.green.shade700 : Colors.red.shade700,
      behavior: SnackBarBehavior.floating,
      width: 500,
      duration: const Duration(seconds: 3),
    ));
  }

  Future<void> _addBeneficiary() async {
    final added = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => Dialog(
        child: SizedBox(
          width: 620,
          height: MediaQuery.of(context).size.height * 0.85,
          child: const AddBeneficiaryScreen(isDialog: true),
        ),
      ),
    );
    if (added == true) _reloadAll();
  }

  void _showAbout() {
    showDialog(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('ℹ️ حول البرنامج'),
        content: const Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('💻 نسخة Windows — تطبيق التقارير المتقدمة v11.01'),
          SizedBox(height: 8),
          Text('الإصدار: 11.1.0 (نسخة سطح المكتب)'),
          Text('دعم عربي RTL + تقارير PDF + إحصائيات متقدمة'),
          Text('مزامنة WiFi مع هواتف الأعوان'),
          SizedBox(height: 8),
          Text('المطور: حميتي نسيم — الحوضان'),
          Text('nas.hamiti89@gmail.com'),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c), child: const Text('حسناً'))
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════
  // الشريط الجانبي — Sidebar دائم
  // ══════════════════════════════════════════════
  Widget _buildSidebar() {
    final d       = _dash;
    final total   = d?['total']   as int? ?? 0;
    final done    = d?['done']    as int? ?? 0;
    final pending = d?['pending'] as int? ?? 0;
    final pct     = total == 0 ? 0.0 : done / total;

    return Container(
      width: 220,
      color: const Color(0xFF0D47A1),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── الترويسة ──────────────────────────
          Container(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
            color: const Color(0xFF0A3880),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.home_work_outlined, color: Colors.white, size: 30),
                const SizedBox(height: 8),
                const Text('إحصاء السكن الريفي',
                    style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
                Text('نسيم — الحوضان · 2026',
                    style: TextStyle(color: Colors.white.withValues(alpha: 0.65), fontSize: 11)),
                const SizedBox(height: 12),
                // شريط التقدم
                Row(children: [
                  Text('${(pct * 100).toStringAsFixed(0)}%',
                      style: const TextStyle(color: Colors.white70, fontSize: 11)),
                  const SizedBox(width: 6),
                  Expanded(child: ClipRRect(
                    borderRadius: BorderRadius.circular(3),
                    child: LinearProgressIndicator(
                      value: pct, minHeight: 4,
                      backgroundColor: Colors.white24,
                      valueColor: const AlwaysStoppedAnimation(Colors.greenAccent),
                    ),
                  )),
                ]),
                const SizedBox(height: 6),
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  _MiniStat('الكل', total, Colors.white),
                  _MiniStat('محصاة', done, Colors.greenAccent),
                  _MiniStat('متبقية', pending, Colors.amber),
                ]),
              ],
            ),
          ),

          // ── زر إضافة مستفيد ───────────────────
          Padding(
            padding: const EdgeInsets.all(12),
            child: ElevatedButton.icon(
              onPressed: _addBeneficiary,
              icon: const Icon(Icons.person_add_alt_1, size: 16),
              label: const Text('إضافة مستفيد', style: TextStyle(fontSize: 12)),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green.shade600,
                padding: const EdgeInsets.symmetric(vertical: 10),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ),

          // ── قائمة العناصر ─────────────────────
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 4),
              children: [
                _SideSection('📊 الإحصائيات'),
                _SideItem(Icons.bar_chart_outlined, 'إحصائيات عامة', Colors.orange, () {
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const StatsScreen()))
                      .then((_) => _reload());
                }),
                _SideItem(Icons.analytics_outlined, 'إحصائيات متقدمة', Colors.purple, () {
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const AdvancedStatsScreen()));
                }),
                _SideItem(Icons.auto_graph, 'تقارير v11.01', Colors.deepPurple.shade300, () {
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const AdvancedV10Screen()));
                }),
                _SideItem(Icons.description_outlined, 'محضر المعاينة (PV)', Colors.indigo.shade200, () {
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const ReportScreen()));
                }),

                const Divider(color: Colors.white12, height: 20),
                _SideSection('📁 البيانات'),
                _SideItem(Icons.download_outlined, 'استيراد Excel', Colors.lightBlue, _importExcel),
                _SideItem(Icons.upload_file_outlined, 'تصدير Excel', Colors.greenAccent, _exportExcel),
                _SideItem(Icons.merge_outlined, 'دمج قواعد البيانات', Colors.purpleAccent, _merge),
                _SideItem(Icons.share_outlined, 'تصدير JSON', Colors.blueGrey.shade300, () {
                  _exportService.exportFullDatabase();
                }),
                _SideItem(Icons.photo_library_outlined, 'تصدير الصور ZIP', Colors.teal.shade300, () {
                  _exportService.exportImagesAsZip();
                }),

                const Divider(color: Colors.white12, height: 20),
                _SideSection('👨‍💼 المدير'),
                _SideItem(Icons.admin_panel_settings_outlined, 'دمج بيانات الأعوان', Colors.indigo.shade200, () {
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminMergeScreen()));
                }),
                _SideItem(Icons.sync_outlined, 'مزامنة WiFi', Colors.cyan.shade300, () {
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const SyncScreen()))
                      .then((_) => _reloadAll());
                }),

                const Divider(color: Colors.white12, height: 20),
                _SideItem(Icons.info_outline, 'حول البرنامج', Colors.white54, _showAbout),
              ],
            ),
          ),

          // ── إصدار ─────────────────────────────
          Padding(
            padding: const EdgeInsets.all(10),
            child: Text('v11.01 — Windows Edition',
                style: TextStyle(color: Colors.white.withValues(alpha: 0.4), fontSize: 10),
                textAlign: TextAlign.center),
          ),
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════
  // المحتوى الرئيسي
  // ══════════════════════════════════════════════
  Widget _buildMainContent() {
    final d       = _dash;
    final total   = d?['total']         as int? ?? 0;
    final done    = d?['done']          as int? ?? 0;
    final withImg = d?['with_image']    as int? ?? 0;
    final noImg   = d?['without_image'] as int? ?? 0;

    return Column(children: [

      // ══ شريط الأرقام العلوي ══════════════════
      Container(
        color: const Color(0xFF0D47A1),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        child: Row(children: [
          const Text('لوحة التحكم',
              style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold)),
          const SizedBox(width: 24),
          _TopStat('الكل',      total,   Colors.white),
          _TopStat('محصاة',     done,    Colors.greenAccent),
          _TopStat('غير محصاة', total - done, Colors.amber),
          _TopStat('📷 بصورة',  withImg, Colors.lightBlueAccent),
          _TopStat('بلا 📷',    noImg,   Colors.redAccent),
          const Spacer(),
          // زر التبويبات
          TabBar(
            controller: _tabs,
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            labelStyle: const TextStyle(fontSize: 12, fontFamily: 'Cairo'),
            tabs: const [
              Tab(text: '📋 غير المحصاة', icon: Icon(Icons.pending_actions, size: 14)),
              Tab(text: '✅ المحصاة',      icon: Icon(Icons.check_circle,   size: 14)),
            ],
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white54,
            indicatorColor: Colors.white,
          ),
        ]),
      ),

      // ══ شريط البحث والفلتر ════════════════════
      Container(
        color: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(children: [
          // فلتر العنوان
          SizedBox(
            width: 200,
            child: DropdownButtonFormField<String?>(
              value: _selectedAddr,
              decoration: const InputDecoration(
                labelText: 'فلتر بالعنوان',
                isDense: true,
                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              ),
              items: [
                const DropdownMenuItem<String?>(value: null, child: Text('كل العناوين')),
                ..._addresses.map((a) => DropdownMenuItem<String?>(value: a, child: Text(a))),
              ],
              onChanged: (v) {
                setState(() => _selectedAddr = v);
                _reload();
              },
            ),
          ),
          const SizedBox(width: 12),
          // حقل البحث
          Expanded(
            child: TextField(
              controller: _searchCtrl,
              decoration: const InputDecoration(
                hintText: '🔍  بحث بالاسم أو العنوان أو البرنامج...',
                isDense: true,
                prefixIcon: Icon(Icons.search, size: 18),
              ),
              onChanged: _onSearch,
            ),
          ),
          const SizedBox(width: 12),
          // زر تحديث
          OutlinedButton.icon(
            onPressed: _reloadAll,
            icon: const Icon(Icons.refresh, size: 16),
            label: const Text('تحديث'),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            ),
          ),
        ]),
      ),

      const Divider(height: 1),

      // ══ القائمة ═══════════════════════════════
      Expanded(
        child: StreamBuilder<List<Beneficiary>>(
          stream: _stream.stream,
          initialData: const [],
          builder: (context, snap) {
            final list    = snap.data ?? const <Beneficiary>[];
            final isEmpty = list.isEmpty && !_loading;

            if (_loading && list.isEmpty) {
              return const Center(child: CircularProgressIndicator());
            }

            if (isEmpty) {
              return Center(
                child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Icon(Icons.people_outline, size: 80, color: Colors.grey.shade300),
                  const SizedBox(height: 16),
                  Text(
                    _tab == 0 ? 'لا توجد حالات غير محصاة' : 'لا توجد حالات محصاة',
                    style: TextStyle(color: Colors.grey.shade500, fontSize: 16),
                  ),
                  if (_search.isNotEmpty || _selectedAddr != null) ...[ 
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: () {
                        _searchCtrl.clear();
                        setState(() { _search = ''; _selectedAddr = null; });
                        _reload();
                      },
                      child: const Text('مسح الفلاتر'),
                    ),
                  ],
                ]),
              );
            }

            return Column(children: [
              // عداد النتائج
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                child: Row(children: [
                  Text('${list.length}${_hasMore ? '+' : ''} نتيجة',
                      style: const TextStyle(
                          color: Color(0xFF475569), fontSize: 13, fontWeight: FontWeight.w600)),
                  const Spacer(),
                  if (_hasMore)
                    Text('تحميل تدريجي — اسحب للأسفل لمزيد',
                        style: TextStyle(color: Colors.grey.shade400, fontSize: 11)),
                ]),
              ),
              // القائمة
              Expanded(
                child: Scrollbar(
                  controller: _scrollCtrl,
                  child: ListView.builder(
                    controller: _scrollCtrl,
                    padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                    itemCount: list.length + (_loadingMore ? 1 : 0),
                    itemBuilder: (context, i) {
                      if (i >= list.length) {
                        return const Padding(
                          padding: EdgeInsets.symmetric(vertical: 16),
                          child: Center(child: CircularProgressIndicator()),
                        );
                      }
                      final b = list[i];
                      return BeneficiaryCard(
                        beneficiary: b,
                        onTap: () => _openSurvey(b),
                      );
                    },
                  ),
                ),
              ),
            ]);
          },
        ),
      ),
    ]);
  }

  Future<void> _openSurvey(Beneficiary b) async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => Dialog(
        child: SizedBox(
          width: 700,
          height: MediaQuery.of(context).size.height * 0.88,
          child: SurveyScreen(beneficiary: b),
        ),
      ),
    );
    if (result == true) _reloadAll();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      body: Row(
        children: [
          _buildSidebar(),
          const VerticalDivider(width: 1, thickness: 1),
          Expanded(child: _buildMainContent()),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
// مكونات مساعدة
// ─────────────────────────────────────────────

class _MiniStat extends StatelessWidget {
  final String label;
  final int value;
  final Color color;
  const _MiniStat(this.label, this.value, this.color);

  @override
  Widget build(BuildContext context) => Column(children: [
    Text(value.toString(),
        style: TextStyle(color: color, fontSize: 13, fontWeight: FontWeight.bold)),
    Text(label, style: const TextStyle(color: Colors.white54, fontSize: 9)),
  ]);
}

class _TopStat extends StatelessWidget {
  final String label;
  final int value;
  final Color color;
  const _TopStat(this.label, this.value, this.color);

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 12),
    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      Text(value.toString(),
          style: TextStyle(color: color, fontSize: 16, fontWeight: FontWeight.bold)),
      Text(label, style: const TextStyle(color: Colors.white60, fontSize: 10)),
    ]),
  );
}

class _SideSection extends StatelessWidget {
  final String title;
  const _SideSection(this.title);

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(14, 6, 14, 3),
    child: Text(title,
        style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.bold,
            color: Colors.white.withValues(alpha: 0.45),
            letterSpacing: 0.3)),
  );
}

class _SideItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _SideItem(this.icon, this.label, this.color, this.onTap);

  @override
  Widget build(BuildContext context) {
    return ListTile(
      dense: true,
      leading: Icon(icon, color: color, size: 18),
      title: Text(label,
          style: const TextStyle(fontSize: 12, color: Colors.white)),
      onTap: onTap,
      horizontalTitleGap: 8,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 0),
      hoverColor: Colors.white.withValues(alpha: 0.08),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
    );
  }
}
