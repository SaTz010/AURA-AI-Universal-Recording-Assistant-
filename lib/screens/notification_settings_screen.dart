import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/notification_preferences.dart';
import '../theme/aura_theme.dart';
import '../theme/aura_tokens.dart';

class NotificationSettingsScreen extends StatefulWidget {
  const NotificationSettingsScreen({super.key});

  @override
  State<NotificationSettingsScreen> createState() =>
      _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState
    extends State<NotificationSettingsScreen> {
  final NotificationPreferences _prefs = NotificationPreferences.instance;

  @override
  void initState() {
    super.initState();
    _prefs.addListener(_onPrefsChanged);
  }

  @override
  void dispose() {
    _prefs.removeListener(_onPrefsChanged);
    super.dispose();
  }

  void _onPrefsChanged() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final colors = AuraThemeColors.of(context);

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        scrolledUnderElevation: 0,
        elevation: 0,
        leading: IconButton(
          onPressed: () {
            HapticFeedback.lightImpact();
            Navigator.of(context).pop();
          },
          icon: Icon(Icons.arrow_back_rounded, color: colors.iconDefault),
        ),
        title: Text(
          'Notifications',
          style: AuraTypography.titleLarge(colors.textPrimary),
        ),
        centerTitle: false,
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(
          horizontal: AuraSpacing.base,
          vertical: AuraSpacing.lg,
        ),
        children: [
          _SectionHeader(title: 'Preferences'),
          const SizedBox(height: AuraSpacing.sm),
          _Card(
            children: [
              _SwitchTile(
                icon: Icons.chat_bubble_outline_rounded,
                title: 'In-app alerts',
                subtitle: 'Confirmation snackbars and small toasts',
                value: _prefs.inAppAlerts,
                onChanged: (value) {
                  HapticFeedback.lightImpact();
                  _prefs.setInAppAlerts(value);
                },
              ),
              Divider(height: 1, color: colors.border),
              _SwitchTile(
                icon: Icons.vibration_rounded,
                title: 'Haptic feedback',
                subtitle: 'Subtle vibration on taps and actions',
                value: _prefs.haptics,
                onChanged: (value) {
                  if (value) HapticFeedback.lightImpact();
                  _prefs.setHaptics(value);
                },
              ),
            ],
          ),
          const SizedBox(height: AuraSpacing.xxl),
          _SectionHeader(title: 'System notifications'),
          const SizedBox(height: AuraSpacing.sm),
          _Card(
            children: [
              _InfoTile(
                icon: Icons.mic_rounded,
                title: 'Recording in background',
                body:
                    'AURA shows a system notification while a recording is in progress so the OS keeps capture alive. This is required by Android and cannot be disabled.',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    final colors = AuraThemeColors.of(context);
    return Padding(
      padding: const EdgeInsets.only(left: AuraSpacing.xs),
      child: Text(
        title.toUpperCase(),
        style: AuraTypography.overline(colors.textTertiary).copyWith(
          fontWeight: FontWeight.w600,
          letterSpacing: 1.5,
        ),
      ),
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final colors = AuraThemeColors.of(context);
    return Container(
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: AuraRadius.mdBr,
        border: Border.all(color: colors.border),
      ),
      child: ClipRRect(
        borderRadius: AuraRadius.mdBr,
        child: Column(children: children),
      ),
    );
  }
}

class _SwitchTile extends StatelessWidget {
  const _SwitchTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final colors = AuraThemeColors.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AuraSpacing.base,
        vertical: AuraSpacing.md,
      ),
      child: Row(
        children: [
          Icon(icon, size: 20, color: colors.iconDefault),
          const SizedBox(width: AuraSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: AuraTypography.bodyLarge(colors.textPrimary),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: AuraTypography.caption(colors.textSecondary),
                ),
              ],
            ),
          ),
          const SizedBox(width: AuraSpacing.sm),
          Switch(
            value: value,
            onChanged: onChanged,
            activeThumbColor: colors.accent,
          ),
        ],
      ),
    );
  }
}

class _InfoTile extends StatelessWidget {
  const _InfoTile({
    required this.icon,
    required this.title,
    required this.body,
  });

  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final colors = AuraThemeColors.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AuraSpacing.base,
        vertical: AuraSpacing.md,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: colors.iconDefault),
          const SizedBox(width: AuraSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AuraTypography.bodyLarge(colors.textPrimary),
                ),
                const SizedBox(height: AuraSpacing.xs),
                Text(
                  body,
                  style: AuraTypography.caption(colors.textSecondary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
