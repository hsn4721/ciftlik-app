import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/theme/app_theme.dart';
import '../../core/constants/app_constants.dart';
import '../../core/services/auth_service.dart';
import '../../core/services/vet_request_service.dart';
import '../../data/models/vet_request_model.dart';
import 'vet_request_detail_screen.dart';
import 'vet_request_form_screen.dart';

/// Veteriner talep listesi. İki mod:
/// - `asVet`: Vet rolü için kendisine gelen talepleri gösterir
/// - `asRequester`: Owner/Assistant için kendi açtığı talepleri gösterir
class VetRequestListScreen extends StatelessWidget {
  final bool asVet;
  const VetRequestListScreen({super.key, required this.asVet});

  @override
  Widget build(BuildContext context) {
    final user = AuthService.instance.currentUser;
    if (user == null) {
      return const Scaffold(body: Center(child: Text('Oturum açılmamış')));
    }

    final stream = asVet
        ? VetRequestService.instance.streamRequestsForVet(farmId: user.farmId, vetId: user.uid)
        : VetRequestService.instance.streamMyRequests(farmId: user.farmId, requesterId: user.uid);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(asVet ? 'Gelen Talepler' : 'Veteriner Talepleri'),
      ),
      floatingActionButton: asVet
          ? null
          : (user.hasFullControl
              ? FloatingActionButton.extended(
                  onPressed: () => Navigator.push(context,
                      MaterialPageRoute(builder: (_) => const VetRequestFormScreen())),
                  backgroundColor: AppColors.primaryGreen,
                  icon: const Icon(Icons.add, color: Colors.white),
                  label: const Text('Veteriner Çağır',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                )
              : null),
      body: StreamBuilder<List<VetRequestModel>>(
        stream: stream,
        builder: (_, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return Center(child: Text('Hata: ${snap.error}'));
          }
          final items = snap.data ?? const [];
          if (items.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.inbox_outlined, size: 56, color: AppColors.textGrey),
                    const SizedBox(height: 14),
                    Text(
                      asVet ? 'Henüz talep yok' : 'Henüz veteriner çağrısı yapmadınız',
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      asVet
                          ? 'Ana Sahip veya Yardımcı size talep gönderince burada görünür.'
                          : 'Acil durumlar için veterinere hızlı istek oluşturun.',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: AppColors.textGrey, fontSize: 12, height: 1.4),
                    ),
                  ],
                ),
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 80),
            itemCount: items.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (_, i) => _RequestTile(req: items[i], asVet: asVet),
          );
        },
      ),
    );
  }
}

class _RequestTile extends StatelessWidget {
  final VetRequestModel req;
  final bool asVet;
  const _RequestTile({required this.req, required this.asVet});

  Color get _urgencyColor {
    switch (req.urgency) {
      case AppConstants.urgencyCritical: return AppColors.errorRed;
      case AppConstants.urgencyHigh:     return AppColors.gold;
      default:                           return AppColors.primaryGreen;
    }
  }

  IconData get _categoryIcon {
    switch (req.category) {
      case AppConstants.vetCatBirth:        return Icons.child_friendly;
      case AppConstants.vetCatCalfHealth:   return Icons.baby_changing_station;
      case AppConstants.vetCatAnimalHealth: return Icons.favorite;
      default:                              return Icons.medical_services;
    }
  }

  @override
  Widget build(BuildContext context) {
    final unread = !req.isRead;
    final timeFmt = DateFormat('d MMM HH:mm', 'tr_TR');

    return InkWell(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => VetRequestDetailScreen(req: req, asVet: asVet)),
      ),
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border(left: BorderSide(color: _urgencyColor, width: 4)),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 6)],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: _urgencyColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(_categoryIcon, color: _urgencyColor, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          req.reason,
                          style: TextStyle(
                            fontWeight: unread ? FontWeight.w800 : FontWeight.w600,
                            fontSize: 14,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: _urgencyColor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(req.urgencyLabel,
                            style: TextStyle(fontSize: 10, color: _urgencyColor, fontWeight: FontWeight.w800)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${req.categoryLabel} · ${asVet ? req.requesterName : req.vetName}',
                    style: const TextStyle(fontSize: 12, color: AppColors.textGrey),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Text(timeFmt.format(req.createdAt),
                          style: const TextStyle(fontSize: 11, color: AppColors.textGrey)),
                      const Spacer(),
                      if (req.isRead) ...[
                        const Icon(Icons.done_all, size: 14, color: AppColors.infoBlue),
                        const SizedBox(width: 3),
                        Text('Okundu', style: TextStyle(fontSize: 11, color: AppColors.infoBlue, fontWeight: FontWeight.w700)),
                      ] else if (asVet) ...[
                        Container(
                          width: 8, height: 8,
                          decoration: BoxDecoration(color: _urgencyColor, shape: BoxShape.circle),
                        ),
                      ] else ...[
                        Text('Gönderildi — bekliyor',
                            style: TextStyle(fontSize: 11, color: AppColors.textGrey, fontStyle: FontStyle.italic)),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
