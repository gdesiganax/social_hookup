import 'package:flutter/material.dart';

import 'screens/authenticated_shell_screen.dart';
import 'screens/guest_home_screen.dart';
import 'services/api_service.dart';
import 'services/session_store.dart';

void main() {
  runApp(const HookupApp());
}

class HookupApp extends StatelessWidget {
  const HookupApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Hookup',
      theme: ThemeData(
        primarySwatch: Colors.pink,
        inputDecorationTheme: const InputDecorationTheme(
          filled: true,
          fillColor: Color(0xFFF8F8FA),
        ),
      ),
      home: const _AuthGate(),
    );
  }
}

class _AuthGate extends StatefulWidget {
  const _AuthGate();

  @override
  State<_AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<_AuthGate> {
  final _apiService = ApiService();
  final _sessionStore = SessionStore();

  SavedSession? _session;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _restoreSession();
  }

  Future<void> _restoreSession() async {
    final session = await _sessionStore.read();
    if (session == null) {
      if (mounted) {
        setState(() => _loading = false);
      }
      return;
    }

    if (!mounted) {
      return;
    }
    setState(() {
      _session = session;
      _loading = false;
    });

    try {
      final user = await _apiService.me(session.token);
      if (!mounted) {
        return;
      }
      setState(() {
        _session = SavedSession(token: session.token, user: user);
        _loading = false;
      });
    } on ApiException {
      // Keep the saved session. Connectivity/API failures should not log out
      // the user; only the explicit Logout action clears this session.
    }
  }

  Future<void> _handleAuthenticated(AuthResult result) async {
    await _sessionStore.save(token: result.token, user: result.user);
    if (!mounted) {
      return;
    }
    setState(() {
      _session = SavedSession(token: result.token, user: result.user);
    });
  }

  Future<void> _logout() async {
    await _sessionStore.clear();
    if (!mounted) {
      return;
    }
    setState(() => _session = null);
  }

  Future<bool> _handleRootBackPressed() async {
    final focusedNode = FocusManager.instance.primaryFocus;
    if (focusedNode != null && focusedNode.context != null) {
      focusedNode.unfocus();
      return false;
    }

    return false;
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return WillPopScope(
        onWillPop: _handleRootBackPressed,
        child: const Scaffold(
          body: Center(child: CircularProgressIndicator()),
        ),
      );
    }

    final session = _session;
    if (session != null) {
      return WillPopScope(
        onWillPop: _handleRootBackPressed,
        child: AuthenticatedShellScreen(
          user: session.user,
          token: session.token,
          onLogout: _logout,
        ),
      );
    }

    return WillPopScope(
      onWillPop: _handleRootBackPressed,
      child: GuestHomeScreen(onAuthenticated: _handleAuthenticated),
    );
  }
}
