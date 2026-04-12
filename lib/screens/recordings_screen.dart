import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:just_audio/just_audio.dart';
import 'package:path_provider/path_provider.dart';

import '../theme/aura_theme.dart';
import '../theme/aura_tokens.dart';
import 'widgets/main_bottom_nav.dart';

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

class _RecordingsScreenState extends State<RecordingsScreen> {
  List<_RecordingEntry> _allRecordings = const [];
  bool _isLoading = true;

  _SortMode _sortMode = _SortMode.timeDesc;
  _SourceFilter _sourceFilter = _SourceFilter.all;

  late final AudioPlayer _audioPlayer;
  String? _playingFilePath;
  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;

  Future<void> _onBottomNavTapped(int index) async {
    if (index == 1) return;

    switch (index) {
      case 0:
        Navigator.pushReplacementNamed(context, '/home');
        break;
      case 2:
        Navigator.pushReplacementNamed(context, '/history');
        break;
      case 3:
        Navigator.pushReplacementNamed(context, '/summary');
        break;
    }
  }

  @override
  void initState() {
    super.initState();
    _audioPlayer = AudioPlayer();
    _audioPlayer.durationStream.listen((duration) {
      setState(() => _duration = duration ?? Duration.zero);
    });
    _audioPlayer.positionStream.listen((position) {
      setState(() => _position = position);
    });
    _loadRecordings();
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }

  _RecordingSource _inferSource(String fileName) {
    final lower = fileName.toLowerCase();
    if (lower.startsWith('aura_')) return _RecordingSource.recorded;
    return _RecordingSource.uploaded;
  }

  String _sourceLabel(_RecordingSource source) {
    switch (source) {
      case _RecordingSource.recorded:
        return 'Recorded';
      case _RecordingSource.uploaded:
        return 'Uploaded';
    }
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
      final dir = await getApplicationDocumentsDirectory();
      final entities = dir.listSync();
      final files = entities
          .where((e) => e.path.toLowerCase().endsWith('.m4a'))
          .map((e) => File(e.path))
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

      if (!mounted) return;
      setState(() {
        _allRecordings = entries;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }

  Future<void> _playRecording(String filePath) async {
    try {
      if (_playingFilePath == filePath && _audioPlayer.playing) {
        await _audioPlayer.pause();
        setState(() => _playingFilePath = null);
      } else {
        await _audioPlayer.setFilePath(filePath);
        await _audioPlayer.play();
        setState(() => _playingFilePath = filePath);
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error playing audio: $e')),
      );
    }
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
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
            return SafeArea(
              child: Column(
                mainAxisSize: MainAxisSize.min,
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
      bottomNavigationBar: MainBottomNav(
        selectedIndex: 1,
        onTap: _onBottomNavTapped,
      ),
      appBar: AppBar(
        backgroundColor: colors.surface,
        elevation: 0,
        leading: _ScreenBackButton(),
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
        final fileName = entry.fileName;
        final fileSize = entry.sizeBytes;
        final lastModified = entry.modified;
        final formattedDate =
            '${lastModified.year}-${lastModified.month.toString().padLeft(2, '0')}-${lastModified.day.toString().padLeft(2, '0')} '
            '${lastModified.hour.toString().padLeft(2, '0')}:${lastModified.minute.toString().padLeft(2, '0')}';
        final isPlaying = _playingFilePath == file.path;

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
                    Material(
                      color: Colors.transparent,
                      borderRadius: AuraRadius.fullBr,
                      child: InkWell(
                        borderRadius: AuraRadius.fullBr,
                        onTap: () => _playRecording(file.path),
                        child: Icon(
                          isPlaying
                              ? Icons.pause_circle_filled_rounded
                              : Icons.play_circle_filled_rounded,
                          color: colors.accent,
                          size: 40,
                        ),
                      ),
                    ),
                    const SizedBox(width: AuraSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            fileName,
                            style: AuraTypography.bodyLarge(colors.textPrimary),
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: AuraSpacing.xxs),
                          Text(
                            '$formattedDate  •  ${_sourceLabel(entry.source)}  •  ${(fileSize / 1024 / 1024).toStringAsFixed(2)} MB',
                            style: AuraTypography.caption(colors.textSecondary),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    Material(
                      color: Colors.transparent,
                      borderRadius: AuraRadius.fullBr,
                      child: InkWell(
                        borderRadius: AuraRadius.fullBr,
                        onTap: () => _showDeleteDialog(context, fileName, file.path, colors),
                        child: Padding(
                          padding: const EdgeInsets.all(AuraSpacing.sm),
                          child: Icon(
                            Icons.delete_outline_rounded,
                            color: colors.textTertiary,
                            size: 22,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                if (isPlaying) ...[
                  const SizedBox(height: AuraSpacing.sm),
                  Slider(
                    value: _position.inSeconds.toDouble(),
                    max: _duration.inSeconds.toDouble().clamp(1, double.infinity),
                    onChanged: (v) => _audioPlayer.seek(Duration(seconds: v.toInt())),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: AuraSpacing.sm),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          _formatDuration(_position),
                          style: AuraTypography.caption(colors.textSecondary),
                        ),
                        Text(
                          _formatDuration(_duration),
                          style: AuraTypography.caption(colors.textSecondary),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
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

class _ScreenBackButton extends StatelessWidget {
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
