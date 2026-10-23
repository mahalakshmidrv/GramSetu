import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../database/vault_database.dart';
import '../transport/transport_manager.dart';

class SyncScreen extends StatefulWidget {
  final String lang;
  final Function(String newLang) onLanguageChanged;

  const SyncScreen({
    super.key,
    required this.lang,
    required this.onLanguageChanged,
  });

  @override
  State<SyncScreen> createState() => _SyncScreenState();
}

class _SyncScreenState extends State<SyncScreen> {
  final TextEditingController _serverCtrl = TextEditingController();
  bool _isSyncing = false;
  bool _isChecking = false;
  String? _syncStatus;
  bool? _isServerOnline;
  bool _allowRelay = true;
  int _maxHops = 3;

  int _contactCount = 0;
  int _resourceCount = 0;
  int _messageCount = 0;
  int _sosCount = 0;

  @override
  void initState() {
    super.initState();
    _serverCtrl.text = TransportManager.instance.serverBaseUrl;
    _loadSettingsAndStats();
  }

  Future<void> _loadSettingsAndStats() async {
    final relayVal = await VaultDatabase.instance.getSetting('allowRelay', defaultVal: 'true');
    final hopsVal = await VaultDatabase.instance.getSetting('maxHops', defaultVal: '3');
    final contacts = await VaultDatabase.instance.getContacts();
    final resources = await VaultDatabase.instance.getResources();
    final messages = await VaultDatabase.instance.getMessages();
    final sos = await VaultDatabase.instance.getSosRecords();

    if (mounted) {
      setState(() {
        _allowRelay = relayVal == 'true';
        _maxHops = int.tryParse(hopsVal) ?? 3;
        _contactCount = contacts.length;
        _resourceCount = resources.length;
        _messageCount = messages.length;
        _sosCount = sos.length;
      });
    }
  }

  Future<void> _checkHealth() async {
    setState(() {
      _isChecking = true;
      _isServerOnline = null;
    });

    TransportManager.instance.serverBaseUrl = _serverCtrl.text.trim();
    final ok = await TransportManager.instance.syncWithServer();

    if (mounted) {
      setState(() {
        _isChecking = false;
        _isServerOnline = ok;
      });
    }
  }

