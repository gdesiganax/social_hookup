import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform, kIsWeb;
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';

import '../models/profile.dart';
import '../models/user.dart';

/// Successful authentication payload returned by `users.php`.
class AuthResult {
  const AuthResult({
    required this.token,
    required this.user,
  });

  final String token;
  final User user;
}

/// User-facing API error that is safe to show in the UI.
class ApiException implements Exception {
  const ApiException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() {
    if (statusCode == null) {
      return message;
    }
    return '$message (HTTP $statusCode)';
  }
}

/// Small REST client for the PHP API.
class ApiService {
  ApiService({
    http.Client? client,
    Uri? baseUri,
    this.timeout = const Duration(seconds: 8),
  })  : _client = client ?? http.Client(),
        baseUri = baseUri ?? Uri.parse(defaultBaseUrl);

  static const String androidBaseUrl = 'https://hookup.cobim.org/api/';
  static const String browserBaseUrl = 'http://127.0.0.1/Hookup/api/';

  static String get defaultBaseUrl {
    const configuredBaseUrl = String.fromEnvironment('API_BASE_URL');
    if (configuredBaseUrl.isNotEmpty) {
      return _withTrailingSlash(configuredBaseUrl);
    }

    if (kIsWeb) {
      return browserBaseUrl;
    }

    if (defaultTargetPlatform == TargetPlatform.android) {
      return androidBaseUrl;
    }

    return browserBaseUrl;
  }

  static const Set<String> allowedTableEndpoints = <String>{
    'users.php',
    'profiles.php',
    'profile_media.php',
    'user_verifications.php',
    'interests.php',
    'profile_interests.php',
    'matches.php',
    'conversations.php',
    'conversation_members.php',
    'messages.php',
    'posts.php',
    'post_reactions.php',
    'post_comments.php',
    'wallet_accounts.php',
    'gift_catalog.php',
    'gift_purchases.php',
    'wallet_transactions.php',
    'wallet_topups.php',
    'withdrawal_requests.php',
    'dates.php',
    'reports.php',
    'settings.php',
  };

  final http.Client _client;
  final Uri baseUri;
  final Duration timeout;

  Future<AuthResult> login({
    required String email,
    required String password,
  }) async {
    final body = <String, dynamic>{
      'action': 'login',
      'email': email.trim(),
      'password': password,
    };

    final json = await _postJson(
      'users.php',
      query: <String, String>{'action': 'login'},
      body: body,
    );

    return _authResultFromJson(json);
  }

  Future<AuthResult> register({
    required String email,
    required String password,
    required String displayName,
    required String username,
    required int age,
    required String city,
    required String bio,
    String gender = 'female',
    String lookingFor = 'everyone',
    String? avatarUrl,
  }) async {
    final body = <String, dynamic>{
      'action': 'register',
      'email': email.trim(),
      'password': password,
      'display_name': displayName.trim(),
      'username': username.trim(),
      'age': age,
      'city': city.trim(),
      'gender': gender,
      'looking_for': lookingFor,
      'bio': bio.trim(),
      if (avatarUrl != null && avatarUrl.trim().isNotEmpty)
        'avatar_url': avatarUrl.trim(),
    };

    final json = await _postJson(
      'users.php',
      query: <String, String>{'action': 'register'},
      body: body,
    );

    return _authResultFromJson(json);
  }

  Future<void> requestPasswordReset({
    required String email,
  }) async {
    await _postJson(
      'users.php',
      query: <String, String>{'action': 'forgot_password'},
      body: <String, dynamic>{
        'action': 'forgot_password',
        'email': email.trim(),
      },
    );
  }

  /// Fetches the current authenticated user using the bearer token issued by
  /// `users.php?action=login` or `users.php?action=register`.
  Future<User> me(String token) async {
    final json = await _getJson(
      'users.php',
      query: <String, String>{'action': 'me'},
      token: token,
    );

    final userJson = json['user'];
    if (userJson is! Map) {
      throw const ApiException('The server returned an invalid user payload.');
    }

    return User.fromJson(Map<String, dynamic>.from(userJson));
  }

