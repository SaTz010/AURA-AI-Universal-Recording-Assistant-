import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../providers/auth_provider.dart';
import '../theme/aura_theme.dart';
import '../theme/aura_tokens.dart';
import '../theme/theme_provider.dart';
import '../widgets/aura_snack_bar.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = AuraThemeColors.of(context);
    final themeNotifier = AuraThemeProvider.of(context);
    final authProvider = AuraAuthProvider.of(context);

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        scrolledUnderElevation: 0,
        elevation: 0,
        leading: _BackButton(),
        title: Text(
          'Settings',
          style: AuraTypography.titleLarge(colors.textPrimary),
        ),
        centerTitle: false,
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(
          horizontal: AuraSpacing.base,
          vertical: AuraSpacing.xl,
        ),
        children: [
          _SectionHeader(title: 'Appearance'),
          const SizedBox(height: AuraSpacing.sm),
          _SettingsCard(
            children: [
              _ThemeOptionTile(
                title: 'Dark Mode',
                subtitle: 'Deep space dark theme',
                icon: Icons.dark_mode_rounded,
                isSelected: themeNotifier.themeMode == ThemeMode.dark,
                onTap: () {
                  HapticFeedback.selectionClick();
                  themeNotifier.setThemeMode(ThemeMode.dark);
                },
              ),
              Divider(height: 1, color: colors.border),
              _ThemeOptionTile(
                title: 'Light Mode',
                subtitle: 'Clean bright interface',
                icon: Icons.light_mode_rounded,
                isSelected: themeNotifier.themeMode == ThemeMode.light,
                onTap: () {
                  HapticFeedback.selectionClick();
                  themeNotifier.setThemeMode(ThemeMode.light);
                },
              ),
            ],
          ),
          const SizedBox(height: AuraSpacing.xxl),
          _SectionHeader(title: 'General'),
          const SizedBox(height: AuraSpacing.sm),
          _SettingsCard(
            children: [
              _SettingsTile(
                icon: Icons.notifications_rounded,
                title: 'Notifications',
                trailing: Icon(
                  Icons.chevron_right_rounded,
                  color: colors.textTertiary,
                ),
                onTap: () {
                  HapticFeedback.lightImpact();
                  Navigator.of(context).pushNamed('/settings/notifications');
                },
              ),
              Divider(height: 1, color: colors.border),
              _SettingsTile(
                icon: Icons.storage_rounded,
                title: 'Storage',
                trailing: Icon(
                  Icons.chevron_right_rounded,
                  color: colors.textTertiary,
                ),
                onTap: () {
                  HapticFeedback.lightImpact();
                  Navigator.of(context).pushNamed('/settings/storage');
                },
              ),
            ],
          ),
          const SizedBox(height: AuraSpacing.xxl),
          _SectionHeader(title: 'Terms & Policies'),
          const SizedBox(height: AuraSpacing.sm),
          _SettingsCard(
            children: [
              _SettingsTile(
                icon: Icons.privacy_tip_rounded,
                title: 'Privacy Policy',
                trailing: Icon(
                  Icons.chevron_right_rounded,
                  color: colors.textTertiary,
                ),
                onTap: () {
                  HapticFeedback.lightImpact();
                  Navigator.of(context).pushNamed('/privacy');
                },
              ),
              Divider(height: 1, color: colors.border),
              _SettingsTile(
                icon: Icons.article_rounded,
                title: 'Terms & Conditions',
                trailing: Icon(
                  Icons.chevron_right_rounded,
                  color: colors.textTertiary,
                ),
                onTap: () {
                  HapticFeedback.lightImpact();
                  Navigator.of(context).pushNamed('/terms');
                },
              ),
            ],
          ),
          const SizedBox(height: AuraSpacing.xxl),
          _SectionHeader(title: 'Customer Support'),
          const SizedBox(height: AuraSpacing.sm),
          _SettingsCard(
            children: [
              _SettingsTile(
                icon: Icons.support_agent_rounded,
                title: '+977 9841234567',
                trailing: Icon(
                  Icons.copy_rounded,
                  size: 18,
                  color: colors.textTertiary,
                ),
                onTap: () {
                  HapticFeedback.lightImpact();
                  Clipboard.setData(
                    const ClipboardData(text: '+977 9841234567'),
                  );
                  showAuraSnackBar(
                    context,
                    message: 'Phone number copied to clipboard',
                    duration: auraBriefSnackBarDuration,
                  );
                },
              ),
            ],
          ),
          if (!authProvider.isGuest) ...[
            const SizedBox(height: AuraSpacing.xxl),
            _SectionHeader(title: 'Account'),
            const SizedBox(height: AuraSpacing.sm),
            _SettingsCard(
              children: [
                _SettingsTile(
                  icon: Icons.logout_rounded,
                  title: 'Logout',
                  isDestructive: true,
                  onTap: () async {
                    HapticFeedback.mediumImpact();
                    final shouldLogout = await showDialog<bool>(
                      context: context,
                      builder: (dialogContext) {
                        return AlertDialog(
                          title: const Text('Logout'),
                          content: const Text(
                            'Are you sure you want to log out?',
                          ),
                          actions: [
                            TextButton(
                              onPressed: () =>
                                  Navigator.of(dialogContext).pop(false),
                              child: const Text('Cancel'),
                            ),
                            TextButton(
                              onPressed: () =>
                                  Navigator.of(dialogContext).pop(true),
                              child: const Text('Logout'),
                            ),
                          ],
                        );
                      },
                    );

                    if (shouldLogout == true && context.mounted) {
                      await authProvider.signOut();
                      if (!context.mounted) return;
                      Navigator.of(
                        context,
                      ).pushNamedAndRemoveUntil('/auth', (route) => false);
                    }
                  },
                ),
              ],
            ),
          ],
          const SizedBox(height: AuraSpacing.xxl),
          Center(
            child: Text(
              'Version 1.0.0',
              style: AuraTypography.caption(colors.textTertiary),
            ),
          ),
          const SizedBox(height: AuraSpacing.lg),
        ],
      ),
    );
  }
}

