import 'package:flutter_test/flutter_test.dart';

import 'package:aura/models/audio_process_response.dart';

void main() {
  group('AudioProcessResponse', () {
    test('parses flat summary_points separately from summary text', () {
      final response = AudioProcessResponse.fromJson({
        'cleaned_transcript_en': 'Clean transcript',
        'summary_text': 'Paragraph summary.',
        'summary_points': ['First point', 'Second point'],
      });

      expect(response.transcript, 'Clean transcript');
      expect(response.summary, 'Paragraph summary.');
      expect(response.summaryPoints, ['First point', 'Second point']);
    });

    test('parses nested summaryPoints from wrapped backend payloads', () {
      final response = AudioProcessResponse.fromJson({
        'result': {
          'cleaned_transcript_en': 'Nested transcript',
          'summary_text': 'Nested summary.',
          'summaryPoints': ['Nested point'],
        },
      });

      expect(response.transcript, 'Nested transcript');
      expect(response.summary, 'Nested summary.');
      expect(response.summaryPoints, ['Nested point']);
    });

    test('returns an empty summaryPoints list when missing', () {
      final response = AudioProcessResponse.fromJson({
        'cleaned_transcript_en': 'Clean transcript',
        'summary_text': 'Paragraph summary.',
      });

      expect(response.summaryPoints, isEmpty);
    });

    test(
      'does not infer summary points from legacy sectioned summary blobs',
      () {
        final response = AudioProcessResponse.fromJson({
          'summary': '''
### CLEANED TRANSCRIPT
Clean transcript

### ENGLISH SUMMARY
- Legacy point
- Another legacy point
''',
        });

        expect(response.transcript, 'Clean transcript');
        expect(response.summary, '- Legacy point\n- Another legacy point');
        expect(response.summaryPoints, isEmpty);
      },
    );
  });
}
