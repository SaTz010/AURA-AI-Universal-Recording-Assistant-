import 'dart:async';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../providers/auth_provider.dart';
import '../services/api_service.dart';
import '../services/recordings_library_events.dart';
import '../services/recordings_storage.dart';
import '../services/summaries_library_events.dart';
import '../services/summaries_storage.dart';
import 'summarized_audio_detail_screen.dart';
import 'widgets/aura_skeleton.dart';
import 'widgets/summarization_flow.dart';
import '../theme/aura_theme.dart';
import '../theme/aura_tokens.dart';
import '../widgets/aura_snack_bar.dart';

class _AudioChoice {
  const _AudioChoice({
    required this.filePath,
    required this.fileName,
    required this.modified,
  });

  final String filePath;
  final String fileName;
  final DateTime modified;
}

class SummaryScreen extends StatefulWidget {
  const SummaryScreen({super.key});

  @override
  State<SummaryScreen> createState() => _SummaryScreenState();
}

class _SummaryScreenState extends State<SummaryScreen> {
  String? _effectiveUid;
  bool _hasLoadedOnce = false;

  late final ApiService _apiService;

  late final VoidCallback _summariesListener;
  late final VoidCallback _recordingsListener;

  bool _isLoadingRecordings = true;
  bool _isLoadingSummaries = true;
  bool _isPickingUpload = false;
  List<_AudioChoice> _recordings = const [];
  List<SummarizedAudio> _summaries = const [];

  _AudioChoice? _selected;

  @override
  void initState() {
    super.initState();

    _apiService = ApiService();

    _summariesListener = () {
      if (!mounted) return;
      unawaited(_loadSummaries());
    };
    SummariesLibraryEvents.revision.addListener(_summariesListener);

    _recordingsListener = () {
      if (!mounted) return;
      unawaited(_loadRecordings());
    };
    RecordingsLibraryEvents.revision.addListener(_recordingsListener);
  }

  @override
  void dispose() {
    SummariesLibraryEvents.revision.removeListener(_summariesListener);
    RecordingsLibraryEvents.revision.removeListener(_recordingsListener);
    _apiService.dispose();
    super.dispose();
  }

