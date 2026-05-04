/// Model representing the response from the backend audio processing endpoint.
class AudioProcessResponse {
  const AudioProcessResponse({
    required this.transcript,
    required this.summary,
    this.summaryPoints = const [],
    this.translation,
    this.cost = 0.0,
  });

  /// The transcribed text from the audio file.
  final String transcript;

  /// The summarized version of the transcript.
  final String summary;

  /// Key summary points returned by the backend.
  final List<String> summaryPoints;

  /// Optional translated text (if translation was performed).
  final String? translation;

  /// The cost of the API processing (in dollars).
  final double cost;

  /// Converts JSON response from the backend into this model.
  factory AudioProcessResponse.fromJson(Map<String, dynamic> json) {
    // Backend payloads can be either flat:
    //   {"clean_transcript": "...", "summary": "..."}
    // or nested/wrapped:
    //   {"result": {"clean_transcript": "...", "summary": "..."}}
    // Some backends also return segment arrays.
    final rawTranscript = _readTranscript(json);

    // Prefer the plain text summary field when available.
    final rawSummaryText = _readSummaryText(json);
    final summaryPoints = _readSummaryPoints(json);

    // Some backends return a combined Markdown-ish "summary" blob that
    // contains sections like "### CLEANED TRANSCRIPT" and "### ENGLISH SUMMARY".
    final combinedSummaryBlob = _readSummaryBlob(json);
    final parsedSections = _parseSectionedSummary(combinedSummaryBlob);

    final transcript = _cleanDisplayText(
      rawTranscript.trim().isNotEmpty
          ? rawTranscript
          : parsedSections.cleanedTranscript,
    );

    final summary = _cleanDisplayText(
      rawSummaryText.trim().isNotEmpty
          ? rawSummaryText
          : parsedSections.englishSummary.trim().isNotEmpty
          ? parsedSections.englishSummary
          : combinedSummaryBlob,
    );

    return AudioProcessResponse(
      transcript: transcript,
      summary: summary,
      summaryPoints: summaryPoints,
      translation: _readNullableTextDeep(json, const [
        'translation',
        'translated_text',
        'translatedText',
        'english_translation',
        'englishTranslation',
      ]),
      cost: _readCostDeep(json),
    );
  }

  static String _readTranscript(Map<String, dynamic> json) {
    final text = _readFirstTextDeep(json, const [
      // Preferred cleaned transcript keys (common in current API responses).
      'cleaned_transcript_en',
      'cleanedTranscriptEn',
      'cleaned_transcript',
      'cleanedTranscript',
      'clean_transcript',
      'clean transcript',
      'cleaned transcript',
      'clean_transcription',
      'cleanTranscript',
      'cleanTranscriptText',
      'cleanedTranscriptText',
      'transcription',
      'transcript',
      'full_transcript',
    ]);
    if (text.trim().isNotEmpty) return text;

    final fromSegments = _readSegmentsTextDeep(json, const [
      'segments',
      'transcript_segments',
      'transcriptSegments',
      'chunks',
    ]);
    return fromSegments;
  }

  static String _readSummaryText(Map<String, dynamic> json) {
    return _readFirstTextDeep(json, const [
      'summary_text',
      'summaryText',
      'english_summary_text',
      'englishSummaryText',
    ]);
  }

  static List<String> _readSummaryPoints(Map<String, dynamic> json) {
    final value = _readFirstValueDeep(json, const [
      'summary_points',
      'summaryPoints',
      'bullets',
    ]);

    final items = <String>[];
    if (value is List) {
      for (final item in value) {
        final t = _cleanSummaryPoint(_extractText(item));
        if (t.isEmpty) continue;
        items.add(t);
      }
    } else if (value is String) {
      for (final line in value.split(RegExp(r'[\r\n]+'))) {
        final t = _cleanSummaryPoint(line);
        if (t.isEmpty) continue;
        items.add(t);
      }
    }

    return List.unmodifiable(items);
  }

  static String _cleanSummaryPoint(String text) {
    return text.replaceFirst(RegExp(r'^\s*(?:[-*•]|\d+[.)])\s+'), '').trim();
  }

  static String _readSummaryBlob(Map<String, dynamic> json) {
    return _readFirstTextDeep(json, const [
      // The combined blob often lives under "summary".
      'summary',
      'summarized_text',
      'summarizedText',
    ]);
  }

  static String _cleanDisplayText(String text) {
    final normalized = text.replaceAll('\r\n', '\n').replaceAll('\r', '\n');
    final withoutHeadings = _stripMarkdownHeadings(normalized);
    return withoutHeadings.trim();
  }

  static String _stripMarkdownHeadings(String text) {
    // Removes heading lines like "### CLEANED TRANSCRIPT".
    final lines = text.split('\n');
    final kept = <String>[];
    for (final line in lines) {
      if (RegExp(r'^\s*#{1,6}\s+').hasMatch(line)) continue;
      kept.add(line);
    }
    return kept.join('\n');
  }

  static _SectionedSummary _parseSectionedSummary(String text) {
    final cleaned = _extractSection(text, 'CLEANED TRANSCRIPT');
    final english = _extractSection(text, 'ENGLISH SUMMARY');
    return _SectionedSummary(
      cleanedTranscript: _cleanDisplayText(cleaned),
      englishSummary: _cleanDisplayText(english),
    );
  }

