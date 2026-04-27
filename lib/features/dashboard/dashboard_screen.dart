import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart' show SharedPreferences;
import '../../core/theme/app_theme.dart';
import '../../core/services/auth_service.dart';
import '../../core/services/backup_service.dart';
import '../../core/services/weather_service.dart';
import '../../core/services/notification_service.dart';
import '../../core/services/vet_request_service.dart';
import '../../core/services/invitation_service.dart';
import '../../core/services/notification_feed_service.dart';
import '../../core/services/farm_task_service.dart';
import '../../core/services/leave_request_service.dart';
import '../../shared/widgets/masked_amount.dart';
import '../../data/models/invitation_model.dart';
import '../../data/models/notification_item_model.dart';
import '../../core/constants/app_constants.dart';
import '../auth/farm_picker_screen.dart';
import '../../data/repositories/animal_repository.dart';
import '../../data/repositories/milking_repository.dart';
import '../../data/repositories/finance_repository.dart';
import '../../data/repositories/health_repository.dart';
import '../../data/repositories/feed_repository.dart';
import '../../data/repositories/calf_repository.dart';
import '../auth/login_screen.dart';
import '../herd/herd_screen.dart';
import '../vet_request/vet_request_form_screen.dart';
import '../herd/add_animal_screen.dart';
import '../milk/milk_screen.dart';
import '../health/health_screen.dart';
import '../finance/finance_screen.dart';
import '../feed/feed_screen.dart';
import '../calf/calf_screen.dart';
import '../staff/staff_screen.dart';
import '../equipment/equipment_screen.dart';
import '../subsidies/subsidies_screen.dart';
import '../search/global_search_screen.dart';
import 'widgets/farm_health_score.dart';
import 'widgets/herd_distribution_pie.dart';
import 'widgets/daily_status_badge.dart';
import 'widgets/weekly_summary_card.dart';
import 'settings_screen.dart';
import '../../core/subscription/feature_gate.dart';
import '../../core/subscription/subscription_service.dart';
import '../subscription/paywall_screen.dart';
import '../notifications/notification_bell_button.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int _currentIndex = 0;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySub;
  StreamSubscription? _userSub;
  StreamSubscription? _vetReqSub;
  StreamSubscription? _inviteSub;
  StreamSubscription? _taskAssignedSub;
  StreamSubscription? _taskCompletedSub;
  StreamSubscription? _leaveRequestSub;
  StreamSubscription? _leaveResponseSub;
  final Set<String> _notifiedReqIds = {};
  bool _wasOffline = false;

  /// Role göre filtrelenmiş bottom nav yapısı
  List<_NavEntry> _navEntries() {
    final user = AuthService.instance.currentUser;
    final entries = <_NavEntry>[
      _NavEntry(
        label: 'Ana Sayfa',
        icon: Icons.home_outlined,
        activeIcon: Icons.home,
        screen: const _HomeTab(),
        visible: true,
      ),
      _NavEntry(
        label: 'Sürü',
        icon: Icons.pets_outlined,
        activeIcon: Icons.pets,
        screen: const HerdScreen(),
        visible: user?.canSeeHerd ?? true,
      ),
      _NavEntry(
        label: 'Süt',
        icon: Icons.water_drop_outlined,
        activeIcon: Icons.water_drop,
        screen: const MilkScreen(),
        visible: user?.canSeeMilk ?? true,
      ),
      _NavEntry(
        label: 'Sağlık',
        icon: Icons.favorite_outline,
        activeIcon: Icons.favorite,
        screen: const HealthScreen(),
        visible: user?.canSeeHealth ?? true,
      ),
      _NavEntry(
        label: 'Finans',
        icon: Icons.bar_chart_outlined,
        activeIcon: Icons.bar_chart,
        screen: const FinanceScreen(),
        visible: user?.canSeeFinance ?? true,
      ),
    ];
    return entries.where((e) => e.visible).toList();
  }

  @override
  void initState() {
    super.initState();
    _startConnectivityWatch();
    _watchCurrentUser();
    _watchVetRequests();
    _watchRequesterReads();
    _watchInvitationResponses();
    _watchTaskAssignments();
    _watchTaskCompletions();
    _watchLeaveRequests();
    _watchLeaveResponses();
  }

  @override
  void dispose() {
    _connectivitySub?.cancel();
    _userSub?.cancel();
    _vetReqSub?.cancel();
    _inviteSub?.cancel();
    _taskAssignedSub?.cancel();
    _taskCompletedSub?.cancel();
    _leaveRequestSub?.cancel();
    _leaveResponseSub?.cancel();
    super.dispose();
  }

  /// Bildirim dedup için persistent skip-set — uygulama kapanıp açılsa bile
  /// aynı bildirim tekrar push olarak gönderilmez.
  Future<void> _markPushSent(String key) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final existing = prefs.getStringList('push_sent_ids') ?? [];
      if (!existing.contains(key)) {
        existing.add(key);
        // Listeyi son 500 ile sınırla
        final trimmed = existing.length > 500
            ? existing.sublist(existing.length - 500) : existing;
        await prefs.setStringList('push_sent_ids', trimmed);
      }
    } catch (_) {}
  }

  Future<bool> _wasPushSent(String key) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final existing = prefs.getStringList('push_sent_ids') ?? [];
      return existing.contains(key);
    } catch (_) {
      return false;
    }
  }

  /// Vet rolü için: yeni okunmamış talep gelince yerel bildirim göster.
  /// Persistent dedup — aynı talep için uygulama kapanıp açılsa bile tekrar push yok.
  void _watchVetRequests() {
    final user = AuthService.instance.currentUser;
    if (user == null || !user.isVet) return;
    _vetReqSub = VetRequestService.instance
        .streamAllForVet(user.uid)
        .listen((items) async {
      for (final r in items) {
        if (r.id == null || r.isRead) continue;
        final key = 'vet_req_${r.id}';
        if (_notifiedReqIds.contains(key)) continue;
        if (await _wasPushSent(key)) {
          _notifiedReqIds.add(key);
          continue;
        }
        _notifiedReqIds.add(key);
        await _markPushSent(key);
        NotificationService.instance.showVetRequestAlert(
          farmName: r.farmName,
          requesterName: r.requesterName,
          category: r.categoryLabel,
          urgency: r.urgencyLabel,
          notifId: r.id.hashCode.abs() % 1000000,
        );
      }
    });
  }

  /// Owner/Assistant: kendi gönderdikleri davetlerin cevaplarını dinler.
  /// Vet davet kabul ederse "X kabul etti" bildirimi, reddederse "X reddetti".
  /// Persistent dedup.
  void _watchInvitationResponses() {
    final user = AuthService.instance.currentUser;
    if (user == null || !user.canManageUsers) return;

    _inviteSub = FirebaseFirestore.instance
        .collection('invitations')
        .where('invitedBy', isEqualTo: user.uid)
        .snapshots()
        .listen((snap) async {
      for (final doc in snap.docs) {
        final data = doc.data();
        final status = (data['status'] as String?) ?? 'pending';
        final id = doc.id;
        if (status != 'accepted' && status != 'rejected') continue;
        // Persistent dedup key
        final key = 'invite_${id}_$status';
        if (await _wasPushSent(key)) continue;
        await _markPushSent(key);

        final email = (data['email'] as String?) ?? '';
        final farmName = (data['farmName'] as String?) ?? '';
        final farmId = (data['farmId'] as String?) ?? '';
        final role = (data['role'] as String?) ?? '';
        final responderName = (data['responderName'] as String?) ?? '';
        final accepted = status == 'accepted';

        // 1) Push bildirim (device)
        NotificationService.instance.showInvitationResponse(
          inviteeName: responderName,
          inviteeEmail: email,
          farmName: farmName,
          accepted: accepted,
          notifId: id.hashCode.abs() % 1000000,
        );

        // 2) Çiftlik-içi bildirim paneline de yaz (owner/assistant feed'inde kalsın)
        if (farmId.isNotEmpty) {
          try {
            // Target: owner + assistant'lar (hasFullControl olanlar)
            final members = await FirebaseFirestore.instance
                .collection('farms').doc(farmId).collection('members')
                .where('role', whereIn: ['owner', 'assistant', 'partner'])
                .where('isActive', isEqualTo: true)
                .get();
            final targetUids = members.docs
                .map((d) => (d.data()['uid'] ?? d.id).toString())
                .toList();
            if (targetUids.isEmpty) continue;

            final roleLabel = AppConstants.roleLabels[role] ?? role;
            final displayName = responderName.isNotEmpty ? responderName : email;
            await NotificationFeedService.instance.create(
              NotificationItemModel(
                farmId: farmId,
                type: accepted
                    ? NotificationType.invitationAccepted
                    : NotificationType.invitationRejected,
                title: accepted ? 'Davet Kabul Edildi' : 'Davet Reddedildi',
                body: accepted
                    ? '$displayName "$roleLabel" olarak çiftliğinize katıldı'
                    : '$displayName "$roleLabel" davetinizi reddetti',
                targetUids: targetUids,
                readByUids: const [],
                createdAt: DateTime.now(),
                relatedRef: 'invitations/$id',
              ),
            );
          } catch (e) {
            debugPrint('[dashboard invitation notif write] $e');
          }
        }
      }
    }, onError: (e) => debugPrint('[dashboard invitation watch] $e'));
  }

  /// Requester rolü için: talep okunduğunda requester'a "Okundu" bildirimi göster.
  /// Persistent dedup.
  void _watchRequesterReads() {
    final user = AuthService.instance.currentUser;
    if (user == null || !user.hasFullControl) return;
    if (user.activeFarmId == null) return;
    _vetReqSub = VetRequestService.instance
        .streamMyRequests(farmId: user.activeFarmId!, requesterId: user.uid)
        .listen((items) async {
      for (final r in items) {
        if (r.id == null || !r.isRead) continue;
        final key = 'vet_read_${r.id}';
        if (await _wasPushSent(key)) continue;
        await _markPushSent(key);
        NotificationService.instance.showVetReadReceipt(
          vetName: r.vetName,
          category: r.categoryLabel,
          notifId: r.id.hashCode.abs() % 1000000,
        );
      }
    });
  }

  /// Worker/Assistant için: kendisine atanan görev geldiğinde push bildirim.
  /// Persistent dedup — uygulama kapanıp açılsa bile aynı görev tekrar push olmaz.
  void _watchTaskAssignments() {
    final user = AuthService.instance.currentUser;
    if (user == null || user.activeFarmId == null) return;
    if (!user.canReceiveTasks && !user.isAssistant) return;
    _taskAssignedSub = FarmTaskService.instance
        .streamForStaff(farmId: user.activeFarmId!, staffUid: user.uid)
        .listen((tasks) async {
      for (final t in tasks) {
        if (t.id == null) continue;
        // Yalnızca henüz aktif (tamamlanmamış) görevler için bildir
        if (t.isCompleted || t.isCancelled) continue;
        final key = 'task_assigned_${t.id}';
        if (await _wasPushSent(key)) continue;
        await _markPushSent(key);
        NotificationService.instance.showTaskAssigned(
          taskTitle: t.title,
          assignedByName: t.assignedByName,
          priorityLabel: t.priorityLabel,
          dueDate: t.dueDate,
          notifId: t.id!.hashCode.abs() % 1000000,
        );
      }
    }, onError: (e) => debugPrint('[dashboard task assignment watch] $e'));
  }

  /// Owner/Assistant için: çiftlikteki bir görev tamamlandığında push + panel bildirimi.
  /// Atayan kişi kendisi tamamlamış olsa push gönderilmez (self-action dedup).
  void _watchTaskCompletions() {
    final user = AuthService.instance.currentUser;
    if (user == null || user.activeFarmId == null) return;
    if (!user.hasFullControl) return;
    _taskCompletedSub = FarmTaskService.instance
        .streamAllForFarm(user.activeFarmId!)
        .listen((tasks) async {
      for (final t in tasks) {
        if (t.id == null || !t.isCompleted) continue;
        // Bu kullanıcı kendisi tamamlamışsa (atayan + yapan aynı) bildirim yok
        if (t.assignedToUid == user.uid) continue;
        final key = 'task_completed_${t.id}';
        if (await _wasPushSent(key)) continue;
        await _markPushSent(key);
        NotificationService.instance.showTaskCompleted(
          taskTitle: t.title,
          completedByName: t.assignedToName,
          completionNote: t.completionNote,
          notifId: t.id!.hashCode.abs() % 1000000,
        );

        // Çiftlik-içi feed'e yaz
        if (t.farmId.isEmpty) continue;
        try {
          final managers = await FirebaseFirestore.instance
              .collection('farms').doc(t.farmId).collection('members')
              .where('role', whereIn: ['owner', 'assistant', 'partner'])
              .where('isActive', isEqualTo: true)
              .get();
          final targetUids = managers.docs
              .map((d) => (d.data()['uid'] ?? d.id).toString())
              .where((u) => u != t.assignedToUid)
              .toList();
          if (targetUids.isEmpty) continue;
          await NotificationFeedService.instance.create(
            NotificationItemModel(
              farmId: t.farmId,
              type: NotificationType.activity,
              title: '${t.assignedToName} görev tamamladı',
              body: t.title,
              targetUids: targetUids,
              readByUids: const [],
              createdAt: DateTime.now(),
              relatedRef: 'tasks/${t.id}',
              meta: {
                'actionType': 'task_completed',
                'actorUid': t.assignedToUid,
                if (t.completionNote != null) 'completionNote': t.completionNote,
              },
            ),
          );
        } catch (e) {
          debugPrint('[dashboard task completion feed] $e');
        }
      }
    }, onError: (e) => debugPrint('[dashboard task completion watch] $e'));
  }

  /// Owner/Assistant için: yeni izin talebi geldiğinde push + panel bildirimi.
  void _watchLeaveRequests() {
    final user = AuthService.instance.currentUser;
    if (user == null || user.activeFarmId == null) return;
    if (!user.hasFullControl) return;
    _leaveRequestSub = LeaveRequestService.instance
        .streamAllForFarm(user.activeFarmId!)
        .listen((list) async {
      for (final l in list) {
        if (l.id == null || !l.isPending) continue;
        final key = 'leave_request_${l.id}';
        if (await _wasPushSent(key)) continue;
        await _markPushSent(key);
        NotificationService.instance.showLeaveRequested(
          staffName: l.staffName,
          reason: l.reason,
          dayCount: l.dayCount,
          notifId: l.id!.hashCode.abs() % 1000000,
        );

        if (l.farmId.isEmpty) continue;
        try {
          final managers = await FirebaseFirestore.instance
              .collection('farms').doc(l.farmId).collection('members')
              .where('role', whereIn: ['owner', 'assistant', 'partner'])
              .where('isActive', isEqualTo: true)
              .get();
          final targetUids = managers.docs
              .map((d) => (d.data()['uid'] ?? d.id).toString())
              .where((u) => u != l.staffUid)
              .toList();
          if (targetUids.isEmpty) continue;
          await NotificationFeedService.instance.create(
            NotificationItemModel(
              farmId: l.farmId,
              type: NotificationType.activity,
              title: '${l.staffName} izin talebinde bulundu',
              body: '${l.reason} · ${l.dayCount} gün',
              targetUids: targetUids,
              readByUids: const [],
              createdAt: DateTime.now(),
              relatedRef: 'leave_requests/${l.id}',
              meta: {
                'actionType': 'leave_requested',
                'actorUid': l.staffUid,
              },
            ),
          );
        } catch (e) {
          debugPrint('[dashboard leave request feed] $e');
        }
      }
    }, onError: (e) => debugPrint('[dashboard leave request watch] $e'));
  }

  /// Worker/Vet için: kendi izin talebine cevap geldiğinde push bildirim.
  void _watchLeaveResponses() {
    final user = AuthService.instance.currentUser;
    if (user == null || user.activeFarmId == null) return;
    if (!user.canRequestLeave) return;
    _leaveResponseSub = LeaveRequestService.instance
        .streamForStaff(farmId: user.activeFarmId!, staffUid: user.uid)
        .listen((list) async {
      for (final l in list) {
        if (l.id == null || l.isPending) continue;
        final key = 'leave_response_${l.id}_${l.status}';
        if (await _wasPushSent(key)) continue;
        await _markPushSent(key);
        NotificationService.instance.showLeaveResponse(
          reason: l.reason,
          approved: l.isApproved,
          responderName: l.respondedByName ?? '',
          responseNote: l.responseNote,
          notifId: l.id!.hashCode.abs() % 1000000,
        );
      }
    }, onError: (e) => debugPrint('[dashboard leave response watch] $e'));
  }

  /// Kullanıcı bilgisini canlı izler.
  /// Ana Sahip tarafından silindi / devre dışı bırakıldıysa AuthService zorla
  /// sign out eder ve `currentUser = null` olur — burası yakalar ve login ekranına döndürür.
  void _watchCurrentUser() {
    _userSub = AuthService.instance.userStream.listen((user) {
      if (!mounted) return;
      if (user == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Oturum sonlandı — hesabınızda değişiklik yapıldı'),
            backgroundColor: AppColors.errorRed,
            duration: Duration(seconds: 4),
          ),
        );
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const LoginScreen()),
          (_) => false,
        );
      } else {
        // Rol değişmiş olabilir — UI'nin yeniden çizilmesi için setState
        setState(() {});
      }
    });
  }

  void _startConnectivityWatch() {
    _connectivitySub = Connectivity().onConnectivityChanged.listen((results) {
      final isOnline = results.any((r) => r != ConnectivityResult.none);
      if (!isOnline && !_wasOffline && mounted) {
        // Yeni offline duruma geçti — kullanıcıya görsel bildirim
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(children: [
              Icon(Icons.cloud_off, color: Colors.white, size: 16),
              SizedBox(width: 8),
              Expanded(child: Text(
                'İnternet bağlantısı yok — değişiklikler bağlantı geri gelince '
                'otomatik senkronlanacak',
              )),
            ]),
            backgroundColor: AppColors.errorRed,
            behavior: SnackBarBehavior.floating,
            duration: Duration(seconds: 4),
          ),
        );
      }
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
    final entries = _navEntries();
    final safeIndex = _currentIndex.clamp(0, entries.length - 1);
    final user = AuthService.instance.currentUser;

    // Aktif çiftlik değişince tüm alt ekranlar yeniden oluşsun diye KeyedSubtree
    final farmKey = user?.activeFarmId ?? 'none';

    return Scaffold(
      body: Column(
        children: [
          if (user != null && user.isReadOnlyViewer) const _ReadOnlyBanner(),
          Expanded(
            child: IndexedStack(
              index: safeIndex,
              children: entries.map((e) => KeyedSubtree(
                key: ValueKey('${farmKey}_${e.label}'),
                child: e.screen,
              )).toList(),
            ),
          ),
        ],
      ),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 8)],
        ),
        child: BottomNavigationBar(
          currentIndex: safeIndex,
          type: BottomNavigationBarType.fixed,
          onTap: (i) => setState(() => _currentIndex = i),
          items: entries.map((e) => BottomNavigationBarItem(
            icon: Icon(e.icon),
            activeIcon: Icon(e.activeIcon),
            label: e.label,
          )).toList(),
        ),
      ),
    );
  }
}

