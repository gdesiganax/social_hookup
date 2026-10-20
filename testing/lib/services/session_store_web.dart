import 'session_store_models.dart';

SessionPersistence createSessionPersistence() => _WebSessionPersistence();

class _WebSessionPersistence implements SessionPersistence {
  static SavedSession? _session;

  @override
  Future<SavedSession?> read() async {
    return _session;
  }

  @override
  Future<void> save(SavedSession session) async {
    _session = session;
  }

  @override
  Future<void> clear() async {
    _session = null;
  }
}