  Future<List<Profile>> discoveryProfiles({
    String? gender,
    String? city,
  }) async {
    final rows = await fetchRawArray(
      'profiles.php',
      query: <String, String?>{
        'action': 'discovery',
        if (gender != null && gender != 'everyone') 'gender': gender,
        if (city != null && city.isNotEmpty) 'city': city,
      },
    );

    final profiles = rows.map(Profile.fromJson);
    return profiles.where((Profile profile) {
      final matchesGender = gender == null ||
          gender == 'everyone' ||
          profile.gender.toLowerCase() == gender.toLowerCase();
      final matchesCity = city == null ||
          city.isEmpty ||
          profile.city.toLowerCase().contains(city.toLowerCase());
      return matchesGender && matchesCity;
    }).toList(growable: false);
  }

  Future<List<Map<String, dynamic>>> feedPosts(
    String token, {
    int limit = 10,
    int offset = 0,
  }) {
    return fetchRawArray(
      'posts.php',
      query: <String, String?>{
        'action': 'feed',
        'limit': limit.toString(),
        'offset': offset.toString(),
      },
      token: token,
    );
  }

  Future<List<Map<String, dynamic>>> publicProfileMedia({
    required String token,
    required int userId,
  }) {
    return fetchRawArray(
      'profile_media.php',
      query: <String, String?>{
        'action': 'public',
        'user_id': userId.toString(),
      },
      token: token,
    );
  }

  Future<Map<String, dynamic>> walletSummary({
    required String token,
    required int userId,
  }) async {
    final json = await _getJson(
      'wallet_accounts.php',
      query: <String, String?>{
        'action': 'summary',
        'user_id': userId.toString(),
      },
      token: token,
    );
    final data = json['data'];
    if (data is Map<String, dynamic>) {
      return data;
    }
    if (data is Map) {
      return Map<String, dynamic>.from(data);
    }
    return const <String, dynamic>{};
  }

  Future<Map<String, dynamic>> myWallet(String token) async {
    final json = await _getJson(
      'wallet_accounts.php',
      query: const <String, String?>{'action': 'mine'},
      token: token,
    );
    final data = json['data'];
    if (data is Map<String, dynamic>) {
      return data;
    }
    if (data is Map) {
      return Map<String, dynamic>.from(data);
    }
    return const <String, dynamic>{};
  }

  Future<Map<String, dynamic>> createPost({
    required String token,
    required String content,
    Uint8List? imageBytes,
    String? imageFilename,
    String? imageMimeType,
  }) {
    if (imageBytes != null && imageBytes.isNotEmpty) {
      return _postMultipart(
        'posts.php',
        query: const <String, String?>{'action': 'create'},
        token: token,
        fields: <String, String>{
          'body': content.trim(),
          'content': content.trim(),
          'visibility': 'public',
        },
        fileField: 'post_media',
        fileBytes: imageBytes,
        filename: imageFilename ?? 'post-image.jpg',
        mimeType: imageMimeType ?? 'application/octet-stream',
      );
    }

    return _postJson(
      'posts.php',
      token: token,
      body: <String, dynamic>{
        'content': content.trim(),
        'body': content.trim(),
        'visibility': 'public',
      },
    );
  }

  Future<List<Map<String, dynamic>>> postComments({
    required String token,
    required int postId,
  }) {
    return fetchRawArray(
      'post_comments.php',
      query: <String, String?>{
        'action': 'for_post',
        'post_id': postId.toString(),
      },
      token: token,
    );
  }

  Future<Map<String, dynamic>> createComment({
    required String token,
    required int postId,
    required String body,
  }) {
    return _postJson(
      'post_comments.php',
      token: token,
      body: <String, dynamic>{
        'post_id': postId,
        'body': body.trim(),
      },
    );
  }

  Future<Map<String, dynamic>> likePost({
    required String token,
    required int postId,
  }) {
    return _postJson(
      'post_reactions.php',
      query: <String, String?>{'post_id': postId.toString()},
      token: token,
      body: <String, dynamic>{'post_id': postId},
    );
  }

  Future<List<Map<String, dynamic>>> myMatches(String token) {
    return fetchRawArray(
      'matches.php',
      query: const <String, String?>{'action': 'mine'},
      token: token,
    );
  }

