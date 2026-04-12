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
    required this.durationText,
  });

  final String filePath;
  final String title;
  final String subtitle;

  // Nullable to avoid hot-reload state issues when this model changes.
  final String? durationText;
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

  late final AudioPlayer _audioPlayer;
  String? _expandedFilePath;
  String? _loadedFilePath;
  bool _isPreparing = false;
  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;

  @override
  void initState() {
    super.initState();
    _audioPlayer = AudioPlayer();
    _audioPlayer.durationStream.listen((duration) {
      if (!mounted) return;
      setState(() => _duration = duration ?? Duration.zero);
    });
    _audioPlayer.positionStream.listen((position) {
      if (!mounted) return;
      setState(() => _position = position);
    });
    _load();
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
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
              durationText: _formatDuration(duration),
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

  Future<void> _prepareFile(String filePath) async {
    if (_loadedFilePath == filePath) return;

    try {
      setState(() => _isPreparing = true);
      await _audioPlayer.setFilePath(filePath);
      if (!mounted) return;
      setState(() {
        _loadedFilePath = filePath;
        _isPreparing = false;
        _position = Duration.zero;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _isPreparing = false);
    }
  }

  Future<void> _toggleExpanded(String filePath) async {
    if (_expandedFilePath == filePath) {
      if (_loadedFilePath == filePath && _audioPlayer.playing) {
        await _audioPlayer.pause();
      }
      if (!mounted) return;
      setState(() => _expandedFilePath = null);
      return;
    }

    setState(() => _expandedFilePath = filePath);
    await _prepareFile(filePath);
  }

  Future<void> _playPause(String filePath) async {
    try {
      if (_loadedFilePath != filePath) {
        await _prepareFile(filePath);
      }

      if (_audioPlayer.playing) {
        await _audioPlayer.pause();
      } else {
        await _audioPlayer.play();
      }

      if (!mounted) return;
      setState(() {});
    } catch (_) {
      // ignore
    }
  }

  Future<void> _seekRelative(String filePath, Duration delta) async {
    if (_loadedFilePath != filePath) return;
    if (_duration == Duration.zero) return;

    final raw = _position + delta;
    final clamped = raw < Duration.zero
        ? Duration.zero
        : (raw > _duration ? _duration : raw);

    await _audioPlayer.seek(clamped);
  }

  Future<void> _deleteRecent(String filePath) async {
    try {
      if (_loadedFilePath == filePath) {
        await _audioPlayer.stop();
      }
      await File(filePath).delete();
      await _load();
      if (!mounted) return;
      setState(() {
        if (_expandedFilePath == filePath) _expandedFilePath = null;
        if (_loadedFilePath == filePath) _loadedFilePath = null;
      });
    } catch (_) {
      // ignore
    }
  }

  void _showDeleteDialog(AuraThemeColors colors, String title, String filePath) {
    showDialog<void>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: const Text('Delete Recording?'),
        content: Text('Are you sure you want to delete $title?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(dialogCtx);
              _deleteRecent(filePath);
            },
            child: Text(
              'Delete',
              style: TextStyle(
                color: colors.accent,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
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
          _RecentExpandableTile(
            colors: colors,
            data: _items[i],
            isExpanded: _expandedFilePath == _items[i].filePath,
            isActive: _loadedFilePath == _items[i].filePath,
            isPlaying: _loadedFilePath == _items[i].filePath && _audioPlayer.playing,
            isPreparing: _isPreparing && _loadedFilePath != _items[i].filePath,
            position: _loadedFilePath == _items[i].filePath ? _position : Duration.zero,
            duration: _loadedFilePath == _items[i].filePath ? _duration : Duration.zero,
            onToggle: () {
              HapticFeedback.selectionClick();
              _toggleExpanded(_items[i].filePath);
            },
            onOpenFull: widget.onFileTap == null
                ? null
                : () {
                    HapticFeedback.lightImpact();
                    widget.onFileTap?.call(_items[i].filePath);
                  },
            onPlayPause: () => _playPause(_items[i].filePath),
            onSeekToSeconds: (seconds) =>
                _audioPlayer.seek(Duration(seconds: seconds)),
            onSkipBack: () => _seekRelative(
              _items[i].filePath,
              const Duration(seconds: -15),
            ),
            onSkipForward: () => _seekRelative(
              _items[i].filePath,
              const Duration(seconds: 15),
            ),
            onDelete: () => _showDeleteDialog(
              colors,
              _items[i].title,
              _items[i].filePath,
            ),
          ),
          if (i != _items.length - 1) const SizedBox(height: AuraSpacing.sm),
        ],
      ],
    );
  }
}

