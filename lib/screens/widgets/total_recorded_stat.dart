import 'dart:io';

import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:path_provider/path_provider.dart';

import '../../theme/aura_theme.dart';
import '../../theme/aura_tokens.dart';

class RecordingTotalsCards extends StatefulWidget {
  const RecordingTotalsCards({super.key});

  @override
  State<RecordingTotalsCards> createState() => _RecordingTotalsCardsState();
}

class _RecordingTotalsCardsState extends State<RecordingTotalsCards> {
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

    final totalTimeText = _isLoading
        ? '—'
        : (_durationsResolved == 0 && _recordingsCount > 0)
            ? '--'
            : _formatTotal(_totalRecorded);

    final countText = _isLoading ? '—' : _recordingsCount.toString();

    final meta = _isLoading
        ? 'Calculating…'
        : _recordingsCount == 0
            ? 'No recordings yet'
            : (_latestTimestamp == null)
                ? '$_recordingsCount recordings'
                : 'Last recorded: ${_formatRelativeDateTime(_latestTimestamp!, DateTime.now())}';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: _MiniStatCard(
                icon: Icons.timer_rounded,
                label: 'Total time',
                value: totalTimeText,
              ),
            ),
            const SizedBox(width: AuraSpacing.sm),
            Expanded(
              child: _MiniStatCard(
                icon: Icons.multitrack_audio_rounded,
                label: 'Recordings',
                value: countText,
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
    );
  }
}

class _MiniStatCard extends StatelessWidget {
  const _MiniStatCard({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final colors = AuraThemeColors.of(context);

    return Container(
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: AuraRadius.lgBr,
        border: Border.all(color: colors.border),
        boxShadow: AuraElevation.low(Colors.black),
      ),
      padding: const EdgeInsets.all(AuraSpacing.md),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: colors.surfaceElevated,
              border: Border.all(color: colors.border),
            ),
            child: Icon(icon, size: 18, color: colors.accent),
          ),
          const SizedBox(width: AuraSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: AuraTypography.caption(colors.textSecondary),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: AuraTypography.titleMedium(colors.textPrimary).copyWith(
                    fontFeatures: const [FontFeature.tabularFigures()],
                    fontWeight: FontWeight.w700,
                  ),
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
