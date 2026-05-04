import 'package:flutter_test/flutter_test.dart';

import 'package:aura/services/summaries_storage.dart';

void main() {
  group('SummarizedAudio', () {
    test('preserves summaryPoints through JSON round trip', () {
      const item = SummarizedAudio(
        filePath: '/recordings/lecture.m4a',
        fileName: 'lecture.m4a',
        createdAtMs: 123,
        description: 'Lecture',
        summary: 'Paragraph summary.',
        summaryPoints: ['First point', 'Second point'],
        transcript: 'Transcript text.',
        category: 'Lecture / class',
        pdfUri: 'content://pdf',
      );

      final decoded = SummarizedAudio.fromJson(item.toJson());

      expect(decoded, isNotNull);
      expect(decoded!.summaryPoints, ['First point', 'Second point']);
      expect(decoded.summary, item.summary);
      expect(decoded.transcript, item.transcript);
      expect(decoded.pdfUri, item.pdfUri);
    });

    test(
      'defaults summaryPoints to an empty list for older saved summaries',
      () {
        final decoded = SummarizedAudio.fromJson({
          'filePath': '/recordings/lecture.m4a',
          'fileName': 'lecture.m4a',
          'createdAtMs': 123,
          'description': 'Lecture',
          'summary': 'Paragraph summary.',
          'transcript': 'Transcript text.',
        });

        expect(decoded, isNotNull);
        expect(decoded!.summaryPoints, isEmpty);
      },
    );
  });
}
