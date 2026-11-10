import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

enum _AuthMode { login, signup, verifySignup, recover, verifyRecovery, setPassword }

class _AuthScreenState extends State<AuthScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController(text: '+237');
  final _password = TextEditingController();
  final _confirmPassword = TextEditingController();
  final _otp = TextEditingController();

  _AuthMode _mode = _AuthMode.login;
  bool _busy = false;
  bool _obscurePassword = true;
  bool _acceptedTerms = false;
  bool _acceptedPrivacy = false;
  String? _pendingPhone;
  String? _error;

  SupabaseClient get _supabase => Supabase.instance.client;
  static const _ink = Color(0xFF101B2D);
  static const _green = Color(0xFFB8F36B);

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _phone.dispose();
    _password.dispose();
    _confirmPassword.dispose();
    _otp.dispose();
    super.dispose();
  }

  String? _required(String? value, String label) =>
      value == null || value.trim().isEmpty ? 'Enter your $label.' : null;

  String? _validatePhone(String? value) {
    final phone = value?.trim() ?? '';
    if (!RegExp(r'^\+[1-9]\d{7,14}$').hasMatch(phone)) {
      return 'Use international format, e.g. +2376XXXXXXXX.';
    }
    return null;
  }

  Future<void> _run(Future<void> Function() action) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await action();
    } on AuthException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (e) {
      if (mounted) setState(() => _error = 'Something went wrong. Please try again.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _signUp() async {
    if (!_formKey.currentState!.validate()) return;
    if (!_acceptedTerms || !_acceptedPrivacy) {
      setState(() => _error = 'Please accept the Terms and Privacy Notice to continue.');
      return;
    }
    await _run(() async {
      final phone = _phone.text.trim();
      final response = await _supabase.auth.signUp(
        phone: phone,
        password: _password.text,
        data: {
          'display_name': _name.text.trim(),
          'email': _email.text.trim().toLowerCase(),
          'terms_accepted': true,
          'privacy_accepted': true,
          'consent_version': '2026-11-v1',
        },
      );
      if (response.session == null) {
        setState(() {
          _pendingPhone = phone;
          _mode = _AuthMode.verifySignup;
        });
      }
    });
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;
    await _run(() async {
      await _supabase.auth.signInWithPassword(
        phone: _phone.text.trim(),
        password: _password.text,
      );
    });
  }

  Future<void> _sendRecoveryCode() async {
    if (!_formKey.currentState!.validate()) return;
    await _run(() async {
      final phone = _phone.text.trim();
      await _supabase.auth.signInWithOtp(
        phone: phone,
        shouldCreateUser: false,
      );
      setState(() {
        _pendingPhone = phone;
        _mode = _AuthMode.verifyRecovery;
      });
    });
  }

  Future<void> _verifyCode() async {
    if (_otp.text.trim().length < 6) {
      setState(() => _error = 'Enter the 6-digit code sent to your phone.');
      return;
    }
    await _run(() async {
      await _supabase.auth.verifyOTP(
        phone: _pendingPhone!,
        token: _otp.text.trim(),
        type: OtpType.sms,
      );
      if (_mode == _AuthMode.verifyRecovery) {
        setState(() => _mode = _AuthMode.setPassword);
      }
    });
  }

  Future<void> _resendCode() async {
    await _run(() async {
      await _supabase.auth.resend(
        type: OtpType.sms,
        phone: _pendingPhone!,
      );
    });
  }

  Future<void> _setNewPassword() async {
    if (!_formKey.currentState!.validate()) return;
    await _run(() async {
      await _supabase.auth.updateUser(
        UserAttributes(password: _password.text),
      );
      await _supabase.auth.signOut();
      setState(() {
        _password.clear();
        _confirmPassword.clear();
        _otp.clear();
        _mode = _AuthMode.login;
      });
    });
  }

  void _switch(_AuthMode mode) {
    setState(() {
      _mode = mode;
      _error = null;
      _password.clear();
      _confirmPassword.clear();
      _otp.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final isSignup = _mode == _AuthMode.signup;
    final isLogin = _mode == _AuthMode.login;
    final isCode = _mode == _AuthMode.verifySignup || _mode == _AuthMode.verifyRecovery;
    final isPasswordReset = _mode == _AuthMode.setPassword;
    final title = switch (_mode) {
      _AuthMode.login => 'Welcome back',
      _AuthMode.signup => 'Create your Pusa account',
      _AuthMode.verifySignup => 'Verify your phone',
      _AuthMode.recover => 'Recover your account',
      _AuthMode.verifyRecovery => 'Confirm it’s you',
      _AuthMode.setPassword => 'Set a new password',
    };
    final subtitle = switch (_mode) {
      _AuthMode.login => 'Sign in to organise your money with purpose.',
      _AuthMode.signup => 'One account to give every franc a purpose.',
      _AuthMode.verifySignup => 'Enter the SMS code sent to $_pendingPhone.',
      _AuthMode.recover => 'We’ll send a one-time code to your registered phone.',
      _AuthMode.verifyRecovery => 'Enter the recovery code sent to $_pendingPhone.',
      _AuthMode.setPassword => 'Choose a new password for your account.',
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
                    Center(
                      child: Container(
                        width: 62,
                        height: 62,
                        decoration: BoxDecoration(
                          color: _ink,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Icon(Icons.savings_rounded, color: _green, size: 31),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(title, textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 25, fontWeight: FontWeight.w900, color: _ink)),
                    const SizedBox(height: 8),
                    Text(subtitle, textAlign: TextAlign.center,
                      style: const TextStyle(color: Color(0xFF7B8795), height: 1.5)),
                    const SizedBox(height: 28),
                    if (isSignup) ...[
                      _field(_name, 'Full name', validator: (v) => _required(v, 'name')),
                      const SizedBox(height: 13),
                      _field(_email, 'Email address', keyboard: TextInputType.emailAddress,
                        validator: (v) {
                          if (_required(v, 'email address') != null) return 'Enter your email address.';
                          return RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(v!.trim())
                              ? null : 'Enter a valid email address.';
                        }),
                      const SizedBox(height: 13),
                    ],
                    if (isLogin || isSignup || _mode == _AuthMode.recover) ...[
                      _field(_phone, 'Phone number (+237...)', keyboard: TextInputType.phone,
                        validator: _validatePhone),
                      const SizedBox(height: 13),
                    ],
                    if (isLogin || isSignup || isPasswordReset) ...[
                      _field(_password, isPasswordReset ? 'New password' : 'Password',
                        obscure: _obscurePassword,
                        suffix: IconButton(
                          onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                          icon: Icon(_obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                        ),
                        validator: (v) {
                          if (_required(v, 'password') != null) return 'Enter a password.';
                          if (v!.length < 8) return 'Use at least 8 characters.';
                          return null;
                        }),
                      if (isSignup || isPasswordReset) ...[
                        const SizedBox(height: 13),
                        _field(_confirmPassword, 'Confirm password', obscure: true,
                          validator: (v) => v != _password.text ? 'Passwords do not match.' : null),
                      ],
                    ],
                    if (isCode) ...[
                      _field(_otp, '6-digit SMS code', keyboard: TextInputType.number,
                        validator: (v) => v == null || v.trim().length != 6 ? 'Enter the 6-digit code.' : null),
                      Align(alignment: Alignment.centerRight,
                        child: TextButton(onPressed: _busy ? null : _resendCode, child: const Text('Resend code'))),
                    ],
                    if (isSignup) ...[
                      const SizedBox(height: 8),
                      CheckboxListTile(
                        contentPadding: EdgeInsets.zero,
                        value: _acceptedTerms,
                        onChanged: (v) => setState(() => _acceptedTerms = v ?? false),
                        controlAffinity: ListTileControlAffinity.leading,
                        title: const Text('I agree to the Terms of Service.', style: TextStyle(fontSize: 12)),
                      ),
                      CheckboxListTile(
                        contentPadding: EdgeInsets.zero,
                        value: _acceptedPrivacy,
                        onChanged: (v) => setState(() => _acceptedPrivacy = v ?? false),
                        controlAffinity: ListTileControlAffinity.leading,
                        title: const Text('I have read the Privacy Notice.', style: TextStyle(fontSize: 12)),
                      ),
                    ],
                    if (_error != null) ...[
                      const SizedBox(height: 10),
                      Text(_error!, style: const TextStyle(color: Colors.red, fontSize: 13)),
                    ],
                    const SizedBox(height: 18),
                    FilledButton(
                      onPressed: _busy ? null : () {
                        if (isLogin) {
                          _login();
                        } else if (isSignup) {
                          _signUp();
                        } else if (_mode == _AuthMode.recover) {
                          _sendRecoveryCode();
                        } else if (isCode) {
                          _verifyCode();
                        } else if (isPasswordReset) {
                          _setNewPassword();
                        }
                      },
                      style: FilledButton.styleFrom(
                        backgroundColor: _ink,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      child: _busy
                          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                          : Text(isLogin ? 'Sign in' : isSignup ? 'Create account' :
                              isCode ? 'Verify code' : isPasswordReset ? 'Save new password' : 'Send recovery code'),
                    ),
                    const SizedBox(height: 12),
                    if (isLogin) ...[
                      TextButton(onPressed: () => _switch(_AuthMode.recover), child: const Text('Forgot password?')),
                      TextButton(onPressed: () => _switch(_AuthMode.signup),
                        child: const Text('New to Pusa? Create an account')),
                    ] else if (isSignup || _mode == _AuthMode.recover) ...[
                      TextButton(onPressed: () => _switch(_AuthMode.login), child: const Text('Already have an account? Sign in')),
                    ] else if (isPasswordReset) ...[
                      TextButton(onPressed: () => _switch(_AuthMode.login), child: const Text('Back to sign in')),
                    ],
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
  }) {
    return TextFormField(
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
}
