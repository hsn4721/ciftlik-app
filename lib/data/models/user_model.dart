import '../../core/constants/app_constants.dart';
import 'membership_model.dart';

/// Uygulama kullanıcısı.
///
/// Çoklu-çiftlik desteği:
/// - `memberships`: Kullanıcının tüm çiftlik üyelikleri (ör. vet birden fazla çiftlikte)
/// - `farmId` + `role` + `isActive`: Şu anda AKTİF çiftliğe göre dinamik
/// - `activeFarmId`: Firestore'da kalıcı (hangi çiftlik seçili)
///
/// Eski kod hâlâ `farmId` ve `role` kullanır — semantik olarak "aktif çiftlik"
/// bilgisini taşır. Yeni kod `memberships` üzerinden çok çiftlikli sorgu yapar.
class UserModel {
  final String uid;
  final String email;
  final String displayName;
  final DateTime createdAt;
  final String? activeFarmId;                // Kalıcı: Firestore'dan okunur
  final Map<String, MembershipModel> memberships; // farmId → membership
  /// Kayıt anındaki rol (ör. 'vet'). Davet kabul olmadığı için memberships
  /// boş olsa da kullanıcının "doğuştan" rolünü taşır. Şu an sadece vet
  /// kayıtlarında set ediliyor — diğer roller davet üzerinden gelir.
  final String? registrationRole;

  const UserModel({
    required this.uid,
    required this.email,
    required this.displayName,
    required this.createdAt,
    this.activeFarmId,
    this.memberships = const <String, MembershipModel>{},
    this.registrationRole,
  });

  // ─── Aktif çiftlik kısayolları (eski API ile uyumlu) ─────────────────────

  /// Aktif çiftlikteki üyelik — null ise henüz çiftlik seçilmemiş.
  MembershipModel? get activeMembership =>
      activeFarmId != null ? memberships[activeFarmId] : null;

  /// Eski `farmId` alanı — aktif çiftliğin id'si (null olabilir).
  String get farmId => activeFarmId ?? '';

  /// Eski `role` alanı — aktif çiftlikteki rol (üyelik yoksa default worker).
  String get role => activeMembership?.role ?? AppConstants.roleWorker;

  /// Eski `isActive` alanı — aktif çiftlikteki membership durumu.
  bool get isActive => activeMembership?.isActive ?? false;

  /// Çoklu çiftlik üyesi mi? (Çiftlik değiştirici gösterme kararı için)
  bool get hasMultipleFarms => memberships.length > 1;

  /// Aktif üyelik var mı? (Dashboard erişim kararı için)
  bool get hasAnyActiveMembership =>
      memberships.values.any((m) => m.isActive);

  // ─── Rol kontrolü ────────────────────────────────────────────────────────
  bool get isMainOwner => role == AppConstants.roleOwner;
  bool get isAssistant => role == AppConstants.roleAssistant;
  bool get isPartner   => role == AppConstants.rolePartner;
  /// Vet: ya aktif çiftlik üyeliğinde rol vet, ya da kayıt anında vet seçilmiş
  /// (henüz hiçbir çiftliğe davet kabul etmemiş freshly-registered vet).
  bool get isVet       => role == AppConstants.roleVet
      || registrationRole == AppConstants.roleVet;
  bool get isWorker    => role == AppConstants.roleWorker;

  // Geriye uyumluluk — eski kod isOwner kullanıyor
  bool get isOwner => isMainOwner;

  /// Ana Sahip veya Yardımcı — tam yetkili
  bool get hasFullControl => isMainOwner || isAssistant;

  /// Ortak rolü — tüm modülleri görür, hiçbir yerde değişiklik yapamaz
  bool get isReadOnlyViewer => isPartner;

  // ─── Modül görünürlüğü (ekran açılır mı?) ────────────────────────────────
  bool get canSeeHerd       => true; // Vet dahil tüm roller hayvanları görür
  bool get canSeeMilk       => hasFullControl || isPartner || isWorker;
  bool get canSeeHealth     => true; // Worker da kendi hayvanının sağlığını görür
  bool get canSeeCalves     => hasFullControl || isPartner || isVet; // Vet doğum + buzağı sağlığı takibi yapar
  bool get canSeeFeed       => hasFullControl || isPartner || isWorker;
  bool get canSeeFinance    => hasFullControl || isPartner;
  bool get canSeeStaff      => hasFullControl || isPartner || isWorker; // Worker kendi görevlerini görür
  bool get canSeeEquipment  => hasFullControl || isPartner;
  bool get canSeeSubsidies  => hasFullControl || isPartner;

  // ─── Modül eylemleri (ekle/düzenle/sil) ──────────────────────────────────
  // Sürü
  bool get canAddAnimal     => hasFullControl || isWorker;
  bool get canEditAnimal    => hasFullControl; // Worker değiştiremez
  bool get canRemoveAnimal  => hasFullControl; // Satış/çıkış yalnızca owner+assistant

