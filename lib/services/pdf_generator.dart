import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

class PdfGenerator {
  static Future<File?> generateSummaryPdf({
    required String fileName,
    required String category,
    required String summary,
    required String transcript,
    required String? translation,
    required double cost,
  }) async {
    try {
      final pdf = pw.Document();

      // Create PDF content
      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(40),
          build: (context) => [
            // Title
            pw.Text(
              'Audio Summary Report',
              style: pw.TextStyle(
                fontSize: 24,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
            pw.SizedBox(height: 20),

            // File info box
            pw.Container(
              padding: const pw.EdgeInsets.all(15),
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: PdfColors.grey400),
                borderRadius: const pw.BorderRadius.all(pw.Radius.circular(5)),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    'File Information',
                    style: pw.TextStyle(
                      fontSize: 12,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.SizedBox(height: 8),
                  pw.Text(
                    'File Name: $fileName',
                    style: const pw.TextStyle(fontSize: 11),
                  ),
                  pw.SizedBox(height: 4),
                  pw.Text(
                    'Category: $category',
                    style: const pw.TextStyle(fontSize: 11),
                  ),
                  pw.SizedBox(height: 4),
                  pw.Text(
                    'Generated: ${_formatDateTime(DateTime.now())}',
                    style: const pw.TextStyle(fontSize: 11),
                  ),
                  pw.SizedBox(height: 4),
                  pw.Text(
                    'Cost: \$${cost.toStringAsFixed(4)}',
                    style: const pw.TextStyle(fontSize: 11),
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 20),

            // Summary section
            pw.Text(
              'Summary',
              style: pw.TextStyle(
                fontSize: 16,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
            pw.SizedBox(height: 8),
            pw.Paragraph(
              text: summary,
              textAlign: pw.TextAlign.justify,
            ),
            pw.SizedBox(height: 20),

            // Transcript section
            pw.Text(
              'Full Transcript',
              style: pw.TextStyle(
                fontSize: 16,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
            pw.SizedBox(height: 8),
            pw.Paragraph(
              text: transcript,
              textAlign: pw.TextAlign.justify,
            ),

            // Translation section if available
            if (translation != null && translation.isNotEmpty) ...[
              pw.SizedBox(height: 20),
              pw.Text(
                'Translation',
                style: pw.TextStyle(
                  fontSize: 16,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 8),
              pw.Paragraph(
                text: translation,
                textAlign: pw.TextAlign.justify,
              ),
            ],
          ],
        ),
      );

      // Save PDF to documents directory
      final dir = await getApplicationDocumentsDirectory();
      final pdfFile = File(
        '${dir.path}/pdf_exports/${_sanitizeFileName(fileName)}_${DateTime.now().millisecondsSinceEpoch}.pdf',
      );

      // Create directory if it doesn't exist
      await pdfFile.parent.create(recursive: true);
      await pdfFile.writeAsBytes(await pdf.save());

      return pdfFile;
    } catch (e) {
      return null;
    }
  }

  static String _formatDateTime(DateTime dateTime) {
    final monthNames = ['', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 
                        'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    final month = monthNames[dateTime.month];
    final day = dateTime.day;
    final year = dateTime.year;
    final hour = dateTime.hour.toString().padLeft(2, '0');
    final minute = dateTime.minute.toString().padLeft(2, '0');
    return '$month $day, $year $hour:$minute';
  }

  static String _sanitizeFileName(String fileName) {
    // Remove file extension if present
    final name = fileName.contains('.') 
        ? fileName.substring(0, fileName.lastIndexOf('.'))
        : fileName;
    
    // Replace invalid characters
    return name.replaceAll(RegExp(r'[^\w\s-]'), '_').replaceAll(RegExp(r'\s+'), '_');
  }
}
