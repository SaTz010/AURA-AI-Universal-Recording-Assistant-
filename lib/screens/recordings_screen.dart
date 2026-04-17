import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:just_audio/just_audio.dart';

import '../providers/auth_provider.dart';
import '../services/api_service.dart';
import '../services/recordings_library_events.dart';
import '../services/recordings_storage.dart';
import '../services/summaries_library_events.dart';
import '../services/summaries_storage.dart';
import 'summarized_audio_detail_screen.dart';
import 'widgets/summarization_flow.dart';
import '../theme/aura_theme.dart';
import '../theme/aura_tokens.dart';

enum _RecordingSource { recorded, uploaded }

enum _SortMode {
  timeDesc,
  timeAsc,
  nameAsc,
  nameDesc,
  sizeDesc,
  sizeAsc,
}

enum _SourceFilter { all, recorded, uploaded }

class _RecordingEntry {
  const _RecordingEntry({
    required this.file,
    required this.fileName,
    required this.sizeBytes,
    required this.modified,
    required this.source,
  });

  final File file;
  final String fileName;
  final int sizeBytes;
  final DateTime modified;
  final _RecordingSource source;
}

class RecordingsScreen extends StatefulWidget {
  const RecordingsScreen({super.key});

  @override
  State<RecordingsScreen> createState() => _RecordingsScreenState();
}

class _RecordingsScreenState extends State<RecordingsScreen> with TickerProviderStateMixin {
  List<_RecordingEntry> _allRecordings = const [];
  bool _isLoading = true;

  final Map<String, Duration?> _durationCache = {};
  final Map<String, SummarizedAudio> _summariesMap = {}; // Track summaries by file path

  String? _effectiveUid;
  bool _hasLoadedOnce = false;
  late final VoidCallback _libraryListener;
  late final VoidCallback _summariesListener;

  _SortMode _sortMode = _SortMode.timeDesc;
  _SourceFilter _sourceFilter = _SourceFilter.all;

  late final AudioPlayer _audioPlayer;
  late final ApiService _apiService;
  String? _playingFilePath;
  String? _loadedFilePath;
  String? _expandedFilePath;
  bool _isPreparing = false;

  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;

  @override
  void initState() {
    super.initState();
    _audioPlayer = AudioPlayer();
    _apiService = ApiService();
    _audioPlayer.durationStream.listen((duration) {
      setState(() => _duration = duration ?? Duration.zero);
    });
    _audioPlayer.positionStream.listen((position) {
      setState(() => _position = position);
    });

    _libraryListener = () {
      if (!mounted) return;
      unawaited(_loadRecordings());
    };
    RecordingsLibraryEvents.revision.addListener(_libraryListener);

    _summariesListener = () {
      if (!mounted) return;
      unawaited(_loadSummariesMap());
    };
    SummariesLibraryEvents.revision.addListener(_summariesListener);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final authProvider = AuraAuthProvider.of(context);
    if (!authProvider.initialized) return;
    final nextUid = authProvider.isGuest ? null : authProvider.user?.uid;
    final didUserChange = nextUid != _effectiveUid;
    if (!didUserChange && _hasLoadedOnce) return;

    _effectiveUid = nextUid;
    _hasLoadedOnce = true;

    if (didUserChange) {
      _durationCache.clear();
      _loadedFilePath = null;
      _expandedFilePath = null;
      _playingFilePath = null;
    }

    _isLoading = true;
    unawaited(_loadRecordings());
  }

  @override
  void dispose() {
    RecordingsLibraryEvents.revision.removeListener(_libraryListener);
    SummariesLibraryEvents.revision.removeListener(_summariesListener);
    _audioPlayer.dispose();
    _apiService.dispose();
    super.dispose();
  }

  _RecordingSource _inferSource(String fileName) {
    final lower = fileName.toLowerCase();
    if (lower.startsWith('aura_')) return _RecordingSource.recorded;
    return _RecordingSource.uploaded;
  }