class _NavEntry {
  final String label;
  final IconData icon;
  final IconData activeIcon;
  final Widget screen;
  final bool visible;
  const _NavEntry({
    required this.label,
    required this.icon,
    required this.activeIcon,
    required this.screen,
    required this.visible,
  });
}

/// Ortak rolü için uygulamanın üstünde sabit salt-okunur göstergesi.
class _ReadOnlyBanner extends StatelessWidget {
  const _ReadOnlyBanner();

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.infoBlue.withValues(alpha: 0.12),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: Row(children: const [
            Icon(Icons.visibility_outlined, color: AppColors.infoBlue, size: 16),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'Salt-okunur mod — Ortak olarak giriş yaptınız. Kayıt ekleme/düzenleme/silme yetkiniz yok.',
                style: TextStyle(fontSize: 11, color: AppColors.infoBlue, fontWeight: FontWeight.w700),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}

/// İçinde bulunulan aya göre devlet destekleri hakkında kısa bilgi metni.
/// Türkiye tarım destekleri takvimine göre yaygın dönemsel başlıklar.
String _currentMonthSubsidyHint() {
  final month = DateTime.now().month;
  switch (month) {
    case 1:  return 'Ocak — Yem bitkileri destek başvuruları';
    case 2:  return 'Şubat — Süt teşvik primi dönemi';
    case 3:  return 'Mart — Buzağı ve suni tohumlama desteği';
    case 4:  return 'Nisan — Şap Aşısı kampanyası aktif';
    case 5:  return 'Mayıs — Hayvan başı doğrudan destek';
    case 6:  return 'Haziran — Silaj bitkileri teşviki';
    case 7:  return 'Temmuz — Yurtiçi damızlık desteği';
    case 8:  return 'Ağustos — Anaç sığır desteği';
    case 9:  return 'Eylül — Süt üretim teşvik primi (2. dönem)';
    case 10: return 'Ekim — Bitkisel üretim destekleri';
    case 11: return 'Kasım — Sertifikalı tohum kullanım desteği';
    case 12: return 'Aralık — Yıl sonu ödeme dönemi';
    default: return 'Aktif destekleri incele';
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
  String? _farmName;

  @override
  void initState() {
    super.initState();
    _loadStats();
    _loadWeather();
    _loadFarmName();
    _clockTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) setState(() => _now = DateTime.now());
    });
    // Trial bitiş bildirimi — SubscriptionService listener'ı
    SubscriptionService.instance.trialExpiredAt.addListener(_onTrialExpired);
    // Eğer ekran açılırken zaten trial bitmiş ise hemen göster
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (SubscriptionService.instance.trialExpiredAt.value != null) {
        _onTrialExpired();
      }
    });
  }

  @override
  void dispose() {
    _clockTimer?.cancel();
    SubscriptionService.instance.trialExpiredAt.removeListener(_onTrialExpired);
    super.dispose();
  }

  bool _trialDialogShown = false;
  void _onTrialExpired() {
    if (!mounted || _trialDialogShown) return;
    if (SubscriptionService.instance.trialExpiredAt.value == null) return;
    _trialDialogShown = true;
    final user = AuthService.instance.currentUser;
    final canBuy = user?.hasFullControl ?? false;
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        icon: const Icon(Icons.hourglass_disabled, color: AppColors.gold, size: 40),
        title: const Text('14 Günlük Deneme Sona Erdi',
            textAlign: TextAlign.center,
            style: TextStyle(fontWeight: FontWeight.w800)),
        content: Text(
          canBuy
              ? 'ÇiftlikPRO\'nun tüm özelliklerine erişimini sürdürmek için bir paket seçin. '
                  'Verileriniz güvende — istediğiniz an Aile veya Pro paketine geçebilirsiniz.'
              : 'Çiftliğin deneme süresi sona erdi. Çiftlik sahibinden paketi yükseltmesini isteyin.',
          style: const TextStyle(fontSize: 13, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Daha Sonra'),
          ),
          if (canBuy)
            ElevatedButton(
              onPressed: () {
                Navigator.pop(ctx);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const PaywallScreen(
                      featureName: '14 Günlük Deneme Sona Erdi',
                      reason: 'Aile veya Pro paketle çiftliğinin tüm özelliklerine erişmeye devam et.',
                    ),
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryGreen,
                foregroundColor: Colors.white,
              ),
              child: const Text('Paketleri Gör'),
            ),
        ],
      ),
    );
  }

  /// Çiftlik sağlık skoru — 0-100.
  /// Hasta hayvan, eksik aşı, geciken doğum, düşük stok metrikleri etkiler.
  int _calculateHealthScore() {
    int score = 100;
    // Bekleyen aşılar: her eksik aşı -5 (max -25)
    score -= (_upcomingVaccines.clamp(0, 5)) * 5;
    // Düşük stoklar: her düşük stok -6 (max -24)
    score -= (_lowStockCount.clamp(0, 4)) * 6;
    // Yaklaşan doğum uyarı değil — skora etkisiz
    // Toplam sürü 0 ise skoru nötr bırak
    if (_total == 0) score = 80;
    return score.clamp(0, 100);
  }

  Future<void> _confirmLeaveFarmFromDashboard(BuildContext context, user) async {
    final membership = user.activeMembership;
    if (membership == null) return;

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(children: [
          Icon(Icons.warning_amber_rounded, color: AppColors.errorRed),
          SizedBox(width: 10),
          Expanded(child: Text('Çiftlikten Ayrıl')),
        ]),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '"${membership.farmName}" çiftliğinin üyeliğinden çıkmak üzeresiniz.',
              style: const TextStyle(fontSize: 13, height: 1.5),
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.gold.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Icon(Icons.info_outline, color: AppColors.gold, size: 16),
                SizedBox(width: 8),
                Expanded(child: Text(
                  'Bu işlem sonrası bu çiftliğin verilerine erişemezsiniz. '
                  'Yeniden üye olmanız için Ana Sahip\'in sizi tekrar davet etmesi gerekir.',
                  style: TextStyle(fontSize: 11, height: 1.4),
                )),
              ]),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('İptal')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.errorRed),
            child: const Text('Ayrıl'),
          ),
        ],
      ),
    );

    if (ok != true) return;

    final err = await AuthService.instance.leaveFarm(membership.farmId);
    if (!mounted) return;
    if (err != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(err), backgroundColor: AppColors.errorRed),
      );
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('"${membership.farmName}" çiftliğinden ayrıldınız'),
        backgroundColor: AppColors.primaryGreen,
      ),
    );
    // Her durumda vet için FarmPicker'a dönüş
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const FarmPickerScreen()),
      (_) => false,
    );
  }

  void _showFarmSwitcher(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      isScrollControlled: true,
      builder: (_) => const _FarmSwitcherSheet(),
    );
  }

  Future<void> _loadFarmName() async {
    final user = AuthService.instance.currentUser;
    if (user == null) return;
    final farmId = user.activeFarmId;
    // Vet yeni kayıt sonrası veya henüz çiftliğe katılmamış kullanıcılarda
    // activeFarmId boş olabilir — Firestore .doc('') throw eder, koru.
    if (farmId == null || farmId.isEmpty) return;

    // Önce önbellekten oku — offline durumda bile adı göster
    final prefs = await SharedPreferences.getInstance();
    final cached = prefs.getString('farmName_$farmId');
    if (cached != null && cached.isNotEmpty && mounted) {
      setState(() => _farmName = cached);
    }

    // Sonra buluttan tazele
    try {
      final doc = await FirebaseFirestore.instance.collection('farms').doc(farmId).get();
      final name = doc.data()?['name'] as String?;
      if (name != null && name.isNotEmpty) {
        await prefs.setString('farmName_$farmId', name);
        if (mounted) setState(() => _farmName = name);
      }
    } catch (e) {
      debugPrint('[HomeTab._loadFarmName] $e');
    }
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
      final user = AuthService.instance.currentUser;
      // RBAC: Veteriner ve diğer roller farklı veri kümelerine erişir.
      // Yetkisiz Firestore çağrıları (finance/feed/staff) hem permission-denied
      // log'una neden olur hem de gereksiz read maliyeti yaratır — koşullu yükle.
      final canReadAnimals = user?.canSeeHerd ?? false;
      final canReadCalves = user?.canSeeCalves ?? false;
      final canReadMilk = user?.canSeeMilk ?? false;
      final canReadFinance = user?.canSeeFinance ?? false;
      final canReadHealth = user?.canSeeHealth ?? false;
      final canReadFeed = user?.canSeeFeed ?? false;

      final counts = canReadAnimals ? await _animalRepo.getStatusCounts() : <String, int>{};
      final total = canReadAnimals ? await _animalRepo.getTotalCount() : 0;
      final calves = canReadCalves ? await _calfRepo.getAllCalves() : const [];
      final todayMilk = canReadMilk ? await _milkRepo.getTodayTotal() : 0.0;
      final summary = canReadFinance
          ? await _financeRepo.getMonthSummary(DateTime.now().year, DateTime.now().month)
          : <String, double>{};
      final vaccines = canReadHealth ? await _healthRepo.getUpcomingVaccines(7) : const [];
      final births = canReadCalves ? await _calfRepo.getUpcomingBirths(7) : const [];
      final stocks = canReadFeed ? await _feedRepo.getAllStocks() : const [];
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
    } catch (e, st) {
      debugPrint('[HomeTab._loadStats] $e\n$st');
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
            expandedHeight: 190,
            floating: false,
            pinned: true,
            backgroundColor: AppColors.primaryGreen,
            // Vet için farklı AppBar: settings gear YOK,
            // sol üstte "Ana Sayfam" (FarmPicker'a dönüş) ve sağda "Bu Çiftlikten Ayrıl"
            leading: Builder(builder: (_) {
              final u = AuthService.instance.currentUser;
              if (u != null && u.isVet) {
                return IconButton(
                  icon: const Icon(Icons.arrow_back, color: Colors.white),
                  tooltip: 'Ana Sayfam',
                  onPressed: () => Navigator.pushAndRemoveUntil(
                    context,
                    MaterialPageRoute(builder: (_) => const FarmPickerScreen()),
                    (_) => false,
                  ),
                );
              }
              return const SizedBox.shrink();
            }),
            actions: [
              Builder(builder: (_) {
                final u = AuthService.instance.currentUser;
                if (u == null) return const SizedBox.shrink();

                // Veteriner: Arama + Bildirim Zili + "Bu Çiftlikten Ayrıl"
                if (u.isVet) {
                  return Row(children: [
                    IconButton(
                      icon: const Icon(Icons.search, color: Colors.white),
                      tooltip: 'Arama',
                      onPressed: () => Navigator.push(context,
                          MaterialPageRoute(builder: (_) => const GlobalSearchScreen())),
                    ),
                    const NotificationBellButton(vetPanel: true),
                    IconButton(
                      icon: const Icon(Icons.logout, color: Colors.white),
                      tooltip: 'Bu Çiftlikten Ayrıl',
                      onPressed: () => _confirmLeaveFarmFromDashboard(context, u),
                    ),
                  ]);
                }

                // Worker/Partner/Owner/Assistant: Arama + Bildirim Zili + Ana Sayfam (opsiyonel) + Settings
                return Row(children: [
                  IconButton(
                    icon: const Icon(Icons.search, color: Colors.white),
                    tooltip: 'Arama',
                    onPressed: () => Navigator.push(context,
                        MaterialPageRoute(builder: (_) => const GlobalSearchScreen())),
                  ),
                  const NotificationBellButton(),
                  if (!u.isMainOwner)
                    IconButton(
                      icon: const Icon(Icons.home_outlined, color: Colors.white),
                      tooltip: 'Çiftlikler / Ana Sayfam',
                      onPressed: () => Navigator.push(context,
                          MaterialPageRoute(builder: (_) => const FarmPickerScreen())),
                    ),
                  IconButton(
                    icon: const Icon(Icons.settings_outlined, color: Colors.white),
                    onPressed: () => Navigator.push(context,
                        MaterialPageRoute(builder: (_) => const SettingsScreen())),
                  ),
                ]);
              }),
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
                    padding: const EdgeInsets.fromLTRB(20, 14, 20, 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        // Çiftlik adı — en üstte, çoklu-çiftlik varsa tıklanabilir
                        GestureDetector(
                          onTap: () {
                            final u = AuthService.instance.currentUser;
                            if (u != null && u.hasMultipleFarms) {
                              _showFarmSwitcher(context);
                            }
                          },
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.18),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Icon(Icons.agriculture, color: Colors.white, size: 16),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  _farmName ?? 'Çiftliğim',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 18,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 0.3,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              Builder(builder: (_) {
                                final u = AuthService.instance.currentUser;
                                if (u == null || !u.hasMultipleFarms) return const SizedBox.shrink();
                                return Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.2),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: const Icon(Icons.swap_horiz, color: Colors.white, size: 16),
                                );
                              }),
                            ],
                          ),
                        ),
                        const SizedBox(height: 14),
                        // Selamlama + saat
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('$greeting,', style: const TextStyle(color: Colors.white70, fontSize: 13)),
                                  Text(
                                    name,
                                    style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w800),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 12),
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
                  const SizedBox(height: 16),

                  // Bekleyen çiftlik davetleri banner (herkes için)
                  Builder(builder: (_) {
                    final u = AuthService.instance.currentUser;
                    if (u == null) return const SizedBox.shrink();
                    return StreamBuilder<List<InvitationModel>>(
                      stream: InvitationService.instance.streamPendingForEmail(u.email),
                      builder: (_, snap) {
                        final pending = snap.data ?? const [];
                        if (pending.isEmpty) return const SizedBox.shrink();
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 16),
                          child: _InvitationBanner(
                            count: pending.length,
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => const FarmPickerScreen()),
                            ),
                          ),
                        );
                      },
                    );
                  }),

                  // Vet talepleri artık vet'in ana sayfasında (FarmPicker) — banner burada YOK.
                  // Yine de push bildirim dinleyicisi (_watchVetRequests) çalışmaya devam eder.

                  // Owner/Assistant için: Çiftlik-içi bildirim paneli
                  // (davet cevapları, vet read receipts, aktiviteler)
                  Builder(builder: (_) {
                    final u = AuthService.instance.currentUser;
                    if (u == null || !u.hasFullControl) return const SizedBox.shrink();
                    if (u.activeFarmId == null) return const SizedBox.shrink();
                    return StreamBuilder<List<NotificationItemModel>>(
                      stream: NotificationFeedService.instance
                          .streamForUser(farmId: u.activeFarmId!, uid: u.uid),
                      builder: (_, snap) {
                        final all = snap.data ?? const [];
                        final unread = all.where((n) => !n.isReadBy(u.uid)).toList();
                        if (unread.isEmpty) return const SizedBox.shrink();
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 16),
                          child: _NotificationFeedPanel(
                            unread: unread,
                            onMarkRead: (id) async {
                              await NotificationFeedService.instance.markAsRead(
                                farmId: u.activeFarmId!, notifId: id, uid: u.uid);
                            },
                            onMarkAllRead: () async {
                              await NotificationFeedService.instance.markAllAsRead(
                                farmId: u.activeFarmId!, uid: u.uid);
                            },
                          ),
                        );
                      },
                    );
                  }),

                  const SizedBox(height: 4),

                  // KPI kartları — rol bazlı filtreli
                  Builder(builder: (_) {
                    final u = AuthService.instance.currentUser;
                    if (u != null && !u.canSeeFarmStats) return const SizedBox.shrink();
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
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
                          Builder(builder: (_) {
                            final showIncome = u?.canSeeIncomeStats ?? true;
                            if (!showIncome) {
                              return Row(children: [
                                Expanded(child: _StatCard(title: 'Bugün Süt', value: '${_todayMilk.toStringAsFixed(1)} L', icon: Icons.water_drop, color: AppColors.infoBlue)),
                                const SizedBox(width: 12),
                                const Expanded(child: SizedBox()),
                              ]);
                            }
                            return Row(children: [
                              Expanded(child: _StatCard(title: 'Bugün Süt', value: '${_todayMilk.toStringAsFixed(1)} L', icon: Icons.water_drop, color: AppColors.infoBlue)),
                              const SizedBox(width: 12),
                              Expanded(child: _StatCard(title: 'Bu Ay Gelir', value: '₺${NumberFormat('#,##0', 'tr_TR').format(_monthIncome)}', icon: Icons.trending_up, color: AppColors.gold, maskable: true)),
                            ]);
                          }),

                          // ─── YENİ WIDGET'LAR (Faz 12) ───────────────
                          const SizedBox(height: 16),
                          // Günlük durum rozeti
                          DailyStatusBadge(
                            todoCount: _upcomingVaccines + _upcomingBirths,
                            warningCount: _lowStockCount,
                          ),
                          const SizedBox(height: 12),
                          // Çiftlik sağlık skoru (hesaplanan)
                          FarmHealthScore(
                            score: _calculateHealthScore(),
                            issueCount: _upcomingVaccines + _lowStockCount,
                          ),
                          if ((u?.canSeeFarmStats ?? true) && _total > 0) ...[
                            const SizedBox(height: 12),
                            // Sürü dağılım pie
                            HerdDistributionPie(slices: [
                              HerdDistributionSlice(
                                label: 'Sağımda',
                                count: _milking,
                                color: AppColors.infoBlue,
                              ),
                              HerdDistributionSlice(
                                label: 'Gebe',
                                count: _pregnant,
                                color: const Color(0xFF6A1B9A),
                              ),
                              HerdDistributionSlice(
                                label: 'Buzağı',
                                count: _calfCount,
                                color: AppColors.gold,
                              ),
                              HerdDistributionSlice(
                                label: 'Diğer',
                                count: (_total - _milking - _pregnant).clamp(0, 9999),
                                color: AppColors.primaryGreen,
                              ),
                            ]),
                          ],
                          if (u?.canSeeIncomeStats ?? true) ...[
                            const SizedBox(height: 12),
                            // Haftalık özet
                            WeeklySummaryCard(stats: [
                              WeeklyStat(
                                icon: Icons.water_drop,
                                label: 'Süt (gün)',
                                value: '${_todayMilk.toStringAsFixed(0)}L',
                                color: AppColors.infoBlue,
                              ),
                              WeeklyStat(
                                icon: Icons.trending_up,
                                label: 'Bu ay gelir',
                                value: '₺${NumberFormat.compact(locale: 'tr_TR').format(_monthIncome)}',
                                color: AppColors.gold,
                              ),
                              WeeklyStat(
                                icon: Icons.vaccines,
                                label: 'Bekleyen aşı',
                                value: '$_upcomingVaccines',
                                color: AppColors.errorRed,
                              ),
                              WeeklyStat(
                                icon: Icons.child_friendly,
                                label: 'Yakın doğum',
                                value: '$_upcomingBirths',
                                color: const Color(0xFF6A1B9A),
                              ),
                            ]),
                          ],
                        ],
                        const SizedBox(height: 24),
                      ],
                    );
                  }),

                  // Hatırlatıcılar — rol bazlı filtreli
                  Builder(builder: (_) {
                    final u = AuthService.instance.currentUser;
                    final reminders = <Widget>[
                      if (u?.canSeeVaccineReminder ?? true)
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
                      if (u?.canSeeBirthReminder ?? true)
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
                      if (u?.canSeeStockReminder ?? true)
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
                      if (u?.canSeeSubsidyReminder ?? true)
                        _ReminderCard(
                          icon: Icons.account_balance_outlined,
                          color: AppColors.gold,
                          title: 'Devlet Destekleri',
                          subtitle: _currentMonthSubsidyHint(),
                          hasAlert: false,
                          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SubsidiesScreen())),
                        ),
                    ];
                    if (reminders.isEmpty) return const SizedBox.shrink();
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Hatırlatıcılar',
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.textDark)),
                        const SizedBox(height: 12),
                        for (int i = 0; i < reminders.length; i++) ...[
                          if (i > 0) const SizedBox(height: 8),
                          reminders[i],
                        ],
                        const SizedBox(height: 24),
                      ],
                    );
                  }),

                  // Hızlı işlemler — role bazlı filtre
                  Builder(builder: (context) {
                    final user = AuthService.instance.currentUser;
                    final actions = <Widget>[
                      if (user?.canAddMilking ?? true)
                        _QuickActionButton(
                          icon: Icons.water_drop,
                          label: 'Sağım\nGir',
                          color: AppColors.infoBlue,
                          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const MilkScreen())),
                        ),
                      if (user?.canAddAnimal ?? true)
                        _QuickActionButton(
                          icon: Icons.pets,
                          label: 'Hayvan\nEkle',
                          color: AppColors.primaryGreen,
                          onTap: () async {
                            // Plan limiti kontrolü — limit aştıysa paywall
                            if (!await FeatureGate.checkAnimalLimit(context, _total)) return;
                            if (!context.mounted) return;
                            final result = await Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (_) => const AddAnimalScreen()));
                            if (result == true && mounted) _loadStats();
                          },
                        ),
                      if (user?.canManageHealth ?? true)
                        _QuickActionButton(
                          icon: Icons.vaccines,
                          label: 'Aşı\nKaydet',
                          color: AppColors.errorRed,
                          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const HealthScreen())),
                        ),
                      // Ana Sahip / Yardımcı veteriner çağırabilir
                      if (user?.hasFullControl ?? false)
                        _QuickActionButton(
                          icon: Icons.medical_services,
                          label: 'Veteriner\nÇağır',
                          color: const Color(0xFF6A1B9A),
                          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const VetRequestFormScreen())),
                        ),
                      if (user?.canSeeFinance ?? true)
                        _QuickActionButton(
                          icon: Icons.attach_money,
                          label: 'Finans',
                          color: AppColors.gold,
                          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const FinanceScreen())),
                        ),
                    ];
                    if (actions.isEmpty) return const SizedBox.shrink();
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Hızlı İşlem',
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.textDark)),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            for (int i = 0; i < actions.length; i++) ...[
                              if (i > 0) const SizedBox(width: 10),
                              Expanded(child: actions[i]),
                            ],
                          ],
                        ),
                        const SizedBox(height: 24),
                      ],
                    );
                  }),

                  // Diğer Modüller — role bazlı filtre
                  Builder(builder: (context) {
                    final user = AuthService.instance.currentUser;
                    final cards = <Widget>[
                      if (user?.canSeeCalves ?? true)
                        _ModuleCard(icon: Icons.baby_changing_station, label: 'Buzağı &\nÜreme', color: const Color(0xFF6A1B9A),
                          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CalfScreen()))),
                      if (user?.canSeeFeed ?? true)
                        _ModuleCard(icon: Icons.grass, label: 'Yem\nYönetimi', color: const Color(0xFF558B2F),
                          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const FeedScreen()))),
                      if (user?.canSeeStaff ?? true)
                        _ModuleCard(icon: Icons.people_outline, label: 'Personel &\nGörevler', color: AppColors.infoBlue,
                          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const StaffScreen()))),
                      if (user?.canSeeEquipment ?? true)
                        _ModuleCard(icon: Icons.build_outlined, label: 'Ekipman', color: const Color(0xFF37474F),
                          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const EquipmentScreen()))),
                      if (user?.canSeeSubsidies ?? true)
                        _ModuleCard(icon: Icons.account_balance, label: 'Devlet\nDestekleri', color: AppColors.gold,
                          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SubsidiesScreen()))),
                    ];
                    if (cards.isEmpty) return const SizedBox.shrink();
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Diğer Modüller',
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.textDark)),
                        const SizedBox(height: 12),
                        GridView.count(
                          crossAxisCount: 3,
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          crossAxisSpacing: 10,
                          mainAxisSpacing: 10,
                          childAspectRatio: 1.1,
                          children: cards,
                        ),
                      ],
                    );
                  }),
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
  /// true ise tutar güvenlik ayarında gizlenebilir (finans değerleri için).
  final bool maskable;
  const _StatCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
    this.maskable = false,
  });

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
                maskable
                    ? MaskedAmount(text: value, style: const TextStyle(
                        fontSize: 17, fontWeight: FontWeight.w800, color: AppColors.textDark))
                    : Text(value, style: const TextStyle(
                        fontSize: 17, fontWeight: FontWeight.w800, color: AppColors.textDark)),
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

