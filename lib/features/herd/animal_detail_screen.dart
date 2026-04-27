import 'dart:io';
import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../core/services/auth_service.dart';
import '../../data/models/animal_model.dart';
import '../../data/repositories/animal_repository.dart';
import '../milk/milk_screen.dart';
import '../health/health_screen.dart';
import 'add_animal_screen.dart';

class AnimalDetailScreen extends StatelessWidget {
  final AnimalModel animal;
  const AnimalDetailScreen({super.key, required this.animal});

  Color get _statusColor {
    switch (animal.status) {
      case 'Sağımda': return AppColors.infoBlue;
      case 'Kuruda': return AppColors.gold;
      case 'Gebe': return const Color(0xFF6A1B9A);
      case 'Hasta': return AppColors.errorRed;
      default: return AppColors.primaryGreen;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 200,
            pinned: true,
            backgroundColor: AppColors.primaryGreen,
            actions: [
              // Sadece Ana Sahip + Yardımcı düzenleyebilir/silebilir.
              // Vet, worker, partner hayvan kartını değiştiremez.
              if (AuthService.instance.currentUser?.canEditAnimal ?? true)
                IconButton(
                  icon: const Icon(Icons.edit, color: Colors.white),
                  onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => AddAnimalScreen(animal: animal))),
                ),
              if (AuthService.instance.currentUser?.canRemoveAnimal ?? true)
                IconButton(
                  icon: const Icon(Icons.delete_outline, color: Colors.white),
                  onPressed: () => _confirmDelete(context),
                ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [AppColors.primaryGreen, AppColors.mediumGreen],
                  ),
                ),
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            animal.photoPath != null
                                ? Container(
                                    width: 64,
                                    height: 64,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      border: Border.all(color: Colors.white, width: 2.5),
                                    ),
                                    clipBehavior: Clip.antiAlias,
                                    child: Image.file(File(animal.photoPath!), fit: BoxFit.cover),
                                  )
                                : Container(
                                    padding: const EdgeInsets.all(14),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withValues(alpha: 0.2),
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                    child: const Icon(Icons.pets, color: Colors.white, size: 32),
                                  ),
                            const SizedBox(width: 16),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  animal.name ?? animal.earTag,
                                  style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w800),
                                ),
                                if (animal.name != null)
                                  Text(animal.earTag, style: const TextStyle(color: Colors.white70, fontSize: 14)),
                                const SizedBox(height: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: _statusColor,
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Text(animal.status, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700)),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  // Temel bilgiler
                  _InfoCard(title: 'Temel Bilgiler', items: [
                    _InfoItem(label: 'Küpe No', value: animal.earTag, icon: Icons.tag),
                    _InfoItem(label: 'Irk', value: animal.breed, icon: Icons.pets),
                    _InfoItem(label: 'Cinsiyet', value: animal.gender, icon: Icons.transgender),
                    _InfoItem(label: 'Yaş', value: animal.ageDisplay, icon: Icons.cake_outlined),
                    if (animal.weight != null)
                      _InfoItem(label: 'Ağırlık', value: '${animal.weight} kg', icon: Icons.monitor_weight_outlined),
                  ]),
                  const SizedBox(height: 16),
                  _InfoCard(title: 'Kayıt Bilgileri', items: [
                    _InfoItem(label: 'Doğum Tarihi', value: animal.birthDate, icon: Icons.calendar_today),
                    _InfoItem(label: 'Giriş Tarihi', value: animal.entryDate, icon: Icons.login),
                    _InfoItem(label: 'Giriş Türü', value: animal.entryType, icon: Icons.input),
                  ]),
                  if (animal.notes != null) ...[
                    const SizedBox(height: 16),
                    _InfoCard(title: 'Notlar', items: [
                      _InfoItem(label: 'Not', value: animal.notes!, icon: Icons.notes),
                    ]),
                  ],
                  const SizedBox(height: 16),
                  // Hızlı işlemler — rol bazlı filtrelenir
                  Builder(builder: (context) {
                    final u = AuthService.instance.currentUser;
                    final buttons = <Widget>[
                      // Sağım Gir yalnızca sağım yetkisi olana (worker + owner + assistant)
                      if (u?.canAddMilking ?? true)
                        Expanded(child: _ActionButton(
                          label: 'Sağım Gir', icon: Icons.water_drop, color: AppColors.infoBlue,
                          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const MilkScreen())),
                        )),
                      if (u?.canManageHealth ?? true)
                        Expanded(child: _ActionButton(
                          label: 'Sağlık Kaydı', icon: Icons.favorite, color: AppColors.errorRed,
                          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const HealthScreen())),
                        )),
                      if (u?.canManageHealth ?? true)
                        Expanded(child: _ActionButton(
                          label: 'Aşı Ekle', icon: Icons.vaccines, color: AppColors.primaryGreen,
                          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const HealthScreen())),
                        )),
                    ];
                    if (buttons.isEmpty) return const SizedBox.shrink();
                    return Row(
                      children: [
                        for (int i = 0; i < buttons.length; i++) ...[
                          if (i > 0) const SizedBox(width: 10),
                          buttons[i],
                        ],
                      ],
                    );
                  }),
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _confirmDelete(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Hayvanı Sil'),
        content: Text('${animal.name ?? animal.earTag} kaydını silmek istediğinize emin misiniz?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('İptal')),
          TextButton(
            onPressed: () async {
              await AnimalRepository().delete(animal.id!);
              if (ctx.mounted) { Navigator.pop(ctx); Navigator.pop(context); }
            },
            child: const Text('Sil', style: TextStyle(color: AppColors.errorRed, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  final String title;
  final List<_InfoItem> items;
  const _InfoCard({required this.title, required this.items});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
            child: Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.primaryGreen)),
          ),
          const Divider(height: 1, color: AppColors.divider),
          ...items.map((item) => Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  children: [
                    Icon(item.icon, size: 18, color: AppColors.primaryGreen),
                    const SizedBox(width: 12),
                    Text(item.label, style: const TextStyle(fontSize: 13, color: AppColors.textGrey)),
                    const Spacer(),
                    Text(item.value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textDark)),
                  ],
                ),
              ),
              if (item != items.last) const Divider(height: 1, indent: 46, color: AppColors.divider),
            ],
          )),
        ],
      ),
    );
  }
}

class _InfoItem {
  final String label;
  final String value;
  final IconData icon;
  const _InfoItem({required this.label, required this.value, required this.icon});
}

class _ActionButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  const _ActionButton({required this.label, required this.icon, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 6),
            Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: color)),
          ],
        ),
      ),
    );
  }
}
