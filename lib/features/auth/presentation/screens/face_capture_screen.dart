import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_spacing.dart';
import '../../../../core/errors/failures.dart';
import '../../../../widgets/buttons/primary_button.dart';
import '../../../../widgets/feedback/app_toast.dart';

enum FaceCaptureMode { enroll, verify }

/// Capture caméra avant + retourne le chemin du fichier photo.
class FaceCaptureScreen extends StatefulWidget {
  const FaceCaptureScreen({
    super.key,
    required this.mode,
  });

  final FaceCaptureMode mode;

  static const routePathEnroll = '/face-enroll';
  static const routePathVerify = '/face-verify';

  @override
  State<FaceCaptureScreen> createState() => _FaceCaptureScreenState();
}

class _FaceCaptureScreenState extends State<FaceCaptureScreen>
    with WidgetsBindingObserver {
  CameraController? _controller;
  bool _ready = false;
  bool _busy = false;
  bool _isFront = true;
  bool _initializing = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Attendre la 1re frame : évite le crash CameraX
    // « flutterSurfaceProducer … has not yet been initialized ».
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _initCamera();
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) return;
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused) {
      _disposeController();
      if (mounted) setState(() => _ready = false);
    } else if (state == AppLifecycleState.resumed) {
      _initCamera();
    }
  }

  Future<void> _disposeController() async {
    final c = _controller;
    _controller = null;
    if (c != null) {
      try {
        await c.dispose();
      } catch (_) {}
    }
  }

  bool _isSurfaceRaceError(Object e) {
    final s = e.toString();
    return s.contains('flutterSurfaceProducer') ||
        s.contains('surfaceProducerHandlesCropAndRotation') ||
        s.contains('releaseFlutterSurfaceTexture');
  }

  Future<void> _initCamera({int attempt = 0}) async {
    if (!mounted || _initializing) return;
    if (kIsWeb) {
      setState(() {
        _error = 'Caméra / reconnaissance faciale indisponible sur le web.';
      });
      return;
    }

    setState(() {
      _initializing = true;
      _error = null;
      _ready = false;
    });

    try {
      final camStatus = await Permission.camera.request();
      if (!camStatus.isGranted) {
        if (!mounted) return;
        setState(() {
          _error = 'Autorisez l’accès à la caméra pour continuer.';
          _initializing = false;
        });
        return;
      }

      await _disposeController();

      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        if (!mounted) return;
        setState(() {
          _error = 'Aucune caméra disponible.';
          _initializing = false;
        });
        return;
      }

      final front = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.front,
        orElse: () => cameras.first,
      );

      // medium = plus stable que high sur certains Android (CameraX).
      final controller = CameraController(
        front,
        ResolutionPreset.medium,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.jpeg,
      );

      await controller.initialize();
      if (!mounted) {
        await controller.dispose();
        return;
      }

      // Laisser le SurfaceProducer s’attacher avant CameraPreview.
      await Future<void>.delayed(const Duration(milliseconds: 80));
      if (!mounted) {
        await controller.dispose();
        return;
      }

      setState(() {
        _controller = controller;
        _isFront = front.lensDirection == CameraLensDirection.front;
        _ready = true;
        _error = null;
        _initializing = false;
      });
    } catch (e) {
      await _disposeController();
      if (!mounted) return;

      if (_isSurfaceRaceError(e) && attempt < 2) {
        await Future<void>.delayed(Duration(milliseconds: 250 * (attempt + 1)));
        if (!mounted) return;
        setState(() => _initializing = false);
        await _initCamera(attempt: attempt + 1);
        return;
      }

      setState(() {
        _initializing = false;
        _error = _isSurfaceRaceError(e)
            ? 'La caméra n’a pas pu démarrer (conflit Android). '
                'Appuyez sur Réessayer, ou quittez puis rouvrez l’écran.'
            : 'Impossible d’ouvrir la caméra. Vérifiez les permissions '
                'et qu’aucune autre app n’utilise la caméra.';
      });
    }
  }

  Future<void> _capture() async {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized || _busy) {
      return;
    }
    setState(() => _busy = true);
    try {
      final file = await controller.takePicture();
      if (!mounted) return;
      context.pop<String>(file.path);
    } on Failure catch (e) {
      if (mounted) {
        showAppToast(context, e.message, type: ToastType.error);
      }
    } catch (e) {
      if (mounted) {
        showAppToast(
          context,
          'Capture impossible. Réessayez.',
          type: ToastType.error,
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    final c = _controller;
    _controller = null;
    c?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.mode == FaceCaptureMode.enroll
        ? 'Enrôlement facial'
        : 'Validation faciale';
    final hint = widget.mode == FaceCaptureMode.enroll
        ? 'Visage de face, yeux ouverts, bonne lumière. Évitez lunettes trop réfléchissantes.'
        : 'Même conditions qu’à l’enrôlement : face, lumière, yeux ouverts.';

    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                hint,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: AppSpacing.md),
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: ColoredBox(
                    color: Colors.black,
                    child: _error != null
                        ? Center(
                            child: Padding(
                              padding: const EdgeInsets.all(AppSpacing.lg),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    _error!,
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(color: Colors.white),
                                  ),
                                  const SizedBox(height: AppSpacing.md),
                                  TextButton.icon(
                                    onPressed: _initializing
                                        ? null
                                        : () => _initCamera(),
                                    icon: const Icon(Icons.refresh,
                                        color: Colors.white),
                                    label: const Text(
                                      'Réessayer',
                                      style: TextStyle(color: Colors.white),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          )
                        : !_ready || _controller == null
                            ? const Center(
                                child: CircularProgressIndicator(
                                  color: AppColors.primary,
                                ),
                              )
                            : Stack(
                                fit: StackFit.expand,
                                children: [
                                  // Miroir pour caméra avant (comportement selfie).
                                  Transform.flip(
                                    flipX: _isFront,
                                    child: CameraPreview(_controller!),
                                  ),
                                  Center(
                                    child: Container(
                                      width: 240,
                                      height: 300,
                                      decoration: BoxDecoration(
                                        borderRadius:
                                            BorderRadius.circular(140),
                                        border: Border.all(
                                          color: AppColors.primary,
                                          width: 3,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              PrimaryButton(
                label: widget.mode == FaceCaptureMode.enroll
                    ? 'Enregistrer mon visage'
                    : 'Valider mon visage',
                loading: _busy,
                onPressed:
                    (!_ready || _error != null || _busy) ? null : _capture,
              ),
              TextButton(
                onPressed: _busy ? null : () => context.pop(),
                child: const Text('Annuler'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
