import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class PocketsScreen extends StatefulWidget {
  const PocketsScreen({super.key});

  @override
  State<PocketsScreen> createState() => _PocketsScreenState();
}

class _PocketsScreenState extends State<PocketsScreen> {
  static const _ink = Color(0xFF101B2D);
  static const _muted = Color(0xFF7B8795);

  bool _loading = true;
  bool _saving = false;
  String? _error;
  List<Map<String, dynamic>> _pockets = [];

  static const _icons = <String, IconData>{
    'savings': Icons.savings_outlined,
    'home': Icons.home_outlined,
    'food': Icons.restaurant_outlined,
    'transport': Icons.directions_bus_outlined,
    'education': Icons.school_outlined,
    'health': Icons.health_and_safety_outlined,
    'shield': Icons.shield_outlined,
    'flag': Icons.flag_outlined,
    'business': Icons.storefront_outlined,
  };
  static const _colors = <String, Color>{
    'lime': Color(0xFFB8F36B),
    'blue': Color(0xFF9CC9FF),
    'orange': Color(0xFFFFD18B),
    'purple': Color(0xFFD8B8FF),
    'rose': Color(0xFFFFB8C5),
  };

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
      final rows = await Supabase.instance.client.from('pocket_balances')
        .select('pocket_id,user_id,name,description,color_key,icon_key,status,is_locked,balance_xaf,created_at')
        .eq('user_id', user.id).order('created_at');
      if (!mounted) return;
      setState(() {
        _pockets = rows.cast<Map<String, dynamic>>();
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() { _loading = false; _error = 'Unable to load pockets. Pull down to retry.'; });
    }
  }

  String _money(dynamic value) {
    final amount = (value as num?)?.toInt() ?? 0;
    final digits = amount.abs().toString().replaceAllMapped(
      RegExp(r'\B(?=(\d{3})+(?!\d))'), (match) => ',',
    );
    return '$digits XAF';
  }

  Future<void> _showPocketForm({Map<String, dynamic>? pocket}) async {
    final name = TextEditingController(text: pocket?['name'] as String? ?? '');
    final description = TextEditingController(text: pocket?['description'] as String? ?? '');
    var iconKey = pocket?['icon_key'] as String? ?? 'savings';
    var colorKey = pocket?['color_key'] as String? ?? 'lime';
    String? formError;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFFF6F8F4),
      builder: (sheetContext) => StatefulBuilder(builder: (context, setSheetState) {
        return Padding(
          padding: EdgeInsets.fromLTRB(20, 22, 20, MediaQuery.of(context).viewInsets.bottom + 24),
          child: SingleChildScrollView(child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(pocket == null ? 'Create a pocket' : 'Edit pocket',
                style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w800, color: _ink)),
              const SizedBox(height: 6),
              const Text('Give this part of your finances a clear purpose.', style: TextStyle(color: _muted)),
              const SizedBox(height: 18),
              TextField(controller: name, maxLength: 60, textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(labelText: 'Pocket name', border: OutlineInputBorder(), filled: true, fillColor: Colors.white)),
              const SizedBox(height: 12),
              TextField(controller: description, maxLength: 180, maxLines: 2,
                decoration: const InputDecoration(labelText: 'Description (optional)', border: OutlineInputBorder(), filled: true, fillColor: Colors.white)),
              const SizedBox(height: 14),
              const Text('Choose an icon', style: TextStyle(fontWeight: FontWeight.w700, color: _ink)),
              const SizedBox(height: 8),
              Wrap(spacing: 8, runSpacing: 8, children: _icons.entries.map((entry) => ChoiceChip(
                label: Icon(entry.value, size: 19),
                selected: iconKey == entry.key,
                onSelected: (_) => setSheetState(() => iconKey = entry.key),
              )).toList()),
              const SizedBox(height: 14),
              const Text('Choose a colour', style: TextStyle(fontWeight: FontWeight.w700, color: _ink)),
              const SizedBox(height: 8),
              Wrap(spacing: 10, children: _colors.entries.map((entry) => GestureDetector(
                onTap: () => setSheetState(() => colorKey = entry.key),
                child: Container(width: 34, height: 34,
                  decoration: BoxDecoration(color: entry.value, shape: BoxShape.circle,
                    border: Border.all(color: colorKey == entry.key ? _ink : Colors.transparent, width: 2))),
              )).toList()),
              if (formError != null) ...[
                const SizedBox(height: 10),
                Text(formError!, style: const TextStyle(color: Colors.red, fontSize: 12)),
              ],
              const SizedBox(height: 20),
              FilledButton(
                onPressed: _saving ? null : () async {
                  final cleanName = name.text.trim();
                  if (cleanName.isEmpty) {
                    setSheetState(() => formError = 'Enter a name for this pocket.');
                    return;
                  }
                  setState(() => _saving = true);
                  try {
                    final client = Supabase.instance.client;
                    final user = client.auth.currentUser!;
                    final values = {
                      'name': cleanName,
                      'description': description.text.trim().isEmpty ? null : description.text.trim(),
                      'icon_key': iconKey,
                      'color_key': colorKey,
                    };
                    if (pocket == null) {
                      await client.from('pockets').insert({...values, 'user_id': user.id});
                    } else {
                      await client.from('pockets').update(values)
                        .eq('id', pocket['pocket_id']).eq('user_id', user.id);
                    }
                    if (!mounted) return;
                    Navigator.of(sheetContext).pop();
                    await _load();
                  } catch (_) {
                    setSheetState(() => formError = 'Could not save this pocket. Please try again.');
                  } finally {
                    if (mounted) setState(() => _saving = false);
                  }
                },
                child: _saving ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                  : Text(pocket == null ? 'Create pocket' : 'Save changes'),
              ),
            ],
          )),
        );
      }),
    );
    name.dispose();
    description.dispose();
  }

  Future<void> _toggleArchive(Map<String, dynamic> pocket) async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;
    final currentlyArchived = pocket['status'] == 'archived';
    try {
      await Supabase.instance.client.from('pockets').update({
        'status': currentlyArchived ? 'active' : 'archived',
      }).eq('id', pocket['pocket_id']).eq('user_id', user.id);
      await _load();
    } catch (_) {
      if (mounted) setState(() => _error = 'Could not update this pocket. Please try again.');
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Financial pockets', style: TextStyle(fontWeight: FontWeight.w800))),
    body: RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 100),
        children: [
          const Text('Organize your financial priorities.',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: _ink)),
          const SizedBox(height: 8),
          const Text('Create dedicated pockets for obligations, plans and reserves. Balances come from recorded ledger entries.',
            style: TextStyle(color: _muted, height: 1.5)),
          const SizedBox(height: 16),
          if (_error != null) Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: const Color(0xFFFFEEEE), borderRadius: BorderRadius.circular(12)),
            child: Text(_error!, style: const TextStyle(color: Color(0xFF9B3030), fontSize: 12)),
          ),
          if (_loading && _pockets.isEmpty)
            const Padding(padding: EdgeInsets.all(32), child: Center(child: CircularProgressIndicator()))
          else if (_pockets.isEmpty)
            _empty()
          else ..._pockets.map(_pocketCard),
          const SizedBox(height: 12),
          const Text('Pockets are accounting categories. Creating or editing a pocket does not move money.',
            style: TextStyle(color: _muted, fontSize: 11, height: 1.4)),
        ],
      ),
    ),
    floatingActionButton: FloatingActionButton.extended(
      onPressed: _saving ? null : () => _showPocketForm(),
      backgroundColor: _ink,
      foregroundColor: Colors.white,
      icon: const Icon(Icons.add),
      label: const Text('New pocket'),
    ),
  );

  Widget _empty() => Container(
    padding: const EdgeInsets.all(22),
    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18),
      border: Border.all(color: const Color(0xFFE9EDE6))),
    child: const Column(children: [
      Icon(Icons.wallet_outlined, size: 34, color: _muted),
      SizedBox(height: 10),
      Text('No pockets yet', style: TextStyle(fontWeight: FontWeight.w800, color: _ink)),
      SizedBox(height: 5),
      Text('Create your first pocket to start organizing your financial priorities.',
        textAlign: TextAlign.center, style: TextStyle(color: _muted, fontSize: 12, height: 1.4)),
    ]),
  );

  Widget _pocketCard(Map<String, dynamic> pocket) {
    final iconKey = pocket['icon_key'] as String? ?? 'savings';
    final colorKey = pocket['color_key'] as String? ?? 'lime';
    final archived = pocket['status'] == 'archived';
    final locked = pocket['is_locked'] as bool? ?? false;
    return Card(
      margin: const EdgeInsets.only(bottom: 11),
      color: archived ? const Color(0xFFF0F1EF) : Colors.white,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 7),
        child: ListTile(
          leading: CircleAvatar(backgroundColor: (_colors[colorKey] ?? _colors['lime']!).withValues(alpha: .45),
            child: Icon(_icons[iconKey] ?? _icons['savings'], color: _ink)),
          title: Text(pocket['name'] as String? ?? 'Pocket', style: const TextStyle(fontWeight: FontWeight.w800)),
          subtitle: Text([
            if (archived) 'Archived',
            if (locked) 'Locked',
            if ((pocket['description'] as String? ?? '').isNotEmpty) pocket['description'] as String,
          ].join(' · ').isEmpty ? 'Personal financial category' : [
            if (archived) 'Archived',
            if (locked) 'Locked',
            if ((pocket['description'] as String? ?? '').isNotEmpty) pocket['description'] as String,
          ].join(' · ')),
          trailing: Row(mainAxisSize: MainAxisSize.min, children: [
            Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text(_money(pocket['balance_xaf']), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12)),
              const SizedBox(height: 2),
              const Text('recorded balance', style: TextStyle(color: _muted, fontSize: 9)),
            ]),
            PopupMenuButton<String>(
              tooltip: 'Pocket actions',
              onSelected: (value) {
                if (value == 'edit') _showPocketForm(pocket: pocket);
                if (value == 'archive' || value == 'restore') _confirmArchive(pocket);
              },
              itemBuilder: (context) => [
                const PopupMenuItem(value: 'edit', child: Text('Edit pocket')),
                PopupMenuItem(value: archived ? 'restore' : 'archive', child: Text(archived ? 'Restore pocket' : 'Archive pocket')),
              ],
            ),
          ]),
          onTap: () => _showPocketForm(pocket: pocket),
        ),
      ),
    );
  }

  Future<void> _confirmArchive(Map<String, dynamic> pocket) async {
    final archived = pocket['status'] == 'archived';
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(archived ? 'Restore pocket?' : 'Archive pocket?'),
        content: Text(archived
          ? 'This pocket will become active again.'
          : 'This hides the pocket from active planning. Its history and recorded balance remain unchanged.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: Text(archived ? 'Restore' : 'Archive')),
        ],
      ),
    );
    if (confirm == true) await _toggleArchive(pocket);
  }
}
