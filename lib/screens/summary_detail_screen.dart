import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';

import '../providers/auth_provider.dart';
import '../services/summaries_storage.dart';
import '../theme/aura_theme.dart';
import '../theme/aura_tokens.dart';

class SummaryDetailScreen extends StatefulWidget {
  const SummaryDetailScreen({
    super.key,
    required this.summary,
  });

  final SummarizedAudio summary;

  @override
  State<SummaryDetailScreen> createState() => _SummaryDetailScreenState();
}

class _SummaryDetailScreenState extends State<SummaryDetailScreen> {
  bool _isExportingPdf = false;

  String _displayTitle(String fileName) {
    final dot = fileName.lastIndexOf('.');
    if (dot <= 0) return fileName;
    return fileName.substring(0, dot);
  }

  String _safeFileComponent(String input) {
    final cleaned = input.replaceAll(RegExp(r'[<>:"/\\|?*]'), '_').trim();
    if (cleaned.isEmpty) return 'summary';
    return cleaned.length > 70 ? cleaned.substring(0, 70) : cleaned;
  }

  String _folderNameForUid(String? uid) {
    final normalized = uid?.trim();
    if (normalized == null || normalized.isEmpty) return '_guest';
    return normalized;
  }

  String _join(String a, String b) {
    final sep = Platform.pathSeparator;
    if (a.endsWith(sep)) return '$a$b';
    return '$a$sep$b';
  }

  Future<File> _exportPdf() async {
    final auth = AuraAuthProvider.of(context);
    final uid = auth.isGuest ? null : auth.user?.uid;

    final createdAt = DateTime.fromMillisecondsSinceEpoch(widget.summary.createdAtMs);
    final title = _displayTitle(widget.summary.fileName);

    final doc = pw.Document();
    doc.addPage(
      pw.Page(
        margin: const pw.EdgeInsets.all(32),
        build: (ctx) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                title,
                style: pw.TextStyle(
                  fontSize: 22,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 8),
              pw.Text('Created: ${createdAt.toIso8601String()}'),
              pw.SizedBox(height: 18),
              pw.Text(
                widget.summary.description,
                style: const pw.TextStyle(fontSize: 12),
              ),
            ],
          );
        },
      ),
    );

    final bytes = await doc.save();

    final docs = await getApplicationDocumentsDirectory();
    final exportDir = Directory(
      _join(
        _join(
          _join(docs.path, 'summaries'),
          _folderNameForUid(uid),
        ),
        'exports',
      ),
    );
    if (!await exportDir.exists()) {
      await exportDir.create(recursive: true);
    }

    final fileName = '${_safeFileComponent(title)}_summary_${widget.summary.createdAtMs}.pdf';
    final outFile = File(_join(exportDir.path, fileName));
    await outFile.writeAsBytes(bytes, flush: true);
    return outFile;
  }

  Future<void> _onTapPdf() async {
    if (_isExportingPdf) return;
    HapticFeedback.lightImpact();

    setState(() => _isExportingPdf = true);
    try {
      final file = await _exportPdf();
      if (!mounted) return;
      await Share.shareXFiles(
        [XFile(file.path)],
        subject: _displayTitle(widget.summary.fileName),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Could not export PDF.'),
          backgroundColor: AuraThemeColors.of(context).surface,
        ),
      );
    } finally {
      if (mounted) setState(() => _isExportingPdf = false);
    }
  }

  Future<void> _onTapShare() async {
    HapticFeedback.lightImpact();

    final title = _displayTitle(widget.summary.fileName);
    final text = widget.summary.description;

    try {
      await Share.share(text, subject: title);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Could not share.'),
          backgroundColor: AuraThemeColors.of(context).surface,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = AuraThemeColors.of(context);

    final title = _displayTitle(widget.summary.fileName);

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        backgroundColor: colors.background,
        surfaceTintColor: Colors.transparent,
        scrolledUnderElevation: 0,
        elevation: 0,
        title: Text(
          title,
          style: AuraTypography.titleLarge(colors.textPrimary),
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          IconButton(
            onPressed: _isExportingPdf ? null : _onTapPdf,
            icon: Icon(Icons.picture_as_pdf_rounded, color: colors.iconDefault),
            tooltip: 'Download PDF',
          ),
          IconButton(
            onPressed: _onTapShare,
            icon: Icon(Icons.share_rounded, color: colors.iconDefault),
            tooltip: 'Share',
          ),
          const SizedBox(width: AuraSpacing.xs),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.fromLTRB(
          AuraSpacing.base,
          AuraSpacing.lg,
          AuraSpacing.base,
          AuraSpacing.lg,
        ),
        child: Container(
          decoration: BoxDecoration(
            color: colors.surface,
            borderRadius: AuraRadius.mdBr,
            border: Border.all(color: colors.border),
            boxShadow: AuraElevation.low(Colors.black),
          ),
          padding: const EdgeInsets.all(AuraSpacing.lg),
          child: SingleChildScrollView(
            child: Text(
              widget.summary.description,
              style: AuraTypography.bodyMedium(colors.textPrimary),
            ),
          ),
        ),
      ),
    );
  }
}
