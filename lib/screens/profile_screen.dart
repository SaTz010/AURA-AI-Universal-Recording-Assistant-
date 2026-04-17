import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../providers/auth_provider.dart';
import '../theme/aura_theme.dart';
import '../theme/aura_tokens.dart';
import 'widgets/total_recorded_stat.dart';
import 'widgets/total_summaries_stat.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final authProvider = AuraAuthProvider.of(context);
    final colors = AuraThemeColors.of(context);

    if (authProvider.isGuest) {
      return Scaffold(
        backgroundColor: colors.background,
        appBar: AppBar(
          backgroundColor: colors.background,
          elevation: 0,
          title: Text(
            'Profile',
            style: AuraTypography.titleLarge(colors.textPrimary),
          ),
          centerTitle: false,
          actions: [
            IconButton(
              onPressed: () {
                HapticFeedback.lightImpact();
                Navigator.pushNamed(context, '/settings');
              },
              icon: Icon(
                Icons.settings_rounded,
                color: colors.iconDefault,
              ),
            ),
          ],
        ),
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
        centerTitle: false,
        actions: [
          IconButton(
            onPressed: () {
              HapticFeedback.lightImpact();
              Navigator.pushNamed(context, '/settings');
            },
            icon: Icon(
              Icons.settings_rounded,
              color: colors.iconDefault,
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AuraSpacing.xl),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _ProfileHeader(
              name: name,
              email: email,
              joinedAt: user?.metadata.creationTime?.toLocal(),
              photoUrl: photoUrl,
            ),
            const SizedBox(height: AuraSpacing.xl),
            const _SectionHeader(title: 'Current plan'),
            const SizedBox(height: AuraSpacing.sm),
            const _ComingSoonCard(),
            const SizedBox(height: AuraSpacing.xl),
            const _SectionHeader(title: 'Recordings'),
            const SizedBox(height: AuraSpacing.sm),
            const RecordingTotalsCards(),
            const SizedBox(height: AuraSpacing.xl),
            const _SectionHeader(title: 'Summary'),
            const SizedBox(height: AuraSpacing.sm),
            const SummaryTotalsCard(),
          ],
        ),
      ),
    );
  }
}

class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader({
    required this.name,
    required this.email,
    required this.joinedAt,
    required this.photoUrl,
  });

  final String name;
  final String email;
  final DateTime? joinedAt;
  final String? photoUrl;

  String _formatJoined(DateTime dt) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];

    return '${months[dt.month - 1]} ${dt.day}, ${dt.year}';
  }

  @override
  Widget build(BuildContext context) {
    final colors = AuraThemeColors.of(context);

    final joinedText = joinedAt == null ? 'Joined: —' : 'Joined ${_formatJoined(joinedAt!)}';

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        CircleAvatar(
          radius: 34,
          backgroundColor: colors.surfaceElevated,
          backgroundImage: (photoUrl != null && photoUrl!.isNotEmpty) ? NetworkImage(photoUrl!) : null,
          child: (photoUrl == null || photoUrl!.isEmpty)
              ? Icon(
                  Icons.person_rounded,
                  size: 34,
                  color: colors.iconDefault,
                )
              : null,
        ),
        const SizedBox(width: AuraSpacing.lg),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                name,
                overflow: TextOverflow.ellipsis,
                style: AuraTypography.titleLarge(colors.textPrimary),
              ),
              const SizedBox(height: AuraSpacing.xxs),
              Text(
                email,
                overflow: TextOverflow.ellipsis,
                style: AuraTypography.bodyMedium(colors.textSecondary),
              ),
              const SizedBox(height: AuraSpacing.xxs),
              Text(
                joinedText,
                overflow: TextOverflow.ellipsis,
                style: AuraTypography.caption(colors.textTertiary),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    final colors = AuraThemeColors.of(context);

    return Text(
      title,
      style: AuraTypography.titleMedium(colors.textPrimary).copyWith(
        fontWeight: FontWeight.w800,
      ),
    );
  }
}

class _ComingSoonCard extends StatelessWidget {
  const _ComingSoonCard();

  @override
  Widget build(BuildContext context) {
    final colors = AuraThemeColors.of(context);

    return Container(
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: AuraRadius.lgBr,
        border: Border.all(color: colors.border),
      ),
      padding: const EdgeInsets.all(AuraSpacing.lg),
      child: Row(
        children: [
          Icon(Icons.auto_awesome_rounded, color: colors.accent),
          const SizedBox(width: AuraSpacing.md),
          Expanded(
            child: Text(
              'Coming soon',
              style: AuraTypography.bodyMedium(colors.textSecondary),
            ),
          ),
        ],
      ),
    );
  }
}