  Future<void> _deleteSummaryAt(int index) async {
    if (index < 0 || index >= _summaries.length) return;

    final s = _summaries[index];
    final title = _displayTitle(s.fileName);

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        final dialogColors = AuraThemeColors.of(ctx);
        final destructiveColor = AuraSemanticColors.subtleDestructive(ctx);
        return AlertDialog(
          backgroundColor: dialogColors.surface,
          title: Text(
            'Delete summary?',
            style: AuraTypography.titleMedium(dialogColors.textPrimary),
          ),
          content: Text(
            'This will remove the summary for "$title" from this device.',
            style: AuraTypography.bodyMedium(dialogColors.textSecondary),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: Text(
                'Cancel',
                style: AuraTypography.bodyMedium(dialogColors.textSecondary),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: Text(
                'Delete',
                style: AuraTypography.bodyMedium(
                  destructiveColor,
                ).copyWith(fontWeight: FontWeight.w700),
              ),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;
    if (!mounted) return;

    final next = [..._summaries]..removeAt(index);
    setState(() => _summaries = next);

    await SummariesStorage.save(_effectiveUid, next);
    SummariesLibraryEvents.notifyChanged();
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
    _selected = null;
    _isLoadingRecordings = true;
    _isLoadingSummaries = true;
    unawaited(_loadAll());
  }

  Future<void> _loadAll() async {
    await Future.wait([_loadRecordings(), _loadSummaries()]);
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

      final choices = files.map((f) {
        final fileName = f.path.split(RegExp(r'[\\/]')).last;
        return _AudioChoice(
          filePath: f.path,
          fileName: fileName,
          modified: f.lastModifiedSync(),
        );
      }).toList()..sort((a, b) => b.modified.compareTo(a.modified));

      if (!mounted) return;
      setState(() {
        _recordings = choices;
        _isLoadingRecordings = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _isLoadingRecordings = false);
    }
  }

  Future<void> _loadSummaries() async {
    final start = DateTime.now();
    const minSkeletonDuration = Duration(milliseconds: 250);

    final items = await SummariesStorage.load(_effectiveUid);

    // Keep only entries whose audio still exists.
    final existing = <SummarizedAudio>[];
    for (final item in items) {
      if (File(item.filePath).existsSync()) {
        existing.add(item);
      }
    }

    existing.sort((a, b) => b.createdAtMs.compareTo(a.createdAtMs));

    final elapsed = DateTime.now().difference(start);
    if (elapsed < minSkeletonDuration) {
      await Future<void>.delayed(minSkeletonDuration - elapsed);
    }

    if (!mounted) return;
    setState(() {
      _summaries = existing;
      _isLoadingSummaries = false;
    });
  }

  String _displayTitle(String fileName) {
    final dot = fileName.lastIndexOf('.');
    if (dot <= 0) return fileName;
    return fileName.substring(0, dot);
  }

  String _formatRelativeDateTime(DateTime dt) {
    final now = DateTime.now();
    final isSameDay =
        now.year == dt.year && now.month == dt.month && now.day == dt.day;

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

  Future<_AudioChoice?> _openChooseSheet(AuraThemeColors colors) async {
    HapticFeedback.lightImpact();

    if (_isLoadingRecordings) return null;

    final selectedPath = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        final sheetColors = AuraThemeColors.of(ctx);
        return SafeArea(
          top: false,
          child: DraggableScrollableSheet(
            initialChildSize: 0.88,
            minChildSize: 0.60,
            maxChildSize: 0.95,
            builder: (context, scrollController) {
              return Container(
                decoration: BoxDecoration(
                  color: sheetColors.surface,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(26),
                    topRight: Radius.circular(26),
                  ),
                  border: Border.all(color: sheetColors.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: AuraSpacing.sm),
                    Center(
                      child: Container(
                        width: 44,
                        height: 5,
                        decoration: BoxDecoration(
                          color: sheetColors.border,
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(
                        AuraSpacing.base,
                        AuraSpacing.lg,
                        AuraSpacing.base,
                        AuraSpacing.sm,
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              'Select a recording',
                              style: AuraTypography.titleLarge(
                                sheetColors.textPrimary,
                              ),
                            ),
                          ),
                          IconButton(
                            onPressed: () => Navigator.of(ctx).pop(),
                            icon: Icon(
                              Icons.close_rounded,
                              color: sheetColors.iconDefault,
                            ),
                            tooltip: 'Close',
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: _recordings.isEmpty
                          ? Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: AuraSpacing.xl,
                              ),
                              child: Center(
                                child: Text(
                                  'No recordings found',
                                  textAlign: TextAlign.center,
                                  style: AuraTypography.bodyMedium(
                                    sheetColors.textSecondary,
                                  ),
                                ),
                              ),
                            )
                          : ListView.separated(
                              controller: scrollController,
                              padding: const EdgeInsets.fromLTRB(
                                AuraSpacing.base,
                                AuraSpacing.sm,
                                AuraSpacing.base,
                                AuraSpacing.lg,
                              ),
                              itemCount: _recordings.length,
                              separatorBuilder: (context, index) =>
                                  const SizedBox(height: AuraSpacing.sm),
                              itemBuilder: (ctx, index) {
                                final r = _recordings[index];
                                final title = _displayTitle(r.fileName);

                                return Container(
                                  decoration: BoxDecoration(
                                    color: sheetColors.surface,
                                    borderRadius: AuraRadius.mdBr,
                                    border: Border.all(
                                      color: sheetColors.border,
                                    ),
                                    boxShadow: AuraElevation.low(Colors.black),
                                  ),
                                  child: Material(
                                    color: Colors.transparent,
                                    child: InkWell(
                                      borderRadius: AuraRadius.mdBr,
                                      onTap: () {
                                        HapticFeedback.selectionClick();
                                        Navigator.of(ctx).pop(r.filePath);
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
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    title,
                                                    style:
                                                        AuraTypography.bodyLarge(
                                                          sheetColors
                                                              .textPrimary,
                                                        ).copyWith(
                                                          fontWeight:
                                                              FontWeight.w600,
                                                        ),
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                  ),
                                                  const SizedBox(height: 4),
                                                  Text(
                                                    _formatRelativeDateTime(
                                                      r.modified,
                                                    ),
                                                    style:
                                                        AuraTypography.caption(
                                                          sheetColors
                                                              .textSecondary,
                                                        ),
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                    ),
                  ],
                ),
              );
            },
          ),
        );
      },
    );

    if (!mounted) return null;
    if (selectedPath == null) return null;

    final match = _recordings.where((r) => r.filePath == selectedPath).toList();
    if (match.isEmpty) return null;
    return match.first;
  }

  Future<void> _pickAndProcessUploadedAudio(AuraThemeColors colors) async {
    if (_isPickingUpload) return;
    setState(() => _isPickingUpload = true);

    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: const [
          'm4a',
          'mp3',
          'wav',
          'aac',
          'flac',
          'ogg',
          'opus',
        ],
      );

      if (!mounted) return;
      if (result == null || result.files.isEmpty) return;

      final file = result.files.single;
      final audioPath = file.path;
      if (audioPath == null || audioPath.isEmpty) {
        showAuraSnackBar(
          context,
          message: 'We could not access that file. Please choose it again.',
          backgroundColor: colors.surface,
        );
        return;
      }

      await SummarizationFlow.summarizeAndOpen(
        context: context,
        apiService: _apiService,
        uid: _effectiveUid,
        audioPath: audioPath,
        audioFileName: file.name,
      );
    } catch (_) {
      if (!mounted) return;
      showAuraSnackBar(
        context,
        message: 'We could not open the file picker. Please try again.',
        backgroundColor: colors.surface,
      );
    } finally {
      if (mounted) {
        setState(() => _isPickingUpload = false);
      } else {
        _isPickingUpload = false;
      }
    }
  }

  Future<void> _startSummarizeFlow(AuraThemeColors colors) async {
    final selected = await _openChooseSheet(colors);
    if (!mounted) return;
    if (selected == null) return;

    setState(() => _selected = selected);

    final already = _summaries
        .where((s) => s.filePath == selected.filePath)
        .firstOrNull;
    if (already != null) {
      setState(() => _selected = null);
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => SummarizedAudioDetailScreen(summary: already),
        ),
      );
      return;
    }

    await SummarizationFlow.summarizeAndOpen(
      context: context,
      apiService: _apiService,
      uid: _effectiveUid,
      audioPath: selected.filePath,
      audioFileName: selected.fileName,
    );

    if (!mounted) return;
    setState(() => _selected = null);
  }

  @override
  Widget build(BuildContext context) {
    final colors = AuraThemeColors.of(context);
    final authProvider = AuraAuthProvider.of(context);

    if (authProvider.isGuest) {
      return Scaffold(
        backgroundColor: colors.background,
        appBar: AppBar(
          backgroundColor: colors.background,
          surfaceTintColor: Colors.transparent,
          scrolledUnderElevation: 0,
          elevation: 0,
          automaticallyImplyLeading: false,
          title: Text(
            'Summarize',
            style: AuraTypography.titleLarge(colors.textPrimary),
          ),
          centerTitle: false,
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(AuraSpacing.xl),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.lock_person_rounded,
                  size: 56,
                  color: colors.iconDefault,
                ),
                const SizedBox(height: AuraSpacing.base),
                Text(
                  'Login to summarize',
                  style: AuraTypography.titleMedium(colors.textPrimary),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AuraSpacing.sm),
                Text(
                  'You are currently using guest mode.',
                  style: AuraTypography.bodyMedium(colors.textSecondary),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AuraSpacing.lg),
                ElevatedButton(
                  onPressed: () {
                    Navigator.of(
                      context,
                    ).pushNamedAndRemoveUntil('/auth', (route) => false);
                  },
                  child: const Text('Go to Login'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        backgroundColor: colors.background,
        surfaceTintColor: Colors.transparent,
        scrolledUnderElevation: 0,
        elevation: 0,
        automaticallyImplyLeading: false,
        title: Text(
          'Summarize',
          style: AuraTypography.titleLarge(colors.textPrimary),
        ),
        centerTitle: false,
      ),
      body: Padding(
        padding: const EdgeInsets.fromLTRB(
          AuraSpacing.base,
          AuraSpacing.lg,
          AuraSpacing.base,
          AuraSpacing.lg,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              decoration: BoxDecoration(
                color: colors.surface,
                borderRadius: AuraRadius.mdBr,
                border: Border.all(color: colors.border),
                boxShadow: AuraElevation.low(Colors.black),
              ),
              padding: const EdgeInsets.all(AuraSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.auto_awesome_rounded,
                        color: colors.accent,
                        size: 24,
                      ),
                      const SizedBox(width: AuraSpacing.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Summarize an audio',
                              style: AuraTypography.titleSmall(
                                colors.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Import or either select a recording to generate AI-powered summaries and transcriptions.',
                              style: AuraTypography.caption(
                                colors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  if (_selected != null) ...[
                    const SizedBox(height: AuraSpacing.md),
                    Container(
                      decoration: BoxDecoration(
                        color: colors.surfaceElevated,
                        borderRadius: AuraRadius.smBr,
                        border: Border.all(color: colors.border),
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: AuraSpacing.md,
                        vertical: AuraSpacing.sm,
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              _displayTitle(_selected!.fileName),
                              style: AuraTypography.bodyMedium(
                                colors.textPrimary,
                              ).copyWith(fontWeight: FontWeight.w600),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: AuraSpacing.sm),
                          Text(
                            _formatRelativeDateTime(_selected!.modified),
                            style: AuraTypography.caption(colors.textSecondary),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: AuraSpacing.lg),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _isPickingUpload
                              ? null
                              : () => _pickAndProcessUploadedAudio(colors),
                          icon: const Icon(
                            Icons.file_upload_outlined,
                            size: 18,
                          ),
                          label: Text(
                            _isPickingUpload ? 'Picking…' : 'Import audio',
                          ),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: colors.textPrimary,
                            side: BorderSide(color: colors.border),
                            padding: const EdgeInsets.symmetric(
                              vertical: AuraSpacing.md,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: AuraRadius.mdBr,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: AuraSpacing.sm),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: _isLoadingRecordings
                              ? null
                              : () => _startSummarizeFlow(colors),
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                              vertical: AuraSpacing.md,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: AuraRadius.mdBr,
                            ),
                          ),
                          child: Text(
                            _isLoadingRecordings ? 'Loading…' : 'My Library',
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: AuraSpacing.lg),
            Text(
              'Summarized audios',
              style: AuraTypography.titleSmall(colors.textPrimary),
            ),
            const SizedBox(height: AuraSpacing.sm),
            Expanded(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                child: _isLoadingSummaries
                    ? const _SummariesListSkeleton(key: ValueKey('skeleton'))
                    : _summaries.isEmpty
                    ? Center(
                        key: const ValueKey('empty'),
                        child: Text(
                          'No summarized audios yet',
                          style: AuraTypography.bodyMedium(
                            colors.textSecondary,
                          ),
                        ),
                      )
                    : ListView.separated(
                        key: const ValueKey('content'),
                        padding: const EdgeInsets.only(bottom: AuraSpacing.lg),
                        separatorBuilder: (context, index) =>
                            const SizedBox(height: AuraSpacing.sm),
                        itemCount: _summaries.length,
                        itemBuilder: (ctx, index) {
                          final s = _summaries[index];
                          final title = _displayTitle(s.fileName);
                          final createdAt = DateTime.fromMillisecondsSinceEpoch(
                            s.createdAtMs,
                          );
                          return Material(
                            color: Colors.transparent,
                            child: InkWell(
                              borderRadius: AuraRadius.mdBr,
                              onTap: () {
                                HapticFeedback.lightImpact();
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) =>
                                        SummarizedAudioDetailScreen(summary: s),
                                  ),
                                );
                              },
                              child: Container(
                                decoration: BoxDecoration(
                                  color: colors.surface,
                                  borderRadius: AuraRadius.mdBr,
                                  border: Border.all(color: colors.border),
                                  boxShadow: AuraElevation.low(Colors.black),
                                ),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: AuraSpacing.lg,
                                  vertical: AuraSpacing.md,
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                title,
                                                style:
                                                    AuraTypography.bodyLarge(
                                                      colors.textPrimary,
                                                    ).copyWith(
                                                      fontWeight:
                                                          FontWeight.w600,
                                                    ),
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                              const SizedBox(height: 4),
                                              Text(
                                                _formatRelativeDateTime(
                                                  createdAt,
                                                ),
                                                style: AuraTypography.caption(
                                                  colors.textSecondary,
                                                ),
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ],
                                          ),
                                        ),
                                        IconButton(
                                          onPressed: () =>
                                              _deleteSummaryAt(index),
                                          icon: Icon(
                                            Icons.delete_outline_rounded,
                                            color:
                                                AuraSemanticColors.subtleDestructive(
                                                  context,
                                                ),
                                          ),
                                          tooltip: 'Delete summary',
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: AuraSpacing.sm),
                                    Text(
                                      s.description,
                                      style: AuraTypography.bodyMedium(
                                        colors.textSecondary,
                                      ),
                                      maxLines: 3,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

extension _IterableFirstOrNull<E> on Iterable<E> {
  E? get firstOrNull {
    final it = iterator;
    if (!it.moveNext()) return null;
    return it.current;
  }
}

class _SummariesListSkeleton extends StatelessWidget {
  const _SummariesListSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = AuraThemeColors.of(context);
    return AuraSkeletonGroup(
      child: ListView.separated(
        padding: const EdgeInsets.only(bottom: AuraSpacing.lg),
        separatorBuilder: (context, index) =>
            const SizedBox(height: AuraSpacing.sm),
        itemCount: 4,
        itemBuilder: (context, index) {
          return Container(
            decoration: BoxDecoration(
              color: colors.surface,
              borderRadius: AuraRadius.mdBr,
              border: Border.all(color: colors.border),
            ),
            padding: const EdgeInsets.symmetric(
              horizontal: AuraSpacing.lg,
              vertical: AuraSpacing.md,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          AuraSkeletonBox(width: 180, height: 14),
                          SizedBox(height: 8),
                          AuraSkeletonBox(width: 110, height: 10),
                        ],
                      ),
                    ),
                    SizedBox(width: AuraSpacing.md),
                    AuraSkeletonBox(width: 22, height: 22),
                  ],
                ),
                SizedBox(height: AuraSpacing.sm),
                AuraSkeletonBox(height: 10),
                SizedBox(height: 6),
                AuraSkeletonBox(height: 10),
                SizedBox(height: 6),
                AuraSkeletonBox(width: 220, height: 10),
              ],
            ),
          );
        },
      ),
    );
  }
}
