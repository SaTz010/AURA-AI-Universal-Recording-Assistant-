import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:printing/printing.dart';

import '../services/pdf_saf_service.dart';
import '../theme/aura_theme.dart';
import '../theme/aura_tokens.dart';

class PdfPreviewScreen extends StatefulWidget {
  const PdfPreviewScreen({
    super.key,
    required this.pdfBytes,
    required this.suggestedFileName,
  });

  final Uint8List pdfBytes;
  final String suggestedFileName;

  @override
  State<PdfPreviewScreen> createState() => _PdfPreviewScreenState();
}

class _PdfPreviewScreenState extends State<PdfPreviewScreen> {
  bool _isSaving = false;

  Future<void> _download() async {
    if (_isSaving) return;

    HapticFeedback.lightImpact();
    final colors = AuraThemeColors.of(context);

    if (!Platform.isAndroid) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Download is only supported on Android.'),
          behavior: SnackBarBehavior.floating,
          backgroundColor: colors.surface,
        ),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      final uri = await PdfSafService.createPdfDocument(
        suggestedName: widget.suggestedFileName,
      );
      if (!mounted) return;

      if (uri == null || uri.trim().isEmpty) {
        setState(() => _isSaving = false);
        return;
      }

      final ok = await PdfSafService.writeBytesToUri(
        uri: uri,
        bytes: widget.pdfBytes,
      );

      if (!mounted) return;

      if (!ok) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Failed to save PDF.'),
            behavior: SnackBarBehavior.floating,
            backgroundColor: colors.surface,
          ),
        );
        setState(() => _isSaving = false);
        return;
      }

      Navigator.of(context).pop(uri);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Failed to save PDF.'),
          behavior: SnackBarBehavior.floating,
          backgroundColor: colors.surface,
        ),
      );
      setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = AuraThemeColors.of(context);

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        backgroundColor: colors.background,
        elevation: 0,
        title: Text(
          'PDF Preview',
          style: AuraTypography.titleLarge(colors.textPrimary),
        ),
        centerTitle: false,
        actions: [
          IconButton(
            icon: _isSaving
                ? SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: colors.accent,
                    ),
                  )
                : Icon(Icons.download_rounded, color: colors.accent),
            tooltip: 'Download',
            onPressed: _isSaving ? null : _download,
          ),
          const SizedBox(width: AuraSpacing.sm),
        ],
      ),
      body: PdfPreview(
        build: (_) async => widget.pdfBytes,
        allowSharing: false,
        allowPrinting: false,
        canChangeOrientation: false,
        canChangePageFormat: false,
        canDebug: false,
      ),
    );
  }
}
