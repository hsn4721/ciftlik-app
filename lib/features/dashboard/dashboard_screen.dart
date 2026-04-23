import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../../core/theme/app_theme.dart';
import '../../core/services/auth_service.dart';
import '../../core/services/backup_service.dart';
import '../../core/services/weather_service.dart';
import '../../data/repositories/animal_repository.dart';
import '../../data/repositories/milking_repository.dart';
import '../../data/repositories/finance_repository.dart';
import '../../data/repositories/health_repository.dart';
import '../../data/repositories/feed_repository.dart';
import '../../data/repositories/calf_repository.dart';
import '../herd/herd_screen.dart';
import '../herd/add_animal_screen.dart';
import '../milk/milk_screen.dart';
import '../health/health_screen.dart';
import '../finance/finance_screen.dart';
import '../feed/feed_screen.dart';
import '../calf/calf_screen.dart';
import '../staff/staff_screen.dart';
import '../equipment/equipment_screen.dart';
import '../subsidies/subsidies_screen.dart';
import 'settings_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int _currentIndex = 0;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySub;
  bool _wasOffline = false;

  final List<Widget> _screens = const [
    _HomeTab(),
    HerdScreen(),
    MilkScreen(),
    HealthScreen(),
    FinanceScreen(),
  ];

  @override
  void initState() {
    super.initState();
    _startConnectivityWatch();
  }

  @override
  void dispose() {
    _connectivitySub?.cancel();
    super.dispose();
  }

  void _startConnectivityWatch() {
    _connectivitySub = Connectivity().onConnectivityChanged.listen((results) {
      final isOnline = results.any((r) => r != ConnectivityResult.none);
      if (isOnline && _wasOffline) {
        _autoSync();
      }
      _wasOffline = !isOnline;
    });
  }

  Future<void> _autoSync() async {
    if (AuthService.instance.currentUser == null) return;
    final result = await BackupService.instance.backup();
    if (mounted && result.success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Row(children: [
            Icon(Icons.cloud_done_outlined, color: Colors.white, size: 16),
            SizedBox(width: 8),
            Text('Veriler buluta yedeklendi'),
          ]),
          backgroundColor: AppColors.primaryGreen,
          behavior: SnackBarBehavior.floating,
          duration: Duration(seconds: 3),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _currentIndex, children: _screens),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 8)],
        ),
        child: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: (i) => setState(() => _currentIndex = i),
          items: const [
            BottomNavigationBarItem(icon: Icon(Icons.home_outlined), activeIcon: Icon(Icons.home), label: 'Ana Sayfa'),
            BottomNavigationBarItem(icon: Icon(Icons.pets_outlined), activeIcon: Icon(Icons.pets), label: 'Sürü'),
            BottomNavigationBarItem(icon: Icon(Icons.water_drop_outlined), activeIcon: Icon(Icons.water_drop), label: 'Süt'),
            BottomNavigationBarItem(icon: Icon(Icons.favorite_outline), activeIcon: Icon(Icons.favorite), label: 'Sağlık'),
            BottomNavigationBarItem(icon: Icon(Icons.bar_chart_outlined), activeIcon: Icon(Icons.bar_chart), label: 'Finans'),
          ],
        ),
      ),
    );
  }
}

class _HomeTab extends StatefulWidget {
  const _HomeTab();

