import 'dart:async';
import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import '../database/vault_database.dart';
import '../models/models.dart';

class DiscoveredPeer {
  final String id;
  final String name;
  final int rssi;
  final int lastSeen;

  DiscoveredPeer({
    required this.id,
    required this.name,
    required this.rssi,
    required this.lastSeen,
  });
}

class TransportManager {
  static final TransportManager instance = TransportManager._init();
  static const MethodChannel _channel = MethodChannel('com.gramsetu.nearby/bluetooth');

  bool _isAdvertising = false;
  bool _isScanning = false;
  bool get isScanning => _isScanning;
  bool get isAdvertising => _isAdvertising;

  final Map<String, DiscoveredPeer> _peers = {};
  List<DiscoveredPeer> get peers => _peers.values.toList();

  final Set<String> _seenPackets = {};
  final StreamController<List<DiscoveredPeer>> _peerStreamController = StreamController.broadcast();
  Stream<List<DiscoveredPeer>> get peerStream => _peerStreamController.stream;

  String serverBaseUrl = 'http://127.0.0.1:8000';

  TransportManager._init() {
    _channel.setMethodCallHandler(_handleNativeCall);
  }

  Future<void> _handleNativeCall(MethodCall call) async {
    if (call.method == 'onDeviceDiscovered') {
      final map = Map<String, dynamic>.from(call.arguments as Map);
      final id = map['id'] as String;
      final name = map['name'] as String;
      final rssi = map['rssi'] as int;

      _peers[id] = DiscoveredPeer(
        id: id,
        name: name,
        rssi: rssi,
        lastSeen: DateTime.now().millisecondsSinceEpoch,
      );
      _peerStreamController.add(peers);
    }
  }

  // ---------- Native BLE Discovery & Advertising ----------
  Future<Map<String, dynamic>> checkHardwareSupport() async {
    try {
      final res = await _channel.invokeMethod<Map>('checkHardwareSupport');
      return Map<String, dynamic>.from(res ?? {});
    } catch (e) {
      return {'bluetoothEnabled': false, 'leAdvertisingSupported': false};
    }
  }

  Future<bool> startDiscovery() async {
    try {
      final res = await _channel.invokeMethod<bool>('startDiscovery');
      _isScanning = res ?? false;
      return _isScanning;
    } catch (e) {
      _isScanning = false;
      return false;
    }
  }

  Future<void> stopDiscovery() async {
    try {
      await _channel.invokeMethod('stopDiscovery');
    } catch (_) {
      // Ignore cleanup error
    }
    _isScanning = false;
  }

  Future<bool> startAdvertising(String deviceId) async {
    try {
      final res = await _channel.invokeMethod<bool>('startAdvertising', {'deviceId': deviceId});
      _isAdvertising = res ?? false;
      return _isAdvertising;
    } catch (e) {
      _isAdvertising = false;
      return false;
    }
  }

  Future<void> stopAdvertising() async {
    try {
      await _channel.invokeMethod('stopAdvertising');
    } catch (_) {
      // Ignore cleanup error
    }
    _isAdvertising = false;
  }

  // ---------- Mode B & Mode C Store-and-Forward Relay ----------
  Future<bool> sendNearbyPacket(MessageModel msg, {String? targetPeerId}) async {
    // 1. Check deduplication
    if (_seenPackets.contains(msg.id)) return false;
    _seenPackets.add(msg.id);

    // 2. Check hop limit
    if (msg.hopCount >= msg.maxHops) {
      return false; // Hop limit exceeded
    }

    // 3. Check TTL
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final createdSec = msg.createdAt ~/ 1000;
    if (now > (createdSec + msg.ttl)) {
      return false; // Expired packet
    }

    // 4. Transmit via native direct packet channel
    try {
      final packetJson = jsonEncode(msg.toMap());
      final res = await _channel.invokeMethod<Map>('sendDirectPacket', {
        'peerId': targetPeerId ?? 'broadcast',
        'payload': packetJson,
      });

      if (res != null && res['status'] == 'delivered') {
        await VaultDatabase.instance.updateMessageStatus(
          msg.id,
          'delivered_device',
          deliveredAt: DateTime.now().millisecondsSinceEpoch,
        );
        return true;
      }
    } catch (e) {
      // Offline fallback: keep in outbox
    }
    return false;
  }

  // ---------- Mode A Backend Sync ----------
  Future<bool> syncWithServer() async {
    try {
      // Health check
      final healthUri = Uri.parse('$serverBaseUrl/api/health');
      final healthRes = await http.get(healthUri).timeout(const Duration(seconds: 4));
      if (healthRes.statusCode != 200) return false;

      // 1. Sync messages
      final msgs = await VaultDatabase.instance.getMessages();
      for (final m in msgs) {
        if (m.status == 'local') {
          final uri = Uri.parse('$serverBaseUrl/api/messages/send');
          final res = await http.post(
            uri,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'id': m.id,
              'recipient_id': m.toId,
              'recipient_name': m.toName,
              'body': m.body,
              'transport': 'backend',
              'created_at': m.createdAt,
            }),
          );
          if (res.statusCode == 200) {
            await VaultDatabase.instance.updateMessageStatus(m.id, 'queued');
          }
        }
      }

      // 2. Sync SOS records
      final sosRecords = await VaultDatabase.instance.getSosRecords();
      for (final s in sosRecords) {
        if (s.status == 'saved_locally') {
          final uri = Uri.parse('$serverBaseUrl/api/sos');
          final res = await http.post(
            uri,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'id': s.id,
              'name': s.name,
              'village': s.village,
              'phone': s.phone,
              'latitude': s.lat,
              'longitude': s.lon,
              'location_note': s.locationNote,
              'text': s.text,
              'lang': 'en',
              'created_at': s.createdAt,
            }),
          );
          if (res.statusCode == 200) {
            await VaultDatabase.instance.saveSosRecord(SosRecord(
              id: s.id,
              name: s.name,
              village: s.village,
              phone: s.phone,
              lat: s.lat,
              lon: s.lon,
              locationNote: s.locationNote,
              text: s.text,
              status: 'transmitted_server',
              createdAt: s.createdAt,
            ));
          }
        }
      }

      // 3. Fetch latest resources
      final resUri = Uri.parse('$serverBaseUrl/api/vault/resources');
      final rRes = await http.get(resUri).timeout(const Duration(seconds: 5));
      if (rRes.statusCode == 200) {
        final list = jsonDecode(rRes.body) as List;
        for (final item in list) {
          final r = ResourceModel.fromMap(Map<String, dynamic>.from(item as Map));
          await VaultDatabase.instance.saveResource(r);
        }
      }

      return true;
    } catch (e) {
      return false;
    }
  }
}
