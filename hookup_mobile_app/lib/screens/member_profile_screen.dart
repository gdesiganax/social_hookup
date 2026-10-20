import 'package:flutter/material.dart';

import '../models/profile.dart';
import '../services/api_service.dart';
import '../widgets/profile_status.dart';

class MemberProfileScreen extends StatefulWidget {
  const MemberProfileScreen({
    super.key,
    required this.profile,
    required this.token,
  });

  final Profile profile;
  final String token;

  @override
  State<MemberProfileScreen> createState() => _MemberProfileScreenState();
}

class _MemberProfileScreenState extends State<MemberProfileScreen> {
  final _apiService = ApiService();
  late Future<List<Map<String, dynamic>>> _mediaFuture;
  late Future<Map<String, dynamic>> _walletFuture;

  @override
  void initState() {
    super.initState();
    _mediaFuture = _apiService.publicProfileMedia(
      token: widget.token,
      userId: widget.profile.userId,
    );
    _walletFuture = _apiService.walletSummary(
      token: widget.token,
      userId: widget.profile.userId,
    );
  }

  @override
  Widget build(BuildContext context) {
    final profile = widget.profile;
    final avatarUrl = _apiService.resolveMediaUrl(profile.avatarUrl);

    return Scaffold(
      appBar: AppBar(title: Text(profile.displayName)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: <Widget>[
          Center(
            child: ProfileAvatar(
              imageUrl: avatarUrl,
              isOnline: profile.isOnline,
              isVerified: profile.hasSubmittedVerification,
              radius: 54,
            ),
          ),
          const SizedBox(height: 12),
          Center(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                Flexible(
                  child: Text(
                    '${profile.displayName}, ${profile.age}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.headline5?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                ),
                if (profile.isVerified) ...<Widget>[
                  const SizedBox(width: 8),
                  const Icon(Icons.verified, color: Color(0xFF1DA1F2)),
                ],
              ],
            ),
          ),
          const SizedBox(height: 10),
          Center(child: ProfileStatusBadges(profile: profile)),
          const SizedBox(height: 4),
          Center(
            child: Text(
              '@${profile.username} - ${profile.city}',
              style: const TextStyle(color: Color(0xFF6B5961)),
            ),
          ),
          const SizedBox(height: 18),
          Text(profile.bio),
          const SizedBox(height: 22),
          FutureBuilder<Map<String, dynamic>>(
            future: _walletFuture,
            builder: (BuildContext context,
                AsyncSnapshot<Map<String, dynamic>> snapshot) {
              final wallet = snapshot.data ?? const <String, dynamic>{};
              return _WalletSummary(
                loading: snapshot.connectionState == ConnectionState.waiting,
                wallet: wallet,
              );
            },
          ),
          const SizedBox(height: 22),
          Text(
            'Public media',
            style: Theme.of(context).textTheme.headline6,
          ),
          const SizedBox(height: 10),
          FutureBuilder<List<Map<String, dynamic>>>(
            future: _mediaFuture,
            builder: (BuildContext context,
                AsyncSnapshot<List<Map<String, dynamic>>> snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Center(child: CircularProgressIndicator()),
                );
              }

              if (snapshot.hasError) {
                return _ProfileNotice(message: snapshot.error.toString());
              }

              final media = snapshot.data ?? const <Map<String, dynamic>>[];
              if (media.isEmpty) {
                return const _ProfileNotice(
                  message: 'No public photos or videos yet.',
                );
              }

              return Column(
                children: <Widget>[
                  for (final item in media)
                    _ProfileMediaTile(
                      item: item,
                      resolveMediaUrl: _apiService.resolveMediaUrl,
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _WalletSummary extends StatelessWidget {
  const _WalletSummary({
    required this.loading,
    required this.wallet,
  });

  final bool loading;
  final Map<String, dynamic> wallet;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                const Icon(Icons.account_balance_wallet_outlined,
                    color: Color(0xFFE91E63)),
                const SizedBox(width: 8),
                Text(
                  'Wallet',
                  style: Theme.of(context).textTheme.subtitle1?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (loading)
              const LinearProgressIndicator()
            else
              Row(
                children: <Widget>[
                  Expanded(
                    child: _WalletMetric(
                      label: 'Cash',
                      value: _money(wallet['cash_balance']),
                    ),
                  ),
                  Expanded(
                    child: _WalletMetric(
                      label: 'Gifts',
                      value: _money(wallet['gift_balance']),
                    ),
                  ),
                  Expanded(
                    child: _WalletMetric(
                      label: 'Pending',
                      value: _money(wallet['pending_withdrawal']),
                    ),
                  ),
                ],
              ),
            const SizedBox(height: 10),
            const Text(
              'Withdrawals are available only through the website.',
              style: TextStyle(color: Color(0xFF6B5961)),
            ),
          ],
        ),
      ),
    );
  }
}

class _WalletMetric extends StatelessWidget {
  const _WalletMetric({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          label,
          style: const TextStyle(fontSize: 12, color: Color(0xFF6B5961)),
        ),
        const SizedBox(height: 3),
        Text(
          value,
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
      ],
    );
  }
}

class _ProfileMediaTile extends StatelessWidget {
  const _ProfileMediaTile({
    required this.item,
    required this.resolveMediaUrl,
  });

  final Map<String, dynamic> item;
  final String Function(String rawUrl) resolveMediaUrl;

  @override
  Widget build(BuildContext context) {
    final mediaType = _read(item, <String>['media_type']);
    final mediaUrl = resolveMediaUrl(_read(item, <String>['media_url']));
    final caption = _read(item, <String>['caption']);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          if (mediaType == 'video')
            Container(
              height: 190,
              color: const Color(0xFFF1E7EC),
              alignment: Alignment.center,
              child: const Icon(
                Icons.play_circle_fill,
                size: 56,
                color: Color(0xFFE91E63),
              ),
            )
          else
            AspectRatio(
              aspectRatio: 4 / 3,
              child: Image.network(
                mediaUrl,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                  color: const Color(0xFFF1E7EC),
                  alignment: Alignment.center,
                  child: const Icon(Icons.broken_image),
                ),
              ),
            ),
          if (caption.isNotEmpty || mediaType == 'video')
            Padding(
              padding: const EdgeInsets.all(12),
              child: Text(
                caption.isEmpty ? mediaUrl : caption,
                maxLines: mediaType == 'video' ? 2 : 3,
                overflow: TextOverflow.ellipsis,
              ),
            ),
        ],
      ),
    );
  }
}

class _ProfileNotice extends StatelessWidget {
  const _ProfileNotice({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 22),
      child: Center(
        child: Text(
          message,
          textAlign: TextAlign.center,
          style: const TextStyle(color: Color(0xFF6B5961)),
        ),
      ),
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

String _money(dynamic value) {
  final amount = double.tryParse(value?.toString() ?? '') ?? 0;
  return 'NGN ${amount.toStringAsFixed(0)}';
}