  @override
  State<_HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends State<_HomeTab> {
  final _animalRepo = AnimalRepository();
  final _milkRepo = MilkingRepository();
  final _financeRepo = FinanceRepository();
  final _healthRepo = HealthRepository();
  final _feedRepo = FeedRepository();
  final _calfRepo = CalfRepository();

  int _total = 0;
  int _calfCount = 0;
  int _milking = 0;
  int _pregnant = 0;
  double _todayMilk = 0;
  double _monthIncome = 0;
  int _upcomingVaccines = 0;
  int _upcomingBirths = 0;
  int _lowStockCount = 0;
  bool _isLoading = true;
  DateTime _now = DateTime.now();
  Timer? _clockTimer;

  WeatherModel? _weather;
  WeatherStatus _weatherStatus = WeatherStatus.loading;

  @override
  void initState() {
    super.initState();
    _loadStats();
    _loadWeather();
    _clockTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) setState(() => _now = DateTime.now());
    });
  }

  @override
  void dispose() {
    _clockTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadWeather() async {
    final result = await WeatherService.instance.getWeather();
    if (mounted) {
      setState(() {
        _weather = result.data;
        _weatherStatus = result.status;
      });
    }
  }

  Future<void> _loadStats() async {
    if (mounted) setState(() => _isLoading = true);
    try {
      final counts = await _animalRepo.getStatusCounts();
      final total = await _animalRepo.getTotalCount();
      final calves = await _calfRepo.getAllCalves();
      final todayMilk = await _milkRepo.getTodayTotal();
      final summary = await _financeRepo.getMonthSummary(DateTime.now().year, DateTime.now().month);
      final vaccines = await _healthRepo.getUpcomingVaccines(7);
      final births = await _calfRepo.getUpcomingBirths(7);
      final stocks = await _feedRepo.getAllStocks();
      if (mounted) {
        setState(() {
          _total = total;
          _calfCount = calves.length;
          _milking = counts['Sağımda'] ?? 0;
          _pregnant = counts['Gebe'] ?? 0;
          _todayMilk = todayMilk;
          _monthIncome = summary['income'] ?? 0;
          _upcomingVaccines = vaccines.length;
          _upcomingBirths = births.length;
          _lowStockCount = stocks.where((s) => s.isLow).length;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Veriler yüklenirken hata oluştu. Sayfayı aşağı çekerek yenileyin.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = AuthService.instance.currentUser;
    final name = user?.displayName.split(' ').first ?? 'Çiftlik Sahibi';
    final hour = _now.hour;
    final greeting = hour < 6
        ? 'İyi geceler'
        : hour < 12
            ? 'Günaydın'
            : hour < 18
                ? 'İyi günler'
                : hour < 21
                    ? 'İyi akşamlar'
                    : 'İyi geceler';
    final timeStr = '${hour.toString().padLeft(2, '0')}:${_now.minute.toString().padLeft(2, '0')}';
    final dateStr = '${_now.day.toString().padLeft(2, '0')}.${_now.month.toString().padLeft(2, '0')}.${_now.year}';

    return Scaffold(
      backgroundColor: AppColors.background,
      body: RefreshIndicator(
        color: AppColors.primaryGreen,
        onRefresh: _loadStats,
        child: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 160,
            floating: false,
            pinned: true,
            backgroundColor: AppColors.primaryGreen,
            actions: [
              IconButton(
                icon: const Icon(Icons.settings_outlined, color: Colors.white),
                onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsScreen())),
              ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [AppColors.primaryGreen, AppColors.mediumGreen],
                  ),
                ),
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('$greeting,', style: const TextStyle(color: Colors.white70, fontSize: 14)),
                                Text(name, style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w800)),
                              ],
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.2),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Row(children: [
                                    const Icon(Icons.access_time, color: Colors.white70, size: 12),
                                    const SizedBox(width: 4),
                                    Text(timeStr, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700)),
                                  ]),
                                ),
                                const SizedBox(height: 4),
                                Text(dateStr, style: const TextStyle(color: Colors.white60, fontSize: 11)),
                              ],
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _WeatherCard(weather: _weather, status: _weatherStatus, onRetry: _loadWeather),
                  const SizedBox(height: 20),
                  const Text('Bugün', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.textDark)),
                  const SizedBox(height: 12),
                  if (_isLoading)
                    const Center(child: Padding(
                      padding: EdgeInsets.symmetric(vertical: 32),
                      child: CircularProgressIndicator(color: AppColors.primaryGreen, strokeWidth: 2),
                    ))
                  else ...[
                  Row(children: [
                    Expanded(child: _StatCard(title: 'Toplam Sürü', value: '$_total Baş', icon: Icons.pets, color: AppColors.primaryGreen)),
                    const SizedBox(width: 12),
                    Expanded(child: _StatCard(title: 'Buzağı', value: '$_calfCount Baş', icon: Icons.baby_changing_station, color: const Color(0xFF6A1B9A))),
                  ]),
                  const SizedBox(height: 12),
                  Row(children: [
                    Expanded(child: _StatCard(title: 'Sağımda', value: '$_milking Baş', icon: Icons.water_drop_outlined, color: AppColors.infoBlue)),
                    const SizedBox(width: 12),
                    Expanded(child: _StatCard(title: 'Gebe', value: '$_pregnant Baş', icon: Icons.child_friendly, color: const Color(0xFF6A1B9A))),
                  ]),
                  const SizedBox(height: 12),
                  Row(children: [
                    Expanded(child: _StatCard(title: 'Bugün Süt', value: '${_todayMilk.toStringAsFixed(1)} L', icon: Icons.water_drop, color: AppColors.infoBlue)),
                    const SizedBox(width: 12),
                    Expanded(child: _StatCard(title: 'Bu Ay Gelir', value: '₺${NumberFormat('#,##0', 'tr_TR').format(_monthIncome)}', icon: Icons.trending_up, color: AppColors.gold)),
                  ]),
                  ],
                  const SizedBox(height: 24),

                  // Hatırlatıcılar
                  const Text('Hatırlatıcılar', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.textDark)),
                  const SizedBox(height: 12),
                  _ReminderCard(
                    icon: Icons.vaccines,
                    color: AppColors.errorRed,
                    title: 'Aşı Hatırlatıcısı',
                    subtitle: _upcomingVaccines > 0
                        ? '$_upcomingVaccines aşı 7 gün içinde yapılmalı!'
                        : '7 gün içinde yaklaşan aşı yok',
                    hasAlert: _upcomingVaccines > 0,
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const HealthScreen())),
                  ),
                  const SizedBox(height: 8),
                  _ReminderCard(
                    icon: Icons.child_friendly,
                    color: const Color(0xFF6A1B9A),
                    title: 'Yaklaşan Doğumlar',
                    subtitle: _upcomingBirths > 0
                        ? '$_upcomingBirths doğum 7 gün içinde bekleniyor!'
                        : '7 gün içinde doğum beklenen yok',
                    hasAlert: _upcomingBirths > 0,
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CalfScreen())),
                  ),
                  const SizedBox(height: 8),
                  _ReminderCard(
                    icon: Icons.inventory_2_outlined,
                    color: AppColors.infoBlue,
                    title: 'Stok Uyarısı',
                    subtitle: _lowStockCount > 0
                        ? '$_lowStockCount ürün kritik stok seviyesinde!'
                        : 'Kritik stok seviyesi yok',
                    hasAlert: _lowStockCount > 0,
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const FeedScreen())),
                  ),
                  const SizedBox(height: 8),
                  _ReminderCard(
                    icon: Icons.account_balance_outlined,
                    color: AppColors.gold,
                    title: 'Devlet Destekleri',
                    subtitle: 'Nisan — Şap Aşısı kampanyası aktif',
                    hasAlert: false,
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SubsidiesScreen())),
                  ),
                  const SizedBox(height: 24),

                  // Hızlı işlemler
                  const Text('Hızlı İşlem', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.textDark)),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(child: _QuickActionButton(
                        icon: Icons.water_drop,
                        label: 'Sağım\nGir',
                        color: AppColors.infoBlue,
                        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const MilkScreen())),
                      )),
                      const SizedBox(width: 10),
                      Expanded(child: _QuickActionButton(
                        icon: Icons.pets,
                        label: 'Hayvan\nEkle',
                        color: AppColors.primaryGreen,
                        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AddAnimalScreen())),
                      )),
                      const SizedBox(width: 10),
                      Expanded(child: _QuickActionButton(
                        icon: Icons.vaccines,
                        label: 'Aşı\nKaydet',
                        color: AppColors.errorRed,
                        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const HealthScreen())),
                      )),
                      const SizedBox(width: 10),
                      Expanded(child: _QuickActionButton(
                        icon: Icons.attach_money,
                        label: 'Finans',
                        color: AppColors.gold,
                        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const FinanceScreen())),
                      )),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Diğer Modüller
                  const Text('Diğer Modüller', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.textDark)),
                  const SizedBox(height: 12),
                  GridView.count(
                    crossAxisCount: 3,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 10,
                    childAspectRatio: 1.1,
                    children: [
                      _ModuleCard(icon: Icons.baby_changing_station, label: 'Buzağı &\nÜreme', color: const Color(0xFF6A1B9A),
                        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CalfScreen()))),
                      _ModuleCard(icon: Icons.grass, label: 'Yem\nYönetimi', color: const Color(0xFF558B2F),
                        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const FeedScreen()))),
                      _ModuleCard(icon: Icons.people_outline, label: 'Personel &\nGörevler', color: AppColors.infoBlue,
                        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const StaffScreen()))),
                      _ModuleCard(icon: Icons.build_outlined, label: 'Ekipman', color: const Color(0xFF37474F),
                        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const EquipmentScreen()))),
                      _ModuleCard(icon: Icons.account_balance, label: 'Devlet\nDestekleri', color: AppColors.gold,
                        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SubsidiesScreen()))),
                    ],
                  ),
                  const SizedBox(height: 32),

                  // Developer kredisi (ana sayfada minimal)
                  Center(
                    child: Text(
                      'ÇiftlikPRO · @hsnduz · © 2026',
                      style: TextStyle(fontSize: 11, color: AppColors.textGrey.withValues(alpha: 0.6)),
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            ),
          ),
        ],
      ),
      ), // RefreshIndicator
    );
  }
}

