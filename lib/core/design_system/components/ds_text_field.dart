import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../tokens/ds_colors.dart';
import '../tokens/ds_typography.dart';
import '../tokens/ds_radius.dart';

/// Premium text input — floating label, filled bg, focus ring.
class DsTextField extends StatefulWidget {
  final TextEditingController? controller;
  final String label;
  final String? hint;
  final String? helperText;
  final String? errorText;
  final IconData? prefixIcon;
  final Widget? suffix;
  final bool obscureText;
  final TextInputType? keyboardType;
  final List<TextInputFormatter>? inputFormatters;
  final int? maxLines;
  final int? maxLength;
  final bool autofocus;
  final bool enabled;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final VoidCallback? onTap;
  final bool readOnly;
  final FocusNode? focusNode;
  final TextInputAction? textInputAction;

  const DsTextField({
    super.key,
    this.controller,
    required this.label,
    this.hint,
    this.helperText,
    this.errorText,
    this.prefixIcon,
    this.suffix,
    this.obscureText = false,
    this.keyboardType,
    this.inputFormatters,
    this.maxLines = 1,
    this.maxLength,
    this.autofocus = false,
    this.enabled = true,
    this.onChanged,
    this.onSubmitted,
    this.onTap,
    this.readOnly = false,
    this.focusNode,
    this.textInputAction,
  });

  @override
  State<DsTextField> createState() => _DsTextFieldState();
}

class _DsTextFieldState extends State<DsTextField> {
  late FocusNode _focusNode;
  bool _focused = false;

  @override
  void initState() {
    super.initState();
    _focusNode = widget.focusNode ?? FocusNode();
    _focusNode.addListener(_onFocusChange);
  }

  @override
  void dispose() {
    _focusNode.removeListener(_onFocusChange);
    if (widget.focusNode == null) _focusNode.dispose();
    super.dispose();
  }

  void _onFocusChange() {
    if (mounted) setState(() => _focused = _focusNode.hasFocus);
  }

  @override
  Widget build(BuildContext context) {
    final tokens = DsTokens.of(context);
    final hasError = widget.errorText != null;

    final borderColor = hasError
        ? tokens.error
        : _focused
            ? tokens.primary
            : tokens.border;
    final borderWidth = _focused || hasError ? 1.8 : 1.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          decoration: BoxDecoration(
            color: widget.enabled ? tokens.surfaceElevated : tokens.surfaceHighest,
            borderRadius: DsRadius.brMd,
            border: Border.all(color: borderColor, width: borderWidth),
          ),
          child: TextField(
            controller: widget.controller,
            focusNode: _focusNode,
            obscureText: widget.obscureText,
            keyboardType: widget.keyboardType,
            inputFormatters: widget.inputFormatters,
            maxLines: widget.maxLines,
            maxLength: widget.maxLength,
            autofocus: widget.autofocus,
            enabled: widget.enabled,
            onChanged: widget.onChanged,
            onSubmitted: widget.onSubmitted,
            onTap: widget.onTap,
            readOnly: widget.readOnly,
            textInputAction: widget.textInputAction,
            cursorColor: tokens.primary,
            cursorWidth: 1.6,
            style: DsTypography.body(color: tokens.textPrimary),
            decoration: InputDecoration(
              labelText: widget.label,
              labelStyle: DsTypography.body(
                color: _focused ? tokens.primary : tokens.textSecondary,
              ),
              floatingLabelStyle: DsTypography.label(
                color: _focused ? tokens.primary : tokens.textSecondary,
              ),
              hintText: widget.hint,
              hintStyle: DsTypography.body(color: tokens.textTertiary),
              prefixIcon: widget.prefixIcon == null
                  ? null
                  : Icon(
                      widget.prefixIcon,
                      color: _focused ? tokens.primary : tokens.textSecondary,
                      size: 20,
                    ),
              suffixIcon: widget.suffix,
              filled: false,
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              errorBorder: InputBorder.none,
              focusedErrorBorder: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              counterText: '',
            ),
          ),
        ),
        if (widget.helperText != null || hasError) ...[
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Text(
              hasError ? widget.errorText! : widget.helperText!,
              style: DsTypography.caption(
                color: hasError ? tokens.error : tokens.textSecondary,
              ),
            ),
          ),
        ],
      ],
    );
  }
}

/// Search field — arama çubuğu için özelleştirilmiş.
class DsSearchField extends StatelessWidget {
  final TextEditingController? controller;
  final String hint;
  final ValueChanged<String>? onChanged;
  final VoidCallback? onClear;
  final bool autofocus;

  const DsSearchField({
    super.key,
    this.controller,
    this.hint = 'Ara...',
    this.onChanged,
    this.onClear,
    this.autofocus = false,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = DsTokens.of(context);
    return Container(
      decoration: BoxDecoration(
        color: tokens.surfaceHighest,
        borderRadius: DsRadius.brMd,
      ),
      child: TextField(
        controller: controller,
        autofocus: autofocus,
        onChanged: onChanged,
        cursorColor: tokens.primary,
        style: DsTypography.body(color: tokens.textPrimary),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: DsTypography.body(color: tokens.textTertiary),
          prefixIcon: Icon(Icons.search, color: tokens.textSecondary, size: 20),
          suffixIcon: (controller?.text.isNotEmpty ?? false)
              ? IconButton(
                  icon: Icon(Icons.close, color: tokens.textSecondary, size: 18),
                  onPressed: onClear,
                )
              : null,
          filled: false,
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        ),
      ),
    );
  }
}
