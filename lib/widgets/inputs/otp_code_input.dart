import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_spacing.dart';

/// Saisie OTP 6 chiffres :
/// - chiffres toujours visibles (contraste fort, cases assez hautes)
/// - collage multi-chiffres
/// - autofill clavier (SMS / e-mail Android)
/// - bandeau si un code 6 chiffres est dans le presse-papiers
class OtpCodeInput extends StatefulWidget {
  const OtpCodeInput({
    super.key,
    required this.onChanged,
    this.onCompleted,
    this.length = 6,
    this.enabled = true,
  });

  final ValueChanged<String> onChanged;
  final ValueChanged<String>? onCompleted;
  final int length;
  final bool enabled;

  @override
  State<OtpCodeInput> createState() => OtpCodeInputState();
}

class OtpCodeInputState extends State<OtpCodeInput>
    with WidgetsBindingObserver {
  late final TextEditingController _controller;
  late final FocusNode _focus;
  String? _clipboardHint;
  Timer? _clipTimer;

  String get code {
    final digits = _controller.text.replaceAll(RegExp(r'\D'), '');
    return digits.length > widget.length
        ? digits.substring(0, widget.length)
        : digits;
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _controller = TextEditingController();
    _focus = FocusNode();
    _controller.addListener(_onText);
    _refreshClipboardHint();
    _clipTimer = Timer.periodic(
      const Duration(seconds: 2),
      (_) => _refreshClipboardHint(),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && widget.enabled) _focus.requestFocus();
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _refreshClipboardHint();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _clipTimer?.cancel();
    _controller.removeListener(_onText);
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _onText() {
    final c = code;
    if (_controller.text != c) {
      final sel = c.length;
      _controller.value = TextEditingValue(
        text: c,
        selection: TextSelection.collapsed(offset: sel),
      );
      return;
    }
    widget.onChanged(c);
    if (c.length == widget.length) {
      widget.onCompleted?.call(c);
      TextInput.finishAutofillContext(shouldSave: false);
    }
    setState(() {});
    _refreshClipboardHint();
  }

  Future<void> _refreshClipboardHint() async {
    try {
      final data = await Clipboard.getData(Clipboard.kTextPlain);
      final raw = data?.text?.trim() ?? '';
      final digits = raw.replaceAll(RegExp(r'\D'), '');
      String? hint;
      if (digits.length >= widget.length) {
        hint = RegExp('\\d{${widget.length}}').firstMatch(digits)?.group(0);
      }
      if (!mounted) return;
      if (hint != null && hint == code) hint = null;
      if (hint != _clipboardHint) {
        setState(() => _clipboardHint = hint);
      }
    } catch (_) {}
  }

  void clear() {
    _controller.clear();
    widget.onChanged('');
    _focus.requestFocus();
  }

  void applyDigits(String raw) {
    final digits = raw.replaceAll(RegExp(r'\D'), '');
    if (digits.isEmpty) return;
    final next = digits.length > widget.length
        ? digits.substring(0, widget.length)
        : digits;
    _controller.value = TextEditingValue(
      text: next,
      selection: TextSelection.collapsed(offset: next.length),
    );
  }

  Future<void> pasteFromClipboard() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    applyDigits(data?.text ?? '');
    await _refreshClipboardHint();
  }

  void useClipboardHint() {
    final hint = _clipboardHint;
    if (hint == null) return;
    applyDigits(hint);
    setState(() => _clipboardHint = null);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final digits = code.padRight(widget.length).substring(0, widget.length);

    return AutofillGroup(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Champ réel (autofill + collage) — opaque pour rester accessible.
          TextField(
            controller: _controller,
            focusNode: _focus,
            enabled: widget.enabled,
            keyboardType: TextInputType.number,
            textInputAction: TextInputAction.done,
            obscureText: false,
            autocorrect: false,
            enableSuggestions: false,
            enableInteractiveSelection: true,
            showCursor: true,
            cursorColor: scheme.primary,
            style: const TextStyle(
              color: AppColors.charcoal,
              fontSize: 28,
              fontWeight: FontWeight.w800,
              letterSpacing: 10,
              height: 1.2,
            ),
            textAlign: TextAlign.center,
            autofillHints: const [AutofillHints.oneTimeCode],
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(widget.length),
            ],
            decoration: InputDecoration(
              hintText: '••••••',
              hintStyle: TextStyle(
                color: AppColors.textSecondaryLight.withValues(alpha: 0.45),
                fontSize: 28,
                fontWeight: FontWeight.w700,
                letterSpacing: 10,
              ),
              filled: true,
              fillColor: Colors.white,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 18,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: AppColors.outlineLight),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: scheme.primary, width: 2),
              ),
            ),
            onTap: () => _refreshClipboardHint(),
          ),
          const SizedBox(height: AppSpacing.md),
          // Cases visuelles (lecture seule) — chiffres toujours lisibles.
          LayoutBuilder(
            builder: (context, constraints) {
              const gap = 8.0;
              final cellW = ((constraints.maxWidth - gap * (widget.length - 1)) /
                      widget.length)
                  .clamp(40.0, 56.0);
              return IgnorePointer(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: List.generate(widget.length, (i) {
                    final ch = digits[i].trim();
                    final filled = ch.isNotEmpty && RegExp(r'\d').hasMatch(ch);
                    return Container(
                      width: cellW,
                      height: cellW + 12,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: filled ? scheme.primary : AppColors.outlineLight,
                          width: filled ? 2 : 1,
                        ),
                      ),
                      child: Text(
                        filled ? ch : '',
                        style: TextStyle(
                          color: AppColors.charcoal,
                          fontSize: cellW > 44 ? 26 : 22,
                          fontWeight: FontWeight.w900,
                          height: 1,
                        ),
                      ),
                    );
                  }),
                ),
              );
            },
          ),
          const SizedBox(height: AppSpacing.sm),
          if (_clipboardHint != null)
            Material(
              color: scheme.primaryContainer.withValues(alpha: 0.65),
              borderRadius: BorderRadius.circular(12),
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: useClipboardHint,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 12,
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.mark_email_unread_outlined,
                          color: scheme.primary, size: 22),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Code trouvé : $_clipboardHint\nTouchez pour l’utiliser',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: scheme.onPrimaryContainer,
                            height: 1.25,
                          ),
                        ),
                      ),
                      Icon(Icons.chevron_right, color: scheme.primary),
                    ],
                  ),
                ),
              ),
            ),
          if (_clipboardHint != null) const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              TextButton.icon(
                onPressed: widget.enabled ? pasteFromClipboard : null,
                icon: const Icon(Icons.content_paste_rounded, size: 18),
                label: const Text('Coller'),
              ),
              TextButton.icon(
                onPressed: widget.enabled
                    ? () {
                        _focus.requestFocus();
                        _refreshClipboardHint();
                      }
                    : null,
                icon: const Icon(Icons.keyboard_rounded, size: 18),
                label: const Text('Clavier / autofill'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
