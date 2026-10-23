import 'dart:async';
import 'package:flutter/material.dart';
import '../database/vault_database.dart';
import '../transport/transport_manager.dart';

class NearbyScreen extends StatefulWidget {
  final String lang;
  final Function(String peerId, String peerName)? onDirectMessage;

  const NearbyScreen({super.key, required this.lang, this.onDirectMessage});

  @override
  State<NearbyScreen> createState() => _NearbyScreenState();
}

class _NearbyScreenState extends State<NearbyScreen> {
  bool isScanning = false;
  bool isAdvertising = false;
  bool allowRelay = true;
  int maxHops = 3;
  StreamSubscription? _sub;
  List<DiscoveredPeer> peers = [];

  @override
  void initState() {
    super.initState();
    _loadSettings();
    _sub = TransportManager.instance.peerStream.listen((list) {
      if (mounted) setState(() => peers = list);
    });
    peers = TransportManager.instance.peers;
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  Future<void> _loadSettings() async {
    final relayVal = await VaultDatabase.instance.getSetting('allowRelay', defaultVal: 'true');
    final hopsVal = await VaultDatabase.instance.getSetting('maxHops', defaultVal: '3');
    if (mounted) {
      setState(() {
        allowRelay = relayVal == 'true';
        maxHops = int.tryParse(hopsVal) ?? 3;
        isScanning = TransportManager.instance.isScanning;
        isAdvertising = TransportManager.instance.isAdvertising;
      });
    }
  }

  Future<void> _toggleDiscovery() async {
    if (isScanning) {
      await TransportManager.instance.stopDiscovery();
      setState(() => isScanning = false);
    } else {
      final success = await TransportManager.instance.startDiscovery();
      setState(() => isScanning = success);
      if (!success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not start Bluetooth discovery. Check permissions.')),
        );
      }
    }
  }

  Future<void> _toggleAdvertising() async {
    if (isAdvertising) {
      await TransportManager.instance.stopAdvertising();
      setState(() => isAdvertising = false);
    } else {
      final success = await TransportManager.instance.startAdvertising('phone-${DateTime.now().millisecondsSinceEpoch % 10000}');
      setState(() => isAdvertising = success);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isTa = widget.lang == 'ta';

    return Scaffold(
      appBar: AppBar(
        title: Text(isTa ? 'அருகிலுள்ள இணைப்பு' : 'Nearby Connect (BLE / P2P)'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Discovery Control Card
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.bluetooth_searching, color: isScanning ? Colors.blue : Colors.grey, size: 28),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              isTa ? 'சாதன கண்டறிதல் (BLE Scanning)' : 'Device Discovery (Mode B)',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                            ),
                            Text(
                              isTa ? 'அருகிலுள்ள கிராமசேது சாதனங்களைத் தேடுங்கள்.' : 'Scan for nearby GramSetu neighbour devices.',
                              style: const TextStyle(fontSize: 12, color: Colors.grey),
                            ),
                          ],
                        ),
                      ),
                      Switch(
                        value: isScanning,
                        onChanged: (_) => _toggleDiscovery(),
                      ),
                    ],
                  ),
                  const Divider(height: 24),
                  Row(
                    children: [
                      Icon(Icons.cell_tower, color: isAdvertising ? Colors.green : Colors.grey, size: 28),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              isTa ? 'அடையாள ஒளிபரப்பு (BLE Advertising)' : 'Make Device Visible (Advertising)',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                            ),
                            Text(
                              isTa ? 'மற்ற அண்டை வீட்டார் உங்களைக் கண்டறிய உதவும்.' : 'Broadcast presence so neighbours can send messages.',
                              style: const TextStyle(fontSize: 12, color: Colors.grey),
                            ),
                          ],
                        ),
                      ),
                      Switch(
                        value: isAdvertising,
                        onChanged: (_) => _toggleAdvertising(),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Discovered Peers
          Text(
            isTa ? 'கண்டறியப்பட்ட சாதனங்கள் (${peers.length})' : 'Discovered Devices (${peers.length})',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          if (peers.isEmpty)
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  const Icon(Icons.wifi_tethering_off, size: 36, color: Colors.grey),
                  const SizedBox(height: 8),
                  Text(
                    isTa ? 'சாதனங்கள் எதுவும் கண்டறியப்படவில்லை. கண்டறிதலை இயக்கவும்.' : 'No nearby devices found yet. Toggle discovery on.',
                    style: const TextStyle(color: Colors.grey, fontSize: 13),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            )
          else
            ...peers.map((p) => _peerCard(p, isTa)),

          const SizedBox(height: 20),

          // Mode C Store-and-Forward Relay
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.share_location, color: Colors.deepPurple, size: 24),
                      const SizedBox(width: 8),
                      Text(
                        isTa ? 'சமூக தொடர் செய்தி பரிமாற்றம் (Mode C)' : 'Community Store-and-Forward Relay (Mode C)',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    isTa
                        ? 'நேரடி புளூடூத் எட்டாத தூரத்தில் உள்ள அண்டை வீட்டாருக்கு என்க்ரிப்ட் செய்யப்பட்ட செய்திகளை சுமந்து செல்ல உதவும்.'
                        : 'Carry encrypted emergency/health messages for distant neighbours. Plaintext content is never exposed to relaying phones.',
                    style: const TextStyle(fontSize: 12, color: Colors.black87),
                  ),
                  const SizedBox(height: 12),
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(isTa ? 'செய்தி தொடர் பரிமாற்றத்தில் பங்கேற்கவும்' : 'Participate in store-and-forward relaying'),
                    value: allowRelay,
                    onChanged: (val) async {
                      setState(() => allowRelay = val ?? true);
                      await VaultDatabase.instance.setSetting('allowRelay', allowRelay.toString());
                    },
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Text(isTa ? 'அதிகபட்ச தடம் வரம்பு:' : 'Max Hop Limit:'),
                      const SizedBox(width: 12),
                      DropdownButton<int>(
                        value: maxHops,
                        items: const [
                          DropdownMenuItem(value: 2, child: Text('2 Hops')),
                          DropdownMenuItem(value: 3, child: Text('3 Hops (Recommended)')),
                          DropdownMenuItem(value: 5, child: Text('5 Hops (Max Range)')),
                        ],
                        onChanged: (val) async {
                          if (val != null) {
                            setState(() => maxHops = val);
                            await VaultDatabase.instance.setSetting('maxHops', val.toString());
                          }
                        },
                      ),
                    ],
                  )
                ],
              ),
            ),
          )
        ],
      ),
    );
  }

  Widget _peerCard(DiscoveredPeer p, bool isTa) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Colors.blue.shade100,
          child: const Icon(Icons.phone_android, color: Colors.blue),
        ),
        title: Text(p.name, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text('RSSI: ${p.rssi} dBm · ID: ${p.id.take(12)}'),
        trailing: ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.blue.shade700,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          ),
          onPressed: () {
            if (widget.onDirectMessage != null) {
              widget.onDirectMessage!(p.id, p.name);
            }
          },
          child: Text(isTa ? 'நேரடி செய்தி' : 'Send Direct'),
        ),
      ),
    );
  }
}

extension StringExtension on String {
  String take(int n) => length <= n ? this : substring(0, n);
}
