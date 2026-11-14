import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key, required this.backendConfigured});
  final bool backendConfigured;
  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _nameController = TextEditingController();
  Map<String, dynamic>? _profile;
  bool _loading = true;
  bool _saving = false;
  String? _message;
  String? _error;

  @override
  void initState() {
    super.initState();
    if (widget.backendConfigured) {
      _loadProfile();
    } else {
      _loading = false;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;
    try {
      final row = await Supabase.instance.client.from('profiles')
          .select('display_name,email,phone_e164,preferred_currency')
          .eq('id', user.id).maybeSingle();
      if (!mounted) return;
      setState(() {
        _profile = row;
        _nameController.text = row?['display_name'] as String? ?? '';
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() {
        _loading = false;
        _error = 'Unable to load your profile. Check your connection and try again.';
      });
    }
  }

  Future<void> _saveName() async {
    final name = _nameController.text.trim();
    if (name.isEmpty || name.length > 80) {
      setState(() => _error = 'Enter a name between 1 and 80 characters.');
      return;
    }
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;
    setState(() { _saving = true; _message = null; _error = null; });
    try {
      await Supabase.instance.client.from('profiles').update({'display_name': name}).eq('id', user.id);
      await _loadProfile();
      if (mounted) setState(() => _message = 'Profile updated.');
    } catch (_) {
      if (mounted) setState(() => _error = 'Could not save your profile. Please try again.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _signOut() async => Supabase.instance.client.auth.signOut();

  @override
  Widget build(BuildContext context) {
    if (!widget.backendConfigured) {
      return Scaffold(
        appBar: AppBar(title: const Text('Profile & settings', style: TextStyle(fontWeight: FontWeight.w800))),
        body: const Center(child: Text('Demo profile · Connect the Pusa backend to sign in.')),
      );
    }
    final user = Supabase.instance.client.auth.currentUser;
    final phone = _profile?['phone_e164'] as String? ?? user?.phone ?? 'Not available';
    final email = _profile?['email'] as String? ?? 'Not provided';
    return Scaffold(
      appBar: AppBar(title: const Text('Profile & settings', style: TextStyle(fontWeight: FontWeight.w800))),
      body: _loading ? const Center(child: CircularProgressIndicator()) : ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const CircleAvatar(radius: 34, backgroundColor: Color(0xFFE7EEDC),
            child: Icon(Icons.person_outline_rounded, size: 34, color: Color(0xFF101B2D))),
          const SizedBox(height: 12),
          Text(_profile?['display_name'] as String? ?? 'Pusa member', textAlign: TextAlign.center,
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
          const SizedBox(height: 4),
          Text(phone, textAlign: TextAlign.center, style: const TextStyle(color: Color(0xFF7B8795))),
          const SizedBox(height: 28),
          const Text('Personal information', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
          const SizedBox(height: 12),
          TextField(controller: _nameController, maxLength: 80,
            decoration: const InputDecoration(labelText: 'Full name', border: OutlineInputBorder(), filled: true, fillColor: Colors.white)),
          const SizedBox(height: 12),
          _detail('Email address', email),
          _detail('Verified phone', phone),
          _detail('Currency', 'XAF'),
          if (_error != null) Text(_error!, style: const TextStyle(color: Colors.red)),
          if (_message != null) Text(_message!, style: const TextStyle(color: Colors.green)),
          const SizedBox(height: 14),
          FilledButton(onPressed: _saving ? null : _saveName,
            child: _saving ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Save profile')),
          const SizedBox(height: 26),
          const Divider(),
          const ListTile(leading: Icon(Icons.lock_outline), title: Text('Password & account recovery'),
            subtitle: Text('Use Forgot password on the sign-in screen to reset your password.')),
          ListTile(leading: const Icon(Icons.logout_rounded, color: Colors.red),
            title: const Text('Sign out', style: TextStyle(color: Colors.red)), onTap: _signOut),
        ],
      ),
    );
  }

  Widget _detail(String label, String value) => ListTile(
    contentPadding: EdgeInsets.zero,
    title: Text(label, style: const TextStyle(color: Color(0xFF7B8795), fontSize: 12)),
    subtitle: Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
  );
}
