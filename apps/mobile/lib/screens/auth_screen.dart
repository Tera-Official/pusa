import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const _authRedirect = 'com.teraofficial.pusa://login-callback';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key, this.passwordRecovery = false});
  final bool passwordRecovery;

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

enum _AuthMode { login, signup, confirmation, recovery, newPassword }

class _AuthScreenState extends State<AuthScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirmPassword = TextEditingController();
  _AuthMode _mode = _AuthMode.login;
  bool _busy = false;
  bool _obscure = true;
  String? _error;
  String? _notice;

  SupabaseClient get _client => Supabase.instance.client;

  @override
  void initState() {
    super.initState();
    if (widget.passwordRecovery) _mode = _AuthMode.newPassword;
  }

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    _confirmPassword.dispose();
    super.dispose();
  }

  String? _emailValidator(String? value) {
    final email = value?.trim() ?? '';
    if (email.isEmpty) return 'Enter your email address.';
    if (!RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(email)) {
      return 'Enter a valid email address.';
    }
    return null;
  }

  String? _passwordValidator(String? value) {
    if (value == null || value.isEmpty) return 'Enter your password.';
    if (value.length < 8) return 'Use at least 8 characters.';
    return null;
  }

  Future<void> _perform(Future<void> Function() action) async {
    if (_busy) return;
    setState(() { _busy = true; _error = null; _notice = null; });
    try {
      await action();
    } on AuthException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) setState(() => _error = 'Something went wrong. Check your connection and try again.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _signUp() async {
    if (!_formKey.currentState!.validate()) return;
    await _perform(() async {
      final response = await _client.auth.signUp(
        email: _email.text.trim().toLowerCase(),
        password: _password.text,
        emailRedirectTo: _authRedirect,
        data: {'display_name': _name.text.trim()},
      );
      if (response.session == null && mounted) {
        setState(() {
          _mode = _AuthMode.confirmation;
          _notice = 'We sent a confirmation link to ${_email.text.trim()}. Open it on this device to verify your email, then sign in.';
        });
      }
    });
  }

  Future<void> _signIn() async {
    if (!_formKey.currentState!.validate()) return;
    await _perform(() async {
      await _client.auth.signInWithPassword(
        email: _email.text.trim().toLowerCase(),
        password: _password.text,
      );
    });
  }

  Future<void> _sendRecovery() async {
    if (!_formKey.currentState!.validate()) return;
    await _perform(() async {
      await _client.auth.resetPasswordForEmail(
        _email.text.trim().toLowerCase(),
        redirectTo: _authRedirect,
      );
      if (mounted) setState(() {
        _mode = _AuthMode.recovery;
        _notice = 'If an account exists for this email, a password-reset link has been sent.';
      });
    });
  }

  Future<void> _saveNewPassword() async {
    if (!_formKey.currentState!.validate()) return;
    if (_password.text != _confirmPassword.text) {
      setState(() => _error = 'Passwords do not match.');
      return;
    }
    await _perform(() async {
      await _client.auth.updateUser(UserAttributes(password: _password.text));
      if (mounted) {
        await _client.auth.signOut();
        setState(() {
          _mode = _AuthMode.login;
          _password.clear();
          _confirmPassword.clear();
          _notice = 'Your password has been updated. Sign in with your new password.';
        });
      }
    });
  }

  void _switch(_AuthMode mode) {
    setState(() {
      _mode = mode;
      _error = null;
      _notice = null;
      _password.clear();
      _confirmPassword.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final isSignup = _mode == _AuthMode.signup;
    final isLogin = _mode == _AuthMode.login;
    final isReset = _mode == _AuthMode.newPassword;
    final isForm = isSignup || isLogin || _mode == _AuthMode.recovery || _mode == _AuthMode.recovery;
    final title = switch (_mode) {
      _AuthMode.login => 'Welcome back',
      _AuthMode.signup => 'Create your Pusa account',
      _AuthMode.confirmation => 'Check your email',
      _AuthMode.recovery => 'Check your inbox',
      _AuthMode.newPassword => 'Choose a new password',
    };
    final subtitle = switch (_mode) {
      _AuthMode.login => 'Sign in to organise your money with purpose.',
      _AuthMode.signup => 'One account to give every franc a purpose.',
      _AuthMode.confirmation => 'Your account is almost ready.',
      _AuthMode.recovery => 'Follow the secure link in your email to continue.',
      _AuthMode.newPassword => 'Choose a strong password you have not used before.',
    };

    return Scaffold(
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
                  children: [
                    Center(child: Container(
                      width: 62, height: 62,
                      decoration: BoxDecoration(color: const Color(0xFF101B2D), borderRadius: BorderRadius.circular(20)),
                      child: const Icon(Icons.savings_rounded, color: Color(0xFFB8F36B), size: 31),
                    )),
                    const SizedBox(height: 24),
                    Text(title, textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 25, fontWeight: FontWeight.w900, color: Color(0xFF101B2D))),
                    const SizedBox(height: 8),
                    Text(subtitle, textAlign: TextAlign.center,
                      style: const TextStyle(color: Color(0xFF7B8795), height: 1.5)),
                    const SizedBox(height: 28),
                    if (isForm || isReset) ...[
                      if (isSignup) ...[
                        _field(_name, 'Full name', validator: (v) =>
                          v == null || v.trim().isEmpty ? 'Enter your name.' : null),
                        const SizedBox(height: 13),
                      ],
                      if (_mode != _AuthMode.recovery && !isReset || isLogin || isSignup)
                        _field(_email, 'Email address', keyboard: TextInputType.emailAddress,
                          validator: _emailValidator),
                      if (isLogin || isSignup || isReset) ...[
                        const SizedBox(height: 13),
                        _field(_password, isReset ? 'New password' : 'Password',
                          obscure: _obscure,
                          suffix: IconButton(
                            onPressed: () => setState(() => _obscure = !_obscure),
                            icon: Icon(_obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                          ),
                          validator: _passwordValidator),
                      ],
                      if (isSignup || isReset) ...[
                        const SizedBox(height: 13),
                        _field(_confirmPassword, 'Confirm password', obscure: true,
                          validator: (v) => v != _password.text ? 'Passwords do not match.' : null),
                      ],
                    ],
                    if (_notice != null) ...[
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(color: const Color(0xFFEAF4E2), borderRadius: BorderRadius.circular(12)),
                        child: Text(_notice!, style: const TextStyle(color: Color(0xFF24451D))),
                      ),
                      const SizedBox(height: 12),
                    ],
                    if (_error != null) ...[
                      Text(_error!, style: const TextStyle(color: Colors.red, fontSize: 13)),
                      const SizedBox(height: 12),
                    ],
                    if (isLogin || isSignup || isReset || _mode == _AuthMode.recovery)
                      FilledButton(
                        onPressed: _busy ? null : () {
                          if (isLogin) _signIn();
                          else if (isSignup) _signUp();
                          else if (isReset) _saveNewPassword();
                          else _sendRecovery();
                        },
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFF101B2D),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                        child: _busy
                          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                          : Text(isLogin ? 'Sign in' : isSignup ? 'Create account' : isReset ? 'Save new password' : 'Send reset link'),
                      ),
                    const SizedBox(height: 12),
                    if (isLogin) ...[
                      TextButton(onPressed: () => _switch(_AuthMode.recovery), child: const Text('Forgot password?')),
                      TextButton(onPressed: () => _switch(_AuthMode.signup), child: const Text('New to Pusa? Create an account')),
                    ] else if (isSignup || _mode == _AuthMode.recovery || _mode == _AuthMode.confirmation) ...[
                      TextButton(onPressed: () => _switch(_AuthMode.login), child: const Text('Back to sign in')),
                    ] else if (isReset) ...[
                      TextButton(onPressed: () => _switch(_AuthMode.login), child: const Text('Back to sign in')),
                    ],
                    const SizedBox(height: 20),
                    const Text('Phone verification will be available in a future update.',
                      textAlign: TextAlign.center, style: TextStyle(color: Color(0xFF8993A0), fontSize: 12)),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _field(
    TextEditingController controller,
    String label, {
    TextInputType keyboard = TextInputType.text,
    bool obscure = false,
    Widget? suffix,
    String? Function(String?)? validator,
  }) => TextFormField(
    controller: controller,
    keyboardType: keyboard,
    obscureText: obscure,
    validator: validator,
    decoration: InputDecoration(
      labelText: label,
      suffixIcon: suffix,
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
    ),
  );
}