class _RecentExpandableTile extends StatelessWidget {
  const _RecentExpandableTile({
    required this.colors,
    required this.data,
    required this.isExpanded,
    required this.isActive,
    required this.isPlaying,
    required this.isPreparing,
    required this.position,
    required this.duration,
    required this.onToggle,
    required this.onOpenFull,
    required this.onPlayPause,
    required this.onSeekToSeconds,
    required this.onSkipBack,
    required this.onSkipForward,
    required this.onDelete,
  });

  final AuraThemeColors colors;
  final _RecentRecordingPreviewData data;
  final bool isExpanded;
  final bool isActive;
  final bool isPlaying;
  final bool isPreparing;
  final Duration position;
  final Duration duration;
  final VoidCallback onToggle;
  final VoidCallback? onOpenFull;
  final VoidCallback onPlayPause;
  final ValueChanged<int> onSeekToSeconds;
  final VoidCallback onSkipBack;
  final VoidCallback onSkipForward;
  final VoidCallback onDelete;

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    final canSeek = isActive && duration.inMilliseconds > 0;
    final maxSeconds = duration.inSeconds <= 0 ? 1 : duration.inSeconds;
    final valueSeconds = canSeek
        ? position.inSeconds.clamp(0, maxSeconds).toDouble()
        : 0.0;

    final remainingRaw = duration - position;
    final remaining = remainingRaw.isNegative ? Duration.zero : remainingRaw;

    const skipIconSize = 30.0;

    final skipLabelStyle = AuraTypography.caption(colors.iconDefault).copyWith(
      fontSize: 10,
      fontWeight: FontWeight.w800,
      height: 1,
    );

    Widget skipIcon(IconData baseIcon) {
      return SizedBox.square(
        dimension: skipIconSize,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Icon(baseIcon, size: skipIconSize, color: colors.iconDefault),
            Positioned(
              bottom: skipIconSize * 0.20,
              child: Text('15', style: skipLabelStyle),
            ),
          ],
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: AuraRadius.mdBr,
        border: Border.all(color: colors.border),
        boxShadow: AuraElevation.low(Colors.black),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: AuraRadius.mdBr,
              onTap: onToggle,
              onLongPress: onOpenFull,
              child: Padding(
                padding: const EdgeInsets.all(AuraSpacing.md),
                child: Row(
                  children: [
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
                      data.durationText ?? '--:--',
                      style: AuraTypography.caption(colors.textSecondary).copyWith(
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          AnimatedSize(
            duration: AuraMotion.fast,
            curve: AuraMotion.standard,
            child: isExpanded
                ? Padding(
                    padding: const EdgeInsets.fromLTRB(
                      AuraSpacing.md,
                      0,
                      AuraSpacing.md,
                      AuraSpacing.md,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Container(height: 1, color: colors.border),
                        const SizedBox(height: AuraSpacing.sm),
                        if (isPreparing) ...[
                          LinearProgressIndicator(
                            minHeight: 2,
                            color: colors.accent,
                            backgroundColor: colors.border,
                          ),
                          const SizedBox(height: AuraSpacing.sm),
                        ],
                        SliderTheme(
                          data: SliderTheme.of(context).copyWith(
                            trackHeight: 3,
                            activeTrackColor: colors.accent,
                            inactiveTrackColor: colors.border,
                            thumbColor: colors.accent,
                            overlayColor: colors.accent.withValues(alpha: 0.12),
                          ),
                          child: Slider(
                            value: valueSeconds,
                            max: maxSeconds.toDouble(),
                            onChanged: canSeek ? (v) => onSeekToSeconds(v.toInt()) : null,
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: AuraSpacing.sm),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                _formatDuration(canSeek ? position : Duration.zero),
                                style: AuraTypography.caption(colors.textSecondary),
                              ),
                              Text(
                                canSeek ? '-${_formatDuration(remaining)}' : '--:--',
                                style: AuraTypography.caption(colors.textSecondary),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: AuraSpacing.sm),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Icon(Icons.graphic_eq_rounded, color: colors.accent, size: 28),
                            IconButton(
                              onPressed: canSeek ? onSkipBack : null,
                              icon: skipIcon(Icons.replay_rounded),
                              iconSize: 30,
                              tooltip: 'Back 15s',
                            ),
                            IconButton(
                              onPressed: onPlayPause,
                              icon: Icon(
                                isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                                color: colors.textPrimary,
                              ),
                              iconSize: 46,
                              tooltip: 'Play / Pause',
                            ),
                            IconButton(
                              onPressed: canSeek ? onSkipForward : null,
                              icon: skipIcon(Icons.forward_rounded),
                              iconSize: 30,
                              tooltip: 'Forward 15s',
                            ),
                            IconButton(
                              onPressed: onDelete,
                              icon: Icon(Icons.delete_outline_rounded, color: colors.accent),
                              iconSize: 30,
                              tooltip: 'Delete',
                            ),
                          ],
                        ),
                      ],
                    ),
                  )
                : const SizedBox.shrink(),
          ),
        ],
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

