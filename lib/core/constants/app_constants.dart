class AppConstants {
  static const String appName = 'ÇiftlikPRO';
  static const String appVersion = '1.0.0';

  // Kullanıcı rolleri
  static const String roleOwner = 'owner';
  static const String rolePartner = 'partner';
  static const String roleVet = 'vet';
  static const String roleWorker = 'worker';

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

  // Personel rolleri
  static const List<String> staffRoles = ['Çalışan', 'Veteriner', 'Muhasebeci', 'Yönetici', 'Mevsimlik İşçi'];

  // Ekipman kategorileri
  static const List<String> equipmentCategories = [
    'Sağım Makinesi', 'Traktör', 'Sulama Sistemi', 'Aydınlatma', 'Soğutma', 'Besi Ekipmanı', 'Diğer'
  ];

  // Ekipman durumları
  static const String equipmentActive = 'Çalışıyor';
  static const String equipmentMaintenance = 'Bakımda';
  static const String equipmentBroken = 'Arızalı';

  // Türkiye zorunlu aşılar
  static const List<String> mandatoryVaccines = [
    'Şap Aşısı',
    'Brusella Aşısı',
    'LSD (Lumpy Skin)',
    'Anthrax (Şarbon)',
    'Clostridial Aşısı',
  ];

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
