import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../services/api_service.dart';
import '../../services/summaries_library_events.dart';
import '../../services/summaries_storage.dart';
import '../../theme/aura_theme.dart';
import '../../theme/aura_tokens.dart';
import '../summarized_audio_detail_screen.dart';
import 'analyzing_screen.dart';

class SummarizationFlow {
  static const Map<String, String> defaultContextOptions = {
    '1': 'Medical consultation',
    '2': 'Business meeting',
    '3': 'Interview',
    '4': 'Lecture / class',
    '5': 'Personal note',
    '6': 'Legal / official',
    '7': 'Other',
  };

  static const Map<String, IconData> defaultContextIcons = {
    '1': Icons.medical_services_rounded,
    '2': Icons.business_center_rounded,
    '3': Icons.mic_rounded,
    '4': Icons.school_rounded,
    '5': Icons.sticky_note_2_rounded,
    '6': Icons.gavel_rounded,
    '7': Icons.auto_awesome_rounded,
  };

  static Future<SummarizedAudio?> summarizeAndOpen({
    required BuildContext context,
    required ApiService apiService,
    required String? uid,
    required String audioPath,
    required String audioFileName,
    Map<String, String> contextOptions = defaultContextOptions,
    Map<String, IconData> contextIcons = defaultContextIcons,
  }) async {
    final colors = AuraThemeColors.of(context);

    try {
      final existing = await SummariesStorage.load(uid);
      final existingItem = existing.where((s) => s.filePath == audioPath).cast<SummarizedAudio?>().firstOrNull;
      if (existingItem != null) {
        if (!context.mounted) return existingItem;
        await Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => SummarizedAudioDetailScreen(summary: existingItem),
          ),
        );
        return existingItem;
      }

      final title = _displayTitle(audioFileName);

      final contextKey = await _openContextSheet(
        context,
        colors: colors,
        title: title,
        options: contextOptions,
        icons: contextIcons,
      );
      if (!context.mounted) return null;
      if (contextKey == null || !contextOptions.containsKey(contextKey)) return null;

      final extraDetails = await _openExtraDetailsSheet(context, colors: colors, title: title);
      if (!context.mounted) return null;
      if (extraDetails == null) return null;

      final categoryLabel = contextOptions[contextKey]!;

      final loadingRoute = PageRouteBuilder(
        pageBuilder: (ctx, a1, a2) => AnalyzingScreen(
          title: 'Processing…',
          subtitle: extraDetails.trim().isEmpty
              ? categoryLabel
              : '$categoryLabel • Using extra details',
          autoPopAfter: const Duration(minutes: 10),
        ),
        transitionsBuilder: (ctx, animation, secondary, child) {
          return FadeTransition(opacity: animation, child: child);
        },
        transitionDuration: AuraMotion.fast,
      );

      unawaited(Navigator.of(context).push(loadingRoute));

