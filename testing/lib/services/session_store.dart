import '../models/user.dart';
import 'session_store_io.dart'
    if (dart.library.html) 'session_store_web.dart'
    if (dart.library.io) 'session_store_io.dart';
import 'session_store_models.dart';

export 'session_store_models.dart' show SavedSession;

class SessionStore {
  SessionStore({SessionPersistence? persistence})
      : _persistence = persistence ?? createSessionPersistence();

  final SessionPersistence _persistence;

  Future<SavedSession?> read() {
    return _persistence.read();
  }

  Future<void> save({
    required String token,
    required User user,
  }) {
    return _persistence.save(SavedSession(token: token, user: user));
  }

  Future<void> clear() {
    return _persistence.clear();
  }
}
