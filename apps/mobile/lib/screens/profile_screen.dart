import 'package:flutter/material.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Profile & settings',
      style: TextStyle(fontWeight: FontWeight.w800))),
    body: ListView(
      padding: const EdgeInsets.all(20),
      children: const [
        CircleAvatar(radius: 34, backgroundColor: Color(0xFFE7EEDC),
          child: Text('TT', style: TextStyle(fontSize: 20,
            color: Color(0xFF101B2D), fontWeight: FontWeight.w800))),
        SizedBox(height: 12),
        Text('Pusa preview account', textAlign: TextAlign.center,
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
        SizedBox(height: 4),
        Text('Demo profile · Not connected to an account',
          textAlign: TextAlign.center, style: TextStyle(color: Color(0xFF7B8795))),
        SizedBox(height: 28),
        _SettingRow(Icons.person_outline, 'Personal information'),
        _SettingRow(Icons.lock_outline, 'Security & access'),
        _SettingRow(Icons.notifications_none, 'Notifications'),
        _SettingRow(Icons.help_outline, 'Help & support'),
        _SettingRow(Icons.info_outline, 'About Pusa'),
      ],
    ),
  );
}

class _SettingRow extends StatelessWidget {
  const _SettingRow(this.icon, this.label);
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) => Card(
    margin: const EdgeInsets.only(bottom: 9),
    child: ListTile(
      leading: Icon(icon, color: const Color(0xFF35465B)),
      title: Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
      trailing: const Icon(Icons.chevron_right_rounded),
      onTap: () {},
    ),
  );
}