  Future<void> _startSummarizeFlowForEntry(_RecordingEntry entry) async {
    final saved = await SummarizationFlow.summarizeAndOpen(
      context: context,
      apiService: _apiService,
      uid: _effectiveUid,
      audioPath: entry.file.path,
      audioFileName: entry.fileName,
    );

    if (!mounted) return;
    if (saved == null) return;

    setState(() => _summariesMap[saved.filePath] = saved);
  }

  Future<void> _loadSummariesMap() async {
    final summaries = await SummariesStorage.load(_effectiveUid);
    final next = <String, SummarizedAudio>{};
    for (final s in summaries) {
      next[s.filePath] = s;
    }

    if (!mounted) return;
    setState(() {
      _summariesMap
        ..clear()
        ..addAll(next);
    });
  }


  List<_RecordingEntry> _visibleRecordings() {
    final filtered = _allRecordings.where((r) {
      switch (_sourceFilter) {
        case _SourceFilter.all:
          return true;
        case _SourceFilter.recorded:
          return r.source == _RecordingSource.recorded;
        case _SourceFilter.uploaded:
          return r.source == _RecordingSource.uploaded;
      }
    }).toList();

    int compare(_RecordingEntry a, _RecordingEntry b) {
      switch (_sortMode) {
        case _SortMode.timeDesc:
          return b.modified.compareTo(a.modified);
        case _SortMode.timeAsc:
          return a.modified.compareTo(b.modified);
        case _SortMode.nameAsc:
          return a.fileName.toLowerCase().compareTo(b.fileName.toLowerCase());
        case _SortMode.nameDesc:
          return b.fileName.toLowerCase().compareTo(a.fileName.toLowerCase());
        case _SortMode.sizeDesc:
          return b.sizeBytes.compareTo(a.sizeBytes);
        case _SortMode.sizeAsc:
          return a.sizeBytes.compareTo(b.sizeBytes);
      }
    }

    filtered.sort(compare);
    return filtered;
  }

  Future<void> _loadRecordings() async {
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

      final entries = <_RecordingEntry>[];
      for (final file in files) {
        final fileName = file.path.split(RegExp(r'[\\/]')).last;
        final sizeBytes = file.lengthSync();
        final modified = file.lastModifiedSync();
        entries.add(
          _RecordingEntry(
            file: file,
            fileName: fileName,
            sizeBytes: sizeBytes,
            modified: modified,
            source: _inferSource(fileName),
          ),
        );
      }

      // Load summaries for all recordings
      final summaries = await SummariesStorage.load(_effectiveUid);
      final summariesMap = <String, SummarizedAudio>{};
      for (final summary in summaries) {
        summariesMap[summary.filePath] = summary;
      }

      if (!mounted) return;
      setState(() {
        _allRecordings = entries;
        _isLoading = false;
        _summariesMap.clear();
        _summariesMap.addAll(summariesMap);
      });

      final newestFirst = [...entries]..sort((a, b) => b.modified.compareTo(a.modified));
      unawaited(_prefetchDurations(newestFirst.take(25)));
    } catch (_) {
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }

  String _displayTitle(String fileName) {
    final dot = fileName.lastIndexOf('.');
    if (dot <= 0) return fileName;
    return fileName.substring(0, dot);
  }

  String _formatRelativeDateTime(DateTime dt) {
    final now = DateTime.now();
    final isSameDay = now.year == dt.year && now.month == dt.month && now.day == dt.day;

    final hour12 = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
    final minute = dt.minute.toString().padLeft(2, '0');
    final ampm = dt.hour >= 12 ? 'PM' : 'AM';
    final time = '$hour12:$minute $ampm';

    if (isSameDay) return 'Today, $time';

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

    final month = months[(dt.month - 1).clamp(0, 11)];
    return '$month ${dt.day}, $time';
  }

  Future<void> _prefetchDurations(Iterable<_RecordingEntry> entries) async {
    final probe = AudioPlayer();
    try {
      for (final entry in entries) {
        final path = entry.file.path;
        if (_durationCache.containsKey(path)) continue;

        try {
          final d = await probe.setFilePath(path);
          if (d != null) {
            _durationCache[path] = d;
          } else {
            _durationCache[path] = null;
          }
        } catch (_) {
          _durationCache[path] = null;
        }

        if (!mounted) return;
      }
    } finally {
      await probe.dispose();
    }

    if (!mounted) return;
    setState(() {});
  }

