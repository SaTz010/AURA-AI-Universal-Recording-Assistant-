import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:just_audio/just_audio.dart';

import '../../providers/auth_provider.dart';
import '../../services/recordings_library_events.dart';
import '../../services/recordings_storage.dart';
import '../../theme/aura_theme.dart';
import '../../theme/aura_tokens.dart';
import 'aura_skeleton.dart';

class RecordingTotalsCards extends StatefulWidget {
  const RecordingTotalsCards({super.key, this.onTap});

  final VoidCallback? onTap;

  @override
  State<RecordingTotalsCards> createState() => _RecordingTotalsCardsState();
}

class _RecordingTotalsCardsState extends State<RecordingTotalsCards> {
  static final Map<String, _RecordingTotalsSnapshot> _cacheByUidKey = {};

  bool _isLoading = true;
  int _recordingsCount = 0;
  int _durationsResolved = 0;
  Duration _totalRecorded = Duration.zero;
  DateTime? _latestTimestamp;

  String? _effectiveUid;

  late final VoidCallback _revisionListener;

  @override
  void initState() {
    super.initState();

    _restoreFromCache();

    _revisionListener = () {
      if (!mounted) return;
      unawaited(_load(showLoading: false));
    };
    RecordingsLibraryEvents.revision.addListener(_revisionListener);

    unawaited(_loadIfStale());
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final authProvider = AuraAuthProvider.of(context);
    final nextUid = authProvider.isGuest ? null : authProvider.user?.uid;
    if (nextUid == _effectiveUid) return;
    _effectiveUid = nextUid;

    _restoreFromCache();
    unawaited(_loadIfStale());
  }

  @override
  void dispose() {
    RecordingsLibraryEvents.revision.removeListener(_revisionListener);
    super.dispose();
  }

  String _uidKey() {
    final normalized = _effectiveUid?.trim();
    return (normalized == null || normalized.isEmpty) ? '_guest' : normalized;
  }

  void _restoreFromCache() {
    final snapshot = _cacheByUidKey[_uidKey()];
    if (snapshot == null) return;

    if (!mounted) return;
    setState(() {
      _recordingsCount = snapshot.recordingsCount;
      _durationsResolved = snapshot.durationsResolved;
      _totalRecorded = snapshot.totalRecorded;
      _latestTimestamp = snapshot.latestTimestamp;
      _isLoading = false;
    });
  }

  Future<void> _loadIfStale() async {
    final key = _uidKey();
    final currentRevision = RecordingsLibraryEvents.revision.value;
    final cached = _cacheByUidKey[key];

    if (cached != null && cached.revision == currentRevision && cached.isValid) {
      if (_isLoading) {
        _restoreFromCache();
      }
      return;
    }

    final shouldShowLoading = cached == null;
    await _load(showLoading: shouldShowLoading);
  }

