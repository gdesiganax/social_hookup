/// Safe representation of a row returned from the `users` table.
///
/// PHP/PDO often serializes numeric and datetime values as strings, so parsing
/// accepts those common shapes while keeping the app model strongly typed.
class User {
  const User({
    required this.id,
    required this.email,
    required this.role,
    required this.status,
    this.passwordHash,
    this.emailVerifiedAt,
    this.lastLoginAt,
    this.createdAt,
    this.updatedAt,
    this.deletedAt,
  });

  final int id;
  final String email;
  final String? passwordHash;
  final String role;
  final String status;
  final DateTime? emailVerifiedAt;
  final DateTime? lastLoginAt;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final DateTime? deletedAt;

  bool get isActive => status == 'active';
  bool get isAdmin => role == 'admin';
  bool get isMember => role == 'member';

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: _readInt(json['id'], fieldName: 'id'),
      email: _readString(json['email'], fieldName: 'email'),
      passwordHash: _readNullableString(json['password_hash']),
      role: _readString(json['role'], fieldName: 'role'),
      status: _readString(json['status'], fieldName: 'status'),
      emailVerifiedAt: _readDateTime(json['email_verified_at']),
      lastLoginAt: _readDateTime(json['last_login_at']),
      createdAt: _readDateTime(json['created_at']),
      updatedAt: _readDateTime(json['updated_at']),
      deletedAt: _readDateTime(json['deleted_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'email': email,
      if (passwordHash != null) 'password_hash': passwordHash,
      'role': role,
      'status': status,
      'email_verified_at': emailVerifiedAt?.toIso8601String(),
      'last_login_at': lastLoginAt?.toIso8601String(),
      'created_at': createdAt?.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
      'deleted_at': deletedAt?.toIso8601String(),
    };
  }

  User copyWith({
    int? id,
    String? email,
    String? passwordHash,
    String? role,
    String? status,
    DateTime? emailVerifiedAt,
    DateTime? lastLoginAt,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? deletedAt,
  }) {
    return User(
      id: id ?? this.id,
      email: email ?? this.email,
      passwordHash: passwordHash ?? this.passwordHash,
      role: role ?? this.role,
      status: status ?? this.status,
      emailVerifiedAt: emailVerifiedAt ?? this.emailVerifiedAt,
      lastLoginAt: lastLoginAt ?? this.lastLoginAt,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: deletedAt ?? this.deletedAt,
    );
  }

  static int _readInt(dynamic value, {required String fieldName}) {
    if (value is int) {
      return value;
    }
    if (value is num) {
      return value.toInt();
    }
    if (value is String) {
      final parsed = int.tryParse(value);
      if (parsed != null) {
        return parsed;
      }
    }
    throw FormatException('Invalid or missing "$fieldName" value.');
  }

  static String _readString(dynamic value, {required String fieldName}) {
    if (value is String && value.isNotEmpty) {
      return value;
    }
    throw FormatException('Invalid or missing "$fieldName" value.');
  }

  static String? _readNullableString(dynamic value) {
    if (value == null) {
      return null;
    }
    return value.toString();
  }

  static DateTime? _readDateTime(dynamic value) {
    if (value == null || value == '') {
      return null;
    }
    if (value is DateTime) {
      return value;
    }

    // MySQL DATETIME values arrive as "YYYY-MM-DD HH:MM:SS"; Dart expects a
    // "T" separator for reliable parsing on every platform.
    return DateTime.tryParse(value.toString().replaceFirst(' ', 'T'));
  }
}
