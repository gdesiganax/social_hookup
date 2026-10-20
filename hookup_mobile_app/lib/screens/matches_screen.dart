import 'package:flutter/material.dart';

import '../models/profile.dart';
import '../models/user.dart';
import '../services/api_service.dart';
import '../widgets/profile_status.dart';
import 'member_profile_screen.dart';

class MatchesScreen extends StatefulWidget {
  const MatchesScreen({
    super.key,
    required this.user,
    required this.token,
  });

  final User user;
  final String token;

  @override
  State<MatchesScreen> createState() => _MatchesScreenState();
}

class _MatchesScreenState extends State<MatchesScreen> {
  final _apiService = ApiService();
  late Future<_MatchesData> _future;
  final Set<int> _matching = <int>{};

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<_MatchesData> _load() async {
    final myProfile = await _apiService.myProfile(widget.token);
    final profiles = await _apiService.discoveryProfiles();
    final matches = await _apiService.myMatches(widget.token);
    final city = myProfile?.city ?? '';
    final people = profiles
        .where((Profile profile) => profile.userId != widget.user.id)
        .toList(growable: false);
    _sortProfilesByCity(people, city);
    final sortedMatches = matches.toList(growable: false);
    _sortRowsByCity(sortedMatches, city);

    return _MatchesData(
      people: people,
      matches: sortedMatches,
    );
  }

  void _refresh() {
    setState(() => _future = _load());
  }

  Future<void> _match(Profile profile) async {
    if (_matching.contains(profile.userId)) {
      return;
    }

    setState(() => _matching.add(profile.userId));
    try {
      await _apiService.matchUser(
        token: widget.token,
        userId: profile.userId,
      );
      _showMessage('Match request sent to ${profile.displayName}.');
      _refresh();
    } on ApiException catch (error) {
      _showMessage(error.message);
    } finally {
      if (mounted) {
        setState(() => _matching.remove(profile.userId));
      }
    }
  }

  void _showMessage(String message) {
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  void _openProfile(Profile profile) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => MemberProfileScreen(
          profile: profile,
          token: widget.token,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Matches'),
        actions: <Widget>[
          IconButton(
            tooltip: 'Refresh',
            onPressed: _refresh,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: FutureBuilder<_MatchesData>(
        future: _future,
        builder: (BuildContext context, AsyncSnapshot<_MatchesData> snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return _ErrorPanel(message: snapshot.error.toString(), onRetry: _refresh);
          }

          final data = snapshot.data ?? const _MatchesData();
          return RefreshIndicator(
            onRefresh: () async => _refresh(),
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: <Widget>[
                Text(
                  'People to match with',
                  style: Theme.of(context).textTheme.headline6,
                ),
                const SizedBox(height: 10),
                if (data.people.isEmpty)
                  const _EmptyMessage(message: 'No profiles available.')
                else
                  for (final profile in data.people)
                    _MatchCandidateTile(
                      profile: profile,
                      imageUrl: _apiService.resolveMediaUrl(profile.avatarUrl),
                      busy: _matching.contains(profile.userId),
                      onOpen: () => _openProfile(profile),
                      onMatch: () => _match(profile),
                    ),
                const SizedBox(height: 18),
                Text(
                  'Your matches',
                  style: Theme.of(context).textTheme.headline6,
                ),
                const SizedBox(height: 10),
                if (data.matches.isEmpty)
                  const _EmptyMessage(message: 'No matches yet.')
                else
                  for (final match in data.matches)
                    _RawMatchTile(
                      match: match,
                      imageUrl: _apiService.resolveMediaUrl(
                        _read(match, <String>['avatar_url']),
                      ),
                      onTap: () => _openProfile(Profile.fromJson(match)),
                    ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _MatchesData {
  const _MatchesData({
    this.people = const <Profile>[],
    this.matches = const <Map<String, dynamic>>[],
  });

  final List<Profile> people;
  final List<Map<String, dynamic>> matches;
}

class _MatchCandidateTile extends StatelessWidget {
  const _MatchCandidateTile({
    required this.profile,
    required this.imageUrl,
    required this.busy,
    required this.onOpen,
    required this.onMatch,
  });

  final Profile profile;
  final String imageUrl;
  final bool busy;
  final VoidCallback onOpen;
  final VoidCallback onMatch;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        onTap: onOpen,
        leading: ProfileAvatar(
          imageUrl: imageUrl,
          isOnline: profile.isOnline,
          isVerified: profile.hasSubmittedVerification,
        ),
        title: Text('${profile.displayName}, ${profile.age}'),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text('${profile.city} - ${profile.bio}'),
            ProfileStatusBadges(profile: profile),
          ],
        ),
        trailing: ElevatedButton.icon(
          onPressed: busy ? null : onMatch,
          icon: busy
              ? const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.favorite),
          label: const Text('Match'),
        ),
      ),
    );
  }
}

class _RawMatchTile extends StatelessWidget {
  const _RawMatchTile({
    required this.match,
    required this.imageUrl,
    required this.onTap,
  });

  final Map<String, dynamic> match;
  final String imageUrl;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final name = _read(match, <String>[
      'display_name',
      'username',
      'matched_username',
      'email',
    ]);
    final status = _read(match, <String>['status', 'match_status']);
    final verificationStatus = _read(match, <String>['verification_status']);

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        onTap: onTap,
        leading: ProfileAvatar(
          imageUrl: imageUrl,
          isOnline: _isOnline(match),
          isVerified: verificationStatus.isNotEmpty,
        ),
        title: Text(name.isEmpty ? 'Match' : name),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(status.isEmpty ? _read(match, <String>['city']) : status),
            RowStatusBadges(
              isOnline: _isOnline(match),
              verificationStatus: verificationStatus,
            ),
          ],
        ),
      ),
    );
  }
}

