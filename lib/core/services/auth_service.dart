import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'dart:convert';
import '../../data/models/user_model.dart';
import '../constants/app_constants.dart';

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
          return _currentUser;
        }
      } catch (_) {}
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
      if (!userModel.isActive) return AuthResult.error('Hesabınız devre dışı bırakılmış');

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

      final farmId = _db.collection('farms').doc().id;

      // Önce kullanıcı kaydı (farm kuralı belongsToFarm'a bağlı sub-koleksiyonlar için)
      final userModel = UserModel(
        uid: user.uid,
        email: email.trim(),
        displayName: ownerName,
        role: AppConstants.roleOwner,
        farmId: farmId,
        createdAt: DateTime.now(),
      );
      await _db.collection('users').doc(user.uid).set(userModel.toMap());

      // Sonra çiftlik kaydı
      await _db.collection('farms').doc(farmId).set({
        'name': farmName,
        'ownerId': user.uid,
        'createdAt': FieldValue.serverTimestamp(),
      });

      _currentUser = userModel;
      await _cacheUser(userModel);
      _userController.add(_currentUser);
      return AuthResult.success(userModel);
    } on FirebaseAuthException catch (e) {
      return AuthResult.error(_firebaseErrorMessage(e.code));
    } catch (e) {
      return AuthResult.error('Kayıt sırasında hata oluştu: $e');
    }
  }

  // ─── Kullanıcı davet et (sahip/ortak tarafından) ─────────────────────────

  Future<AuthResult> inviteUser({
    required String email,
    required String displayName,
    required String role,
    required String password,
  }) async {
    final currentUser = _currentUser;
    if (currentUser == null) return AuthResult.error('Oturum açılmamış');
    if (!currentUser.canManageStaff) return AuthResult.error('Bu işlem için yetkiniz yok');

    FirebaseApp? secondaryApp;
    try {
      secondaryApp = await Firebase.initializeApp(
        name: 'secondary_auth',
        options: Firebase.app().options,
      );
      final secondaryAuth = FirebaseAuth.instanceFor(app: secondaryApp);

      final credential = await secondaryAuth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      final newUser = credential.user;
      if (newUser == null) return AuthResult.error('Kullanıcı oluşturulamadı');

      await newUser.updateDisplayName(displayName);

      final userModel = UserModel(
        uid: newUser.uid,
        email: email.trim(),
        displayName: displayName,
        role: role,
        farmId: currentUser.farmId,
        createdAt: DateTime.now(),
      );
      await _db.collection('users').doc(newUser.uid).set(userModel.toMap());

      await secondaryAuth.signOut();
      return AuthResult.success(userModel);
    } on FirebaseAuthException catch (e) {
      return AuthResult.error(_firebaseErrorMessage(e.code));
    } catch (e) {
      return AuthResult.error('Kullanıcı eklenirken hata: $e');
    } finally {
      try { await secondaryApp?.delete(); } catch (_) {}
    }
  }

  // ─── Çiftlik kullanıcılarını listele ─────────────────────────────────────

  Future<List<UserModel>> getFarmUsers() async {
    if (_currentUser == null) return [];
    try {
      final snap = await _db
          .collection('users')
          .where('farmId', isEqualTo: _currentUser!.farmId)
          .get();
      return snap.docs.map((d) => UserModel.fromMap(d.data())).toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> updateUserRole(String uid, String newRole) async {
    await _db.collection('users').doc(uid).update({'role': newRole});
  }

  Future<void> deactivateUser(String uid) async {
    await _db.collection('users').doc(uid).update({'isActive': false});
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

  Future<void> signOut() async {
    await _auth.signOut();
    await _clearCache();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('remember_me', false);
    _currentUser = null;
    _userController.add(null);
  }

  // ─── Firestore'dan kullanıcı çek ─────────────────────────────────────────

  Future<UserModel?> _fetchUserFromFirestore(String uid) async {
    final doc = await _db.collection('users').doc(uid).get();
    if (!doc.exists) return null;
    return UserModel.fromMap(doc.data()!);
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

  // ─── Firebase hata mesajları Türkçe ──────────────────────────────────────

  String _firebaseErrorMessage(String code) {
    switch (code) {
      case 'user-not-found': return 'Bu e-posta ile kayıtlı kullanıcı bulunamadı';
      case 'wrong-password': return 'Şifre yanlış';
      case 'invalid-credential': return 'E-posta veya şifre hatalı';
      case 'email-already-in-use': return 'Bu e-posta zaten kullanımda';
      case 'weak-password': return 'Şifre en az 6 karakter olmalı';
      case 'invalid-email': return 'Geçersiz e-posta adresi';
      case 'too-many-requests': return 'Çok fazla deneme. Lütfen bekleyin';
      case 'network-request-failed': return 'İnternet bağlantısı yok';
      case 'user-disabled': return 'Bu hesap devre dışı bırakılmış';
      default: return 'Bir hata oluştu ($code)';
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
