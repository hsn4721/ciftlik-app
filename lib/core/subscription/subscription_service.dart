import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/analytics_service.dart';
import '../services/auth_service.dart';
import '../services/app_logger.dart';
import '../constants/app_constants.dart';
import 'subscription_constants.dart';
import 'subscription_state.dart';

/// IAP merkezi servisi — Apple App Store + Google Play.
///
/// Sorumluluklar:
/// - Mağaza ürünlerini yükle (queryProductDetails)
/// - Satın alma akışı (buyNonConsumable)
/// - Restore purchases
/// - Subscription state Firestore senkron
/// - Trial başlatma + bitiş takibi
///
/// **NOT**: Production'da receipt validation **server-side** (Firebase Functions)
/// yapılmalı. Bu service client-side basic validation yapar; backend Functions
/// hazır olunca `_verifyOnServer()` çağrısı eklenmeli.
class SubscriptionService extends ChangeNotifier {
  SubscriptionService._();
  static final SubscriptionService instance = SubscriptionService._();

  final InAppPurchase _iap = InAppPurchase.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  bool _initialized = false;
  bool _available = false;
  List<ProductDetails> _products = [];
  StreamSubscription<List<PurchaseDetails>>? _purchaseSub;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _stateSub;
  StreamSubscription<dynamic>? _userSub;
  SubscriptionState _state = SubscriptionState.empty();
  // Listener'ın hangi user/farm context'inde kurulduğu — değişiklikte yeniden
  // attach kararı için. (Vet user-level path, çiftlik kullanıcı farm-level path
  // dinler; activeFarmId değişince eski farm'ın listener'ı kapatılır.)
  String? _attachedUid;
  String? _attachedFarmId;

  /// Trial bittiğinde tetiklenir — UI dinleyicisi (DashboardScreen) "Trial Bitti"
  /// dialog'u + paywall yönlendirmesi yapar. Listener kurulan widget tek seferlik
  /// gösterimi kontrol eder (boolean flag) — service tetikleyici, UI sunum sahibi.
  final ValueNotifier<DateTime?> trialExpiredAt = ValueNotifier<DateTime?>(null);

  // ─── Public API ──────────────────────────────────────────

  /// Test/QA override — sadece debug build + AppConstants.enableTestProAllowlist
  /// açıkken çalışır. Listedeki e-postalar otomatik Pro paket görür; Firestore'a
  /// sahte abonelik yazılmaz (sadece in-memory override).
  ///
  /// **Mağaza yayınından önce `enableTestProAllowlist=false` yapın.** kDebugMode
  /// guard'ı release build'de zaten dead-code olarak elemine eder, ama her
  /// ihtimale karşı flag de eklenmiştir (defense in depth).
  bool get _hasTestProOverride {
    if (!kDebugMode) return false;
    if (!AppConstants.enableTestProAllowlist) return false;
    final email = AuthService.instance.currentUser?.email.toLowerCase().trim();
    if (email == null || email.isEmpty) return false;
    return AppConstants.testProAllowlistEmails.contains(email);
  }

  /// Vet test override — listedeki e-postalar otomatik vet aboneliği görür.
  /// Multi-farm vet panelini abonelik almadan test etmek için.
  bool get _hasTestVetOverride {
    if (!kDebugMode) return false;
    if (!AppConstants.enableTestProAllowlist) return false;
    final email = AuthService.instance.currentUser?.email.toLowerCase().trim();
    if (email == null || email.isEmpty) return false;
    return AppConstants.testVetAllowlistEmails.contains(email);
  }

  /// Test için sentetik Pro state — Firestore'a yazılmaz.
  SubscriptionState _testProState() => SubscriptionState(
        plan: SubscriptionPlan.pro,
        status: SubscriptionStatus.active,
        startedAt: DateTime(2025, 1, 1),
        expiresAt: DateTime(2099, 12, 31),
        autoRenew: false,
        productId: 'TEST_OVERRIDE',
        platform: 'debug',
        paidByUid: AuthService.instance.currentUser?.uid,
      );

