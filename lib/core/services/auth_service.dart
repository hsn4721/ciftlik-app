import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../data/models/user_model.dart';
import '../../data/models/membership_model.dart';
import '../../data/models/invitation_model.dart';
import '../../data/local/database_helper.dart';
import '../constants/app_constants.dart';
import 'analytics_service.dart';
import 'app_logger.dart';

class AuthService {
  static final AuthService instance = AuthService._();
  AuthService._();

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final _secureStorage = const FlutterSecureStorage();

  UserModel? _currentUser;
  UserModel? get currentUser => _currentUser;
  bool get isLoggedIn => _currentUser != null;

  final StreamController<UserModel?> _userController = StreamController<UserModel?>.broadcast();
  Stream<UserModel?> get userStream => _userController.stream;

  /// Firestore'daki user dokümanını canlı dinler.
  /// Rol değişirse `_currentUser` güncellenir, doküman silinir veya isActive=false
  /// olursa otomatik sign out tetiklenir.
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _userDocSub;

  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _membershipsSub;

  void _startUserDocListener(String uid) {
    _userDocSub?.cancel();
    _membershipsSub?.cancel();

    // 1) Profil dokümanı (activeFarmId, displayName, email)
    _userDocSub = _db.collection('users').doc(uid).snapshots().listen(
      (snap) async {
        if (!snap.exists) {
          debugPrint('[AuthService] user doc removed — forcing sign out');
          await signOut();
          return;
        }
        final data = snap.data();
        if (data == null) return;

        // "Tüm cihazlardan çıkış" — sessionVersion değiştiyse bu cihazın
        // oturumunu da sonlandır.
        try {
          final remoteVersion = (data['sessionVersion'] as num?)?.toInt();
          if (remoteVersion != null) {
            final prefs = await SharedPreferences.getInstance();
            final localVersion = prefs.getInt('session_version_$uid');
            if (localVersion == null) {
              await prefs.setInt('session_version_$uid', remoteVersion);
            } else if (remoteVersion > localVersion) {
              debugPrint('[AuthService] sessionVersion mismatch — forcing sign out');
              await prefs.setInt('session_version_$uid', remoteVersion);
              await signOut();
              return;
            }
          }
        } catch (e) {
          debugPrint('[AuthService] sessionVersion check: $e');
        }

        try {
          final current = _currentUser;
          // Memberships'leri koru — subcollection listener'ı güncelliyor
          final memberships = current?.memberships ?? await loadMemberships(uid);
          final updated = UserModel.fromMap(data, memberships: memberships);
          // Aktif çiftlik hâlâ geçerli mi?
          if (updated.activeFarmId != null &&
              memberships.isNotEmpty &&
              !memberships.containsKey(updated.activeFarmId)) {
            // Aktif çiftlik silinmiş — başka bir aktif çiftliğe geç
            final firstActive = memberships.values.firstWhere(
                (m) => m.isActive, orElse: () => memberships.values.first);
            await setActiveFarm(firstActive.farmId);
            return;
          }
          _currentUser = updated;
          await _cacheUser(updated);
          _userController.add(_currentUser);
        } catch (e) {
          debugPrint('[AuthService] user doc parse error: $e');
        }
      },
      onError: (Object e, StackTrace st) =>
          AppLogger.error('AuthService.userDocListener', e, st),
    );

    // 2) Memberships subcollection — rol veya isActive değiştiğinde tetiklenir
    _membershipsSub = _db
        .collection('users')
        .doc(uid)
        .collection('memberships')
        .snapshots()
        .listen(
      (snap) async {
        final memberships = <String, MembershipModel>{
          for (final d in snap.docs) d.id: MembershipModel.fromMap(d.data()),
        };
        final current = _currentUser;
        if (current == null) return;

        // Aktif çiftlikte devre dışı bırakıldı mı?
        final active = current.activeFarmId != null
            ? memberships[current.activeFarmId]
            : null;
        if (active != null && !active.isActive) {
          // Başka aktif membership var mı?
          final other = memberships.values.where((m) => m.isActive).toList();
          if (other.isEmpty) {
            debugPrint('[AuthService] all memberships deactivated — forcing sign out');
            await signOut();
            return;
          }
          await setActiveFarm(other.first.farmId);
          return;
        }

        _currentUser = current.copyWith(memberships: memberships);
        await _cacheUser(_currentUser!);
        _userController.add(_currentUser);
      },
      onError: (Object e, StackTrace st) =>
          AppLogger.error('AuthService.membershipsListener', e, st),
    );
  }

  void _stopUserDocListener() {
    _userDocSub?.cancel();
    _userDocSub = null;
    _membershipsSub?.cancel();
    _membershipsSub = null;
  }

  // ─── Uygulama başlarken oturumu kontrol et ───────────────────────────────

  Future<UserModel?> checkSession() async {
    // "Beni Hatırla" seçilmemişse oturum açma
    final prefs = await SharedPreferences.getInstance();
    final rememberMe = prefs.getBool('remember_me') ?? false;
    if (!rememberMe) {
      await _auth.signOut();
      return null;
    }

    // Firebase oturumunu kontrol et
    final firebaseUser = _auth.currentUser;
    if (firebaseUser != null) {
      try {
        final userModel = await _fetchUserFromFirestore(firebaseUser.uid);
        if (userModel != null) {
          _currentUser = userModel;
          await _cacheUser(userModel);
          _userController.add(_currentUser);
          _startUserDocListener(firebaseUser.uid);
          unawaited(_syncMyMemberDocs());
          return _currentUser;
        }
      } catch (e) {
        debugPrint('[AuthService.checkSession] fetch failed, falling back to cache: $e');
      }
    }

    // Offline: cache'den oku
    final cached = await _loadCachedUser();
    if (cached != null) {
      _currentUser = cached;
      _userController.add(_currentUser);
      return _currentUser;
    }

    return null;
  }

  // ─── Giriş ───────────────────────────────────────────────────────────────

  Future<AuthResult> signIn(String email, String password, {bool rememberMe = false}) async {
    try {
      final credential = await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      final user = credential.user;
      if (user == null) return AuthResult.error('Giriş başarısız');

      final userModel = await _fetchUserFromFirestore(user.uid);
      if (userModel == null) return AuthResult.error('Kullanıcı kaydı bulunamadı');
      // Çoklu-çiftlik: Aktif membership yok ama davet olabilir — login_screen
      // FarmPicker'a yönlendirir. Hiç aktif çiftlik + hiç davet yok ise kullanıcı
      // "çiftliksiz" ekranında kalır, bilinçli çıkış yapabilir.

      // SQLite — kullanıcı değişmişse cihaz cache'ini sıfırla
      await _resetLocalIfUserChanged(userModel.uid);

      _currentUser = userModel;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('remember_me', rememberMe);
      if (rememberMe) {
        await _cacheUser(userModel);
        await _secureStorage.write(key: 'saved_password', value: password);
      } else {
        await _clearCache();
      }
      _userController.add(_currentUser);
      _startUserDocListener(user.uid);
      // Crash raporlarına UID ekle + analytics user property
      unawaited(AppLogger.setUserId(user.uid));
      unawaited(AnalyticsService.instance.setUser(uid: user.uid, role: userModel.role));
      // Eski member aynalarında displayName/email eksik olabilir — sync et
      unawaited(_syncMyMemberDocs());
      return AuthResult.success(userModel);
    } on FirebaseAuthException catch (e) {
      return AuthResult.error(_firebaseErrorMessage(e.code));
    } catch (e) {
      // Offline mod: sadece "Beni Hatırla" seçildiyse cache'den dene
      final prefs = await SharedPreferences.getInstance();
      if (prefs.getBool('remember_me') ?? false) {
        final cached = await _loadCachedUser();
        if (cached != null && cached.email == email.trim()) {
          _currentUser = cached;
          _userController.add(_currentUser);
          return AuthResult.success(cached, isOffline: true);
        }
      }
      return AuthResult.error('Bağlantı hatası. İnternet bağlantınızı kontrol edin.');
    }
  }

