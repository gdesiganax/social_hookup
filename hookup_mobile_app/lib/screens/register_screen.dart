import 'package:flutter/material.dart';

import '../services/api_service.dart';
import 'authenticated_shell_screen.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({
    super.key,
    this.onAuthenticated,
  });

  final Future<void> Function(AuthResult result)? onAuthenticated;

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _apiService = ApiService();
  final _displayNameController = TextEditingController();
  final _usernameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _ageController = TextEditingController();
  final _cityController = TextEditingController();
  final _bioController = TextEditingController();

  String _gender = 'female';
  String _lookingFor = 'everyone';
  bool _isLoading = false;
  bool _obscurePassword = true;

  @override
  void dispose() {
    _displayNameController.dispose();
    _usernameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _ageController.dispose();
    _cityController.dispose();
    _bioController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final form = _formKey.currentState;
    if (form == null || !form.validate() || _isLoading) {
      return;
    }

    FocusScope.of(context).unfocus();
    setState(() => _isLoading = true);
    try {
      final result = await _apiService.register(
        email: _emailController.text,
        password: _passwordController.text,
        displayName: _displayNameController.text,
        username: _usernameController.text,
        age: int.parse(_ageController.text.trim()),
        city: _cityController.text,
        bio: _bioController.text,
        gender: _gender,
        lookingFor: _lookingFor,
      );

      if (!mounted) {
        return;
      }

      final onAuthenticated = widget.onAuthenticated;
      if (onAuthenticated != null) {
        await onAuthenticated(result);
        if (mounted) {
          Navigator.of(context).popUntil(
            (Route<dynamic> route) => route.isFirst,
          );
        }
        return;
      }

      Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(
          builder: (_) => AuthenticatedShellScreen(
            user: result.user,
            token: result.token,
          ),
        ),
      );
    } on ApiException catch (error) {
      _showMessage(error.message);
    } on FormatException {
      _showMessage('Enter a valid age.');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _showMessage(String message) {
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          behavior: SnackBarBehavior.floating,
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Create account')),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    Text(
                      'Join Hookup',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.headline4,
                    ),
                    const SizedBox(height: 24),
                    TextFormField(
                      controller: _displayNameController,
                      enabled: !_isLoading,
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(
                        labelText: 'Display name',
                        prefixIcon: Icon(Icons.badge_outlined),
                        border: OutlineInputBorder(),
                      ),
                      validator: _required('Enter your display name.'),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _usernameController,
                      enabled: !_isLoading,
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(
                        labelText: 'Username',
                        prefixIcon: Icon(Icons.alternate_email),
                        border: OutlineInputBorder(),
                      ),
                      validator: _required('Choose a username.'),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _emailController,
                      enabled: !_isLoading,
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.next,
                      autofillHints: const <String>[AutofillHints.email],
                      decoration: const InputDecoration(
                        labelText: 'Email',
                        prefixIcon: Icon(Icons.email_outlined),
                        border: OutlineInputBorder(),
                      ),
                      validator: (String? value) {
                        final email = value?.trim() ?? '';
                        if (email.isEmpty) {
                          return 'Enter your email address.';
                        }
                        if (!email.contains('@')) {
                          return 'Enter a valid email address.';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _passwordController,
                      enabled: !_isLoading,
                      obscureText: _obscurePassword,
                      textInputAction: TextInputAction.next,
                      autofillHints: const <String>[AutofillHints.newPassword],
                      decoration: InputDecoration(
                        labelText: 'Password',
                        prefixIcon: const Icon(Icons.lock_outline),
                        border: const OutlineInputBorder(),
                        suffixIcon: IconButton(
                          tooltip: _obscurePassword
                              ? 'Show password'
                              : 'Hide password',
                          onPressed: _isLoading
                              ? null
                              : () {
                                  setState(() {
                                    _obscurePassword = !_obscurePassword;
                                  });
                                },
                          icon: Icon(
                            _obscurePassword
                                ? Icons.visibility_outlined
                                : Icons.visibility_off_outlined,
                          ),
                        ),
                      ),
                      validator: (String? value) {
                        if ((value ?? '').length < 6) {
                          return 'Use at least 6 characters.';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: TextFormField(
                            controller: _ageController,
                            enabled: !_isLoading,
                            keyboardType: TextInputType.number,
                            textInputAction: TextInputAction.next,
                            decoration: const InputDecoration(
                              labelText: 'Age',
                              border: OutlineInputBorder(),
                            ),
                            validator: (String? value) {
                              final age = int.tryParse(value?.trim() ?? '');
                              if (age == null || age < 18) {
                                return '18+ only.';
                              }
                              return null;
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextFormField(
                            controller: _cityController,
                            enabled: !_isLoading,
                            textInputAction: TextInputAction.next,
                            decoration: const InputDecoration(
                              labelText: 'City',
                              border: OutlineInputBorder(),
                            ),
                            validator: _required('Enter your city.'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            value: _gender,
                            decoration: const InputDecoration(
                              labelText: 'Gender',
                              border: OutlineInputBorder(),
                            ),
                            items: const <DropdownMenuItem<String>>[
                              DropdownMenuItem<String>(
                                value: 'female',
                                child: Text('Female'),
                              ),
                              DropdownMenuItem<String>(
                                value: 'male',
                                child: Text('Male'),
                              ),
                              DropdownMenuItem<String>(
                                value: 'other',
                                child: Text('Other'),
                              ),
                            ],
                            onChanged: _isLoading
                                ? null
                                : (String? value) {
                                    setState(() {
                                      _gender = value ?? 'female';
                                    });
                                  },
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            value: _lookingFor,
                            decoration: const InputDecoration(
                              labelText: 'Looking for',
                              border: OutlineInputBorder(),
                            ),
                            items: const <DropdownMenuItem<String>>[
                              DropdownMenuItem<String>(
                                value: 'everyone',
                                child: Text('Everyone'),
                              ),
                              DropdownMenuItem<String>(
                                value: 'female',
                                child: Text('Women'),
                              ),
                              DropdownMenuItem<String>(
                                value: 'male',
                                child: Text('Men'),
                              ),
                            ],
                            onChanged: _isLoading
                                ? null
                                : (String? value) {
                                    setState(() {
                                      _lookingFor = value ?? 'everyone';
                                    });
                                  },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _bioController,
                      enabled: !_isLoading,
                      minLines: 2,
                      maxLines: 4,
                      decoration: const InputDecoration(
                        labelText: 'Bio',
                        border: OutlineInputBorder(),
                      ),
                      validator: _required('Write a short bio.'),
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      height: 52,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _submit,
                        child: _isLoading
                            ? const SizedBox(
                                height: 22,
                                width: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.5,
                                ),
                              )
                            : const Text('Create account'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

FormFieldValidator<String> _required(String message) {
  return (String? value) {
    if ((value ?? '').trim().isEmpty) {
      return message;
    }
    return null;
  };
}