  /// Test için sentetik Vet state — Firestore'a yazılmaz.
  SubscriptionState _testVetState() => SubscriptionState(
        plan: SubscriptionPlan.vet,
        status: SubscriptionStatus.active,
        startedAt: DateTime(2025, 1, 1),
        expiresAt: DateTime(2099, 12, 31),
        autoRenew: false,
        productId: 'TEST_OVERRIDE_VET',
        platform: 'debug',
        paidByUid: AuthService.instance.currentUser?.uid,
      );

  /// Aktif abonelik durumu.
  /// Override öncelik sırası: vet > pro > gerçek state.
  SubscriptionState get state {
    if (_hasTestVetOverride) return _testVetState();
    if (_hasTestProOverride) return _testProState();
    return _state;
  }

  /// Anlık plan.
  SubscriptionPlan get plan => state.plan;

  /// Mağazadan yüklenmiş ürünler.
  List<ProductDetails> get products => _products;

  /// Mağaza erişilebilir mi (sandbox/uçak modu).
  bool get available => _available;

  /// Verilen feature için kullanıcı yetkili mi?
  bool isUnlocked(SubscriptionPlan requiredPlan) {
    final p = state.plan;
    switch (requiredPlan) {
      case SubscriptionPlan.starter: return p.hasStarterAccess;
      case SubscriptionPlan.family:  return p.hasFamilyAccess;
      case SubscriptionPlan.pro:     return p.hasProAccess;
      case SubscriptionPlan.trial:   return p == SubscriptionPlan.trial;
      case SubscriptionPlan.vet:     return p.hasVetAccess;
      case SubscriptionPlan.none:    return true;
    }
  }

  // ─── Initialization ──────────────────────────────────────

  /// Uygulama başlangıcında çağrılır. Mağazayı kontrol eder, ürünleri yükler,
  /// satın alma stream'ini dinler, kullanıcının mevcut abonelik state'ini
  /// Firestore'dan yükler.
  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;

