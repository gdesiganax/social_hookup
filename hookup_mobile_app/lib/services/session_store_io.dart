import 'dart:convert';
import 'dart:io';

import 'session_store_models.dart';

SessionPersistence createSessionPersistence() => _FileSessionPersistence();

class _FileSessionPersistence implements SessionPersistence {
  File get _file {
    final separator = Platform.pathSeparator;
    final basePath = Platform.environment['APPDATA'] ??
        Platform.environment['HOME'] ??
        Directory.systemTemp.path;
    final directory = Directory('$basePath${separator}Hookup');
    return File('${directory.path}${separator}session.json');
  }

  @override
  Future<SavedSession?> read() async {
    final file = _file;
    if (!await file.exists()) {
      return null;
    }

    try {
      final decoded = jsonDecode(await file.readAsString());
      if (decoded is! Map) {
        return null;
      }
      return SavedSession.fromJson(Map<String, dynamic>.from(decoded));
    } on FormatException {
      return null;
    } on FileSystemException {
      return null;
    }
  }

  @override
  Future<void> save(SavedSession session) async {
    final file = _file;
    await file.parent.create(recursive: true);
    await file.writeAsString(jsonEncode(session.toJson()));
  }

  @override
  Future<void> clear() async {
    final file = _file;
    if (await file.exists()) {
      await file.delete();
    }
  }
}
