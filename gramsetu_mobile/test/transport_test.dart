import 'package:flutter_test/flutter_test.dart';
import 'package:gramsetu_mobile/models/models.dart';
import 'package:gramsetu_mobile/transport/transport_manager.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  group('GramSetu 2.0 Transport Logic Suite', () {
    test('Hop limit rejection when hopCount >= maxHops', () async {
      final msg = MessageModel(
        id: 'hop-test-1',
        toId: 'peer-village',
        toName: 'Panchayat Office',
        body: 'Village meeting announcement',
        status: 'relayed',
        transport: 'relay',
        hopCount: 3,
        maxHops: 3,
        ttl: 86400,
        createdAt: DateTime.now().millisecondsSinceEpoch,
      );

      final accepted = await TransportManager.instance.sendNearbyPacket(msg);
      expect(accepted, isFalse);
    });

    test('TTL expiration rejection when packet is too old', () async {
      // Created 2 hours ago with 1 hour TTL
      final pastTime = DateTime.now().subtract(const Duration(hours: 2)).millisecondsSinceEpoch;
      final expiredMsg = MessageModel(
        id: 'ttl-test-1',
        toId: 'peer-health',
        toName: 'Primary Health Centre',
        body: 'Expired routine query',
        status: 'local',
        transport: 'nearby_ble',
        hopCount: 1,
        maxHops: 3,
        ttl: 3600, // 1 hour TTL
        createdAt: pastTime,
      );

      final accepted = await TransportManager.instance.sendNearbyPacket(expiredMsg);
      expect(accepted, isFalse);
    });

    test('Deduplication prevents re-transmitting already seen packet ID', () async {
      // First submission with hop limit exceeded marks it in _seenPackets
      final msg = MessageModel(
        id: 'dedup-unique-msg-99',
        toId: 'peer-farmer',
        toName: 'Kisan Kendra',
        body: 'Fertilizer stock query',
        status: 'local',
        transport: 'relay',
        hopCount: 5, // Exceeds maxHops
        maxHops: 3,
        ttl: 86400,
        createdAt: DateTime.now().millisecondsSinceEpoch,
      );

      final firstAttempt = await TransportManager.instance.sendNearbyPacket(msg);
      expect(firstAttempt, isFalse); // Rejected due to hop limit

      // Second attempt rejected immediately by deduplication set
      final validMsg = msg.copyWith(hopCount: 0);
      final secondAttempt = await TransportManager.instance.sendNearbyPacket(validMsg);
      expect(secondAttempt, isFalse); // Suppressed by deduplication
    });
  });
}
