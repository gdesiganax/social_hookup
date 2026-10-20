import 'dart:async';

import 'package:flutter/material.dart';

import '../models/user.dart';
import '../services/api_service.dart';
import 'dashboard_screen.dart';
import 'guest_home_screen.dart';
import 'matches_screen.dart';
import 'messages_screen.dart';
import 'profile_screen.dart';

class AuthenticatedShellScreen extends StatefulWidget {
  const AuthenticatedShellScreen({
    super.key,
    required this.user,
    required this.token,
    this.onLogout,
  });

  final User user;
  final String token;
  final Future<void> Function()? onLogout;

  @override
  State<AuthenticatedShellScreen> createState() =>
      _AuthenticatedShellScreenState();
}

class _AuthenticatedShellScreenState extends State<AuthenticatedShellScreen> {
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  final _apiService = ApiService();

  Timer? _notificationTimer;
  String _lastPostSignature = '';
  String _lastConversationSignature = '';
  bool _hasNotificationBaseline = false;
  int _newPostCount = 0;
  int _newMessageCount = 0;
  int _selectedIndex = 1;

  void _select(int index) {
    setState(() {
      _selectedIndex = index;
      if (index == 1) {
        _newPostCount = 0;
      }
      if (index == 3) {
        _newMessageCount = 0;
      }
    });
    if (_scaffoldKey.currentState?.isDrawerOpen ?? false) {
      Navigator.of(context).pop();
    }
  }

  @override
  void initState() {
    super.initState();
    _checkNotifications();
    _notificationTimer = Timer.periodic(
      const Duration(seconds: 30),
      (_) => _checkNotifications(showToast: true),
    );
  }

  @override
  void dispose() {
    _notificationTimer?.cancel();
    super.dispose();
  }

