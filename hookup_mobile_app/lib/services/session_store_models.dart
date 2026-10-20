import '../models/user.dart';

class SavedSession {
  const SavedSession({
    required this.token,
    required this.user,
  });

  final String token;
  final User user;

  factory SavedSession.fromJson(Map<String, dynamic> json) {
    final userJson = json['user'];
    if (userJson is! Map) {
      throw const FormatException('Invalid saved user payload.');
    }

    return SavedSession(
      token: json['token'].toString(),
      user: User.fromJson(Map<String, dynamic>.from(userJson)),
    );
  }

  Map<String, dynamic> toJson() {
    final userJson = user.toJson()..remove('password_hash');
    return <String, dynamic>{
      'token': token,
      'user': userJson,
    };
  }
}

abstract class SessionPersistence {
  Future<SavedSession?> read();
  Future<void> save(SavedSession session);
  Future<void> clear();
}
