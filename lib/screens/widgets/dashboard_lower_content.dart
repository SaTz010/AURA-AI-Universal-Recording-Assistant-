import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:just_audio/just_audio.dart';
import 'package:path_provider/path_provider.dart';

import '../../theme/aura_theme.dart';
import '../../theme/aura_tokens.dart';

class DashboardLowerContent extends StatelessWidget {
  const DashboardLowerContent({
    super.key,
    this.onUploadAudio,
    this.onSummarize,
    this.onViewAllRecent,
    this.onRecentFileTap,
  });

  final VoidCallback? onUploadAudio;
  final VoidCallback? onSummarize;
  final VoidCallback? onViewAllRecent;
  final ValueChanged<String>? onRecentFileTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionHeaderRow(
          title: 'Recent',
          actionLabel: 'View all',
          onActionTap: onViewAllRecent,
        ),
        const SizedBox(height: AuraSpacing.sm),
        _RecentRecordingsPreview(
          onFileTap: onRecentFileTap,
        ),
        const SizedBox(height: AuraSpacing.xl),
        const _SectionHeader(title: 'Quick Actions'),
        const SizedBox(height: AuraSpacing.sm),
        _QuickActionsGrid(
          onUploadAudio: onUploadAudio,
          onSummarize: onSummarize,
        ),
        const SizedBox(height: AuraSpacing.xl),
        const _TotalRecordedCard(),
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

class _SectionHeaderRow extends StatelessWidget {
  const _SectionHeaderRow({
    required this.title,
    required this.actionLabel,
    this.onActionTap,
  });

  final String title;
  final String actionLabel;
  final VoidCallback? onActionTap;

