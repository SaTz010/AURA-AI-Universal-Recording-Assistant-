import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

import '../models/audio_process_response.dart';
import '../services/pdf_generator.dart';
import '../theme/aura_theme.dart';
import '../theme/aura_tokens.dart';

class AudioProcessResultScreen extends StatefulWidget {
  const AudioProcessResultScreen({
    super.key,
    required this.response,
    required this.audioFileName,
    required this.category,
  });

  final AudioProcessResponse response;
  final String audioFileName;
  final String category;

  @override
  State<AudioProcessResultScreen> createState() => _AudioProcessResultScreenState();
}

class _AudioProcessResultScreenState extends State<AudioProcessResultScreen> {
  int _selectedTabIndex = 0; // 0: Summary, 1: Transcript, 2: Translation (if available)

  String _getDisplayFileName() {
    final dot = widget.audioFileName.lastIndexOf('.');
    if (dot <= 0) return widget.audioFileName;
    return widget.audioFileName.substring(0, dot);
  }

  void _copyToClipboard(String text) {
    HapticFeedback.lightImpact();
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

  @override
  Widget build(BuildContext context) {
    final colors = AuraThemeColors.of(context);
    final hasTranslation = widget.response.translation != null && 
                          widget.response.translation!.isNotEmpty;

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        backgroundColor: colors.background,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: colors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Processing Result',
          style: AuraTypography.titleLarge(colors.textPrimary),
        ),
        centerTitle: false,
        actions: [
          IconButton(
            icon: Icon(Icons.picture_as_pdf_rounded, color: colors.accent),
            onPressed: _downloadPdf,
            tooltip: 'Download PDF',
          ),
          IconButton(
            icon: Icon(Icons.print_rounded, color: colors.accent),
            onPressed: _printPdf,
            tooltip: 'Print',
          ),
          SizedBox(width: AuraSpacing.sm),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with file info
            Container(
              color: colors.surfaceElevated,
              padding: EdgeInsets.all(AuraSpacing.base),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _getDisplayFileName(),
                    style: AuraTypography.titleMedium(colors.textPrimary),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  SizedBox(height: AuraSpacing.xs),
                  Row(
                    children: [
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: AuraSpacing.sm,
                          vertical: AuraSpacing.xs,
                        ),
                        decoration: BoxDecoration(
                          color: colors.accent.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(AuraRadius.md),
                        ),
                        child: Text(
                          widget.category,
                          style: AuraTypography.bodySmall(colors.accent),
                        ),
                      ),
                      const Spacer(),
                      Text(
                        'Cost: \$${widget.response.cost.toStringAsFixed(4)}',
                        style: AuraTypography.bodySmall(colors.textSecondary),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Tab bar for different content
            Container(
              color: colors.surface,
              padding: EdgeInsets.symmetric(horizontal: AuraSpacing.base),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _buildTabButton('Summary', 0, colors),
                    _buildTabButton('Transcript', 1, colors),
                    if (hasTranslation) _buildTabButton('Translation', 2, colors),
                  ],
                ),
              ),
            ),

            // Content based on selected tab
            Container(
              color: colors.surface,
              padding: EdgeInsets.all(AuraSpacing.base),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildContentSection(colors),
                  SizedBox(height: AuraSpacing.base),
                  _buildCopyButton(colors),
                ],
              ),
            ),

            // Action buttons
            Padding(
              padding: EdgeInsets.all(AuraSpacing.base),
              child: Row(
                children: [
                  Expanded(
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () {
                          HapticFeedback.lightImpact();
                          Navigator.pop(context);
                        },
                        borderRadius: BorderRadius.circular(AuraRadius.md),
                        child: Container(
                          padding: EdgeInsets.symmetric(
                            vertical: AuraSpacing.sm + AuraSpacing.xs,
                            horizontal: AuraSpacing.base,
                          ),
                          decoration: BoxDecoration(
                            border: Border.all(color: colors.border),
                            borderRadius: BorderRadius.circular(AuraRadius.md),
                          ),
                          child: Center(
                            child: Text(
                              'Back',
                              style: AuraTypography.button(colors.textPrimary),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: AuraSpacing.base),
                  Expanded(
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () {
                          HapticFeedback.lightImpact();
                          _shareResult();
                        },
                        borderRadius: BorderRadius.circular(AuraRadius.md),
                        child: Container(
                          padding: EdgeInsets.symmetric(
                            vertical: AuraSpacing.sm + AuraSpacing.xs,
                            horizontal: AuraSpacing.base,
                          ),
                          decoration: BoxDecoration(
                            color: colors.accent,
                            borderRadius: BorderRadius.circular(AuraRadius.md),
                          ),
                          child: Center(
                            child: Text(
                              'Share',
                              style: AuraTypography.button(colors.isDark ? AuraColors.spaceDark : AuraColors.lightBg),
                            ),
                          ),
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
          padding: EdgeInsets.symmetric(
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

  Widget _buildContentSection(AuraThemeColors colors) {
    String content;
    switch (_selectedTabIndex) {
      case 0:
        content = widget.response.summary;
        break;
      case 1:
        content = widget.response.transcript;
        break;
      case 2:
        content = widget.response.translation ?? '';
        break;
      default:
        content = '';
    }

    return Text(
      content,
      style: AuraTypography.bodyMedium(colors.textPrimary).copyWith(height: 1.6),
    );
  }

  Widget _buildCopyButton(AuraThemeColors colors) {
    String content;
    switch (_selectedTabIndex) {
      case 0:
        content = widget.response.summary;
        break;
      case 1:
        content = widget.response.transcript;
        break;
      case 2:
        content = widget.response.translation ?? '';
        break;
      default:
        content = '';
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _copyToClipboard(content),
        borderRadius: BorderRadius.circular(AuraRadius.md),
        child: Container(
          padding: EdgeInsets.symmetric(
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
              SizedBox(width: AuraSpacing.xs),
              Text(
                'Copy text',
                style: AuraTypography.button(colors.accentSoft),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _shareResult() {
    final buffer = StringBuffer();
    buffer.writeln('Audio Processing Result');
    buffer.writeln('=======================\n');
    buffer.writeln('File: ${_getDisplayFileName()}');
    buffer.writeln('Category: ${widget.category}');
    buffer.writeln('Cost: \$${widget.response.cost.toStringAsFixed(4)}\n');
    
    buffer.writeln('SUMMARY');
    buffer.writeln('-------');
    buffer.writeln(widget.response.summary);
    buffer.writeln('\nTRANSCRIPT');
    buffer.writeln('---------');
    buffer.writeln(widget.response.transcript);

    if (widget.response.translation != null && widget.response.translation!.isNotEmpty) {
      buffer.writeln('\nTRANSLATION');
      buffer.writeln('-----------');
      buffer.writeln(widget.response.translation);
    }

    HapticFeedback.lightImpact();
    Share.share(
      buffer.toString(),
      subject: 'Audio Summary - ${_getDisplayFileName()}',
    );
  }

  Future<void> _downloadPdf() async {
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
      fileName: widget.audioFileName,
      category: widget.category,
      summary: widget.response.summary,
      transcript: widget.response.transcript,
      translation: widget.response.translation,
      cost: widget.response.cost,
    );

    if (!mounted) return;

    if (pdfFile != null) {
      // Share the PDF file
      await Share.shareXFiles(
        [XFile(pdfFile.path)],
        subject: 'Audio Summary - ${_getDisplayFileName()}',
      );

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('PDF saved to: ${pdfFile.path}'),
          duration: const Duration(seconds: 3),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Failed to generate PDF'),
          backgroundColor: colors.accent.withOpacity(0.8),
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _printPdf() async {
    HapticFeedback.lightImpact();
    final colors = AuraThemeColors.of(context);
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Preparing for print...'),
        duration: const Duration(seconds: 1),
        behavior: SnackBarBehavior.floating,
      ),
    );

    final pdfFile = await PdfGenerator.generateSummaryPdf(
      fileName: widget.audioFileName,
      category: widget.category,
      summary: widget.response.summary,
      transcript: widget.response.transcript,
      translation: widget.response.translation,
      cost: widget.response.cost,
    );

    if (!mounted) return;

    if (pdfFile != null) {
      // For now, we'll share the file which allows the user to print
      // In a production app, you might use the printing package directly
      await Share.shareXFiles(
        [XFile(pdfFile.path)],
        subject: 'Print - Audio Summary - ${_getDisplayFileName()}',
      );

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Select a print app from the share menu'),
          duration: const Duration(seconds: 3),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Failed to generate PDF for printing'),
          backgroundColor: colors.accent.withOpacity(0.8),
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }
}
