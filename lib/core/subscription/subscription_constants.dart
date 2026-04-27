/// Abonelik paket tanımları + Apple/Google product ID'leri.
///
/// **Mağaza Kurulumu**:
/// - **App Store Connect**: bu ID'ler ile auto-renewable subscriptions oluşturulur
/// - **Play Console**: aynı ID'ler ile subscription products oluşturulur
/// - Trial: Apple/Google config'den 14 gün introductory period eklenir
class IapProductIds {
  IapProductIds._();

  // Başlangıç paketi
  static const starterMonthly = 'ciftlikpro_starter_monthly';
  static const starterYearly = 'ciftlikpro_starter_yearly';

  // Aile paketi (en popüler)
  static const familyMonthly = 'ciftlikpro_family_monthly';
  static const familyYearly = 'ciftlikpro_family_yearly';

  // Pro Premium
  static const proMonthly = 'ciftlikpro_pro_monthly';
  static const proYearly = 'ciftlikpro_pro_yearly';

  // Veteriner — yıllık tek seferlik abonelik (aylık yok)
  static const vetYearly = 'ciftlikpro_vet_yearly';

  /// Tüm aktif product ID'leri — InAppPurchase.queryProductDetails için.
  static const Set<String> allIds = {
    starterMonthly, starterYearly,
    familyMonthly, familyYearly,
    proMonthly, proYearly,
    vetYearly,
  };
}

/// Abonelik planları.
enum SubscriptionPlan {
  /// Henüz abonelik yok — ücretsiz erişimle bile kısıtlı kullanım
  none,
  /// 14 gün ücretsiz deneme — Pro tüm özellikler (yalnızca çiftlik kullanıcıları)
  trial,
  /// Başlangıç (₺79.99/ay, ₺749.99/yıl)
  starter,
  /// Aile (₺149.99/ay, ₺1399.99/yıl) — EN POPÜLER
  family,
  /// Pro Premium (₺249.99/ay, ₺2399.99/yıl)
  pro,
  /// Veteriner Profesyonel (₺299.99/yıl tek seferlik)
  vet,
}

extension SubscriptionPlanX on SubscriptionPlan {
  String get label {
    switch (this) {
      case SubscriptionPlan.none:    return 'Abonelik Yok';
      case SubscriptionPlan.trial:   return 'Ücretsiz Deneme';
      case SubscriptionPlan.starter: return 'Başlangıç';
      case SubscriptionPlan.family:  return 'Aile';
      case SubscriptionPlan.pro:     return 'Pro Premium';
      case SubscriptionPlan.vet:     return 'Veteriner Profesyonel';
    }
  }

  String get badge {
    switch (this) {
      case SubscriptionPlan.none:    return '';
      case SubscriptionPlan.trial:   return '🎁 Deneme';
      case SubscriptionPlan.starter: return '🌱 Başlangıç';
      case SubscriptionPlan.family:  return '🏠 Aile';
      case SubscriptionPlan.pro:     return '💎 Pro';
      case SubscriptionPlan.vet:     return '🩺 Veteriner';
    }
  }

  /// Pro tüm özellikler aktif (trial = pro eşdeğeri).
  bool get hasProAccess => this == SubscriptionPlan.pro || this == SubscriptionPlan.trial;
  bool get hasFamilyAccess => hasProAccess || this == SubscriptionPlan.family;
  bool get hasStarterAccess => hasFamilyAccess || this == SubscriptionPlan.starter;
  /// Vet plan aktif mi? (vet kullanıcılar için zorunlu)
  bool get hasVetAccess => this == SubscriptionPlan.vet;
  bool get isActive => this != SubscriptionPlan.none;

  /// Hayvan limiti.
  int get animalLimit {
    switch (this) {
      case SubscriptionPlan.none:    return 5;
      case SubscriptionPlan.trial:   return 999999;
      case SubscriptionPlan.starter: return 30;
      case SubscriptionPlan.family:  return 100;
      case SubscriptionPlan.pro:     return 999999;
      case SubscriptionPlan.vet:     return 0; // Vet kendi çiftlik yönetmez
    }
  }

  /// Çiftlik üye sayısı limiti (owner dahil).
  int get userLimit {
    switch (this) {
      case SubscriptionPlan.none:    return 1;
      case SubscriptionPlan.trial:   return 16;
      case SubscriptionPlan.starter: return 1;
      case SubscriptionPlan.family:  return 2;
      case SubscriptionPlan.pro:     return 16;
      case SubscriptionPlan.vet:     return 0;
    }
  }
}

/// Belirli bir feature'a hangi plan gerekli — gating helper.
class Features {
  Features._();

  // Temel modüller — Starter ve üstü
  static const animals = SubscriptionPlan.starter;
  static const milking = SubscriptionPlan.starter;
  static const health = SubscriptionPlan.starter;
  static const calves = SubscriptionPlan.starter;
  static const feed = SubscriptionPlan.starter;
  static const equipment = SubscriptionPlan.starter;
  static const finance = SubscriptionPlan.starter;
  static const excelExport = SubscriptionPlan.starter;
  static const pushNotifications = SubscriptionPlan.starter;

  // Aile özellikleri — Family ve üstü
  static const cloudBackup = SubscriptionPlan.family;
  static const pdfReports = SubscriptionPlan.family;
  static const multiUser = SubscriptionPlan.family;
  static const activityLog = SubscriptionPlan.family;
  static const exitedAnimalsArchive = SubscriptionPlan.family;
  static const masterFinanceMask = SubscriptionPlan.family;

  // Pro özellikler — sadece Pro
  static const qrScanner = SubscriptionPlan.pro;
  static const pregnancyCalendar = SubscriptionPlan.pro;
  static const vetRequests = SubscriptionPlan.pro;
  static const tasksAndLeave = SubscriptionPlan.pro;
  static const subsidies = SubscriptionPlan.pro;
  static const multiFarm = SubscriptionPlan.pro;
  static const bulkOperations = SubscriptionPlan.pro;
  static const advancedAnalytics = SubscriptionPlan.pro;
  static const farmHealthScore = SubscriptionPlan.pro;
  static const prioritySupport = SubscriptionPlan.pro;
}
