import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AllocationPlansScreen extends StatefulWidget {
  const AllocationPlansScreen({super.key, this.backendConfigured = true});
  final bool backendConfigured;

  @override
  State<AllocationPlansScreen> createState() => _AllocationPlansScreenState();
}

class _AllocationPlansScreenState extends State<AllocationPlansScreen> {
  static const _ink = Color(0xFF101B2D);
  static const _muted = Color(0xFF7B8795);
  static const _green = Color(0xFFB8F36B);

  bool _loading = true;
  bool _saving = false;
  String? _error;
  List<Map<String, dynamic>> _plans = [];
  List<Map<String, dynamic>> _pockets = [];
  final Map<String, List<Map<String, dynamic>>> _rules = {};

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
        client.from('allocation_plans')
          .select('id,name,status,currency,created_at,updated_at')
          .eq('user_id', user.id)
          .order('updated_at', ascending: false),
        client.from('pocket_balances')
          .select('pocket_id,name,icon_key,color_key,status,balance_xaf')
          .eq('user_id', user.id)
          .eq('status', 'active')
          .order('created_at'),
      ]);
      final plans = (results[0] as List).cast<Map<String, dynamic>>();
      final pockets = (results[1] as List).cast<Map<String, dynamic>>();
      final rules = <String, List<Map<String, dynamic>>>{};
      if (plans.isNotEmpty) {
        final planIds = plans.map((plan) => plan['id'] as String).toList();
        final ruleRows = await client.from('allocation_rules')
          .select('id,plan_id,pocket_id,percentage,priority')
          .inFilter('plan_id', planIds)
          .order('priority');
        for (final row in (ruleRows as List).cast<Map<String, dynamic>>()) {
          final planId = row['plan_id'] as String;
          rules.putIfAbsent(planId, () => []).add(row);
        }
      }
      if (!mounted) return;
      setState(() {
        _plans = plans;
        _pockets = pockets;
        _rules
          ..clear()
          ..addAll(rules);
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() {
        _loading = false;
        _error = 'Unable to load allocation plans. Pull down to retry.';
      });
    }
  }

  int? _basisPoints(String value) {
    final input = value.trim();
    if (!RegExp(r'^\d{1,3}(\.\d{1,2})?$').hasMatch(input)) return null;
    final parts = input.split('.');
    final whole = int.tryParse(parts[0]);
    if (whole == null) return null;
    final fraction = parts.length == 1 ? 0 : int.parse(parts[1].padRight(2, '0'));
    final result = whole * 100 + fraction;
    return result > 0 && result <= 10000 ? result : null;
  }

  String _percent(int basisPoints) =>
      '${basisPoints ~/ 100}.${(basisPoints % 100).toString().padLeft(2, '0')}%';

  String _money(int amount) =>
      '${amount.toString().replaceAllMapped(RegExp(r'\\B(?=(\\d{3})+(?!\\d))'), (m) => ',')} XAF';

  int _totalBasisPoints(List<Map<String, dynamic>> rules) {
    var total = 0;
    for (final rule in rules) {
      final value = rule['percentage'];
      final parsed = value is num ? (value * 100).round() : _basisPoints(value.toString());
      total += parsed ?? 0;
    }
    return total;
  }

  List<Map<String, dynamic>> _previewRows(
    List<Map<String, dynamic>> selected,
    Map<String, TextEditingController> controllers,
    int amount,
  ) {
    final rows = <Map<String, dynamic>>[];
    for (var i = 0; i < selected.length; i++) {
      final pocket = selected[i];
      final bp = _basisPoints(controllers[pocket['pocket_id']]?.text ?? '');
      if (bp == null) continue;
      final numerator = amount * bp;
      rows.add({
        'name': pocket['name'],
        'amount': numerator ~/ 10000,
        'remainder': numerator % 10000,
        'priority': i,
      });
    }
    final allocated = rows.fold<int>(0, (sum, row) => sum + (row['amount'] as int));
    var remaining = amount - allocated;
    final ranked = [...rows]..sort((a, b) {
      final byRemainder = (b['remainder'] as int).compareTo(a['remainder'] as int);
      return byRemainder != 0 ? byRemainder : (a['priority'] as int).compareTo(b['priority'] as int);
    });
    for (final row in ranked) {
      if (remaining <= 0) break;
      row['amount'] = (row['amount'] as int) + 1;
      remaining--;
    }
    return rows;
  }

  Future<void> _editPlan({Map<String, dynamic>? plan}) async {
    if (_pockets.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Create at least one active pocket before building an allocation plan.')),
      );
      return;
    }
    final name = TextEditingController(text: plan?['name'] as String? ?? 'My allocation plan');
    final previewAmount = TextEditingController(text: '100000');
    final controllers = <String, TextEditingController>{};
    final existing = plan == null ? <Map<String, dynamic>>[] : (_rules[plan['id']] ?? []);
    final selectedIds = <String>{};
    for (final pocket in _pockets) {
      final id = pocket['pocket_id'] as String;
      final rule = existing.where((item) => item['pocket_id'] == id).firstOrNull;
      if (rule != null) {
        selectedIds.add(id);
        controllers[id] = TextEditingController(text: (rule['percentage'] as num).toStringAsFixed(2));
      } else {
        controllers[id] = TextEditingController(text: '0');
      }
    }
    String? formError;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFFF6F8F4),
      builder: (sheetContext) => StatefulBuilder(builder: (context, setSheetState) {
        final selected = _pockets.where((p) => selectedIds.contains(p['pocket_id'])).toList();
        final total = selected.fold<int>(0, (sum, pocket) =>
          sum + (_basisPoints(controllers[pocket['pocket_id']]!.text) ?? 0));
        final amount = int.tryParse(previewAmount.text.trim()) ?? 0;
        final preview = _previewRows(selected, controllers, amount);
        return Padding(
          padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(context).viewInsets.bottom + 22),
          child: SizedBox(
            height: MediaQuery.of(context).size.height * .82,
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Text(plan == null ? 'Create allocation plan' : 'Edit allocation plan',
                style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w800, color: _ink)),
              const SizedBox(height: 5),
              const Text('Decide how a future verified deposit should be assigned to your pockets.',
                style: TextStyle(color: _muted, fontSize: 12)),
              const SizedBox(height: 14),
              TextField(controller: name, maxLength: 80,
                decoration: const InputDecoration(labelText: 'Plan name', border: OutlineInputBorder(), filled: true, fillColor: Colors.white)),
              const SizedBox(height: 8),
              Row(children: [
                const Expanded(child: Text('Choose pockets and set percentages', style: TextStyle(fontWeight: FontWeight.w800, color: _ink))),
                Text(_percent(total), style: TextStyle(fontWeight: FontWeight.w900, color: total == 10000 ? Colors.green.shade700 : _ink)),
              ]),
              const SizedBox(height: 5),
              Expanded(child: ListView(
                children: _pockets.map((pocket) {
                  final id = pocket['pocket_id'] as String;
                  final selectedPocket = selectedIds.contains(id);
                  return Card(
                    margin: const EdgeInsets.only(bottom: 7),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      child: Row(children: [
                        Checkbox(
                          value: selectedPocket,
                          onChanged: (checked) => setSheetState(() {
                            if (checked == true) {
                              selectedIds.add(id);
                              if (controllers[id]!.text == '0') controllers[id]!.text = '10';
                            } else {
                              selectedIds.remove(id);
                            }
                          }),
                        ),
                        Expanded(child: Text(pocket['name'] as String, style: const TextStyle(fontWeight: FontWeight.w700))),
                        SizedBox(width: 88, child: TextField(
                          controller: controllers[id],
                          enabled: selectedPocket,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
                          textAlign: TextAlign.end,
                          onChanged: (_) => setSheetState(() {}),
                          decoration: const InputDecoration(suffixText: '%', isDense: true, border: OutlineInputBorder(), contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 10)),
                        )),
                      ]),
                    ),
                  );
                }).toList(),
              )),
              const SizedBox(height: 7),
              Row(children: [
                const Expanded(child: Text('Preview deposit (XAF)', style: TextStyle(fontWeight: FontWeight.w700))),
                SizedBox(width: 132, child: TextField(
                  controller: previewAmount,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  textAlign: TextAlign.end,
                  onChanged: (_) => setSheetState(() {}),
                  decoration: const InputDecoration(isDense: true, border: OutlineInputBorder(), contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 10)),
                )),
              ]),
              const SizedBox(height: 6),
              if (preview.isNotEmpty)
                ...preview.map((row) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Row(children: [
                    Expanded(child: Text(row['name'] as String, style: const TextStyle(fontSize: 12))),
                    Text(_money(row['amount'] as int), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
                  ]),
                )),
              if (formError != null) Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(formError!, style: const TextStyle(color: Colors.red, fontSize: 12)),
              ),
              const SizedBox(height: 8),
              Text(
                total == 10000
                  ? 'The plan totals 100%. It can be activated after saving.'
                  : 'Drafts can be saved now, but activation requires exactly 100.00%.',
                style: TextStyle(color: total == 10000 ? Colors.green.shade700 : _muted, fontSize: 11),
              ),
              const SizedBox(height: 10),
              FilledButton(
                onPressed: _saving ? null : () async {
                  if (name.text.trim().isEmpty) {
                    setSheetState(() => formError = 'Enter a name for this plan.');
                    return;
                  }
                  final rules = <Map<String, dynamic>>[];
                  var valid = true;
                  for (var i = 0; i < selected.length; i++) {
                    final pocket = selected[i];
                    final id = pocket['pocket_id'] as String;
                    final bp = _basisPoints(controllers[id]!.text);
                    if (bp == null) { valid = false; break; }
                    rules.add({
                      'pocket_id': id,
                      'percentage': (bp / 100).toStringAsFixed(2),
                      'priority': i + 1,
                    });
                  }
                  if (!valid) {
                    setSheetState(() => formError = 'Each selected pocket needs a percentage greater than 0 and no more than 100, with up to 2 decimal places.');
                    return;
                  }
                  setState(() => _saving = true);
                  try {
                    await Supabase.instance.client.rpc('save_allocation_plan_draft', params: {
                      'p_plan_id': plan?['id'],
                      'p_name': name.text.trim(),
                      'p_rules': rules,
                    });
                    if (!mounted) return;
                    Navigator.of(sheetContext).pop();
                    await _load();
                    if (mounted) ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Allocation plan saved as a draft.')),
                    );
                  } catch (_) {
                    setSheetState(() => formError = 'Could not save this plan. Check your selections and try again.');
                  } finally {
                    if (mounted) setState(() => _saving = false);
                  }
                },
                child: _saving ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('Save draft'),
              ),
            ]),
          ),
        );
      }),
    );
    name.dispose();
    previewAmount.dispose();
    for (final controller in controllers.values) {
      controller.dispose();
    }
  }

  Future<void> _activate(Map<String, dynamic> plan) async {
    final rules = _rules[plan['id']] ?? [];
    if (_totalBasisPoints(rules) != 10000 || rules.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('This plan must total exactly 100.00% before activation.')),
      );
      return;
    }
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Activate this plan?'),
        content: const Text('This becomes your active allocation plan for future verified deposits. It does not move money or change previous transactions. Any previously active plan will be archived.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Not now')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Activate plan')),
        ],
      ),
    );
    if (confirm != true) return;
    setState(() { _saving = true; _error = null; });
    try {
      await Supabase.instance.client.rpc('activate_allocation_plan', params: {'p_plan_id': plan['id']});
      await _load();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Allocation plan activated.')),
      );
    } catch (_) {
      if (mounted) setState(() => _error = 'The plan could not be activated. Confirm all selected pockets are still active and the total is 100%.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Widget _planCard(Map<String, dynamic> plan) {
    final id = plan['id'] as String;
    final rules = _rules[id] ?? [];
    final total = _totalBasisPoints(rules);
    final status = plan['status'] as String? ?? 'draft';
    final active = status == 'active';
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(15),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [
            Expanded(child: Text(plan['name'] as String? ?? 'Allocation plan',
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: _ink))),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
              decoration: BoxDecoration(
                color: active ? const Color(0xFFE7F4DA) : const Color(0xFFECEFF2),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(status.toUpperCase(), style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w900)),
            ),
          ]),
          const SizedBox(height: 8),
          if (rules.isEmpty)
            const Text('No pocket rules yet.', style: TextStyle(color: _muted, fontSize: 12))
          else
            ...rules.map((rule) {
              final pocket = _pockets.where((p) => p['pocket_id'] == rule['pocket_id']).firstOrNull;
              final label = pocket?['name'] as String? ?? 'Pocket';
              final percentage = (rule['percentage'] as num).toStringAsFixed(2);
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Row(children: [
                  Expanded(child: Text(label, style: const TextStyle(fontSize: 12))),
                  Text('$percentage%', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12)),
                ]),
              );
            }),
          const Divider(height: 18),
          Row(children: [
            Expanded(child: Text('Total allocation', style: TextStyle(color: _muted, fontSize: 11))),
            Text(_percent(total), style: const TextStyle(fontWeight: FontWeight.w900, color: _ink)),
          ]),
          if (status == 'draft') ...[
            const SizedBox(height: 10),
            Row(children: [
              Expanded(child: OutlinedButton.icon(
                onPressed: _saving ? null : () => _editPlan(plan: plan),
                icon: const Icon(Icons.edit_outlined, size: 17),
                label: const Text('Edit draft'),
              )),
              const SizedBox(width: 9),
              Expanded(child: FilledButton(
                onPressed: _saving || total != 10000 || rules.isEmpty ? null : () => _activate(plan),
                child: const Text('Activate'),
              )),
            ]),
            if (total != 10000) const Padding(
              padding: EdgeInsets.only(top: 5),
              child: Text('Activation requires exactly 100.00%.', style: TextStyle(color: _muted, fontSize: 10)),
            ),
          ] else if (active)
            const Padding(
              padding: EdgeInsets.only(top: 7),
              child: Text('Used for future verified deposits. No funds move when a plan is activated.',
                style: TextStyle(color: _muted, fontSize: 11, height: 1.4)),
            ),
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.backendConfigured) {
      return Scaffold(
        appBar: AppBar(title: const Text('Allocation plans')),
        body: const Center(child: Padding(
          padding: EdgeInsets.all(28),
          child: Text('Connect your Pusa account to create and manage allocation plans. Plans determine how future verified deposits are assigned to your financial pockets.',
            textAlign: TextAlign.center, style: TextStyle(color: _muted, height: 1.5)),
        )),
      );
    }
    return Scaffold(
      appBar: AppBar(
        title: const Text('Allocation plans', style: TextStyle(fontWeight: FontWeight.w800)),
        actions: [IconButton(onPressed: _load, tooltip: 'Refresh', icon: const Icon(Icons.refresh))],
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 100),
          children: [
            const Text('Put every incoming amount to purpose.',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: _ink)),
            const SizedBox(height: 7),
            const Text('Create percentage rules for your pockets. Your active plan will apply to future verified deposits when deposit processing is enabled.',
              style: TextStyle(color: _muted, height: 1.45, fontSize: 12)),
            const SizedBox(height: 16),
            if (_error != null) Text(_error!, style: const TextStyle(color: Colors.red, fontSize: 12)),
            if (_loading && _plans.isEmpty)
              const Padding(padding: EdgeInsets.all(30), child: Center(child: CircularProgressIndicator()))
            else if (_plans.isEmpty)
              Container(
                padding: const EdgeInsets.all(22),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: const Color(0xFFE9EDE6))),
                child: const Column(children: [
                  Icon(Icons.pie_chart_outline_rounded, size: 36, color: _muted),
                  SizedBox(height: 10),
                  Text('No allocation plans yet', style: TextStyle(fontWeight: FontWeight.w800, color: _ink)),
                  SizedBox(height: 5),
                  Text('Build your first plan by choosing pockets and assigning a percentage to each one.',
                    textAlign: TextAlign.center, style: TextStyle(color: _muted, fontSize: 12, height: 1.4)),
                ]),
              )
            else
              ..._plans.map(_planCard),
            const SizedBox(height: 12),
            const Text('Activating a plan only configures allocation rules. It does not deposit, transfer, withdraw or hold money.',
              style: TextStyle(color: _muted, fontSize: 11, height: 1.4)),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _saving ? null : () => _editPlan(),
        backgroundColor: _ink,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('New plan'),
      ),
    );
  }
}