  // ─── Çiftlik + Ana Sahip kaydı ────────────────────────────────────────────

  Future<AuthResult> registerFarm({
    required String farmName,
    required String ownerName,
    required String email,
    required String password,
  }) async {
    try {
      final credential = await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      final user = credential.user;
      if (user == null) return AuthResult.error('Kayıt başarısız');

      await user.updateDisplayName(ownerName);
      await user.getIdToken(true); // Xiaomi/MIUI race fix

      final farmId = _db.collection('farms').doc().id;
      final now = DateTime.now();
      final emailLc = email.trim().toLowerCase();

      // 1) Çiftlik dokümanı
      await _db.collection('farms').doc(farmId).set({
        'name': farmName,
        'ownerId': user.uid,
        'createdAt': FieldValue.serverTimestamp(),
      });

      // 2) Kullanıcı profili (aktif çiftlik = yeni oluşturulan)
      final membership = MembershipModel(
        farmId: farmId,
        farmName: farmName,
        role: AppConstants.roleOwner,
        isActive: true,
        joinedAt: now,
      );
      final userModel = UserModel(
        uid: user.uid,
        email: emailLc,
        displayName: ownerName,
        activeFarmId: farmId,
        memberships: <String, MembershipModel>{farmId: membership},
        createdAt: now,
      );
      await _db.collection('users').doc(user.uid).set(userModel.toMap());

      // 3) Üyelik (user'ın alt koleksiyonunda + farm'ın aynasında)
      await _writeMembership(user.uid, membership,
          displayName: ownerName, email: emailLc);

      // 4) SQLite — yeni kullanıcı, varsa eski cache temizle
      await _resetLocalIfUserChanged(user.uid);

      _currentUser = userModel;
      await _cacheUser(userModel);
      _userController.add(_currentUser);
      _startUserDocListener(user.uid);
      return AuthResult.success(userModel);
    } on FirebaseAuthException catch (e) {
      return AuthResult.error(_firebaseErrorMessage(e.code));
    } on FirebaseException catch (e) {
      return AuthResult.error('Kayıt hatası [${e.code}]: ${e.message ?? ''}');
    } catch (e) {
      return AuthResult.error('Kayıt sırasında hata oluştu: $e');
    }
  }

  /// Davetli kullanıcı kayıt akışı — yeni çiftlik OLUŞTURMAZ. Sadece
  /// Firebase Auth + users/{uid} profili oluşturur. Kullanıcı giriş yapınca
  /// email'ine gelen davetleri görüp kabul eder.
  ///
  /// Vet için [phone] ve [clinicName] gönderilebilir — `users/{uid}` doc'una
  /// ek alan olarak kaydedilir; davet kabul akışında çiftliğin member ayna
  /// doc'una da yansıtılabilir.
  Future<AuthResult> registerAsInvitee({
    required String displayName,
    required String email,
    required String password,
    String? phone,
    String? clinicName,
    bool isVet = false,
  }) async {
    try {
      final credential = await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      final user = credential.user;
      if (user == null) return AuthResult.error('Kayıt başarısız');

      await user.updateDisplayName(displayName);
      await user.getIdToken(true);

      final now = DateTime.now();
      final userModel = UserModel(
        uid: user.uid,
        email: email.trim().toLowerCase(),
        displayName: displayName,
        activeFarmId: null, // Henüz çiftlik yok — davetleri kabul edince dolacak
        memberships: const <String, MembershipModel>{},
        registrationRole: isVet ? AppConstants.roleVet : null,
        createdAt: now,
      );
      final userDoc = userModel.toMap();
      if (phone != null && phone.isNotEmpty) userDoc['phone'] = phone;
      if (clinicName != null && clinicName.isNotEmpty) userDoc['clinicName'] = clinicName;
      await _db.collection('users').doc(user.uid).set(userDoc);

      // SQLite — yeni kullanıcı, varsa eski cache temizle
      await _resetLocalIfUserChanged(user.uid);

      _currentUser = userModel;
      await _cacheUser(userModel);
      _userController.add(_currentUser);
      _startUserDocListener(user.uid);
      return AuthResult.success(userModel);
    } on FirebaseAuthException catch (e) {
      return AuthResult.error(_firebaseErrorMessage(e.code));
    } on FirebaseException catch (e) {
      return AuthResult.error('Kayıt hatası [${e.code}]: ${e.message ?? ''}');
    } catch (e) {
      return AuthResult.error('Kayıt sırasında hata oluştu: $e');
    }
  }

  // ─── Çiftlik yönetimi (üyelik) ────────────────────────────────────────────

  /// Aktif çiftliği değiştir — Firestore'a yazılır, stream tetiklenir.
  ///
  /// **Veri izolasyonu**: Multi-farm kullanıcı (örn. iki çiftlikte assistant
  /// olan kişi) çiftlik değiştirdiğinde SQLite cache'i de sıfırlanır.
  /// Aksi halde yeni çiftlikte eski çiftliğin animals/milking/finance kayıtları
  /// görünürdü — gizlilik ihlali.
  Future<void> setActiveFarm(String farmId) async {
    final user = _currentUser;
    if (user == null) return;
    if (!user.memberships.containsKey(farmId)) {
      debugPrint('[AuthService.setActiveFarm] $farmId not in memberships');
      return;
    }
    final isSwitching = user.activeFarmId != null && user.activeFarmId != farmId;
    try {
      await _db.collection('users').doc(user.uid).update({
        'activeFarmId': farmId,
        // Legacy uyumluluk için scalar alanlar da güncellenir
        'farmId': farmId,
        'role': user.memberships[farmId]!.role,
        'isActive': user.memberships[farmId]!.isActive,
      });
      // Çiftlik gerçekten değişiyorsa local cache'i temizle
      if (isSwitching) {
        try {
          await DatabaseHelper.instance.resetAllData();
        } catch (e) {
          debugPrint('[AuthService.setActiveFarm] SQLite reset: $e');
        }
      }
      _currentUser = user.copyWith(activeFarmId: farmId);
      await _cacheUser(_currentUser!);
      _userController.add(_currentUser);
    } catch (e) {
      debugPrint('[AuthService.setActiveFarm] $e');
    }
  }

  /// Davet kabul et: memberships + farm members ayna yaz, invitation işaretle.
  Future<String?> acceptInvitation(InvitationModel inv) async {
    final user = _currentUser;
    if (user == null) return 'Oturum açılmamış';
    if (inv.id == null) return 'Geçersiz davet';

    try {
      // Çiftlik adını HER ZAMAN farms doc'tan tazele — `inv.farmName` davet
      // anındaki snapshot olabilir. Vet daveti aldığında çiftliğin gerçek
      // güncel adını görmeli, owner farm'ı yeniden adlandırdıysa da yansır.
      String farmName = inv.farmName;
      try {
        final fd = await _db.collection('farms').doc(inv.farmId).get();
        final fresh = (fd.data()?['name'] as String?)?.trim();
        if (fresh != null && fresh.isNotEmpty) farmName = fresh;
      } catch (_) {/* Offline/permission fallback — davetteki ismi kullan */}
      // Son çare: hâlâ boşsa anlamlı bir varsayılan ata
      if (farmName.isEmpty) farmName = 'Çiftlik';

      final membership = MembershipModel(
        farmId: inv.farmId,
        farmName: farmName,
        role: inv.role,
        isActive: true,
        invitedBy: inv.invitedBy,
        joinedAt: DateTime.now(),
      );
      await _writeMembership(user.uid, membership,
          displayName: user.displayName, email: user.email);

      await _db.collection('invitations').doc(inv.id).update({
        'status': InvitationStatus.accepted,
        'respondedAt': Timestamp.fromDate(DateTime.now()),
        'acceptedByUid': user.uid,
        'responderName': user.displayName, // Owner tarafı notif yaratırken kullanır
      });

      // Kullanıcının aktif çiftliği yoksa bunu aktif yap
      final updatedMemberships = {...user.memberships, inv.farmId: membership};
      if (user.activeFarmId == null) {
        await _db.collection('users').doc(user.uid).update({
          'activeFarmId': inv.farmId,
          'farmId': inv.farmId,
          'role': inv.role,
          'isActive': true,
        });
        _currentUser = user.copyWith(
          activeFarmId: inv.farmId,
          memberships: updatedMemberships,
        );
      } else {
        _currentUser = user.copyWith(memberships: updatedMemberships);
      }
      await _cacheUser(_currentUser!);
      _userController.add(_currentUser);
      return null; // başarılı
    } catch (e) {
      debugPrint('[AuthService.acceptInvitation] $e');
      return 'Davet kabul edilemedi: $e';
    }
  }

