import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../core/theme/app_theme.dart';
import '../../core/constants/app_constants.dart';
import '../../core/services/auth_service.dart';
import '../../core/services/vet_request_service.dart';
import '../../data/models/user_model.dart';
import '../../data/models/vet_request_model.dart';

/// Veteriner çağır formu — Ana Sahip + Yardımcı kullanır.
class VetRequestFormScreen extends StatefulWidget {
  const VetRequestFormScreen({super.key});

  @override
  State<VetRequestFormScreen> createState() => _VetRequestFormScreenState();
}

class _VetRequestFormScreenState extends State<VetRequestFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _animalTagCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();

  List<UserModel> _vets = [];
  UserModel? _selectedVet;
  String _category = AppConstants.vetCatAnimalHealth;
  String? _reason;
  String _urgency = AppConstants.urgencyHigh;
  String? _farmName;
  bool _loading = true;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadInitial();
  }

  @override
  void dispose() {
    _animalTagCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadInitial() async {
    final user = AuthService.instance.currentUser;
    if (user == null) return;
    final farmId = user.activeFarmId;
    if (farmId == null || farmId.isEmpty) {
      if (mounted) {
        setState(() {
          _error = 'Aktif çiftlik seçili değil';
          _loading = false;
        });
      }
      return;
    }
    try {
      // Aktif çiftlikteki veterinerleri farms/{farmId}/members altından çek
      final membersSnap = await FirebaseFirestore.instance
          .collection('farms')
          .doc(farmId)
          .collection('members')
          .where('role', isEqualTo: AppConstants.roleVet)
          .where('isActive', isEqualTo: true)
          .get();
      final vets = membersSnap.docs.map((d) {
        final m = d.data();
        return UserModel(
          uid: (m['uid'] ?? d.id).toString(),
          email: (m['email'] ?? '').toString(),
          displayName: (m['displayName'] ?? '').toString(),
          createdAt: DateTime.now(),
        );
      }).toList();

      // Çiftlik adını çek (farmId yukarıda doğrulandı)
      final farmDoc = await FirebaseFirestore.instance
          .collection('farms')
          .doc(farmId)
          .get();
      final farmName = farmDoc.data()?['name'] as String?;

      if (!mounted) return;
      setState(() {
        _vets = vets;
        _selectedVet = vets.isNotEmpty ? vets.first : null;
        _farmName = farmName ?? 'Çiftliğim';
        _reason = AppConstants.vetRequestReasons[_category]?.first;
        _loading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Veteriner listesi alınamadı: $e';
          _loading = false;
        });
      }
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedVet == null) {
      setState(() => _error = 'Veteriner seçilmedi');
      return;
    }
    final user = AuthService.instance.currentUser;
    if (user == null) return;
    final farmId = user.activeFarmId;
    if (farmId == null || farmId.isEmpty) {
      setState(() => _error = 'Aktif çiftlik seçili değil');
      return;
    }

    setState(() { _saving = true; _error = null; });

    final req = VetRequestModel(
      farmId: farmId,
      farmName: _farmName ?? 'Çiftliğim',
      requesterId: user.uid,
      requesterName: user.displayName,
      vetId: _selectedVet!.uid,
      vetName: _selectedVet!.displayName,
      category: _category,
      reason: _reason ?? '',
      urgency: _urgency,
      animalTag: _animalTagCtrl.text.trim().isEmpty ? null : _animalTagCtrl.text.trim(),
      notes: _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
      createdAt: DateTime.now(),
    );

    final id = await VetRequestService.instance.createRequest(req);

    if (!mounted) return;
    setState(() => _saving = false);

    if (id != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Talep ${_selectedVet!.displayName}\'e iletildi'),
          backgroundColor: AppColors.primaryGreen,
        ),
      );
      Navigator.pop(context, true);
    } else {
      setState(() => _error = 'Talep gönderilemedi. İnternet bağlantınızı kontrol edin.');
    }
  }

  Color _urgencyColor(String u) {
    switch (u) {
      case AppConstants.urgencyCritical: return AppColors.errorRed;
      case AppConstants.urgencyHigh:     return AppColors.gold;
      default:                           return AppColors.primaryGreen;
    }
  }

  @override
  Widget build(BuildContext context) {
    final reasons = AppConstants.vetRequestReasons[_category] ?? const [];

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Veteriner Çağır')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _vets.isEmpty
              ? _noVetState()
              : Form(
                  key: _formKey,
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      if (_error != null) ...[
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppColors.errorRed.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(children: [
                            const Icon(Icons.error_outline, color: AppColors.errorRed, size: 18),
                            const SizedBox(width: 8),
                            Expanded(child: Text(_error!,
                              style: const TextStyle(color: AppColors.errorRed, fontSize: 12))),
                          ]),
                        ),
                        const SizedBox(height: 12),
                      ],
                      // Veteriner seçimi
                      DropdownButtonFormField<UserModel>(
        initialValue: _selectedVet,
                        decoration: const InputDecoration(
                          labelText: 'Veteriner *',
                          prefixIcon: Icon(Icons.medical_services, color: AppColors.primaryGreen),
                        ),
                        items: _vets.map((v) => DropdownMenuItem(
                          value: v,
                          child: Text(v.displayName),
                        )).toList(),
                        onChanged: (v) => setState(() => _selectedVet = v),
                      ),
                      const SizedBox(height: 16),
                      // Kategori
                      const Text('Kategori', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textGrey)),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: AppConstants.vetRequestCategories.entries.map((e) {
                          final selected = e.key == _category;
                          return ChoiceChip(
                            label: Text(e.value),
                            selected: selected,
                            onSelected: (_) => setState(() {
                              _category = e.key;
                              _reason = AppConstants.vetRequestReasons[_category]?.first;
                            }),
                            selectedColor: AppColors.primaryGreen.withValues(alpha: 0.2),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 16),
                      // Sebep
                      DropdownButtonFormField<String>(
        initialValue: reasons.contains(_reason) ? _reason : (reasons.isNotEmpty ? reasons.first : null),
                        isExpanded: true,
                        decoration: const InputDecoration(
                          labelText: 'Sebep *',
                          prefixIcon: Icon(Icons.report_gmailerrorred, color: AppColors.primaryGreen),
                        ),
                        items: reasons.map((r) => DropdownMenuItem(
                          value: r,
                          child: Text(r, overflow: TextOverflow.ellipsis),
                        )).toList(),
                        onChanged: (v) => setState(() => _reason = v),
                        validator: (v) => v == null || v.isEmpty ? 'Sebep seçin' : null,
                      ),
                      const SizedBox(height: 16),
                      // Aciliyet
                      const Text('Aciliyet Durumu', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textGrey)),
                      const SizedBox(height: 8),
                      Row(
                        children: AppConstants.urgencyLabels.entries.map((e) {
                          final selected = e.key == _urgency;
                          final color = _urgencyColor(e.key);
                          return Expanded(
                            child: Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: GestureDetector(
                                onTap: () => setState(() => _urgency = e.key),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                  decoration: BoxDecoration(
                                    color: selected ? color : color.withValues(alpha: 0.08),
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(color: color, width: 1.5),
                                  ),
                                  child: Center(
                                    child: Text(
                                      e.value,
                                      style: TextStyle(
                                        color: selected ? Colors.white : color,
                                        fontWeight: FontWeight.w700,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _animalTagCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Hayvan Küpe No (opsiyonel)',
                          prefixIcon: Icon(Icons.tag, color: AppColors.primaryGreen),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _notesCtrl,
                        maxLines: 3,
                        decoration: const InputDecoration(
                          labelText: 'Ek Not (opsiyonel)',
                          alignLabelWithHint: true,
                          prefixIcon: Icon(Icons.notes, color: AppColors.primaryGreen),
                          hintText: 'Ek detay varsa yazın...',
                        ),
                      ),
                      const SizedBox(height: 20),
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton.icon(
                          onPressed: _saving ? null : _submit,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _urgencyColor(_urgency),
                          ),
                          icon: _saving
                              ? const SizedBox(width: 18, height: 18,
                                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                              : const Icon(Icons.send, color: Colors.white),
                          label: const Text('Talep Gönder',
                              style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700)),
                        ),
                      ),
                    ],
                  ),
                ),
    );
  }

  Widget _noVetState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.medical_services_outlined, size: 56, color: AppColors.textGrey),
            const SizedBox(height: 16),
            const Text('Kayıtlı Veteriner Yok', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            const Text(
              'Talep göndermek için çiftliğinize veteriner rolünde bir kullanıcı eklemelisiniz.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textGrey, fontSize: 13, height: 1.5),
            ),
            const SizedBox(height: 16),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Geri'),
            ),
          ],
        ),
      ),
    );
  }
}
