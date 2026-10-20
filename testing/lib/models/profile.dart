class Profile {
  const Profile({
    required this.userId,
    required this.displayName,
    required this.username,
    required this.age,
    required this.city,
    required this.gender,
    required this.lookingFor,
    required this.bio,
    required this.avatarUrl,
    required this.isFeatured,
    this.email,
    this.status,
    this.profileVisibility,
    this.verificationStatus,
    this.lastSeenAt,
  });

  final int userId;
  final String? email;
  final String? status;
  final String displayName;
  final String username;
  final int age;
  final String city;
  final String gender;
  final String lookingFor;
  final String? profileVisibility;
  final String bio;
  final String avatarUrl;
  final bool isFeatured;
  final String? verificationStatus;
  final DateTime? lastSeenAt;

  bool get isVerified => verificationStatus == 'verified';
  bool get hasSubmittedVerification =>
      verificationStatus != null && verificationStatus!.isNotEmpty;
  bool get isOnline {
    final seenAt = lastSeenAt;
    if (seenAt == null) {
      return false;
    }
    return DateTime.now().difference(seenAt).inMinutes <= 5;
  }

  factory Profile.fromJson(Map<String, dynamic> json) {
    return Profile(
      userId: _readInt(json['user_id'] ?? json['id'], fallback: 0),
      email: _readNullableString(json['email']),
      status: _readNullableString(json['status']),
      displayName: _readString(json['display_name'], fallback: 'Unknown'),
      username: _readString(json['username'], fallback: 'member'),
      age: _readInt(json['age'], fallback: 18),
      city: _readString(json['city'], fallback: 'Nearby'),
      gender: _readString(json['gender'], fallback: 'unknown'),
      lookingFor: _readString(json['looking_for'], fallback: 'everyone'),
      profileVisibility: _readNullableString(json['profile_visibility']),
      bio: _readString(json['bio'], fallback: ''),
      avatarUrl: _readString(json['avatar_url'], fallback: ''),
      isFeatured: _readBool(json['is_featured']),
      verificationStatus: _readNullableString(json['verification_status']),
      lastSeenAt: _readDateTime(json['last_seen_at']),
    );
  }

  static int _readInt(dynamic value, {required int fallback}) {
    if (value is int) {
      return value;
    }
    if (value is num) {
      return value.toInt();
    }
    if (value is String) {
      return int.tryParse(value) ?? fallback;
    }
    return fallback;
  }

  static String _readString(dynamic value, {required String fallback}) {
    if (value is String && value.trim().isNotEmpty) {
      return value.trim();
    }
    return fallback;
  }

  static String? _readNullableString(dynamic value) {
    if (value == null || value == '') {
      return null;
    }
    return value.toString();
  }

  static bool _readBool(dynamic value) {
    if (value is bool) {
      return value;
    }
    if (value is num) {
      return value != 0;
    }
    if (value is String) {
      return value == '1' || value.toLowerCase() == 'true';
    }
    return false;
  }

  static DateTime? _readDateTime(dynamic value) {
    if (value == null || value == '') {
      return null;
    }
    return DateTime.tryParse(value.toString().replaceFirst(' ', 'T'));
  }
}
