import 'package:flutter/material.dart';

import '../models/profile.dart';
import '../models/user.dart';
import '../services/api_service.dart';
import '../widgets/profile_status.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({
    super.key,
    required this.user,
    required this.token,
  });

  final User user;
  final String token;

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _apiService = ApiService();
  final _displayNameController = TextEditingController();
  final _usernameController = TextEditingController();
  final _cityController = TextEditingController();
  final _bioController = TextEditingController();
  late Future<Profile?> _profileFuture;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _profileFuture = _loadProfile();
  }

  @override
  void dispose() {
    _displayNameController.dispose();
    _usernameController.dispose();
    _cityController.dispose();
    _bioController.dispose();
    super.dispose();
  }

  Future<Profile?> _loadProfile() async {
    final mine = await _apiService.myProfile(widget.token);

    if (mine != null) {
      _displayNameController.text = mine.displayName;
      _usernameController.text = mine.username;
      _cityController.text = mine.city;
      _bioController.text = mine.bio;
    }

    return mine;
  }

  Future<void> _save() async {
    if (_saving) {
      return;
    }

    setState(() => _saving = true);
    try {
      await _apiService.updateProfile(
        token: widget.token,
        userId: widget.user.id,
        values: <String, dynamic>{
          'display_name': _displayNameController.text.trim(),
          'username': _usernameController.text.trim(),
          'city': _cityController.text.trim(),
          'bio': _bioController.text.trim(),
        },
      );
      _showMessage('Profile updated.');
      setState(() => _profileFuture = _loadProfile());
    } on ApiException catch (error) {
      _showMessage(error.message);
    } finally {
      if (mounted) {
        setState(() => _saving = false);
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: FutureBuilder<Profile?>(
        future: _profileFuture,
        builder: (BuildContext context, AsyncSnapshot<Profile?> snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(snapshot.error.toString()),
              ),
            );
          }

          final profile = snapshot.data;
          return ListView(
            padding: const EdgeInsets.all(16),
            children: <Widget>[
              Center(
                child: ProfileAvatar(
                  imageUrl: profile == null
                      ? ''
                      : _apiService.resolveMediaUrl(profile.avatarUrl),
                  isOnline: profile?.isOnline ?? false,
                  isVerified: profile?.hasSubmittedVerification ?? false,
                  radius: 48,
                ),
              ),
              if (profile != null) ...<Widget>[
                const SizedBox(height: 10),
                Center(child: ProfileStatusBadges(profile: profile)),
              ],
              const SizedBox(height: 12),
              Center(
                child: Text(
                  widget.user.email,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: _displayNameController,
                decoration: const InputDecoration(
                  labelText: 'Display name',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _usernameController,
                decoration: const InputDecoration(
                  labelText: 'Username',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _cityController,
                decoration: const InputDecoration(
                  labelText: 'City',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _bioController,
                minLines: 3,
                maxLines: 5,
                decoration: const InputDecoration(
                  labelText: 'Bio',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 18),
              SizedBox(
                height: 50,
                child: ElevatedButton.icon(
                  onPressed: _saving ? null : _save,
                  icon: _saving
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.save),
                  label: const Text('Save profile'),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
