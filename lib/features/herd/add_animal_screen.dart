import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../../core/theme/app_theme.dart';
import '../../core/constants/app_constants.dart';
import '../../data/models/animal_model.dart';
import '../../data/repositories/animal_repository.dart';

class AddAnimalScreen extends StatefulWidget {
  final AnimalModel? animal;
  const AddAnimalScreen({super.key, this.animal});

  @override
  State<AddAnimalScreen> createState() => _AddAnimalScreenState();
}

class _AddAnimalScreenState extends State<AddAnimalScreen> {
  final _formKey = GlobalKey<FormState>();
  final _repo = AnimalRepository();

  final _earTagController = TextEditingController();
  final _nameController = TextEditingController();
  final _weightController = TextEditingController();
  final _priceController = TextEditingController();
  final _notesController = TextEditingController();

  String _breed = 'Holstein';
  String _gender = AppConstants.female;
  String _status = AppConstants.animalMilking;
  String _entryType = 'Satın Alma';
  DateTime _birthDate = DateTime.now();
  DateTime _entryDate = DateTime.now();
  bool _isLoading = false;
  String? _photoPath;

  final List<String> _breeds = ['Holstein', 'Simental', 'Montofon', 'Jersey', 'Angus', 'Diğer'];
  final List<String> _entryTypes = ['Satın Alma', 'Hibe', 'Diğer'];

  List<String> get _statuses => _gender == AppConstants.male
      ? AppConstants.maleStatuses
      : AppConstants.femaleStatuses;

  @override
  void initState() {
    super.initState();
    if (widget.animal != null) {
      final a = widget.animal!;
      _earTagController.text = a.earTag;
      _nameController.text = a.name ?? '';
      _weightController.text = a.weight?.toString() ?? '';
      _notesController.text = a.notes ?? '';
      _breed = a.breed;
      _gender = a.gender;
      _status = a.status;
      _entryType = _entryTypes.contains(a.entryType) ? a.entryType : 'Satın Alma';
      _birthDate = DateTime.parse(a.birthDate);
      _entryDate = DateTime.parse(a.entryDate);
      _photoPath = a.photoPath;
      if (a.purchasePrice != null) _priceController.text = a.purchasePrice!.toStringAsFixed(2);
    }
  }