class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;
  const _StatCard({required this.title, required this.value, required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontSize: 11, color: AppColors.textGrey)),
                const SizedBox(height: 2),
                Text(value, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: AppColors.textDark)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ReminderCard extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final bool hasAlert;
  final VoidCallback? onTap;

  const _ReminderCard({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    this.hasAlert = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: hasAlert ? Border.all(color: color.withValues(alpha: 0.4)) : null,
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 6, offset: const Offset(0, 2))],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(8)),
              child: Icon(icon, color: color, size: 18),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textDark)),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(fontSize: 11, color: hasAlert ? color : AppColors.textGrey, fontWeight: hasAlert ? FontWeight.w600 : FontWeight.normal),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: AppColors.textGrey, size: 18),
          ],
        ),
      ),
    );
  }
}

class _ModuleCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _ModuleCard({required this.icon, required this.label, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 6, offset: const Offset(0, 2))],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(10)),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(height: 8),
            Text(label, textAlign: TextAlign.center, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: AppColors.textDark)),
          ],
        ),
      ),
    );
  }
}

class _QuickActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _QuickActionButton({required this.icon, required this.label, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 6, offset: const Offset(0, 2))],
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 6),
            Text(label, textAlign: TextAlign.center, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: AppColors.textDark)),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// WEATHER CARD