  Future<Map<String, dynamic>> matchUser({
    required String token,
    required int userId,
  }) {
    return _postJson(
      'matches.php',
      query: const <String, String?>{'action': 'match'},
      token: token,
      body: <String, dynamic>{
        'target_user_id': userId,
        'matched_user_id': userId,
        'user_id': userId,
      },
    );
  }

  Future<List<Map<String, dynamic>>> myConversations(String token) {
    return fetchRawArray(
      'conversations.php',
      query: const <String, String?>{'action': 'mine'},
      token: token,
    );
  }

  Future<List<Map<String, dynamic>>> conversationMembers({
    required String token,
    required int conversationId,
  }) {
    return fetchRawArray(
      'conversation_members.php',
      query: <String, String?>{'conversation_id': conversationId.toString()},
      token: token,
    );
  }

  Future<List<Map<String, dynamic>>> giftCatalog(String token) {
    return fetchRawArray(
      'gift_catalog.php',
      query: const <String, String?>{'active': '1'},
      token: token,
    );
  }

  Future<Map<String, dynamic>> sendGift({
    required String token,
    required int conversationId,
    required int giftId,
    required int recipientId,
  }) {
    return _postJson(
      'gift_purchases.php',
      query: const <String, String?>{'action': 'send'},
      token: token,
      body: <String, dynamic>{
        'conversation_id': conversationId,
        'gift_id': giftId,
        'recipient_id': recipientId,
      },
    );
  }

  Future<Map<String, dynamic>> fundWallet({
    required String token,
    required double amount,
  }) async {
    final json = await _postJson(
      'wallet_topups.php',
      query: const <String, String?>{'action': 'fund'},
      token: token,
      body: <String, dynamic>{'amount': amount},
    );
    final data = json['data'];
    if (data is Map<String, dynamic>) {
      return data;
    }
    if (data is Map) {
      return Map<String, dynamic>.from(data);
    }
    return json;
  }

  Future<List<Map<String, dynamic>>> conversationMessages({
    required String token,
    required int conversationId,
  }) {
    return fetchRawArray(
      'messages.php',
      query: <String, String?>{
        'action': 'conversation',
        'conversation_id': conversationId.toString(),
      },
      token: token,
    );
  }

  Future<Map<String, dynamic>> sendMessage({
    required String token,
    required int conversationId,
    required String message,
  }) {
    return _postJson(
      'messages.php',
      token: token,
      body: <String, dynamic>{
        'conversation_id': conversationId,
        'body': message.trim(),
        'message': message.trim(),
        'content': message.trim(),
      },
    );
  }

  Future<Map<String, dynamic>> updateProfile({
    required String token,
    required int userId,
    required Map<String, dynamic> values,
  }) {
    return _patchJson(
      'profiles.php',
      query: <String, String?>{'id': userId.toString()},
      token: token,
      body: values,
    );
  }

  Future<Profile?> myProfile(String token) async {
    final json = await _getJson(
      'profiles.php',
      query: const <String, String?>{'action': 'me'},
      token: token,
    );

    final profileJson = json['data'];
    if (profileJson == null) {
      return null;
    }
    if (profileJson is Map<String, dynamic>) {
      return Profile.fromJson(profileJson);
    }
    if (profileJson is Map) {
      return Profile.fromJson(Map<String, dynamic>.from(profileJson));
    }

    throw const ApiException('The server returned an invalid profile payload.');
  }

  String resolveMediaUrl(String rawUrl) {
    final parsed = Uri.tryParse(rawUrl);
    if (parsed == null || !parsed.hasScheme) {
      return rawUrl;
    }

    final isLocalAsset =
        parsed.host == 'localhost' || parsed.host == '127.0.0.1';
    if (!isLocalAsset) {
      return rawUrl;
    }

    return parsed
        .replace(
          scheme: baseUri.scheme,
          host: baseUri.host,
          port: baseUri.hasPort ? baseUri.port : null,
        )
        .toString();
  }

