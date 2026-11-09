import 'package:flutter/material.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key, required this.backendConfigured});

  final bool backendConfigured;

  static const _ink = Color(0xFF101B2D);
  static const _muted = Color(0xFF7B8795);
  static const _green = Color(0xFFB8F36B);

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
      children: [
        Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: _ink,
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(Icons.savings_rounded, color: _green),
            ),
            const SizedBox(width: 11),
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('PUSA', style: TextStyle(
                  color: _ink, fontWeight: FontWeight.w900,
                  letterSpacing: 2.2, fontSize: 15,
                )),
                Text('Smart Saving', style: TextStyle(color: _muted, fontSize: 11)),
              ],
            ),
            const Spacer(),
            IconButton(
              onPressed: () {},
              icon: const Icon(Icons.notifications_none_rounded, color: _ink),
              style: IconButton.styleFrom(
                backgroundColor: Colors.white,
                side: const BorderSide(color: Color(0xFFE9EDE6)),
              ),
            ),
            const SizedBox(width: 5),
            CircleAvatar(
              radius: 20,
              backgroundColor: const Color(0xFFE7EEDC),
              child: const Text('TT', style: TextStyle(
                color: _ink, fontWeight: FontWeight.bold,
              )),
            ),
          ],
        ),
        const SizedBox(height: 28),
        const Text('Good evening,', style: TextStyle(color: _muted, fontSize: 14)),
        const Text('Let’s put your money to work.',
          style: TextStyle(color: _ink, fontSize: 21, fontWeight: FontWeight.w800)),
        const SizedBox(height: 20),
        Container(
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            color: _ink,
            borderRadius: BorderRadius.circular(26),
            gradient: const LinearGradient(
              colors: [Color(0xFF172942), Color(0xFF0D1727)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                const Text('TOTAL SAVINGS OVERVIEW',
                  style: TextStyle(color: Color(0xFFB9C4D0), fontSize: 10,
                    fontWeight: FontWeight.w700, letterSpacing: 1.3)),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: .10),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text('DEMO', style: TextStyle(
                    color: _green, fontSize: 9, fontWeight: FontWeight.w800,
                    letterSpacing: 1,
                  )),
                ),
              ]),
              const SizedBox(height: 16),
              const Text('125,000 XAF',
                style: TextStyle(color: Colors.white, fontSize: 32,
                  fontWeight: FontWeight.w800, letterSpacing: -.8)),
              const SizedBox(height: 6),
              const Text('Across your active pockets',
                style: TextStyle(color: Color(0xFFB9C4D0), fontSize: 12)),
              const SizedBox(height: 23),
              Row(children: [
                Expanded(child: _SummaryMetric(
                  label: 'THIS MONTH', value: '+35,000 XAF',
                  icon: Icons.trending_up_rounded,
                )),
                Container(width: 1, height: 38, color: Colors.white24),
                const SizedBox(width: 16),
                const Expanded(child: _SummaryMetric(
                  label: 'ACTIVE POCKETS', value: '4 pockets',
                  icon: Icons.wallet_outlined,
                )),
              ]),
            ],
          ),
        ),
        const SizedBox(height: 18),
        if (!backendConfigured)
          Container(
            padding: const EdgeInsets.all(13),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF5D9),
              borderRadius: BorderRadius.circular(15),
              border: Border.all(color: const Color(0xFFF2E2B2)),
            ),
            child: const Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.info_outline_rounded, color: Color(0xFF946B16), size: 19),
                SizedBox(width: 9),
                Expanded(child: Text(
                  'Preview mode is active. Sample figures are shown until the secure Pusa backend is connected.',
                  style: TextStyle(color: Color(0xFF765719), fontSize: 11, height: 1.4),
                )),
              ],
            ),
          ),
        const SizedBox(height: 23),
        Row(children: [
          const Expanded(child: Text('Your pockets', style: TextStyle(
            color: _ink, fontWeight: FontWeight.w800, fontSize: 17,
          ))),
          TextButton(onPressed: () {}, child: const Text('See all')),
        ]),
        const SizedBox(height: 5),
        const _PocketTile(
          name: 'Emergency fund', amount: '50,000 XAF',
          percent: 40, color: Color(0xFFB8F36B), icon: Icons.shield_outlined,
        ),
        const _PocketTile(
          name: 'Rent & housing', amount: '35,000 XAF',
          percent: 28, color: Color(0xFF9CC9FF), icon: Icons.home_outlined,
        ),
        const _PocketTile(
          name: 'Daily living', amount: '25,000 XAF',
          percent: 20, color: Color(0xFFFFD18B), icon: Icons.restaurant_outlined,
        ),
        const _PocketTile(
          name: 'Future plans', amount: '15,000 XAF',
          percent: 12, color: Color(0xFFD8B8FF), icon: Icons.flag_outlined,
        ),
        const SizedBox(height: 20),
        const Text('Quick actions', style: TextStyle(
          color: _ink, fontWeight: FontWeight.w800, fontSize: 17,
        )),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(child: _QuickAction(
            icon: Icons.add_rounded, label: 'Add money',
            onTap: () => _showInfo(context, 'Deposits will be enabled after payment integration.'),
          )),
          const SizedBox(width: 10),
          Expanded(child: _QuickAction(
            icon: Icons.tune_rounded, label: 'Allocation',
            onTap: () => _showInfo(context, 'Allocation setup is coming in the next mobile build.'),
          )),
        ]),
      ],
    );
  }

  static void _showInfo(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }
}

class _SummaryMetric extends StatelessWidget {
  const _SummaryMetric({required this.label, required this.value, required this.icon});
  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(children: [
        Icon(icon, size: 13, color: const Color(0xFFB8F36B)),
        const SizedBox(width: 5),
        Text(label, style: const TextStyle(color: Color(0xFFB9C4D0),
          fontSize: 9, fontWeight: FontWeight.w700, letterSpacing: .6)),
      ]),
      const SizedBox(height: 7),
      Text(value, style: const TextStyle(color: Colors.white,
        fontSize: 14, fontWeight: FontWeight.w700)),
    ],
  );
}

class _PocketTile extends StatelessWidget {
  const _PocketTile({
    required this.name, required this.amount, required this.percent,
    required this.color, required this.icon,
  });
  final String name;
  final String amount;
  final int percent;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE9EDE6)),
      ),
      child: Row(children: [
        Container(
          width: 42, height: 42,
          decoration: BoxDecoration(color: color.withValues(alpha: .25),
            borderRadius: BorderRadius.circular(13)),
          child: Icon(icon, color: const Color(0xFF243247), size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(name, style: const TextStyle(fontWeight: FontWeight.w700,
            color: Color(0xFF182437), fontSize: 13)),
          const SizedBox(height: 5),
          Text('$percent% allocation', style: const TextStyle(
            color: Color(0xFF8993A0), fontSize: 10)),
        ])),
        Text(amount, style: const TextStyle(color: Color(0xFF182437),
          fontWeight: FontWeight.w800, fontSize: 12)),
      ]),
    ),
  );
}

class _QuickAction extends StatelessWidget {
  const _QuickAction({required this.icon, required this.label, required this.onTap});
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(16),
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 17, horizontal: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE9EDE6)),
      ),
      child: Row(children: [
        Icon(icon, color: const Color(0xFF26374B), size: 19),
        const SizedBox(width: 8),
        Text(label, style: const TextStyle(fontSize: 12,
          color: Color(0xFF26374B), fontWeight: FontWeight.w700)),
      ]),
    ),
  );
}
