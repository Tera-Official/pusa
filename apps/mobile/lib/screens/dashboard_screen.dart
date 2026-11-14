import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key, required this.backendConfigured});
  final bool backendConfigured;

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  static const _ink = Color(0xFF101B2D);
  static const _muted = Color(0xFF7B8795);
  static const _green = Color(0xFFB8F36B);

  bool _loading = true;
  String? _error;
  String _displayName = 'there';
  List<Map<String, dynamic>> _pockets = [];
  int _totalBalance = 0;
  int _monthIncome = 0;
  int _monthOutflow = 0;

  @override
  void initState() {
    super.initState();
    if (widget.backendConfigured) {
      _load();
    } else {
      _loading = false;
    }
  }

  Future<void> _load() async {
    final client = Supabase.instance.client;
    final user = client.auth.currentUser;
    if (user == null) {
      if (mounted) setState(() { _loading = false; _error = 'Please sign in again.'; });
      return;
    }
    setState(() { _loading = true; _error = null; });
    try {
      final results = await Future.wait([
        client.from('profiles').select('display_name').eq('id', user.id).maybeSingle(),
        client.from('pocket_balances').select(
          'pocket_id,name,description,color_key,icon_key,status,is_locked,balance_xaf,created_at',
        ).eq('user_id', user.id).order('created_at'),
        client.from('ledger_transactions').select(
          'transaction_type,amount_xaf,created_at',
        ).eq('user_id', user.id).eq('status', 'posted')
          .gte('created_at', DateTime(DateTime.now().year, DateTime.now().month).toIso8601String())
          .inFilter('transaction_type', ['deposit', 'withdrawal']),
      ]);
      final profile = results[0] as Map<String, dynamic>?;
      final allPocketRows = (results[1] as List).cast<Map<String, dynamic>>();
      final activePocketRows = allPocketRows.where((pocket) => pocket['status'] == 'active').toList();
      final transactionRows = (results[2] as List).cast<Map<String, dynamic>>();
      var balance = 0;
      for (final pocket in allPocketRows) {
        balance += (pocket['balance_xaf'] as num?)?.toInt() ?? 0;
      }
      var income = 0;
      var outflow = 0;
      for (final transaction in transactionRows) {
        final amount = (transaction['amount_xaf'] as num?)?.toInt() ?? 0;
        if (transaction['transaction_type'] == 'deposit') income += amount;
        if (transaction['transaction_type'] == 'withdrawal') outflow += amount;
      }
      if (!mounted) return;
      setState(() {
        _displayName = (profile?['display_name'] as String?)?.trim().split(' ').first ?? 'there';
        if (_displayName.isEmpty) _displayName = 'there';
        _pockets = activePocketRows;
        _totalBalance = balance;
        _monthIncome = income;
        _monthOutflow = outflow;
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() {
        _loading = false;
        _error = 'We could not load your financial overview. Pull down to try again.';
      });
    }
  }

  String _money(int amount) => '${amount.abs().toString().replaceAllMapped(
    RegExp(r'\B(?=(\d{3})+(?!\d))'), (match) => ',',
  )} XAF';

  IconData _icon(String? key) => switch (key) {
    'home' => Icons.home_outlined,
    'food' => Icons.restaurant_outlined,
    'transport' => Icons.directions_bus_outlined,
    'education' => Icons.school_outlined,
    'health' => Icons.health_and_safety_outlined,
    'shield' => Icons.shield_outlined,
    'flag' => Icons.flag_outlined,
    'business' => Icons.storefront_outlined,
    _ => Icons.account_balance_wallet_outlined,
  };

  Color _color(String? key) => switch (key) {
    'blue' => const Color(0xFF9CC9FF),
    'orange' => const Color(0xFFFFD18B),
    'purple' => const Color(0xFFD8B8FF),
    'rose' => const Color(0xFFFFB8C5),
    _ => _green,
  };

  @override
  Widget build(BuildContext context) {
    if (!widget.backendConfigured) {
      return _preview();
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
        children: [
          _header(),
          const SizedBox(height: 28),
          Text('Good day, $_displayName', style: const TextStyle(color: _muted, fontSize: 14)),
          const Text('Here is your financial picture.', style: TextStyle(
            color: _ink, fontSize: 21, fontWeight: FontWeight.w800,
          )),
          const SizedBox(height: 20),
          _overviewCard(),
          if (_error != null) ...[
            const SizedBox(height: 14),
            _notice(_error!, isError: true),
          ],
          const SizedBox(height: 22),
          Row(children: [
            const Expanded(child: Text('Your pockets', style: TextStyle(
              color: _ink, fontWeight: FontWeight.w800, fontSize: 17,
            ))),
            Text('${_pockets.length} active', style: const TextStyle(color: _muted, fontSize: 12)),
          ]),
          const SizedBox(height: 10),
          if (_loading && _pockets.isEmpty)
            const Padding(padding: EdgeInsets.all(28), child: Center(child: CircularProgressIndicator()))
          else if (_pockets.isEmpty)
            _emptyPockets()
          else
            ..._pockets.take(4).map((pocket) => _PocketTile(
              name: pocket['name'] as String? ?? 'Pocket',
              amount: _money((pocket['balance_xaf'] as num?)?.toInt() ?? 0),
              color: _color(pocket['color_key'] as String?),
              icon: _icon(pocket['icon_key'] as String?),
              locked: pocket['is_locked'] as bool? ?? false,
            )),
          const SizedBox(height: 16),
          _notice('Pusa shows accounting allocations recorded in your account. This is not a bank balance or confirmation that funds are held by Pusa.'),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: _loading ? null : _load,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Refresh financial overview'),
          ),
        ],
      ),
    );
  }

  Widget _header() => Row(children: [
    Container(
      width: 42, height: 42,
      decoration: BoxDecoration(color: _ink, borderRadius: BorderRadius.circular(14)),
      child: const Icon(Icons.account_balance_wallet_rounded, color: _green),
    ),
    const SizedBox(width: 11),
    const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('PUSA', style: TextStyle(color: _ink, fontWeight: FontWeight.w900, letterSpacing: 2.2, fontSize: 15)),
      Text('Financial Management', style: TextStyle(color: _muted, fontSize: 11)),
    ]),
    const Spacer(),
    IconButton(
      onPressed: _load,
      icon: const Icon(Icons.refresh_rounded, color: _ink),
      tooltip: 'Refresh',
      style: IconButton.styleFrom(backgroundColor: Colors.white, side: const BorderSide(color: Color(0xFFE9EDE6))),
    ),
  ]);

  Widget _overviewCard() => Container(
    padding: const EdgeInsets.all(22),
    decoration: BoxDecoration(
      color: _ink, borderRadius: BorderRadius.circular(26),
      gradient: const LinearGradient(colors: [Color(0xFF172942), Color(0xFF0D1727)],
        begin: Alignment.topLeft, end: Alignment.bottomRight),
    ),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('TOTAL RECORDED ACROSS ALL POCKETS', style: TextStyle(
        color: Color(0xFFB9C4D0), fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 1.1,
      )),
      const SizedBox(height: 14),
      _loading ? const SizedBox(height: 38, child: LinearProgressIndicator())
        : Text(_money(_totalBalance), style: const TextStyle(
          color: Colors.white, fontSize: 30, fontWeight: FontWeight.w800, letterSpacing: -.7,
        )),
      const SizedBox(height: 22),
      Row(children: [
        Expanded(child: _Metric(label: 'INCOME THIS MONTH', value: _loading ? '—' : '+${_money(_monthIncome)}', icon: Icons.south_west_rounded)),
        Container(width: 1, height: 42, color: Colors.white24),
        const SizedBox(width: 16),
        Expanded(child: _Metric(label: 'OUTGOING THIS MONTH', value: _loading ? '—' : _money(_monthOutflow), icon: Icons.north_east_rounded)),
      ]),
    ]),
  );

  Widget _emptyPockets() => Container(
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18),
      border: Border.all(color: const Color(0xFFE9EDE6))),
    child: const Column(children: [
      Icon(Icons.account_balance_wallet_outlined, size: 32, color: _muted),
      SizedBox(height: 9),
      Text('Your financial workspace starts here', style: TextStyle(fontWeight: FontWeight.w800, color: _ink)),
      SizedBox(height: 5),
      Text('Create pockets to organize your priorities and track their recorded balances.',
        textAlign: TextAlign.center, style: TextStyle(color: _muted, height: 1.4, fontSize: 12)),
    ]),
  );

  Widget _notice(String message, {bool isError = false}) => Container(
    padding: const EdgeInsets.all(13),
    decoration: BoxDecoration(
      color: isError ? const Color(0xFFFFEEEE) : const Color(0xFFFFF5D9),
      borderRadius: BorderRadius.circular(15),
      border: Border.all(color: isError ? const Color(0xFFF3CACA) : const Color(0xFFF2E2B2)),
    ),
    child: Text(message, style: TextStyle(
      color: isError ? const Color(0xFF9B3030) : const Color(0xFF765719),
      fontSize: 11, height: 1.4,
    )),
  );

  Widget _preview() => ListView(padding: const EdgeInsets.all(20), children: [
    _header(),
    const SizedBox(height: 28),
    const Text('Your financial workspace', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: _ink)),
    const SizedBox(height: 8),
    const Text('Connect the Pusa account to see your personal financial overview.', style: TextStyle(color: _muted)),
    const SizedBox(height: 18),
    _notice('Preview mode. No real financial information is being displayed.'),
  ]);
}

