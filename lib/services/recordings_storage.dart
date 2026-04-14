import 'dart:io';

import 'package:path_provider/path_provider.dart';

class RecordingsStorage {
  static const String _rootFolderName = 'recordings';

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

  static Future<Directory> getUserRecordingsDir(String? uid) async {
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

    await _migrateLegacyRootRecordingsIfPresent(docs, dir);
    return dir;
  }

  static Future<void> _migrateLegacyRootRecordingsIfPresent(
    Directory docsDir,
    Directory targetDir,
  ) async {
    List<FileSystemEntity> entities;
    try {
      entities = docsDir.listSync();
    } catch (_) {
      return;
    }

    final legacy = entities
        .where((e) => e is File && e.path.toLowerCase().endsWith('.m4a'))
        .cast<File>()
        .toList();

    if (legacy.isEmpty) return;

    for (final file in legacy) {
      final fileName = file.uri.pathSegments.isNotEmpty ? file.uri.pathSegments.last : file.path;
      var destPath = _join(targetDir.path, fileName);

      if (File(destPath).existsSync()) {
        final dot = fileName.lastIndexOf('.');
        final base = dot == -1 ? fileName : fileName.substring(0, dot);
        final ext = dot == -1 ? '' : fileName.substring(dot);
        destPath = _join(
          targetDir.path,
          '${base}_${DateTime.now().millisecondsSinceEpoch}$ext',
        );
      }

      try {
        await file.rename(destPath);
      } catch (_) {
        try {
          await file.copy(destPath);
          await file.delete();
        } catch (_) {
          // ignore individual migration failures
        }
      }
    }
  }
}
