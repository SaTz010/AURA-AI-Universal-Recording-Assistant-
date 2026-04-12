import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../theme/aura_theme.dart';
import '../../theme/aura_tokens.dart';

class DashboardLowerContent extends StatelessWidget {
  const DashboardLowerContent({
    super.key,
    this.onUploadFile,
    this.onRecordMeeting,
    this.onVoiceMemo,
    this.onCloudImport,
    this.onRecentTapped,
  });

  final VoidCallback? onUploadFile;
  final VoidCallback? onRecordMeeting;
  final VoidCallback? onVoiceMemo;
  final VoidCallback? onCloudImport;
  final ValueChanged<String>? onRecentTapped;

  @override
  Widget build(BuildContext context) {
    final colors = AuraThemeColors.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionHeader(title: 'Quick Actions'),
        const SizedBox(height: AuraSpacing.sm),
        _QuickActionsGrid(
          onUploadAudio: onUploadFile,
          onTbdAction: null,
        ),
        const SizedBox(height: AuraSpacing.xl),
        _SectionHeader(title: 'Recent'),
        const SizedBox(height: AuraSpacing.sm),
        _RecentRecordingsList(
          items: const [
            _RecentRecordingItemData(
              title: 'Product Team Sync',
              subtitle: 'Today, 10:00 AM',
              duration: '15:42',
              icon: Icons.play_circle_filled_rounded,
            ),
            _RecentRecordingItemData(
              title: 'Interview Notes',
              subtitle: 'Yesterday, 5:12 PM',
              duration: '08:07',
              icon: Icons.graphic_eq_rounded,
            ),
            _RecentRecordingItemData(
              title: 'Voice Memo – Ideas',
              subtitle: 'Mon, 9:20 AM',
              duration: '03:18',
              icon: Icons.multitrack_audio_rounded,
            ),
          ],
          onTap: onRecentTapped,
        ),
        const SizedBox(height: AuraSpacing.xl),
        _StorageAndStatsCard(
          title: 'Weekly Recording',
          value: '2.5 Hours',
          progressValue: 0.62,
          progressLabel: 'Storage used',
          accent: colors.accent,
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
      style: AuraTypography.overline(colors.textSecondary).copyWith(
        letterSpacing: 1.4,
      ),
    );
  }
}

class _RecentRecordingItemData {
  const _RecentRecordingItemData({
    required this.title,
    required this.subtitle,
    required this.duration,
    required this.icon,
  });

  final String title;
  final String subtitle;
  final String duration;
  final IconData icon;
}

class _RecentRecordingsList extends StatelessWidget {
  const _RecentRecordingsList({required this.items, this.onTap});

  final List<_RecentRecordingItemData> items;
  final ValueChanged<String>? onTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (int i = 0; i < items.length; i++) ...[
          _RecentRecordingTile(
            data: items[i],
            onTap: () {
              HapticFeedback.lightImpact();
              onTap?.call(items[i].title);
            },
          ),
          if (i != items.length - 1) const SizedBox(height: AuraSpacing.sm),
        ],
      ],
    );
  }
}

class _RecentRecordingTile extends StatelessWidget {
  const _RecentRecordingTile({required this.data, this.onTap});

  final _RecentRecordingItemData data;
  final VoidCallback? onTap;

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
      child: Material(
        color: Colors.transparent,
        borderRadius: AuraRadius.mdBr,
        child: InkWell(
          borderRadius: AuraRadius.mdBr,
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(AuraSpacing.md),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: colors.surfaceElevated,
                    border: Border.all(color: colors.border),
                  ),
                  child: Icon(data.icon, color: colors.accent, size: 26),
                ),
                const SizedBox(width: AuraSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        data.title,
                        style: AuraTypography.bodyLarge(colors.textPrimary).copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: AuraSpacing.xxs),
                      Text(
                        data.subtitle,
                        style: AuraTypography.caption(colors.textSecondary),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: AuraSpacing.md),
                Text(
                  data.duration,
                  style: AuraTypography.caption(colors.textSecondary).copyWith(
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _QuickActionsGrid extends StatelessWidget {
  const _QuickActionsGrid({
    this.onUploadAudio,
    this.onTbdAction,
  });

  final VoidCallback? onUploadAudio;
  final VoidCallback? onTbdAction;

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      mainAxisSpacing: AuraSpacing.sm,
      crossAxisSpacing: AuraSpacing.sm,
      physics: const NeverScrollableScrollPhysics(),
      childAspectRatio: 2.35,
      children: [
        _ActionCard(
          icon: Icons.file_upload_outlined,
          label: 'Upload Audio',
          onTap: onUploadAudio,
          dense: true,
        ),
        _ActionCard(
          icon: Icons.summarize_rounded,
          label: 'Summarize',
          onTap: onTbdAction,
          dense: true,
        ),
      ],
    );
  }
}

class _ActionCard extends StatelessWidget {
  const _ActionCard({
    required this.icon,
    required this.label,
    this.onTap,
    this.dense = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final bool dense;

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
      child: Material(
        color: Colors.transparent,
        borderRadius: AuraRadius.mdBr,
        child: InkWell(
          borderRadius: AuraRadius.mdBr,
          onTap: () {
            HapticFeedback.lightImpact();
            onTap?.call();
          },
          child: Padding(
            padding: EdgeInsets.all(dense ? AuraSpacing.sm : AuraSpacing.md),
            child: Row(
              children: [
                Container(
                  width: dense ? 34 : 38,
                  height: dense ? 34 : 38,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: colors.surfaceElevated,
                    border: Border.all(color: colors.border),
                  ),
                  child: Icon(icon, color: colors.iconDefault, size: dense ? 18 : 20),
                ),
                SizedBox(width: dense ? AuraSpacing.sm : AuraSpacing.md),
                Expanded(
                  child: Text(
                    label,
                    style: AuraTypography.bodyMedium(colors.textPrimary).copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _StorageAndStatsCard extends StatelessWidget {
  const _StorageAndStatsCard({
    required this.title,
    required this.value,
    required this.progressValue,
    required this.progressLabel,
    required this.accent,
  });

  final String title;
  final String value;
  final double progressValue;
  final String progressLabel;
  final Color accent;

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
      child: Padding(
        padding: const EdgeInsets.all(AuraSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: AuraTypography.bodyMedium(colors.textSecondary),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Text(
                  value,
                  style: AuraTypography.titleMedium(colors.textPrimary).copyWith(
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ],
            ),
            const SizedBox(height: AuraSpacing.md),
            ClipRRect(
              borderRadius: AuraRadius.fullBr,
              child: LinearProgressIndicator(
                minHeight: 6,
                value: progressValue.clamp(0.0, 1.0),
                backgroundColor: colors.surfaceElevated,
                valueColor: AlwaysStoppedAnimation<Color>(accent),
              ),
            ),
            const SizedBox(height: AuraSpacing.xs),
            Text(
              progressLabel,
              style: AuraTypography.caption(colors.textTertiary),
            ),
          ],
        ),
      ),
    );
  }
}
