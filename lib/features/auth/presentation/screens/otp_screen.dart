import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_spacing.dart';
import '../../../../core/errors/failures.dart';
import '../../../../providers/app_providers.dart';
import '../../../../providers/otp_flow_provider.dart';
import '../../../../services/session_controller.dart';
import '../../../../widgets/buttons/primary_button.dart';
import '../../../../widgets/feedback/app_toast.dart';
import '../../../../widgets/inputs/otp_code_input.dart';
import '../../data/models/auth_api_models.dart';
import '../../../dashboard/presentation/screens/dashboard_screen.dart';

class OtpScreen extends ConsumerStatefulWidget {
  const OtpScreen({super.key});

  static const routePath = '/otp';

  @override
  ConsumerState<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends ConsumerState<OtpScreen> {
  final _otpKey = GlobalKey<OtpCodeInputState>();
  Timer? _cooldown;
  int _seconds = 30;
  bool _loading = false;
  String _code = '';

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
    super.dispose();
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

  @override
  Widget build(BuildContext context) {
    final id = ref.watch(otpIdentifierProvider) ?? '';
    final scheme = Theme.of(context).colorScheme;

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
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight - 32),
                child: IntrinsicHeight(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'Un code a été envoyé à votre adresse e-mail liée à :',
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
                      OtpCodeInput(
                        key: _otpKey,
                        enabled: !_loading,
                        onChanged: (c) => setState(() => _code = c),
                        onCompleted: (_) {
                          if (!_loading) _verify();
                        },
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        'Saisissez ou collez le code à 6 chiffres. '
                        'Si vous copiez le code depuis l’e-mail sur ce téléphone, '
                        'un bandeau « Code trouvé » apparaît en bas pour l’appliquer.',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: scheme.onSurfaceVariant,
                              height: 1.35,
                            ),
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      Row(
                        children: [
                          Icon(Icons.mark_email_read_outlined,
                              color: scheme.primary),
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
                      const SizedBox(height: AppSpacing.lg),
                      PrimaryButton(
                        label: 'Vérifier',
                        loading: _loading,
                        onPressed: _verify,
                      ),
                      const SizedBox(height: AppSpacing.md),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
