import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

import '../providers/auth_provider.dart';
import '../screens/pdf_preview_screen.dart';

import '../services/pdf_generator.dart';
import '../services/pdf_saf_service.dart';
import '../services/summaries_library_events.dart';
import '../services/summaries_storage.dart';
import '../theme/aura_theme.dart';
import '../theme/aura_tokens.dart';
import '../widgets/aura_snack_bar.dart';

class SummarizedAudioDetailScreen extends StatefulWidget {
  const SummarizedAudioDetailScreen({super.key, required this.summary});

  final SummarizedAudio summary;

  @override
  State<SummarizedAudioDetailScreen> createState() =>
      _SummarizedAudioDetailScreenState();
}

class _SummarizedAudioDetailScreenState
    extends State<SummarizedAudioDetailScreen> {
  String? _effectiveUid;
  String? _pdfUri;
  bool _isPdfBusy = false;

  @override
  void initState() {
    super.initState();
    _pdfUri = widget.summary.pdfUri;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final authProvider = AuraAuthProvider.of(context);
    final nextUid = authProvider.isGuest ? null : authProvider.user?.uid;
    if (nextUid == _effectiveUid) return;
    _effectiveUid = nextUid;
  }

  String _displayTitle(String fileName) {
    final dot = fileName.lastIndexOf('.');
    if (dot <= 0) return fileName;
    return fileName.substring(0, dot);
  }

  String _suggestedPdfFileName() {
    final title = _displayTitle(widget.summary.fileName).trim();
    final safe = title.isEmpty
        ? 'AURA_Summary'
        : title.replaceAll(RegExp(r'[\\/\n\r\t]'), '_');
    return '$safe.pdf';
  }

  void _copyToClipboard(String text) {
    HapticFeedback.lightImpact();
    Clipboard.setData(ClipboardData(text: text));
    if (!mounted) return;

    showAuraSnackBar(
      context,
      message: 'Copied to clipboard',
      duration: auraBriefSnackBarDuration,
    );
  }

  void _shareText() {
    HapticFeedback.lightImpact();

    final title = _displayTitle(widget.summary.fileName);
    final category = widget.summary.category.isEmpty
        ? 'Unknown'
        : widget.summary.category;

    final resolved = _resolveDisplayedTexts();

    final buffer = StringBuffer();
    buffer.writeln('AURA Summary');
    buffer.writeln('============\n');
    buffer.writeln('File: $title');
    buffer.writeln('Category: $category');

    buffer.writeln('SUMMARY');
    buffer.writeln('-------');
    buffer.writeln(resolved.summary);

    if (resolved.summaryPoints.isNotEmpty) {
      buffer.writeln('\nSUMMARY POINTS');
      buffer.writeln('--------------');
      buffer.writeln(_formatSummaryPoints(resolved.summaryPoints));
    }

    buffer.writeln('\nTRANSCRIPT');
    buffer.writeln('----------');
    buffer.writeln(resolved.transcript);

    final translation = widget.summary.translation;
    if (translation != null && translation.trim().isNotEmpty) {
      buffer.writeln('\nTRANSLATION');
      buffer.writeln('-----------');
      buffer.writeln(translation);
    }

    Share.share(buffer.toString(), subject: 'AURA Summary - $title');
  }

  Future<void> _exportPdf() async {
    if (_isPdfBusy) return;

    HapticFeedback.lightImpact();
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    final colors = AuraThemeColors.of(context);

    setState(() => _isPdfBusy = true);
    try {
      final existingUri = _pdfUri?.trim();
      if (existingUri != null && existingUri.isNotEmpty) {
        try {
          final opened = await PdfSafService.openPdfUri(uri: existingUri);
          if (opened) return;
        } catch (_) {
          // Fall through to preview+download.
        }

        // Clear stale URI so the next steps re-download.
        final updated = await SummariesStorage.updatePdfUri(
          uid: _effectiveUid,
          item: widget.summary,
          pdfUri: null,
        );
        if (updated != null) {
          SummariesLibraryEvents.notifyChanged();
        }
        _pdfUri = null;
      }

      if (!mounted) return;

      final resolved = _resolveDisplayedTexts();

      showAuraSnackBarWithMessenger(
        messenger,
        message: 'Preparing PDF...',
        duration: const Duration(seconds: 1),
      );

      final bytes = await PdfGenerator.generateSummaryPdfBytes(
        fileName: widget.summary.fileName,
        category: widget.summary.category.isEmpty
            ? 'Unknown'
            : widget.summary.category,
        summary: resolved.summary,
        summaryPoints: resolved.summaryPoints,
        transcript: resolved.transcript,
        translation: widget.summary.translation,
        cost: widget.summary.cost,
      );

      if (!mounted) return;

      if (bytes == null) {
        showAuraSnackBarWithMessenger(
          messenger,
          message: 'We could not create the PDF. Please try again.',
          duration: auraBriefSnackBarDuration,
          backgroundColor: colors.accent.withValues(alpha: 204),
        );
        return;
      }

      final savedUri = await navigator.push<String?>(
        MaterialPageRoute(
          builder: (_) => PdfPreviewScreen(
            pdfBytes: bytes,
            suggestedFileName: _suggestedPdfFileName(),
          ),
        ),
      );

      if (!mounted) return;

      if (savedUri == null || savedUri.trim().isEmpty) return;

      final updated = await SummariesStorage.updatePdfUri(
        uid: _effectiveUid,
        item: widget.summary,
        pdfUri: savedUri,
      );
      if (updated != null) {
        SummariesLibraryEvents.notifyChanged();
      }

      setState(() => _pdfUri = savedUri);

      showAuraSnackBarWithMessenger(
        messenger,
        message: 'PDF downloaded',
        duration: auraBriefSnackBarDuration,
      );
    } finally {
      if (mounted) {
        setState(() => _isPdfBusy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = AuraThemeColors.of(context);
    final title = _displayTitle(widget.summary.fileName);
    final category = widget.summary.category.isEmpty
        ? 'Unknown'
        : widget.summary.category;

    final resolved = _resolveDisplayedTexts();

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        backgroundColor: colors.background,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: colors.textPrimary),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'Summary Details',
          style: AuraTypography.titleLarge(colors.textPrimary),
        ),
        centerTitle: false,
        actions: [
          PopupMenuButton<String>(
            icon: Icon(Icons.more_vert_rounded, color: colors.textPrimary),
            color: colors.surface,
            shape: RoundedRectangleBorder(borderRadius: AuraRadius.mdBr),
            tooltip: 'More options',
            onSelected: (value) {
              switch (value) {
                case 'share':
                  _shareText();
                  break;
                case 'pdf':
                  if (!_isPdfBusy) _exportPdf();
                  break;
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem<String>(
                value: 'share',
                child: Row(
                  children: [
                    Icon(Icons.share_rounded, color: colors.accent, size: 20),
                    const SizedBox(width: AuraSpacing.md),
                    Text(
                      'Share',
                      style: AuraTypography.bodyMedium(colors.textPrimary),
                    ),
                  ],
                ),
              ),
              PopupMenuItem<String>(
                value: 'pdf',
                enabled: !_isPdfBusy,
                child: Row(
                  children: [
                    Icon(
                      Icons.picture_as_pdf_rounded,
                      color: _isPdfBusy ? colors.textTertiary : colors.accent,
                      size: 20,
                    ),
                    const SizedBox(width: AuraSpacing.md),
                    Text(
                      'Export PDF',
                      style: AuraTypography.bodyMedium(
                        _isPdfBusy ? colors.textTertiary : colors.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(width: AuraSpacing.xs),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AuraSpacing.base,
            AuraSpacing.lg,
            AuraSpacing.base,
            AuraSpacing.lg,
          ),
          child: SingleChildScrollView(
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
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _DetailMetaRow(
                        icon: Icons.headphones_rounded,
                        label: 'Audio',
                        value: title,
                        colors: colors,
                      ),
                      const SizedBox(height: AuraSpacing.md),
                      Container(height: 1, color: colors.border),
                      const SizedBox(height: AuraSpacing.md),
                      _DetailMetaRow(
                        icon: Icons.label_outline_rounded,
                        label: 'Category',
                        value: category,
                        colors: colors,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AuraSpacing.lg),
                _DropdownSection(
                  title: 'Cleaned transcript',
                  icon: Icons.subject_rounded,
                  text: resolved.transcript,
                  onCopy: () => _copyToClipboard(resolved.transcript),
                  initiallyExpanded: false,
                ),
                const SizedBox(height: AuraSpacing.base),
                if (resolved.summaryPoints.isNotEmpty) ...[
                  _DropdownSection(
                    title: 'Summary points',
                    icon: Icons.format_list_bulleted_rounded,
                    text: _formatSummaryPoints(resolved.summaryPoints),
                    onCopy: () => _copyToClipboard(
                      _formatSummaryPoints(resolved.summaryPoints),
                    ),
                    initiallyExpanded: true,
                  ),
                  const SizedBox(height: AuraSpacing.base),
                ],
                _DropdownSection(
                  title: 'Summary',
                  icon: Icons.summarize_rounded,
                  text: resolved.summary,
                  onCopy: () => _copyToClipboard(resolved.summary),
                  initiallyExpanded: true,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  ({String transcript, String summary, List<String> summaryPoints})
  _resolveDisplayedTexts() {
    final transcript = widget.summary.transcript.trim();
    final summary = widget.summary.summary.trim();
    final summaryPoints = widget.summary.summaryPoints
        .map((point) => point.trim())
        .where((point) => point.isNotEmpty)
        .toList(growable: false);

    // If the summary contains section headings from the backend, split it so
    // "Cleaned transcript" and "Summary" render separately.
    if (_looksSectioned(summary)) {
      final cleanedTranscript = _cleanDisplayText(
        _extractSection(summary, 'CLEANED TRANSCRIPT'),
      );
      final englishSummary = _cleanDisplayText(
        _extractSection(summary, 'ENGLISH SUMMARY'),
      );

      final effectiveTranscript = transcript.isNotEmpty
          ? _cleanDisplayText(transcript)
          : cleanedTranscript;

      final effectiveSummary = englishSummary.isNotEmpty
          ? englishSummary
          : _cleanDisplayText(summary);

      return (
        transcript: effectiveTranscript,
        summary: effectiveSummary,
        summaryPoints: summaryPoints,
      );
    }

    return (
      transcript: _cleanDisplayText(transcript),
      summary: _cleanDisplayText(summary),
      summaryPoints: summaryPoints,
    );
  }

  String _formatSummaryPoints(List<String> points) {
    return points
        .map((point) => point.trim())
        .where((point) => point.isNotEmpty)
        .map((point) => '- $point')
        .join('\n');
  }

  bool _looksSectioned(String text) {
    final upper = text.toUpperCase();
    return upper.contains('CLEANED TRANSCRIPT') ||
        upper.contains('ENGLISH SUMMARY') ||
        text.contains('###');
  }

  String _cleanDisplayText(String text) {
    final normalized = text.replaceAll('\r\n', '\n').replaceAll('\r', '\n');
    final lines = normalized.split('\n');
    final kept = <String>[];
    for (final line in lines) {
      if (RegExp(r'^\s*#{1,6}\s+').hasMatch(line)) continue;
      kept.add(line);
    }
    return kept.join('\n').trim();
  }

  String _extractSection(String text, String heading) {
    if (text.trim().isEmpty) return '';

    final normalized = text.replaceAll('\r\n', '\n').replaceAll('\r', '\n');
    final pattern = '^\\s*(?:#{1,6}\\s*)?${RegExp.escape(heading)}\\s*\$';
    final startRe = RegExp(pattern, multiLine: true, caseSensitive: false);
    final start = startRe.firstMatch(normalized);
    if (start == null) return '';

    final remainder = normalized.substring(start.end);
    final nextHeading = RegExp(
      r'^\s*#{1,6}\s+.+$',
      multiLine: true,
    ).firstMatch(remainder);

    final content = nextHeading == null
        ? remainder
        : remainder.substring(0, nextHeading.start);

    return content.trim();
  }
}

class _DropdownSection extends StatelessWidget {
  const _DropdownSection({
    required this.title,
    required this.icon,
    required this.text,
    required this.onCopy,
    this.initiallyExpanded = false,
  });

  final String title;
  final IconData icon;
  final String text;
  final VoidCallback onCopy;
  final bool initiallyExpanded;

  @override
  Widget build(BuildContext context) {
    final colors = AuraThemeColors.of(context);
    final effectiveText = text.trim().isEmpty
        ? 'No text available.'
        : text.trim();

    return Container(
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: AuraRadius.lgBr,
        border: Border.all(color: colors.border),
        boxShadow: AuraElevation.low(Colors.black),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ClipRRect(
          borderRadius: AuraRadius.lgBr,
          child: ExpansionTile(
            initiallyExpanded: initiallyExpanded,
            tilePadding: const EdgeInsets.symmetric(
              horizontal: AuraSpacing.lg,
              vertical: AuraSpacing.xs,
            ),
            childrenPadding: const EdgeInsets.fromLTRB(
              AuraSpacing.lg,
              0,
              AuraSpacing.lg,
              AuraSpacing.lg,
            ),
            iconColor: colors.textSecondary,
            collapsedIconColor: colors.textSecondary,
            leading: Icon(icon, color: colors.accentSoft),
            title: Text(
              title,
              style: AuraTypography.titleSmall(
                colors.textPrimary,
              ).copyWith(fontWeight: FontWeight.w600),
            ),
            children: [
              SelectableText(
                effectiveText,
                style: AuraTypography.bodyMedium(
                  colors.textPrimary,
                ).copyWith(height: 1.6),
              ),
              const SizedBox(height: AuraSpacing.base),
              Align(
                alignment: Alignment.centerRight,
                child: OutlinedButton.icon(
                  onPressed: onCopy,
                  icon: const Icon(Icons.content_copy_rounded, size: 18),
                  label: const Text('Copy'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: colors.textPrimary,
                    side: BorderSide(color: colors.border),
                    padding: const EdgeInsets.symmetric(
                      vertical: AuraSpacing.sm,
                      horizontal: AuraSpacing.base,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: AuraRadius.mdBr,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DetailMetaRow extends StatelessWidget {
  const _DetailMetaRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.colors,
  });

  final IconData icon;
  final String label;
  final String value;
  final AuraThemeColors colors;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: colors.textTertiary, size: 14),
        const SizedBox(width: 6),
        Text(
          label,
          style: AuraTypography.caption(
            colors.textTertiary,
          ).copyWith(letterSpacing: 0.4),
        ),
        const SizedBox(width: AuraSpacing.sm),
        Expanded(
          child: Text(
            value,
            style: AuraTypography.bodyMedium(
              colors.textPrimary,
            ).copyWith(fontWeight: FontWeight.w600),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}