bool _isOnline(Map<String, dynamic> row) {
  final raw = _read(row, <String>['last_seen_at', 'last_login_at']);
  if (raw.isEmpty) {
    return false;
  }
  final seenAt = DateTime.tryParse(raw.replaceFirst(' ', 'T'));
  if (seenAt == null) {
    return false;
  }
  return DateTime.now().difference(seenAt).inMinutes <= 5;
}

void _sortProfilesByCity(List<Profile> profiles, String city) {
  if (city.trim().isEmpty) {
    return;
  }
  final normalizedCity = city.trim().toLowerCase();
  profiles.sort((Profile a, Profile b) {
    final aLocal = a.city.trim().toLowerCase() == normalizedCity;
    final bLocal = b.city.trim().toLowerCase() == normalizedCity;
    if (aLocal == bLocal) {
      return a.displayName.compareTo(b.displayName);
    }
    return aLocal ? -1 : 1;
  });
}

void _sortRowsByCity(List<Map<String, dynamic>> rows, String city) {
  if (city.trim().isEmpty) {
    return;
  }
  final normalizedCity = city.trim().toLowerCase();
  rows.sort((Map<String, dynamic> a, Map<String, dynamic> b) {
    final aLocal = _read(a, <String>['city']).trim().toLowerCase() ==
        normalizedCity;
    final bLocal = _read(b, <String>['city']).trim().toLowerCase() ==
        normalizedCity;
    if (aLocal == bLocal) {
      return _read(a, <String>['display_name', 'username'])
          .compareTo(_read(b, <String>['display_name', 'username']));
    }
    return aLocal ? -1 : 1;
  });
}

class _ErrorPanel extends StatelessWidget {
  const _ErrorPanel({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const Icon(Icons.error_outline, size: 42, color: Color(0xFFE91E63)),
            const SizedBox(height: 10),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            ElevatedButton(onPressed: onRetry, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }
}

class _EmptyMessage extends StatelessWidget {
  const _EmptyMessage({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 18),
      child: Center(child: Text(message)),
    );
  }
}

String _read(Map<String, dynamic> row, List<String> keys) {
  for (final key in keys) {
    final value = row[key];
    if (value != null && value.toString().trim().isNotEmpty) {
      return value.toString();
    }
  }
  return '';
}
