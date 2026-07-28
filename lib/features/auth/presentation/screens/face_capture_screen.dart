import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
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

class _FaceCaptureScreenState extends State<FaceCaptureScreen> {
  CameraController? _controller;
  bool _ready = false;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _initCamera();
  }

  Future<void> _initCamera() async {
    if (kIsWeb) {
      setState(() {
        _error = 'Caméra / reconnaissance faciale indisponible sur le web.';
      });
      return;
    }

    final camStatus = await Permission.camera.request();
    if (!camStatus.isGranted) {
      setState(() {
        _error = 'Autorisez l’accès à la caméra pour continuer.';
      });
      return;
    }

    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        setState(() => _error = 'Aucune caméra disponible.');
        return;
      }
      final front = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.front,
        orElse: () => cameras.first,
      );
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
      setState(() {
        _controller = controller;
        _ready = true;
      });
    } catch (e) {
      setState(() => _error = 'Impossible d’ouvrir la caméra : $e');
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
      Navigator.of(context).pop<String>(file.path);
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
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.mode == FaceCaptureMode.enroll
        ? 'Enrôlement facial'
        : 'Validation faciale';
    final hint = widget.mode == FaceCaptureMode.enroll
        ? 'Placez votre visage dans le cadre, regard droit, puis capturez.'
        : 'Placez votre visage dans le cadre pour valider le pointage.';

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
                              child: Text(
                                _error!,
                                textAlign: TextAlign.center,
                                style: const TextStyle(color: Colors.white),
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
                                  CameraPreview(_controller!),
                                  Center(
                                    child: Container(
                                      width: 240,
                                      height: 300,
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(140),
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
                onPressed: (!_ready || _error != null || _busy) ? null : _capture,
              ),
              TextButton(
                onPressed: _busy ? null : () => Navigator.of(context).pop(),
                child: const Text('Annuler'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
