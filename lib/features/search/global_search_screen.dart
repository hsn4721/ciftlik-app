import 'dart:async';
import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../data/models/animal_model.dart';
import '../../data/models/calf_model.dart';
import '../../data/models/staff_model.dart';
import '../../data/models/feed_model.dart';
import '../../data/models/equipment_model.dart';
import '../../data/models/farm_member_model.dart';
import '../../data/repositories/animal_repository.dart';
import '../../data/repositories/calf_repository.dart';
import '../../data/repositories/staff_repository.dart';
import '../../data/repositories/feed_repository.dart';
import '../../data/repositories/equipment_repository.dart';
import '../../core/services/auth_service.dart';
import '../../core/services/farm_member_service.dart';
import '../herd/animal_detail_screen.dart';

/// Uygulama genelinde arama — hayvan (küpe/isim), buzağı, yem stoku,
/// ekipman, personel kayıtları ve çiftlik üyeleri içinde metin eşleştirmesi.
class GlobalSearchScreen extends StatefulWidget {
  const GlobalSearchScreen({super.key});

  @override
  State<GlobalSearchScreen> createState() => _GlobalSearchScreenState();
}

class _GlobalSearchScreenState extends State<GlobalSearchScreen> {
  final _ctrl = TextEditingController();
  Timer? _debounce;

  List<AnimalModel> _animals = [];
  List<CalfModel> _calves = [];
  List<FeedStockModel> _feedStocks = [];
  List<EquipmentModel> _equipments = [];
  List<StaffModel> _staff = [];
  List<FarmMember> _members = [];

  List<AnimalModel> _aResult = [];
  List<CalfModel> _cResult = [];
  List<FeedStockModel> _fResult = [];
  List<EquipmentModel> _eResult = [];
  List<StaffModel> _sResult = [];
  List<FarmMember> _mResult = [];

  bool _loading = true;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _loadSources();
  }

  Future<void> _loadSources() async {
    try {
      final results = await Future.wait([
        AnimalRepository().getAll(),
        CalfRepository().getAllCalves(),
        FeedRepository().getAllStocks(),
        EquipmentRepository().getAll(),
        StaffRepository().getAllStaff(),
        _loadFarmMembers(),
      ]);
      if (!mounted) return;
      setState(() {
        _animals = results[0] as List<AnimalModel>;
        _calves = results[1] as List<CalfModel>;
        _feedStocks = results[2] as List<FeedStockModel>;
        _equipments = results[3] as List<EquipmentModel>;
        _staff = results[4] as List<StaffModel>;
        _members = results[5] as List<FarmMember>;
        _loading = false;
      });
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<List<FarmMember>> _loadFarmMembers() async {
    final farmId = AuthService.instance.currentUser?.activeFarmId;
    if (farmId == null) return [];
    final stream = FarmMemberService.instance.streamMembers(farmId);
    return stream.first;
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onChanged(String q) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 200), () {
      setState(() {
        _query = q.trim().toLowerCase();
        if (_query.isEmpty) {
          _aResult = [];
          _cResult = [];
          _fResult = [];
          _eResult = [];
          _sResult = [];
          _mResult = [];
        } else {
          _aResult = _animals.where((a) =>
              (a.earTag.toLowerCase().contains(_query)) ||
              ((a.name ?? '').toLowerCase().contains(_query))).toList();
          _cResult = _calves.where((c) =>
              c.earTag.toLowerCase().contains(_query) ||
              (c.name ?? '').toLowerCase().contains(_query)).toList();
          _fResult = _feedStocks.where((f) =>
              f.name.toLowerCase().contains(_query)).toList();
          _eResult = _equipments.where((e) =>
              e.name.toLowerCase().contains(_query) ||
              (e.brand ?? '').toLowerCase().contains(_query)).toList();
          _sResult = _staff.where((s) =>
              s.name.toLowerCase().contains(_query) ||
              (s.phone ?? '').toLowerCase().contains(_query)).toList();
          _mResult = _members.where((m) =>
              m.displayName.toLowerCase().contains(_query) ||
              m.email.toLowerCase().contains(_query)).toList();
        }
      });
    });
  }

  int get _totalResults =>
      _aResult.length + _cResult.length + _fResult.length +
      _eResult.length + _sResult.length + _mResult.length;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: TextField(
          controller: _ctrl,
          autofocus: true,
          onChanged: _onChanged,
          cursorColor: Colors.white,
          style: const TextStyle(color: Colors.white, fontSize: 16),
          decoration: const InputDecoration(
            hintText: 'Hayvan, buzağı, yem, ekipman, personel ara...',
            hintStyle: TextStyle(color: Colors.white60, fontSize: 14),
            // AppTheme varsayılan olarak beyaz dolgulu input kullanıyor —
            // AppBar üzerinde görünmesi için dolguyu kapat ve sınırları kaldır.
            filled: false,
            border: InputBorder.none,
            enabledBorder: InputBorder.none,
            focusedBorder: InputBorder.none,
            disabledBorder: InputBorder.none,
            contentPadding: EdgeInsets.symmetric(vertical: 14),
            prefixIcon: Icon(Icons.search, color: Colors.white70),
          ),
        ),
        actions: [
          if (_ctrl.text.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.close, color: Colors.white),
              onPressed: () {
                _ctrl.clear();
                _onChanged('');
              },
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primaryGreen))
          : _query.isEmpty
              ? const _EmptyHint()
              : _totalResults == 0
                  ? const _NoResult()
                  : ListView(
                      padding: const EdgeInsets.all(12),
                      children: [
                        if (_aResult.isNotEmpty)
                          _Section(
                            icon: Icons.pets,
                            title: 'Hayvanlar (${_aResult.length})',
                            color: AppColors.primaryGreen,
                            children: _aResult.take(10).map((a) => _ResultTile(
                              title: a.earTag,
                              subtitle: [a.name, a.status, a.breed]
                                  .where((e) => e != null && e.isNotEmpty)
                                  .join(' · '),
                              icon: Icons.pets,
                              color: AppColors.primaryGreen,
                              onTap: () => Navigator.push(context, MaterialPageRoute(
                                  builder: (_) => AnimalDetailScreen(animal: a))),
                            )).toList(),
                          ),
                        if (_cResult.isNotEmpty)
                          _Section(
                            icon: Icons.child_care,
                            title: 'Buzağılar (${_cResult.length})',
                            color: AppColors.infoBlue,
                            children: _cResult.take(10).map((c) => _ResultTile(
                              title: c.earTag.isNotEmpty ? c.earTag : (c.name ?? 'Buzağı'),
                              subtitle: [c.name, c.gender, c.status]
                                  .where((e) => e != null && e.isNotEmpty)
                                  .join(' · '),
                              icon: Icons.child_care,
                              color: AppColors.infoBlue,
                            )).toList(),
                          ),
                        if (_fResult.isNotEmpty)
                          _Section(
                            icon: Icons.grass,
                            title: 'Yem Stoku (${_fResult.length})',
                            color: const Color(0xFF8D6E63),
                            children: _fResult.take(10).map((f) => _ResultTile(
                              title: f.name,
                              subtitle: '${f.type} · ${f.quantity} ${f.unit}',
                              icon: Icons.grass,
                              color: const Color(0xFF8D6E63),
                            )).toList(),
                          ),
                        if (_eResult.isNotEmpty)
                          _Section(
                            icon: Icons.build,
                            title: 'Ekipman (${_eResult.length})',
                            color: const Color(0xFF6A1B9A),
                            children: _eResult.take(10).map((e) => _ResultTile(
                              title: e.name,
                              subtitle: [e.brand, e.category]
                                  .where((x) => x != null && x.isNotEmpty)
                                  .join(' · '),
                              icon: Icons.build,
                              color: const Color(0xFF6A1B9A),
                            )).toList(),
                          ),
                        if (_mResult.isNotEmpty)
                          _Section(
                            icon: Icons.group,
                            title: 'Çiftlik Üyeleri (${_mResult.length})',
                            color: AppColors.gold,
                            children: _mResult.take(10).map((m) => _ResultTile(
                              title: m.displayName,
                              subtitle: '${m.roleLabel} · ${m.email}',
                              icon: Icons.person_outline,
                              color: AppColors.gold,
                            )).toList(),
                          ),
                        if (_sResult.isNotEmpty)
                          _Section(
                            icon: Icons.people_outline,
                            title: 'Personel Kayıtları (${_sResult.length})',
                            color: AppColors.infoBlue,
                            children: _sResult.take(10).map((s) => _ResultTile(
                              title: s.name,
                              subtitle: [s.role, s.phone]
                                  .where((e) => e != null && e.toString().isNotEmpty)
                                  .join(' · '),
                              icon: Icons.person_outline,
                              color: AppColors.infoBlue,
                            )).toList(),
                          ),
                      ],
                    ),
    );
  }
}