// ─────────────────────────────────────────────

class _WeatherCard extends StatelessWidget {
  final WeatherModel? weather;
  final WeatherStatus status;
  final VoidCallback onRetry;

  const _WeatherCard({required this.weather, required this.status, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    if (status == WeatherStatus.loading && weather == null) return _buildLoading();
    if (status == WeatherStatus.locationDenied) {
      return _buildMessage(Icons.location_off, 'Konum izni gerekli', 'Hava durumu için konum iznine ihtiyaç var');
    }
    if (status == WeatherStatus.locationDisabled) {
      return _buildMessage(Icons.location_disabled, 'Konum servisi kapalı', 'Cihazınızın konumunu açın');
    }
    if (weather == null) {
      return _buildMessage(Icons.wifi_off, 'Hava durumu alınamadı', 'İnternet bağlantınızı kontrol edin');
    }

    final w = weather!;
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: w.gradientColors, begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: w.gradientColors.first.withValues(alpha: 0.35), blurRadius: 14, offset: const Offset(0, 5))],
      ),
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 14),
      child: Row(
        children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                const Icon(Icons.location_on, color: Colors.white70, size: 12),
                const SizedBox(width: 3),
                Text(w.cityName, style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w500)),
              ]),
              const SizedBox(height: 10),
              Row(children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(10)),
                  child: Icon(w.icon, color: w.iconColor, size: 24),
                ),
                const SizedBox(width: 12),
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(w.description, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 4),
                  Row(children: [
                    const Icon(Icons.water_drop_outlined, color: Colors.white60, size: 11),
                    const SizedBox(width: 2),
                    Text('${w.humidity}%', style: const TextStyle(color: Colors.white60, fontSize: 11)),
                    const SizedBox(width: 10),
                    const Icon(Icons.air, color: Colors.white60, size: 11),
                    const SizedBox(width: 2),
                    Text('${w.windSpeed.toStringAsFixed(0)} km/s', style: const TextStyle(color: Colors.white60, fontSize: 11)),
                  ]),
                ]),
              ]),
            ]),
          ),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text(
              '${w.temperature.toStringAsFixed(0)}°',
              style: const TextStyle(color: Colors.white, fontSize: 52, fontWeight: FontWeight.w200, height: 1),
            ),
            const Text('C', style: TextStyle(color: Colors.white54, fontSize: 14)),
          ]),
        ],
      ),
    );
  }

  Widget _buildLoading() {
    return Container(
      height: 88,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 8)],
      ),
      child: const Center(
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primaryGreen)),
          SizedBox(width: 10),
          Text('Hava durumu yükleniyor...', style: TextStyle(color: AppColors.textGrey, fontSize: 13)),
        ]),
      ),
    );
  }

  Widget _buildMessage(IconData icon, String title, String subtitle) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 8)],
      ),
      child: Row(children: [
        Icon(icon, color: AppColors.textGrey, size: 26),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textDark)),
          Text(subtitle, style: const TextStyle(fontSize: 11, color: AppColors.textGrey)),
        ])),
        TextButton(
          onPressed: onRetry,
          style: TextButton.styleFrom(
            foregroundColor: AppColors.primaryGreen,
            minimumSize: Size.zero,
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          ),
          child: const Text('Yenile', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
        ),
      ]),
    );
  }
}