    try {
      _available = await _iap.isAvailable();
      if (_available) {
        await _loadProducts();
        _purchaseSub = _iap.purchaseStream.listen(
          _handlePurchaseUpdates,
          onError: (Object e, StackTrace st) =>
              AppLogger.error('SubscriptionService.purchaseStream', e, st),
        );
      }
      await _attachStateListener();

      // AuthService user/farm değişikliği listener'ı — vet farm switch ya da
      // çiftlik kullanıcı setActiveFarm yapınca subscription doc path'i değişir.
      // Eski listener kapatılıp yeni context için yeniden bağlanması zorunlu;
      // aksi halde kullanıcı eski farm'ın subscription'ını görür (gating bug).
      _userSub = AuthService.instance.userStream.listen((_) async {
        final user = AuthService.instance.currentUser;
        final newUid = user?.uid;
        final newFarm = user?.isVet == true ? null : user?.activeFarmId;
        if (newUid != _attachedUid || newFarm != _attachedFarmId) {
          await _attachStateListener();
        }
      });
    } catch (e, st) {
      AppLogger.error('SubscriptionService.init', e, st);
    }
    notifyListeners();
  }

  /// Mağazadan tüm ürünleri sorgula.
  Future<void> _loadProducts() async {
    try {
      final response = await _iap.queryProductDetails(IapProductIds.allIds);
      if (response.error != null) {
        AppLogger.warn('SubscriptionService._loadProducts',
            'product query error: ${response.error?.message}');
      }
      _products = response.productDetails;
    } catch (e, st) {
      AppLogger.error('SubscriptionService._loadProducts', e, st);
    }
  }

  /// Subscription dokümanı için referans seçimi.
  ///
  /// - **Veteriner**: kendi user-level subscription'ı (multi-farm bağımsız)
  /// - **Diğer roller (owner/assistant/partner/worker)**: aktif çiftliğin
  ///   subscription'ı — owner satın alır, ekip yararlanır.
  DocumentReference<Map<String, dynamic>>? _subscriptionDocRef() {
    final user = AuthService.instance.currentUser;
    if (user == null) return null;

    // Vet için user-level
    if (user.isVet) {
      return _db.collection('users').doc(user.uid)
          .collection('subscription').doc('current');
    }

    // Diğer roller için farm-level
    final farmId = user.activeFarmId;
    if (farmId == null) return null;
    return _db.collection('farms').doc(farmId)
        .collection('subscription').doc('current');
  }

  /// Realtime Firestore listener.
  ///
  /// Önceki sürüm tek seferlik `.get()` yapıyordu — bu yüzden owner iOS'ta
  /// satın alma yapınca aynı çiftlikteki Android team member uygulamayı
  /// kapatıp açmadan upgrade'i göremiyordu. Artık `.snapshots()` kullanıp
  /// canlı sync sağlıyoruz.
  Future<void> _attachStateListener() async {
    await _stateSub?.cancel();
    _stateSub = null;

    final user = AuthService.instance.currentUser;
    _attachedUid = user?.uid;
    _attachedFarmId = user?.isVet == true ? null : user?.activeFarmId;

    final ref = _subscriptionDocRef();
    if (ref == null) {
      _state = SubscriptionState.empty();
      notifyListeners();
      return;
    }

    _stateSub = ref.snapshots().listen(
      (doc) async {
        if (doc.exists && doc.data() != null) {
          final next = SubscriptionState.fromMap(doc.data()!);
          _state = next;
          if (_state.isTrialExpired()) {
            // İlk tespit — dialog'u tetikle (uygulama başında veya canlı session'da).
            // _expireSubscription plan'ı 'none' yapacak, bir sonraki snapshot
            // isTrialExpired=false döner → dialog tek seferlik.
            if (trialExpiredAt.value == null) {
              trialExpiredAt.value = DateTime.now();
            }
            await _expireSubscription();
          }
        } else {
          _state = SubscriptionState.empty();
        }
        notifyListeners();
      },
      onError: (Object e, StackTrace st) {
        AppLogger.error('SubscriptionService._attachStateListener', e, st);
      },
    );
  }

  // ─── Trial ──────────────────────────────────────────────

  /// 14 gün ücretsiz Pro deneme başlat — sadece çiftlik (owner) için.
  /// Vet kullanıcılar için trial yok (kayıt sonrası zorunlu paywall).
  /// Owner kayıt sonrası registerFarm akışında çağrılır.
  Future<void> startTrial() async {
    final user = AuthService.instance.currentUser;
    if (user == null) return;
    if (user.isVet) {
      AppLogger.info('SubscriptionService.startTrial', 'vet için trial yok');
      return;
    }
    // Farm trial daha önce alındı mı? (per-farm tracking)
    final farmId = user.activeFarmId;
    if (farmId == null) return;
    final prefs = await SharedPreferences.getInstance();
    final usedKey = 'farm_trial_used_$farmId';
    if (prefs.getBool(usedKey) ?? false) {
      AppLogger.info('SubscriptionService.startTrial',
          'çiftlik daha önce trial almış');
      return;
    }

    final now = DateTime.now();
    final trialEnd = now.add(const Duration(days: 14));
    _state = SubscriptionState(
      plan: SubscriptionPlan.trial,
      status: SubscriptionStatus.trial,
      startedAt: now,
      expiresAt: trialEnd,
      autoRenew: false,
      productId: null,
      platform: defaultTargetPlatform.name,
      paidByUid: user.uid,
    );
    await _writeStateToFirestore();
    await prefs.setBool(usedKey, true);
    unawaited(AnalyticsService.instance.logTrialStarted());
    notifyListeners();
  }

  // ─── Satın Alma ────────────────────────────────────────

  /// Son satın alma hatası (UI'da göstermek için).
  String? lastPurchaseError;

  /// Belirli bir ürünü satın al — abonelik için non-consumable.
  /// [product] queryProductDetails'tan gelen ProductDetails.
  Future<bool> buy(ProductDetails product) async {
    if (!_available) {
      lastPurchaseError = 'Mağaza erişilemiyor. İnternet bağlantınızı kontrol edin.';
      return false;
    }
    try {
      lastPurchaseError = null;
      unawaited(AnalyticsService.instance.logPurchaseInitiated(productId: product.id));
      final purchaseParam = PurchaseParam(productDetails: product);
      // Subscriptions için non-consumable (Apple/Google subscription handling)
      return await _iap.buyNonConsumable(purchaseParam: purchaseParam);
    } catch (e, st) {
      AppLogger.error('SubscriptionService.buy', e, st,
          context: {'productId': product.id});
      lastPurchaseError = 'Satın alma başlatılamadı: ${e.toString()}';
      unawaited(AnalyticsService.instance.logPurchaseFailed(
          productId: product.id, reason: e.toString()));
      return false;
    }
  }

  /// Daha önce alınmış aboneliği geri yükle (cihaz değişikliği vb.).
  Future<void> restorePurchases() async {
    if (!_available) return;
    try {
      await _iap.restorePurchases();
    } catch (e, st) {
      AppLogger.error('SubscriptionService.restorePurchases', e, st);
    }
  }

  // ─── Purchase Stream Handler ─────────────────────────

  Future<void> _handlePurchaseUpdates(List<PurchaseDetails> purchases) async {
    for (final purchase in purchases) {
      bool activated = false;
      switch (purchase.status) {
        case PurchaseStatus.pending:
          // UI loading state — completePurchase çağırma, mağaza henüz teslim
          // etmedi.
          break;
        case PurchaseStatus.purchased:
        case PurchaseStatus.restored:
          activated = await _activatePurchase(purchase);
          break;
        case PurchaseStatus.error:
          final err = purchase.error;
          AppLogger.error(
            'SubscriptionService.purchaseError',
            err ?? 'unknown',
            StackTrace.current,
            context: {'productId': purchase.productID, 'status': purchase.status.name},
          );
          lastPurchaseError = err?.message ?? 'Satın alma başarısız oldu.';
          break;
        case PurchaseStatus.canceled:
          break;
      }
      // completePurchase **yalnızca** sunucu doğrulaması başarılıysa veya
      // kullanıcı iptal/error sonucu artık tekrar denemeyecekse çağrılır.
      // Pending durumunda mağaza henüz son söz vermedi.
      // Eski mantık: success'te validation FAIL olsa bile complete çağırırdı —
      // Google bunu "satın alma teslim edildi" sayar, kullanıcı parasını kaybeder.
      final isTerminal = purchase.status == PurchaseStatus.canceled ||
          purchase.status == PurchaseStatus.error ||
          activated;
      if (purchase.pendingCompletePurchase && isTerminal) {
        await _iap.completePurchase(purchase);
      }
    }
    notifyListeners();
  }

  /// Satın alma başarılı — Cloud Function ile **sunucu doğrulaması** yapar,
  /// Function Apple/Google API'sine danışır, geçerli ise Firestore'a yazar.
  ///
  /// Eski akış (production-unsafe): client direkt Firestore'a `plan: pro` yazar
  /// → hacker fake receipt ile bedavaya Pro açabilirdi.
  ///
  /// Yeni akış (production-safe):
  ///   1. Client Cloud Function'a `validateReceipt(receipt, productId)` gönderir
  ///   2. Function Apple/Google'a sorar: "bu satın alma gerçek mi?"
  ///   3. Onaylanırsa Function Firestore'a yazar (serverValidated: true)
  ///   4. Realtime listener Firestore'daki yeni state'i alır → UI günceller
  /// @returns server validation başarılıysa true (caller `completePurchase`
  /// tetikler). Hata/exception durumunda false döner; mağaza retry imkanını
  /// koruyup kullanıcı para kaybetmez.
  Future<bool> _activatePurchase(PurchaseDetails purchase) async {
    final user = AuthService.instance.currentUser;
    if (user == null) return false;

    final plan = _planFromProductId(purchase.productID);
    if (plan == SubscriptionPlan.none) {
      AppLogger.warn('SubscriptionService.activatePurchase',
          'unknown productID: ${purchase.productID}');
      return false;
    }

    // Hedef Firestore yolu — vet için user-level, çiftlik için farm-level.
    // Cloud Function bu yolu kontrol edip yetki doğrulaması yapar.
    final isVet = plan == SubscriptionPlan.vet;
    final targetPath = isVet
        ? 'users/${user.uid}/subscription/current'
        : 'farms/${user.activeFarmId}/subscription/current';

    if (!isVet && (user.activeFarmId == null || user.activeFarmId!.isEmpty)) {
      AppLogger.error('SubscriptionService.activatePurchase',
          'No active farm for non-vet purchase', StackTrace.current,
          context: {'productId': purchase.productID});
      lastPurchaseError = 'Aktif çiftlik bulunamadı';
      return false;
    }

    try {
      final functions = FirebaseFunctions.instanceFor(region: 'europe-west1');
      final callable = functions.httpsCallable('validateReceipt');
      final result = await callable.call<Map<String, dynamic>>({
        'platform': defaultTargetPlatform == TargetPlatform.iOS ? 'ios' : 'android',
        'receipt': purchase.verificationData.serverVerificationData,
        'productId': purchase.productID,
        'targetPath': targetPath,
      });
      AppLogger.info('SubscriptionService.activatePurchase',
          'Server-validated: plan=${result.data['plan']}, expires=${result.data['expiresAt']}');
      // Firestore listener (_attachStateListener) yeni state'i otomatik alacak.
    } on FirebaseFunctionsException catch (e, st) {
      AppLogger.error('SubscriptionService.activatePurchase', e, st,
          context: {
            'code': e.code,
            'message': e.message,
            'productId': purchase.productID,
          });
      // Kullanıcıya gösterilecek mesaj — code'a göre ayrıştır
      switch (e.code) {
        case 'permission-denied':
          lastPurchaseError =
              'Satın alma doğrulanamadı: ${e.message ?? "Geçersiz makbuz"}';
          break;
        case 'unauthenticated':
          lastPurchaseError = 'Önce giriş yapmalısınız';
          break;
        case 'invalid-argument':
          lastPurchaseError = 'Satın alma bilgileri eksik';
          break;
        case 'failed-precondition':
          lastPurchaseError =
              'Sunucu yapılandırması eksik. Lütfen tekrar deneyin';
          break;
        default:
          lastPurchaseError =
              'Satın alma doğrulanamadı (${e.code}). Tekrar deneyin';
      }
      unawaited(AnalyticsService.instance.logPurchaseFailed(
        productId: purchase.productID,
        reason: e.code,
      ));
      return false;
    } catch (e, st) {
      AppLogger.error('SubscriptionService.activatePurchase.unknown', e, st);
      lastPurchaseError = 'Beklenmeyen hata: ${e.toString()}';
      return false;
    }

    final isYearly = purchase.productID.endsWith('_yearly');
    unawaited(AnalyticsService.instance.logPurchaseCompleted(
      productId: purchase.productID,
      plan: plan.name,
      yearly: isYearly,
    ));
    notifyListeners();
    return true;
  }

  Future<void> _expireSubscription() async {
    _state = _state.copyWith(
      plan: SubscriptionPlan.none,
      status: SubscriptionStatus.expired,
    );
    await _writeStateToFirestore();
    notifyListeners();
  }

  Future<void> _writeStateToFirestore() async {
    final ref = _subscriptionDocRef();
    if (ref == null) return;
    try {
      await ref.set(_state.toMap(), SetOptions(merge: true));
    } catch (e, st) {
      AppLogger.error('SubscriptionService.writeState', e, st,
          context: {'plan': _state.plan.name, 'status': _state.status.name});
    }
  }

  SubscriptionPlan _planFromProductId(String productId) {
    if (productId.startsWith('ciftlikpro_starter_')) return SubscriptionPlan.starter;
    if (productId.startsWith('ciftlikpro_family_')) return SubscriptionPlan.family;
    if (productId.startsWith('ciftlikpro_pro_')) return SubscriptionPlan.pro;
    if (productId.startsWith('ciftlikpro_vet_')) return SubscriptionPlan.vet;
    return SubscriptionPlan.none;
  }

  /// Kullanıcı değiştiğinde state'i sıfırla + yeni kullanıcı için listener kur.
  Future<void> onUserChanged() async {
    _state = SubscriptionState.empty();
    trialExpiredAt.value = null;
    await _attachStateListener();
    notifyListeners();
  }

  @override
  void dispose() {
    _purchaseSub?.cancel();
    _stateSub?.cancel();
    _userSub?.cancel();
    trialExpiredAt.dispose();
    super.dispose();
  }
}