  @override
  Widget build(BuildContext context) {
    final colors = AuraThemeColors.of(context);

    return Row(
      children: [
        Expanded(child: _SectionHeader(title: title)),
        Material(
          color: Colors.transparent,
          borderRadius: AuraRadius.fullBr,
          child: InkWell(
            borderRadius: AuraRadius.fullBr,
            onTap: onActionTap == null
                ? null
                : () {
                    HapticFeedback.lightImpact();
                    onActionTap?.call();
                  },
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AuraSpacing.sm,
                vertical: AuraSpacing.xs,
              ),
              child: Row(
                children: [
                  Text(
                    actionLabel,
                    style: AuraTypography.labelSmall(colors.accent),
                  ),
                  const SizedBox(width: AuraSpacing.xxs),
                  Icon(
                    Icons.chevron_right_rounded,
                    size: 18,
                    color: colors.accent,
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _RecentRecordingPreviewData {
  const _RecentRecordingPreviewData({
    required this.filePath,
    required this.title,
    required this.subtitle,
    required this.duration,
    required this.icon,
  });

  final String filePath;
  final String title;
  final String subtitle;
  final String duration;
  final IconData icon;
}

class _RecentRecordingsPreview extends StatefulWidget {
  const _RecentRecordingsPreview({this.onFileTap});

  final ValueChanged<String>? onFileTap;

  @override
  State<_RecentRecordingsPreview> createState() => _RecentRecordingsPreviewState();
}

class _RecentRecordingsPreviewState extends State<_RecentRecordingsPreview> {
  bool _isLoading = true;
  List<_RecentRecordingPreviewData> _items = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final entities = dir.listSync();
      final recordingFiles = entities.where((e) => e.path.toLowerCase().endsWith('.m4a')).toList();
      recordingFiles.sort(
        (a, b) => File(b.path).lastModifiedSync().compareTo(File(a.path).lastModifiedSync()),
      );

      final previewFiles = recordingFiles.take(3).map((e) => File(e.path)).toList();
      final now = DateTime.now();

      final items = <_RecentRecordingPreviewData>[];
      final audioPlayer = AudioPlayer();
      try {
        for (final file in previewFiles) {
          final fileName = file.path.split(RegExp(r'[\\/]')).last;
          final title = _stripExtension(fileName);
          final modified = file.lastModifiedSync();

          Duration? duration;
          try {
            duration = await audioPlayer.setFilePath(file.path);
          } catch (_) {
            duration = null;
          }

          items.add(
            _RecentRecordingPreviewData(
              filePath: file.path,
              title: title,
              subtitle: _formatRelativeDateTime(modified, now),
              duration: _formatDuration(duration),
              icon: Icons.play_circle_filled_rounded,
            ),
          );
        }
      } finally {
        await audioPlayer.dispose();
      }

      if (!mounted) return;
      setState(() {
        _items = items;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _items = const [];
        _isLoading = false;
      });
    }
  }

  String _stripExtension(String fileName) {
    final dot = fileName.lastIndexOf('.');
    return dot == -1 ? fileName : fileName.substring(0, dot);
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  String _formatRelativeDateTime(DateTime dt, DateTime now) {
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));

    final dayLabel = _isSameDay(dt, today)
        ? 'Today'
        : _isSameDay(dt, yesterday)
            ? 'Yesterday'
            : now.difference(dt).inDays < 7
                ? const ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'][dt.weekday - 1]
                : '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';

    final hour12 = (dt.hour % 12) == 0 ? 12 : (dt.hour % 12);
    final minute = dt.minute.toString().padLeft(2, '0');
    final suffix = dt.hour >= 12 ? 'PM' : 'AM';

    return '$dayLabel, $hour12:$minute $suffix';
  }

  String _formatDuration(Duration? duration) {
    if (duration == null) return '--:--';

    final totalSeconds = duration.inSeconds;
    final seconds = (totalSeconds % 60).toString().padLeft(2, '0');
    final totalMinutes = duration.inMinutes;

    if (totalMinutes >= 60) {
      final hours = duration.inHours;
      final minutes = (totalMinutes % 60).toString().padLeft(2, '0');
      return '$hours:$minutes:$seconds';
    }

    final minutes = totalMinutes.toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    final colors = AuraThemeColors.of(context);

    if (_isLoading) {
      return Container(
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: AuraRadius.mdBr,
          border: Border.all(color: colors.border),
          boxShadow: AuraElevation.low(Colors.black),
        ),
        padding: const EdgeInsets.all(AuraSpacing.md),
        child: Row(
          children: [
            SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: colors.accent,
              ),
            ),
            const SizedBox(width: AuraSpacing.md),
            Expanded(
              child: Text(
                'Loading recent recordings…',
                style: AuraTypography.bodyMedium(colors.textSecondary),
              ),
            ),
          ],
        ),
      );
    }

    if (_items.isEmpty) {
      return Container(
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: AuraRadius.mdBr,
          border: Border.all(color: colors.border),
          boxShadow: AuraElevation.low(Colors.black),
        ),
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
              child: Icon(Icons.mic_rounded, color: colors.iconDefault, size: 22),
            ),
            const SizedBox(width: AuraSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'No recordings yet',
                    style: AuraTypography.bodyLarge(colors.textPrimary).copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: AuraSpacing.xxs),
                  Text(
                    'Start recording to see your latest files here.',
                    style: AuraTypography.caption(colors.textSecondary),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        for (int i = 0; i < _items.length; i++) ...[
          _RecentRecordingTile(
            data: _items[i],
            onTap: widget.onFileTap == null
                ? null
                : () {
                    HapticFeedback.lightImpact();
                    widget.onFileTap?.call(_items[i].filePath);
                  },
          ),
          if (i != _items.length - 1) const SizedBox(height: AuraSpacing.sm),
        ],
      ],
    );
  }
}

class _RecentRecordingTile extends StatelessWidget {
  const _RecentRecordingTile({required this.data, this.onTap});

  final _RecentRecordingPreviewData data;
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
    this.onSummarize,
  });