  // Süt
  bool get canAddMilking    => hasFullControl || isWorker;
  bool get canEditMilking   => hasFullControl; // sadece owner+assistant
  bool get canSellMilk      => hasFullControl; // tank satışı
  bool get canManageTank    => hasFullControl;

  // Sağlık / Aşı
  bool get canManageHealth  => hasFullControl || isVet;

  // Yem
  bool get canAddFeedStock  => hasFullControl;
  bool get canApplyFeeding  => hasFullControl || isWorker;
  bool get canManageFeedPlan => hasFullControl;

  // Finans
  bool get canManageFinance => hasFullControl;

  // Personel & Görevler
  bool get canManageStaff   => hasFullControl;
  bool get canAssignTasks   => hasFullControl;
  bool get canReceiveTasks  => isWorker;
  bool get canRequestLeave  => isWorker || isVet;

  // Ekipman / Destekler
  bool get canManageEquipment => hasFullControl;
  bool get canManageSubsidies => hasFullControl;

  // Buzağı / Üreme — Vet sadece görüntüler (doğum listesi ve buzağı kartları),
  // yeni buzağı veya tohumlama kaydı ekleyemez. Bu kayıtlar ana sahip/yardımcı
  // sorumluluğundadır.
  bool get canManageCalves  => hasFullControl;

  // Uygulama bakımı (yedek/geri yükle/orphan temizleme)
  bool get canManageBackup  => hasFullControl;

  // Kullanıcı yönetimi — SADECE Ana Sahip
  // (Yardımcı dahil diğer roller kullanıcı ekleyemez/silemez/rol değiştiremez)
  bool get canManageUsers   => isMainOwner;

  /// Yem maliyeti (stok fiyatı, alım tutarı, günlük toplam maliyet) görür mü?
  /// Personel operasyonel personeldir, maliyet bilgisine erişmez.
  bool get canSeeFeedCost => !isWorker;

  /// Ana sayfadaki "Bu Ay Gelir" ve diğer finansal göstergeler görür mü?
  bool get canSeeIncomeStats => canSeeFinance;

  /// Ana sayfadaki KPI kartları (sürü sayıları, süt, gelir) görür mü?
  /// Veteriner sadece kendi alanını görür — bu istatistikler kapsam dışı.
  bool get canSeeFarmStats => !isVet;

  /// Doğum/yaklaşan aşı/stok/destek hatırlatıcı kartlarını görür mü?
  /// Vet doğum ve aşı hatırlatıcılarını görür (doğum sonrası aşı takibi için gerekli).
  bool get canSeeBirthReminder   => true; // Vet dahil herkes
  bool get canSeeStockReminder   => !isVet;
  bool get canSeeSubsidyReminder => !isVet && !isWorker;
  bool get canSeeVaccineReminder => true;

  /// Tam yetkili (ana sahip/yardımcı) değilse ama modülü görebiliyorsa → salt-okunur
  bool readOnlyFor(bool canManageThisModule) => !canManageThisModule;

  String get roleDisplay =>
      AppConstants.roleLabels[role] ?? role;

  String get roleDescription =>
      AppConstants.roleDescriptions[role] ?? '';

  /// Firestore dokümanına yazılacak alanlar (memberships subcollection'da ayrı).
  Map<String, dynamic> toMap() => {
    'uid': uid,
    'email': email,
    'displayName': displayName,
    'activeFarmId': activeFarmId,
    'createdAt': createdAt.toIso8601String(),
    if (registrationRole != null) 'registrationRole': registrationRole,
    // Legacy alanlar — eski sürümden yükseltilen kullanıcılar için yazılmaya devam
    // edilir; yeni kayıtlarda null kalabilir. Backward compat için koruyoruz.
    'farmId': activeFarmId ?? '',
    'role': role,
    'isActive': isActive,
  };

  /// Sadece profil bilgilerini (memberships olmadan) yükler. Memberships ayrı
  /// subcollection'dan `loadMemberships` ile yüklenir.
  factory UserModel.fromMap(Map<String, dynamic> m, {
    Map<String, MembershipModel>? memberships,
  }) => UserModel(
    uid: m['uid'] ?? '',
    email: m['email'] ?? '',
    displayName: m['displayName'] ?? '',
    activeFarmId: (m['activeFarmId'] as String?) ?? (m['farmId'] as String?),
    memberships: memberships ?? const <String, MembershipModel>{},
    registrationRole: m['registrationRole'] as String?,
    createdAt: m['createdAt'] != null
        ? DateTime.tryParse(m['createdAt']) ?? DateTime.now()
        : DateTime.now(),
  );

  UserModel copyWith({
    String? uid,
    String? email,
    String? displayName,
    String? activeFarmId,
    Map<String, MembershipModel>? memberships,
    String? registrationRole,
    DateTime? createdAt,
  }) => UserModel(
    uid: uid ?? this.uid,
    email: email ?? this.email,
    displayName: displayName ?? this.displayName,
    activeFarmId: activeFarmId ?? this.activeFarmId,
    memberships: memberships ?? this.memberships,
    registrationRole: registrationRole ?? this.registrationRole,
    createdAt: createdAt ?? this.createdAt,
  );
}