  static String _extractSection(String text, String heading) {
    if (text.trim().isEmpty) return '';

    final normalized = text.replaceAll('\r\n', '\n').replaceAll('\r', '\n');
    final pattern = '^\\s*(?:#{1,6}\\s*)?${RegExp.escape(heading)}\\s*\$';
    final startRe = RegExp(pattern, multiLine: true, caseSensitive: false);
    final start = startRe.firstMatch(normalized);
    if (start == null) return '';

    final contentStart = start.end;
    final remainder = normalized.substring(contentStart);
    final nextHeading = RegExp(
      r'^\s*#{1,6}\s+.+$',
      multiLine: true,
    ).firstMatch(remainder);

    final content = nextHeading == null
        ? remainder
        : remainder.substring(0, nextHeading.start);

    return content.trim();
  }

  static String _readSegmentsTextDeep(
    Map<String, dynamic> json,
    List<String> keys,
  ) {
    final segmentsValue = _readFirstValueDeep(json, keys);
    if (segmentsValue is! List) return '';

    final buffer = StringBuffer();
    for (final seg in segmentsValue) {
      final text = _extractText(seg).trim();
      if (text.isEmpty) continue;
      if (buffer.isNotEmpty) buffer.writeln();
      buffer.write(text);
    }
    return buffer.toString();
  }

  static String _extractText(dynamic value) {
    if (value == null) return '';
    if (value is String) return value;

    if (value is List) {
      final buffer = StringBuffer();
      for (final item in value) {
        final t = _extractText(item).trim();
        if (t.isEmpty) continue;
        if (buffer.isNotEmpty) buffer.writeln();
        buffer.write(t);
      }
      return buffer.toString();
    }

    // Some backends return objects for text fields, e.g. {"text": "..."}.
    if (value is Map) {
      const candidateKeys = [
        'text',
        'value',
        'content',
        'clean_transcript',
        'cleanTranscript',
        'cleaned_transcript',
        'cleanedTranscript',
        'clean',
        'transcript',
        'summary',
      ];
      for (final key in candidateKeys) {
        final nested = value[key];
        if (nested == null) continue;
        final t = _extractText(nested).trim();
        if (t.isNotEmpty) return t;
      }
      return value.toString();
    }

    return value.toString();
  }

  static Object? _readFirstValueDeep(
    Map<String, dynamic> json,
    List<String> keys,
  ) {
    for (final key in keys) {
      if (json.containsKey(key)) return json[key];
    }

    // Common wrappers.
    const wrappers = ['data', 'result', 'payload', 'output', 'response'];
    for (final wrapper in wrappers) {
      final nested = json[wrapper];
      if (nested is Map<String, dynamic>) {
        final found = _readFirstValueDeep(nested, keys);
        if (found != null) return found;
      }
    }

    // Fallback: depth-limited scan (handles unknown nesting).
    return _scanForKeys(json, keys, maxDepth: 4);
  }

  static Object? _scanForKeys(
    Object? node,
    List<String> keys, {
    required int maxDepth,
  }) {
    if (node == null || maxDepth < 0) return null;

    if (node is Map) {
      for (final key in keys) {
        if (node.containsKey(key)) return node[key];
      }
      for (final value in node.values) {
        final found = _scanForKeys(value, keys, maxDepth: maxDepth - 1);
        if (found != null) return found;
      }
      return null;
    }

    if (node is List) {
      for (final value in node) {
        final found = _scanForKeys(value, keys, maxDepth: maxDepth - 1);
        if (found != null) return found;
      }
      return null;
    }

    return null;
  }

  static String _readFirstTextDeep(
    Map<String, dynamic> json,
    List<String> keys,
  ) {
    final value = _readFirstValueDeep(json, keys);
    return _extractText(value);
  }

  static String? _readNullableTextDeep(
    Map<String, dynamic> json,
    List<String> keys,
  ) {
    final text = _readFirstTextDeep(json, keys).trim();
    return text.isEmpty ? null : text;
  }

  static double _readCostDeep(Map<String, dynamic> json) {
    final cost = _readFirstValueDeep(json, const [
      'cost',
      'total_cost',
      'totalCost',
    ]);
    if (cost == null) return 0.0;
    if (cost is num) return cost.toDouble();
    if (cost is String) {
      final parsed = double.tryParse(cost.trim());
      if (parsed != null) return parsed;
    }

    // Handle object-shaped cost payloads, e.g. {"usd": 0.0123}.
    if (cost is Map) {
      const candidateKeys = [
        'usd',
        'total',
        'total_usd',
        'value',
        'amount',
        'cost',
        'total_cost',
      ];

      for (final key in candidateKeys) {
        final value = cost[key];
        if (value is num) return value.toDouble();
        if (value is String) {
          final parsed = double.tryParse(value.trim());
          if (parsed != null) return parsed;
        }
      }
    }

    return 0.0;
  }

  /// Converts this model to JSON format.
  Map<String, dynamic> toJson() => {
    'transcript': transcript,
    'summary': summary,
    'summaryPoints': summaryPoints,
    'translation': translation,
    'cost': cost,
  };

  @override
  String toString() {
    return 'AudioProcessResponse('
        'transcript: ${transcript.substring(0, transcript.length > 50 ? 50 : transcript.length)}, '
        'summary: ${summary.substring(0, summary.length > 50 ? 50 : summary.length)}, '
        'summaryPoints: ${summaryPoints.length}, '
        'translation: $translation, '
        'cost: $cost)';
  }
}

class _SectionedSummary {
  const _SectionedSummary({
    required this.cleanedTranscript,
    required this.englishSummary,
  });

  final String cleanedTranscript;
  final String englishSummary;
}