  @override
  void dispose() {
    _earTagController.dispose();
    _nameController.dispose();
    _weightController.dispose();
    _priceController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _pickDate(bool isBirth) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: isBirth ? _birthDate : _entryDate,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.light(primary: AppColors.primaryGreen),
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      setState(() {
        if (isBirth) _birthDate = picked;
        else _entryDate = picked;
      });
    }
  }

  // ─── Fotoğraf seçimi ────────────────────────────────────────────────────────

  Future<void> _showPhotoOptions() async {
    await showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(width: 40, height: 4,
              decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 16),
            const Text('Fotoğraf Ekle', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
            const SizedBox(height: 12),
            ListTile(
              leading: const CircleAvatar(backgroundColor: AppColors.primaryGreen, child: Icon(Icons.camera_alt, color: Colors.white)),
              title: const Text('Kamera ile Çek'),
              onTap: () { Navigator.pop(context); _pickImage(ImageSource.camera); },
            ),
            ListTile(
              leading: const CircleAvatar(backgroundColor: AppColors.infoBlue, child: Icon(Icons.photo_library, color: Colors.white)),
              title: const Text('Galeriden Seç'),
              onTap: () { Navigator.pop(context); _pickImage(ImageSource.gallery); },
            ),
            if (_photoPath != null)
              ListTile(
                leading: const CircleAvatar(backgroundColor: AppColors.errorRed, child: Icon(Icons.delete, color: Colors.white)),
                title: const Text('Fotoğrafı Kaldır', style: TextStyle(color: AppColors.errorRed)),
                onTap: () { Navigator.pop(context); setState(() => _photoPath = null); },
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Future<void> _pickImage(ImageSource source) async {
    final picker = ImagePicker();
    final file = await picker.pickImage(source: source, imageQuality: 85, maxWidth: 600, maxHeight: 600);
    if (file != null) setState(() => _photoPath = file.path);
  }

  // ─── QR Kod okuma ───────────────────────────────────────────────────────────

  Future<void> _openQrScanner() async {
    final result = await Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (_) => const _QrScannerPage()),
    );
    if (result != null && result.isNotEmpty) {
      _parseQrData(result);
    }
  }

  void _parseQrData(String raw) {
    // Tarım Bakanlığı resmi küpe QR formatları:
    // Format 1: "TR792XXXXXXXXXXXX" veya "TRXXXXXXXXXX" → sadece küpe no
    // Format 2: "KÜPENO;DDMMYYYY;E/D;IRK" → noktalı virgülle ayrılmış
    // Format 3: Sadece sayısal ID
    final cleaned = raw.trim();

    if (cleaned.contains(';')) {
      // Yapılandırılmış format: küpeno;tarih;cinsiyet;irk
      final parts = cleaned.split(';');
      if (parts.isNotEmpty) _earTagController.text = _formatEarTag(parts[0]);
      if (parts.length > 1) {
        final d = _parseDateString(parts[1]);
        if (d != null) setState(() => _birthDate = d);
      }
      if (parts.length > 2) {
        final g = parts[2].toUpperCase();
        if (g == 'E' || g == 'ERKEK' || g == 'M') {
          setState(() {
            _gender = AppConstants.male;
            if (!_statuses.contains(_status)) _status = _statuses.first;
          });
        } else if (g == 'D' || g == 'DİŞİ' || g == 'F') {
          setState(() => _gender = AppConstants.female);
        }
      }
      if (parts.length > 3) {
        final irkRaw = parts[3].trim();
        final matched = _matchBreed(irkRaw);
        if (matched != null) setState(() => _breed = matched);
      }
    } else {
      // Sade format: sadece küpe no
      _earTagController.text = _formatEarTag(cleaned);
    }

    setState(() {});
    _showQrSuccess(cleaned);
  }

  String _formatEarTag(String raw) {
    // TR792XXXX → TRXXXX, salt rakamlar olduğu gibi
    var tag = raw.trim().toUpperCase();
    if (tag.startsWith('TR792')) tag = 'TR${tag.substring(5)}';
    return tag;
  }

  DateTime? _parseDateString(String s) {
    final clean = s.replaceAll(RegExp(r'[^0-9]'), '');
    if (clean.length == 8) {
      try {
        // DDMMYYYY veya YYYYMMDD
        if (int.parse(clean.substring(0, 4)) > 1900) {
          // YYYYMMDD
          return DateTime(int.parse(clean.substring(0, 4)),
              int.parse(clean.substring(4, 6)), int.parse(clean.substring(6, 8)));
        } else {
          // DDMMYYYY
          return DateTime(int.parse(clean.substring(4, 8)),
              int.parse(clean.substring(2, 4)), int.parse(clean.substring(0, 2)));
        }
      } catch (_) {}
    }
    return null;
  }

  String? _matchBreed(String raw) {
    final lower = raw.toLowerCase();
    for (final b in _breeds) {
      if (lower.contains(b.toLowerCase()) || b.toLowerCase().contains(lower)) return b;
    }
    return null;
  }

  void _showQrSuccess(String raw) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(children: [
          const Icon(Icons.qr_code_scanner, color: Colors.white, size: 18),
          const SizedBox(width: 8),
          Expanded(child: Text('QR okundu: ${raw.length > 40 ? '${raw.substring(0, 40)}…' : raw}')),
        ]),
        backgroundColor: AppColors.primaryGreen,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  // ─── Kaydet ─────────────────────────────────────────────────────────────────

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    final now = DateTime.now().toIso8601String();
    final animal = AnimalModel(
      id: widget.animal?.id,
      earTag: _earTagController.text.trim(),
      name: _nameController.text.trim().isEmpty ? null : _nameController.text.trim(),
      breed: _breed,
      gender: _gender,
      birthDate: _birthDate.toIso8601String().split('T').first,
      status: _status,
      weight: double.tryParse(_weightController.text.replaceAll(',', '.')),
      photoPath: _photoPath,
      entryDate: _entryDate.toIso8601String().split('T').first,
      entryType: _entryType,
      purchasePrice: _entryType == 'Satın Alma'
          ? double.tryParse(_priceController.text.replaceAll(',', '.'))
          : null,
      notes: _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
      createdAt: widget.animal?.createdAt ?? now,
      updatedAt: now,
    );

    try {
      if (widget.animal == null) {
        await _repo.insert(animal);
      } else {
        await _repo.update(animal);
      }
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Hata: $e'), backgroundColor: AppColors.errorRed),
      );
    }
  }

  // ─── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.animal != null;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(isEdit ? 'Hayvanı Düzenle' : 'Yeni Hayvan Ekle'),
        actions: [
          if (_isLoading)
            const Padding(padding: EdgeInsets.all(16), child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)))
          else
            TextButton(
              onPressed: _save,
              child: const Text('Kaydet', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 16)),
            ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // ── Fotoğraf bölümü ──────────────────────────────────────────────
            _PhotoSection(photoPath: _photoPath, onTap: _showPhotoOptions),
            const SizedBox(height: 16),

            // ── Temel bilgiler ───────────────────────────────────────────────
            _SectionCard(
              title: 'Temel Bilgiler',
              children: [
                // Küpe No + QR butonu
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _earTagController,
                        decoration: const InputDecoration(
                          labelText: 'Küpe No *',
                          prefixIcon: Icon(Icons.tag, color: AppColors.primaryGreen, size: 20),
                        ),
                        validator: (v) => v == null || v.isEmpty ? 'Küpe no zorunludur' : null,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Tooltip(
                      message: 'QR/Barkod Okut',
                      child: InkWell(
                        onTap: _openQrScanner,
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          height: 56,
                          width: 52,
                          decoration: BoxDecoration(
                            color: AppColors.primaryGreen.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppColors.primaryGreen.withOpacity(0.4)),
                          ),
                          child: const Icon(Icons.qr_code_scanner, color: AppColors.primaryGreen, size: 26),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                _buildField(
                  controller: _nameController,
                  label: 'İsim (isteğe bağlı)',
                  icon: Icons.label_outline,
                ),
                const SizedBox(height: 14),
                _buildDropdown(
                  label: 'Irk',
                  icon: Icons.pets,
                  value: _breed,
                  items: _breeds,
                  onChanged: (v) => setState(() => _breed = v!),
                ),
                const SizedBox(height: 14),
                _buildDropdown(
                  label: 'Cinsiyet',
                  icon: Icons.transgender,
                  value: _gender,
                  items: [AppConstants.female, AppConstants.male],
                  onChanged: (v) {
                    setState(() {
                      _gender = v!;
                      final statuses = _gender == AppConstants.male
                          ? AppConstants.maleStatuses
                          : AppConstants.femaleStatuses;
                      if (!statuses.contains(_status)) _status = statuses.first;
                    });
                  },
                ),
                const SizedBox(height: 14),
                _buildDropdown(
                  label: 'Durum',
                  icon: Icons.info_outline,
                  value: _status,
                  items: _statuses,
                  onChanged: (v) => setState(() => _status = v!),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // ── Tarih & Kayıt ─────────────────────────────────────────────────
            _SectionCard(
              title: 'Tarih & Kayıt',
              children: [
                _DatePickerTile(label: 'Doğum Tarihi', date: _birthDate, onTap: () => _pickDate(true)),
                const SizedBox(height: 12),
                _buildDropdown(
                  label: 'Giriş Türü',
                  icon: Icons.login,
                  value: _entryType,
                  items: _entryTypes,
                  onChanged: (v) => setState(() => _entryType = v!),
                ),
                if (_entryType == 'Satın Alma') ...[
                  const SizedBox(height: 12),
                  _buildField(
                    controller: _priceController,
                    label: 'Alış Fiyatı (₺)',
                    icon: Icons.attach_money,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  ),
                ],
                const SizedBox(height: 12),
                _DatePickerTile(label: 'Sürüye Giriş Tarihi', date: _entryDate, onTap: () => _pickDate(false)),
              ],
            ),
            const SizedBox(height: 16),

            // ── Ek Bilgiler ──────────────────────────────────────────────────
            _SectionCard(
              title: 'Ek Bilgiler',
              children: [
                _buildField(
                  controller: _weightController,
                  label: 'Ağırlık (kg)',
                  icon: Icons.monitor_weight_outlined,
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 14),
                _buildField(
                  controller: _notesController,
                  label: 'Notlar',
                  icon: Icons.notes,
                  maxLines: 3,
                ),
              ],
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType? keyboardType,
    int maxLines = 1,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      maxLines: maxLines,
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: AppColors.primaryGreen, size: 20),
      ),
    );
  }

  Widget _buildDropdown({
    required String label,
    required IconData icon,
    required String value,
    required List<String> items,
    required void Function(String?) onChanged,
  }) {
    return DropdownButtonFormField<String>(
      value: value,
      onChanged: onChanged,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: AppColors.primaryGreen, size: 20),
      ),
      items: items.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
    );
  }
}