  Future<void> rejectInvitation(InvitationModel inv) async {
    if (inv.id == null) return;
    try {
      final user = _currentUser;
      await _db.collection('invitations').doc(inv.id).update({
        'status': InvitationStatus.rejected,
        'respondedAt': Timestamp.fromDate(DateTime.now()),
        'responderName': user?.displayName ?? '',
      });
    } catch (e) {
      debugPrint('[AuthService.rejectInvitation] $e');
    }
  }

  /// users/{uid}/memberships/{farmId} + farms/{farmId}/members/{uid} ayna yaz.
  /// Member aynası `displayName` + `email` de tutar ki Kullanıcı Yönetimi
  /// listesinde isim/email görünsün (cross-user read izni olmasın diye
  /// users dokümanını değil members aynasını okuyoruz).
  Future<void> _writeMembership(
    String uid,
    MembershipModel m, {
    required String displayName,
    required String email,
  }) async {
    final batch = _db.batch();
    batch.set(
      _db.collection('users').doc(uid).collection('memberships').doc(m.farmId),
      m.toMap(),
    );
    batch.set(
      _db.collection('farms').doc(m.farmId).collection('members').doc(uid),
      {
        ...m.toMap(),
        'uid': uid,
        'displayName': displayName,
        'email': email.toLowerCase(),
      },
    );
    await batch.commit();
  }

  /// Login sonrası ya da profil güncelleme sonrası: kullanıcının tüm
  /// member ayna belgelerinde displayName + email güncel olsun diye sync.
  /// Eski kayıtlar için de self-healing — kullanıcı her girişte isim senkron olur.
  Future<void> _syncMyMemberDocs() async {
    final user = _currentUser;
    if (user == null || user.memberships.isEmpty) return;
    try {
      final batch = _db.batch();
      var any = false;
      for (final farmId in user.memberships.keys) {
        batch.set(
          _db.collection('farms').doc(farmId).collection('members').doc(user.uid),
          {
            'displayName': user.displayName,
            'email': user.email.toLowerCase(),
            'uid': user.uid,
          },
          SetOptions(merge: true),
        );
        any = true;
      }
      if (any) await batch.commit();
    } catch (e) {
      debugPrint('[AuthService._syncMyMemberDocs] $e');
    }
    // Çiftlik isimleri eski kalmış olabilir — kaynaktan tazele
    await _syncFarmNamesToMemberships();
  }

  /// Çiftlik adlarını users/{uid}/memberships/{farmId} doc'una sync.
  /// `farms/{farmId}.name` kaynak — owner çiftliği yeniden adlandırırsa
  /// veya membership eski snapshot içeriyorsa (örn. vet daveti boş geldiyse)
  /// burada düzelir. Self-healing — best-effort, hata olursa sessizce geçer.
  Future<void> _syncFarmNamesToMemberships() async {
    final user = _currentUser;
    if (user == null || user.memberships.isEmpty) return;
    try {
      final batch = _db.batch();
      final updated = <String, MembershipModel>{};
      var any = false;
      for (final entry in user.memberships.entries) {
        final farmId = entry.key;
        final m = entry.value;
        try {
          final fd = await _db.collection('farms').doc(farmId).get();
          final fresh = (fd.data()?['name'] as String?)?.trim();
          if (fresh != null && fresh.isNotEmpty && fresh != m.farmName) {
            final updatedM = m.copyWith(farmName: fresh);
            updated[farmId] = updatedM;
            batch.set(
              _db.collection('users').doc(user.uid)
                  .collection('memberships').doc(farmId),
              {'farmName': fresh},
              SetOptions(merge: true),
            );
            any = true;
          }
        } catch (_) {/* Tek farm okunamadı — diğerlerine devam */}
      }
      if (any) {
        await batch.commit();
        // In-memory state'i de güncelle
        final merged = <String, MembershipModel>{...user.memberships};
        for (final e in updated.entries) {
          merged[e.key] = e.value;
        }
        _currentUser = user.copyWith(memberships: merged);
        await _cacheUser(_currentUser!);
        _userController.add(_currentUser);
      }
    } catch (e) {
      debugPrint('[AuthService._syncFarmNamesToMemberships] $e');
    }
  }

  /// Aktif kullanıcının tüm memberships'lerini Firestore'dan yükler.
  Future<Map<String, MembershipModel>> loadMemberships(String uid) async {
    try {
      final snap = await _db
          .collection('users')
          .doc(uid)
          .collection('memberships')
          .get();
      return <String, MembershipModel>{
        for (final d in snap.docs) d.id: MembershipModel.fromMap(d.data()),
      };
    } catch (e) {
      debugPrint('[AuthService.loadMemberships] $e');
      return <String, MembershipModel>{};
    }
  }

  /// Legacy kullanıcı migrasyonu — scalar farmId var ama memberships yok ise
  /// eskisini memberships'e aktarır. Bir kere çalışır, sonra no-op.
  Future<Map<String, MembershipModel>> _migrateLegacyIfNeeded(
      String uid, Map<String, dynamic> userDocData) async {
    final memberships = await loadMemberships(uid);
    if (memberships.isNotEmpty) return memberships;

    final legacyFarmId = userDocData['farmId'] as String?;
    if (legacyFarmId == null || legacyFarmId.isEmpty) return memberships;

    // Farm adını çek
    String farmName = 'Çiftliğim';
    try {
      final farmDoc = await _db.collection('farms').doc(legacyFarmId).get();
      farmName = (farmDoc.data()?['name'] as String?) ?? farmName;
    } catch (_) {}

    final m = MembershipModel(
      farmId: legacyFarmId,
      farmName: farmName,
      role: (userDocData['role'] as String?) ?? AppConstants.roleWorker,
      isActive: (userDocData['isActive'] as bool?) ?? true,
      joinedAt: DateTime.tryParse(userDocData['createdAt'] as String? ?? '') ?? DateTime.now(),
    );
    try {
      await _writeMembership(uid, m,
          displayName: (userDocData['displayName'] as String?) ?? '',
          email: (userDocData['email'] as String?) ?? '');
      await _db.collection('users').doc(uid).update({
        'activeFarmId': legacyFarmId,
      });
    } catch (e) {
      debugPrint('[AuthService._migrateLegacy] $e');
    }
    return {legacyFarmId: m};
  }

  // ─── Kullanıcı davet et (sahip/ortak tarafından) ─────────────────────────

  /// Rol başına maksimum kullanıcı sayısı (abonelik kısıtlaması).
  /// Ana Sahip çiftliği oluşturan tek kişidir (+1), davet edilen diğer roller
  /// için ayrı kota uygulanır. Toplam: 1 (owner) + 2 + 3 + 8 + 2 = 16
  static const Map<String, int> maxPerRole = {
    AppConstants.roleAssistant: 2,
    AppConstants.rolePartner:   3,
    AppConstants.roleWorker:    8,
    AppConstants.roleVet:       2,
  };