/// Owner/Assistant için bildirim paneli — okunmamış öğeleri liste halinde gösterir,
/// tıkla→okundu işaretle, "Tümünü okundu" butonu.
class _NotificationFeedPanel extends StatelessWidget {
  final List<NotificationItemModel> unread;
  final Future<void> Function(String notifId) onMarkRead;
  final VoidCallback onMarkAllRead;

  const _NotificationFeedPanel({
    required this.unread,
    required this.onMarkRead,
    required this.onMarkAllRead,
  });

  IconData _typeIcon(String type) {
    switch (type) {
      case NotificationType.vetRead: return Icons.done_all;
      case NotificationType.invitationAccepted: return Icons.check_circle;
      case NotificationType.invitationRejected: return Icons.cancel;
      default: return Icons.notifications;
    }
  }

  Color _typeColor(String type) {
    switch (type) {
      case NotificationType.vetRead: return AppColors.infoBlue;
      case NotificationType.invitationAccepted: return AppColors.primaryGreen;
      case NotificationType.invitationRejected: return AppColors.errorRed;
      default: return AppColors.gold;
    }
  }

  @override
  Widget build(BuildContext context) {
    final top = unread.take(5).toList();
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.gold.withValues(alpha: 0.35)),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 8)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const Icon(Icons.notifications_active, color: AppColors.gold, size: 18),
            const SizedBox(width: 8),
            Text('Bildirimler (${unread.length})',
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800)),
            const Spacer(),
            if (unread.length > 1)
              TextButton(
                onPressed: onMarkAllRead,
                style: TextButton.styleFrom(
                  minimumSize: Size.zero,
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                ),
                child: const Text('Tümünü Okundu',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
              ),
          ]),
          const SizedBox(height: 10),
          ...top.map((n) {
            final c = _typeColor(n.type);
            return InkWell(
              onTap: () => onMarkRead(n.id!),
              borderRadius: BorderRadius.circular(8),
              child: Container(
                margin: const EdgeInsets.only(bottom: 6),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: c.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(8),
                  border: Border(left: BorderSide(color: c, width: 3)),
                ),
                child: Row(
                  children: [
                    Icon(_typeIcon(n.type), color: c, size: 18),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(n.title,
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800)),
                          Text(n.body,
                              style: const TextStyle(fontSize: 11, color: AppColors.textGrey),
                              maxLines: 2, overflow: TextOverflow.ellipsis),
                        ],
                      ),
                    ),
                    const Icon(Icons.close, size: 16, color: AppColors.textGrey),
                  ],
                ),
              ),
            );
          }),
          if (unread.length > 5)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text('Ve ${unread.length - 5} bildirim daha',
                  style: const TextStyle(fontSize: 11, color: AppColors.textGrey)),
            ),
        ],
      ),
    );
  }
}

