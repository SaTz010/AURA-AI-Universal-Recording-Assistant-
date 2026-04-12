import 'package:flutter/material.dart';

import '../providers/auth_provider.dart';
import '../theme/aura_theme.dart';
import '../theme/aura_tokens.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final authProvider = AuraAuthProvider.of(context);
    final colors = AuraThemeColors.of(context);

    if (authProvider.isGuest) {
      return Scaffold(
        backgroundColor: colors.background,
        appBar: AppBar(title: const Text('Profile')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.lock_person_rounded, size: 56),
                const SizedBox(height: 16),
                const Text(
                  'Login to show profile',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  'You are currently using guest mode.',
                  style: Theme.of(context).textTheme.bodyMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).pushNamedAndRemoveUntil('/auth', (route) => false);
                  },
                  child: const Text('Go to Login'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final user = authProvider.user;
    final name =
        user?.displayName?.trim().isNotEmpty == true ? user!.displayName!.trim() : 'AURA User';
    final email = user?.email?.trim().isNotEmpty == true ? user!.email!.trim() : 'Signed in';
    final photoUrl = user?.photoURL?.trim();

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        backgroundColor: colors.background,
        elevation: 0,
        title: Text(
          'Profile',
          style: AuraTypography.titleLarge(colors.textPrimary),
        ),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(AuraSpacing.xl),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.all(AuraSpacing.xl),
              decoration: BoxDecoration(
                color: colors.surface,
                borderRadius: AuraRadius.xlBr,
                border: Border.all(color: colors.border),
              ),
              child: Column(
                children: [
                  CircleAvatar(
                    radius: 34,
                    backgroundColor: colors.surfaceElevated,
                    backgroundImage: (photoUrl != null && photoUrl.isNotEmpty)
                        ? NetworkImage(photoUrl)
                        : null,
                    child: (photoUrl == null || photoUrl.isEmpty)
                        ? Icon(
                            Icons.person_rounded,
                            size: 34,
                            color: colors.iconDefault,
                          )
                        : null,
                  ),
                  const SizedBox(height: AuraSpacing.md),
                  Text(
                    name,
                    textAlign: TextAlign.center,
                    style: AuraTypography.titleLarge(colors.textPrimary),
                  ),
                  const SizedBox(height: AuraSpacing.xs),
                  Text(
                    email,
                    textAlign: TextAlign.center,
                    style: AuraTypography.bodyMedium(colors.textSecondary),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AuraSpacing.xl),
            _ProfileActionTile(
              icon: Icons.settings_rounded,
              label: 'Settings',
              onTap: () => Navigator.pushNamed(context, '/settings'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProfileActionTile extends StatelessWidget {
  const _ProfileActionTile({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = AuraThemeColors.of(context);

    return Material(
      color: colors.surface,
      borderRadius: AuraRadius.lgBr,
      child: InkWell(
        borderRadius: AuraRadius.lgBr,
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AuraSpacing.lg,
            vertical: AuraSpacing.lg,
          ),
          decoration: BoxDecoration(
            borderRadius: AuraRadius.lgBr,
            border: Border.all(color: colors.border),
          ),
          child: Row(
            children: [
              Icon(icon, color: colors.accent),
              const SizedBox(width: AuraSpacing.md),
              Expanded(
                child: Text(
                  label,
                  style: AuraTypography.titleMedium(colors.textPrimary),
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: colors.textTertiary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