      return await _processAndOpen(
        context,
        apiService: apiService,
        uid: uid,
        audioPath: audioPath,
        audioFileName: audioFileName,
        category: categoryLabel,
        detail: extraDetails.trim().isEmpty ? null : extraDetails.trim(),
      );
    } catch (_) {
      if (!context.mounted) return null;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Failed to start summarization'),
          backgroundColor: colors.surface,
        ),
      );
      return null;
    }
  }

  static Future<SummarizedAudio?> _processAndOpen(
    BuildContext context, {
    required ApiService apiService,
    required String? uid,
    required String audioPath,
    required String audioFileName,
    required String category,
    required String? detail,
  }) async {
    try {
      final response = await apiService.uploadAudioAndProcess(
        audioPath: audioPath,
        category: category,
        detail: detail,
      );

      if (!context.mounted) return null;

      if (Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }

      final existing = await SummariesStorage.load(uid);
      final newEntry = SummarizedAudio(
        filePath: audioPath,
        fileName: audioFileName,
        createdAtMs: DateTime.now().millisecondsSinceEpoch,
        description: detail ?? '',
        summary: response.summary,
        transcript: response.transcript,
        translation: response.translation,
        cost: response.cost,
        category: category,
      );

      final next = [newEntry, ...existing];
      await SummariesStorage.save(uid, next);
      SummariesLibraryEvents.notifyChanged();

      if (!context.mounted) return newEntry;

      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => SummarizedAudioDetailScreen(summary: newEntry),
        ),
      );

      return newEntry;
    } catch (e) {
      if (!context.mounted) return null;
      if (Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }

      String message = 'Failed to process audio';
      if (e is ApiException) {
        message = e.message;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          duration: const Duration(seconds: 5),
          action: SnackBarAction(
            label: 'Retry',
            onPressed: () {
              unawaited(
                _retryWithLoading(
                  context,
                  apiService: apiService,
                  uid: uid,
                  audioPath: audioPath,
                  audioFileName: audioFileName,
                  category: category,
                  detail: detail,
                ),
              );
            },
          ),
        ),
      );

      return null;
    }
  }

  static Future<void> _retryWithLoading(
    BuildContext context, {
    required ApiService apiService,
    required String? uid,
    required String audioPath,
    required String audioFileName,
    required String category,
    required String? detail,
  }) async {
    if (!context.mounted) return;

    final loadingRoute = PageRouteBuilder(
      pageBuilder: (ctx, a1, a2) => AnalyzingScreen(
        title: 'Processing…',
        subtitle: detail == null || detail.trim().isEmpty
            ? category
            : '$category • Using extra details',
        autoPopAfter: const Duration(minutes: 10),
      ),
      transitionsBuilder: (ctx, animation, secondary, child) {
        return FadeTransition(opacity: animation, child: child);
      },
      transitionDuration: AuraMotion.fast,
    );

    unawaited(Navigator.of(context).push(loadingRoute));

    await _processAndOpen(
      context,
      apiService: apiService,
      uid: uid,
      audioPath: audioPath,
      audioFileName: audioFileName,
      category: category,
      detail: detail,
    );
  }

  static String _displayTitle(String fileName) {
    final dot = fileName.lastIndexOf('.');
    if (dot <= 0) return fileName;
    return fileName.substring(0, dot);
  }

  static Future<String?> _openContextSheet(
    BuildContext context, {
    required AuraThemeColors colors,
    required String title,
    required Map<String, String> options,
    required Map<String, IconData> icons,
  }) async {
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
            initialChildSize: 0.78,
            minChildSize: 0.55,
            maxChildSize: 0.95,
            expand: false,
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
                padding: const EdgeInsets.fromLTRB(
                  AuraSpacing.base,
                  AuraSpacing.lg,
                  AuraSpacing.base,
                  AuraSpacing.lg,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Summarize as…',
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
                        title,
                        style: AuraTypography.bodyMedium(sheetColors.textPrimary)
                            .copyWith(fontWeight: FontWeight.w600),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(height: AuraSpacing.md),
                    Expanded(
                      child: ListView.separated(
                        controller: scrollController,
                        itemCount: options.length,
                        separatorBuilder: (context, index) =>
                            const SizedBox(height: AuraSpacing.sm),
                        itemBuilder: (context, index) {
                          final entry = options.entries.elementAt(index);
                          final icon = icons[entry.key] ?? Icons.auto_awesome_rounded;
                          return Material(
                            color: Colors.transparent,
                            child: InkWell(
                              borderRadius: AuraRadius.mdBr,
                              onTap: () => Navigator.of(ctx).pop(entry.key),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: AuraSpacing.md,
                                  vertical: AuraSpacing.md,
                                ),
                                decoration: BoxDecoration(
                                  color: sheetColors.surface,
                                  borderRadius: AuraRadius.mdBr,
                                  border: Border.all(color: sheetColors.border),
                                ),
                                child: Row(
                                  children: [
                                    Icon(icon, color: sheetColors.accent),
                                    const SizedBox(width: AuraSpacing.md),
                                    Expanded(
                                      child: Text(
                                        entry.value,
                                        style: AuraTypography.bodyMedium(sheetColors.textPrimary)
                                            .copyWith(fontWeight: FontWeight.w600),
                                      ),
                                    ),
                                    Icon(
                                      Icons.chevron_right_rounded,
                                      color: sheetColors.iconDefault,
                                    ),
                                  ],
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

  static Future<String?> _openExtraDetailsSheet(
    BuildContext context, {
    required AuraThemeColors colors,
    required String title,
  }) async {
    HapticFeedback.lightImpact();

    return showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        final sheetColors = AuraThemeColors.of(ctx);
        final controller = TextEditingController();

        final maxHeight = MediaQuery.of(ctx).size.height * 0.85;

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
              child: ConstrainedBox(
                constraints: BoxConstraints(maxHeight: maxHeight),
                child: SingleChildScrollView(
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
                          title,
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
            ),
          ),
        );
      },
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
