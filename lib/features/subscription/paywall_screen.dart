import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/constants/app_constants.dart';
import '../../core/design_system/ds.dart';
import '../../core/services/auth_service.dart';
import '../../core/subscription/subscription_constants.dart';
import '../../core/subscription/subscription_service.dart';
import '../auth/login_screen.dart';

/// Premium paywall ekranı — 3 paket karşılaştırma + monthly/yearly toggle.
/// Vet-only mode'da sadece veteriner paketi gösterilir.
class PaywallScreen extends StatefulWidget {
  /// Vurgulanacak paket (kilit kontrolünden gelmişse).
  final SubscriptionPlan? highlightPlan;
  /// Kilit nedeni metni — kullanıcıya neden paywall görüntülendiğini açıklar.
  final String? featureName;
  final String? reason;
  /// Vet-only mode — sadece veteriner paketi görünür, kapatılamaz (zorunlu).
  final bool vetOnly;
  /// Geri butonu/Kapat butonu kapatılsın mı (zorunlu paywall için).
  final bool blocking;

  const PaywallScreen({
    super.key,
    this.highlightPlan,
    this.featureName,
    this.reason,
    this.vetOnly = false,
    this.blocking = false,
  });

  @override
  State<PaywallScreen> createState() => _PaywallScreenState();
}

class _PaywallScreenState extends State<PaywallScreen> {
  bool _yearly = true; // Yıllık varsayılan (daha çok dönüşüm)
  bool _processing = false;

  ProductDetails? _findProduct(String productId) {
    final products = SubscriptionService.instance.products;
    try {
      return products.firstWhere((p) => p.id == productId);
    } catch (_) {
      return null;
    }
  }

