# ÇiftlikPRO Gizlilik Politikası ve KVKK Aydınlatma Metni

**Yürürlük tarihi:** 26 Nisan 2026
**Son güncelleme:** 26 Nisan 2026

ÇiftlikPRO mobil uygulamasını kullandığınız için teşekkür ederiz. Bu metin, kişisel verilerinizin nasıl toplandığı, işlendiği, saklandığı ve korunduğu hakkında sizi bilgilendirmek amacıyla 6698 sayılı Kişisel Verilerin Korunması Kanunu ("KVKK") ve Avrupa Birliği Genel Veri Koruma Tüzüğü ("GDPR") uyarınca hazırlanmıştır.

---

## 1. Veri Sorumlusu

**Uygulama Sahibi:** Hasan Düz
**E-posta:** ciftlikpro@ciftlikpro.net
**Web sitesi:** https://www.ciftlikpro.net
**Adres:** Türkiye

ÇiftlikPRO tarafından sunulan hizmetler kapsamında kişisel verilerinizin işlenmesinde "veri sorumlusu" sıfatıyla yukarıda bilgileri verilen taraf hareket etmektedir.

---

## 2. Topladığımız Kişisel Veriler

ÇiftlikPRO, hizmet sunabilmek için aşağıdaki kategorilerde veri toplar:

### 2.1 Kayıt Bilgileri (Tüm Kullanıcılar)
- Ad ve soyad
- E-posta adresi
- Şifre (yalnızca **şifrelenmiş** olarak — düz metin kaydedilmez)
- Çiftlik adı (Ana Sahip kullanıcılar için)
- Telefon numarası (Veteriner kayıtlarında zorunlu, diğer rollerde opsiyonel)
- Klinik / muayenehane bilgisi (Veteriner kullanıcıları için, opsiyonel)

### 2.2 Çiftlik Yönetim Verileri
Uygulamayı kullanırken oluşturduğunuz işletme verileri:
- Hayvan kayıtları (küpe no, ırk, doğum tarihi, fotoğraflar)
- Süt üretim kayıtları
- Sağlık ve aşı geçmişi
- Yem stoğu ve maliyetleri
- Finansal kayıtlar (gelir/gider)
- Personel bilgileri ve görevleri
- Veteriner talepleri ve cevapları

Bu veriler, çiftlik üyeleri (Ana Sahip, Yardımcı, Ortak, Veteriner, Personel) arasında **rol-tabanlı** olarak paylaşılır.

### 2.3 Cihaz ve Kullanım Verileri (Otomatik)
- Cihaz tipi, işletim sistemi versiyonu
- Uygulama versiyonu, dil ayarı
- Çökme raporları (Firebase Crashlytics)
- Anonim kullanım istatistikleri (Firebase Analytics): hangi ekranlar açıldı, hangi özellikler kullanıldı

### 2.4 Konum Verisi (Opsiyonel)
- Hava durumu modülünü kullanırken — kaba konum bilgisi
- **Konum verisi sunucularımızda saklanmaz**, yalnızca cihazınızdan hava durumu API'sine anlık iletilir

### 2.5 Ödeme Bilgileri
- Apple App Store / Google Play Store üzerinden yapılan abonelik satın alma kayıtları
- **Kredi kartı bilgileri ÇiftlikPRO sunucularına ulaşmaz** — ödeme tamamen Apple/Google tarafından işlenir
- Yalnızca satın alma onayı (receipt), abonelik plan tipi ve süresi tarafımızca kaydedilir

---

## 3. Verileri Hangi Amaçlarla İşleriz

KVKK madde 5/2 ve GDPR madde 6 kapsamında aşağıdaki hukuki sebeplere dayanarak işliyoruz:

| Amaç | Hukuki Sebep |
|------|-------------|
| Hesap oluşturma ve kimlik doğrulama | Sözleşmenin ifası |
| Çiftlik yönetim hizmetinin sunulması | Sözleşmenin ifası |
| Abonelik ve ödeme işlemleri | Sözleşmenin ifası, hukuki yükümlülük |
| Bildirimler (vet talepleri, görevler, davetler) | Sözleşmenin ifası |
| Hata teşhisi ve uygulama iyileştirme | Meşru menfaat |
| Anonim kullanım istatistikleri | Meşru menfaat (rıza çekilebilir) |
| Yasal yükümlülüklerin yerine getirilmesi | Hukuki yükümlülük |

---

## 4. Verilerin Saklanma Süreleri

- **Aktif kullanıcı verileri**: hesap aktif kaldığı sürece
- **Hesap silme sonrası**: 30 gün içinde tamamen silinir (yedeklerden de)
- **Yasal saklama yükümlülüğü olan veriler** (örn. fatura kayıtları): 10 yıl (Türk Ticaret Kanunu)
- **Çökme raporları**: Firebase tarafından 90 gün
- **Analytics verileri**: 14 ay, sonra anonim toplulaştırılır

---

## 5. Verilerin Aktarıldığı Üçüncü Taraflar

ÇiftlikPRO verilerinizi **satmaz**, ancak aşağıdaki teknik altyapı sağlayıcılarıyla paylaşır:

| Üçüncü Taraf | Aktarılan Veri | Amaç | Konum |
|--------------|----------------|------|-------|
| **Google Firebase** (Authentication, Firestore, Storage, Crashlytics, Analytics) | Kayıt bilgileri, çiftlik verileri, kullanım verileri | Bulut altyapı | AB / ABD |
| **Apple App Store** | Apple ID, satın alma kayıtları | Abonelik işleme | Apple sunucuları |
| **Google Play Store** | Google hesabı, satın alma kayıtları | Abonelik işleme | Google sunucuları |
| **Hava Durumu API** (OpenWeatherMap veya muadili) | Anlık konum (saklanmaz) | Hava durumu gösterimi | Üçüncü taraf API |