  /// Çiftlik başına toplam maksimum kullanıcı sayısı (tüm roller dahil).
  static int get maxUsersPerFarm =>
      1 + maxPerRole.values.fold<int>(0, (a, b) => a + b);

  /// Belirli bir rol için güncel doluluk: {'used': x, 'max': y, 'available': z}.
  /// UI kullanıcı yönetimi panelinde rol rozetlerini göstermek için kullanılır.
  Future<Map<String, int>> getRoleQuotaFor(String role) async {
    final farmId = _currentUser?.activeFarmId;
    if (farmId == null) return {'used': 0, 'max': 0, 'available': 0};
    final max = maxPerRole[role] ?? 0;
    try {
      final memberSnap = await _db
          .collection('farms').doc(farmId)
          .collection('members')
          .where('role', isEqualTo: role)
          .where('isActive', isEqualTo: true)
          .get();
      final pendingSnap = await _db
          .collection('invitations')
          .where('farmId', isEqualTo: farmId)
          .where('role', isEqualTo: role)
          .where('status', isEqualTo: InvitationStatus.pending)
          .get();
      final used = memberSnap.docs.length + pendingSnap.docs.length;
      return {
        'used': used,
        'max': max,
        'available': (max - used).clamp(0, max),
      };
    } catch (e) {
      debugPrint('[AuthService.getRoleQuotaFor] $e');
      return {'used': 0, 'max': max, 'available': max};
    }
  }

  /// Tüm rollerin kotasını tek seferde getir (quota ekranı için).
  Future<Map<String, Map<String, int>>> getAllRoleQuotas() async {
    final result = <String, Map<String, int>>{};
    for (final role in maxPerRole.keys) {
      result[role] = await getRoleQuotaFor(role);
    }
    return result;
  }

  /// Veteriner davet akışı.
  ///
  /// Vet'ler çoklu çiftlik çalışabildiği için Firebase Auth kaydını kendileri
  /// oluşturmalı. Owner yalnızca invitation kaydı oluşturur.
  ///
  /// Dönüş: isRegistered = email zaten uygulamada kayıtlı mı?
  /// - true  → vet uygulamasında davet banner'ı görünür
  /// - false → owner'a "kullanıcı kayıtlı değil, mail daveti göndereceğiz" uyarısı gösterilir
  Future<VetInvitationResult> inviteVet({
    required String email,
    required String displayName,
  }) async {
    final currentUser = _currentUser;
    if (currentUser == null) {
      return VetInvitationResult.error('Oturum açılmamış');
    }
    if (!currentUser.canManageUsers) {
      return VetInvitationResult.error('Kullanıcı ekleme yetkisi yalnızca Ana Sahip\'e aittir');
    }
    final activeFarmId = currentUser.activeFarmId;
    if (activeFarmId == null) {
      return VetInvitationResult.error('Aktif çiftlik seçilmemiş');
    }

    final emailLc = email.trim().toLowerCase();
    if (emailLc.isEmpty || !emailLc.contains('@')) {
      return VetInvitationResult.error('Geçerli bir e-posta giriniz');
    }

    // Quota + duplicate check (vet kotası)
    final quotaErr = await _checkInviteQuota(
      activeFarmId, emailLc, role: AppConstants.roleVet);
    if (quotaErr != null) return VetInvitationResult.error(quotaErr);

    // Email sistemde kayıtlı mı? Firestore'daki users koleksiyonunda email alanıyla sorgu.
    // (Firebase Auth'un fetchSignInMethodsForEmail'i enumeration protection açıkken
    // boş liste dönebiliyor — onun yerine Firestore'dan bakıyoruz.)
    bool isRegistered = false;
    try {
      final userQuery = await _db
          .collection('users')
          .where('email', isEqualTo: emailLc)
          .limit(1)
          .get();
      isRegistered = userQuery.docs.isNotEmpty;
    } catch (e) {
      debugPrint('[AuthService.inviteVet] firestore email lookup: $e');
      // Kontrol başarısız — yine de davet oluşturup owner'a mail önerisi sunarız
    }

    try {
      final invitation = InvitationModel(
        email: emailLc,
        farmId: activeFarmId,
        farmName: currentUser.activeMembership?.farmName ?? '',
        role: AppConstants.roleVet,
        invitedBy: currentUser.uid,
        invitedByName: currentUser.displayName,
        createdAt: DateTime.now(),
        status: InvitationStatus.pending,
      );
      await _db.collection('invitations').add(invitation.toMap());
      return VetInvitationResult(
        success: true,
        isRegistered: isRegistered,
        email: emailLc,
        displayName: displayName,
        farmName: currentUser.activeMembership?.farmName ?? '',
        ownerName: currentUser.displayName,
      );
    } catch (e) {
      debugPrint('[AuthService.inviteVet] write: $e');
      return VetInvitationResult.error('Davet gönderilemedi: $e');
    }
  }

  /// Yardımcı / Ortak / Personel — owner şifre belirleyip doğrudan hesap oluşturur.
  /// Vet bu akışta kullanılamaz (vet kendi hesabını kayıt akışıyla açar).
  Future<AuthResult> inviteUserWithPassword({
    required String email,
    required String displayName,
    required String role,
    required String password,
  }) async {
    if (role == AppConstants.roleVet) {
      return AuthResult.error('Veteriner için inviteVet kullanın');
    }
    final currentUser = _currentUser;
    if (currentUser == null) return AuthResult.error('Oturum açılmamış');
    if (!currentUser.canManageUsers) {
      return AuthResult.error('Kullanıcı ekleme yetkisi yalnızca Ana Sahip\'e aittir');
    }
    final activeFarmId = currentUser.activeFarmId;
    if (activeFarmId == null) return AuthResult.error('Aktif çiftlik seçilmemiş');

    final emailLc = email.trim().toLowerCase();
    if (emailLc.isEmpty || !emailLc.contains('@')) {
      return AuthResult.error('Geçerli bir e-posta giriniz');
    }
    if (password.length < 6) {
      return AuthResult.error('Şifre en az 6 karakter olmalı');
    }

    final quotaErr = await _checkInviteQuota(activeFarmId, emailLc, role: role);
    if (quotaErr != null) return AuthResult.error(quotaErr);

    FirebaseApp? secondaryApp;
    try {
      // Secondary app yalnızca Auth hesap oluşturma için kullanılır; owner'ın
      // oturumunu bozmadan yeni kullanıcı açmaya yarar. Firestore yazımları
      // owner'ın ana _db'si ile yapılır (rules hasFullControl'a izin veriyor).
      secondaryApp = await Firebase.initializeApp(
        name: 'secondary_auth_${DateTime.now().millisecondsSinceEpoch}',
        options: Firebase.app().options,
      );
      final secondaryAuth = FirebaseAuth.instanceFor(app: secondaryApp);

      final credential = await secondaryAuth.createUserWithEmailAndPassword(
        email: emailLc,
        password: password,
      );
      final newUser = credential.user;
      if (newUser == null) return AuthResult.error('Kullanıcı oluşturulamadı');
      await newUser.updateDisplayName(displayName);

      final now = DateTime.now();
      final farmName = currentUser.activeMembership?.farmName ?? '';
      final membership = MembershipModel(
        farmId: activeFarmId,
        farmName: farmName,
        role: role,
        isActive: true,
        invitedBy: currentUser.uid,
        joinedAt: now,
      );
      final userModel = UserModel(
        uid: newUser.uid,
        email: emailLc,
        displayName: displayName,
        activeFarmId: activeFarmId,
        memberships: {activeFarmId: membership},
        createdAt: now,
      );

      // Tüm Firestore yazımları owner'ın auth bağlamında (_db) yapılır —
      // rules `hasFullControl(activeFarmId)` kontrolüyle yeni kullanıcı
      // dokümanı + memberships + members aynasına yazıma izin veriyor.
      final batch = _db.batch();
      batch.set(_db.collection('users').doc(newUser.uid), userModel.toMap());
      batch.set(
        _db.collection('users').doc(newUser.uid)
           .collection('memberships').doc(activeFarmId),
        membership.toMap(),
      );
      batch.set(
        _db.collection('farms').doc(activeFarmId)
           .collection('members').doc(newUser.uid),
        {
          ...membership.toMap(),
          'uid': newUser.uid,
          'displayName': displayName,
          'email': emailLc,
        },
      );
      await batch.commit();

      // Secondary auth oturumunu kapat — secondaryApp finally'de silinecek.
      await secondaryAuth.signOut();
      return AuthResult.success(userModel);
    } on FirebaseAuthException catch (e) {
      return AuthResult.error(_firebaseErrorMessage(e.code));
    } catch (e) {
      debugPrint('[AuthService.inviteUserWithPassword] $e');
      return AuthResult.error('Kullanıcı eklenirken hata: $e');
    } finally {
      try { await secondaryApp?.delete(); } catch (_) {}
    }
  }