  Future<void> _purchase(SubscriptionPlan plan) async {
    // Yetki kontrolü — sadece owner/assistant veya vet kendi planını alabilir
    final user = AuthService.instance.currentUser;
    if (user != null) {
      // Vet kendi vet planını alır
      if (plan == SubscriptionPlan.vet && !user.isVet && !widget.vetOnly) {
        // Çiftlik kullanıcısı vet planı satın alamaz
        return;
      }
      // Çiftlik planları sadece owner/assistant satın alabilir
      if (plan != SubscriptionPlan.vet && !user.hasFullControl) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Abonelik satın alma yetkisi yalnızca Ana Sahip / Yardımcı\'da. '
                'Lütfen çiftlik sahibinize danışın.'),
            backgroundColor: DsColors.errorRed,
            duration: Duration(seconds: 4),
          ),
        );
        return;
      }
    }

    setState(() => _processing = true);
    try {
      String productId;
      switch (plan) {
        case SubscriptionPlan.starter:
          productId = _yearly ? IapProductIds.starterYearly : IapProductIds.starterMonthly;
          break;
        case SubscriptionPlan.family:
          productId = _yearly ? IapProductIds.familyYearly : IapProductIds.familyMonthly;
          break;
        case SubscriptionPlan.pro:
          productId = _yearly ? IapProductIds.proYearly : IapProductIds.proMonthly;
          break;
        case SubscriptionPlan.vet:
          productId = IapProductIds.vetYearly; // Sadece yıllık
          break;
        default:
          return;
      }

      final product = _findProduct(productId);
      if (product == null) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ürün mağazada bulunamadı: $productId'),
            backgroundColor: DsColors.errorRed,
          ),
        );
        return;
      }

      HapticFeedback.lightImpact();
      final ok = await SubscriptionService.instance.buy(product);
      if (!mounted) return;
      if (!ok) {
        final svc = SubscriptionService.instance;
        final msg = svc.lastPurchaseError ?? 'Satın alma başlatılamadı';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(msg),
            backgroundColor: DsColors.errorRed,
            duration: const Duration(seconds: 5),
            action: SnackBarAction(
              label: 'Tekrar Dene',
              textColor: Colors.white,
              onPressed: () => _purchase(plan),
            ),
          ),
        );
      }
      // Purchase stream listener Firestore state'i güncelleyince paywall pop olur.
      // Manuel pop yerine listener'la dön.
    } finally {
      if (mounted) setState(() => _processing = false);
    }
  }

  Future<void> _restore() async {
    setState(() => _processing = true);
    await SubscriptionService.instance.restorePurchases();
    if (!mounted) return;
    setState(() => _processing = false);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Satın almalar geri yüklendi'),
        backgroundColor: DsColors.accentGreen,
      ),
    );
  }

  /// Blocking paywall'dan çıkış — kullanıcıyı login ekranına döndürür.
  /// Vet abonelik almadan vazgeçerse hesabıyla bir daha login olabilir.
  Future<void> _signOutAndExit() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Çıkış Yap'),
        content: const Text(
          'Abonelik almadan çıkış yapmak istediğinize emin misiniz? '
          'Tekrar giriş yaptığınızda bu ekranı yeniden göreceksiniz.',
          style: TextStyle(height: 1.5, fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Vazgeç'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: DsColors.errorRed),
            child: const Text('Çıkış'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    if (!mounted) return;
    setState(() => _processing = true);
    await AuthService.instance.signOut();
    if (!mounted) return;
    Navigator.of(context, rootNavigator: true).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return PopScope(
      canPop: !widget.blocking,
      child: Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: const Color(0xFF061D0A),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        automaticallyImplyLeading: false,
        leading: widget.blocking
            ? null
            : IconButton(
                icon: const Icon(Icons.close, color: Colors.white),
                onPressed: () => Navigator.pop(context),
              ),
        actions: [
          TextButton(
            onPressed: _processing ? null : _restore,
            child: const Text(
              'Geri Yükle',
              style: TextStyle(color: Colors.white70, fontSize: 12),
            ),
          ),
          // Blocking paywall'da abonelik almadan çıkıp login ekranına dönmek
          // isteyen kullanıcı için çıkış butonu (özellikle vet kayıt akışı).
          if (widget.blocking)
            TextButton.icon(
              onPressed: _processing ? null : _signOutAndExit,
              icon: const Icon(Icons.logout, color: Colors.white70, size: 16),
              label: const Text(
                'Çıkış',
                style: TextStyle(color: Colors.white70, fontSize: 12),
              ),
            ),
          const SizedBox(width: 8),
        ],
      ),
      body: Stack(children: [
        // Background gradient
        Container(
          width: double.infinity, height: double.infinity,
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xFF061D0A),
                Color(0xFF0A2E0F),
                Color(0xFF1B5E20),
              ],
            ),
          ),
        ),
        Positioned(
          top: -size.width * 0.3,
          right: -size.width * 0.2,
          child: Container(
            width: size.width * 0.8, height: size.width * 0.8,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(colors: [
                DsColors.gold.withValues(alpha: 0.15),
                Colors.transparent,
              ]),
            ),
          ),
        ),

        SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              // Hero
              const SizedBox(height: 8),
              Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(
                    color: DsColors.gold.withValues(alpha: 0.15),
                    borderRadius: DsRadius.brPill,
                    border: Border.all(color: DsColors.gold.withValues(alpha: 0.4)),
                  ),
                  child: const Text(
                    '✨ ABONELİK PLANLARI',
                    style: TextStyle(
                      color: DsColors.gold, fontSize: 11,
                      fontWeight: FontWeight.w800, letterSpacing: 1.5,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              ShaderMask(
                shaderCallback: (bounds) => const LinearGradient(
                  colors: [Colors.white, Color(0xFFB8F2C4)],
                ).createShader(bounds),
                child: Text(
                  widget.featureName != null
                      ? '${widget.featureName}\nPro\'ya Özel'
                      : 'Tam Erişim için\nPro\'ya Yükselt',
                  textAlign: TextAlign.center,
                  style: DsTypography.titleLarge(color: Colors.white).copyWith(
                    fontSize: 28, height: 1.2, letterSpacing: -0.6,
                  ),
                ),
              ),
              if (widget.reason != null) ...[
                const SizedBox(height: 10),
                Text(
                  widget.reason!,
                  textAlign: TextAlign.center,
                  style: DsTypography.body(color: Colors.white.withValues(alpha: 0.75))
                      .copyWith(height: 1.5),
                ),
              ],
              const SizedBox(height: 22),

              // Vet-only mode: tek paket, toggle yok
              if (widget.vetOnly) ...[
                _buildVetCard(),
              ] else ...[
                // Aylık/Yıllık Toggle
                Center(
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.1),
                      borderRadius: DsRadius.brPill,
                      border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
                    ),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      _toggleBtn('Aylık', !_yearly, () => setState(() => _yearly = false)),
                      _toggleBtn('Yıllık · 2 ay bedava', _yearly, () => setState(() => _yearly = true)),
                    ]),
                  ),
                ),
                const SizedBox(height: 22),

                // Paket kartları
                _buildPlanCard(
                  plan: SubscriptionPlan.starter,
                  emoji: '🌱',
                  title: 'Başlangıç',
                  tagline: 'Tek kişi · Küçük çiftlik',
                  monthlyPrice: '₺79.99',
                  yearlyPrice: '₺749.99',
                  features: const [
                    'Max 30 hayvan',
                    'Tek kullanıcı',
                    'Tüm temel modüller',
                    'Excel export',
                  ],
                  color: DsColors.accentGreen,
                ),
                const SizedBox(height: 12),
                _buildPlanCard(
                  plan: SubscriptionPlan.family,
                  emoji: '🏠',
                  title: 'Aile',
                  tagline: 'EN POPÜLER · Aile işletmesi',
                  monthlyPrice: '₺149.99',
                  yearlyPrice: '₺1399.99',
                  features: const [
                    'Max 100 hayvan',
                    '2 kullanıcı (eş ekleme)',
                    'PDF rapor',
                    'Cloud yedekleme',
                    'Aktivite log',
                  ],
                  color: DsColors.gold,
                  featured: true,
                ),
                const SizedBox(height: 12),
                _buildPlanCard(
                  plan: SubscriptionPlan.pro,
                  emoji: '💎',
                  title: 'Pro Premium',
                  tagline: 'Profesyonel · Tam erişim',
                  monthlyPrice: '₺249.99',
                  yearlyPrice: '₺2399.99',
                  features: const [
                    'SINIRSIZ hayvan',
                    '16 kullanıcı (5 rol)',
                    'QR/Barkod tarama',
                    'Gebelik takvimi',
                    'Görev/İzin yönetimi',
                    'Vet talep sistemi',
                    'Devlet destekleri',
                    'Öncelikli destek',
                  ],
                  color: DsColors.premium,
                ),
              ],

              const SizedBox(height: 24),

              // Trial bilgisi
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.06),
                  borderRadius: DsRadius.brMd,
                  border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                ),
                child: Row(children: [
                  const Icon(Icons.info_outline, color: Colors.white70, size: 18),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Yeni kullanıcılar 14 gün ücretsiz deneme alır. '
                      'Deneme süresi sonunda seçtiğiniz paket için otomatik tahsilat başlar.',
                      style: DsTypography.bodySmall(color: Colors.white70).copyWith(height: 1.45),
                    ),
                  ),
                ]),
              ),
              const SizedBox(height: 16),

              // IAP otomatik yenileme açıklaması — Apple Guideline 3.1.2(a) +
              // Play Store consumer protection zorunlu metin (kullanıcı satın
              // alma butonunun yakınında bunu görmeli).
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.04),
                  borderRadius: DsRadius.brMd,
                  border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                ),
                child: Text(
                  'Abonelik bilgisi: Seçtiğiniz paket otomatik olarak yenilenir. '
                  'Mevcut dönem bitmeden en az 24 saat önce iptal edilmedikçe, '
                  'bir sonraki dönem ücreti hesabınızdan tahsil edilir. '
                  'Aboneliğinizi istediğiniz zaman ${defaultTargetPlatformIsApple ? "App Store" : "Google Play"} '
                  'hesap ayarlarından yönetebilir veya iptal edebilirsiniz. '
                  'Ücretsiz deneme süresi içinde iptal ederseniz herhangi bir ücret tahsil edilmez.',
                  style: DsTypography.caption(color: Colors.white.withValues(alpha: 0.75))
                      .copyWith(height: 1.45),
                ),
              ),
              const SizedBox(height: 16),

              // Footer — tıklanır Privacy/Terms linkleri
              Center(
                child: Column(children: [
                  Text(
                    'Aboneliği istediğiniz zaman App Store / Play Store\'dan yönetebilirsiniz',
                    textAlign: TextAlign.center,
                    style: DsTypography.caption(color: Colors.white.withValues(alpha: 0.5)),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 16,
                    children: [
                      InkWell(
                        onTap: () => _openUrl(AppConstants.privacyPolicyUrl),
                        child: Text('Gizlilik Politikası',
                            style: DsTypography.caption(color: Colors.white70)
                                .copyWith(decoration: TextDecoration.underline)),
                      ),
                      InkWell(
                        onTap: () => _openUrl(AppConstants.termsOfServiceUrl),
                        child: Text('Kullanım Şartları',
                            style: DsTypography.caption(color: Colors.white70)
                                .copyWith(decoration: TextDecoration.underline)),
                      ),
                    ],
                  ),
                ]),
              ),
            ]),
          ),
        ),

        if (_processing)
          Positioned.fill(
            child: Container(
              color: Colors.black.withValues(alpha: 0.5),
              child: const Center(
                child: CircularProgressIndicator(color: DsColors.gold),
              ),
            ),
          ),
      ]),
    ),
    );
  }

  Widget _toggleBtn(String label, bool selected, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? DsColors.gold : Colors.transparent,
          borderRadius: DsRadius.brPill,
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.black : Colors.white,
            fontWeight: FontWeight.w700,
            fontSize: 12,
          ),
        ),
      ),
    );
  }

  /// Veteriner özel paket kartı — tek kart, vet-only mode'da gösterilir.
  Widget _buildVetCard() {
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft, end: Alignment.bottomRight,
          colors: [Color(0x33AF52DE), Color(0x1A0A84FF)],
        ),
        borderRadius: DsRadius.brXl,
        border: Border.all(color: DsColors.premium.withValues(alpha: 0.6), width: 2),
        boxShadow: [
          BoxShadow(
            color: DsColors.premium.withValues(alpha: 0.3),
            blurRadius: 30,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      padding: const EdgeInsets.all(24),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Text('🩺', style: TextStyle(fontSize: 36)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Veteriner Profesyonel',
                    style: DsTypography.title(color: Colors.white)
                        .copyWith(fontSize: 20)),
                Text('Çoklu çiftlikte hizmet verin',
                    style: DsTypography.caption(color: DsColors.premium)
                        .copyWith(fontWeight: FontWeight.w700, letterSpacing: 0.3)),
              ],
            ),
          ),
        ]),

        const SizedBox(height: 18),

        // Fiyat — büyük vurgu
        Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text(
            '₺299.99',
            style: DsTypography.titleLarge(color: Colors.white).copyWith(
              fontSize: 36, fontWeight: FontWeight.w900, letterSpacing: -1,
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(bottom: 6, left: 6),
            child: Text('/yıl',
                style: DsTypography.body(color: Colors.white60)),
          ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: DsColors.gold,
              borderRadius: DsRadius.brSm,
            ),
            child: const Text(
              'TEK SEFERLİK',
              style: TextStyle(
                color: Colors.black, fontSize: 10,
                fontWeight: FontWeight.w900, letterSpacing: 0.5,
              ),
            ),
          ),
        ]),

        const SizedBox(height: 6),
        Text(
          'Birkaç kahve fiyatına 1 yıl boyunca profesyonel veteriner paneli',
          style: DsTypography.caption(color: DsColors.accentGreen)
              .copyWith(fontWeight: FontWeight.w700),
        ),

        const SizedBox(height: 18),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.08),
            borderRadius: DsRadius.brSm,
          ),
          child: Text(
            'Veteriner Profesyonel Paketi ile uygulamada neler yapabilirsiniz:',
            style: DsTypography.label(color: Colors.white).copyWith(letterSpacing: 0.2),
          ),
        ),

        const SizedBox(height: 14),

        ..._vetFeatures.map((feat) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 5),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Icon(Icons.check_circle, color: DsColors.accentGreen, size: 18),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(feat['title']!,
                          style: DsTypography.subtitle(color: Colors.white)
                              .copyWith(fontSize: 13)),
                      const SizedBox(height: 2),
                      Text(feat['desc']!,
                          style: DsTypography.caption(color: Colors.white70)
                              .copyWith(height: 1.4)),
                    ],
                  ),
                ),
              ]),
            )),

        const SizedBox(height: 18),

        SizedBox(
          width: double.infinity,
          height: 54,
          child: ElevatedButton(
            onPressed: _processing ? null : () => _purchase(SubscriptionPlan.vet),
            style: ElevatedButton.styleFrom(
              backgroundColor: DsColors.premium,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: DsRadius.brMd),
            ),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('Aboneliği Başlat',
                    style: TextStyle(
                      color: Colors.white, fontWeight: FontWeight.w800, fontSize: 16,
                    )),
                SizedBox(width: 8),
                Icon(Icons.arrow_forward_rounded, color: Colors.white, size: 20),
              ],
            ),
          ),
        ),
      ]),
    );
  }

  // Vet özelliklerinin detaylı listesi — paywall'da gösterilir.
  static const List<Map<String, String>> _vetFeatures = [
    {
      'title': 'Sınırsız Çiftliğe Hizmet',
      'desc': 'Tek hesapla istediğiniz kadar çiftliğe veteriner olarak bağlanın',
    },
    {
      'title': 'Anlık Sağlık Talep Bildirimleri',
      'desc': 'Çiftliklerden gelen acil sağlık talepleri push notification ile gelir',
    },
    {
      'title': 'Hayvan Sağlık Geçmişi',
      'desc': 'Tüm çiftliklerin hayvan kartları, geçmiş muayene + aşı kayıtları',
    },
    {
      'title': 'Sağlık + Aşı Kaydı Ekleme',
      'desc': 'Muayene, tedavi, aşı kayıtlarını doğrudan uygulamadan ekleyin',
    },
    {
      'title': 'Doğum + Buzağı Takibi',
      'desc': 'Gebe hayvanların doğum tarihleri + yeni buzağı kayıtlarını görüntüleme',
    },
    {
      'title': 'Çoklu Çiftlik Geçişi',
      'desc': 'Tek dokunuşla farklı çiftlikler arasında geçiş',
    },
    {
      'title': 'Mobil Erişim',
      'desc': 'Saha çalışmasında telefonla anında kayıt + geçmiş incele',
    },
    {
      'title': 'Profesyonel Kimlik',
      'desc': 'Çiftlik sahipleri Veteriner Profesyonel rozetinizi görür',
    },
  ];

  Widget _buildPlanCard({
    required SubscriptionPlan plan,
    required String emoji,
    required String title,
    required String tagline,
    required String monthlyPrice,
    required String yearlyPrice,
    required List<String> features,
    required Color color,
    bool featured = false,
  }) {
    final price = _yearly ? yearlyPrice : monthlyPrice;
    final priceUnit = _yearly ? '/yıl' : '/ay';
    final yearlyMonthly = _yearly
        ? '~₺${(double.parse(yearlyPrice.replaceAll('₺', '').replaceAll('.', '').replaceAll(',', '.')) / 12).toStringAsFixed(0)}/ay'
        : '';
    final isHighlighted = widget.highlightPlan == plan;

    return Container(
      decoration: BoxDecoration(
        gradient: featured || isHighlighted
            ? LinearGradient(
                begin: Alignment.topLeft, end: Alignment.bottomRight,
                colors: [color.withValues(alpha: 0.15), color.withValues(alpha: 0.05)],
              )
            : null,
        color: featured || isHighlighted ? null : Colors.white.withValues(alpha: 0.04),
        borderRadius: DsRadius.brXl,
        border: Border.all(
          color: featured || isHighlighted
              ? color.withValues(alpha: 0.6)
              : Colors.white.withValues(alpha: 0.08),
          width: featured || isHighlighted ? 2 : 1,
        ),
        boxShadow: featured || isHighlighted
            ? [
                BoxShadow(
                  color: color.withValues(alpha: 0.25),
                  blurRadius: 24,
                  offset: const Offset(0, 8),
                ),
              ]
            : null,
      ),
      padding: const EdgeInsets.all(20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Text(emoji, style: const TextStyle(fontSize: 28)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(title,
                    style: DsTypography.headline(color: Colors.white)
                        .copyWith(fontSize: 18)),
                Text(tagline,
                    style: DsTypography.caption(color: color)
                        .copyWith(fontWeight: FontWeight.w700, letterSpacing: 0.3)),
              ],
            ),
          ),
          if (featured)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: color,
                borderRadius: DsRadius.brSm,
              ),
              child: const Text(
                '⭐ POPÜLER',
                style: TextStyle(
                  color: Colors.black, fontSize: 9,
                  fontWeight: FontWeight.w900, letterSpacing: 0.5,
                ),
              ),
            ),
        ]),

        const SizedBox(height: 14),

        Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text(
            price,
            style: DsTypography.titleLarge(color: Colors.white).copyWith(
              fontSize: 28, fontWeight: FontWeight.w900,
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(bottom: 5, left: 4),
            child: Text(priceUnit,
                style: DsTypography.body(color: Colors.white60)),
          ),
          if (yearlyMonthly.isNotEmpty) ...[
            const Spacer(),
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Text(
                yearlyMonthly,
                style: DsTypography.caption(color: DsColors.accentGreen)
                    .copyWith(fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ]),

        const SizedBox(height: 14),

        ...features.map((f) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Row(children: [
                Icon(Icons.check_circle, color: color, size: 16),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(f,
                      style: DsTypography.bodySmall(color: Colors.white.withValues(alpha: 0.85))),
                ),
              ]),
            )),

        const SizedBox(height: 14),

        SizedBox(
          width: double.infinity,
          height: 48,
          child: ElevatedButton(
            onPressed: _processing ? null : () => _purchase(plan),
            style: ElevatedButton.styleFrom(
              backgroundColor: color,
              foregroundColor: featured ? Colors.black : Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: DsRadius.brMd),
            ),
            child: Text(
              '$title Seç',
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
            ),
          ),
        ),
      ]),
    );
  }

  bool get defaultTargetPlatformIsApple {
    final p = Theme.of(context).platform;
    return p == TargetPlatform.iOS || p == TargetPlatform.macOS;
  }

  Future<void> _openUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Bağlantı açılamadı: $url')),
      );
    }
  }
}