/// Bekleyen davet banner'ı (tüm roller için).
class _InvitationBanner extends StatelessWidget {
  final int count;
  final VoidCallback onTap;
  const _InvitationBanner({required this.count, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.gold.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.gold.withValues(alpha: 0.4)),
        ),
        child: Row(children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.gold.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.mail_outline, color: AppColors.gold),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('$count yeni çiftlik daveti',
                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
                const Text('İncele ve kabul et',
                    style: TextStyle(fontSize: 11, color: AppColors.textGrey)),
              ],
            ),
          ),
          const Icon(Icons.chevron_right, color: AppColors.textGrey),
        ]),
      ),
    );
  }
}

/// Çiftlik değiştirici bottom sheet — mevcut tüm aktif üyelikler listesi.
class _FarmSwitcherSheet extends StatelessWidget {
  const _FarmSwitcherSheet();

  @override
  Widget build(BuildContext context) {
    final user = AuthService.instance.currentUser;
    if (user == null) return const SizedBox.shrink();
    final memberships = user.memberships.values.where((m) => m.isActive).toList();

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40, height: 4,
              decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)),
            ),
            const SizedBox(height: 14),
            const Text('Çiftlik Değiştir',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
            const SizedBox(height: 10),
            ...memberships.map((m) {
              final isActive = user.activeFarmId == m.farmId;
              final roleLabel = AppConstants.roleLabels[m.role] ?? m.role;
              return Container(
                margin: const EdgeInsets.symmetric(vertical: 4),
                decoration: BoxDecoration(
                  color: isActive
                      ? AppColors.primaryGreen.withValues(alpha: 0.08)
                      : Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isActive ? AppColors.primaryGreen : AppColors.divider,
                    width: isActive ? 2 : 1,
                  ),
                ),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: AppColors.primaryGreen.withValues(alpha: 0.15),
                    child: const Icon(Icons.agriculture, color: AppColors.primaryGreen),
                  ),
                  title: Text(m.farmName, style: const TextStyle(fontWeight: FontWeight.w700)),
                  subtitle: Text(roleLabel,
                      style: const TextStyle(fontSize: 11, color: AppColors.textGrey)),
                  trailing: isActive
                      ? const Icon(Icons.check_circle, color: AppColors.primaryGreen)
                      : const Icon(Icons.chevron_right, color: AppColors.textGrey),
                  onTap: () async {
                    Navigator.pop(context);
                    if (!isActive) {
                      await AuthService.instance.setActiveFarm(m.farmId);
                    }
                  },
                ),
              );
            }),
            const SizedBox(height: 6),
            TextButton.icon(
              onPressed: () {
                Navigator.pop(context);
                Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const FarmPickerScreen()));
              },
              icon: const Icon(Icons.list_alt, size: 16),
              label: const Text('Tüm çiftlikler / davetler'),
            ),
          ],
        ),
      ),
    );
  }
}

