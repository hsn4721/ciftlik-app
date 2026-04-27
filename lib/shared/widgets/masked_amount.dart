import 'package:flutter/material.dart';
import '../../core/services/security_service.dart';

/// Hassas tutarı SecurityService.isMaskFinanceEnabled() değerine göre
/// maskeleyip gösteren text widget. Tap ile geçici olarak açılabilir.
///
/// Kullanım:
/// ```dart
/// MaskedAmount(text: '₺1.234,00', style: TextStyle(...))
/// ```
class MaskedAmount extends StatefulWidget {
  final String text;
  final TextStyle? style;
  final String placeholder;
  final TextAlign? textAlign;
  final int? maxLines;
  final TextOverflow? overflow;

  const MaskedAmount({
    super.key,
    required this.text,
    this.style,
    this.placeholder = '••••••',
    this.textAlign,
    this.maxLines,
    this.overflow,
  });

  @override
  State<MaskedAmount> createState() => _MaskedAmountState();
}

class _MaskedAmountState extends State<MaskedAmount> {
  bool _masked = false;
  bool _revealed = false;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final m = await SecurityService.instance.isMaskFinanceEnabled();
    if (!mounted) return;
    setState(() {
      _masked = m;
      _loaded = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!_loaded) {
      // İlk frame'de orijinal gösterildiği hissini vermemek için placeholder
      return Text(widget.placeholder,
          style: widget.style, textAlign: widget.textAlign,
          maxLines: widget.maxLines, overflow: widget.overflow);
    }
    final showOriginal = !_masked || _revealed;
    final display = showOriginal ? widget.text : widget.placeholder;

    if (!_masked) {
      return Text(display,
          style: widget.style, textAlign: widget.textAlign,
          maxLines: widget.maxLines, overflow: widget.overflow);
    }

    return GestureDetector(
      onTap: () {
        setState(() => _revealed = !_revealed);
        // 4 saniye sonra otomatik kapat
        if (_revealed) {
          Future.delayed(const Duration(seconds: 4), () {
            if (mounted) setState(() => _revealed = false);
          });
        }
      },
      child: Text(display,
          style: widget.style, textAlign: widget.textAlign,
          maxLines: widget.maxLines, overflow: widget.overflow),
    );
  }
}