  final VoidCallback? onUploadAudio;
  final VoidCallback? onSummarize;

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
          onTap: onSummarize,
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
          onTap: onTap == null
              ? null
              : () {
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

class _TotalRecordedCard extends StatefulWidget {
  const _TotalRecordedCard();

  @override
  State<_TotalRecordedCard> createState() => _TotalRecordedCardState();
}

class _TotalRecordedCardState extends State<_TotalRecordedCard> {
  bool _isLoading = true;
  int _recordingsCount = 0;
  int _durationsResolved = 0;
  Duration _totalRecorded = Duration.zero;
  DateTime? _latestTimestamp;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final entities = dir.listSync();
      final files = entities
          .where((e) => e.path.toLowerCase().endsWith('.m4a'))
          .map((e) => File(e.path))
          .toList();

      final audioPlayer = AudioPlayer();
      var total = Duration.zero;
      var resolved = 0;
      DateTime? latest;

      try {
        for (final file in files) {
          final modified = file.lastModifiedSync();
          if (latest == null || modified.isAfter(latest)) {
            latest = modified;
          }

          try {
            final d = await audioPlayer.setFilePath(file.path);
            if (d != null) {
              total += d;
              resolved++;
            }
          } catch (_) {
            // ignore individual decode errors
          }
        }
      } finally {
        await audioPlayer.dispose();
      }

      if (!mounted) return;
      setState(() {
        _recordingsCount = files.length;
        _durationsResolved = resolved;
        _totalRecorded = total;
        _latestTimestamp = latest;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _recordingsCount = 0;
        _durationsResolved = 0;
        _totalRecorded = Duration.zero;
        _latestTimestamp = null;
        _isLoading = false;
      });
    }
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  String _formatRelativeDateTime(DateTime dt, DateTime now) {
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));

    final dayLabel = _isSameDay(dt, today)
        ? 'Today'
        : _isSameDay(dt, yesterday)
            ? 'Yesterday'
            : now.difference(dt).inDays < 7
                ? const ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'][dt.weekday - 1]
                : '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';

    final hour12 = (dt.hour % 12) == 0 ? 12 : (dt.hour % 12);
    final minute = dt.minute.toString().padLeft(2, '0');
    final suffix = dt.hour >= 12 ? 'PM' : 'AM';

    return '$dayLabel, $hour12:$minute $suffix';
  }

  String _formatTotal(Duration d) {
    if (d == Duration.zero) return '0m';

    final totalMinutes = d.inMinutes;
    if (totalMinutes < 60) {
      return '${totalMinutes}m';
    }

    final hours = d.inHours;
    final minutes = totalMinutes % 60;
    return '${hours}h ${minutes}m';
  }

  @override
  Widget build(BuildContext context) {
    final colors = AuraThemeColors.of(context);

    final title = Text(
      'Total Recorded',
      style: AuraTypography.bodyMedium(colors.textSecondary),
      overflow: TextOverflow.ellipsis,
    );

    final valueText = _isLoading
        ? '—'
        : (_durationsResolved == 0 && _recordingsCount > 0)
            ? '--'
            : _formatTotal(_totalRecorded);

    final meta = _isLoading
        ? 'Calculating…'
        : _recordingsCount == 0
            ? 'No recordings yet'
            : '$_recordingsCount recordings'
                '${_latestTimestamp == null ? '' : ' • Last: ${_formatRelativeDateTime(_latestTimestamp!, DateTime.now())}'}';

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
                Expanded(child: title),
                Icon(Icons.timer_rounded, color: colors.accent, size: 18),
                const SizedBox(width: AuraSpacing.xs),
                Text(
                  valueText,
                  style: AuraTypography.titleMedium(colors.textPrimary).copyWith(
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ],
            ),
            const SizedBox(height: AuraSpacing.xs),
            Text(
              meta,
              style: AuraTypography.caption(colors.textTertiary),
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}
