/// Model representing the response from the backend audio processing endpoint.
class AudioProcessResponse {
  const AudioProcessResponse({
    required this.transcript,
    required this.summary,
    this.translation,
    this.cost = 0.0,
  });

  /// The transcribed text from the audio file.
  final String transcript;

  /// The summarized version of the transcript.
  final String summary;

  /// Optional translated text (if translation was performed).
  final String? translation;

  /// The cost of the API processing (in dollars).
  final double cost;

  /// Converts JSON response from the backend into this model.
  factory AudioProcessResponse.fromJson(Map<String, dynamic> json) {
    return AudioProcessResponse(
      transcript: _readText(json, 'transcript'),
      summary: _readText(json, 'summary'),
      translation: _readNullableText(json, 'translation'),
      cost: _readCost(json),
    );
  }

  static String _readText(Map<String, dynamic> json, String key) {
    final value = json[key];
    if (value == null) return '';
    if (value is String) return value;

    // Some backends return objects for text fields, e.g. {"text": "..."}.
    if (value is Map) {
      final nested = value['text'] ?? value['value'] ?? value['content'];
      if (nested is String) return nested;
      return value.toString();
    }

    return value.toString();
  }

  static String? _readNullableText(Map<String, dynamic> json, String key) {
    if (!json.containsKey(key) || json[key] == null) return null;
    final text = _readText(json, key).trim();
    return text.isEmpty ? null : text;
  }

  static double _readCost(Map<String, dynamic> json) {
    final cost = json['cost'];
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
        'translation': translation,
        'cost': cost,
      };

  @override
  String toString() {
    return 'AudioProcessResponse('
        'transcript: ${transcript.substring(0, transcript.length > 50 ? 50 : transcript.length)}, '
        'summary: ${summary.substring(0, summary.length > 50 ? 50 : summary.length)}, '
        'translation: $translation, '
        'cost: $cost)';
  }
}
