import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../providers/auth_provider.dart';
import '../services/recordings_storage.dart';
import '../services/summaries_library_events.dart';
import '../services/summaries_storage.dart';
import 'summary_detail_screen.dart';
import 'widgets/analyzing_screen.dart';
import '../theme/aura_theme.dart';
import '../theme/aura_tokens.dart';

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

  late final VoidCallback _summariesListener;

  bool _isLoadingRecordings = true;
  bool _isLoadingSummaries = true;
  List<_AudioChoice> _recordings = const [];
  List<SummarizedAudio> _summaries = const [];

  _AudioChoice? _selected;

  static const Map<String, String> _contextOptions = {
    '1': 'Medical consultation',
    '2': 'Business meeting',
    '3': 'Interview',
    '4': 'Lecture / class',
    '5': 'Personal note',
    '6': 'Legal / official',
    '7': 'Other',
  };

  static const Map<String, IconData> _contextIcons = {
    '1': Icons.medical_services_rounded,
    '2': Icons.business_center_rounded,
    '3': Icons.mic_rounded,
    '4': Icons.school_rounded,
    '5': Icons.sticky_note_2_rounded,
    '6': Icons.gavel_rounded,
    '7': Icons.auto_awesome_rounded,
  };

  @override
  void initState() {
    super.initState();

    _summariesListener = () {
      if (!mounted) return;
      unawaited(_loadSummaries());
    };
    SummariesLibraryEvents.revision.addListener(_summariesListener);

    unawaited(_loadAll());
  }

  @override
  void dispose() {
    SummariesLibraryEvents.revision.removeListener(_summariesListener);
    super.dispose();
  }

  Future<void> _deleteSummaryAt(int index) async {
    if (index < 0 || index >= _summaries.length) return;

    final colors = AuraThemeColors.of(context);
    final s = _summaries[index];
    final title = _displayTitle(s.fileName);

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        final dialogColors = AuraThemeColors.of(ctx);
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
                style: AuraTypography.bodyMedium(colors.accent).copyWith(
                  fontWeight: FontWeight.w700,
                ),
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
    final nextUid = authProvider.isGuest ? null : authProvider.user?.uid;
    if (nextUid == _effectiveUid) return;
    _effectiveUid = nextUid;
    _selected = null;
    _isLoadingRecordings = true;
    _isLoadingSummaries = true;
    unawaited(_loadAll());
  }

  Future<void> _loadAll() async {
    await Future.wait([
      _loadRecordings(),
      _loadSummaries(),
    ]);
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

      final choices = files
          .map((f) {
            final fileName = f.path.split(RegExp(r'[\\/]')).last;
            return _AudioChoice(
              filePath: f.path,
              fileName: fileName,
              modified: f.lastModifiedSync(),
            );
          })
          .toList()
        ..sort((a, b) => b.modified.compareTo(a.modified));

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
    final items = await SummariesStorage.load(_effectiveUid);

    // Keep only entries whose audio still exists.
    final existing = <SummarizedAudio>[];
    for (final item in items) {
      if (File(item.filePath).existsSync()) {
        existing.add(item);
      }
    }

    existing.sort((a, b) => b.createdAtMs.compareTo(a.createdAtMs));

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
                              'Choose an audio',
                              style: AuraTypography.titleLarge(sheetColors.textPrimary),
                            ),
                          ),
                          IconButton(
                            onPressed: () => Navigator.of(ctx).pop(),
                            icon: Icon(Icons.close_rounded, color: sheetColors.iconDefault),
                            tooltip: 'Close',
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: _recordings.isEmpty
                          ? Padding(
                              padding: const EdgeInsets.symmetric(horizontal: AuraSpacing.xl),
                              child: Center(
                                child: Text(
                                  'No recordings found',
                                  textAlign: TextAlign.center,
                                  style: AuraTypography.bodyMedium(sheetColors.textSecondary),
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
                                    border: Border.all(color: sheetColors.border),
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
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    title,
                                                    style: AuraTypography.bodyLarge(
                                                      sheetColors.textPrimary,
                                                    ).copyWith(
                                                      fontWeight: FontWeight.w600,
                                                    ),
                                                    overflow: TextOverflow.ellipsis,
                                                  ),
                                                  const SizedBox(height: 4),
                                                  Text(
                                                    _formatRelativeDateTime(r.modified),
                                                    style: AuraTypography.caption(
                                                      sheetColors.textSecondary,
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

  Future<String?> _openContextSheet(AuraThemeColors colors, _AudioChoice selected) async {
    HapticFeedback.lightImpact();

    return showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        final sheetColors = AuraThemeColors.of(ctx);
        return SafeArea(
          top: false,
          child: DraggableScrollableSheet(
            initialChildSize: 0.70,
            minChildSize: 0.55,
            maxChildSize: 0.90,
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
                              'Select context',
                              style: AuraTypography.titleLarge(sheetColors.textPrimary),
                            ),
                          ),
                          IconButton(
                            onPressed: () => Navigator.of(ctx).pop(),
                            icon: Icon(Icons.close_rounded, color: sheetColors.iconDefault),
                            tooltip: 'Close',
                          ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: AuraSpacing.base),
                      child: Container(
                        decoration: BoxDecoration(
                          color: sheetColors.surfaceElevated,
                          borderRadius: AuraRadius.smBr,
                          border: Border.all(color: sheetColors.border),
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: AuraSpacing.md,
                          vertical: AuraSpacing.sm,
                        ),
                        child: Text(
                          _displayTitle(selected.fileName),
                          style: AuraTypography.bodyMedium(sheetColors.textPrimary).copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                    const SizedBox(height: AuraSpacing.sm),
                    Expanded(
                      child: ListView.separated(
                        controller: scrollController,
                        padding: const EdgeInsets.fromLTRB(
                          AuraSpacing.base,
                          AuraSpacing.sm,
                          AuraSpacing.base,
                          AuraSpacing.lg,
                        ),
                        itemCount: _contextOptions.length,
                        separatorBuilder: (context, index) =>
                            const SizedBox(height: AuraSpacing.sm),
                        itemBuilder: (ctx, index) {
                          final key = _contextOptions.keys.elementAt(index);
                          final label = _contextOptions[key]!;
                          final icon = _contextIcons[key] ?? Icons.circle;

                          return Container(
                            decoration: BoxDecoration(
                              color: sheetColors.surface,
                              borderRadius: AuraRadius.mdBr,
                              border: Border.all(color: sheetColors.border),
                              boxShadow: AuraElevation.low(Colors.black),
                            ),
                            child: Material(
                              color: Colors.transparent,
                              child: InkWell(
                                borderRadius: AuraRadius.mdBr,
                                onTap: () {
                                  HapticFeedback.selectionClick();
                                  Navigator.of(ctx).pop(key);
                                },
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: AuraSpacing.lg,
                                    vertical: AuraSpacing.md,
                                  ),
                                  child: Row(
                                    children: [
                                      Container(
                                        width: 36,
                                        height: 36,
                                        decoration: BoxDecoration(
                                          color: sheetColors.surfaceElevated,
                                          borderRadius: BorderRadius.circular(12),
                                          border: Border.all(color: sheetColors.border),
                                        ),
                                        alignment: Alignment.center,
                                        child: Icon(
                                          icon,
                                          size: 20,
                                          color: sheetColors.accent,
                                        ),
                                      ),
                                      const SizedBox(width: AuraSpacing.md),
                                      Expanded(
                                        child: Text(
                                          label,
                                          style: AuraTypography.bodyLarge(sheetColors.textPrimary)
                                              .copyWith(fontWeight: FontWeight.w600),
                                          overflow: TextOverflow.ellipsis,
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
  }

  Future<String?> _openExtraDetailsSheet(AuraThemeColors colors, _AudioChoice selected) async {
    HapticFeedback.lightImpact();

    return showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        final sheetColors = AuraThemeColors.of(ctx);
        final controller = TextEditingController();

        return SafeArea(
          top: false,
          child: Padding(
            padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
            child: Container(
              decoration: BoxDecoration(
                color: sheetColors.surface,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(26),
                  topRight: Radius.circular(26),
                ),
                border: Border.all(color: sheetColors.border),
              ),
              padding: const EdgeInsets.fromLTRB(
                AuraSpacing.base,
                AuraSpacing.lg,
                AuraSpacing.base,
                AuraSpacing.lg,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Any extra detail?',
                          style: AuraTypography.titleLarge(sheetColors.textPrimary),
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.of(ctx).pop(),
                        icon: Icon(Icons.close_rounded, color: sheetColors.iconDefault),
                        tooltip: 'Close',
                      ),
                    ],
                  ),
                  const SizedBox(height: AuraSpacing.sm),
                  Container(
                    decoration: BoxDecoration(
                      color: sheetColors.surfaceElevated,
                      borderRadius: AuraRadius.smBr,
                      border: Border.all(color: sheetColors.border),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: AuraSpacing.md,
                      vertical: AuraSpacing.sm,
                    ),
                    child: Text(
                      _displayTitle(selected.fileName),
                      style: AuraTypography.bodyMedium(sheetColors.textPrimary)
                          .copyWith(fontWeight: FontWeight.w600),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(height: AuraSpacing.md),
                  TextField(
                    controller: controller,
                    maxLines: 3,
                    minLines: 3,
                    enableSuggestions: false,
                    autocorrect: false,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: InputDecoration(
                      hintText: 'Optional — add helpful notes for summarization',
                      filled: true,
                      fillColor: sheetColors.surface,
                      border: OutlineInputBorder(
                        borderRadius: AuraRadius.mdBr,
                        borderSide: BorderSide(color: sheetColors.border),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: AuraRadius.mdBr,
                        borderSide: BorderSide(color: sheetColors.border),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: AuraRadius.mdBr,
                        borderSide: BorderSide(color: sheetColors.accent),
                      ),
                    ),
                    style: AuraTypography.bodyMedium(sheetColors.textPrimary),
                  ),
                  const SizedBox(height: AuraSpacing.lg),
                  ElevatedButton(
                    onPressed: () {
                      final text = controller.text.trim();
                      Navigator.of(ctx).pop(text);
                    },
                    child: const Text('Continue'),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _startSummarizeFlow(AuraThemeColors colors) async {
    final selected = await _openChooseSheet(colors);
    if (!mounted) return;
    if (selected == null) return;

    final alreadyExists = _summaries.any((s) => s.filePath == selected.filePath);
    if (alreadyExists) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('This audio is already in your summarized list.'),
          backgroundColor: colors.surface,
        ),
      );
      return;
    }

    setState(() => _selected = selected);

    final contextKey = await _openContextSheet(colors, selected);
    if (!mounted) return;
    if (contextKey == null || !_contextOptions.containsKey(contextKey)) {
      return;
    }

    final extraDetails = await _openExtraDetailsSheet(colors, selected);
    if (!mounted) return;
    if (extraDetails == null) {
      return;
    }

    await Navigator.of(context).push(
      PageRouteBuilder(
        pageBuilder: (ctx, a1, a2) => AnalyzingScreen(
          title: 'Analyzing…',
          subtitle: extraDetails.isEmpty
              ? _contextOptions[contextKey]!
              : '${_contextOptions[contextKey]} • Using extra details',
        ),
        transitionsBuilder: (ctx, animation, secondary, child) {
          return FadeTransition(opacity: animation, child: child);
        },
        transitionDuration: AuraMotion.fast,
      ),
    );

    final contextLabel = _contextOptions[contextKey]!;
    final summaryText = extraDetails.isEmpty
        ? 'Context: $contextLabel\n\nSummary will appear here later.'
        : 'Context: $contextLabel\n\nSummary will appear here later.\n\n(Extra details were provided.)';

    final entry = SummarizedAudio(
      filePath: selected.filePath,
      fileName: selected.fileName,
      createdAtMs: DateTime.now().millisecondsSinceEpoch,
      description: summaryText,
    );

    final next = [entry, ..._summaries];
    setState(() {
      _summaries = next;
      _selected = null;
    });

    try {
      await SummariesStorage.save(_effectiveUid, next);
      SummariesLibraryEvents.notifyChanged();
    } catch (_) {
      // ignore persistence failures for now
    }

    if (!mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (ctx) => SummaryDetailScreen(summary: entry),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = AuraThemeColors.of(context);

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        backgroundColor: colors.background,
        surfaceTintColor: Colors.transparent,
        scrolledUnderElevation: 0,
        elevation: 0,
        automaticallyImplyLeading: false,
        title: Text('Summarize', style: AuraTypography.titleLarge(colors.textPrimary)),
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
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: colors.surfaceElevated,
                        ),
                        child: Icon(
                          Icons.auto_awesome_rounded,
                          color: colors.textTertiary,
                        ),
                      ),
                      const SizedBox(width: AuraSpacing.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Choose an audio to summarize',
                              style: AuraTypography.titleSmall(colors.textPrimary),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              _selected == null
                                  ? 'No audio selected'
                                  : _displayTitle(_selected!.fileName),
                              style: AuraTypography.caption(colors.textSecondary),
                              overflow: TextOverflow.ellipsis,
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
                              style: AuraTypography.bodyMedium(colors.textPrimary).copyWith(
                                fontWeight: FontWeight.w600,
                              ),
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
                  ElevatedButton(
                    onPressed: _isLoadingRecordings ? null : () => _startSummarizeFlow(colors),
                    child: Text(_isLoadingRecordings ? 'Loading…' : 'Choose audio'),
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
              child: _isLoadingSummaries
                  ? Center(child: CircularProgressIndicator(color: colors.accent))
                  : _summaries.isEmpty
                      ? Center(
                          child: Text(
                            'No summarized audios yet',
                            style: AuraTypography.bodyMedium(colors.textSecondary),
                          ),
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.only(bottom: AuraSpacing.lg),
                          separatorBuilder: (context, index) =>
                              const SizedBox(height: AuraSpacing.sm),
                          itemCount: _summaries.length,
                          itemBuilder: (ctx, index) {
                            final s = _summaries[index];
                            final title = _displayTitle(s.fileName);
                            final createdAt = DateTime.fromMillisecondsSinceEpoch(s.createdAtMs);
                            return Container(
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
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              title,
                                              style: AuraTypography.bodyLarge(colors.textPrimary)
                                                  .copyWith(fontWeight: FontWeight.w600),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              _formatRelativeDateTime(createdAt),
                                              style: AuraTypography.caption(colors.textSecondary),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ],
                                        ),
                                      ),
                                      IconButton(
                                        onPressed: () => _deleteSummaryAt(index),
                                        icon: Icon(
                                          Icons.delete_outline_rounded,
                                          color: colors.iconDefault,
                                        ),
                                        tooltip: 'Delete summary',
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: AuraSpacing.sm),
                                  Text(
                                    s.description,
                                    style: AuraTypography.bodyMedium(colors.textSecondary),
                                    maxLines: 3,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }
}

