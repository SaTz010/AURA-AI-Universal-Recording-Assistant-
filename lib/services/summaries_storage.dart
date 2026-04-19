import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

class SummarizedAudio {
  const SummarizedAudio({
    required this.filePath,
    required this.fileName,
    required this.createdAtMs,
    required this.description,
    this.summary = '',
    this.transcript = '',
    this.translation,
    this.cost = 0.0,
    this.category = '',
    this.pdfUri,
  });

  final String filePath;
  final String fileName;
  final int createdAtMs;
  final String description;
  final String summary;
  final String transcript;
  final String? translation;
  final double cost;
  final String category;
  final String? pdfUri;

  SummarizedAudio copyWith({
    String? pdfUri,
  }) {
    return SummarizedAudio(
      filePath: filePath,
      fileName: fileName,
      createdAtMs: createdAtMs,
      description: description,
      summary: summary,
      transcript: transcript,
      translation: translation,
      cost: cost,
      category: category,
      pdfUri: pdfUri,
    );
  }

  Map<String, Object?> toJson() => {
        'filePath': filePath,
        'fileName': fileName,
        'createdAtMs': createdAtMs,
        'description': description,
        'summary': summary,
        'transcript': transcript,
        'translation': translation,
        'cost': cost,
        'category': category,
      'pdfUri': pdfUri,
      };

  static SummarizedAudio? fromJson(Object? raw) {
    if (raw is! Map) return null;

    final filePath = raw['filePath'];
    final fileName = raw['fileName'];
    final createdAtMs = raw['createdAtMs'];
    final description = raw['description'];

    if (filePath is! String || filePath.isEmpty) return null;
    if (fileName is! String || fileName.isEmpty) return null;
    if (createdAtMs is! int) return null;
    if (description is! String) return null;

    // Optional response data fields for backward compatibility
    final summary = raw['summary'] as String? ?? '';
    final transcript = raw['transcript'] as String? ?? '';
    final translation = raw['translation'] as String?;
    final cost = _readCost(raw);
    final category = raw['category'] as String? ?? '';
    final pdfUri = raw['pdfUri'] as String?;

    return SummarizedAudio(
      filePath: filePath,
      fileName: fileName,
      createdAtMs: createdAtMs,
      description: description,
      summary: summary,
      transcript: transcript,
      translation: translation,
      cost: cost,
      category: category,
      pdfUri: pdfUri,
    );
  }

  static double _readCost(dynamic json) {
    if (json is! Map) return 0.0;
    final value = json['cost'];
    if (value == null) return 0.0;
    if (value is num) return value.toDouble();
    if (value is String) {
      return double.tryParse(value) ?? 0.0;
    }
    if (value is Map) {
      final numeric = value['usd'] ?? value['total'] ?? value['value'] ?? 
                      value['amount'] ?? value['cost'] ?? value['total_cost'];
      if (numeric is num) return numeric.toDouble();
      if (numeric is String) return double.tryParse(numeric) ?? 0.0;
    }
    return 0.0;
  }
}

class SummariesStorage {
  static const String _rootFolderName = 'summaries';
  static const String _indexFileName = 'summaries.json';

  static String _folderNameForUid(String? uid) {
    final normalized = uid?.trim();
    if (normalized == null || normalized.isEmpty) return '_guest';
    return normalized;
  }

  static String _join(String a, String b) {
    final sep = Platform.pathSeparator;
    if (a.endsWith(sep)) return '$a$b';
    return '$a$sep$b';
  }

  static Future<File> _indexFile(String? uid) async {
    final docs = await getApplicationDocumentsDirectory();
    final dir = Directory(
      _join(
        _join(docs.path, _rootFolderName),
        _folderNameForUid(uid),
      ),
    );

    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }

    return File(_join(dir.path, _indexFileName));
  }

  static Future<List<SummarizedAudio>> load(String? uid) async {
    try {
      final file = await _indexFile(uid);
      if (!await file.exists()) return const [];

      final raw = jsonDecode(await file.readAsString());
      if (raw is! List) return const [];

      return raw.map(SummarizedAudio.fromJson).whereType<SummarizedAudio>().toList();
    } catch (_) {
      return const [];
    }
  }

  static Future<void> save(String? uid, List<SummarizedAudio> items) async {
    final file = await _indexFile(uid);
    final jsonText = jsonEncode(items.map((e) => e.toJson()).toList());
    await file.writeAsString(jsonText);
  }

  static Future<SummarizedAudio?> updatePdfUri({
    required String? uid,
    required SummarizedAudio item,
    required String? pdfUri,
  }) async {
    final items = await load(uid);

    final index = items.indexWhere(
      (e) => e.createdAtMs == item.createdAtMs && e.filePath == item.filePath,
    );
    if (index < 0) return null;

    final updated = items[index].copyWith(pdfUri: pdfUri);
    final next = [...items]..[index] = updated;
    await save(uid, next);
    return updated;
  }
}
