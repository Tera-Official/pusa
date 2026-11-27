import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class MobileMoneyDetectionScreen extends StatefulWidget {
  const MobileMoneyDetectionScreen({super.key});
  @override
  State<MobileMoneyDetectionScreen> createState() => _MobileMoneyDetectionScreenState();
}

class _MobileMoneyDetectionScreenState extends State<MobileMoneyDetectionScreen> with WidgetsBindingObserver {
  static const _channel = MethodChannel('pusa/mobile_money');
  bool _enabled = false, _mtn = true, _orange = true, _sms = false;
  bool _notificationAccess = false, _smsPermission = false, _loading = true;
  String? _message;
  List<Map<String, dynamic>> _events = [];

  @override
  void initState() { super.initState(); WidgetsBinding.instance.addObserver(this); _refresh(); }

  @override
  void dispose() { WidgetsBinding.instance.removeObserver(this); super.dispose(); }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _refresh();
  }

  Future<void> _refresh() async {
    try {
      final prefs = Map<String, dynamic>.from(await _channel.invokeMapMethod<String, dynamic>('getPreferences') ?? {});
      final access = await _channel.invokeMethod<bool>('hasNotificationAccess') ?? false;
      final sms = await _channel.invokeMethod<bool>('hasSmsPermission') ?? false;
      final events = await _channel.invokeListMethod<dynamic>('getEvents') ?? [];
      if (!mounted) return;
      setState(() {
        _enabled = prefs['enabled'] == true; _mtn = prefs['mtn'] != false;
        _orange = prefs['orange'] != false; _sms = prefs['sms'] == true;
        _notificationAccess = access; _smsPermission = sms;
        _events = events.map((e) => Map<String, dynamic>.from(e as Map)).toList();
        _loading = false;
      });
    } on PlatformException catch (e) {
      if (mounted) setState(() { _loading = false; _message = e.message ?? 'Could not load settings.'; });
    }
  }

  Future<void> _save() async => _channel.invokeMethod<bool>('setPreferences', {
    'enabled': _enabled, 'mtn': _mtn, 'orange': _orange, 'sms': _sms,
  });

  Future<void> _toggleDetection(bool value) async {
    setState(() => _enabled = value); await _save();
    await _channel.invokeMethod<bool>('requestNotificationPermission');
    if (value && !_notificationAccess) {
      await _channel.invokeMethod<bool>('openNotificationAccess');
      setState(() => _message = 'Enable Pusa in Android Notification access, then return here.');
    }
    await _refresh();
  }

  Future<void> _toggleSms(bool value) async {
    setState(() => _sms = value);
    await _save();
    if (value && !_smsPermission) {
      await _channel.invokeMethod<bool>('requestSmsPermission');
      setState(() => _message = 'Grant SMS access in Android if you want to scan provider confirmations. Notification detection works separately.');
    }
    await _refresh();
  }

  Future<void> _scanSms() async {
    try {
      final events = await _channel.invokeListMethod<dynamic>('readSmsHistory') ?? [];
      if (!mounted) return;
      setState(() {
        _events = events.map((e) => Map<String, dynamic>.from(e as Map)).toList();
        _message = 'Recent provider SMS scanned on this phone. Raw message text stays local.';
      });
    } on PlatformException catch (e) {
      if (mounted) setState(() => _message = e.code == 'sms_permission' ? 'Enable SMS permission first.' : 'Could not scan SMS.');
    }
  }

  Future<void> _review(String id) async {
    await _channel.invokeMethod<bool>('markReviewed', {'eventId': id});
    await _refresh();
  }

  @override
  Widget build(BuildContext context) {
    final pending = _events.where((e) => e['reviewed'] != true).toList();
    return Scaffold(
      appBar: AppBar(title: const Text('Money alerts', style: TextStyle(fontWeight: FontWeight.w800))),
      body: _loading ? const Center(child: CircularProgressIndicator()) : ListView(
        padding: const EdgeInsets.all(18),
        children: [
          const Text('Detect Mobile Money activity', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          const Text('Pusa checks supported Orange Money and MTN MoMo notifications on this phone. Detected activity is only a suggestion; it is not a verified deposit and never moves money.'),
          const SizedBox(height: 16),
          SwitchListTile(contentPadding: EdgeInsets.zero, title: const Text('Enable notification detection', style: TextStyle(fontWeight: FontWeight.w700)),
            subtitle: Text(_notificationAccess ? 'Android notification access enabled.' : 'Android will ask you to enable notification access.'),
            value: _enabled, onChanged: _toggleDetection),
          SwitchListTile(contentPadding: EdgeInsets.zero, title: const Text('MTN MoMo'), value: _mtn,
            onChanged: (v) async { setState(() => _mtn = v); await _save(); }),
          SwitchListTile(contentPadding: EdgeInsets.zero, title: const Text('Orange Money'), value: _orange,
            onChanged: (v) async { setState(() => _orange = v); await _save(); }),
          const Divider(),
          SwitchListTile(contentPadding: EdgeInsets.zero, title: const Text('Scan SMS inbox and sent messages'),
            subtitle: Text(_smsPermission ? 'SMS permission granted.' : 'Optional sensitive Android permission.'),
            value: _sms, onChanged: _toggleSms),
          OutlinedButton.icon(onPressed: _smsPermission ? _scanSms : () => _toggleSms(true),
            icon: const Icon(Icons.sms_outlined), label: const Text('Scan recent SMS on this phone')),
          if (_message != null) Padding(padding: const EdgeInsets.only(top: 8), child: Text(_message!, style: const TextStyle(color: Color(0xFF536477)))),
          const SizedBox(height: 20),
          Row(children: [
            Expanded(child: Text('Detected transactions (' + pending.length.toString() + ')', style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800))),
            IconButton(onPressed: _refresh, icon: const Icon(Icons.refresh), tooltip: 'Refresh'),
          ]),
          if (pending.isEmpty) const Card(child: Padding(padding: EdgeInsets.all(16), child: Text('No transactions awaiting review. Matching activity appears here.')))
          else ...pending.map((event) {
            final incoming = event['direction'] == 'incoming';
            final amount = (event['amountXaf'] as num? ?? 0).toInt();
            final provider = event['provider'] as String? ?? 'Mobile Money';
            final id = event['id'] as String? ?? '';
            return Card(child: Padding(padding: const EdgeInsets.all(14), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text((incoming ? 'Possible money received' : 'Possible payment') + ' · ' + provider, style: const TextStyle(fontWeight: FontWeight.w800)),
              const SizedBox(height: 6), Text(amount.toString() + ' XAF', style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w800)),
              Text(event['source'] == 'sms' ? 'Detected from SMS' : 'Detected from app notification', style: const TextStyle(color: Color(0xFF758394), fontSize: 12)),
              Align(alignment: Alignment.centerRight, child: TextButton(onPressed: id.isEmpty ? null : () => _review(id), child: const Text('Review and dismiss'))),
            ])));
          }),
          const SizedBox(height: 16),
          const Text('Notifications are local on-device alerts for now; remote Firebase push setup is still pending. Privacy: parsed suggestions are stored locally. Pusa does not upload your SMS history or raw notification text. It cannot know which received amount is being spent when Mobile Money funds are mixed.', style: TextStyle(fontSize: 12, color: Color(0xFF758394))),
        ],
      ),
    );
  }
}