  /// Fetches raw rows from any known table endpoint without requiring a model.
  ///
  /// This accepts both bare JSON arrays and common wrapped response shapes such
  /// as `{ "data": [...] }`, `{ "items": [...] }`, or `{ "records": [...] }`.
  Future<List<Map<String, dynamic>>> fetchRawArray(
    String endpointFile, {
    Map<String, String?> query = const <String, String?>{},
    String? token,
  }) async {
    _ensureAllowedEndpoint(endpointFile);

    final decoded = await _getDecoded(endpointFile, query: query, token: token);
    final dynamic rows = _extractRows(decoded);

    if (rows is! List) {
      throw const ApiException('The server response did not contain a list.');
    }

    return rows.map<Map<String, dynamic>>((dynamic item) {
      if (item is Map<String, dynamic>) {
        return item;
      }
      if (item is Map) {
        return Map<String, dynamic>.from(item);
      }
      throw const ApiException('The server list contains an invalid row.');
    }).toList(growable: false);
  }

  Future<Map<String, dynamic>> _getJson(
    String endpointFile, {
    Map<String, String?> query = const <String, String?>{},
    String? token,
  }) async {
    final decoded = await _getDecoded(endpointFile, query: query, token: token);
    return _asObject(decoded);
  }

  Future<dynamic> _getDecoded(
    String endpointFile, {
    Map<String, String?> query = const <String, String?>{},
    String? token,
  }) async {
    final uri = _buildUri(endpointFile, _queryWithToken(query, token));
    final response = await _send(
      () => _client.get(
        uri,
        headers: _headers(token),
      ),
    );
    return _decodeJson(response);
  }

  Future<Map<String, dynamic>> _postJson(
    String endpointFile, {
    required Map<String, dynamic> body,
    Map<String, String?> query = const <String, String?>{},
    String? token,
  }) async {
    final uri = _buildUri(endpointFile, _queryWithToken(query, token));

    final response = await _send(
      () => _client.post(
        uri,
        headers: _postHeaders(token),
        body: jsonEncode(body),
      ),
    );
    return _asObject(_decodeJson(response));
  }

  Future<Map<String, dynamic>> _postMultipart(
    String endpointFile, {
    required Map<String, String> fields,
    required String fileField,
    required Uint8List fileBytes,
    required String filename,
    required String mimeType,
    Map<String, String?> query = const <String, String?>{},
    String? token,
  }) async {
    final uri = _buildUri(endpointFile, _queryWithToken(query, token));
    final request = http.MultipartRequest('POST', uri)
      ..headers.addAll(_headers(token))
      ..fields.addAll(fields)
      ..files.add(
        http.MultipartFile.fromBytes(
          fileField,
          fileBytes,
          filename: filename,
          contentType: _mediaTypeFromMimeType(mimeType),
        ),
      );

    final streamedResponse = await _sendStreamed(() => request.send());
    final response = await http.Response.fromStream(streamedResponse);
    return _asObject(_decodeJson(response));
  }

  Future<Map<String, dynamic>> _patchJson(
    String endpointFile, {
    required Map<String, dynamic> body,
    Map<String, String?> query = const <String, String?>{},
    String? token,
  }) async {
    final uri = _buildUri(endpointFile, _queryWithToken(query, token));

    final response = await _send(
      () => _client.patch(
        uri,
        headers: _postHeaders(token),
        body: jsonEncode(body),
      ),
    );
    return _asObject(_decodeJson(response));
  }

