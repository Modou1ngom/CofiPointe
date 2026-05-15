import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_spacing.dart';
import '../../../../providers/app_providers.dart';
import '../../../../providers/async_data_providers.dart';
import '../../../../providers/theme_mode_provider.dart';
import '../../../../services/session_controller.dart';
import '../../../../widgets/feedback/app_toast.dart';
import '../../../auth/data/models/user_model.dart';
import '../../../auth/presentation/screens/login_screen.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  static const routePath = '/profile';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(sessionControllerProvider);
    final profileAsync = ref.watch(profileUserProvider);
    final themeMode = ref.watch(themeModeProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Mon profil')),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.md),
        children: [
          profileAsync.when(
            loading: () => const Card(
              child: SizedBox(
                height: 140,
                child: Center(child: CircularProgressIndicator()),
              ),
            ),
            error: (_, __) => _ProfileHeaderCard(
              user: _mergeUser(session.user, null),
            ),
            data: (u) => _ProfileHeaderCard(
              user: _mergeUser(session.user, u),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(
            'Mon compte',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: AppColors.charcoal,
                ),
          ),
          const SizedBox(height: AppSpacing.sm),
          profileAsync.when(
            loading: () => const SizedBox.shrink(),
            error: (_, __) => _AccountDetails(
              user: _mergeUser(session.user, null),
              biometricEnabled: session.biometricEnabled,
            ),
            data: (u) => _AccountDetails(
              user: _mergeUser(session.user, u),
              biometricEnabled: session.biometricEnabled,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(
            'Paramètres',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: AppColors.charcoal,
                ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Card(
            child: Column(
              children: [
                RadioListTile<ThemeMode>(
                  title: const Text('Apparence système'),
                  value: ThemeMode.system,
                  groupValue: themeMode,
                  onChanged: (v) {
                    if (v != null) {
                      ref.read(themeModeProvider.notifier).state = v;
                    }
                  },
                ),
                RadioListTile<ThemeMode>(
                  title: const Text('Thème clair'),
                  value: ThemeMode.light,
                  groupValue: themeMode,
                  onChanged: (v) {
                    if (v != null) {
                      ref.read(themeModeProvider.notifier).state = v;
                    }
                  },
                ),
                RadioListTile<ThemeMode>(
                  title: const Text('Thème sombre'),
                  value: ThemeMode.dark,
                  groupValue: themeMode,
                  onChanged: (v) {
                    if (v != null) {
                      ref.read(themeModeProvider.notifier).state = v;
                    }
                  },
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.help_outline_rounded),
                  title: const Text('Aide et support'),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => showAppToast(
                    context,
                    'Contactez votre administrateur COFINA pour toute assistance.',
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          FilledButton.tonalIcon(
            style: FilledButton.styleFrom(
              foregroundColor: AppColors.primary,
            ),
            onPressed: () async {
              try {
                await ref.read(authRepositoryProvider).logout();
              } catch (_) {}
              await ref.read(sessionControllerProvider.notifier).logout();
              if (context.mounted) {
                context.go(LoginScreen.routePath);
              }
            },
            icon: const Icon(Icons.logout_rounded),
            label: const Text('Se déconnecter'),
          ),
        ],
      ),
    );
  }

  /// Préfère les champs détaillés du profil API quand présents.
  static UserModel _mergeUser(UserModel? sessionUser, UserModel? apiUser) {
    if (apiUser == null) {
      return sessionUser ??
          const UserModel(id: '', fullName: '—', email: null, matricule: null);
    }
    if (sessionUser == null) return apiUser;
    return UserModel(
      id: apiUser.id.isNotEmpty ? apiUser.id : sessionUser.id,
      fullName: apiUser.fullName.isNotEmpty ? apiUser.fullName : sessionUser.fullName,
      email: apiUser.email ?? sessionUser.email,
      matricule: apiUser.matricule ?? sessionUser.matricule,
      avatarUrl: apiUser.avatarUrl ?? sessionUser.avatarUrl,
      jobTitle: apiUser.jobTitle ?? sessionUser.jobTitle,
      phone: apiUser.phone ?? sessionUser.phone,
      department: apiUser.department ?? sessionUser.department,
      linkedDevice: apiUser.linkedDevice ?? sessionUser.linkedDevice,
    );
  }
}

class _ProfileHeaderCard extends StatelessWidget {
  const _ProfileHeaderCard({required this.user});

  final UserModel user;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              radius: 36,
              backgroundColor: AppColors.primary.withValues(alpha: 0.12),
              foregroundColor: AppColors.primary,
              child: Text(
                user.fullName.trim().isEmpty
                    ? '?'
                    : String.fromCharCode(user.fullName.trim().runes.first)
                        .toUpperCase(),
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    user.fullName,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w900,
                          color: AppColors.charcoal,
                        ),
                  ),
                  if (user.jobTitle != null && user.jobTitle!.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      user.jobTitle!,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: scheme.onSurfaceVariant,
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                  ],
                  if (user.matricule != null && user.matricule!.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      'Matricule : ${user.matricule}',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppColors.primary,
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AccountDetails extends StatelessWidget {
  const _AccountDetails({
    required this.user,
    required this.biometricEnabled,
  });

  final UserModel user;
  final bool biometricEnabled;

  String _orDash(String? v) =>
      (v != null && v.trim().isNotEmpty) ? v.trim() : '—';

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Column(
        children: [
          ListTile(
            leading: const Icon(Icons.email_outlined),
            title: const Text('E-mail'),
            subtitle: Text(_orDash(user.email)),
          ),
          const Divider(height: 1),
          ListTile(
            leading: const Icon(Icons.phone_outlined),
            title: const Text('Téléphone'),
            subtitle: Text(_orDash(user.phone)),
          ),
          const Divider(height: 1),
          ListTile(
            leading: const Icon(Icons.apartment_outlined),
            title: const Text('Département'),
            subtitle: Text(_orDash(user.department)),
          ),
          const Divider(height: 1),
          ListTile(
            leading: const Icon(Icons.badge_outlined),
            title: const Text('Matricule'),
            subtitle: Text(_orDash(user.matricule)),
          ),
          const Divider(height: 1),
          ListTile(
            leading: const Icon(Icons.fingerprint_rounded),
            title: const Text('Biométrie'),
            subtitle: Text(biometricEnabled ? 'Activée' : 'Désactivée'),
          ),
          const Divider(height: 1),
          ListTile(
            leading: const Icon(Icons.smartphone_outlined),
            title: const Text('Appareil lié'),
            subtitle: Text(_orDash(user.linkedDevice)),
          ),
        ],
      ),
    );
  }
}
