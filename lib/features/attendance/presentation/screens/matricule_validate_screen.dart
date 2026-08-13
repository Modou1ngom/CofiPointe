import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_spacing.dart';
import '../../../../core/errors/failures.dart';
import '../../data/models/attendance_models.dart';
import 'success_screen.dart';
import '../../../../providers/app_providers.dart';
import '../../../../providers/attendance_ui_provider.dart';
import '../../../../providers/pointage_mobile_providers.dart';
import '../../../../services/device_info_service.dart';
import '../../../../services/session_controller.dart';
import '../../../../widgets/feedback/app_toast.dart';
import '../../../../widgets/buttons/primary_button.dart';
import '../../../../widgets/inputs/otp_code_input.dart';

/// Agence virtuelle : saisie e-mail → OTP reçu par e-mail → validation du pointage.
class MatriculeValidateScreen extends ConsumerStatefulWidget {
  const MatriculeValidateScreen({super.key});

  static const routePath = '/matricule-validate';

  @override
  ConsumerState<MatriculeValidateScreen> createState() =>
      _MatriculeValidateScreenState();
}

class _MatriculeValidateScreenState
    extends ConsumerState<MatriculeValidateScreen> {
  final _emailController = TextEditingController();
  final _otpKey = GlobalKey<OtpCodeInputState>();

  bool _busy = false;
  bool _otpSent = false;
  String? _confirmedEmail;
  String _otpCode = '';

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _requestOtp() async {
    final pending = ref.read(pendingAttendanceProvider);
    if (pending == null) {
      showAppToast(context, 'Aucun QR valide. Reprenez le scan.',
          type: ToastType.error);
      return;
    }

    final email = _emailController.text.trim();
    if (email.isEmpty || !email.contains('@')) {
      showAppToast(context, 'Saisissez une adresse e-mail valide.',
          type: ToastType.error);
      return;
    }

    setState(() => _busy = true);
    try {
      late final double? latitude;
      late final double? longitude;
      if (pending.scanValidated &&
          pending.scanLatitude != null &&
          pending.scanLongitude != null) {
        latitude = pending.scanLatitude;
        longitude = pending.scanLongitude;
      } else {
        latitude = null;
        longitude = null;
      }

      final device = await DeviceInfoService().resolveAndPersist(
        ref.read(secureStorageServiceProvider).writeDeviceId,
      );

      final remote = ref.read(attendanceRemoteDataSourceProvider);
      final res = await remote.requestVirtualOtp(
        VirtualOtpRequest(
          qrPayload: pending.qrPayload,
          email: email,
          latitude: latitude,
          longitude: longitude,
          deviceId: device.deviceId,
          serialNumber: device.serialNumber,
        ),
      );

      if (!mounted) return;
      setState(() {
        _otpSent = true;
        _confirmedEmail = email.trim().toLowerCase();
      });
      showAppToast(
        context,
        res.message ?? 'Code OTP envoyé sur votre e-mail.',
        type: ToastType.success,
      );
      setState(() => _otpCode = '');
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _otpKey.currentState?.clear();
      });
    } on Failure catch (e) {
      if (mounted) {
        showAppToast(context, e.message, type: ToastType.error);
      }
    } catch (_) {
      if (mounted) {
        showAppToast(
          context,
          'Impossible d’envoyer le code. Réessayez.',
          type: ToastType.error,
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _submitPunch() async {
    final pending = ref.read(pendingAttendanceProvider);
    final email = _confirmedEmail ?? _emailController.text.trim().toLowerCase();
    if (pending == null) {
      showAppToast(context, 'Aucun QR valide. Reprenez le scan.',
          type: ToastType.error);
      return;
    }
    if (_otpCode.length != 6) {
      showAppToast(context, 'Saisissez le code à 6 chiffres.',
          type: ToastType.error);
      return;
    }

    setState(() => _busy = true);
    try {
      final local = ref.read(todayAttendanceUiProvider);
      final api = ref.read(pointageTodayProvider).valueOrNull;
      final checkIn = local.checkIn ?? api?.checkIn;
      final checkOut = local.checkOut ?? api?.checkOut;
      final effectiveType =
          checkIn != null && checkOut == null ? 'checkout' : pending.type;

      final gps = ref.read(gpsVerificationServiceProvider);
      late final double latitude;
      late final double longitude;
      if (pending.scanValidated &&
          pending.scanLatitude != null &&
          pending.scanLongitude != null) {
        latitude = pending.scanLatitude!;
        longitude = pending.scanLongitude!;
      } else {
        final pos = await gps.getCurrentPosition();
        latitude = pos.latitude;
        longitude = pos.longitude;
      }

      final device = await DeviceInfoService().resolveAndPersist(
        ref.read(secureStorageServiceProvider).writeDeviceId,
      );

      final remote = ref.read(attendanceRemoteDataSourceProvider);
      final body = AttendanceSubmitRequest(
        qrPayload: pending.qrPayload,
        latitude: latitude,
        longitude: longitude,
        biometricNonce: 'email_otp:$email',
        type: effectiveType,
        deviceId: device.deviceId,
        serialNumber: device.serialNumber,
        email: email,
        otpCode: _otpCode,
      );

      final res = effectiveType == 'checkout'
          ? await remote.checkOut(body)
          : await remote.checkIn(body);

      final recordedAsCheckout = _isCheckoutType(res.type);
      final ui = ref.read(todayAttendanceUiProvider.notifier);
      final apiToday = ref.read(pointageTodayProvider).valueOrNull;
      if (recordedAsCheckout) {
        ui.syncToday(checkIn: apiToday?.checkIn, checkOut: res.recordedAt);
      } else {
        ui.syncToday(checkIn: res.recordedAt, checkOut: apiToday?.checkOut);
      }
      ref.read(pendingAttendanceProvider.notifier).state = null;
      ref.invalidate(pointageTodayProvider);

      if (!mounted) return;
      context.go(
        SuccessScreen.routePath,
        extra: AttendanceSuccessArgs(
          recordedAt: res.recordedAt,
          kind: recordedAsCheckout ? 'Sortie' : 'Entrée',
        ),
      );
    } on Failure catch (e) {
      if (mounted) {
        showAppToast(context, e.message, type: ToastType.error);
      }
    } catch (_) {
      if (mounted) {
        showAppToast(
          context,
          'Erreur lors du pointage. Réessayez.',
          type: ToastType.error,
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  bool _isCheckoutType(String type) {
    final t = type.trim().toLowerCase();
    return t == 'checkout' || t == 'depart' || t == 'sortie';
  }

  @override
  Widget build(BuildContext context) {
    final pending = ref.watch(pendingAttendanceProvider);
    final siteLabel = pending?.agenceNom ?? 'Agence virtuelle';
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final secondary = isDark
        ? AppColors.textSecondaryDark
        : AppColors.textSecondaryLight;

    return Scaffold(
      appBar: AppBar(
        title: Text(_otpSent ? 'Code OTP' : 'Validation e-mail'),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                siteLabel,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w700,
                    ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                _otpSent
                    ? 'Saisissez le code à 6 chiffres envoyé sur $_confirmedEmail pour valider le pointage de ce collaborateur.'
                    : 'Borne partagée : saisissez l’e-mail du collaborateur enrôlé. Un code OTP lui sera envoyé pour valider son pointage.',
                style: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.copyWith(color: secondary),
              ),
              const SizedBox(height: AppSpacing.xl),
              if (!_otpSent) ...[
                TextField(
                  controller: _emailController,
                  autofocus: true,
                  keyboardType: TextInputType.emailAddress,
                  autocorrect: false,
                  textInputAction: TextInputAction.send,
                  decoration: const InputDecoration(
                    labelText: 'E-mail',
                    hintText: 'prenom.nom@exemple.com',
                    border: OutlineInputBorder(),
                  ),
                  onSubmitted: (_) {
                    if (!_busy) _requestOtp();
                  },
                ),
                const Spacer(),
                PrimaryButton(
                  label: 'Recevoir le code',
                  loading: _busy,
                  onPressed: _busy ? null : _requestOtp,
                ),
              ] else ...[
                OtpCodeInput(
                  key: _otpKey,
                  enabled: !_busy,
                  onChanged: (c) => setState(() => _otpCode = c),
                  onCompleted: (_) {
                    if (!_busy) _submitPunch();
                  },
                ),
                Text(
                  'Chiffres visibles. Collez le code ou utilisez la suggestion '
                  'si l’e-mail est ouvert sur ce téléphone.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: secondary,
                      ),
                ),
                const SizedBox(height: AppSpacing.md),
                TextButton(
                  onPressed: _busy
                      ? null
                      : () {
                          setState(() {
                            _otpSent = false;
                            _otpCode = '';
                          });
                          _otpKey.currentState?.clear();
                        },
                  child: const Text('Modifier l’e-mail'),
                ),
                TextButton(
                  onPressed: _busy ? null : _requestOtp,
                  child: const Text('Renvoyer le code'),
                ),
                const Spacer(),
                PrimaryButton(
                  label: 'Valider le pointage',
                  loading: _busy,
                  onPressed: _busy ? null : _submitPunch,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