  Future<void> _triggerSync() async {
    setState(() {
      _isSyncing = true;
      _syncStatus = null;
    });

    TransportManager.instance.serverBaseUrl = _serverCtrl.text.trim();
    final success = await TransportManager.instance.syncWithServer();
    await _loadSettingsAndStats();

    if (mounted) {
      setState(() {
        _isSyncing = false;
        _syncStatus = success
            ? (widget.lang == 'ta' ? 'ஒத்திசைவு வெற்றிகரமாக முடிந்தது' : 'Sync completed successfully')
            : (widget.lang == 'ta' ? 'சர்வர் கிடைக்கவில்லை - தரவு ஆஃப்லைனில் பாதுகாப்பாக உள்ளது' : 'Server unreachable - data remains safe offline');
        _isServerOnline = success;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_syncStatus!),
          backgroundColor: success ? Colors.green.shade700 : Colors.orange.shade800,
        ),
      );
    }
  }

  Future<void> _toggleRelay(bool value) async {
    setState(() => _allowRelay = value);
    await VaultDatabase.instance.setSetting('allowRelay', value.toString());
  }

  Future<void> _updateMaxHops(int hops) async {
    setState(() => _maxHops = hops);
    await VaultDatabase.instance.setSetting('maxHops', hops.toString());
  }

  Future<void> _exportBackup() async {
    final contacts = await VaultDatabase.instance.getContacts();
    final resources = await VaultDatabase.instance.getResources();
    final messages = await VaultDatabase.instance.getMessages();
    final sos = await VaultDatabase.instance.getSosRecords();

    final backup = {
      'version': '2.0',
      'exportedAt': DateTime.now().toIso8601String(),
      'contacts': contacts.map((c) => c.toMap()).toList(),
      'resources': resources.map((r) => r.toMap()).toList(),
      'messages': messages.map((m) => m.toMap()).toList(),
      'sos': sos.map((s) => s.toMap()).toList(),
    };

    final jsonStr = const JsonEncoder.withIndent('  ').convert(backup);

    if (mounted) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(widget.lang == 'ta' ? 'காப்பு பிரதி (JSON Backup)' : 'Offline Vault Backup (JSON)'),
          content: SizedBox(
            width: double.maxFinite,
            height: 300,
            child: SingleChildScrollView(
              child: SelectableText(
                jsonStr,
                style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
              ),
            ),
          ),
          actions: [
            TextButton.icon(
              onPressed: () {
                Clipboard.setData(ClipboardData(text: jsonStr));
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(widget.lang == 'ta' ? 'கிளிப்போர்டில் நகலெடுக்கப்பட்டது' : 'Copied to clipboard'),
                  ),
                );
              },
              icon: const Icon(Icons.copy),
              label: Text(widget.lang == 'ta' ? 'நகலெடு' : 'Copy'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(widget.lang == 'ta' ? 'மூடு' : 'Close'),
            ),
          ],
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isTa = widget.lang == 'ta';

    return Scaffold(
      appBar: AppBar(
        title: Text(isTa ? 'ஒத்திசைவு & அமைப்புகள்' : 'Sync & Offline Settings'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Language Selector Card
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.language, color: Colors.blue),
                      const SizedBox(width: 8),
                      Text(
                        isTa ? 'மொழி / Language' : 'App Language',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            backgroundColor: !isTa ? Colors.blue.shade50 : null,
                            side: BorderSide(color: !isTa ? Colors.blue : Colors.grey.shade300, width: 2),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                          onPressed: () => widget.onLanguageChanged('en'),
                          child: const Text('English', style: TextStyle(fontWeight: FontWeight.bold)),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            backgroundColor: isTa ? Colors.green.shade50 : null,
                            side: BorderSide(color: isTa ? Colors.green : Colors.grey.shade300, width: 2),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                          onPressed: () => widget.onLanguageChanged('ta'),
                          child: const Text('தமிழ் (Tamil)', style: TextStyle(fontWeight: FontWeight.bold)),
                        ),
                      ),
                    ],
                  )
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Server Connection & Manual Sync Card
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.cloud_sync, color: Colors.teal),
                      const SizedBox(width: 8),
                      Text(
                        isTa ? 'மைய சேவையக ஒத்திசைவு' : 'Backend Server Synchronization',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    isTa
                        ? 'இணையம் கிடைக்கும் போது அவசர எச்சரிக்கைகள், வெளிச்செல்லும் செய்திகள் மற்றும் வழிகாட்டிகளை ஒத்திசைக்கவும்.'
                        : 'Sync outbox messages, emergency SOS dispatches, and download latest village resources when internet is available.',
                    style: const TextStyle(fontSize: 13, color: Colors.black87),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _serverCtrl,
                    decoration: InputDecoration(
                      labelText: isTa ? 'சேவையக முகவரி (Server URL)' : 'Server Base URL',
                      hintText: 'http://10.0.2.2:8000 or http://192.168.1.X:8000',
                      border: const OutlineInputBorder(),
                      prefixIcon: const Icon(Icons.dns),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.teal.shade700,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                          onPressed: _isSyncing ? null : _triggerSync,
                          icon: _isSyncing
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                )
                              : const Icon(Icons.sync),
                          label: Text(
                            _isSyncing
                                ? (isTa ? 'ஒத்திசைக்கிறது...' : 'Syncing...')
                                : (isTa ? 'இப்போது ஒத்திசைக்க' : 'Sync Now'),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      IconButton(
                        tooltip: isTa ? 'இணைப்பைச் சோதிக்கவும்' : 'Check Health',
                        onPressed: _isChecking ? null : _checkHealth,
                        icon: _isChecking
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : Icon(
                                _isServerOnline == true
                                    ? Icons.check_circle
                                    : _isServerOnline == false
                                        ? Icons.cloud_off
                                        : Icons.network_check,
                                color: _isServerOnline == true
                                    ? Colors.green
                                    : _isServerOnline == false
                                        ? Colors.red
                                        : Colors.grey,
                              ),
                      ),
                    ],
                  ),
                  if (_isServerOnline != null) ...[
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(
                          _isServerOnline! ? Icons.wifi : Icons.wifi_off,
                          size: 16,
                          color: _isServerOnline! ? Colors.green : Colors.red,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          _isServerOnline!
                              ? (isTa ? 'சேவையகம் ஆன்லைனில் உள்ளது' : 'Server is reachable')
                              : (isTa ? 'சேவையகம் ஆஃப்லைனில் உள்ளது (ஆஃப்லைன் பயன்முறை தயார்)' : 'Server is unreachable (Offline mode active)'),
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: _isServerOnline! ? Colors.green.shade800 : Colors.red.shade800,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Community Relay (Mode C) Settings Card
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.hub, color: Colors.deepPurple),
                      const SizedBox(width: 8),
                      Text(
                        isTa ? 'சமூக ரிலே அமைப்புகள் (Mode C)' : 'Community Relay Settings (Mode C)',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    isTa
                        ? 'அருகிலுள்ள கிராமவாசிகளின் அவசர செய்திகளை அடுத்த சாதனத்திற்கு அனுப்ப உங்கள் சாதனம் ரிலே போல செயல்பட அனுமதிக்கவும்.'
                        : 'Allow your device to participate in store-and-forward mesh routing for nearby emergency messages and outbox packets.',
                    style: const TextStyle(fontSize: 13, color: Colors.black87),
                  ),
                  const Divider(height: 24),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      isTa ? 'சமூக ரிலே பங்கேற்பு' : 'Participate in Community Relay',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                    subtitle: Text(
                      isTa
                        ? 'இணையம் இல்லாத போது அண்டை வீட்டாரின் செய்திகளை எடுத்துச் செல்ல உதவுகிறது'
                        : 'Carry encrypted neighbor messages across offline pockets',
                      style: const TextStyle(fontSize: 12),
                    ),
                    value: _allowRelay,
                    onChanged: _toggleRelay,
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Text(
                        isTa ? 'அதிகபட்ச தாகங்கள் (Max Hops):' : 'Max Hop Limit:',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                      const SizedBox(width: 12),
                      DropdownButton<int>(
                        value: _maxHops,
                        items: [1, 2, 3, 4, 5].map((h) {
                          return DropdownMenuItem<int>(
                            value: h,
                            child: Text('$h ${isTa ? 'தாகங்கள்' : 'hops'}'),
                          );
                        }).toList(),
                        onChanged: (val) {
                          if (val != null) _updateMaxHops(val);
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Local Database Storage Stats Card
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.storage, color: Colors.blueGrey),
                      const SizedBox(width: 8),
                      Text(
                        isTa ? 'உள்ளூர் பெட்டக சேமிப்பகம்' : 'Local Offline Vault Storage',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _badge(isTa ? 'வழிகாட்டிகள்' : 'Guides', '$_resourceCount', Colors.teal),
                      _badge(isTa ? 'தொடர்புகள்' : 'Contacts', '$_contactCount', Colors.indigo),
                      _badge(isTa ? 'செய்திகள்' : 'Messages', '$_messageCount', Colors.orange),
                      _badge(isTa ? 'SOS எச்சரிக்கைகள்' : 'SOS', '$_sosCount', Colors.red),
                    ],
                  ),
                  const Divider(height: 24),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _exportBackup,
                          icon: const Icon(Icons.file_download),
                          label: Text(isTa ? 'காப்பு பிரதி JSON' : 'Export JSON Backup'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Truth in Technology notice
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.amber.shade50,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.amber.shade300),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.verified_user, color: Colors.amber.shade900, size: 22),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    isTa
                        ? 'உண்மை நெறிமுறை: கிராமசேது இணையம் இல்லாத போது போலியான டெலிவரி ரசீதுகளை உருவாக்காது. அவசர உதவி கோரிக்கைகள் இணையம் அல்லது அருகிலுள்ள ரிலே மூலம் உறுதி செய்யப்படும் வரை "ஆஃப்லைனில் சேமிக்கப்பட்டது" என்றே காண்பிக்கும்.'
                        : 'Truthful Status Policy: GramSetu never fabricates message delivery receipts or claims emergency dispatch when data is stored locally. Records remain labeled "Saved Locally" until positively acknowledged by network or nearby peer.',
                    style: TextStyle(fontSize: 12, color: Colors.amber.shade900, height: 1.4),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _badge(String label, String value, Color color) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: color.withValues(alpha: 0.3)),
          ),
          child: Text(
            value,
            style: TextStyle(color: color, fontSize: 18, fontWeight: FontWeight.bold),
          ),
        ),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
      ],
    );
  }
}