  Future<void> _prepareFile(String filePath) async {
    if (_loadedFilePath == filePath) return;

    try {
      setState(() => _isPreparing = true);
      final loadedDuration = await _audioPlayer.setFilePath(filePath);
      if (!mounted) return;
      setState(() {
        _loadedFilePath = filePath;
        _duration = loadedDuration ?? Duration.zero;
        _durationCache[filePath] = loadedDuration;
        _isPreparing = false;
        _position = Duration.zero;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isPreparing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading audio: $e')),
      );
    }
  }

  Future<void> _toggleExpanded(String filePath) async {
    if (_expandedFilePath == filePath) {
      if (_loadedFilePath == filePath && _audioPlayer.playing) {
        await _audioPlayer.pause();
      }
      if (!mounted) return;
      setState(() {
        _expandedFilePath = null;
        if (_loadedFilePath == filePath) {
          _playingFilePath = null;
        }
      });
      return;
    }

    setState(() => _expandedFilePath = filePath);
    await _prepareFile(filePath);
  }

  Future<void> _seekRelative(String filePath, Duration delta) async {
    if (_loadedFilePath != filePath) return;

    final total = _duration;
    if (total == Duration.zero) return;

    final raw = _position + delta;
    final clamped = raw < Duration.zero
        ? Duration.zero
        : (raw > total ? total : raw);

    await _audioPlayer.seek(clamped);
  }

  Future<void> _playRecording(String filePath) async {
    try {
      final isSameFile = _loadedFilePath == filePath;

      if (isSameFile) {
        if (_audioPlayer.playing) {
          await _audioPlayer.pause();
          if (!mounted) return;
          setState(() => _playingFilePath = null);
        } else {
          await _audioPlayer.play();
          if (!mounted) return;
          setState(() => _playingFilePath = filePath);
        }
        return;
      }

      setState(() => _isPreparing = true);
      final loadedDuration = await _audioPlayer.setFilePath(filePath);
      await _audioPlayer.play();
      if (!mounted) return;
      setState(() {
        _loadedFilePath = filePath;
        _duration = loadedDuration ?? Duration.zero;
        _durationCache[filePath] = loadedDuration;
        _playingFilePath = filePath;
        _expandedFilePath = filePath;
        _isPreparing = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isPreparing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error playing audio: $e')),
      );
    }
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');

    final hours = duration.inHours;
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));

    if (hours > 0) {
      return '$hours:$minutes:$seconds';
    }
    return '$minutes:$seconds';
  }

