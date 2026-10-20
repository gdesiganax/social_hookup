import 'package:flutter/material.dart';

import '../models/user.dart';
import '../services/api_service.dart';
import '../services/payment_launcher.dart';
import '../widgets/profile_status.dart';

class MessagesScreen extends StatefulWidget {
  const MessagesScreen({
    super.key,
    required this.user,
    required this.token,
  });

  final User user;
  final String token;

  @override
  State<MessagesScreen> createState() => _MessagesScreenState();
}

class _MessagesScreenState extends State<MessagesScreen> {
  final _apiService = ApiService();
  final _messageController = TextEditingController();
  final _fundAmountController = TextEditingController(text: '1000');
  late Future<List<Map<String, dynamic>>> _conversationsFuture;
  late Future<Map<String, dynamic>> _walletFuture;
  Future<List<Map<String, dynamic>>>? _messagesFuture;
  Map<String, dynamic>? _selectedConversation;
  final Map<int, Future<String>> _conversationTitleFutures =
      <int, Future<String>>{};
  bool _sending = false;
  bool _funding = false;

  @override
  void initState() {
    super.initState();
    _conversationsFuture = _apiService.myConversations(widget.token);
    _walletFuture = _apiService.myWallet(widget.token);
  }

  @override
  void dispose() {
    _messageController.dispose();
    _fundAmountController.dispose();
    super.dispose();
  }

  int? _conversationId(Map<String, dynamic> row) {
    final value = row['conversation_id'] ?? row['id'];
    if (value is int) {
      return value;
    }
    if (value is num) {
      return value.toInt();
    }
    return int.tryParse(value?.toString() ?? '');
  }

  void _selectConversation(Map<String, dynamic> conversation) {
    final id = _conversationId(conversation);
    if (id == null) {
      _showMessage('This conversation has no valid id.');
      return;
    }

    setState(() {
      _selectedConversation = conversation;
      _messagesFuture = _apiService.conversationMessages(
        token: widget.token,
        conversationId: id,
      );
    });
  }

  Future<String> _conversationTitleFuture(Map<String, dynamic> conversation) {
    final directTitle = _conversationTitleFromRow(conversation);
    if (directTitle.isNotEmpty) {
      return Future<String>.value(directTitle);
    }

    final id = _conversationId(conversation);
    if (id == null) {
      return Future<String>.value('Conversation');
    }

    return _conversationTitleFutures.putIfAbsent(
      id,
      () => _loadConversationTitle(id),
    );
  }

  Future<String> _loadConversationTitle(int conversationId) async {
    try {
      final members = await _apiService.conversationMembers(
        token: widget.token,
        conversationId: conversationId,
      );
      final otherMembers = members.where((Map<String, dynamic> member) {
        return _readInt(member, <String>['user_id', 'id']) != widget.user.id;
      });
      final member = otherMembers.isNotEmpty
          ? otherMembers.first
          : members.isNotEmpty
              ? members.first
              : null;

      if (member == null) {
        return 'Conversation';
      }

      final title = _conversationTitleFromRow(member);
      return title.isEmpty ? 'Conversation' : title;
    } on ApiException {
      return 'Conversation';
    }
  }