// ─── Fotoğraf bölümü widget ─────────────────────────────────────────────────

class _PhotoSection extends StatelessWidget {
  final String? photoPath;
  final VoidCallback onTap;
  const _PhotoSection({required this.photoPath, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: GestureDetector(
        onTap: onTap,
        child: Stack(
          children: [
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white,
                border: Border.all(
                  color: photoPath != null ? AppColors.primaryGreen : AppColors.divider,
                  width: photoPath != null ? 2.5 : 1.5,
                ),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 10, offset: const Offset(0, 3))],
              ),
              clipBehavior: Clip.antiAlias,
              child: photoPath != null
                  ? Image.file(File(photoPath!), fit: BoxFit.cover)
                  : Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.add_a_photo_outlined, color: AppColors.primaryGreen.withOpacity(0.7), size: 28),
                        const SizedBox(height: 5),
                        const Text('Fotoğraf\nEkle', textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 10, color: AppColors.textGrey, height: 1.3)),
                      ],
                    ),
            ),
            Positioned(
              right: 0, bottom: 0,
              child: Container(
                width: 32, height: 32,
                decoration: BoxDecoration(
                  color: AppColors.primaryGreen,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                ),
                child: const Icon(Icons.camera_alt, color: Colors.white, size: 16),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── QR Tarayıcı sayfası ─────────────────────────────────────────────────────

class _QrScannerPage extends StatefulWidget {
  const _QrScannerPage();

  @override
  State<_QrScannerPage> createState() => _QrScannerPageState();
}

class _QrScannerPageState extends State<_QrScannerPage> {
  final MobileScannerController _ctrl = MobileScannerController();
  bool _scanned = false;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: const Text('Küpe QR Okut', style: TextStyle(color: Colors.white)),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.flash_on, color: Colors.white),
            onPressed: () => _ctrl.toggleTorch(),
          ),
        ],
      ),
      body: Stack(
        children: [
          MobileScanner(
            controller: _ctrl,
            onDetect: (capture) {
              if (_scanned) return;
              final barcode = capture.barcodes.firstOrNull;
              if (barcode?.rawValue != null) {
                _scanned = true;
                Navigator.pop(context, barcode!.rawValue);
              }
            },
          ),
          // Kılavuz çerçevesi
          Center(
            child: Container(
              width: 250,
              height: 250,
              decoration: BoxDecoration(
                border: Border.all(color: AppColors.primaryGreen, width: 3),
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
          // Alt bilgi
          Positioned(
            bottom: 40,
            left: 0, right: 0,
            child: Column(children: [
              const Icon(Icons.qr_code, color: Colors.white54, size: 32),
              const SizedBox(height: 8),
              const Text(
                'Resmi Tarım Bakanlığı küpesini\nkameraya gösterin',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white70, fontSize: 14, height: 1.5),
              ),
            ]),
          ),
        ],
      ),
    );
  }
}

// ─── Ortak widget'lar ────────────────────────────────────────────────────────

class _SectionCard extends StatelessWidget {
  final String title;
  final List<Widget> children;
  const _SectionCard({required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
            child: Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.primaryGreen)),
          ),
          const Divider(height: 1, color: AppColors.divider),
          Padding(padding: const EdgeInsets.all(16), child: Column(children: children)),
        ],
      ),
    );
  }
}

class _DatePickerTile extends StatelessWidget {
  final String label;
  final DateTime date;
  final VoidCallback onTap;
  const _DatePickerTile({required this.label, required this.date, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: AppColors.divider),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            const Icon(Icons.calendar_today, color: AppColors.primaryGreen, size: 20),
            const SizedBox(width: 12),
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(label, style: const TextStyle(fontSize: 12, color: AppColors.textGrey)),
              const SizedBox(height: 2),
              Text(
                '${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}.${date.year}',
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.textDark),
              ),
            ]),
            const Spacer(),
            const Icon(Icons.chevron_right, color: AppColors.textGrey),
          ],
        ),
      ),
    );
  }
}
