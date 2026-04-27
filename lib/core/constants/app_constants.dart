class AppConstants {
  static const String appName = 'ÇiftlikPRO';
  static const String appVersion = '1.0.0';

  // ─── Test / Geliştirme override'ları ────────────────────────────────────
  // **MAĞAZA YAYININDAN ÖNCE FALSE YAPILMALI**.
  // Sadece debug build'de + bu flag açıkken `testProAllowlistEmails`
  // listesindeki e-postalar otomatik Pro paket görür. Release build'de
  // (kDebugMode=false) bu override hiç çalışmaz — kod ölü branch olur.
  static const bool enableTestProAllowlist = false;

  /// Test için Pro paket almış sayılan e-postalar (lowercase).
  static const Set<String> testProAllowlistEmails = {
    'hsnduz@hotmail.com',
  };

  /// Test için Vet aboneliği almış sayılan e-postalar (lowercase).
  /// Ayrı liste, çünkü vet user-level subscription'a sahip — owner'ın
  /// farm-level Pro override'ından farklı bir state gerekir.
  static const Set<String> testVetAllowlistEmails = {
    'hduz47@gmail.com',
  };

  // Kullanıcı rolleri (5 rol)
  static const String roleOwner     = 'owner';      // Ana Sahip — tam yetki
  static const String roleAssistant = 'assistant';  // Yardımcı — tam yetki (ana sahip gibi)
  static const String rolePartner   = 'partner';    // Ortak — her şeyi görür, düzenleyemez
  static const String roleVet       = 'vet';        // Veteriner — sağlık/aşı alanı
  static const String roleWorker    = 'worker';     // Personel — sağım + hayvan ekle + görev

  static const List<String> inviteableRoles = [
    roleAssistant, rolePartner, roleVet, roleWorker,
  ];

  static const Map<String, String> roleLabels = {
    roleOwner:     'Ana Sahip',
    roleAssistant: 'Yardımcı',
    rolePartner:   'Ortak',
    roleVet:       'Veteriner',
    roleWorker:    'Personel',
  };

  static const Map<String, String> roleDescriptions = {
    roleOwner:
        'Çiftliğin sahibi — tüm modüllerde tam yetki.',
    roleAssistant:
        'Ana Sahip\'in yardımcısı — tüm modüllerde tam yetki. Satış, silme, finansal işlemler dahil her şeyi yapabilir.',
    rolePartner:
        'Ortak — salt-okunur erişim. Tüm modülleri, finansı, gelir-giderleri izler. '
        'Hiçbir kayıt ekleyemez, değiştiremez veya silemez.',
    roleVet:
        'Veteriner — sürü listesini ve hayvan kartlarını görebilir. '
        'Sağlık ve aşı kayıtlarını ekleyip düzenleyebilir. '
        'Hayvan ekleme/satış, süt, finans erişimi yok.',
    roleWorker:
        'Personel — sağım girişi yapabilir, hayvan kaydı ekleyebilir, '
        'atanan görevleri görür, izin talebinde bulunabilir. '
        'Satış/çıkış, finansal işlemler ve personel yönetimi yoktur.',
  };

  // Hayvan durumları
  static const String animalMilking = 'Sağımda';
  static const String animalDry = 'Kuruda';
  static const String animalPregnant = 'Gebe';
  static const String animalHeifer = 'Düve';
  static const String animalSick = 'Hasta';
  static const String animalForSale = 'Satılık';
  static const String animalHealthy = 'Sağlıklı';
  static const String animalSold = 'Satıldı';
  static const String animalDead = 'Öldü';
  static const String animalSlaughtered = 'Kesime Gitti';

  static const List<String> femaleStatuses = [
    animalMilking, animalDry, animalPregnant, animalHeifer, animalSick, animalForSale,
  ];
  static const List<String> maleStatuses = [
    animalHealthy, animalSick,
  ];

  // Hayvan çıkış nedenleri
  static const List<String> removalReasons = ['Satış', 'Ölüm', 'Kesim', 'Hibe', 'Kayıp', 'Diğer'];

  // Cinsiyet
  static const String male = 'Erkek';
  static const String female = 'Dişi';

  // Yem tipleri (kategoriler)
  static const String feedConcentrate = 'Kesif Yem';
  static const String feedRoughage = 'Kaba Yem';
  static const String feedGrain = 'Tahıl';
  static const String feedByProduct = 'Yan Ürün';
  static const String feedMineral = 'Mineral & Vitamin';
  static const String feedSilage = 'Silaj';
  static const String feedOther = 'Diğer';

  static const List<String> feedTypes = [
    feedConcentrate, feedGrain, feedRoughage, feedSilage, feedByProduct, feedMineral, feedOther,
  ];

  // Önceden tanımlı yem isimleri
  static const List<Map<String, String>> feedPresets = [
    // Kesif Yem
    {'name': 'Süt Yemi',        'type': feedConcentrate},
    {'name': 'Büyütme Yemi',    'type': feedConcentrate},
    {'name': 'Besi Yemi',       'type': feedConcentrate},
    {'name': 'Başlangıç Yemi',  'type': feedConcentrate},
    {'name': 'Dana Yemi',       'type': feedConcentrate},
    // Tahıl
    {'name': 'Arpa',            'type': feedGrain},
    {'name': 'Mısır',           'type': feedGrain},
    {'name': 'Buğday',          'type': feedGrain},
    {'name': 'Yulaf',           'type': feedGrain},
    {'name': 'Çavdar',          'type': feedGrain},
    // Kaba Yem
    {'name': 'Saman',           'type': feedRoughage},
    {'name': 'Yonca',           'type': feedRoughage},
    {'name': 'Fiğ',             'type': feedRoughage},
    {'name': 'Korunga',         'type': feedRoughage},
    {'name': 'İtalyan Çimi',    'type': feedRoughage},
    {'name': 'Kuru Ot',         'type': feedRoughage},
    // Silaj
    {'name': 'Mısır Silajı',    'type': feedSilage},
    {'name': 'Fiğ Silajı',      'type': feedSilage},
    {'name': 'Yonca Silajı',    'type': feedSilage},
    // Yan Ürün
    {'name': 'Kepek',           'type': feedByProduct},
    {'name': 'Soya Küspesi',    'type': feedByProduct},
    {'name': 'Ayçiçek Küspesi', 'type': feedByProduct},
    {'name': 'Pancar Posası',   'type': feedByProduct},
    {'name': 'Bira Posası',     'type': feedByProduct},
    // Mineral & Vitamin
    {'name': 'Mineral Karışımı','type': feedMineral},
    {'name': 'Tuz (Yalama)',    'type': feedMineral},
    {'name': 'Bikarbonat',      'type': feedMineral},
    {'name': 'Vitamin Karışımı','type': feedMineral},
    // Diğer
    {'name': 'Diğer',           'type': feedOther},
  ];

  static const List<String> feedUnits = ['kg', 'ton', 'çuval', 'balya', 'litre'];

  // Gelir / Gider sabitleri
  static const String income = 'Gelir';
  static const String expense = 'Gider';

  // Gelir kategorileri
  static const String incomeMilk = 'Süt Satışı';
  static const String incomeCalf = 'Buzağı Satışı';
  static const String incomeAnimal = 'Hayvan Satışı';
  static const String incomeManure = 'Gübre Satışı';
  static const String incomeSubsidy = 'Devlet Desteği';
  static const String incomeOther = 'Diğer Gelir';

  static const List<String> incomeCategories = [
    incomeMilk, incomeCalf, incomeAnimal, incomeManure, incomeSubsidy, incomeOther,
  ];

  // Gider kategorileri
  static const String expenseFeed = 'Yem';
  static const String expenseMedicine = 'İlaç';
  static const String expenseVet = 'Veteriner';
  static const String expenseAnimal = 'Hayvan Alımı';
  static const String expenseEnergy = 'Enerji';
  static const String expenseLabor = 'İşçilik';
  static const String expenseEquipment = 'Ekipman Bakım';
  static const String expenseOther = 'Diğer Gider';

  static const List<String> expenseCategories = [
    expenseFeed, expenseMedicine, expenseVet, expenseAnimal, expenseEnergy, expenseLabor, expenseEquipment, expenseOther,
  ];

  // ─── Finans kaynak (source) sabitleri ─────────────────────────────────
  // Hangi modülün otomatik oluşturduğunu belirtir; 'manual' kullanıcı girişi.
  static const String srcManual         = 'manual';
  static const String srcFeedPurchase   = 'feed_purchase';   // Yem stok/alım
  static const String srcFeedDaily      = 'feed_daily';      // Günlük yemleme maliyeti
  static const String srcVet            = 'vet';             // Sağlık vizit maliyeti
  static const String srcVaccine        = 'vaccine';         // Aşı maliyeti
  static const String srcAnimalPurchase = 'animal_purchase'; // Hayvan alımı
  static const String srcAnimalSale     = 'animal_sale';     // Hayvan satışı
  static const String srcMilkSale       = 'milk_sale';       // Süt satışı
  static const String srcSubsidy        = 'subsidy';         // Devlet desteği
  static const String srcSalary         = 'salary';          // Maaş ödemesi
  static const String srcEquipment      = 'equipment';       // Ekipman alımı

  // Hangi kategoriler "otomatik modülden oluşur" — manuel girişte uyarı için
  static const Map<String, String> autoCategoryHint = {
    expenseFeed:     'Yem modülünden stok/alım girdiğinizde otomatik oluşur.',
    expenseVet:      'Sağlık modülünden vizit/aşı girdiğinizde otomatik oluşur.',
    expenseMedicine: 'Sağlık modülünden tedavi girdiğinizde otomatik oluşur.',
    expenseAnimal:   'Sürü modülünden hayvan alımı yaptığınızda otomatik oluşur.',
    expenseLabor:    'Personel modülünden maaş ödemesi yaptığınızda otomatik oluşur.',
    expenseEquipment:'Ekipman modülünden alım yaptığınızda otomatik oluşur.',
    incomeMilk:      'Süt tankından satış yaptığınızda otomatik oluşur.',
    incomeAnimal:    'Sürü modülünden hayvan satışı yaptığınızda otomatik oluşur.',
    incomeSubsidy:   'Destekler modülünden kayıt girdiğinizde otomatik oluşur.',
  };

  // Source → Modül adı (UI etiketi)
  static const Map<String, String> srcModuleLabel = {
    srcManual:         'Manuel',
    srcFeedPurchase:   'Yem Modülü',
    srcFeedDaily:      'Yem Modülü',
    srcVet:            'Sağlık Modülü',
    srcVaccine:        'Sağlık Modülü',
    srcAnimalPurchase: 'Sürü Modülü',
    srcAnimalSale:     'Sürü Modülü',
    srcMilkSale:       'Süt Modülü',
    srcSubsidy:        'Destekler Modülü',
    srcSalary:         'Personel Modülü',
    srcEquipment:      'Ekipman Modülü',
  };

  // ─── Ödeme yöntemi (paymentMethod) ────────────────────────────────────
  static const String pmCash     = 'cash';      // Nakit
  static const String pmBank     = 'bank';      // Banka transferi
  static const String pmCard     = 'card';      // Kredi/Banka kartı
  static const String pmDeferred = 'deferred';  // Vadeli / Borç

  static const List<String> paymentMethods = [pmCash, pmBank, pmCard, pmDeferred];

  static const Map<String, String> paymentMethodLabel = {
    pmCash:     'Nakit',
    pmBank:     'Banka',
    pmCard:     'Kart',
    pmDeferred: 'Vadeli',
  };

  // Personel rolleri
  static const List<String> staffRoles = ['Çalışan', 'Veteriner', 'Muhasebeci', 'Yönetici', 'Mevsimlik İşçi'];

  // ─── Aktivite Log türleri ─────────────────────────────────────────────
  static const String activityAnimalAdded    = 'animal_added';
  static const String activityAnimalRemoved  = 'animal_removed';
  static const String activityCalfAdded      = 'calf_added';
  static const String activityHealthAdded    = 'health_added';
  static const String activityVaccineAdded   = 'vaccine_added';
  static const String activityMilkingAdded   = 'milking_added';
  static const String activityFinanceAdded   = 'finance_added';
  static const String activityFinanceDeleted = 'finance_deleted';
  static const String activityFeedStockAdded = 'feed_stock_added';
  static const String activityFeedApplied    = 'feed_applied';
  static const String activityUserInvited    = 'user_invited';
  static const String activityUserRemoved    = 'user_removed';
  static const String activityTaskCompleted  = 'task_completed';

  // ─── Görev (Task) sabitleri ───────────────────────────────────────────
  static const String taskStatusPending    = 'pending';
  static const String taskStatusInProgress = 'in_progress';
  static const String taskStatusCompleted  = 'completed';
  static const String taskStatusCancelled  = 'cancelled';

  static const Map<String, String> taskStatusLabels = {
    taskStatusPending:    'Bekliyor',
    taskStatusInProgress: 'Devam Ediyor',
    taskStatusCompleted:  'Tamamlandı',
    taskStatusCancelled:  'İptal Edildi',
  };

  static const String taskPriorityLow    = 'low';
  static const String taskPriorityNormal = 'normal';
  static const String taskPriorityHigh   = 'high';

  static const Map<String, String> taskPriorityLabels = {
    taskPriorityLow:    'Düşük',
    taskPriorityNormal: 'Normal',
    taskPriorityHigh:   'Yüksek',
  };

  // ─── İzin Talebi sabitleri ────────────────────────────────────────────
  static const String leaveStatusPending  = 'pending';
  static const String leaveStatusApproved = 'approved';
  static const String leaveStatusRejected = 'rejected';

  static const Map<String, String> leaveStatusLabels = {
    leaveStatusPending:  'Bekliyor',
    leaveStatusApproved: 'Onaylandı',
    leaveStatusRejected: 'Reddedildi',
  };

  static const List<String> leaveReasons = [
    'Yıllık İzin',
    'Hastalık İzni',
    'Mazeret İzni',
    'Aile / Cenaze',
    'Askerlik',
    'Diğer',
  ];

  // ─── Veteriner Talep Sistemi ──────────────────────────────────────────
  // Kategoriler
  static const String vetCatBirth        = 'birth';
  static const String vetCatCalfHealth   = 'calf_health';
  static const String vetCatAnimalHealth = 'animal_health';
  static const String vetCatOther        = 'other';

  static const Map<String, String> vetRequestCategories = {
    vetCatBirth:        'Doğum',
    vetCatCalfHealth:   'Buzağı Sağlığı',
    vetCatAnimalHealth: 'Hayvan Sağlığı',
    vetCatOther:        'Diğer',
  };

  // Aciliyet
  static const String urgencyCritical = 'critical'; // Acil — hemen
  static const String urgencyHigh     = 'high';     // Orta — aynı gün
  static const String urgencyNormal   = 'normal';   // Normal — randevu

  static const Map<String, String> urgencyLabels = {
    urgencyCritical: 'Acil',
    urgencyHigh:     'Orta',
    urgencyNormal:   'Normal',
  };

  // Kategori → önerilen sebep listesi (form dropdown'ı için)
  static const Map<String, List<String>> vetRequestReasons = {
    vetCatBirth: [
      'Doğum başladı, müdahale gerekiyor',
      'Güç doğum (dystocia)',
      'Doğum sonrası plasenta atılamadı',
      'Doğum sonrası kanama',
      'Ölü doğum',
      'Yenidoğan buzağı kritik',
    ],
    vetCatCalfHealth: [
      'Buzağı ishali',
      'Buzağı zatürresi / solunum sıkıntısı',
      'Buzağı emmiyor / halsiz',
      'Göbek iltihabı',
      'Buzağı ateşi',
      'Buzağıda eklem şişliği',
      'Kolostrum eksikliği şüphesi',
    ],
    vetCatAnimalHealth: [
      'Mastitis şüphesi',
      'Topallık / bacak sorunu',
      'Yüksek ateş',
      'Şiddetli ishal',
      'İştahsızlık — süt düşüşü',
      'Yaralanma / kesik',
      'Şişlik / abse',
      'İdrar yolu / ürogenital sorun',
      'Göz / gözde akıntı',
      'Ketozis / metabolik sorun şüphesi',
    ],
    vetCatOther: [
      'Rutin muayene talebi',
      'Sürü genel kontrolü',
      'Aşı programı danışmanlığı',
      'Suni tohumlama',
      'Gebelik kontrolü',
    ],
  };

  // Ekipman kategorileri
  static const List<String> equipmentCategories = [
    'Sağım Makinesi', 'Traktör', 'Sulama Sistemi', 'Aydınlatma', 'Soğutma', 'Besi Ekipmanı', 'Diğer'
  ];

  // Ekipman durumları
  static const String equipmentActive = 'Çalışıyor';
  static const String equipmentMaintenance = 'Bakımda';
  static const String equipmentBroken = 'Arızalı';

  // ─── Aşı Kataloğu ──────────────────────────────────────────────────────
  // Türkiye'de büyükbaş hayvancılıkta kullanılan tüm rutin ve zorunlu aşılar.
  // Kategoriler uygulama formunda gruplu gösterilir.

  // Devlet tarafından zorunlu tutulan / ulusal kampanya aşıları
  static const List<String> mandatoryVaccines = [
    'Şap Aşısı',
    'Brusella Aşısı (S19)',
    'LSD (Nodüler Ekzantem)',
    'Anthrax (Şarbon)',
    'Clostridial Aşısı (7-1 / 8-1)',
  ];

  // Solunum yolu hastalıkları — genelde kombine olarak uygulanır
  static const List<String> respiratoryVaccines = [
    'IBR (Rhinotrakeit)',
    'BVD (Viral İshal)',
    'PI3 (Parainfluenza 3)',
    'BRSV (Solunum Sinsityal Virüsü)',
    'IBR-BVD-PI3-BRSV Kombine Aşı',
    'Pasteurella / Mannheimia',
    'Histophilus somni',
  ];

  // Doğum öncesi anne aşıları — buzağıyı kolostrumla korur
  static const List<String> prepartumVaccines = [
    'Rota-Corona-E.coli K99 (Buzağı İshali)',
    'Mastitis Aşısı (E.coli J5)',
    'Clostridial Booster (doğum öncesi)',
  ];

  // Üreme aşıları
  static const List<String> reproductiveVaccines = [
    'Campylobacter (Vibriozis)',
    'Leptospirosis',
    'Trichomoniasis',
  ];

  // Buzağı aşıları (post-natal)
  static const List<String> calfVaccines = [
    'Buzağı İshali Aşısı (Rota-Corona-E.coli)',
    'Buzağı Zatürresi Aşısı',
    'Pinkeye (IBK) Aşısı',
    'Tetanoz',
    'Salmonella',
  ];

  // Diğer / Nadir
  static const List<String> otherVaccines = [
    'Theileriosis (Tropikal)',
    'Babesiosis',
    'Blackleg (Kara Hastalık)',
    'Kuduz',
    'Diğer',
  ];

  /// Tüm aşıların tek bir düz listesi (aşı kaydı dropdown'u için).
  /// Sıralama: zorunlu → solunum → doğum öncesi → üreme → buzağı → diğer
  static const List<String> allVaccines = [
    ...mandatoryVaccines,
    ...respiratoryVaccines,
    ...prepartumVaccines,
    ...reproductiveVaccines,
    ...calfVaccines,
    ...otherVaccines,
  ];

  /// Her aşının kategorisi (dropdown'da başlık/gruplama için).
  /// `final` çünkü collection-for sadece runtime'da çözülür (const değil).
  static final Map<String, String> vaccineCategory = {
    for (final v in mandatoryVaccines) v: 'Zorunlu (Devlet)',
    for (final v in respiratoryVaccines) v: 'Solunum Sistemi',
    for (final v in prepartumVaccines) v: 'Doğum Öncesi (Anne)',
    for (final v in reproductiveVaccines) v: 'Üreme',
    for (final v in calfVaccines) v: 'Buzağı',
    for (final v in otherVaccines) v: 'Diğer',
  };

  /// Aşı → hangi yaş/dönemde uygulanır önerisi (bilgilendirici)
  static const Map<String, String> vaccineSchedule = {
    'Şap Aşısı':                                 'Yılda 2 kez (Nisan, Ekim) — 4 aydan büyük tüm sürü',
    'Brusella Aşısı (S19)':                      'Dişi buzağılar 4-8 aylıkken tek doz',
    'LSD (Nodüler Ekzantem)':                    'Yılda 1 kez, ilkbaharda',
    'Anthrax (Şarbon)':                          'Yılda 1 kez (endemik bölgelerde zorunlu)',
    'Clostridial Aşısı (7-1 / 8-1)':             '6 aylıkken ilk doz + 4 hafta sonra booster, yıllık tekrar',
    'IBR (Rhinotrakeit)':                        '3 aydan itibaren + yıllık booster',
    'BVD (Viral İshal)':                         '3 aydan itibaren + yıllık booster',
    'PI3 (Parainfluenza 3)':                     'Kombine aşı içinde yıllık',
    'BRSV (Solunum Sinsityal Virüsü)':           'Kombine aşı içinde yıllık',
    'IBR-BVD-PI3-BRSV Kombine Aşı':              '3 aydan itibaren + yıllık',
    'Pasteurella / Mannheimia':                  'Taşıma/stress öncesi 2-3 hafta',
    'Histophilus somni':                         'Solunum enfeksiyonu riskli durumlarda',
    'Rota-Corona-E.coli K99 (Buzağı İshali)':    'Doğumdan 3-6 hafta önce gebe ineğe',
    'Mastitis Aşısı (E.coli J5)':                'Kuru dönem başı + 2 hafta sonra + doğum sonrası',
    'Clostridial Booster (doğum öncesi)':        'Doğumdan 4-6 hafta önce',
    'Campylobacter (Vibriozis)':                 'Tohumlamadan 4 hafta önce, yıllık',
    'Leptospirosis':                             'Yılda 2 kez',
    'Trichomoniasis':                            'Damızlık boğalar için yıllık',
    'Buzağı İshali Aşısı (Rota-Corona-E.coli)':  'Yeni doğan buzağıya kolostrum ile (anne aşılı değilse)',
    'Buzağı Zatürresi Aşısı':                    '2-3 aylıkken intranazal',
    'Pinkeye (IBK) Aşısı':                       'Yaz aylarından önce ilkbaharda',
    'Tetanoz':                                   'Yaralanma/cerrahi sonrası',
    'Salmonella':                                'Endemik bölgelerde yıllık',
    'Theileriosis (Tropikal)':                   'Kene mücadelesi yerine geçmez — endemik bölge',
    'Babesiosis':                                'Endemik bölgelerde mevsimsel',
    'Blackleg (Kara Hastalık)':                  'Clostridial kombine içinde',
    'Kuduz':                                     'Endemik bölge + köpek ısırması sonrası',
  };

  // Üreme durumları
  static const String breedingOpen = 'Açık';
  static const String breedingInseminated = 'Tohumlandı';
  static const String breedingPregnant = 'Gebe';
  static const String breedingCalved = 'Doğurdu';

  static const List<String> breedingTypes = ['Doğal Tohumlama', 'Suni Tohumlama'];

  // Buzağı durumları
  static const String calfHealthy = 'Sağlıklı';
  static const String calfSick = 'Hasta';
  static const String calfWeaned = 'Sütten Kesildi';
  static const String calfSold = 'Satıldı';

  // Devlet destekleri
  static const List<Map<String, String>> subsidyDeadlines = [
    {'title': 'Büyükbaş Hayvancılık Destekleri', 'month': 'Ocak - Mart', 'description': 'Soy kütüğüne kayıtlı inek başına destek. TARSİM kayıt zorunlu.'},
    {'title': 'Brusella & Tüberküloz Test', 'month': 'Şubat', 'description': 'Yıllık zorunlu test. Destekten yararlanmak için sonuçların Bakanlığa iletilmesi gerekir.'},
    {'title': 'Süt Sığırcılığı Sürü Yönetimi', 'month': 'Nisan', 'description': 'Yetiştirici birliğine üyelik şartı. İl Tarım ve Orman Müdürlüğüne başvuru.'},
    {'title': 'Şap Aşısı Kampanyası', 'month': 'Nisan & Ekim', 'description': 'Zorunlu şap aşısı. Kaçırıldığında idari para cezası uygulanır.'},
    {'title': 'TKDK / IPARD Yatırım Desteği', 'month': 'Temmuz', 'description': 'Ahır modernizasyonu, soğuk zincir, çevre yatırımları için hibe. Proje dosyası hazırlanmalı.'},
    {'title': 'TARSİM Yenileme', 'month': 'Sürekli', 'description': 'Hayvan hayat sigortası. Ölüm/hastalık desteklerinden yararlanmak için aktif poliçe şart.'},
    {'title': 'Yem Bitkileri Desteği', 'month': 'Ekim', 'description': 'Yonca, mısır silajı vb. yem bitkisi ekimi için doğrudan gelir desteği.'},
    {'title': 'Çiftçi Kayıt Sistemi (ÇKS) Güncelleme', 'month': 'Kasım', 'description': 'Yıllık ÇKS güncellemesi zorunlu. Güncellenmezse tüm destekler kesilir.'},
  ];
}
