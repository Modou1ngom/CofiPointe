import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_spacing.dart';
import '../../../../core/errors/failures.dart';
import '../../../../providers/app_providers.dart';
import '../../../../services/biometric_service.dart';
import '../../../../services/face_recognition_service.dart';
import '../../../../services/session_controller.dart';
import '../../../../widgets/buttons/primary_button.dart';
import '../../../../widgets/feedback/app_toast.dart';
import '../../../dashboard/presentation/screens/dashboard_screen.dart';
import 'face_capture_screen.dart';

enum _BioChoice { fingerprint, face }

class BiometricActivationScreen extends ConsumerStatefulWidget {
  const BiometricActivationScreen({super.key});

  static const routePath = '/biometric-setup';

  @override
  ConsumerState<BiometricActivationScreen> createState() =>
      _BiometricActivationScreenState();
}

class _BiometricActivationScreenState
    extends ConsumerState<BiometricActivationScreen> {
  _BioChoice _choice = _BioChoice.fingerprint;
  bool _loading = false;

  Future<void> _activate() async {
    if (_loading) return;
    if (kIsWeb && _choice == _BioChoice.face) {
      showAppToast(
        context,
        'Sur iPhone (Safari), la reconnaissance faciale n’est pas disponible. '
        'Choisissez Empreinte, ou installez l’APK Android.',
        type: ToastType.error,
      );
      return;
    }
    setState(() => _loading = true);
    try {
      final storage = ref.read(secureStorageServiceProvider);
      final face = ref.read(faceRecognitionServiceProvider);

      if (_choice == _BioChoice.face) {
        final samples = <List<double>>[];
        for (var i = 0; i < FaceRecognitionService.enrollSampleCount; i++) {
          if (!mounted) return;
          showAppToast(
            context,
            'Capture ${i + 1}/${FaceRecognitionService.enrollSampleCount} — '
            'visage de face, bonne lumière',
            type: ToastType.info,
          );
          final path = await context.push<String>(
            FaceCaptureScreen.routePathEnroll,
          );
          if (path == null || path.isEmpty) {
            return;
          }
          samples.add(await face.extractEmbeddingFromFile(path));
        }
        await face.enrollEmbeddings(samples);
        await storage.writeBiometricMode('face_custom');
      } else {
        final bio = ref.read(biometricServiceProvider);
        await bio.authenticate(
          localizedReason: 'Activer l’empreinte digitale',
          preferred: BiometricKind.fingerprint,
        );
        await face.clearEnrollment();
        await storage.writeBiometricMode('fingerprint');
      }

      await ref
          .read(sessionControllerProvider.notifier)
          .setBiometricEnabled(true);
      await ref
          .read(sessionControllerProvider.notifier)
          .setBiometricOnboardingDone(true);
      if (!mounted) return;
      showAppToast(
        context,
        _choice == _BioChoice.fingerprint
            ? 'Empreinte activée'
            : 'Reconnaissance faciale activée',
        type: ToastType.success,
      );
      context.go(DashboardScreen.routePath);
    } on Failure catch (e) {
      if (!mounted) return;
      showAppToast(context, e.message, type: ToastType.error);
    } catch (e) {
      if (!mounted) return;
      showAppToast(
        context,
        'Impossible d’activer la biométrie. Réessayez.',
        type: ToastType.error,
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _skip() async {
    final storage = ref.read(secureStorageServiceProvider);
    await ref.read(faceRecognitionServiceProvider).clearEnrollment();
    await storage.writeBiometricMode(null);
    await ref.read(sessionControllerProvider.notifier).setBiometricEnabled(false);
    await ref.read(sessionControllerProvider.notifier).setBiometricOnboardingDone(true);
    if (!mounted) return;
    context.go(DashboardScreen.routePath);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final faceAvailable = !kIsWeb;

    Widget card({
      required _BioChoice value,
      required String title,
      required String subtitle,
      required IconData icon,
      String? badge,
      bool enabled = true,
    }) {
      final selected = enabled && _choice == value;
      return Opacity(
        opacity: enabled ? 1 : 0.55,
        child: AnimatedContainer(
          duration: 200.ms,
          curve: Curves.easeOut,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
            border: Border.all(
              color: selected ? scheme.primary : scheme.outlineVariant,
              width: selected ? 2 : 1,
            ),
            color: selected
                ? scheme.primary.withValues(alpha: 0.06)
                : scheme.surface,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.06),
                blurRadius: 16,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
            onTap: enabled ? () => setState(() => _choice = value) : null,
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Row(
                children: [
                  Icon(icon, size: 36, color: scheme.primary),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                title,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 16,
                                ),
                              ),
                            ),
                            if (badge != null)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: enabled
                                      ? AppColors.success.withValues(alpha: 0.15)
                                      : scheme.outlineVariant.withValues(
                                          alpha: 0.5,
                                        ),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  badge,
                                  style: TextStyle(
                                    color: enabled
                                        ? AppColors.success
                                        : scheme.onSurfaceVariant,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          subtitle,
                          style:
                              Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: scheme.onSurfaceVariant,
                                  ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    !enabled
                        ? Icons.block
                        : selected
                            ? Icons.radio_button_checked
                            : Icons.radio_button_off,
                    color: selected ? scheme.primary : scheme.outline,
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Activer la biométrie')),
      body: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              kIsWeb
                  ? 'Sur iPhone (web), utilisez l’empreinte. '
                      'La reconnaissance faciale photo nécessite l’APK Android.'
                  : 'Choisissez la méthode pour sécuriser vos pointages.',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
            ),
            const SizedBox(height: AppSpacing.lg),
            card(
              value: _BioChoice.fingerprint,
              title: 'Empreinte digitale',
              subtitle: 'Rapide et fiable via le capteur de l’appareil.',
              icon: Icons.fingerprint,
              badge: 'Recommandé',
            ),
            const SizedBox(height: AppSpacing.md),
            card(
              value: _BioChoice.face,
              title: 'Reconnaissance faciale',
              subtitle: faceAvailable
                  ? '3 photos (Android). Un autre visage sera refusé.'
                  : 'Indisponible sur iPhone/Safari — installez l’APK Android.',
              icon: Icons.face_retouching_natural,
              badge: faceAvailable ? null : 'APK uniquement',
              enabled: faceAvailable,
            ),
            const Spacer(),
            PrimaryButton(
              label: _choice == _BioChoice.face && faceAvailable
                  ? 'Enregistrer mon visage (3 photos)'
                  : 'Activer maintenant',
              loading: _loading,
              onPressed: _activate,
            ),
            TextButton(
              onPressed: _loading ? null : _skip,
              child: const Text('Plus tard'),
            ),
          ],
        ),
      ),
    );
  }
}