  /// Geriye uyumluluk — eski çağrıları kırmasın
  @Deprecated('Use inviteUserWithPassword or inviteVet')
  Future<AuthResult> inviteUser({
    required String email,
    required String displayName,
    required String role,
  }) async {
    if (role == AppConstants.roleVet) {
      final r = await inviteVet(email: email, displayName: displayName);
      if (r.success) {
        return AuthResult.success(UserModel(
          uid: '',
          email: r.email,
          displayName: r.displayName,
          createdAt: DateTime.now(),
        ));
      }
      return AuthResult.error(r.error ?? 'Davet gönderilemedi');
    }
    return AuthResult.error('Şifre gerekli — inviteUserWithPassword kullanın');
  }

  /// Kullanıcı ekleme kota + duplicate davet kontrolü.
  /// [role] verilirse yalnızca o rol için kota uygulanır; null ise
  /// (geriye uyumluluk) sadece duplicate davet kontrolü yapılır.
  Future<String?> _checkInviteQuota(
    String farmId,
    String emailLc, {
    String? role,
  }) async {
    try {
      // Rol-bazlı kota kontrolü
      if (role != null) {
        final max = maxPerRole[role] ?? 0;
        if (max == 0) {
          return 'Bu rol için kullanıcı eklenemez';
        }
        final memberSnap = await _db
            .collection('farms').doc(farmId)
            .collection('members')
            .where('role', isEqualTo: role)
            .where('isActive', isEqualTo: true)
            .get();
        final pendingSnap = await _db
            .collection('invitations')
            .where('farmId', isEqualTo: farmId)
            .where('role', isEqualTo: role)
            .where('status', isEqualTo: InvitationStatus.pending)
            .get();
        final used = memberSnap.docs.length + pendingSnap.docs.length;
        if (used >= max) {
          final label = AppConstants.roleLabels[role] ?? role;
          return '"$label" için maksimum $max kullanıcı sınırına ulaşıldı '
                 '(bekleyen davetler dahil).';
        }
      }

      // Duplicate davet kontrolü (rol'den bağımsız)
      final dup = await _db
          .collection('invitations')
          .where('farmId', isEqualTo: farmId)
          .where('email', isEqualTo: emailLc)
          .where('status', isEqualTo: InvitationStatus.pending)
          .get();
      if (dup.docs.isNotEmpty) {
        return 'Bu e-posta için zaten bekleyen bir davet var';
      }
      return null;
    } on FirebaseException catch (e) {
      debugPrint('[_checkInviteQuota] [${e.code}] ${e.message}');
      if (e.code == 'permission-denied') {
        return 'Firestore kuralları güncel değil. Lütfen deploy edin.';
      }
      return 'Kota kontrolü yapılamadı [${e.code}]';
    } catch (e) {
      debugPrint('[_checkInviteQuota] $e');
      return 'Kota kontrolü hatası: $e';
    }
  }

  // ─── Çiftlik kullanıcılarını listele ─────────────────────────────────────

  /// Aktif çiftlikteki tüm üyeleri getirir (farms/{farmId}/members'tan).
  /// Kullanıcı yönetim ekranı için. Dönen UserModel'ler membership bazlı —
  /// role/isActive bu çiftlikteki değerdir.
  Future<List<UserModel>> getFarmUsers() async {
    final user = _currentUser;
    if (user == null || user.activeFarmId == null) return [];
    try {
      final snap = await _db
          .collection('farms')
          .doc(user.activeFarmId)
          .collection('members')
          .get();
      return snap.docs.map((d) {
        final m = d.data();
        return UserModel(
          uid: m['uid'] ?? d.id,
          email: (m['email'] ?? '').toString(),
          displayName: (m['displayName'] ?? '').toString(),
          activeFarmId: user.activeFarmId,
          memberships: <String, MembershipModel>{
            user.activeFarmId!: MembershipModel.fromMap(m),
          },
          createdAt: (m['joinedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
        );
      }).toList();
    } catch (e) {
      debugPrint('[AuthService.getFarmUsers] $e');
      return [];
    }
  }

  /// Ana Sahip/Yardımcı davet ettiği üyenin bilgilerini günceller.
  /// Güncellenen alanlar farms/{farmId}/members/{uid} aynasına yazılır.
  /// [displayName] null değilse users/{uid}.displayName de güncellenir (rules
  /// `hasFullControl` için izinli).
  /// Başarılıysa null, başarısızsa hata mesajı döner.
  Future<String?> updateMemberInfo({
    required String uid,
    String? displayName,
    String? phone,
    String? notes,
  }) async {
    final farmId = _currentUser?.activeFarmId;
    if (farmId == null) return 'Aktif çiftlik yok';
    if (displayName == null && phone == null && notes == null) return null;
    try {
      final batch = _db.batch();
      final memberData = <String, dynamic>{};
      if (displayName != null) memberData['displayName'] = displayName.trim();
      if (phone != null) memberData['phone'] = phone.trim().isEmpty ? null : phone.trim();
      if (notes != null) memberData['notes'] = notes.trim().isEmpty ? null : notes.trim();
      if (memberData.isNotEmpty) {
        batch.update(
          _db.collection('farms').doc(farmId).collection('members').doc(uid),
          memberData,
        );
      }
      // users/{uid}.displayName — rules izin veriyor (hasFullControl bu çiftlik için)
      if (displayName != null) {
        batch.update(
          _db.collection('users').doc(uid),
          {'displayName': displayName.trim()},
        );
      }
      await batch.commit();
      return null;
    } catch (e) {
      debugPrint('[AuthService.updateMemberInfo] $e');
      return 'Bilgi güncellenemedi: $e';
    }
  }

  /// Ana Sahip/Yardımcı davet ettiği kullanıcıya şifre sıfırlama e-postası
  /// gönderir — kullanıcı kendi şifresini değiştirir. (Admin SDK olmadığı için
  /// client tarafında doğrudan şifre değiştirilemez.)
  Future<String?> sendPasswordResetForMember(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email.trim());
      return null;
    } on FirebaseAuthException catch (e) {
      return _firebaseErrorMessage(e.code);
    } catch (e) {
      return 'Şifre sıfırlama gönderilemedi: $e';
    }
  }

  Future<void> updateUserRole(String uid, String newRole) async {
    final farmId = _currentUser?.activeFarmId;
    if (farmId == null) return;
    final batch = _db.batch();
    batch.update(
      _db.collection('users').doc(uid).collection('memberships').doc(farmId),
      {'role': newRole},
    );
    batch.update(
      _db.collection('farms').doc(farmId).collection('members').doc(uid),
      {'role': newRole},
    );
    await batch.commit();
  }