Tüm aktarımlar TLS 1.2+ ile şifrelidir. Firebase için Google'ın **AB Veri İşleme Eki** (DPA) ve Standart Sözleşme Maddeleri (SCC) geçerlidir.

---

## 6. Veri Güvenliği

Verilerinizi korumak için şu önlemleri uyguluyoruz:

- 🔒 **Şifre güvenliği**: PIN ve uygulama içi kilit (Face ID / parmak izi)
- 🔐 **Aktarım şifrelemesi**: HTTPS / TLS 1.2+ — tüm trafik şifreli
- 🛡️ **Erişim kontrolü**: Rol-tabanlı yetkilendirme (RBAC) — her kullanıcı yalnızca yetkili olduğu çiftlik verilerine erişebilir
- ✅ **Firebase Security Rules**: Sunucu düzeyinde veri izolasyonu
- 📊 **Çökme raporları**: kişisel veri içermez, yalnızca teknik stack trace
- 🔄 **Yedekleme**: Düzenli sunucu yedeklemesi (Firebase tarafından otomatik)

Buna rağmen, internet üzerinden iletim %100 güvenli değildir. Hesabınızı korumak sizin de sorumluluğunuzdadır — şifrenizi paylaşmayın, biyometrik kilidi açık tutun.

---

## 7. KVKK Madde 11 Kapsamında Haklarınız

Veri sahibi olarak aşağıdaki haklara sahipsiniz:

✅ **Bilgi alma**: Kişisel verilerinizin işlenip işlenmediğini öğrenme
✅ **Erişim**: İşlenen verilerinizi talep etme
✅ **Düzeltme**: Yanlış veya eksik verilerin düzeltilmesini isteme
✅ **Silme ("unutulma hakkı")**: Verilerinizin silinmesini isteme
✅ **İşlemeyi sınırlama**: Belirli işleme faaliyetlerini durdurma
✅ **Veri taşıma**: Verilerinizi makine-okunabilir formatta alma
✅ **İtiraz**: Otomatik karar verme veya profilleme süreçlerine itiraz
✅ **Tazminat**: Hukuka aykırı işleme nedeniyle uğradığınız zararları talep

### Hesap ve Veri Silme Yöntemi

**Uygulama içinden**: 
1. Profil → Ayarlar → Bilgilerimi Güncelle → "Hesabımı Sil"
2. Onay sonrası 30 gün içinde tüm verileriniz sistemden silinir

**E-posta ile**: 
ciftlikpro@ciftlikpro.net adresine **kimlik doğrulama** ile birlikte talep gönderebilirsiniz. En geç 30 gün içinde işleme alınır.

---

## 8. Çocukların Gizliliği

ÇiftlikPRO **18 yaş altı kullanıcılar için tasarlanmamıştır**. 18 yaş altı bir kullanıcının kayıt olduğunu fark edersek, hesabı ve verileri derhal sileriz. Velilerin bu konuda ciftlikpro@ciftlikpro.net adresine bildirimde bulunması rica olunur.

---

## 9. Çerezler ve Yerel Depolama

ÇiftlikPRO mobil uygulaması çerez kullanmaz. Ancak performans için cihazınızda yerel depolama (SQLite, SharedPreferences) kullanır:
- Hesap oturum bilgisi (çıkış yapmadığınız sürece)
- Çiftlik verilerinin offline cache'i
- Uygulama tercihleri (dil, tema, bildirim ayarları)

Bu veriler **sadece kendi cihazınızda** kalır, sunucumuza iletilmez. Uygulamayı sildiğinizde otomatik olarak temizlenir.

---

## 10. Politika Değişiklikleri

Bu politikayı güncellediğimizde:
- Uygulama içinde önemli değişiklikler için bildirim gösteririz
- Bu sayfanın "Son güncelleme" tarihi yenilenir
- Önemli değişikliklerde, kayıtlı e-posta adresine bilgi gönderilir

---

## 11. İletişim

KVKK kapsamındaki başvurularınız ve gizlilik soruları için:

📧 **E-posta:** ciftlikpro@ciftlikpro.net
🌐 **Web:** https://www.ciftlikpro.net
📍 **Posta yoluyla:** İletişim sayfasındaki adres

KVKK Veri Sorumluları Sicil (VERBİS) kayıt durumumuz: kayıt aşamasındadır. Tamamlandığında bu sayfada yayımlanacaktır.

KVKK kapsamında başvurunuza 30 gün içinde yanıt verilmediğinde **Kişisel Verileri Koruma Kurulu**'na şikâyet hakkınız saklıdır:
🌐 https://www.kvkk.gov.tr

---

## 12. Apple App Store ve Google Play Store İçin Ek Bildirim

Apple App Store kuralları gereği:
- **App Tracking Transparency**: ÇiftlikPRO reklam takibi yapmaz, IDFA toplamaz
- **Hesap silme**: Uygulama içinde tek tıkla hesap silinebilir (App Store Guideline 5.1.1(v))

Google Play Store kuralları gereği:
- **Data Safety bölümü**: Bu sayfada listelenen tüm veri kategorileri ve amaçları Play Console'da beyan edilmiştir
- **Hesap silme**: Hem uygulama içinden hem ciftlikpro@ciftlikpro.net üzerinden mümkündür

---

**ÇiftlikPRO** — Türk çiftçileri için profesyonel dijital çözüm.
*Verileriniz çiftliğiniz kadar değerlidir — onları koruruz.*
