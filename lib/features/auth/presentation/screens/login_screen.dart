import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_assets.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_spacing.dart';
import '../../../../core/errors/failures.dart';
import '../../../../providers/app_providers.dart';
import '../../../../providers/otp_flow_provider.dart';
import '../../../../services/session_controller.dart';
import '../../../../widgets/buttons/primary_button.dart';
import '../../../../widgets/feedback/app_toast.dart';
import '../../../../widgets/inputs/app_text_field.dart';
import '../../data/models/auth_api_models.dart';
import '../../data/models/user_model.dart';
import '../../../dashboard/presentation/screens/dashboard_screen.dart';
import 'otp_screen.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  static const routePath = '/login';

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _idCtrl = TextEditingController();
  final _pwdCtrl = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _obscure = true;
  bool _loading = false;

  @override
  void dispose() {
    _idCtrl.dispose();
    _pwdCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      final repo = ref.read(authRepositoryProvider);
      final res = await repo.login(
        LoginRequest(
          identifier: _idCtrl.text.trim(),
          password: _pwdCtrl.text,
        ),
      );

      if (res.requiresOtp) {
        ref.read(otpIdentifierProvider.notifier).state = _idCtrl.text.trim();
        if (mounted) context.push(OtpScreen.routePath);
      } else if (res.accessToken != null) {
        await ref.read(sessionControllerProvider.notifier).setAuthenticated(
              user: res.user ??
                  UserModel(
                    id: 'temp',
                    fullName: 'Collaborateur',
                    email: _idCtrl.text.trim(),
                  ),
              accessToken: res.accessToken!,
              refreshToken: res.refreshToken,
              deviceRegistered: false,
              biometricOnboardingDone: false,
            );
        if (mounted) context.go(DashboardScreen.routePath);
      }
    } on Failure catch (e) {
      if (mounted) showAppToast(context, e.message, type: ToastType.error);
    } catch (e) {
      if (mounted) {
        showAppToast(context, e.toString(), type: ToastType.error);
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _biometricLogin() async {
    final bio = ref.read(biometricServiceProvider);
    try {
      final ok = await bio.authenticate(
        localizedReason: 'Connexion COFINA — Pointage sécurisé',
      );
      if (!ok || !mounted) return;
      await ref.read(sessionControllerProvider.notifier).hydrate();
      final s = ref.read(sessionControllerProvider);
      if (s.isAuthenticated) {
        context.go(DashboardScreen.routePath);
      } else {
        showAppToast(
          context,
          'Aucune session sécurisée. Connectez-vous une première fois.',
          type: ToastType.info,
        );
      }
    } on Failure catch (e) {
      showAppToast(context, e.message, type: ToastType.error);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: AppSpacing.md),
                Center(
                  child: Column(
                    children: [
                      Image.asset(
                        AppAssets.cofinaLogo,
                        height: 56,
                        fit: BoxFit.contain,
                        errorBuilder: (_, __, ___) => Text(
                          'COFINA',
                          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                fontWeight: FontWeight.w900,
                                color: AppColors.primary,
                                letterSpacing: 1.2,
                              ),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        'Pointage sécurisé',
                        style: Theme.of(context).textTheme.labelLarge?.copyWith(
                              color: scheme.onSurfaceVariant,
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                Text(
                  'Bonjour !',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  'Connectez-vous à votre compte',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                ),
                const SizedBox(height: AppSpacing.xl),
                AppTextField(
                  controller: _idCtrl,
                  label: ref.watch(envProvider).useTestData
                      ? 'E-mail ou matricule (test)'
                      : 'E-mail professionnel',
                  keyboardType: TextInputType.emailAddress,
                  autofillHints: const [AutofillHints.username],
                  prefixIcon: Icons.person_outline,
                  validator: (v) {
                    final t = v?.trim() ?? '';
                    if (t.isEmpty) return 'Champ requis';
                    if (!ref.read(envProvider).useTestData && !t.contains('@')) {
                      return 'L’API attend une adresse e-mail (comme sur le web).';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: AppSpacing.md),
                AppTextField(
                  controller: _pwdCtrl,
                  label: 'Mot de passe',
                  obscure: _obscure,
                  autofillHints: const [AutofillHints.password],
                  prefixIcon: Icons.lock_outline,
                  validator: (v) =>
                      v == null || v.isEmpty ? 'Champ requis' : null,
                  suffix: IconButton(
                    onPressed: () => setState(() => _obscure = !_obscure),
                    icon: Icon(
                      _obscure ? Icons.visibility_off : Icons.visibility,
                    ),
                  ),
                ),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () => showAppToast(
                      context,
                      'Contactez l’administrateur pour réinitialiser votre accès.',
                    ),
                    child: const Text('Mot de passe oublié ?'),
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                PrimaryButton(
                  label: 'Se connecter',
                  loading: _loading,
                  onPressed: _submit,
                ),
                const SizedBox(height: AppSpacing.md),
                SecondaryOutlinedButton(
                  label: 'Connexion par biométrie',
                  icon: Icons.fingerprint,
                  onPressed: _biometricLogin,
                ),
                const SizedBox(height: AppSpacing.xl),
                Text(
                  'Pas encore de compte ? Contactez l’administrateur',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
