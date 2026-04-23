import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/theme/app_theme.dart';
import '../../core/services/auth_service.dart';

class FeedbackScreen extends StatefulWidget {
  const FeedbackScreen({super.key});

  @override
  State<FeedbackScreen> createState() => _FeedbackScreenState();
}

class _FeedbackScreenState extends State<FeedbackScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleCtrl = TextEditingController();
  final _descCtrl = TextEditingController();

  int _rating = 0;
  String _category = 'Özellik İsteği';
  bool _sending = false;

  static const _categories = [
    _Category('Hata Bildirimi', Icons.bug_report_outlined, Color(0xFFD32F2F)),
    _Category('Özellik İsteği', Icons.lightbulb_outline, Color(0xFFF57F17)),
    _Category('Genel Görüş', Icons.chat_bubble_outline, AppColors.infoBlue),
    _Category('Diğer', Icons.more_horiz, AppColors.textGrey),
  ];

  static const _devEmail = 'hsnduz@hotmail.com';

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_rating == 0) {
      _showError('Lütfen bir puan seçin.');
      return;
    }

    setState(() => _sending = true);

    final user = AuthService.instance.currentUser;
    final now = DateTime.now();
    final Map<String, dynamic> doc = {
      'category': _category,
      'rating': _rating,
      'title': _titleCtrl.text.trim(),
      'description': _descCtrl.text.trim(),
      'userName': user?.displayName ?? 'Bilinmiyor',
      'userEmail': user?.email ?? '',
      'farmId': user?.farmId ?? '',
      'appVersion': '1.0.0',
      'platform': Theme.of(context).platform.name,
      'createdAt': now.toIso8601String(),
    };

    // Firestore'a kaydet
    try {
      await FirebaseFirestore.instance.collection('feedback').add(doc);
    } catch (_) {
      // Offline olsa bile mail açılmaya devam etsin
    }

    // Mailto ile mail oluştur
    final stars = '${'★' * _rating}${'☆' * (5 - _rating)}';
    final subject = Uri.encodeComponent('[$_category] ${_titleCtrl.text.trim()} — ÇiftlikPRO Geri Bildirim');
    final body = Uri.encodeComponent(
      '━━━━━━━━━━━━━━━━━━━━━━\n'
      '  ÇiftlikPRO — Geri Bildirim\n'
      '━━━━━━━━━━━━━━━━━━━━━━\n\n'
      'Kategori  : $_category\n'
      'Puan      : $stars ($_rating/5)\n'
      'Başlık    : ${_titleCtrl.text.trim()}\n\n'
      'Açıklama  :\n${_descCtrl.text.trim()}\n\n'
      '─────────────────────\n'
      'Kullanıcı : ${user?.displayName ?? "Bilinmiyor"}\n'
      'E-posta   : ${user?.email ?? "-"}\n'
      'Farm ID   : ${user?.farmId ?? "-"}\n'
      'Tarih     : ${_formatDate(now)}\n'
      '━━━━━━━━━━━━━━━━━━━━━━\n',
    );

    final mailUri = Uri.parse('mailto:$_devEmail?subject=$subject&body=$body');

    setState(() => _sending = false);

    if (!mounted) return;

    if (await canLaunchUrl(mailUri)) {
      await launchUrl(mailUri);
      if (!mounted) return;
      _showSuccess();
    } else {
      _showError('Mail uygulaması bulunamadı. Geri bildiriminiz kaydedildi.');
    }
  }

  void _showSuccess() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        contentPadding: EdgeInsets.zero,
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(28),
              decoration: const BoxDecoration(
                gradient: LinearGradient(colors: [AppColors.primaryGreen, AppColors.mediumGreen]),
                borderRadius: BorderRadius.only(topLeft: Radius.circular(20), topRight: Radius.circular(20)),
              ),
              child: const Column(children: [
                Icon(Icons.check_circle_outline, color: Colors.white, size: 54),
                SizedBox(height: 10),
                Text('Teşekkürler!', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800)),
              ]),
            ),
            Padding(
              padding: const EdgeInsets.all(24),
              child: Column(children: [
                const Text(
                  'Geri bildiriminiz başarıyla alındı ve kaydedildi. Mail uygulamanız açıldıysa göndermek için "Gönder"e dokunun.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 13, color: AppColors.textGrey, height: 1.6),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context);
                      Navigator.pop(context);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryGreen,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: const Text('Tamam', style: TextStyle(fontWeight: FontWeight.w700)),
                  ),
                ),
              ]),
            ),
          ],
        ),
      ),
    );
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: AppColors.errorRed),
    );
  }

  String _formatDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}.${d.year} '
      '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Geri Bildirim')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Açıklama banner
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [AppColors.primaryGreen, AppColors.mediumGreen],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Row(children: [
                  Icon(Icons.feedback_outlined, color: Colors.white, size: 36),
                  SizedBox(width: 14),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('Görüşleriniz değerlidir',
                        style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w800)),
                    SizedBox(height: 3),
                    Text('Hata, öneri veya görüşlerinizi paylaşın.\nHer bildirim uygulamayı geliştiriyor.',
                        style: TextStyle(color: Colors.white70, fontSize: 12, height: 1.5)),
                  ])),
                ]),
              ),
              const SizedBox(height: 20),

              // Puan
              _SectionLabel(label: 'Genel Memnuniyet'),
              const SizedBox(height: 10),
              _RatingBar(
                value: _rating,
                onChanged: (v) => setState(() => _rating = v),
              ),
              const SizedBox(height: 20),

              // Kategori
              _SectionLabel(label: 'Geri Bildirim Türü'),
              const SizedBox(height: 10),
              GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
                childAspectRatio: 3.2,
                children: _categories.map((cat) {
                  final selected = _category == cat.label;
                  return GestureDetector(
                    onTap: () => setState(() => _category = cat.label),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      decoration: BoxDecoration(
                        color: selected ? cat.color.withValues(alpha: 0.12) : Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: selected ? cat.color : AppColors.divider,
                          width: selected ? 1.5 : 1,
                        ),
                        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 4)],
                      ),
                      child: Row(children: [
                        const SizedBox(width: 12),
                        Icon(cat.icon, color: selected ? cat.color : AppColors.textGrey, size: 18),
                        const SizedBox(width: 8),
                        Expanded(child: Text(cat.label,
                          style: TextStyle(
                            fontSize: 12, fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                            color: selected ? cat.color : AppColors.textGrey,
                          ))),
                      ]),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 20),

              // Başlık
              _SectionLabel(label: 'Başlık'),
              const SizedBox(height: 8),
              TextFormField(
                controller: _titleCtrl,
                decoration: _inputDec('Kısaca özetleyin', Icons.title),
                validator: (v) => (v == null || v.trim().length < 5) ? 'En az 5 karakter girin' : null,
              ),
              const SizedBox(height: 16),

              // Açıklama
              _SectionLabel(label: 'Açıklama'),
              const SizedBox(height: 8),
              TextFormField(
                controller: _descCtrl,
                maxLines: 5,
                maxLength: 1000,
                decoration: _inputDec('Detaylı açıklayın — ne gördünüz, ne bekliyordunuz?', Icons.description_outlined),
                validator: (v) => (v == null || v.trim().length < 20) ? 'En az 20 karakter girin' : null,
              ),
              const SizedBox(height: 8),

              // Bilgi notu
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.infoBlue.withValues(alpha: 0.07),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Icon(Icons.info_outline, color: AppColors.infoBlue, size: 15),
                  SizedBox(width: 8),
                  Expanded(child: Text(
                    'Gönder butonuna bastığınızda mail uygulamanız açılacak. '
                    '"Gönder"e basarak bildiriminizi iletin. '
                    'Geri bildirimler ayrıca sisteme de kaydedilir.',
                    style: TextStyle(fontSize: 11, color: AppColors.infoBlue, height: 1.5),
                  )),
                ]),
              ),
              const SizedBox(height: 24),

              // Gönder butonu
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _sending ? null : _submit,
                  icon: _sending
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.send_rounded),
                  label: Text(_sending ? 'Gönderiliyor...' : 'Geri Bildirim Gönder',
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryGreen,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: AppColors.primaryGreen.withValues(alpha: 0.6),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    elevation: 2,
                  ),
                ),
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  InputDecoration _inputDec(String hint, IconData icon) => InputDecoration(
        hintText: hint,
        prefixIcon: Icon(icon, size: 20, color: AppColors.textGrey),
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.divider)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.divider)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.primaryGreen, width: 1.5)),
        errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.errorRed)),
        focusedErrorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.errorRed, width: 1.5)),
      );
}