  Future<http.Response> _send(Future<http.Response> Function() request) async {
    try {
      final response = await request().timeout(timeout);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw ApiException(
          _errorMessageFromResponse(response),
          statusCode: response.statusCode,
        );
      }
      return response;
    } on TimeoutException {
      throw const ApiException(
        'The request timed out. Please check your local server and try again.',
      );
    } on http.ClientException catch (error) {
      throw ApiException(
        _connectionErrorMessage(error),
      );
    }
  }

  Future<http.StreamedResponse> _sendStreamed(
    Future<http.StreamedResponse> Function() request,
  ) async {
    try {
      final response = await request().timeout(timeout);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        final decoded = await http.Response.fromStream(response);
        throw ApiException(
          _errorMessageFromResponse(decoded),
          statusCode: response.statusCode,
        );
      }
      return response;
    } on TimeoutException {
      throw const ApiException(
        'The request timed out. Please check your local server and try again.',
      );
    } on http.ClientException catch (error) {
      throw ApiException(
        _connectionErrorMessage(error),
      );
    }
  }

  Uri _buildUri(String endpointFile, Map<String, String?> query) {
    final cleanQuery = <String, String>{};
    query.forEach((String key, String? value) {
      if (value != null && value.isNotEmpty) {
        cleanQuery[key] = value;
      }
    });

    return baseUri
        .resolve(_canonicalEndpoint(endpointFile))
        .replace(queryParameters: cleanQuery);
  }

  Map<String, String> _headers(String? token) {
    return <String, String>{
      'Accept': 'application/json',
      if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
    };
  }

  Map<String, String> _postHeaders(String? token) {
    return <String, String>{
      ..._headers(token),
      'Content-Type': 'application/json',
    };
  }

  Map<String, String?> _queryWithToken(
    Map<String, String?> query,
    String? token,
  ) {
    if (token == null || token.isEmpty) {
      return query;
    }

    return <String, String?>{
      ...query,
      'token': token,
    };
  }

  dynamic _decodeJson(http.Response response) {
    try {
      return jsonDecode(response.body);
    } on FormatException {
      throw const ApiException('The server returned invalid JSON.');
    }
  }

  Map<String, dynamic> _asObject(dynamic decoded) {
    if (decoded is Map<String, dynamic>) {
      return decoded;
    }
    if (decoded is Map) {
      return Map<String, dynamic>.from(decoded);
    }

    throw const ApiException('The server returned an unexpected response.');
  }

  String _errorMessageFromResponse(http.Response response) {
    try {
      final dynamic decoded = jsonDecode(response.body);
      if (decoded is Map) {
        final dynamic message = decoded['message'] ?? decoded['error'];
        if (message is String && message.trim().isNotEmpty) {
          return message;
        }
      }
    } on FormatException {
      // Fall through to the generic status message below.
    }

    return 'Request failed. Please try again.';
  }

  AuthResult _authResultFromJson(Map<String, dynamic> json) {
    final token = json['token'];
    final userJson = json['user'];

    if (token is! String || token.isEmpty || userJson is! Map) {
      throw const ApiException('The server returned an invalid auth payload.');
    }

    return AuthResult(
      token: token,
      user: User.fromJson(Map<String, dynamic>.from(userJson)),
    );
  }

  dynamic _extractRows(dynamic json) {
    if (json is List) {
      return json;
    }
    if (json is! Map) {
      return json;
    }
    if (json['data'] is List) {
      return json['data'];
    }
    if (json['rows'] is List) {
      return json['rows'];
    }
    if (json['items'] is List) {
      return json['items'];
    }
    if (json['results'] is List) {
      return json['results'];
    }
    if (json['records'] is List) {
      return json['records'];
    }
    return json;
  }

  void _ensureAllowedEndpoint(String endpointFile) {
    if (!allowedTableEndpoints.contains(endpointFile)) {
      throw ApiException('Unsupported API endpoint: $endpointFile');
    }
  }

  static String _withTrailingSlash(String value) {
    return value.endsWith('/') ? value : '$value/';
  }

  String _canonicalEndpoint(String endpointFile) {
    // The Apache API redirects `users.php` to `users`. Calling the canonical
    // URL directly preserves POST methods and avoids auth routes falling
    // through to protected resource handlers after a redirect.
    if (endpointFile.endsWith('.php')) {
      return endpointFile.substring(0, endpointFile.length - 4);
    }

    return endpointFile;
  }

  String _connectionErrorMessage(http.ClientException error) {
    if (kIsWeb) {
      return 'Could not connect to the API at $baseUri. Restart Chrome debugging and confirm Apache is running.';
    }

    if (defaultTargetPlatform == TargetPlatform.android) {
      return 'Could not connect to the API at $baseUri. Please check your internet connection and try again.';
    }

    return 'Could not connect to the API at $baseUri. ${error.message}';
  }
}

MediaType _mediaTypeFromMimeType(String mimeType) {
  final parts = mimeType.split('/');
  if (parts.length != 2 || parts.first.isEmpty || parts.last.isEmpty) {
    return MediaType('application', 'octet-stream');
  }
  return MediaType(parts.first, parts.last);
}