  Future<void> deactivateUser(String uid) async {
    final farmId = _currentUser?.activeFarmId;
    if (farmId == null) return;
    final batch = _db.batch();
    batch.update(
      _db.collection('users').doc(uid).collection('memberships').doc(farmId),
      {'isActive': false},
    );
    batch.update(
      _db.collection('farms').doc(farmId).collection('members').doc(uid),
      {'isActive': false},
    );
    await batch.commit();
  }

  Future<void> activateUser(String uid) async {
    final farmId = _currentUser?.activeFarmId;
    if (farmId == null) return;
    final batch = _db.batch();
    batch.update(
      _db.collection('users').doc(uid).collection('memberships').doc(farmId),
      {'isActive': true},
    );
    batch.update(
      _db.collection('farms').doc(farmId).collection('members').doc(uid),
      {'isActive': true},
    );
    await batch.commit();
  }

  /// Kullanıcı kendi profili bilgilerini günceller (displayName).
  /// Email değiştirilemez (Firebase Auth kimliği).
  Future<String?> updateMyProfile({required String newDisplayName}) async {
    final user = _currentUser;
    if (user == null) return 'Oturum açık değil';
    final trimmed = newDisplayName.trim();
    if (trimmed.isEmpty) return 'Ad soyad boş olamaz';
    if (trimmed == user.displayName) return null; // değişiklik yok

    try {
      // Firestore users doc
      await _db.collection('users').doc(user.uid).update({'displayName': trimmed});
      // Firebase Auth displayName
      await _auth.currentUser?.updateDisplayName(trimmed);

      // Tüm membership aynalarını da güncelle (farms/{farmId}/members/{uid}.displayName)
      final batch = _db.batch();
      for (final farmId in user.memberships.keys) {
        batch.update(
          _db.collection('farms').doc(farmId).collection('members').doc(user.uid),
          {'displayName': trimmed},
        );
      }
      await batch.commit();

      _currentUser = user.copyWith(displayName: trimmed);
      await _cacheUser(_currentUser!);
      _userController.add(_currentUser);
      return null;
    } catch (e) {
      debugPrint('[AuthService.updateMyProfile] $e');
      return 'Güncellenemedi: $e';
    }
  }

  /// Kullanıcı kendi isteğiyle bir çiftlikten ayrılır.
  /// Aktif çiftlikse: başka aktif çiftliğe geç, yoksa activeFarmId=null (FarmPicker).
  /// Ana Sahip bu yöntemi kullanamaz (çiftliği kapatmak için ayrı bir akış gerekir).
  Future<String?> leaveFarm(String farmId) async {
    final user = _currentUser;
    if (user == null) return 'Oturum açık değil';
    final membership = user.memberships[farmId];
    if (membership == null) return 'Bu çiftliğin üyesi değilsiniz';
    if (membership.role == AppConstants.roleOwner) {
      return 'Ana Sahip çiftlikten ayrılamaz — önce çiftliği devretmeli veya silmelisiniz';
    }

    try {
      final batch = _db.batch();
      batch.delete(_db.collection('users').doc(user.uid).collection('memberships').doc(farmId));
      batch.delete(_db.collection('farms').doc(farmId).collection('members').doc(user.uid));
      await batch.commit();

      // Aktif çiftlik bu ise başka aktif membership'e geç (listener otomatik halleder)
      // Yine de manuel olarak currentUser'ı güncelleyelim
      final updatedMemberships = {...user.memberships}..remove(farmId);
      if (user.activeFarmId == farmId) {
        final firstActive = updatedMemberships.values
            .where((m) => m.isActive)
            .firstOrNull;
        final newActiveFarm = firstActive?.farmId;
        await _db.collection('users').doc(user.uid).update({
          'activeFarmId': newActiveFarm,
          'farmId': newActiveFarm ?? '',
        });
        _currentUser = user.copyWith(
          activeFarmId: newActiveFarm,
          memberships: updatedMemberships,
        );
      } else {
        _currentUser = user.copyWith(memberships: updatedMemberships);
      }
      await _cacheUser(_currentUser!);
      _userController.add(_currentUser);
      return null;
    } catch (e) {
      debugPrint('[AuthService.leaveFarm] $e');
      return 'Çiftlikten ayrılma başarısız: $e';
    }
  }

  /// Owner kullanıcıyı kalıcı silme akışı — kapsamlı temizlik.
  ///
  /// Doğru sıralama (rules `resource.data.activeFarmId` üzerinden kontrol
  /// yaptığı için users doc'u **önce** silinmeli — membership silinince
  /// activeFarmId hâlâ ayakta ama bazı listener akışlarında değişebilir):
  ///
  /// 1. Email'i çiftlik member ayna'dan oku (sonraki adımlar için)
  /// 2. Pending davetleri sil
  /// 3. **users/{uid} doc'u sil** (rules: hasFullControl(activeFarmId))
  /// 4. Membership + farm member ayna sil
  /// 5. Subscription state sil (best-effort)
  ///
  /// Dönüş değeri:
  /// - `null`: Tam başarı (Firebase'de hiç iz kalmadı)
  /// - String: Kısmi başarı (kullanıcı çiftlikten çıkarıldı ama users doc kaldı).
  ///   Rules deploy edilmediyse veya kullanıcı başka çiftlikte aktif ise döner.
  Future<String?> deleteUser(String uid) async {
    final farmId = _currentUser?.activeFarmId;
    if (farmId == null) return 'Aktif çiftlik bulunamadı';

    // 1) Email'i önce oku — member ayna silinmeden (invitations cleanup için)
    String? userEmail;
    try {
      final memberDoc = await _db.collection('farms').doc(farmId)
          .collection('members').doc(uid).get();
      userEmail = (memberDoc.data()?['email'] as String?)?.toLowerCase();
    } catch (e) {
      debugPrint('[deleteUser] member email read: $e');
    }

    // 2) Pending davetleri temizle (best-effort)
    if (userEmail != null && userEmail.isNotEmpty) {
      try {
        final invites = await _db.collection('invitations')
            .where('email', isEqualTo: userEmail)
            .where('farmId', isEqualTo: farmId)
            .get();
        var failedCount = 0;
        for (final d in invites.docs) {
          try {
            await d.reference.delete();
          } catch (e, st) {
            failedCount++;
            AppLogger.error('deleteUser.inviteDelete', e, st,
                context: {'inviteId': d.id});
          }
        }
        if (failedCount > 0) {
          AppLogger.warn('deleteUser.invitations',
              '$failedCount invitation(s) could not be deleted');
        }
      } catch (e, st) {
        AppLogger.error('deleteUser.invitationsCleanup', e, st);
      }
    }

    // 3) KRİTİK SIRA: users/{uid} doc'u ÖNCE sil
    // Rules: resource.data.activeFarmId == bizim çiftliğimiz ise owner siler.
    // Bu adım membership silinmeden önce yapılmalı — listener akışında
    // activeFarmId değişebilir.
    String? warnMessage;
    try {
      await _db.collection('users').doc(uid).delete();
      debugPrint('[deleteUser] users/{uid} doc deleted ✓');
    } on FirebaseException catch (e) {
      if (e.code == 'permission-denied') {
        warnMessage = 'Firebase kuralları güncel değil. Komut çalıştırın:\n'
            'firebase deploy --only firestore:rules';
        debugPrint('[deleteUser] PERMISSION DENIED — rules güncel değil veya activeFarmId farklı');
      } else {
        warnMessage = 'Hesap dokümanı silinemedi: ${e.code}';
        debugPrint('[deleteUser] users doc delete: ${e.code} - ${e.message}');
      }
    } catch (e) {
      warnMessage = 'Hesap dokümanı silinemedi: $e';
      debugPrint('[deleteUser] users doc delete: $e');
    }

    // 4) Membership + farm member ayna sil (kritik — fail ederse rethrow)
    try {
      final batch = _db.batch();
      batch.delete(
        _db.collection('users').doc(uid).collection('memberships').doc(farmId),
      );
      batch.delete(
        _db.collection('farms').doc(farmId).collection('members').doc(uid),
      );
      await batch.commit();
      debugPrint('[deleteUser] membership + ayna deleted ✓');
    } catch (e) {
      debugPrint('[AuthService.deleteUser] membership delete failed: $e');
      rethrow;
    }

    // 5) Subscription subcollection sil (rules sadece self izniyor — best-effort)
    try {
      await _db.collection('users').doc(uid)
          .collection('subscription').doc('current').delete();
    } catch (_) {}

    return warnMessage;
  }

