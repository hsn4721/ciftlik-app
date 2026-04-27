# ÇiftlikPRO Cloud Functions

Bu klasör ÇiftlikPRO için **server-side** Cloud Functions'ları içerir.

## Functions

| Function | Tetikleyici | Amaç |
|----------|-------------|------|
| `validateReceipt` | HTTPS callable | Apple/Google IAP receipt'i doğrular, Firestore'a abonelik state'i yazar |
| `onUserDelete` | Firestore onDelete users/{uid} | Auth user + orphan invitations + vet_requests cleanup |

## İlk Kurulum (One-time)

### 1. Bağımlılıklar
```bash
cd functions
npm install
```

### 2. Apple App Store Server API Setup

1. https://appstoreconnect.apple.com → Users and Access → Keys → "In-App Purchase" sekmesi
2. **+ butonu** → yeni key oluştur (örn: "ÇiftlikPRO Production")
3. **.p8 dosyasını indir** (sadece BİR KEZ indirilebilir — kaybedersen yenisini almak lazım)
4. **Key ID** ve **Issuer ID**'yi kopyala (sayfada görünür)
5. Bundle ID: `com.ciftlikpro.app` (zaten Info.plist'te)

Secrets'ları yükle:
```bash
firebase functions:secrets:set APPLE_KEY_ID
# (key ID'yi yapıştır)

firebase functions:secrets:set APPLE_ISSUER_ID
# (issuer ID'yi yapıştır)

firebase functions:secrets:set APPLE_PRIVATE_KEY
# (.p8 dosyasının TÜM içeriğini yapıştır — -----BEGIN PRIVATE KEY----- dahil)

firebase functions:secrets:set APPLE_BUNDLE_ID
# com.ciftlikpro.app
```

### 3. Google Play Developer API Setup

1. https://console.cloud.google.com → IAM & Admin → Service Accounts → "+ Create"
2. Name: `ciftlikpro-iap-validator`
3. Role: gerekmez (boş geç)
4. Done → açılan listede yeni service account → **Keys** → **Add Key** → JSON
5. JSON dosyasını indir
6. https://play.google.com/console → API access → service account'u **link**
7. Permissions → "Financial data, orders, and cancellation survey responses" iznini ver

Secrets'ları yükle:
```bash
firebase functions:secrets:set GOOGLE_PLAY_SERVICE_ACCOUNT
# (downloaded .json dosyasının TÜM içeriğini yapıştır)

firebase functions:secrets:set GOOGLE_PLAY_PACKAGE_NAME
# com.ciftlikpro.app
```

### 4. Build & Deploy
```bash
npm run build
firebase deploy --only functions
```

İlk deploy 5-10 dk sürer. Function URL'leri Firebase Console → Functions sekmesinde görünür.

## Client Tarafı Entegrasyonu

`SubscriptionService.dart` içinde `_activatePurchase` metoduna eklenecek:

```dart
import 'package:cloud_functions/cloud_functions.dart';

Future<void> _activatePurchase(PurchaseDetails purchase) async {
  final user = AuthService.instance.currentUser;
  if (user == null) return;

  final plan = _planFromProductId(purchase.productID);
  if (plan == SubscriptionPlan.none) return;

  final isVet = plan == SubscriptionPlan.vet;
  final targetPath = isVet
      ? 'users/${user.uid}/subscription/current'
      : 'farms/${user.activeFarmId}/subscription/current';

  try {
    final functions = FirebaseFunctions.instanceFor(region: 'europe-west1');
    final result = await functions.httpsCallable('validateReceipt').call({
      'platform': defaultTargetPlatform == TargetPlatform.iOS ? 'ios' : 'android',
      'receipt': purchase.verificationData.serverVerificationData,
      'productId': purchase.productID,
      'targetPath': targetPath,
    });
    AppLogger.info('SubscriptionService.activatePurchase',
        'Server-validated: ${result.data}');
  } on FirebaseFunctionsException catch (e) {
    AppLogger.error('SubscriptionService.activatePurchase', e, StackTrace.current,
        context: {'code': e.code, 'message': e.message});
    lastPurchaseError = 'Satın alma doğrulanamadı: ${e.message}';
    return;
  }
  // Realtime listener Firestore'daki yeni state'i alacak ve UI güncelleyecek.
}
```

`pubspec.yaml`'a eklenecek:
```yaml
dependencies:
  cloud_functions: ^5.1.4
```

## Test

### Sandbox Testing (Apple)
- TestFlight build'leri otomatik sandbox modda IAP yapar
- Apple sandbox response'ları aynı API üzerinden çalışır

### Test Cards (Google Play)
- Play Console → License Testing → test hesapları ekle
- O hesaplardan yapılan satın almalar gerçek para çekmez ama receipt geçerli

### Local Emulator
```bash
firebase emulators:start --only functions,firestore
```

Bu emulator'de validateReceipt **gerçek** Apple/Google API'sine istek atar (secrets dolduysa). Test için mock client gerekirse `firebase functions:shell` kullan.

## Logs ve Monitoring

```bash
firebase functions:log --only validateReceipt
firebase functions:log --only onUserDelete
```

Ya da Firebase Console → Functions → her function için Logs sekmesi.

## Maliyet

Cloud Functions ilk **2M çağrı/ay ücretsiz** (Free tier — Spark plan).
ÇiftlikPRO için tipik kullanım:
- validateReceipt: kullanıcı başına ~2-3 çağrı/yıl (purchase + restore)
- onUserDelete: nadiren

10,000 kullanıcıya kadar **$0/ay** kalır. Üzerinde küçük dolar/ay seviyesinde fatura oluşur.

## Security Notes

- Secrets `defineSecret` ile yüklenir — ortam değişkeni olarak çalışma anında erişilir, kod içinde GÖRÜNMEZ
- Service account JSON repo'da olmamalı (`.gitignore`'da `serviceAccountKey.json`)
- `enforceAppCheck: false` şu an — Faz 13c'de App Check entegre edilince `true` yapılacak
- `region: europe-west1` — KVKK gereği AB lokasyonunda

---

**Sıradaki adım**: Yukarıdaki secrets setup'ını yap, `npm run build && firebase deploy --only functions` çalıştır, ilk test purchase'i yapıp doğrulamayı kontrol et. Sorun olursa `firebase functions:log` ile bak.
