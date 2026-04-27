import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../core/services/auth_service.dart';
import '../../core/constants/app_constants.dart';
import '../auth/login_screen.dart';

/// KVKK uyumlu hesap silme akışı.
///
/// - Kullanıcıya net uyarı gösterilir (geri alınamaz)
/// - Owner hesaplar için çiftliğin tüm verisinin silineceği belirtilir
/// - Şifre ile re-authentication + email teyit input'u istenir
class DeleteAccountScreen extends StatefulWidget {
  const DeleteAccountScreen({super.key});

  @override
  State<DeleteAccountScreen> createState() => _DeleteAccountScreenState();
}

class _DeleteAccountScreenState extends State<DeleteAccountScreen> {
  final _emailConfirmCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool _deleting = false;
  bool _obscure = true;

  @override
  void dispose() {
    _emailConfirmCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _delete() async {
    final user = AuthService.instance.currentUser;
    if (user == null) return;

    // Teyit: kullanıcı email'ini doğru girdi mi?
    if (_emailConfirmCtrl.text.trim().toLowerCase() != user.email.toLowerCase()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('E-posta teyit alanı eşleşmiyor')),
      );
      return;
    }
    if (_passwordCtrl.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Şifrenizi girin')),
      );
      return;
    }

    final isOwner = user.isMainOwner;
    final finalOk = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Row(children: [
          Icon(Icons.warning_amber_rounded, color: AppColors.errorRed),
          SizedBox(width: 10),
          Text('Son Onay'),
        ]),
        content: Text(
          isOwner
              ? 'Hesabınız ve çiftliğinize ait TÜM veriler (hayvanlar, süt kayıtları, finans, '
                'sağlık, aşı, görevler, izinler, üyeler) kalıcı olarak silinecek. '
                'Bu işlem geri alınamaz.\n\nDevam etmek istiyor musunuz?'
              : 'Hesabınız silinecek ve bu çiftlikteki üyeliğiniz sona erecek. '
                'Bu işlem geri alınamaz.\n\nDevam etmek istiyor musunuz?',
          style: const TextStyle(height: 1.5),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Vazgeç')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.errorRed),
            child: const Text('Hesabı Sil'),
          ),
        ],
      ),
    );
    if (finalOk != true) return;

    setState(() => _deleting = true);
    final err = await AuthService.instance.deleteMyAccount(
      currentPassword: _passwordCtrl.text,
    );
    if (!mounted) return;
    if (err != null) {
      setState(() => _deleting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(err), backgroundColor: AppColors.errorRed),
      );
      return;
    }

    // Login'e dön — geriye yığını temizle
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (_) => false,
    );
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Hesabınız ve verileriniz kalıcı olarak silindi'),
        backgroundColor: AppColors.primaryGreen,
        duration: Duration(seconds: 4),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = AuthService.instance.currentUser;
    final isOwner = user?.isMainOwner ?? false;
    final roleLabel = AppConstants.roleLabels[user?.role ?? ''] ?? '';

    return Scaffold(
      appBar: AppBar(title: const Text('Hesabı Sil')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Uyarı kartı
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.errorRed.withValues(alpha: 0.08),
              border: Border.all(color: AppColors.errorRed.withValues(alpha: 0.4)),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Row(children: [
                Icon(Icons.warning_amber_rounded, color: AppColors.errorRed),
                SizedBox(width: 8),
                Expanded(child: Text(
                  'KVKK Uyumu — Silme Hakkı',
                  style: TextStyle(fontWeight: FontWeight.w800, color: AppColors.errorRed, fontSize: 14),
                )),
              ]),
              const SizedBox(height: 8),
              const Text(
                'Hesabınızı silerek kişisel verilerinizin kalıcı olarak silinmesini '
                'talep edebilirsiniz. Bu işlem GERİ ALINAMAZ.',
                style: TextStyle(fontSize: 12, height: 1.5),
              ),
              const SizedBox(height: 12),
              Text(
                isOwner
                    ? 'Ana Sahip olarak silme işlemi:'
                    : '$roleLabel olarak silme işlemi:',
                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
              ),
              const SizedBox(height: 6),
              Text(
                isOwner
                    ? '• Çiftliğiniz ve altındaki TÜM veriler (hayvanlar, süt, finans, sağlık, '
                      'aşı, görevler, izinler, üyeler) silinir\n'
                      '• Yardımcı/Ortak/Vet/Personel hesaplarının erişimi sona erer\n'
                      '• Firebase Auth hesabınız kapatılır'
                    : '• Bu çiftlikteki üyeliğiniz kaldırılır\n'
                      '• Hesap profili ve çoklu çiftlik üyelikleriniz silinir\n'
                      '• Firebase Auth hesabınız kapatılır\n'
                      '• Çiftliğin verileri (siz sildirdiğiniz için) silinmez',
                style: const TextStyle(fontSize: 11, height: 1.6),
              ),
            ]),
          ),
          const SizedBox(height: 20),

          // Email teyit
          const Text('E-posta Teyidi', style: TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text(
            'Silme işlemini onaylamak için e-posta adresinizi yazın:',
            style: const TextStyle(fontSize: 12, color: AppColors.textGrey),
          ),
          const SizedBox(height: 4),
          Text(
            user?.email ?? '',
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _emailConfirmCtrl,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(
              labelText: 'E-posta',
              prefixIcon: Icon(Icons.email_outlined),
            ),
          ),
          const SizedBox(height: 16),

          // Şifre
          const Text('Şifre', style: TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          const Text(
            'Güvenlik için mevcut şifrenizi girin:',
            style: TextStyle(fontSize: 12, color: AppColors.textGrey),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _passwordCtrl,
            obscureText: _obscure,
            decoration: InputDecoration(
              labelText: 'Şifre',
              prefixIcon: const Icon(Icons.lock_outline),
              suffixIcon: IconButton(
                icon: Icon(_obscure ? Icons.visibility : Icons.visibility_off),
                onPressed: () => setState(() => _obscure = !_obscure),
              ),
            ),
          ),

          const SizedBox(height: 30),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton.icon(
              onPressed: _deleting ? null : _delete,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.errorRed,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              icon: _deleting
                  ? const SizedBox(width: 18, height: 18,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Icon(Icons.delete_forever, color: Colors.white),
              label: Text(
                _deleting ? 'Siliniyor...' : 'Hesabımı Kalıcı Olarak Sil',
                style: const TextStyle(
                  color: Colors.white, fontWeight: FontWeight.w800, fontSize: 15,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
