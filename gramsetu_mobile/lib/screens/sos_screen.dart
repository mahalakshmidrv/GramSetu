import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:uuid/uuid.dart';
import '../database/vault_database.dart';
import '../models/models.dart';
import '../transport/transport_manager.dart';

class SosScreen extends StatefulWidget {
  final String lang;
  const SosScreen({super.key, required this.lang});

  @override
  State<SosScreen> createState() => _SosScreenState();
}

class _SosScreenState extends State<SosScreen> {
  List<SosRecord> alerts = [];
  List<ContactModel> priorityContacts = [];
  final TextEditingController locCtrl = TextEditingController();
  Timer? _countdownTimer;
  int _countdown = 3;
  bool _isCountingDown = false;
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    locCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => isLoading = true);
    final data = await VaultDatabase.instance.getSosRecords();
    final contacts = await VaultDatabase.instance.getContacts();
    setState(() {
      alerts = data;
      priorityContacts = contacts.filter((c) => c.priority == 1).toList();
      isLoading = false;
    });
  }

  void _triggerSosCountdown() {
    setState(() {
      _isCountingDown = true;
      _countdown = 3;
    });

    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_countdown > 1) {
        setState(() => _countdown--);
      } else {
        timer.cancel();
        setState(() => _isCountingDown = false);
        _executeSos();
      }
    });
  }

  void _cancelCountdown() {
    _countdownTimer?.cancel();
    setState(() {
      _isCountingDown = false;
      _countdown = 3;
    });
    final isTa = widget.lang == 'ta';
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(isTa ? 'அவசர SOS ரத்து செய்யப்பட்டது.' : 'SOS activation cancelled.')),
    );
  }

  Future<void> _executeSos() async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final isTa = widget.lang == 'ta';
    final manualLoc = locCtrl.text.trim();

    final record = SosRecord(
      id: 'sos-${const Uuid().v4()}',
      name: 'Citizen',
      village: '',
      phone: '',
      lat: 13.0827, // Default village reference lat/lon
      lon: 80.2707,
      locationNote: manualLoc.isNotEmpty ? manualLoc : (isTa ? 'இருப்பிடம் குறிப்பிடப்படவில்லை' : 'Location not specified'),
      text: isTa ? 'அவசரம்: உடனடி மருத்துவ உதவி தேவை!' : 'EMERGENCY: Urgent medical assistance needed!',
      status: 'saved_locally',
      createdAt: now,
    );

    await VaultDatabase.instance.saveSosRecord(record);
    _loadData();

    // Trigger sync
    TransportManager.instance.syncWithServer();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Colors.red.shade700,
          content: Text(
            isTa
                ? '🚨 அவசர SOS போனில் சேமிக்கப்பட்டது! அருகிலுள்ள சாதனங்களுக்கு அனுப்பப்படுகிறது.'
                : '🚨 Emergency SOS saved locally and broadcast via Nearby Connect!',
          ),
        ),
      );
    }
  }

  Future<void> _callHelpline(String number) async {
    final clean = number.replaceAll(RegExp(r'[^+\d]'), '');
    final uri = Uri(scheme: 'tel', path: clean);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  String _formatDate(int ms) {
    final dt = DateTime.fromMillisecondsSinceEpoch(ms);
    return DateFormat('dd MMM, hh:mm a').format(dt);
  }

  Widget _sosStatusBadge(String status, bool isTa) {
    Color bg = Colors.red.shade100;
    Color fg = Colors.red.shade900;
    String label = status;

    switch (status) {
      case 'saved_locally':
        bg = Colors.red.shade50;
        fg = Colors.red.shade800;
        label = isTa ? '📱 போனில் சேமிக்கப்பட்டது (அனுப்பப்படவில்லை)' : '📱 Saved locally (Not transmitted)';
        break;
      case 'transmitted_server':
        bg = Colors.green.shade50;
        fg = Colors.green.shade800;
        label = isTa ? '🌐 சர்வருக்கு சென்றடைந்தது' : '🌐 Received by Server';
        break;
      case 'cancelled':
        bg = Colors.grey.shade200;
        fg = Colors.grey.shade700;
        label = isTa ? '✕ தவறான எச்சரிக்கை ரத்து செய்யப்பட்டது' : '✕ Cancelled false alarm';
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(10)),
      child: Text(label, style: TextStyle(color: fg, fontSize: 10, fontWeight: FontWeight.bold)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isTa = widget.lang == 'ta';

    return Scaffold(
      appBar: AppBar(
        title: Text(isTa ? 'அவசர உதவி (SOS)' : 'Emergency SOS & Assistance'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Emergency Trigger Card
          Card(
            color: Colors.red.shade50,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: Colors.red.shade300, width: 2),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Text(
                    isTa ? '🚨 அவசர உதவி உடனடியாக தேவைப்படுகிறதா?' : '🚨 Immediate Emergency Assistance',
                    style: TextStyle(color: Colors.red.shade900, fontWeight: FontWeight.bold, fontSize: 16),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    isTa
                        ? 'பொத்தானை அழுத்துவது அவசர எச்சரிக்கையை உடனடியாக சேமித்து அருகிலுள்ள கிராமத்தாருக்கு அனுப்பும்.'
                        : 'Creates an instant SOS record on this phone and alerts nearby responders.',
                    style: TextStyle(color: Colors.red.shade800, fontSize: 12),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: locCtrl,
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: Colors.white,
                      prefixIcon: const Icon(Icons.location_on, color: Colors.red),
                      labelText: isTa ? 'உங்கள் இருப்பிடம் / அடையாளம்' : 'Location / House Landmark',
                      hintText: isTa ? 'எ.கா. கிழக்கு கால்வாய் பாலம், ராம்பூர்' : 'e.g. Near East Canal Gate, Rampur',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  const SizedBox(height: 14),
                  if (_isCountingDown)
                    Column(
                      children: [
                        Text(
                          isTa ? 'அனுப்பப்படுகிறது: $_countdown விநாடிகளில்...' : 'Activating in $_countdown seconds...',
                          style: const TextStyle(color: Colors.red, fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.grey.shade800, foregroundColor: Colors.white),
                          onPressed: _cancelCountdown,
                          icon: const Icon(Icons.close),
                          label: Text(isTa ? 'ரத்துசெய் (தவறாக அழுத்தப்பட்டது)' : 'Cancel (Accidental Press)'),
                        ),
                      ],
                    )
                  else
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red.shade700,
                        foregroundColor: Colors.white,
                        minimumSize: const Size.fromHeight(52),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      onPressed: _triggerSosCountdown,
                      icon: const Icon(Icons.emergency, size: 28),
                      label: Text(
                        isTa ? 'SOS – அவசர உதவி அனுப்பு' : 'SOS – SEND EMERGENCY ALERT',
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Official Phone Helplines
          Text(
            isTa ? 'அவசர தொலைபேசி எண்கள் (செல்லுலார் அழைப்பு)' : 'Emergency Phone Lines (Direct Call)',
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.red.shade800, foregroundColor: Colors.white),
                  onPressed: () => _callHelpline('112'),
                  icon: const Icon(Icons.call),
                  label: const Text('112 (All Emergencies)'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.red.shade800, foregroundColor: Colors.white),
                  onPressed: () => _callHelpline('108'),
                  icon: const Icon(Icons.medical_services),
                  label: const Text('108 (Ambulance)'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _callHelpline('102'),
                  icon: const Icon(Icons.pregnant_woman),
                  label: const Text('102 (Maternity)'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Priority Contacts
          if (priorityContacts.isNotEmpty) ...[
            Text(
              isTa ? 'நம்பகமான முன்னுரிமை தொடர்புகள்' : 'Trusted Priority Contacts',
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            ...priorityContacts.map((c) => Card(
              child: ListTile(
                leading: const CircleAvatar(backgroundColor: Colors.amber, child: Text('⭐')),
                title: Text(c.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text(c.phone),
                trailing: IconButton(
                  icon: const Icon(Icons.phone, color: Colors.green),
                  onPressed: () => _callHelpline(c.phone),
                ),
              ),
            )),
            const SizedBox(height: 16),
          ],

          // SOS History
          Text(
            isTa ? 'சமீபத்திய அவசர எச்சரிக்கைகள் (${alerts.length})' : 'Recent SOS Records (${alerts.length})',
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          if (alerts.isEmpty)
            Text(isTa ? 'எச்சரிக்கைகள் எதுவும் இல்லை.' : 'No emergency alerts recorded.', style: const TextStyle(color: Colors.grey))
          else
            ...alerts.map((a) => Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(a.text, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                        const Spacer(),
                        _sosStatusBadge(a.status, isTa),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text('${isTa ? "இருப்பிடம்:" : "Location:"} ${a.locationNote}', style: const TextStyle(fontSize: 12)),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Text(_formatDate(a.createdAt), style: const TextStyle(color: Colors.grey, fontSize: 11)),
                        const Spacer(),
                        if (a.status != 'cancelled')
                          TextButton(
                            onPressed: () async {
                              await VaultDatabase.instance.cancelSos(a.id);
                              _loadData();
                            },
                            child: Text(isTa ? 'ரத்துசெய் (தவறான எச்சரிக்கை)' : 'Cancel False Alarm'),
                          ),
                      ],
                    )
                  ],
                ),
              ),
            )),
        ],
      ),
    );
  }
}

extension IterableExtension<T> on Iterable<T> {
  Iterable<T> filter(bool Function(T) test) => where(test);
}
