import 'package:flutter/material.dart';

class PocketsScreen extends StatelessWidget {
  const PocketsScreen({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('My pockets', style: TextStyle(fontWeight: FontWeight.w800))),
    body: ListView(
      padding: const EdgeInsets.all(20),
      children: const [
        Text('Give every franc a purpose.',
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: Color(0xFF101B2D))),
        SizedBox(height: 8),
        Text('Your pockets organise money around the things that matter.',
          style: TextStyle(color: Color(0xFF7B8795), height: 1.5)),
        SizedBox(height: 22),
        _PocketRow('Emergency fund', '50,000 XAF', '40%', Icons.shield_outlined),
        _PocketRow('Rent & housing', '35,000 XAF', '28%', Icons.home_outlined),
        _PocketRow('Daily living', '25,000 XAF', '20%', Icons.restaurant_outlined),
        _PocketRow('Future plans', '15,000 XAF', '12%', Icons.flag_outlined),
      ],
    ),
    floatingActionButton: FloatingActionButton.extended(
      onPressed: null,
      icon: Icon(Icons.add),
      label: Text('New pocket'),
    ),
  );
}

class _PocketRow extends StatelessWidget {
  const _PocketRow(this.name, this.amount, this.percent, this.icon);
  final String name, amount, percent;
  final IconData icon;

  @override
  Widget build(BuildContext context) => Card(
    margin: const EdgeInsets.only(bottom: 11),
    child: ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 15, vertical: 8),
      leading: CircleAvatar(backgroundColor: const Color(0xFFEAF3E0),
        child: Icon(icon, color: const Color(0xFF26374B))),
      title: Text(name, style: const TextStyle(fontWeight: FontWeight.w700)),
      subtitle: Text('$percent of your allocation'),
      trailing: Text(amount, style: const TextStyle(fontWeight: FontWeight.w800)),
    ),
  );
}
