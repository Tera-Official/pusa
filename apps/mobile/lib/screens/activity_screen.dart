import 'package:flutter/material.dart';

class ActivityScreen extends StatelessWidget {
  const ActivityScreen({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Activity', style: TextStyle(fontWeight: FontWeight.w800))),
    body: ListView(
      padding: const EdgeInsets.all(20),
      children: const [
        Text('Your money timeline', style: TextStyle(
          fontSize: 22, fontWeight: FontWeight.w800, color: Color(0xFF101B2D))),
        SizedBox(height: 8),
        Text('Deposits and allocations will appear here once connected.',
          style: TextStyle(color: Color(0xFF7B8795))),
        SizedBox(height: 24),
        _ActivityRow(Icons.south_west_rounded, 'Sample deposit', 'Today · Demo transaction', '+25,000 XAF', true),
        _ActivityRow(Icons.call_split_rounded, 'Pocket allocation', 'Today · Demo allocation', '25,000 XAF', false),
        _ActivityRow(Icons.south_west_rounded, 'Sample deposit', 'Yesterday · Demo transaction', '+50,000 XAF', true),
      ],
    ),
  );
}

class _ActivityRow extends StatelessWidget {
  const _ActivityRow(this.icon, this.title, this.subtitle, this.amount, this.income);
  final IconData icon;
  final String title, subtitle, amount;
  final bool income;

  @override
  Widget build(BuildContext context) => Card(
    margin: const EdgeInsets.only(bottom: 10),
    child: ListTile(
      leading: CircleAvatar(
        backgroundColor: const Color(0xFFEAF3E0),
        child: Icon(icon, color: const Color(0xFF26374B)),
      ),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
      subtitle: Text(subtitle),
      trailing: Text(amount, style: TextStyle(
        color: income ? const Color(0xFF397B36) : const Color(0xFF26374B),
        fontWeight: FontWeight.w800, fontSize: 12)),
    ),
  );
}
