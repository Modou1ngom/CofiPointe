import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_spacing.dart';
import '../../../../core/errors/failures.dart';
import '../../../../providers/app_providers.dart';
import '../../../../providers/otp_flow_provider.dart';
import '../../../../services/session_controller.dart';
import '../../../../widgets/buttons/primary_button.dart';
import '../../../../widgets/feedback/app_toast.dart';
import '../../data/models/auth_api_models.dart';
import '../../../dashboard/presentation/screens/dashboard_screen.dart';

class OtpScreen extends ConsumerStatefulWidget {
  const OtpScreen({super.key});

  static const routePath = '/otp';

  @override
  ConsumerState<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends ConsumerState<OtpScreen> {
  final _nodes = List.generate(6, (_) => FocusNode());
  final _controllers = List.generate(6, (_) => TextEditingController());
  Timer? _cooldown;
  int _seconds = 30;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _startCooldown();
  }

  void _startCooldown() {
    _seconds = 30;
    _cooldown?.cancel();
    _cooldown = Timer.periodic(const Duration(seconds: 1), (t) {
      if (_seconds <= 0) {
        t.cancel();
      } else {
        setState(() => _seconds--);
      }
    });
  }

  @override
  void dispose() {
    _cooldown?.cancel();
    for (final n in _nodes) {
      n.dispose();
    }
    for (final c in _controllers) {
      c.dispose();
    }
    super.dispose();
  }

  String get _code => _controllers.map((c) => c.text).join();

  void _applyOtpDigits(String raw, {int startIndex = 0}) {
    final digits = raw.replaceAll(RegExp(r'\D'), '');
    if (digits.isEmpty) return;

    for (var j = 0; j < 6; j++) {
      final idx = startIndex + j;
      if (idx >= 6) break;
      _controllers[idx].text = j < digits.length ? digits[j] : '';
    }

    final filled = _code.length.clamp(0, 6);
    final focusIndex = filled >= 6 ? 5 : filled;
    _nodes[focusIndex].requestFocus();
    setState(() {});
  }

  Future<void> _verify() async {
    final id = ref.read(otpIdentifierProvider);
    if (id == null || id.isEmpty) {
      showAppToast(context, 'Session OTP invalide.', type: ToastType.error);
      return;
    }
    if (_code.length != 6) {
      showAppToast(context, 'Code incomplet.', type: ToastType.error);
      return;
    }
    setState(() => _loading = true);
    try {
      final repo = ref.read(authRepositoryProvider);
      final res = await repo.verifyOtp(
        VerifyOtpRequest(identifier: id, code: _code),
      );
      await ref.read(sessionControllerProvider.notifier).setAuthenticated(
            user: res.user,
            accessToken: res.accessToken,
            refreshToken: res.refreshToken,
            deviceRegistered: !res.requiresDeviceRegistration,
            biometricOnboardingDone: false,
          );
      if (!mounted) return;
      context.go(DashboardScreen.routePath);
    } on Failure catch (e) {
      showAppToast(context, e.message, type: ToastType.error);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Widget _otpCell(int i, ColorScheme scheme, bool isDark) {
    final digit = _controllers[i].text;
    final visibleDigit = digit.isEmpty ? '' : digit.substring(0, 1);
    final textColor =
        isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight;
    final fill =
        isDark ? AppColors.surfaceDark : Colors.white;

    return SizedBox(
      width: 48,
      height: 56,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Chiffre toujours visible (Android masque souvent le TextField).
          IgnorePointer(
            child: Text(
              visibleDigit,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w800,
                color: textColor,
                height: 1,
              ),
            ),
          ),
          TextField(
            controller: _controllers[i],
            focusNode: _nodes[i],
            textAlign: TextAlign.center,
            textAlignVertical: TextAlignVertical.center,
            // visiblePassword = caractères non masqués sur Android OEM.
            keyboardType: TextInputType.visiblePassword,
            textInputAction:
                i == 5 ? TextInputAction.done : TextInputAction.next,
            obscureText: false,
            enableSuggestions: false,
            autocorrect: false,
            enableInteractiveSelection: true,
            autofillHints: const <String>[],
            showCursor: true,
            cursorColor: scheme.primary,
            style: const TextStyle(
              color: Colors.transparent,
              fontSize: 24,
              fontWeight: FontWeight.w800,
              height: 1,
            ),
            decoration: InputDecoration(
              counterText: '',
              isDense: true,
              filled: true,
              fillColor: fill,
              contentPadding: EdgeInsets.zero,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: isDark ? AppColors.outlineDark : AppColors.outlineLight,
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: scheme.primary, width: 2),
              ),
            ),
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(6),
            ],
            onChanged: (v) {
              if (v.length > 1) {
                _applyOtpDigits(v, startIndex: i);
                if (_code.length == 6) {
                  FocusScope.of(context).unfocus();
                }
                return;
              }
              if (v.length == 1 && i < 5) {
                _nodes[i + 1].requestFocus();
              }
              if (v.isEmpty && i > 0) {
                _nodes[i - 1].requestFocus();
              }
              setState(() {});
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final id = ref.watch(otpIdentifierProvider) ?? '';
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        title: const Text('Vérification OTP'),
        actions: [
          IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => context.go('/login'),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Un code a été envoyé à votre adresse liée à :',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              id,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: AppSpacing.xl),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: List.generate(6, (i) => _otpCell(i, scheme, isDark)),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Astuce : vous pouvez coller le code à 6 chiffres d’un coup.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
            ),
            const SizedBox(height: AppSpacing.lg),
            Row(
              children: [
                Icon(Icons.mark_email_read_outlined, color: scheme.primary),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    _seconds > 0
                        ? 'Renvoyer le code dans ${_seconds.toString().padLeft(2, '0')}s'
                        : 'Vous pouvez renvoyer le code.',
                    style: TextStyle(color: scheme.onSurfaceVariant),
                  ),
                ),
              ],
            ),
            const Spacer(),
            PrimaryButton(
              label: 'Vérifier',
              loading: _loading,
              onPressed: _verify,
            ),
            const SizedBox(height: AppSpacing.md),
          ],
        ),
      ),
    );
  }
}
