import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:permission_handler/permission_handler.dart';

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
  static bool get _isPhoneNative =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.iOS ||
          defaultTargetPlatform == TargetPlatform.android);

  late final MobileScannerController _controller = MobileScannerController(
    // Sur web / PC : pas de caméra arrière → démarrage manuel + facing adapté.
    autoStart: false,
    // Analyse chaque frame sans délai entre détections.
    detectionSpeed: DetectionSpeed.unrestricted,
    // Pointage QR : toujours la caméra arrière sur téléphone (iPhone inclus).
    facing: _isPhoneNative ? CameraFacing.back : CameraFacing.front,
    torchEnabled: false,
    formats: const [BarcodeFormat.qrCode],
    // Meilleure netteté QR (Android sinon ~640×480).
    cameraResolution: _isPhoneNative ? const Size(1280, 720) : null,
    // Sélecteur expérimental Android uniquement (sur iOS il peut ouvrir la frontale).
    useNewCameraSelector: defaultTargetPlatform == TargetPlatform.android,
    returnImage: false,
  );

  /// Cadre de détection (coordonnées écran) — recalculé au layout.
  static const double _scanBoxSize = 280;

  bool _handled = false;
  bool _validating = false;
  bool _starting = true;
  String? _startError;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(gpsVerificationServiceProvider).warmUpLocation();
      unawaited(_startCamera());
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// Sur téléphone, refusece la caméra arrière si iOS a ouvert la frontale.
  Future<void> _ensureBackCamera() async {
    if (!_isPhoneNative) return;
    for (var i = 0; i < 2; i++) {
      if (_controller.value.cameraDirection == CameraFacing.back) {
        return;
      }
      try {
        await _controller.switchCamera();
      } catch (_) {
        break;
      }
    }
  }

  Future<void> _startCamera() async {
    if (!mounted) return;
    setState(() {
      _starting = true;
      _startError = null;
    });

    try {
      if (!kIsWeb) {
        final status = await Permission.camera.request();
        if (!status.isGranted) {
          throw Exception(
            'Permission caméra refusée. Autorisez-la dans les réglages.',
          );
        }
      }

      // Relancer proprement (ex. après erreur / Réessayer).
      try {
        await _controller.stop();
      } catch (_) {}

      if (_isPhoneNative) {
        // iPhone / Android : caméra arrière uniquement (pas de secours frontale).
        try {
          await _controller.start(cameraDirection: CameraFacing.back);
        } catch (_) {
          await _controller.start();
        }
        await _ensureBackCamera();
      } else {
        // PC / navigateur : webcam frontale, puis secours.
        try {
          await _controller.start(cameraDirection: CameraFacing.front);
        } catch (_) {
          await _controller.start(cameraDirection: CameraFacing.back);
        }
      }

      if (mounted) {
        setState(() => _starting = false);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _starting = false;
          _startError = e.toString().replaceFirst('Exception: ', '');
        });
      }
    }
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
                ...sites.map(
                  (s) => _SitePickerTile(site: s, onPick: _startManual),
                ),
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

  Future<void> _pasteQrPayload() async {
    final controller = TextEditingController();
    final raw = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Coller le contenu du QR'),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLines: 4,
          decoration: const InputDecoration(
            hintText: 'URL ou code scanné…',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: const Text('Valider'),
          ),
        ],
      ),
    );
    if (raw == null || raw.isEmpty || !mounted) return;
    final pending = _inferPayload(raw);
    await _validateAndOpenBiometric(
      qrPayload: pending.qrPayload,
      type: pending.type,
    );
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
        // Stop immédiat pour figer la détection et libérer le CPU.
        unawaited(_controller.stop());
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

      final device = await DeviceInfoService().resolveAndPersist(
        ref.read(secureStorageServiceProvider).writeDeviceId,
      );

      final remote = ref.read(attendanceRemoteDataSourceProvider);
      final scan = await remote.validateScan(
        AttendanceScanRequest(
          qrPayload: qrPayload,
          latitude: pos.latitude,
          longitude: pos.longitude,
          deviceId: device.deviceId,
          serialNumber: device.serialNumber,
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
        // Remettre la caméra pour un nouveau scan (échec ou retour).
        unawaited(_resumeScanner());
      }
    }
  }

  Future<void> _resumeScanner() async {
    if (!mounted || _starting) return;
    try {
      if (_isPhoneNative) {
        try {
          await _controller.start(cameraDirection: CameraFacing.back);
        } catch (_) {
          await _controller.start();
        }
        await _ensureBackCamera();
      } else {
        try {
          await _controller.start(cameraDirection: CameraFacing.front);
        } catch (_) {
          await _controller.start(cameraDirection: CameraFacing.back);
        }
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: LayoutBuilder(
        builder: (context, constraints) {
          final scanWindow = Rect.fromCenter(
            center: Offset(constraints.maxWidth / 2, constraints.maxHeight / 2),
            width: _scanBoxSize,
            height: _scanBoxSize,
          );

          return Stack(
            fit: StackFit.expand,
            children: [
              MobileScanner(
                controller: _controller,
                onDetect: _onDetect,
                scanWindow: scanWindow,
                fit: BoxFit.cover,
                errorBuilder: (context, error, child) {
                  return _CameraFallback(
                    message: error.errorDetails?.message ??
                        error.errorCode.message,
                    onRetry: _startCamera,
                    onSites: _openSitePicker,
                    onPaste: _pasteQrPayload,
                  );
                },
              ),
              if (_starting)
                const ColoredBox(
                  color: Colors.black87,
                  child: Center(
                    child: CircularProgressIndicator(color: Colors.white),
                  ),
                ),
              if (!_starting && _startError != null)
                _CameraFallback(
                  message: _startError!,
                  onRetry: _startCamera,
                  onSites: _openSitePicker,
                  onPaste: _pasteQrPayload,
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
              if (_startError == null && !_starting)
                Align(
                  alignment: Alignment.center,
                  child: Container(
                    width: _scanBoxSize,
                    height: _scanBoxSize,
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.white24, width: 2),
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: Stack(
                      children: [
                        Positioned(left: 0, top: 0, child: _corner()),
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
                          child:
                              Transform.rotate(angle: -1.5708, child: _corner()),
                        ),
                      ],
                    ),
                  ),
                ),
              Positioned(
                top: MediaQuery.paddingOf(context).top + 8,
                left: AppSpacing.md,
                right: AppSpacing.md,
                child: Row(
                  children: [
                    IconButton.filledTonal(
                      style: IconButton.styleFrom(
                        backgroundColor: Colors.white24,
                        foregroundColor: Colors.white,
                      ),
                      onPressed: _validating ? null : () => context.pop(),
                      icon: const Icon(Icons.arrow_back),
                    ),
                    const Spacer(),
                    IconButton.filledTonal(
                      style: IconButton.styleFrom(
                        backgroundColor: Colors.white24,
                        foregroundColor: Colors.white,
                      ),
                      onPressed: _validating ? null : _pasteQrPayload,
                      icon: const Icon(Icons.content_paste_rounded),
                      tooltip: 'Coller le QR',
                    ),
                    const SizedBox(width: 8),
                    IconButton.filledTonal(
                      style: IconButton.styleFrom(
                        backgroundColor: Colors.white24,
                        foregroundColor: Colors.white,
                      ),
                      onPressed: _validating ? null : _openSitePicker,
                      icon: const Icon(Icons.apartment_rounded),
                      tooltip: 'Sites (sans QR)',
                    ),
                  ],
                ),
              ),
              if (_startError == null && !_starting)
                Positioned(
                  bottom: 48,
                  left: AppSpacing.lg,
                  right: AppSpacing.lg,
                  child: Column(
                    children: [
                      Text(
                        kIsWeb
                            ? 'Autorisez la webcam, puis placez le QR devant'
                            : 'Placez le QR code dans le cadre',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              color: Colors.white,
                              shadows: const [
                                Shadow(blurRadius: 8, color: Colors.black54),
                              ],
                            ),
                      ),
                      if (!kIsWeb) ...[
                        const SizedBox(height: AppSpacing.md),
                        Align(
                          alignment: Alignment.centerRight,
                          child: IconButton.filledTonal(
                            onPressed: _validating
                                ? null
                                : () => _controller.toggleTorch(),
                            icon: const Icon(Icons.flashlight_on_outlined),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
            ],
          );
        },
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

class _CameraFallback extends StatelessWidget {
  const _CameraFallback({
    required this.message,
    required this.onRetry,
    required this.onSites,
    required this.onPaste,
  });

  final String message;
  final VoidCallback onRetry;
  final VoidCallback onSites;
  final VoidCallback onPaste;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Colors.black,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.videocam_off_outlined,
                size: 56,
                color: Colors.white70,
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                'Caméra indisponible',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white70, height: 1.35),
              ),
              if (kIsWeb) ...[
                const SizedBox(height: AppSpacing.sm),
                const Text(
                  'Sur Chrome PC, acceptez l’accès webcam. '
                  'Le scan réel se fait idéalement sur le téléphone (APK).',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white54, fontSize: 13),
                ),
              ],
              const SizedBox(height: AppSpacing.lg),
              FilledButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh),
                label: const Text('Réessayer la caméra'),
              ),
              const SizedBox(height: AppSpacing.sm),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(foregroundColor: Colors.white),
                onPressed: onPaste,
                icon: const Icon(Icons.content_paste_rounded),
                label: const Text('Coller le contenu du QR'),
              ),
              const SizedBox(height: AppSpacing.sm),
              TextButton(
                onPressed: onSites,
                child: const Text('Choisir un site (sans QR)'),
              ),
            ],
          ),
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
