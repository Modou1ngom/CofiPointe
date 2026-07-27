import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
  final _otpNodes = List.generate(6, (_) => FocusNode());
  final _otpControllers = List.generate(6, (_) => TextEditingController());

  bool _busy = false;
  bool _otpSent = false;
  String? _confirmedEmail;

  @override
  void dispose() {
    _emailController.dispose();
    for (final n in _otpNodes) {
      n.dispose();
    }
    for (final c in _otpControllers) {
      c.dispose();
    }
    super.dispose();
  }

  String get _otpCode => _otpControllers.map((c) => c.text).join();

  void _applyOtpDigits(String raw, {int startIndex = 0}) {
    final digits = raw.replaceAll(RegExp(r'\D'), '');
    if (digits.isEmpty) return;

    for (var j = 0; j < 6; j++) {
      final idx = startIndex + j;
      if (idx >= 6) break;
      _otpControllers[idx].text = j < digits.length ? digits[j] : '';
    }

    final filled = _otpCode.length.clamp(0, 6);
    final focusIndex = filled >= 6 ? 5 : filled;
    _otpNodes[focusIndex].requestFocus();
    setState(() {});
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

      var deviceId =
          await ref.read(secureStorageServiceProvider).readDeviceId();
      final deviceInfo = await DeviceInfoService().collect();
      if (deviceId == null || deviceId.trim().isEmpty || deviceId == 'unknown') {
        deviceId = deviceInfo.deviceId;
        await ref.read(secureStorageServiceProvider).writeDeviceId(deviceId);
      }

      final remote = ref.read(attendanceRemoteDataSourceProvider);
      final res = await remote.requestVirtualOtp(
        VirtualOtpRequest(
          qrPayload: pending.qrPayload,
          email: email,
          latitude: latitude,
          longitude: longitude,
          deviceId: deviceId,
          serialNumber: deviceInfo.serialNumber,
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
      _otpNodes.first.requestFocus();
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

      var deviceId =
          await ref.read(secureStorageServiceProvider).readDeviceId();
      String? serialNumber;
      final deviceInfo = await DeviceInfoService().collect();
      if (deviceId == null || deviceId.trim().isEmpty || deviceId == 'unknown') {
        deviceId = deviceInfo.deviceId;
        await ref.read(secureStorageServiceProvider).writeDeviceId(deviceId);
      }
      serialNumber = deviceInfo.serialNumber;

      final remote = ref.read(attendanceRemoteDataSourceProvider);
      final body = AttendanceSubmitRequest(
        qrPayload: pending.qrPayload,
        latitude: latitude,
        longitude: longitude,
        biometricNonce: 'email_otp:$email',
        type: effectiveType,
        deviceId: deviceId,
        serialNumber: serialNumber,
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
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: List.generate(6, (i) {
                    return SizedBox(
                      width: 44,
                      child: TextField(
                        controller: _otpControllers[i],
                        focusNode: _otpNodes[i],
                        autofocus: i == 0,
                        textAlign: TextAlign.center,
                        keyboardType: TextInputType.number,
                        maxLength: 1,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                        ],
                        decoration: const InputDecoration(
                          counterText: '',
                          border: OutlineInputBorder(),
                        ),
                        onChanged: (v) {
                          if (v.length > 1) {
                            _applyOtpDigits(v, startIndex: i);
                            return;
                          }
                          if (v.isNotEmpty && i < 5) {
                            _otpNodes[i + 1].requestFocus();
                          }
                          if (v.isEmpty && i > 0) {
                            _otpNodes[i - 1].requestFocus();
                          }
                          setState(() {});
                          if (_otpCode.length == 6 && !_busy) {
                            _submitPunch();
                          }
                        },
                      ),
                    );
                  }),
                ),
                const SizedBox(height: AppSpacing.md),
                TextButton(
                  onPressed: _busy
                      ? null
                      : () {
                          setState(() {
                            _otpSent = false;
                            for (final c in _otpControllers) {
                              c.clear();
                            }
                          });
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