  Future<void> _logout() async {
    final onLogout = widget.onLogout;
    if (onLogout != null) {
      await onLogout();
      return;
    }

    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute<void>(builder: (_) => const GuestHomeScreen()),
      (Route<dynamic> route) => false,
    );
  }

  Future<void> _checkNotifications({bool showToast = false}) async {
    try {
      final results = await Future.wait<List<Map<String, dynamic>>>([
        _apiService.feedPosts(widget.token, limit: 1),
        _apiService.myConversations(widget.token),
      ]);
      if (!mounted) {
        return;
      }

      final postSignature = _signatureForFirst(results[0]);
      final conversationSignature = _signatureForRows(results[1]);

      if (!_hasNotificationBaseline) {
        setState(() {
          _lastPostSignature = postSignature;
          _lastConversationSignature = conversationSignature;
          _hasNotificationBaseline = true;
        });
        return;
      }

      final hasNewPost =
          postSignature.isNotEmpty && postSignature != _lastPostSignature;
      final hasNewMessage = conversationSignature.isNotEmpty &&
          conversationSignature != _lastConversationSignature;

      if (!hasNewPost && !hasNewMessage) {
        return;
      }

      final notifyNewPost = hasNewPost && _selectedIndex != 1;
      final notifyNewMessage = hasNewMessage && _selectedIndex != 3;

      setState(() {
        _lastPostSignature = postSignature;
        _lastConversationSignature = conversationSignature;
        if (notifyNewPost) {
          _newPostCount += 1;
        }
        if (notifyNewMessage) {
          _newMessageCount += 1;
        }
      });

      if (showToast && (notifyNewPost || notifyNewMessage)) {
        final message = notifyNewPost && notifyNewMessage
            ? 'New dashboard post and message available.'
            : notifyNewPost
                ? 'New post in the dashboard.'
                : 'New message received.';
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(message)));
      }
    } on ApiException {
      // Notifications are best effort and should never force a logout.
    }
  }

  @override
  Widget build(BuildContext context) {
    final pages = <Widget>[
      GuestHomeScreen(
        isAuthenticated: true,
        onOpenDashboard: () => _select(1),
        onOpenMatches: () => _select(2),
        onOpenMessages: () => _select(3),
        onOpenProfile: () => _select(4),
      ),
      DashboardScreen(user: widget.user, token: widget.token),
      MatchesScreen(user: widget.user, token: widget.token),
      MessagesScreen(user: widget.user, token: widget.token),
      ProfileScreen(user: widget.user, token: widget.token),
    ];

    return Scaffold(
      key: _scaffoldKey,
      drawer: _AppDrawer(
        selectedIndex: _selectedIndex,
        user: widget.user,
        onSelect: _select,
        onLogout: _logout,
      ),
      body: IndexedStack(
        index: _selectedIndex,
        children: pages,
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        type: BottomNavigationBarType.fixed,
        selectedItemColor: const Color(0xFFE91E63),
        onTap: _select,
        items: <BottomNavigationBarItem>[
          const BottomNavigationBarItem(
            icon: Icon(Icons.home_outlined),
            activeIcon: Icon(Icons.home),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: _NavigationIcon(
              icon: Icons.dashboard_outlined,
              count: _newPostCount,
            ),
            activeIcon: _NavigationIcon(
              icon: Icons.dashboard,
              count: _newPostCount,
            ),
            label: 'Dashboard',
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.favorite_border),
            activeIcon: Icon(Icons.favorite),
            label: 'Matches',
          ),
          BottomNavigationBarItem(
            icon: _NavigationIcon(
              icon: Icons.chat_bubble_outline,
              count: _newMessageCount,
            ),
            activeIcon: _NavigationIcon(
              icon: Icons.chat_bubble,
              count: _newMessageCount,
            ),
            label: 'Messages',
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.person_outline),
            activeIcon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}

class _AppDrawer extends StatelessWidget {
  const _AppDrawer({
    required this.selectedIndex,
    required this.user,
    required this.onSelect,
    required this.onLogout,
  });

  final int selectedIndex;
  final User user;
  final ValueChanged<int> onSelect;
  final VoidCallback onLogout;

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: SafeArea(
        child: Column(
          children: <Widget>[
            ListTile(
              leading: const CircleAvatar(
                backgroundColor: Color(0xFFE91E63),
                child: Icon(Icons.person, color: Colors.white),
              ),
              title: Text(user.email),
              subtitle: Text(user.role),
            ),
            const Divider(height: 1),
            _DrawerItem(
              icon: Icons.home_outlined,
              label: 'Home',
              selected: selectedIndex == 0,
              onTap: () => onSelect(0),
            ),
            _DrawerItem(
              icon: Icons.dashboard_outlined,
              label: 'Dashboard',
              selected: selectedIndex == 1,
              onTap: () => onSelect(1),
            ),
            _DrawerItem(
              icon: Icons.favorite_border,
              label: 'Matches',
              selected: selectedIndex == 2,
              onTap: () => onSelect(2),
            ),
            _DrawerItem(
              icon: Icons.chat_bubble_outline,
              label: 'Messages',
              selected: selectedIndex == 3,
              onTap: () => onSelect(3),
            ),
            _DrawerItem(
              icon: Icons.person_outline,
              label: 'Profile',
              selected: selectedIndex == 4,
              onTap: () => onSelect(4),
            ),
            const Spacer(),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.logout),
              title: const Text('Logout'),
              onTap: onLogout,
            ),
          ],
        ),
      ),
    );
  }
}

class _NavigationIcon extends StatelessWidget {
  const _NavigationIcon({
    required this.icon,
    required this.count,
  });

  final IconData icon;
  final int count;

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: <Widget>[
        Icon(icon),
        if (count > 0)
          Positioned(
            top: -6,
            right: -10,
            child: Container(
              constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
              padding: const EdgeInsets.symmetric(horizontal: 4),
              alignment: Alignment.center,
              decoration: const BoxDecoration(
                color: Color(0xFFE91E63),
                shape: BoxShape.circle,
              ),
              child: Text(
                count > 9 ? '9+' : count.toString(),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

String _signatureForFirst(List<Map<String, dynamic>> rows) {
  if (rows.isEmpty) {
    return '';
  }
  return _signatureForRow(rows.first);
}

String _signatureForRows(List<Map<String, dynamic>> rows) {
  return rows.map(_signatureForRow).join('|');
}

String _signatureForRow(Map<String, dynamic> row) {
  final id = _read(row, <String>['id', 'post_id', 'conversation_id']);
  final updatedAt = _read(row, <String>['updated_at', 'created_at']);
  final body = _read(row, <String>['last_message', 'body', 'content']);
  return '$id:$updatedAt:$body';
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

class _DrawerItem extends StatelessWidget {
  const _DrawerItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      selected: selected,
      selectedColor: const Color(0xFFE91E63),
      leading: Icon(icon),
      title: Text(label),
      onTap: onTap,
    );
  }
}