  Future<void> _load({required bool showLoading}) async {
    if (mounted && showLoading) {
      setState(() => _isLoading = true);
    }

    final start = DateTime.now();
    const minSkeletonDuration = Duration(milliseconds: 250);

    try {
      final dir = await RecordingsStorage.getUserRecordingsDir(_effectiveUid);
      final entities = dir.listSync();
      final files = entities
          .where((e) => e.path.toLowerCase().endsWith('.m4a'))
          .map((e) => File(e.path))
          .where((f) {
            final name = f.path.split(RegExp(r'[\\/]')).last.toLowerCase();
            return !name.startsWith('recording_');
          })
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

      if (showLoading) {
        final elapsed = DateTime.now().difference(start);
        if (elapsed < minSkeletonDuration) {
          await Future<void>.delayed(minSkeletonDuration - elapsed);
        }
      }

      if (!mounted) return;
      final revision = RecordingsLibraryEvents.revision.value;
      _cacheByUidKey[_uidKey()] = _RecordingTotalsSnapshot(
        revision: revision,
        recordingsCount: files.length,
        durationsResolved: resolved,
        totalRecorded: total,
        latestTimestamp: latest,
        isValid: true,
      );

      setState(() {
        _recordingsCount = files.length;
        _durationsResolved = resolved;
        _totalRecorded = total;
        _latestTimestamp = latest;
        _isLoading = false;
      });
    } catch (_) {
      if (showLoading) {
        final elapsed = DateTime.now().difference(start);
        if (elapsed < minSkeletonDuration) {
          await Future<void>.delayed(minSkeletonDuration - elapsed);
        }
      }

      if (!mounted) return;
      _cacheByUidKey[_uidKey()] = _RecordingTotalsSnapshot(
        revision: RecordingsLibraryEvents.revision.value,
        recordingsCount: 0,
        durationsResolved: 0,
        totalRecorded: Duration.zero,
        latestTimestamp: null,
        isValid: false,
      );

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

    final totalTimeText = (_durationsResolved == 0 && _recordingsCount > 0)
        ? '--'
        : _formatTotal(_totalRecorded);

    final countText = _recordingsCount.toString();

    final meta = _recordingsCount == 0
        ? 'No recordings yet'
        : (_latestTimestamp == null)
            ? '$_recordingsCount recordings'
            : 'Last recorded: ${_formatRelativeDateTime(_latestTimestamp!, DateTime.now())}';

    final body = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: _MiniStatCard(
                icon: Icons.timer_rounded,
                label: 'Total time',
                value: totalTimeText,
                isLoading: _isLoading,
                onTap: widget.onTap,
              ),
            ),
            const SizedBox(width: AuraSpacing.sm),
            Expanded(
              child: _MiniStatCard(
                icon: Icons.multitrack_audio_rounded,
                label: 'Recordings',
                value: countText,
                isLoading: _isLoading,
                onTap: widget.onTap,
              ),
            ),
          ],
        ),
        const SizedBox(height: AuraSpacing.xs),
        _isLoading
            ? const Padding(
                padding: EdgeInsets.symmetric(vertical: 3),
                child: AuraSkeletonBox(width: 180, height: 10),
              )
            : Text(
                meta,
                style: AuraTypography.caption(colors.textTertiary),
                overflow: TextOverflow.ellipsis,
              ),
      ],
    );

    if (_isLoading) {
      return AuraSkeletonGroup(child: body);
    }
    return body;
  }
}

class _RecordingTotalsSnapshot {
  const _RecordingTotalsSnapshot({
    required this.revision,
    required this.recordingsCount,
    required this.durationsResolved,
    required this.totalRecorded,
    required this.latestTimestamp,
    required this.isValid,
  });

  final int revision;
  final int recordingsCount;
  final int durationsResolved;
  final Duration totalRecorded;
  final DateTime? latestTimestamp;
  final bool isValid;
}

class _MiniStatCard extends StatelessWidget {
  const _MiniStatCard({
    required this.icon,
    required this.label,
    required this.value,
    this.isLoading = false,
    this.onTap,
  });

  final IconData icon;
  final String label;
  final String value;
  final bool isLoading;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = AuraThemeColors.of(context);

    return Material(
      color: colors.surface,
      borderRadius: AuraRadius.lgBr,
      child: InkWell(
        onTap: onTap == null
            ? null
            : () {
                HapticFeedback.lightImpact();
                onTap!();
              },
        borderRadius: AuraRadius.lgBr,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: AuraRadius.lgBr,
            border: Border.all(color: colors.border),
          ),
          padding: const EdgeInsets.all(AuraSpacing.md),
          child: Row(
        children: [
          Icon(icon, size: 22, color: colors.accent),
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
                const SizedBox(height: 4),
                isLoading
                    ? const Padding(
                        padding: EdgeInsets.only(top: 2, bottom: 2),
                        child: AuraSkeletonBox(width: 56, height: 16),
                      )
                    : Text(
                        value,
                        style: AuraTypography.titleMedium(colors.textPrimary)
                            .copyWith(
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
        ),
      ),
    );
  }
}