  Future<void> _send() async {
    final conversation = _selectedConversation;
    final id = conversation == null ? null : _conversationId(conversation);
    final message = _messageController.text.trim();
    if (id == null || message.isEmpty || _sending) {
      return;
    }

    setState(() => _sending = true);
    try {
      await _apiService.sendMessage(
        token: widget.token,
        conversationId: id,
        message: message,
      );
      _messageController.clear();
      setState(() {
        _messagesFuture = _apiService.conversationMessages(
          token: widget.token,
          conversationId: id,
        );
      });
    } on ApiException catch (error) {
      _showMessage(error.message);
    } finally {
      if (mounted) {
        setState(() => _sending = false);
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

  Future<void> _fundWallet() async {
    if (_funding) {
      return;
    }
    final amount = double.tryParse(_fundAmountController.text.trim()) ?? 0;
    if (amount < 100) {
      _showMessage('Minimum top-up is NGN 100.');
      return;
    }

    setState(() => _funding = true);
    try {
      final topup = await _apiService.fundWallet(
        token: widget.token,
        amount: amount,
      );
      final url = _read(topup, <String>['authorization_url', 'checkout_url']);
      final opened = await openPaymentUrl(url);
      if (!opened) {
        _showMessage('Open this Paystack checkout on the website: $url');
      } else {
        _showMessage('Paystack checkout opened.');
      }
      setState(() {
        _walletFuture = _apiService.myWallet(widget.token);
      });
    } on ApiException catch (error) {
      _showMessage(error.message);
    } finally {
      if (mounted) {
        setState(() => _funding = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final conversation = _selectedConversation;

    return Scaffold(
      appBar: AppBar(
        title: conversation == null
            ? const Text('Messages')
            : FutureBuilder<String>(
                future: _conversationTitleFuture(conversation),
                builder: (BuildContext context,
                    AsyncSnapshot<String> titleSnapshot) {
                  return Text(titleSnapshot.data ?? 'Conversation');
                },
              ),
        leading: conversation == null
            ? null
            : IconButton(
                tooltip: 'Back to conversations',
                onPressed: () {
                  setState(() {
                    _selectedConversation = null;
                    _messagesFuture = null;
                  });
                },
                icon: const Icon(Icons.arrow_back),
              ),
        actions: <Widget>[
          if (conversation != null)
            IconButton(
              tooltip: 'Send gift',
              onPressed: _openGiftSheet,
              icon: const Icon(Icons.card_giftcard),
            ),
        ],
      ),
      body: conversation == null ? _buildConversationList() : _buildMessages(),
    );
  }

  Future<void> _openGiftSheet() async {
    final conversation = _selectedConversation;
    final id = conversation == null ? null : _conversationId(conversation);
    if (id == null) {
      return;
    }

    final sent = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (BuildContext context) {
        return _GiftSheet(
          apiService: _apiService,
          token: widget.token,
          conversationId: id,
          currentUserId: widget.user.id,
        );
      },
    );

    if (sent == true && mounted) {
      setState(() {
        _messagesFuture = _apiService.conversationMessages(
          token: widget.token,
          conversationId: id,
        );
        _conversationsFuture = _apiService.myConversations(widget.token);
      });
      _showMessage('Gift sent.');
    }
  }

  Widget _buildConversationList() {
    return Column(
      children: <Widget>[
        _WalletFundingPanel(
          walletFuture: _walletFuture,
          controller: _fundAmountController,
          funding: _funding,
          onFund: _fundWallet,
        ),
        Expanded(
          child: FutureBuilder<List<Map<String, dynamic>>>(
            future: _conversationsFuture,
            builder: (BuildContext context,
                AsyncSnapshot<List<Map<String, dynamic>>> snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              if (snapshot.hasError) {
                return _CenteredMessage(message: snapshot.error.toString());
              }

              final conversations =
                  snapshot.data ?? const <Map<String, dynamic>>[];
              if (conversations.isEmpty) {
                return const _CenteredMessage(
                  message: 'No conversations yet. Match with someone first.',
                );
              }

              return ListView.builder(
                padding: const EdgeInsets.all(12),
                itemCount: conversations.length,
                itemBuilder: (BuildContext context, int index) {
                  final conversation = conversations[index];

                  return Card(
                    child: ListTile(
                      leading: const CircleAvatar(
                        child: Icon(Icons.chat_bubble),
                      ),
                      title: FutureBuilder<String>(
                        future: _conversationTitleFuture(conversation),
                        builder: (BuildContext context,
                            AsyncSnapshot<String> titleSnapshot) {
                          final title =
                              titleSnapshot.data ?? 'Loading member...';
                          return Text(title);
                        },
                      ),
                      subtitle: Text(_messagePreview(_read(conversation, <String>[
                        'last_message',
                        'updated_at',
                        'created_at',
                      ]))),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => _selectConversation(conversation),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildMessages() {
    return Column(
      children: <Widget>[
        _WalletFundingPanel(
          walletFuture: _walletFuture,
          controller: _fundAmountController,
          funding: _funding,
          onFund: _fundWallet,
        ),
        Expanded(
          child: FutureBuilder<List<Map<String, dynamic>>>(
            future: _messagesFuture,
            builder: (BuildContext context,
                AsyncSnapshot<List<Map<String, dynamic>>> snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              if (snapshot.hasError) {
                return _CenteredMessage(message: snapshot.error.toString());
              }

              final messages = snapshot.data ?? const <Map<String, dynamic>>[];
              if (messages.isEmpty) {
                return const _CenteredMessage(message: 'No messages yet.');
              }

              return ListView.builder(
                reverse: true,
                padding: const EdgeInsets.all(12),
                itemCount: messages.length,
                itemBuilder: (BuildContext context, int index) {
                  final message = messages[messages.length - index - 1];
                  final senderId =
                      int.tryParse((message['sender_id'] ?? '').toString());
                  final mine = senderId == widget.user.id;
                  final avatarUrl = _apiService.resolveMediaUrl(
                    _read(message, <String>['avatar_url']),
                  );
                  return Align(
                    alignment:
                        mine ? Alignment.centerRight : Alignment.centerLeft,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      textDirection: mine ? TextDirection.rtl : TextDirection.ltr,
                      children: <Widget>[
                        ProfileAvatar(
                          imageUrl: avatarUrl,
                          isOnline: _isOnline(message),
                          isVerified:
                              _read(message, <String>['verification_status'])
                                  .isNotEmpty,
                          radius: 16,
                        ),
                        const SizedBox(width: 8),
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 300),
                          child: Card(
                            color: mine
                                ? const Color(0xFFE91E63)
                                : const Color(0xFFFFFFFF),
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: Text(
                                _messageText(message),
                                style: TextStyle(
                                  color: mine ? Colors.white : Colors.black87,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              );
            },
          ),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
            child: Row(
              children: <Widget>[
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    minLines: 1,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      hintText: 'Message...',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  tooltip: 'Send',
                  onPressed: _sending ? null : _send,
                  icon: const Icon(Icons.send),
                  color: const Color(0xFFE91E63),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _GiftSheet extends StatefulWidget {
  const _GiftSheet({
    required this.apiService,
    required this.token,
    required this.conversationId,
    required this.currentUserId,
  });

  final ApiService apiService;
  final String token;
  final int conversationId;
  final int currentUserId;

  @override
  State<_GiftSheet> createState() => _GiftSheetState();
}

class _WalletFundingPanel extends StatelessWidget {
  const _WalletFundingPanel({
    required this.walletFuture,
    required this.controller,
    required this.funding,
    required this.onFund,
  });

  final Future<Map<String, dynamic>> walletFuture;
  final TextEditingController controller;
  final bool funding;
  final VoidCallback onFund;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
        child: FutureBuilder<Map<String, dynamic>>(
          future: walletFuture,
          builder: (BuildContext context,
              AsyncSnapshot<Map<String, dynamic>> snapshot) {
            final wallet = snapshot.data ?? const <String, dynamic>{};
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    const Icon(Icons.account_balance_wallet_outlined,
                        color: Color(0xFFE91E63)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Wallet: ${_money(wallet['cash_balance'])} cash, ${_money(wallet['gift_balance'])} gifts',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: <Widget>[
                    Expanded(
                      child: TextField(
                        controller: controller,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Paystack top-up',
                          prefixText: 'NGN ',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton.icon(
                      onPressed: funding ? null : onFund,
                      icon: funding
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.payment),
                      label: const Text('Fund'),
                    ),
                  ],
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _GiftSheetState extends State<_GiftSheet> {
  late Future<_GiftData> _future;
  int? _selectedRecipientId;
  int? _sendingGiftId;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<_GiftData> _load() async {
    final gifts = await widget.apiService.giftCatalog(widget.token);
    final members = await widget.apiService.conversationMembers(
      token: widget.token,
      conversationId: widget.conversationId,
    );
    final recipients = members
        .where((Map<String, dynamic> member) =>
            _readInt(member, <String>['user_id']) != widget.currentUserId)
        .toList(growable: false);
    if (recipients.isNotEmpty) {
      _selectedRecipientId ??= _readInt(recipients.first, <String>['user_id']);
    }
    return _GiftData(gifts: gifts, recipients: recipients);
  }

  Future<void> _sendGift(Map<String, dynamic> gift) async {
    final giftId = _readInt(gift, <String>['id']);
    final recipientId = _selectedRecipientId;
    if (giftId == null || recipientId == null || _sendingGiftId != null) {
      return;
    }

    setState(() => _sendingGiftId = giftId);
    try {
      await widget.apiService.sendGift(
        token: widget.token,
        conversationId: widget.conversationId,
        giftId: giftId,
        recipientId: recipientId,
      );
      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } on ApiException catch (error) {
      if (mounted) {
        setState(() => _sendingGiftId = null);
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(error.message)));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          16,
          16,
          16,
          16 + MediaQuery.of(context).viewInsets.bottom,
        ),
        child: FutureBuilder<_GiftData>(
          future: _future,
          builder: (BuildContext context, AsyncSnapshot<_GiftData> snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const SizedBox(
                height: 220,
                child: Center(child: CircularProgressIndicator()),
              );
            }

            if (snapshot.hasError) {
              return SizedBox(
                height: 220,
                child: Center(child: Text(snapshot.error.toString())),
              );
            }

            final data = snapshot.data ?? const _GiftData();
            if (data.gifts.isEmpty || data.recipients.isEmpty) {
              return const SizedBox(
                height: 220,
                child: Center(child: Text('No gift options available.')),
              );
            }

            return SizedBox(
              height: 560,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Text(
                    'Send gift',
                    style: Theme.of(context).textTheme.headline6,
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<int>(
                    value: _selectedRecipientId,
                    decoration: const InputDecoration(
                      labelText: 'Recipient',
                      border: OutlineInputBorder(),
                    ),
                    items: <DropdownMenuItem<int>>[
                      for (final recipient in data.recipients)
                        DropdownMenuItem<int>(
                          value: _readInt(recipient, <String>['user_id']),
                          child: Text(_read(
                            recipient,
                            <String>['display_name', 'username'],
                          )),
                        ),
                    ],
                    onChanged: _sendingGiftId == null
                        ? (int? value) {
                            setState(() => _selectedRecipientId = value);
                          }
                        : null,
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: ListView.builder(
                      itemCount: data.gifts.length,
                      itemBuilder: (BuildContext context, int index) {
                        final gift = data.gifts[index];
                        final giftId = _readInt(gift, <String>['id']);
                        final sending = _sendingGiftId == giftId;
                        return Card(
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor: const Color(0xFFFCE4EC),
                              child: Icon(
                                _giftIcon(gift),
                                color: const Color(0xFFE91E63),
                              ),
                            ),
                            title: Text(_read(gift, <String>['name'])),
                            subtitle: Text(
                              '${_money(gift['price'])} - receiver gets ${_money(gift['redeemable_amount'])}',
                            ),
                            trailing: ElevatedButton(
                              onPressed:
                                  _sendingGiftId == null ? () => _sendGift(gift) : null,
                              child: sending
                                  ? const SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Text('Send'),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _GiftData {
  const _GiftData({
    this.gifts = const <Map<String, dynamic>>[],
    this.recipients = const <Map<String, dynamic>>[],
  });

  final List<Map<String, dynamic>> gifts;
  final List<Map<String, dynamic>> recipients;
}

class _CenteredMessage extends StatelessWidget {
  const _CenteredMessage({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(message, textAlign: TextAlign.center),
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

String _conversationTitleFromRow(Map<String, dynamic> row) {
  final name = _read(row, <String>[
    'display_name',
    'other_display_name',
    'member_name',
    'recipient_name',
    'sender_name',
    'full_name',
    'name',
    'username',
    'other_username',
    'email',
  ]);
  if (name.isNotEmpty && !_looksLikeId(name)) {
    return name;
  }

  final title = _read(row, <String>['title']);
  if (title.isNotEmpty && !_looksLikeId(title)) {
    return title;
  }

  return '';
}

bool _looksLikeId(String value) {
  return RegExp(r'^\d+$').hasMatch(value.trim());
}

int? _readInt(Map<String, dynamic> row, List<String> keys) {
  for (final key in keys) {
    final value = row[key];
    if (value is int) {
      return value;
    }
    if (value is num) {
      return value.toInt();
    }
    final parsed = int.tryParse(value?.toString() ?? '');
    if (parsed != null) {
      return parsed;
    }
  }
  return null;
}

String _messageText(Map<String, dynamic> message) {
  final body = _read(message, <String>['body', 'message', 'content', 'text']);
  final giftMatch = RegExp(r'^\[gift:\d+\]\s*(.*)$').firstMatch(body);
  if (giftMatch == null) {
    return body;
  }
  return giftMatch.group(1) ?? body;
}

String _messagePreview(String body) {
  final giftMatch = RegExp(r'^\[gift:\d+\]\s*(.*)$').firstMatch(body);
  if (giftMatch == null) {
    return body;
  }
  return giftMatch.group(1) ?? body;
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

IconData _giftIcon(Map<String, dynamic> gift) {
  final icon = _read(gift, <String>['icon']);
  if (icon.contains('flower')) {
    return Icons.local_florist;
  }
  if (icon.contains('cup') || icon.contains('coffee')) {
    return Icons.local_cafe;
  }
  if (icon.contains('star')) {
    return Icons.auto_awesome;
  }
  if (icon.contains('egg') || icon.contains('food')) {
    return Icons.restaurant;
  }
  return Icons.card_giftcard;
}

String _money(dynamic value) {
  final amount = double.tryParse(value?.toString() ?? '') ?? 0;
  return 'NGN ${amount.toStringAsFixed(0)}';
}
