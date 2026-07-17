import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
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

class BiometricValidateScreen extends ConsumerStatefulWidget {
  const BiometricValidateScreen({super.key});

  static const routePath = '/biometric-validate';

  @override
  ConsumerState<BiometricValidateScreen> createState() =>
      _BiometricValidateScreenState();
}

class _BiometricValidateScreenState
    extends ConsumerState<BiometricValidateScreen> {
  bool _busy = false;

  Future<void> _submit() async {
    final pending = ref.read(pendingAttendanceProvider);
    if (pending == null) {
      showAppToast(context, 'Aucun QR valide. Reprenez le scan.', type: ToastType.error);
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
      } else if (pending.scanValidated) {
        final pos = await gps.getCurrentPosition();
        latitude = pos.latitude;
        longitude = pos.longitude;
      } else {
        final zone = pending.officeZone ??
            ref.read(pointageTodayProvider).valueOrNull?.officeZone;
        final pos = await gps.verifyWithinOfficeZone(zone: zone);
        latitude = pos.latitude;
        longitude = pos.longitude;
      }

      final bio = ref.read(biometricServiceProvider);
      final nonce = await bio.createNonce();

      // Empreinte appareil pour le blocage multi-comptes (même jour) côté Laravel.
      var deviceId =
          await ref.read(secureStorageServiceProvider).readDeviceId();
      String? serialNumber;
      final deviceInfo = await DeviceInfoService().collect();
      if (deviceId == null || deviceId.trim().isEmpty || deviceId == 'unknown') {
        deviceId = deviceInfo.deviceId;
        await ref.read(secureStorageServiceProvider).writeDeviceId(deviceId);
      }
      serialNumber = deviceInfo.serialNumber;

      final body = AttendanceSubmitRequest(
        qrPayload: pending.qrPayload,
        latitude: latitude,
        longitude: longitude,
        biometricNonce: nonce,
        type: effectiveType,
        deviceId: deviceId,
        serialNumber: serialNumber,
      );

      final remote = ref.read(attendanceRemoteDataSourceProvider);
      final offline = ref.read(offlineSyncServiceProvider);

      AttendanceSubmitResponse res;
      try {
        // Les deux endpoints convergent côté Laravel ; le type réel dépend de l’heure (plage).
        res = effectiveType == 'checkout'
            ? await remote.checkOut(body)
            : await remote.checkIn(body);
      } on Failure catch (e) {
        final queued =
            e is NetworkFailure || !await offline.isOnline;
        if (queued) {
          await offline.enqueuePending(body.toJson());
          if (!mounted) return;
          showAppToast(
            context,
            'Hors ligne : pointage mis en file d’attente sécurisée.',
            type: ToastType.info,
          );
          context.pop();
          context.pop();
          return;
        }
        rethrow;
      }

      // Toujours se fier au type renvoyé par le serveur (plages horaires).
      final recordedAsCheckout = _isCheckoutType(res.type);
      final ui = ref.read(todayAttendanceUiProvider.notifier);
      final apiToday = ref.read(pointageTodayProvider).valueOrNull;
      if (recordedAsCheckout) {
        // Ne pas inventer une Entrée : garder seulement une entrée déjà connue serveur.
        ui.syncToday(
          checkIn: apiToday?.checkIn,
          checkOut: res.recordedAt,
        );
      } else {
        ui.syncToday(
          checkIn: res.recordedAt,
          checkOut: apiToday?.checkOut,
        );
      }
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
      showAppToast(context, e.message, type: ToastType.error);
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
    return Scaffold(
      appBar: AppBar(title: const Text('Validation biométrique')),
      body: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          children: [
            const Spacer(),
            Container(
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.primary.withValues(alpha: 0.12),
              ),
              child: Icon(
                Icons.fingerprint,
                size: 96,
                color: Theme.of(context).colorScheme.primary,
              ),
            )
                .animate(onPlay: (c) => c.repeat(reverse: true))
                .scale(
                  duration: 1600.ms,
                  begin: const Offset(0.96, 0.96),
                  end: const Offset(1, 1),
                  curve: Curves.easeInOut,
                ),
            const SizedBox(height: AppSpacing.xl),
            Text(
              'Touchez le capteur d’empreinte pour valider le pointage',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
            ),
            const Spacer(),
            PrimaryButton(
              label: 'Valider le pointage',
              loading: _busy,
              onPressed: _busy ? null : _submit,
            ),
            TextButton(
              onPressed: _busy ? null : () => context.pop(),
              child: const Text('Annuler'),
            ),
          ],
        ),
      ),
    );
  }
}
