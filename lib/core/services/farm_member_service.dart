import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../../data/models/farm_member_model.dart';

/// Çiftlik üyesi (`farms/{farmId}/members`) CRUD servisi.
/// Üye oluşturma Kullanıcı Yönetimi akışında (AuthService.inviteVet /
/// inviteUserWithPassword) gerçekleşir — bu servis yalnızca okuma ve kısmi
/// güncellemeler (maaş, telefon, notlar, aktiflik) için kullanılır.
class FarmMemberService {
  FarmMemberService._();
  static final FarmMemberService instance = FarmMemberService._();

  final _db = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> _col(String farmId) =>
      _db.collection('farms').doc(farmId).collection('members');

  /// Çiftliğin tüm üyeleri — canlı akış.
  Stream<List<FarmMember>> streamMembers(String farmId) {
    return _col(farmId)
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => FarmMember.fromSnap(d, farmId))
            .toList())
        .handleError((e) {
      debugPrint('[FarmMemberService.streamMembers] $e');
    });
  }

  /// Aylık maaşı güncelle. Null geçilirse alan silinir.
  /// Başarılıysa null döner, başarısızsa UI'ya gösterilecek hata mesajı.
  Future<String?> updateSalary({
    required String farmId,
    required String uid,
    required double? monthlySalary,
  }) async {
    try {
      await _col(farmId).doc(uid).update({
        'monthlySalary': monthlySalary,
      });
      return null;
    } catch (e) {
      debugPrint('[FarmMemberService.updateSalary] $e');
      return 'Maaş güncellenemedi: $e';
    }
  }

  /// Telefon/notlar gibi bilgileri güncelle.
  Future<String?> updateInfo({
    required String farmId,
    required String uid,
    String? phone,
    String? notes,
  }) async {
    try {
      final data = <String, dynamic>{};
      if (phone != null) data['phone'] = phone.isEmpty ? null : phone;
      if (notes != null) data['notes'] = notes.isEmpty ? null : notes;
      if (data.isEmpty) return null;
      await _col(farmId).doc(uid).update(data);
      return null;
    } catch (e) {
      debugPrint('[FarmMemberService.updateInfo] $e');
      return 'Bilgi güncellenemedi: $e';
    }
  }
}