  /// Orphan kullanıcı temizleme — Firestore Console'dan veya başka yerden
  /// users/{uid} doc'u silmek isteyen owner için. Sadece o kullanıcının
  /// activeFarmId'si bizim çiftlikse silebilir (rules guard).
  Future<String?> forceCleanupOrphanUser(String uid) async {
    try {
      await _db.collection('users').doc(uid).delete();
      return null;
    } on FirebaseException catch (e) {
      if (e.code == 'permission-denied') {
        return 'Yetki yok — Firebase kuralları güncel değil veya kullanıcı '
            'başka çiftliğe taşınmış.';
      }
      return 'Hata: ${e.code}';
    } catch (e) {
      return 'Hata: $e';
    }
  }

  // ─── Kayıtlı bilgiler (Beni Hatırla için) ────────────────────────────────

  Future<String?> getSavedEmail() async {
    final prefs = await SharedPreferences.getInstance();
    if (!(prefs.getBool('remember_me') ?? false)) return null;
    final cached = await _loadCachedUser();
    return cached?.email;
  }

  Future<String?> getSavedPassword() async {
    final prefs = await SharedPreferences.getInstance();
    if (!(prefs.getBool('remember_me') ?? false)) return null;
    return _secureStorage.read(key: 'saved_password');
  }

  // ─── Şifre sıfırlama ─────────────────────────────────────────────────────