class _Section extends StatelessWidget {
  final IconData icon;
  final String title;
  final Color color;
  final List<Widget> children;
  const _Section({
    required this.icon,
    required this.title,
    required this.color,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 8),
          Text(title, style: TextStyle(
            fontSize: 13, fontWeight: FontWeight.w800, color: color,
          )),
        ]),
        const SizedBox(height: 8),
        ...children,
      ]),
    );
  }
}

class _ResultTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final VoidCallback? onTap;
  const _ResultTile({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border(left: BorderSide(color: color, width: 3)),
      ),
      child: ListTile(
        dense: true,
        leading: CircleAvatar(
          radius: 16,
          backgroundColor: color.withValues(alpha: 0.12),
          child: Icon(icon, color: color, size: 16),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
        subtitle: subtitle.isEmpty ? null : Text(subtitle,
            style: const TextStyle(fontSize: 11, color: AppColors.textGrey)),
        trailing: onTap != null ? const Icon(Icons.chevron_right, size: 18) : null,
        onTap: onTap,
      ),
    );
  }
}

class _EmptyHint extends StatelessWidget {
  const _EmptyHint();
  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(24),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.search, size: 56, color: AppColors.textGrey),
          SizedBox(height: 12),
          Text('Aramak için yazmaya başlayın',
              style: TextStyle(fontWeight: FontWeight.w700, color: AppColors.textDark)),
          SizedBox(height: 6),
          Text('Küpe numarası, isim, yem, ekipman veya personel',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: AppColors.textGrey)),
        ]),
      ),
    );
  }
}

class _NoResult extends StatelessWidget {
  const _NoResult();
  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(24),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.search_off, size: 56, color: AppColors.textGrey),
          SizedBox(height: 12),
          Text('Sonuç bulunamadı',
              style: TextStyle(fontWeight: FontWeight.w700, color: AppColors.textDark)),
        ]),
      ),
    );
  }
}
