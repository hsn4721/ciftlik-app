import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../../core/theme/app_theme.dart';
import '../../data/repositories/animal_repository.dart';
import 'animal_detail_screen.dart';

/// Hayvan küpe QR/Barkod taramı. Eşleşen hayvan bulunursa detay ekranına git.
class ScanTagScreen extends StatefulWidget {
  const ScanTagScreen({super.key});

  @override
  State<ScanTagScreen> createState() => _ScanTagScreenState();
}

class _ScanTagScreenState extends State<ScanTagScreen> {
  final _controller = MobileScannerController(
    detectionSpeed: DetectionSpeed.normal,
    facing: CameraFacing.back,
  );
  bool _handled = false;
  String? _lastCode;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _handleCode(String rawCode) async {
    if (_handled) return;
    final code = rawCode.trim();
    if (code.isEmpty) return;
    if (code == _lastCode) return;
    _lastCode = code;
    setState(() => _handled = true);

    // Eşleşen hayvan ara
    final all = await AnimalRepository().getAll();
    final match = all.where((a) => a.earTag == code).toList();

    if (!mounted) return;
    if (match.isEmpty) {
      // Bulunamadı — kullanıcıya seçenek sun
      final choice = await showDialog<String>(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Hayvan bulunamadı'),
          content: Text(
            'Okunan küpe numarası: $code\n\n'
            'Bu numaraya sahip kayıtlı hayvan yok. Ne yapmak istersiniz?',
            style: const TextStyle(height: 1.5),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, 'retry'),
              child: const Text('Tekrar Tara'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, 'cancel'),
              child: const Text('Kapat'),
            ),
          ],
        ),
      );
      if (!mounted) return;
      if (choice == 'retry') {
        setState(() {
          _handled = false;
          _lastCode = null;
        });
      } else {
        Navigator.pop(context);
      }
      return;
    }

    // Bulundu — detay ekranına geç (scanner kapatılır)
    await Navigator.pushReplacement(context, MaterialPageRoute(
      builder: (_) => AnimalDetailScreen(animal: match.first),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('Küpe Tara'),
        backgroundColor: Colors.black,
        actions: [
          ValueListenableBuilder(
            valueListenable: _controller,
            builder: (_, state, __) {
              return IconButton(
                icon: Icon(state.torchState == TorchState.on
                    ? Icons.flash_on : Icons.flash_off),
                onPressed: () => _controller.toggleTorch(),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.cameraswitch),
            onPressed: () => _controller.switchCamera(),
          ),
        ],
      ),
      body: Stack(children: [
        MobileScanner(
          controller: _controller,
          onDetect: (capture) {
            for (final b in capture.barcodes) {
              final v = b.rawValue;
              if (v != null && v.isNotEmpty) {
                _handleCode(v);
                break;
              }
            }
          },
        ),
        // Tarama çerçevesi
        Center(
          child: Container(
            width: 260,
            height: 160,
            decoration: BoxDecoration(
              border: Border.all(color: AppColors.primaryGreen, width: 3),
              borderRadius: BorderRadius.circular(14),
            ),
          ),
        ),
        Positioned(
          left: 16, right: 16, bottom: 40,
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.7),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Row(children: [
              Icon(Icons.qr_code_scanner, color: Colors.white, size: 24),
              SizedBox(width: 10),
              Expanded(child: Text(
                'Hayvan küpesindeki QR veya barkodu çerçeveye getirin. '
                'Eşleşen hayvan bulunursa detay ekranı açılır.',
                style: TextStyle(color: Colors.white, fontSize: 12, height: 1.4),
              )),
            ]),
          ),
        ),
      ]),
    );
  }
}