class _BackButton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final colors = AuraThemeColors.of(context);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: AuraRadius.smBr,
        onTap: () {
          HapticFeedback.lightImpact();
          Navigator.pop(context);
        },
        child: Padding(
          padding: const EdgeInsets.all(AuraSpacing.sm),
          child: Icon(Icons.arrow_back_rounded, color: colors.iconDefault),
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    final colors = AuraThemeColors.of(context);
    return Padding(
      padding: const EdgeInsets.only(left: AuraSpacing.xs),
      child: Text(
        title.toUpperCase(),
        style: AuraTypography.overline(
          colors.textTertiary,
        ).copyWith(fontWeight: FontWeight.w600, letterSpacing: 1.5),
      ),
    );
  }
}

class _SettingsCard extends StatelessWidget {
  final List<Widget> children;
  const _SettingsCard({required this.children});

  @override
  Widget build(BuildContext context) {
    final colors = AuraThemeColors.of(context);
    return Container(
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: AuraRadius.mdBr,
        border: Border.all(color: colors.border),
        boxShadow: AuraElevation.low(Colors.black),
      ),
      child: ClipRRect(
        borderRadius: AuraRadius.mdBr,
        child: Column(children: children),
      ),
    );
  }
}

class _ThemeOptionTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  const _ThemeOptionTile({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = AuraThemeColors.of(context);
    return Material(
      color: isSelected ? colors.shimmer : Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AuraSpacing.base,
            vertical: AuraSpacing.md,
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: isSelected
                      ? colors.accent.withValues(alpha: 0.15)
                      : colors.surfaceElevated,
                  borderRadius: AuraRadius.smBr,
                ),
                child: Icon(
                  icon,
                  size: 20,
                  color: isSelected ? colors.accent : colors.textTertiary,
                ),
              ),
              const SizedBox(width: AuraSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: AuraTypography.bodyLarge(colors.textPrimary),
                    ),
                    const SizedBox(height: AuraSpacing.xxs),
                    Text(
                      subtitle,
                      style: AuraTypography.caption(colors.textSecondary),
                    ),
                  ],
                ),
              ),
              AnimatedContainer(
                duration: AuraMotion.fast,
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isSelected ? colors.accent : colors.textTertiary,
                    width: isSelected ? 6 : 1.5,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool isDestructive;

  const _SettingsTile({
    required this.icon,
    required this.title,
    this.trailing,
    this.onTap,
    this.isDestructive = false,
  });

  @override
  Widget build(BuildContext context) {
    final colors = AuraThemeColors.of(context);
    final destructiveColor = Theme.of(context).colorScheme.error;
    final iconColor = isDestructive ? destructiveColor : colors.textTertiary;
    final titleColor = isDestructive ? destructiveColor : colors.textPrimary;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AuraSpacing.base,
            vertical: AuraSpacing.md,
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: colors.surfaceElevated,
                  borderRadius: AuraRadius.smBr,
                ),
                child: Icon(icon, size: 20, color: iconColor),
              ),
              const SizedBox(width: AuraSpacing.md),
              Expanded(
                child: Text(title, style: AuraTypography.bodyLarge(titleColor)),
              ),
              trailing ?? const SizedBox.shrink(),
            ],
          ),
        ),
      ),
    );
  }
}
