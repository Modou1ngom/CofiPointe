import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/constants/app_spacing.dart';
import '../../../../core/errors/failures.dart';
import '../../../../providers/app_providers.dart';
import '../../../../services/device_info_service.dart';
import '../../../../services/session_controller.dart';
import '../../../../widgets/buttons/primary_button.dart';
import '../../../../widgets/cards/glass_card.dart';
import '../../../../widgets/feedback/app_toast.dart';
import '../../data/models/auth_api_models.dart';
import '../../../dashboard/presentation/screens/dashboard_screen.dart';

class DeviceRegistrationScreen extends ConsumerStatefulWidget {
  const DeviceRegistrationScreen({super.key});

  static const routePath = '/device-registration';

  @override
  ConsumerState<DeviceRegistrationScreen> createState() =>
      _DeviceRegistrationScreenState();
}

class _DeviceRegistrationScreenState
    extends ConsumerState<DeviceRegistrationScreen> {
  DeviceRegistrationInfo? _info;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final svc = DeviceInfoService();
    final info = await svc.collect();
    setState(() => _info = info);
  }

  Future<void> _authorize() async {
    final info = _info;
    if (info == null) return;
    setState(() => _loading = true);
    try {
      final repo = ref.read(authRepositoryProvider);
      await repo.registerDevice(
        RegisterDeviceRequest(
          deviceId: info.deviceId,
          model: info.model,
          osVersion: info.osVersion,
          appVersion: info.appVersion,
        ),
      );
      await ref.read(secureStorageServiceProvider).writeDeviceId(info.deviceId);
      await ref.read(sessionControllerProvider.notifier).setDeviceRegistered(true);
      if (!mounted) return;
      showAppToast(context, 'Appareil enregistré.', type: ToastType.success);
      context.go(DashboardScreen.routePath);
    } on Failure catch (e) {
      showAppToast(context, e.message, type: ToastType.error);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final info = _info;
    final df = DateFormat('dd/MM/yyyy HH:mm');

    return Scaffold(
      appBar: AppBar(title: const Text('Enregistrement appareil')),
      body: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Icon(Icons.shield_moon_outlined, size: 56, color: Theme.of(context).colorScheme.primary)
                .animate()
                .fadeIn()
                .scale(begin: const Offset(0.9, 0.9)),
            const SizedBox(height: AppSpacing.lg),
            GlassCard(
              child: info == null
                  ? const Center(child: CircularProgressIndicator())
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Appareil détecté',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                        ),
                        const SizedBox(height: AppSpacing.md),
                        _line('Modèle', info.model),
                        _line('ID appareil', info.deviceId),
                        _line('Système', info.osVersion),
                        _line('Première connexion', df.format(DateTime.now())),
                      ],
                    ),
            ),
            const Spacer(),
            PrimaryButton(
              label: 'Autoriser cet appareil',
              loading: _loading,
              onPressed: info == null ? null : _authorize,
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              'Cet appareil sera lié à votre compte.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _line(String k, String v) {
    final variant = Theme.of(context).colorScheme.onSurfaceVariant;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 130,
            child: Text(k, style: TextStyle(color: variant)),
          ),
          Expanded(
            child: Text(v, style: const TextStyle(fontWeight: FontWeight.w500)),
          ),
        ],
      ),
    );
  }
}
