import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ActivityScreen extends StatefulWidget {
  const ActivityScreen({super.key});

  @override
  State<ActivityScreen> createState() => _ActivityScreenState();
}

class _ActivityScreenState extends State<ActivityScreen> {
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _transactions = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      if (mounted) setState(() { _loading = false; _error = 'Please sign in again.'; });
      return;
    }
    setState(() { _loading = true; _error = null; });
    try {
      final rows = await Supabase.instance.client.from('ledger_transactions')
        .select('id,transaction_type,status,amount_xaf,currency,description,created_at')
        .eq('user_id', user.id)
        .order('created_at', ascending: false)
        .limit(50);
      if (!mounted) return;
      setState(() {
        _transactions = rows.cast<Map<String, dynamic>>();
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() { _loading = false; _error = 'Unable to load your activity. Pull down to retry.'; });
    }
  }

  String _money(dynamic value) {
    final amount = (value as num?)?.toInt() ?? 0;
    return '${amount.abs().toString().replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (m) => ',')} XAF';
  }

  String _title(String type) => switch (type) {
    'deposit' => 'Deposit recorded',
    'withdrawal' => 'Withdrawal recorded',
    'allocation' => 'Pocket allocation',
    'transfer' => 'Internal transfer',
    'reversal' => 'Transaction reversal',
    'adjustment' => 'Account adjustment',
    _ => 'Financial activity',
  };

  IconData _icon(String type) => switch (type) {
    'deposit' => Icons.south_west_rounded,
    'withdrawal' => Icons.north_east_rounded,
    'allocation' => Icons.call_split_rounded,
    'transfer' => Icons.swap_horiz_rounded,
    'reversal' => Icons.undo_rounded,
    _ => Icons.receipt_long_outlined,
  };

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Financial activity', style: TextStyle(fontWeight: FontWeight.w800))),
    body: RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(20),
        children: [
          const Text('Your financial timeline', style: TextStyle(
            fontSize: 22, fontWeight: FontWeight.w800, color: Color(0xFF101B2D))),
          const SizedBox(height: 8),
          const Text('A record of transactions posted to your Pusa ledger.',
            style: TextStyle(color: Color(0xFF7B8795))),
          const SizedBox(height: 18),
          if (_error != null) Text(_error!, style: const TextStyle(color: Colors.red)),
          if (_loading && _transactions.isEmpty)
            const Padding(padding: EdgeInsets.all(30), child: Center(child: CircularProgressIndicator()))
          else if (_transactions.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 42, horizontal: 12),
              child: Column(children: [
                Icon(Icons.receipt_long_outlined, size: 38, color: Color(0xFF7B8795)),
                SizedBox(height: 12),
                Text('No recorded activity yet', style: TextStyle(fontWeight: FontWeight.w800, color: Color(0xFF101B2D))),
                SizedBox(height: 5),
                Text('Verified financial transactions will appear here when they are posted.',
                  textAlign: TextAlign.center, style: TextStyle(color: Color(0xFF7B8795), fontSize: 12, height: 1.4)),
              ]),
            )
          else ..._transactions.map(_transactionCard),
          const SizedBox(height: 14),
          const Text('Only posted ledger transactions are shown. Creating a pocket or an allocation plan does not itself move money.',
            style: TextStyle(color: Color(0xFF7B8795), fontSize: 11, height: 1.4)),
        ],
      ),
    ),
  );

  Widget _transactionCard(Map<String, dynamic> row) {
    final type = row['transaction_type'] as String? ?? '';
    final amount = (row['amount_xaf'] as num?)?.toInt() ?? 0;
    final isInflow = type == 'deposit';
    final date = DateTime.tryParse(row['created_at'] as String? ?? '')?.toLocal();
    final dateText = date == null ? '' : '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year} · ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    return Card(
      margin: const EdgeInsets.only(bottom: 9),
      child: ListTile(
        leading: CircleAvatar(backgroundColor: const Color(0xFFEAF3E0),
          child: Icon(_icon(type), color: const Color(0xFF26374B))),
        title: Text(_title(type), style: const TextStyle(fontWeight: FontWeight.w700)),
        subtitle: Text((row['description'] as String?)?.isNotEmpty == true
          ? '${row['description']} · $dateText' : dateText),
        trailing: Text('${isInflow ? '+' : type == 'withdrawal' ? '−' : ''}${_money(amount)}',
          style: TextStyle(color: isInflow ? const Color(0xFF397B36) : const Color(0xFF26374B),
            fontWeight: FontWeight.w800, fontSize: 11)),
      ),
    );
  }
}
