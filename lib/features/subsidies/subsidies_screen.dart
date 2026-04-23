import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:intl/intl.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/widgets/module_header.dart';
import '../../core/constants/app_constants.dart';
import '../../data/models/finance_model.dart';
import '../../data/repositories/finance_repository.dart';
import '../../shared/widgets/empty_state.dart';

class SubsidiesScreen extends StatefulWidget {
  const SubsidiesScreen({super.key});

  @override
  State<SubsidiesScreen> createState() => _SubsidiesScreenState();
}

class _SubsidiesScreenState extends State<SubsidiesScreen> with SingleTickerProviderStateMixin {
  late TabController _tab;
  final _repo = FinanceRepository();
  List<FinanceModel> _subsidyRecords = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 3, vsync: this);
    _load();
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final all = await _repo.getAll();
      setState(() {
        _subsidyRecords = all.where((f) => f.category == AppConstants.incomeSubsidy).toList();
        _loading = false;
      });
    } catch (_) {
      setState(() => _loading = false);
    }
  }

  Future<void> _delete(FinanceModel f) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Kaydı Sil'),
        content: const Text('Bu destek kaydı silinsin mi?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('İptal')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.errorRed),
            child: const Text('Sil'),
          ),
        ],
      ),
    );
    if (ok == true) {
      await _repo.delete(f.id!);
      _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Devlet Destekleri'),
        bottom: TabBar(
          controller: _tab,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          indicatorColor: Colors.white,
          tabs: const [Tab(text: 'Yıllık Takvim'), Tab(text: 'Alınan Destekler'), Tab(text: 'Bakanlık Duyuruları')],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          await Navigator.push(context, MaterialPageRoute(builder: (_) => const AddSubsidyScreen()));
          _load();
        },
        icon: const Icon(Icons.add),
        label: const Text('Destek Ekle'),
        backgroundColor: AppColors.gold,
        foregroundColor: Colors.white,
      ),
      body: Stack(
        children: [
          const ModuleBackground(pattern: ModulePattern.subsidies),
          _loading
              ? const Center(child: CircularProgressIndicator())
              : TabBarView(
                  controller: _tab,
                  children: [
                    const _CalendarTab(),
                    _ReceivedTab(records: _subsidyRecords, onDelete: _delete, onRefresh: _load),
                    const _AnnouncementsTab(),
                  ],
                ),
        ],
      ),
    );
  }
}

class _CalendarTab extends StatelessWidget {
  const _CalendarTab();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.infoBlue.withOpacity(0.08),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.infoBlue.withOpacity(0.3)),
          ),
          child: const Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.info_outline, color: AppColors.infoBlue, size: 20),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Aşağıdaki takvim T.C. Tarım ve Orman Bakanlığı\'nın yıllık destek programlarına göre hazırlanmıştır. '
                  'Güncel bilgi için İl Tarım ve Orman Müdürlüğünüze danışınız.',
                  style: TextStyle(fontSize: 12, color: AppColors.infoBlue, height: 1.5),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        ...AppConstants.subsidyDeadlines.map((s) => _SubsidyCard(data: s)),
        const SizedBox(height: 80),
      ],
    );
  }
}

class _SubsidyCard extends StatelessWidget {
  final Map<String, String> data;
  const _SubsidyCard({required this.data});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border(left: BorderSide(color: AppColors.gold, width: 4)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 4)],
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const Icon(Icons.account_balance, color: AppColors.gold, size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Text(data['title']!, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
            ),
          ]),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: AppColors.gold.withOpacity(0.15),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              data['month']!,
              style: const TextStyle(color: AppColors.gold, fontWeight: FontWeight.w700, fontSize: 12),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            data['description']!,
            style: const TextStyle(fontSize: 13, color: AppColors.textGrey, height: 1.5),
          ),
        ]),
      ),
    );
  }
}

class _ReceivedTab extends StatelessWidget {
  final List<FinanceModel> records;
  final Function(FinanceModel) onDelete;
  final Future<void> Function() onRefresh;

  const _ReceivedTab({required this.records, required this.onDelete, required this.onRefresh});

  @override
  Widget build(BuildContext context) {
    if (records.isEmpty) {
      return RefreshIndicator(
        onRefresh: onRefresh,
        child: ListView(children: [
          const SizedBox(height: 80),
          const EmptyState(
            icon: Icons.account_balance_outlined,
            title: 'Kayıt Yok',
            subtitle: 'Alınan devlet destekleri burada görüntülenecek.\nSağ alttaki butona basarak kayıt ekleyebilirsiniz.',
          ),
        ]),
      );
    }
    final fmt = NumberFormat('#,##0.00', 'tr_TR');
    final total = records.fold<double>(0, (s, r) => s + r.amount);
    return Column(
      children: [
        Container(
          margin: const EdgeInsets.all(12),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [AppColors.primaryGreen, Color(0xFF2E7D32)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Toplam Alınan Destek', style: TextStyle(color: Colors.white70, fontSize: 12)),
              SizedBox(height: 2),
              Text('Bu yıl', style: TextStyle(color: Colors.white54, fontSize: 11)),
            ]),
            Text(
              '₺${fmt.format(total)}',
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 20),
            ),
          ]),
        ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: onRefresh,
            child: ListView.builder(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 100),
              itemCount: records.length,
            itemBuilder: (_, i) {
              final r = records[i];
              return Container(
                margin: const EdgeInsets.only(bottom: 6),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border(left: BorderSide(color: AppColors.gold, width: 4)),
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 3)],
                ),
                child: ListTile(
                  leading: const CircleAvatar(
                    backgroundColor: Color(0xFFFFF8E1),
                    child: Icon(Icons.account_balance, color: AppColors.gold),
                  ),
                  title: Text(
                    r.description ?? r.category,
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                  ),
                  subtitle: Text(r.date, style: const TextStyle(fontSize: 12, color: AppColors.textGrey)),
                  trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                    Text(
                      '₺${fmt.format(r.amount)}',
                      style: const TextStyle(fontWeight: FontWeight.w700, color: Color(0xFF2E7D32), fontSize: 15),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline, color: AppColors.textGrey, size: 20),
                      onPressed: () => onDelete(r),
                    ),
                  ]),
                ),
              );
            },
            ),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────