  Future<void> _deleteRecording(String filePath) async {
    try {
      if (_playingFilePath == filePath) {
        await _audioPlayer.stop();
        setState(() => _playingFilePath = null);
      }

      await File(filePath).delete();
      await _loadRecordings();
      if (!mounted) return;
      RecordingsLibraryEvents.notifyChanged();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Recording deleted')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error deleting recording: $e')),
      );
    }
  }

  Future<void> _openFilterSheet() async {
    final colors = AuraThemeColors.of(context);

    var tempSort = _sortMode;
    var tempSource = _sourceFilter;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: colors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AuraRadius.lg)),
      ),
      builder: (sheetContext) {
        final sheetColors = AuraThemeColors.of(sheetContext);

        Widget option({
          required String label,
          required bool selected,
          required VoidCallback onTap,
        }) {
          return Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onTap,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AuraSpacing.lg,
                  vertical: AuraSpacing.md,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        label,
                        style: AuraTypography.bodyMedium(sheetColors.textPrimary),
                      ),
                    ),
                    if (selected)
                      Icon(Icons.check_rounded, color: sheetColors.accent, size: 20),
                  ],
                ),
              ),
            ),
          );
        }

        return StatefulBuilder(
          builder: (context, setSheetState) {
            final maxHeight = MediaQuery.sizeOf(context).height * 0.85;

            return SafeArea(
              child: ConstrainedBox(
                constraints: BoxConstraints(maxHeight: maxHeight),
                child: Column(
                  mainAxisSize: MainAxisSize.max,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(
                        AuraSpacing.xl,
                        AuraSpacing.lg,
                        AuraSpacing.xl,
                        AuraSpacing.sm,
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              'Filter & Sort',
                              style: AuraTypography.titleMedium(sheetColors.textPrimary),
                            ),
                          ),
                          TextButton(
                            onPressed: () {
                              setSheetState(() {
                                tempSort = _SortMode.timeDesc;
                                tempSource = _SourceFilter.all;
                              });
                            },
                            child: const Text('Reset'),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: SingleChildScrollView(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: AuraSpacing.xl),
                              child: Text(
                                'Sort by',
                                style: AuraTypography.overline(sheetColors.textSecondary),
                              ),
                            ),
                            const SizedBox(height: AuraSpacing.xs),
                            option(
                              label: 'Time recorded (newest)',
                              selected: tempSort == _SortMode.timeDesc,
                              onTap: () => setSheetState(() => tempSort = _SortMode.timeDesc),
                            ),
                            option(
                              label: 'Time recorded (oldest)',
                              selected: tempSort == _SortMode.timeAsc,
                              onTap: () => setSheetState(() => tempSort = _SortMode.timeAsc),
                            ),
                            option(
                              label: 'Name (A → Z)',
                              selected: tempSort == _SortMode.nameAsc,
                              onTap: () => setSheetState(() => tempSort = _SortMode.nameAsc),
                            ),
                            option(
                              label: 'Name (Z → A)',
                              selected: tempSort == _SortMode.nameDesc,
                              onTap: () => setSheetState(() => tempSort = _SortMode.nameDesc),
                            ),
                            option(
                              label: 'Size (largest)',
                              selected: tempSort == _SortMode.sizeDesc,
                              onTap: () => setSheetState(() => tempSort = _SortMode.sizeDesc),
                            ),
                            option(
                              label: 'Size (smallest)',
                              selected: tempSort == _SortMode.sizeAsc,
                              onTap: () => setSheetState(() => tempSort = _SortMode.sizeAsc),
                            ),
                            const SizedBox(height: AuraSpacing.sm),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: AuraSpacing.xl),
                              child: Text(
                                'Source',
                                style: AuraTypography.overline(sheetColors.textSecondary),
                              ),
                            ),
                            const SizedBox(height: AuraSpacing.xs),
                            option(
                              label: 'All',
                              selected: tempSource == _SourceFilter.all,
                              onTap: () => setSheetState(() => tempSource = _SourceFilter.all),
                            ),
                            option(
                              label: 'Recorded',
                              selected: tempSource == _SourceFilter.recorded,
                              onTap: () => setSheetState(() => tempSource = _SourceFilter.recorded),
                            ),
                            option(
                              label: 'Uploaded',
                              selected: tempSource == _SourceFilter.uploaded,
                              onTap: () => setSheetState(() => tempSource = _SourceFilter.uploaded),
                            ),
                            const SizedBox(height: AuraSpacing.lg),
                          ],
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(
                        AuraSpacing.xl,
                        0,
                        AuraSpacing.xl,
                        AuraSpacing.xl,
                      ),
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.pop(sheetContext);
                          setState(() {
                            _sortMode = tempSort;
                            _sourceFilter = tempSource;
                          });
                        },
                        child: const Text('Apply'),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = AuraThemeColors.of(context);
    final visible = _visibleRecordings();

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        backgroundColor: colors.background,
        surfaceTintColor: Colors.transparent,
        scrolledUnderElevation: 0,
        elevation: 0,
        automaticallyImplyLeading: false,
        title: Text('Recordings', style: AuraTypography.titleLarge(colors.textPrimary)),
        centerTitle: false,
        actions: [
          IconButton(
            onPressed: () {
              HapticFeedback.lightImpact();
              _openFilterSheet();
            },
            icon: Icon(Icons.tune_rounded, color: colors.iconDefault),
            tooltip: 'Filter',
          ),
        ],
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: colors.accent))
          : visible.isEmpty
              ? (_allRecordings.isEmpty ? _buildEmptyState(colors) : _buildFilteredEmptyState(colors))
              : _buildRecordingsList(colors, visible),
    );
  }

  Widget _buildEmptyState(AuraThemeColors colors) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 96,
            height: 96,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: colors.surfaceElevated,
            ),
            child: Icon(Icons.mic_rounded, size: 48, color: colors.textTertiary),
          ),
          const SizedBox(height: AuraSpacing.xl),
          Text('No Recordings', style: AuraTypography.headlineMedium(colors.textPrimary)),
          const SizedBox(height: AuraSpacing.sm),
          Text(
            'Start recording to see your files here',
            style: AuraTypography.bodyMedium(colors.textSecondary),
          ),
        ],
      ),
    );
  }

  Widget _buildFilteredEmptyState(AuraThemeColors colors) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AuraSpacing.xl),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: colors.surfaceElevated,
              ),
              child: Icon(
                Icons.filter_alt_off_rounded,
                size: 44,
                color: colors.textTertiary,
              ),
            ),
            const SizedBox(height: AuraSpacing.xl),
            Text(
              'No matches',
              style: AuraTypography.headlineMedium(colors.textPrimary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AuraSpacing.sm),
            Text(
              'Try changing your filters to see more recordings.',
              style: AuraTypography.bodyMedium(colors.textSecondary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AuraSpacing.lg),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                OutlinedButton(
                  onPressed: _openFilterSheet,
                  child: const Text('Edit filters'),
                ),
                const SizedBox(width: AuraSpacing.sm),
                ElevatedButton(
                  onPressed: () {
                    setState(() {
                      _sortMode = _SortMode.timeDesc;
                      _sourceFilter = _SourceFilter.all;
                    });
                  },
                  child: const Text('Reset'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecordingsList(AuraThemeColors colors, List<_RecordingEntry> recordings) {
    return ListView.separated(
      padding: const EdgeInsets.symmetric(
        horizontal: AuraSpacing.base,
        vertical: AuraSpacing.lg,
      ),
      separatorBuilder: (_, separatorIndex) => const SizedBox(height: AuraSpacing.sm),
      itemCount: recordings.length,
      itemBuilder: (context, index) {
        final entry = recordings[index];
        final file = entry.file;
        final title = _displayTitle(entry.fileName);
        final lastModified = entry.modified;

        final isExpanded = _expandedFilePath == file.path;
        final isActive = _loadedFilePath == file.path;
        final isPlaying = isActive && _audioPlayer.playing;

        final cached = _durationCache[file.path];
        final displayDuration = (isActive && _duration.inMilliseconds > 0)
            ? _duration
            : (cached ?? Duration.zero);
        final durationText = displayDuration.inMilliseconds > 0
            ? _formatDuration(displayDuration)
            : '--:--';

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
                  onTap: () {
                    HapticFeedback.selectionClick();
                    _toggleExpanded(file.path);
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AuraSpacing.lg,
                      vertical: AuraSpacing.md,
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                title,
                                style: AuraTypography.bodyLarge(colors.textPrimary).copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                _formatRelativeDateTime(lastModified),
                                style: AuraTypography.caption(colors.textSecondary),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: AuraSpacing.md),
                        Text(
                          durationText,
                          style: AuraTypography.caption(colors.textSecondary),
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
                    ? _InlinePlayer(
                        colors: colors,
                        filePath: file.path,
                        isActive: isActive,
                        isPlaying: isPlaying,
                        isPreparing: _isPreparing && _loadedFilePath != file.path,
                        position: isActive ? _position : Duration.zero,
                        duration: isActive ? _duration : Duration.zero,
                        formatDuration: _formatDuration,
                        onPlayPause: () => _playRecording(file.path),
                        onSeekToSeconds: (seconds) =>
                            _audioPlayer.seek(Duration(seconds: seconds)),
                        onSkipBack: () =>
                            _seekRelative(file.path, const Duration(seconds: -15)),
                        onSkipForward: () =>
                            _seekRelative(file.path, const Duration(seconds: 15)),
                        onDelete: () => _showDeleteDialog(
                          context,
                          entry.fileName,
                          file.path,
                          colors,
                        ),
                        onSummarize: () => _startSummarizeFlowForEntry(entry),
                        onViewSummary: _summariesMap.containsKey(file.path)
                            ? () => _viewStoredSummary(_summariesMap[file.path]!)
                            : null,
                      )
                    : const SizedBox.shrink(),
              ),
            ],
          ),
        );
      },
    );
  }

  void _viewStoredSummary(SummarizedAudio summary) {
    HapticFeedback.lightImpact();

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => SummarizedAudioDetailScreen(summary: summary),
      ),
    );
  }

  void _showDeleteDialog(
    BuildContext context,
    String fileName,
    String filePath,
    AuraThemeColors colors,
  ) {
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: const Text('Delete Recording?'),
        content: Text('Are you sure you want to delete $fileName?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(dialogCtx);
              _deleteRecording(filePath);
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
}

class _InlinePlayer extends StatelessWidget {
  const _InlinePlayer({
    required this.colors,
    required this.filePath,
    required this.isActive,
    required this.isPlaying,
    required this.isPreparing,
    required this.position,
    required this.duration,
    required this.formatDuration,
    required this.onPlayPause,
    required this.onSeekToSeconds,
    required this.onSkipBack,
    required this.onSkipForward,
    required this.onDelete,
    this.onSummarize,
    this.onViewSummary,
  });

  final AuraThemeColors colors;
  final String filePath;
  final bool isActive;
  final bool isPlaying;
  final bool isPreparing;
  final Duration position;
  final Duration duration;
  final String Function(Duration) formatDuration;
  final VoidCallback onPlayPause;
  final ValueChanged<int> onSeekToSeconds;
  final VoidCallback onSkipBack;
  final VoidCallback onSkipForward;
  final VoidCallback onDelete;
  final VoidCallback? onSummarize;
  final VoidCallback? onViewSummary;

  @override
  Widget build(BuildContext context) {
    final canSeek = isActive && duration.inMilliseconds > 0;
    final maxSeconds = duration.inSeconds <= 0 ? 1 : duration.inSeconds;
    final valueSeconds = canSeek
        ? position.inSeconds.clamp(0, maxSeconds).toDouble()
        : 0.0;

    final remainingRaw = duration - position;
    final remaining = remainingRaw.isNegative ? Duration.zero : remainingRaw;

    final skipTextStyle = AuraTypography.bodyMedium(colors.iconDefault).copyWith(
      fontWeight: FontWeight.w800,
      letterSpacing: 0.2,
    );

    Widget skipText(String label) {
      return SizedBox(
        width: 34,
        child: Center(
          child: Text(label, style: skipTextStyle),
        ),
      );
    }

    return Padding(
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
                  formatDuration(canSeek ? position : Duration.zero),
                  style: AuraTypography.caption(colors.textSecondary),
                ),
                Text(
                  canSeek ? '-${formatDuration(remaining)}' : '--:--',
                  style: AuraTypography.caption(colors.textSecondary),
                ),
              ],
            ),
          ),
          const SizedBox(height: AuraSpacing.sm),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                onPressed: onDelete,
                icon: Icon(Icons.delete_outline_rounded, color: colors.accent),
                iconSize: 30,
                tooltip: 'Delete',
              ),
              IconButton(
                onPressed: canSeek ? onSkipBack : null,
                icon: skipText('-15'),
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
                icon: skipText('+15'),
                tooltip: 'Forward 15s',
              ),
              // Show either "View Summary" or "Summarize" button
              if (onViewSummary != null)
                IconButton(
                  onPressed: onViewSummary,
                  icon: Icon(Icons.visibility_rounded, color: colors.accent),
                  iconSize: 28,
                  tooltip: 'View Summary',
                )
              else
                IconButton(
                  onPressed: onSummarize ?? () {},
                  icon: Icon(Icons.auto_awesome_rounded, color: colors.accent),
                  iconSize: 28,
                  tooltip: 'Summarize',
                ),
            ],
          ),
        ],
      ),
    );
  }
}
