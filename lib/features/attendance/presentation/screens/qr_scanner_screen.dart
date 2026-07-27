import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_spacing.dart';
import '../../../../core/errors/failures.dart';
import '../../../../features/attendance/data/models/attendance_models.dart';
import '../../../../features/attendance/data/models/pointage_mobile_models.dart';
import '../../../../providers/app_providers.dart';
import '../../../../providers/attendance_ui_provider.dart';
import '../../../../providers/pointage_mobile_providers.dart';
import '../../../../services/device_info_service.dart';
import '../../../../services/session_controller.dart';
import '../../../../widgets/feedback/app_toast.dart';
import 'biometric_validate_screen.dart';
import 'matricule_validate_screen.dart';

class QrScannerScreen extends ConsumerStatefulWidget {
  const QrScannerScreen({super.key});

  static const routePath = '/scan';

  @override
  ConsumerState<QrScannerScreen> createState() => _QrScannerScreenState();
}

class _QrScannerScreenState extends ConsumerState<QrScannerScreen> {
  final MobileScannerController _controller = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
    facing: CameraFacing.back,
    torchEnabled: false,
    formats: const [BarcodeFormat.qrCode],
  );

  bool _handled = false;
  bool _validating = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(gpsVerificationServiceProvider).warmUpLocation();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _openSitePicker() async {
    try {
      final sites = await ref.read(pointageSitesProvider.future);
      if (!mounted) return;
      await showModalBottomSheet<void>(
        context: context,
        showDragHandle: true,
        builder: (ctx) {
          if (sites.isEmpty) {
            return const SafeArea(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text('Aucun site de pointage disponible.'),
              ),
            );
          }
          return SafeArea(
            child: ListView(
              shrinkWrap: true,
              children: [
                ListTile(
                  title: Text(
                    'Pointage sans QR',
                    style: Theme.of(ctx).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                  subtitle: const Text(
                    'Choisissez un site puis entrée ou sortie.',
                  ),
                ),
                const Divider(height: 1),
                ...sites.map((s) => _SitePickerTile(site: s, onPick: _startManual)),
              ],
            ),
          );
        },
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Sites : $e')),
      );
    }
  }

  Future<void> _startManual(PointageSiteSummary site, String type) async {
    final payload = jsonEncode({'code_public': site.codePublic});
    await _validateAndOpenBiometric(
      qrPayload: payload,
      type: type,
    );
  }

  void _onDetect(BarcodeCapture capture) {
    if (_handled || _validating) return;
    for (final b in capture.barcodes) {
      final raw = b.rawValue;
      if (raw != null && raw.isNotEmpty) {
        _handled = true;
        final pending = _inferPayload(raw);
        _validateAndOpenBiometric(
          qrPayload: pending.qrPayload,
          type: pending.type,
        );
        break;
      }
    }
  }

  PendingAttendancePayload _inferPayload(String raw) {
    final local = ref.read(todayAttendanceUiProvider);
    final api = ref.read(pointageTodayProvider).valueOrNull;
    final type = resolveNextAttendanceType(
      checkIn: local.checkIn ?? api?.checkIn,
      checkOut: local.checkOut ?? api?.checkOut,
    );
    return PendingAttendancePayload(qrPayload: raw, type: type);
  }

  /// GPS appareil + validation serveur vs site du QR (équipement sur place).
  Future<void> _validateAndOpenBiometric({
    required String qrPayload,
    required String type,
  }) async {
    if (_validating) return;
    setState(() => _validating = true);

    try {
      final gps = ref.read(gpsVerificationServiceProvider);
      final pos = await gps.getCurrentPosition();

      var deviceId =
          await ref.read(secureStorageServiceProvider).readDeviceId();
      final deviceInfo = await DeviceInfoService().collect();
      if (deviceId == null || deviceId.trim().isEmpty || deviceId == 'unknown') {
        deviceId = deviceInfo.deviceId;
        await ref.read(secureStorageServiceProvider).writeDeviceId(deviceId);
      }

      final remote = ref.read(attendanceRemoteDataSourceProvider);
      final scan = await remote.validateScan(
        AttendanceScanRequest(
          qrPayload: qrPayload,
          latitude: pos.latitude,
          longitude: pos.longitude,
          deviceId: deviceId,
          serialNumber: deviceInfo.serialNumber,
        ),
      );

      if (!scan.valid) {
        throw const LocationFailure('Scan refusé par le serveur.');
      }

      ref.read(pendingAttendanceProvider.notifier).state =
          PendingAttendancePayload(
        qrPayload: qrPayload,
        type: type,
        officeZone: scan.officeZone,
        scanValidated: true,
        scanLatitude: pos.latitude,
        scanLongitude: pos.longitude,
        isVirtual: scan.isVirtual,
        requiresMatricule: scan.requiresMatricule,
        agenceNom: scan.agenceNom,
      );

      if (!mounted) return;
      if (scan.requiresEmail || scan.isVirtual) {
        await context.push(MatriculeValidateScreen.routePath);
      } else {
        await context.push(BiometricValidateScreen.routePath);
      }
    } on Failure catch (e) {
      if (mounted) {
        showAppToast(context, e.message, type: ToastType.error);
      }
    } catch (e) {
      if (mounted) {
        showAppToast(
          context,
          e is TimeoutException
              ? 'GPS trop lent : activez la localisation précise et réessayez.'
              : 'Scan impossible : $e',
          type: ToastType.error,
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _validating = false;
          _handled = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          MobileScanner(
            controller: _controller,
            onDetect: _onDetect,
          ),
          if (_validating)
            Container(
              color: Colors.black54,
              alignment: Alignment.center,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const CircularProgressIndicator(color: Colors.white),
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    'Vérification GPS du site…',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: Colors.white,
                        ),
                  ),
                ],
              ),
            ),
          Align(
            alignment: Alignment.center,
            child: Container(
              width: 260,
              height: 260,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.white24, width: 2),
                borderRadius: BorderRadius.circular(24),
              ),
              child: Stack(
                children: [
                  Positioned(
                    left: 0,
                    top: 0,
                    child: _corner(),
                  ),
                  Positioned(
                    right: 0,
                    top: 0,
                    child: Transform.rotate(angle: 1.5708, child: _corner()),
                  ),
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: Transform.rotate(angle: 3.1416, child: _corner()),
                  ),
                  Positioned(
                    left: 0,
                    bottom: 0,
                    child: Transform.rotate(angle: -1.5708, child: _corner()),
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            top: MediaQuery.paddingOf(context).top + 8,
            right: AppSpacing.md,
            child: IconButton.filledTonal(
              style: IconButton.styleFrom(
                backgroundColor: Colors.white24,
                foregroundColor: Colors.white,
              ),
              onPressed: _validating ? null : _openSitePicker,
              icon: const Icon(Icons.apartment_rounded),
              tooltip: 'Sites (sans QR)',
            ),
          ),
          Positioned(
            bottom: 48,
            left: AppSpacing.lg,
            right: AppSpacing.lg,
            child: Column(
              children: [
                Text(
                  'Placez le QR code dans le cadre',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: Colors.white,
                        shadows: const [
                          Shadow(blurRadius: 8, color: Colors.black54),
                        ],
                      ),
                ),
                const SizedBox(height: AppSpacing.md),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    IconButton.filledTonal(
                      onPressed: _validating ? null : () => context.pop(),
                      icon: const Icon(Icons.arrow_back),
                    ),
                    IconButton.filledTonal(
                      onPressed: _validating ? null : () => _controller.toggleTorch(),
                      icon: const Icon(Icons.flashlight_on_outlined),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _corner() {
    return Container(
      width: 36,
      height: 36,
      decoration: const BoxDecoration(
        border: Border(
          top: BorderSide(color: AppColors.primary, width: 4),
          left: BorderSide(color: AppColors.primary, width: 4),
        ),
      ),
    );
  }
}

class _SitePickerTile extends StatelessWidget {
  const _SitePickerTile({
    required this.site,
    required this.onPick,
  });

  final PointageSiteSummary site;
  final void Function(PointageSiteSummary site, String type) onPick;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: Text(site.nom),
      subtitle: Text(
        site.codePublic,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: Wrap(
        spacing: 4,
        children: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              onPick(site, 'checkin');
            },
            child: const Text('Entrée'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              onPick(site, 'checkout');
            },
            child: const Text('Sortie'),
          ),
        ],
      ),
    );
  }
}