  Future<String?> sendPasswordReset(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email.trim());
      return null;
    } on FirebaseAuthException catch (e) {
      return _firebaseErrorMessage(e.code);
    }
  }

  // ─── Çıkış ───────────────────────────────────────────────────────────────

  /// KVKK uyumu — kullanıcının tüm kişisel verilerini siler.
  ///
  /// Akış:
  /// 1. Kullanıcı re-authentication yapar (şifre ile — hassas işlem)
  /// 2. Owner ise: çiftliği ve tüm altındaki veriyi (animals, milking, finance,
  ///    tasks, leave_requests, members, vet_requests, notifications) siler.
  ///    Yardımcı/Ortak/Vet/Personel: sadece kendi üyeliklerini kaldırır.
  /// 3. `users/{uid}` ve subcollection'ları siler
  /// 4. Tüm kesin davetleri (email eşleşen) siler
  /// 5. Firebase Auth hesabını siler
  /// 6. Local cache temizlenir
  ///
  /// Başarılıysa null döner; aksi halde kullanıcıya gösterilecek hata mesajı.
  Future<String?> deleteMyAccount({required String currentPassword}) async {
    final user = _currentUser;
    final fbUser = _auth.currentUser;
    if (user == null || fbUser == null) return 'Oturum açılmamış';

    try {
      // 1) Re-authenticate (son 5 dakika içinde giriş yapılmışsa atlanabilir
      // ama güvenlik için her durumda isteyelim)
      final credential = EmailAuthProvider.credential(
        email: user.email,
        password: currentPassword,
      );
      await fbUser.reauthenticateWithCredential(credential);

      // 2) Firestore verilerini temizle
      for (final entry in user.memberships.entries) {
        final farmId = entry.key;
        final m = entry.value;
        if (m.role == AppConstants.roleOwner) {
          // Owner → çiftliği tamamen sil
          await _deleteFarmAndData(farmId);
        } else {
          // Üye olarak ayrıl: memberships + farm members aynası
          final batch = _db.batch();
          batch.delete(
            _db.collection('users').doc(user.uid).collection('memberships').doc(farmId),
          );
          batch.delete(
            _db.collection('farms').doc(farmId).collection('members').doc(user.uid),
          );
          await batch.commit();
        }
      }

      // 3) Kendi kullanıcı dokümanı
      try {
        await _db.collection('users').doc(user.uid).delete();
      } catch (e) {
        debugPrint('[deleteMyAccount] user doc delete: $e');
      }

      // 4) Bu email'e gelen tüm davetleri sil
      try {
        final invites = await _db
            .collection('invitations')
            .where('email', isEqualTo: user.email.toLowerCase())
            .get();
        final batch = _db.batch();
        for (final d in invites.docs) {
          batch.delete(d.reference);
        }
        if (invites.docs.isNotEmpty) await batch.commit();
      } catch (e) {
        debugPrint('[deleteMyAccount] invitations delete: $e');
      }

      // 5) Firebase Auth hesabını sil
      await fbUser.delete();

      // 6) Local cache
      _stopUserDocListener();
      await _clearCache();
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('remember_me', false);
      _currentUser = null;
      _userController.add(null);

      return null;
    } on FirebaseAuthException catch (e) {
      if (e.code == 'wrong-password' || e.code == 'invalid-credential') {
        return 'Şifre yanlış';
      }
      if (e.code == 'requires-recent-login') {
        return 'Güvenlik için tekrar giriş yapın ve yeniden deneyin';
      }
      return _firebaseErrorMessage(e.code);
    } catch (e) {
      debugPrint('[AuthService.deleteMyAccount] $e');
      return 'Hesap silinemedi: $e';
    }
  }

  /// Çiftlik ve altındaki tüm veriyi siler (owner silme akışı).
  /// Subcollection'ları tek tek temizler — Firestore otomatik recursive delete
  /// yapmaz (Admin SDK gerekir), client tarafında batch'lerle siliyoruz.
  Future<void> _deleteFarmAndData(String farmId) async {
    final farmRef = _db.collection('farms').doc(farmId);
    final subcollections = [
      'members', 'animals', 'calves', 'milking', 'bulk_milking',
      'health', 'vaccines', 'finance', 'feed_stock', 'feed_transactions',
      'equipment', 'staff', 'notifications', 'vet_requests',
      'tasks', 'leave_requests',
    ];

    for (final sub in subcollections) {
      try {
        final snap = await farmRef.collection(sub).get();
        // Her batch max 500 write — büyük koleksiyonlar için segmentlere böl
        const chunk = 400;
        for (var i = 0; i < snap.docs.length; i += chunk) {
          final batch = _db.batch();
          final end = (i + chunk).clamp(0, snap.docs.length);
          for (var j = i; j < end; j++) {
            batch.delete(snap.docs[j].reference);
          }
          await batch.commit();
        }
      } catch (e) {
        debugPrint('[_deleteFarmAndData] $sub: $e');
      }
    }

    // Çiftlik dokümanı
    try {
      await farmRef.delete();
    } catch (e) {
      debugPrint('[_deleteFarmAndData] farm doc: $e');
    }

    // users/*/memberships/{farmId} — bu çiftlikteki tüm membership referanslarını
    // temizlemek için collectionGroup query (kendi uid'im değilken de silmek
    // için rules izin vermeyebilir — best effort).
    try {
      final memSnap = await _db
          .collectionGroup('memberships')
          .where('farmId', isEqualTo: farmId)
          .get();
      var failed = 0;
      for (final d in memSnap.docs) {
        try {
          await d.reference.delete();
        } catch (e, st) {
          failed++;
          AppLogger.error('_deleteFarmAndData.membershipDelete', e, st,
              context: {'docId': d.id, 'farmId': farmId});
        }
      }
      if (failed > 0) {
        AppLogger.warn('_deleteFarmAndData',
            '$failed membership(s) could not be deleted for farm $farmId');
      }
    } catch (e, st) {
      AppLogger.error('_deleteFarmAndData.membershipsCleanup', e, st,
          context: {'farmId': farmId});
    }
  }

  Future<void> signOut() async {
    _stopUserDocListener();
    // SQLite cihaz cache'ini temizle — sonraki kullanıcı temiz başlasın
    try {
      await DatabaseHelper.instance.resetAllData();
    } catch (e, st) {
      AppLogger.error('AuthService.signOut.sqliteReset', e, st);
    }
    await _auth.signOut();
    await _clearCache();
    final prefs = await SharedPreferences.getInstance();
    // Last-known-uid marker'ını da temizle
    await prefs.remove('auth_last_known_uid');
    await prefs.setBool('remember_me', false);
    _currentUser = null;
    _userController.add(null);
    // Crashlytics + Analytics user marker'larını temizle
    unawaited(AppLogger.setUserId(null));
    unawaited(AnalyticsService.instance.clearUser());
  }

  /// Tüm cihazlarda oturum sonlandırma.
  ///
  /// Firebase Auth client-side "revoke all sessions" fonksiyonu sağlamaz
  /// (Admin SDK gerekir). Bunun yerine: users/{uid}.sessionVersion alanını
  /// artırıp tüm aktif client'ların kendi kullanıcı doc listener'ında bunu
  /// yakalayıp otomatik çıkış yapmasını sağlıyoruz.
  ///
  /// Mantık: Her cihaz, giriş anında sessionVersion'ı SharedPreferences'a
  /// kaydeder. User doc'ta versiyon artınca listener uyanır, local cache
  /// ile karşılaştırır, farklıysa zorla signOut tetikler.
  Future<String?> signOutAllDevices() async {
    final user = _currentUser;
    if (user == null) return 'Oturum açılmamış';
    try {
      final newVersion = DateTime.now().millisecondsSinceEpoch;
      await _db.collection('users').doc(user.uid).update({
        'sessionVersion': newVersion,
      });
      // Bu cihazda da hemen çık
      await signOut();
      return null;
    } catch (e) {
      debugPrint('[AuthService.signOutAllDevices] $e');
      return 'Oturumlar sonlandırılamadı: $e';
    }
  }

  // ─── Firestore'dan kullanıcı çek ─────────────────────────────────────────

  Future<UserModel?> _fetchUserFromFirestore(String uid) async {
    final doc = await _db.collection('users').doc(uid).get();
    if (!doc.exists) return null;
    final data = doc.data()!;
    // Memberships'leri yükle (yoksa legacy migrasyon)
    final memberships = await _migrateLegacyIfNeeded(uid, data);
    return UserModel.fromMap(data, memberships: memberships);
  }

  // ─── Cache ───────────────────────────────────────────────────────────────

  Future<void> _cacheUser(UserModel user) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('cached_user', jsonEncode(user.toMap()));
  }

  Future<UserModel?> _loadCachedUser() async {
    final prefs = await SharedPreferences.getInstance();
    final json = prefs.getString('cached_user');
    if (json == null) return null;
    try {
      return UserModel.fromMap(jsonDecode(json));
    } catch (_) {
      return null;
    }
  }

  Future<void> _clearCache() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('cached_user');
    await _secureStorage.delete(key: 'saved_password');
  }

  /// Cihazdaki SQLite verilerinin önceki kullanıcıya ait olma riski varsa sıfırla.
  ///
  /// Senaryo: Telefonu A kullanıcısı kullandı, çıkış yapmadan B kullanıcısı
  /// kayıt oldu/giriş yaptı. SQLite local olduğu için B, A'nın hayvan/finans
  /// kayıtlarını görür. Bu metot last-known-uid karşılaştırarak SQLite'ı
  /// gereken durumlarda sıfırlar.
  ///
  /// [newUid] yeni giriş yapan kullanıcının uid'i. null ise (signOut)
  /// last_known_uid silinir; SQLite olduğu gibi kalır (ileride aynı kullanıcı
  /// tekrar girerse sıfırlanmaz).
  Future<void> _resetLocalIfUserChanged(String? newUid) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      const keyLastUid = 'auth_last_known_uid';
      final lastUid = prefs.getString(keyLastUid);

      if (newUid == null) {
        // Çıkış akışı — sadece marker'ı temizle. SQLite'a dokunma; aynı
        // kullanıcı tekrar girerse veriyi tekrar görür.
        await prefs.remove(keyLastUid);
        return;
      }

      final shouldReset = lastUid != null && lastUid != newUid;
      if (shouldReset) {
        debugPrint('[AuthService] User changed ($lastUid → $newUid) — resetting SQLite');
        await DatabaseHelper.instance.resetAllData();
      }
      await prefs.setString(keyLastUid, newUid);
    } catch (e) {
      debugPrint('[AuthService._resetLocalIfUserChanged] $e');
    }
  }

  // ─── Firebase hata mesajları Türkçe ──────────────────────────────────────

  String _firebaseErrorMessage(String code) {
    switch (code) {
      case 'user-not-found': return 'Bu e-posta ile kayıtlı kullanıcı bulunamadı';
      case 'wrong-password': return 'Şifre yanlış';
      case 'invalid-credential': return 'E-posta veya şifre hatalı';
      case 'email-already-in-use': return 'Bu e-posta zaten kullanımda';
      case 'weak-password': return 'Şifre çok zayıf — en az 8 karakter, harf ve rakam içermeli';
      case 'invalid-email': return 'Geçersiz e-posta adresi';
      case 'too-many-requests': return 'Çok fazla deneme yapıldı. Lütfen birkaç dakika bekleyin';
      case 'network-request-failed': return 'İnternet bağlantısı yok. Lütfen ağınızı kontrol edin';
      case 'user-disabled': return 'Bu hesap devre dışı bırakılmış. Destek için iletişime geçin';
      case 'permission-denied': return 'Bu işlem için yetkiniz yok';
      case 'operation-not-allowed': return 'E-posta ile giriş şu an kapalı. Lütfen daha sonra tekrar deneyin';
      case 'requires-recent-login': return 'Güvenlik için tekrar giriş yapmanız gerekiyor';
      case 'expired-action-code': return 'Bu bağlantı süresi dolmuş';
      case 'invalid-action-code': return 'Geçersiz veya kullanılmış bağlantı';
      case 'account-exists-with-different-credential':
        return 'Bu e-posta farklı bir giriş yöntemiyle kayıtlı';
      case 'unavailable': return 'Sunucuya erişilemiyor. Lütfen birazdan tekrar deneyin';
      case 'cancelled': return 'İşlem iptal edildi';
      default: return 'Bir hata oluştu. Lütfen tekrar deneyin (kod: $code)';
    }
  }

  void dispose() {
    _userController.close();
  }
}

class AuthResult {
  final UserModel? user;
  final String? errorMessage;
  final bool isOffline;

  bool get success => user != null;

  AuthResult._({this.user, this.errorMessage, this.isOffline = false});

  factory AuthResult.success(UserModel user, {bool isOffline = false}) =>
      AuthResult._(user: user, isOffline: isOffline);

  factory AuthResult.error(String message) =>
      AuthResult._(errorMessage: message);
}

/// Veteriner davetinin sonucu. isRegistered=false ise owner'a mail gönderme
/// akışı başlatılır (mailto intent).
class VetInvitationResult {
  final bool success;
  final String? error;
  final bool isRegistered;
  final String email;
  final String displayName;
  final String farmName;
  final String ownerName;

  const VetInvitationResult({
    required this.success,
    this.error,
    this.isRegistered = false,
    this.email = '',
    this.displayName = '',
    this.farmName = '',
    this.ownerName = '',
  });

  factory VetInvitationResult.error(String msg) =>
      VetInvitationResult(success: false, error: msg);
}
