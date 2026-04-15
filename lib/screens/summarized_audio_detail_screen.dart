import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

import '../services/pdf_generator.dart';
import '../services/summaries_storage.dart';
import '../theme/aura_theme.dart';
import '../theme/aura_tokens.dart';

class SummarizedAudioDetailScreen extends StatefulWidget {
  const SummarizedAudioDetailScreen({
    super.key,
    required this.summary,
  });

  final SummarizedAudio summary;

  @override
  State<SummarizedAudioDetailScreen> createState() => _SummarizedAudioDetailScreenState();
}

class _SummarizedAudioDetailScreenState extends State<SummarizedAudioDetailScreen> {
  int _selectedTabIndex = 0; // 0: Summary, 1: Transcript, 2: Translation (if available)

  bool get _hasTranslation {
    final t = widget.summary.translation;
    return t != null && t.trim().isNotEmpty;
  }

  String _displayTitle(String fileName) {
    final dot = fileName.lastIndexOf('.');
    if (dot <= 0) return fileName;
    return fileName.substring(0, dot);
  }

  String _currentTabText() {
    switch (_selectedTabIndex) {
      case 0:
        return widget.summary.summary;
      case 1:
        return widget.summary.transcript;
      case 2:
        return widget.summary.translation ?? '';
      default:
        return '';
    }
  }

  void _copyCurrentTab() {
    HapticFeedback.lightImpact();
    final text = _currentTabText();
    Clipboard.setData(ClipboardData(text: text));
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Copied to clipboard'),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _shareText() {
    HapticFeedback.lightImpact();

    final title = _displayTitle(widget.summary.fileName);
    final category = widget.summary.category.isEmpty ? 'Unknown' : widget.summary.category;

    final buffer = StringBuffer();
    buffer.writeln('AURA Summary');
    buffer.writeln('============\n');
    buffer.writeln('File: $title');
    buffer.writeln('Category: $category');
    buffer.writeln('Cost: \$${widget.summary.cost.toStringAsFixed(4)}\n');

    buffer.writeln('SUMMARY');
    buffer.writeln('-------');
    buffer.writeln(widget.summary.summary);

    buffer.writeln('\nTRANSCRIPT');
    buffer.writeln('----------');
    buffer.writeln(widget.summary.transcript);

    final translation = widget.summary.translation;
    if (translation != null && translation.trim().isNotEmpty) {
      buffer.writeln('\nTRANSLATION');
      buffer.writeln('-----------');
      buffer.writeln(translation);
    }

    Share.share(
      buffer.toString(),
      subject: 'AURA Summary - $title',
    );
  }

  Future<void> _exportPdf() async {
    HapticFeedback.lightImpact();
    final colors = AuraThemeColors.of(context);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Generating PDF...'),
        duration: const Duration(seconds: 1),
        behavior: SnackBarBehavior.floating,
      ),
    );

    final pdfFile = await PdfGenerator.generateSummaryPdf(
      fileName: widget.summary.fileName,
      category: widget.summary.category.isEmpty ? 'Unknown' : widget.summary.category,
      summary: widget.summary.summary,
      transcript: widget.summary.transcript,
      translation: widget.summary.translation,
      cost: widget.summary.cost,
    );

    if (!mounted) return;

    if (pdfFile == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Failed to generate PDF'),
          backgroundColor: colors.accent.withOpacity(0.8),
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    await Share.shareXFiles(
      [XFile(pdfFile.path)],
      subject: 'AURA Summary - ${_displayTitle(widget.summary.fileName)}',
    );

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('PDF saved to: ${pdfFile.path}'),
        duration: const Duration(seconds: 3),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = AuraThemeColors.of(context);
    final title = _displayTitle(widget.summary.fileName);
    final category = widget.summary.category.isEmpty ? 'Unknown' : widget.summary.category;

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
          'Summary',
          style: AuraTypography.titleLarge(colors.textPrimary),
        ),
        centerTitle: false,
        actions: [
          IconButton(
            icon: Icon(Icons.share_rounded, color: colors.accent),
            onPressed: _shareText,
            tooltip: 'Share',
          ),
          IconButton(
            icon: Icon(Icons.picture_as_pdf_rounded, color: colors.accent),
            onPressed: _exportPdf,
            tooltip: 'Export PDF',
          ),
          const SizedBox(width: AuraSpacing.sm),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              color: colors.surfaceElevated,
              padding: const EdgeInsets.all(AuraSpacing.base),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: AuraTypography.titleMedium(colors.textPrimary),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: AuraSpacing.xs),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AuraSpacing.sm,
                          vertical: AuraSpacing.xs,
                        ),
                        decoration: BoxDecoration(
                          color: colors.accent.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(AuraRadius.md),
                        ),
                        child: Text(
                          category,
                          style: AuraTypography.bodySmall(colors.accent),
                        ),
                      ),
                      const Spacer(),
                      Text(
                        'Cost: \$${widget.summary.cost.toStringAsFixed(4)}',
                        style: AuraTypography.bodySmall(colors.textSecondary),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Container(
              color: colors.surface,
              padding: const EdgeInsets.symmetric(horizontal: AuraSpacing.base),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _buildTabButton('Summary', 0, colors),
                    _buildTabButton('Transcript', 1, colors),
                    if (_hasTranslation) _buildTabButton('Translation', 2, colors),
                  ],
                ),
              ),
            ),
            Container(
              color: colors.surface,
              padding: const EdgeInsets.all(AuraSpacing.base),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _currentTabText(),
                    style: AuraTypography.bodyMedium(colors.textPrimary).copyWith(height: 1.6),
                  ),
                  const SizedBox(height: AuraSpacing.base),
                  Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: _copyCurrentTab,
                      borderRadius: BorderRadius.circular(AuraRadius.md),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          vertical: AuraSpacing.sm,
                          horizontal: AuraSpacing.base,
                        ),
                        decoration: BoxDecoration(
                          color: colors.accentSoft.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(AuraRadius.md),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.content_copy, size: 18, color: colors.accentSoft),
                            const SizedBox(width: AuraSpacing.xs),
                            Text(
                              'Copy text',
                              style: AuraTypography.button(colors.accentSoft),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTabButton(String label, int index, AuraThemeColors colors) {
    final isSelected = _selectedTabIndex == index;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          HapticFeedback.lightImpact();
          setState(() => _selectedTabIndex = index);
        },
        child: Container(
          padding: const EdgeInsets.symmetric(
            vertical: AuraSpacing.base,
            horizontal: AuraSpacing.sm,
          ),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: isSelected ? colors.accent : Colors.transparent,
                width: 2,
              ),
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: isSelected ? colors.accent : colors.textSecondary,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
              height: 1.5,
            ),
          ),
        ),
      ),
    );
  }
}