// ─── Alt Bileşenler ──────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  final String label;
  const _SectionLabel({required this.label});

  @override
  Widget build(BuildContext context) => Text(
        label,
        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textDark),
      );
}

class _RatingBar extends StatelessWidget {
  final int value;
  final ValueChanged<int> onChanged;
  const _RatingBar({required this.value, required this.onChanged});

  static const _labels = ['', 'Çok Kötü', 'Kötü', 'Orta', 'İyi', 'Mükemmel'];
  static const _colors = [
    Colors.transparent,
    Color(0xFFD32F2F),
    Color(0xFFFF7043),
    Color(0xFFFFA000),
    Color(0xFF7CB342),
    Color(0xFF2E7D32),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: List.generate(5, (i) {
            final star = i + 1;
            final filled = star <= value;
            return GestureDetector(
              onTap: () => onChanged(star),
              child: AnimatedScale(
                scale: filled ? 1.15 : 1.0,
                duration: const Duration(milliseconds: 150),
                child: Icon(
                  filled ? Icons.star_rounded : Icons.star_outline_rounded,
                  size: 44,
                  color: filled ? _colors[value] : AppColors.divider,
                ),
              ),
            );
          }),
        ),
        if (value > 0) ...[
          const SizedBox(height: 8),
          Text(_labels[value],
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: _colors[value])),
        ],
      ]),
    );
  }
}

class _Category {
  final String label;
  final IconData icon;
  final Color color;
  const _Category(this.label, this.icon, this.color);
}