// ANNOUNCEMENTS TAB (WebView)
// ─────────────────────────────────────────────

class _AnnouncementsTab extends StatefulWidget {
  const _AnnouncementsTab();

  @override
  State<_AnnouncementsTab> createState() => _AnnouncementsTabState();
}

class _AnnouncementsTabState extends State<_AnnouncementsTab> {
  late final WebViewController _controller;
  bool _loading = true;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(NavigationDelegate(
        onPageStarted: (_) => setState(() { _loading = true; _hasError = false; }),
        onPageFinished: (_) => setState(() => _loading = false),
        onWebResourceError: (_) => setState(() { _loading = false; _hasError = true; }),
      ))
      ..loadRequest(Uri.parse('https://www.tarimorman.gov.tr'));
  }

  @override
  Widget build(BuildContext context) {
    if (_hasError) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.wifi_off, size: 48, color: AppColors.textGrey),
            const SizedBox(height: 16),
            const Text('Sayfa yüklenemedi', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.textDark)),
            const SizedBox(height: 8),
            const Text('İnternet bağlantınızı kontrol ediniz', style: TextStyle(fontSize: 13, color: AppColors.textGrey)),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () {
                setState(() { _loading = true; _hasError = false; });
                _controller.reload();
              },
              icon: const Icon(Icons.refresh),
              label: const Text('Tekrar Dene'),
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryGreen, foregroundColor: Colors.white),
            ),
          ],
        ),
      );
    }
    return Stack(
      children: [
        WebViewWidget(
          controller: _controller,
          gestureRecognizers: {
            Factory<VerticalDragGestureRecognizer>(() => VerticalDragGestureRecognizer()),
            Factory<HorizontalDragGestureRecognizer>(() => HorizontalDragGestureRecognizer()),
            Factory<ScaleGestureRecognizer>(() => ScaleGestureRecognizer()),
          },
        ),
        if (_loading)
          const LinearProgressIndicator(
            backgroundColor: Colors.transparent,
            valueColor: AlwaysStoppedAnimation<Color>(AppColors.primaryGreen),
          ),
      ],
    );
  }
}

// ─────────────────────────────────────────────
// ADD SUBSIDY SCREEN
// ─────────────────────────────────────────────

class AddSubsidyScreen extends StatefulWidget {
  const AddSubsidyScreen({super.key});

  @override
  State<AddSubsidyScreen> createState() => _AddSubsidyScreenState();
}

class _AddSubsidyScreenState extends State<AddSubsidyScreen> {
  final _formKey = GlobalKey<FormState>();
  final _repo = FinanceRepository();
  final _descCtrl = TextEditingController();
  final _amountCtrl = TextEditingController();
  DateTime _date = DateTime.now();
  bool _saving = false;

  Future<void> _pickDate() async {
    final d = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (d != null) setState(() => _date = d);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    final model = FinanceModel(
      type: AppConstants.income,
      category: AppConstants.incomeSubsidy,
      amount: double.parse(_amountCtrl.text.replaceAll(',', '.')),
      date: DateFormat('yyyy-MM-dd').format(_date),
      description: _descCtrl.text.trim().isEmpty ? null : _descCtrl.text.trim(),
      createdAt: DateTime.now().toIso8601String(),
    );
    try {
      await _repo.insert(model);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      setState(() => _saving = false);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Hata: $e')));
    }
  }

  @override
  void dispose() {
    _descCtrl.dispose();
    _amountCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Destek Kaydı Ekle')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.gold.withOpacity(0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.gold.withOpacity(0.3)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.lightbulb_outline, color: AppColors.gold, size: 18),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Aldığınız devlet desteklerini buraya kaydederek yıllık destek gelirinizi takip edebilirsiniz.',
                      style: TextStyle(fontSize: 12, color: AppColors.textGrey, height: 1.5),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Card(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(children: [
                  TextFormField(
                    controller: _descCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Destek Adı / Açıklama *',
                      hintText: 'Örn: Büyükbaş Hayvancılık Desteği 2026',
                    ),
                    validator: (v) => v == null || v.isEmpty ? 'Açıklama giriniz' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _amountCtrl,
                    decoration: const InputDecoration(labelText: 'Tutar (₺) *', prefixText: '₺ '),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    validator: (v) {
                      if (v == null || v.isEmpty) return 'Tutar giriniz';
                      if (double.tryParse(v.replaceAll(',', '.')) == null) return 'Geçersiz tutar';
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  InkWell(
                    onTap: _pickDate,
                    child: InputDecorator(
                      decoration: const InputDecoration(
                        labelText: 'Alınma Tarihi',
                        suffixIcon: Icon(Icons.calendar_today, size: 18),
                      ),
                      child: Text(DateFormat('dd MMMM yyyy', 'tr_TR').format(_date)),
                    ),
                  ),
                ]),
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              height: 50,
              child: ElevatedButton(
                onPressed: _saving ? null : _save,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.gold,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: _saving
                    ? const CircularProgressIndicator(color: Colors.white, strokeWidth: 2)
                    : const Text('Destek Kaydet', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
