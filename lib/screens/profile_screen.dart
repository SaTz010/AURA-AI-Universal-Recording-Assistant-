import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../providers/auth_provider.dart';
import '../services/summaries_library_events.dart';
import '../services/summaries_storage.dart';
import '../theme/aura_theme.dart';
import '../theme/aura_tokens.dart';
import 'widgets/total_recorded_stat.dart';
import 'widgets/total_summaries_stat.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key, this.onSelectTab});

  final ValueChanged<int>? onSelectTab;

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
            _HighlightCard(joinedAt: user?.metadata.creationTime?.toLocal()),
            const SizedBox(height: AuraSpacing.xl),
            const _SectionHeader(title: 'Recordings'),
            const SizedBox(height: AuraSpacing.sm),
            RecordingTotalsCards(
              onTap: onSelectTab == null ? null : () => onSelectTab!(1),
            ),
            const SizedBox(height: AuraSpacing.xl),
            const _SectionHeader(title: 'Summary'),
            const SizedBox(height: AuraSpacing.sm),
            SummaryTotalsCard(
              onTap: onSelectTab == null ? null : () => onSelectTab!(2),
            ),
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

    final joinedText = joinedAt == null
        ? 'Welcome to AURA'
        : 'Member since ${_formatJoined(joinedAt!)}';

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: AuraRadius.lgBr,
        border: Border.all(color: colors.border),
      ),
      padding: const EdgeInsets.symmetric(
        horizontal: AuraSpacing.xl,
        vertical: AuraSpacing.xl,
      ),
      child: Column(
        children: [
          CircleAvatar(
            radius: 32,
            backgroundColor: colors.surfaceElevated,
            backgroundImage:
                (photoUrl != null && photoUrl!.isNotEmpty) ? NetworkImage(photoUrl!) : null,
            child: (photoUrl == null || photoUrl!.isEmpty)
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
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: AuraTypography.titleLarge(colors.textPrimary).copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            email,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: AuraTypography.bodyMedium(colors.textSecondary),
          ),
          const SizedBox(height: 6),
          Text(
            joinedText,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: AuraTypography.caption(colors.textTertiary),
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

    return Text(
      title,
      style: AuraTypography.titleMedium(colors.textPrimary).copyWith(
        fontWeight: FontWeight.w800,
      ),
    );
  }
}

class _HighlightCard extends StatefulWidget {
  const _HighlightCard({required this.joinedAt});

  final DateTime? joinedAt;

  @override
  State<_HighlightCard> createState() => _HighlightCardState();
}

class _HighlightCardState extends State<_HighlightCard> {
  String? _effectiveUid;
  bool _hasInit = false;
  bool _isLoading = true;
  int _thisMonthCount = 0;

  late final VoidCallback _summariesListener;

  @override
  void initState() {
    super.initState();
    _summariesListener = () {
      if (!mounted) return;
      unawaited(_load());
    };
    SummariesLibraryEvents.revision.addListener(_summariesListener);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final auth = AuraAuthProvider.of(context);
    if (!auth.initialized) return;
    final nextUid = auth.isGuest ? null : auth.user?.uid;
    if (_hasInit && nextUid == _effectiveUid) return;
    _effectiveUid = nextUid;
    _hasInit = true;
    unawaited(_load());
  }

  @override
  void dispose() {
    SummariesLibraryEvents.revision.removeListener(_summariesListener);
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final items = await SummariesStorage.load(_effectiveUid);
      final now = DateTime.now();
      var count = 0;
      for (final s in items) {
        final dt = DateTime.fromMillisecondsSinceEpoch(s.createdAtMs);
        if (dt.year == now.year && dt.month == now.month) count++;
      }
      if (!mounted) return;
      setState(() {
        _thisMonthCount = count;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _thisMonthCount = 0;
        _isLoading = false;
      });
    }
  }

  String _formatJoined(DateTime dt) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${months[dt.month - 1]} ${dt.day}, ${dt.year}';
  }

  @override
  Widget build(BuildContext context) {
    final colors = AuraThemeColors.of(context);

    final headline = _isLoading
        ? '…'
        : _thisMonthCount == 0
            ? 'No summaries this month yet'
            : _thisMonthCount == 1
                ? '1 summary this month'
                : '$_thisMonthCount summaries this month';

    final subline = widget.joinedAt == null
        ? 'Welcome — record your first audio to get started'
        : 'Member since ${_formatJoined(widget.joinedAt!)}';

    return Container(
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: AuraRadius.lgBr,
        border: Border.all(color: colors.border),
      ),
      padding: const EdgeInsets.all(AuraSpacing.lg),
      child: Row(
        children: [
          Icon(Icons.auto_awesome_rounded, color: colors.accent, size: 22),
          const SizedBox(width: AuraSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  headline,
                  style: AuraTypography.bodyLarge(colors.textPrimary).copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  subline,
                  style: AuraTypography.caption(colors.textSecondary),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