class _Metric extends StatelessWidget {
  const _Metric({required this.label, required this.value, required this.icon});
  final String label, value;
  final IconData icon;

  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Row(children: [
      Icon(icon, size: 13, color: const Color(0xFFB8F36B)),
      const SizedBox(width: 5),
      Expanded(child: Text(label, style: const TextStyle(color: Color(0xFFB9C4D0),
        fontSize: 9, fontWeight: FontWeight.w700, letterSpacing: .4))),
    ]),
    const SizedBox(height: 7),
    Text(value, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700)),
  ]);
}

class _PocketTile extends StatelessWidget {
  const _PocketTile({required this.name, required this.amount, required this.color, required this.icon, required this.locked});
  final String name, amount;
  final Color color;
  final IconData icon;
  final bool locked;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE9EDE6))),
      child: Row(children: [
        Container(width: 42, height: 42,
          decoration: BoxDecoration(color: color.withValues(alpha: .25), borderRadius: BorderRadius.circular(13)),
          child: Icon(icon, color: const Color(0xFF243247), size: 20)),
        const SizedBox(width: 12),
        Expanded(child: Text(name, style: const TextStyle(fontWeight: FontWeight.w700, color: Color(0xFF182437), fontSize: 13))),
        if (locked) const Padding(padding: EdgeInsets.only(right: 6), child: Icon(Icons.lock_outline, size: 14, color: Color(0xFF8993A0))),
        Text(amount, style: const TextStyle(color: Color(0xFF182437), fontWeight: FontWeight.w800, fontSize: 12)),
      ]),
    ),
  );
}
