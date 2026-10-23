import 'package:flutter_test/flutter_test.dart';
import 'package:gramsetu_mobile/models/models.dart';

void main() {
  group('GramSetu 2.0 Models Test Suite', () {
    test('ContactModel serialization and deserialization', () {
      final contact = ContactModel(
        id: 'c-101',
        name: 'Murugan (Panchayat Head)',
        phone: '+919876543210',
        category: 'emergency',
        note: 'Village President, Main Street',
        priority: 1,
        trusted: true,
        createdAt: 1700000000,
        updatedAt: 1700000000,
      );

      final map = contact.toMap();
      expect(map['id'], 'c-101');
      expect(map['name'], 'Murugan (Panchayat Head)');
      expect(map['priority'], 1);

      final from = ContactModel.fromMap(map);
      expect(from.id, contact.id);
      expect(from.name, contact.name);
      expect(from.phone, contact.phone);
      expect(from.category, contact.category);
      expect(from.priority, 1);
    });

    test('MessageModel hop counting, TTL and status', () {
      final msg = MessageModel(
        id: 'msg-abc',
        toId: 'peer-42',
        toName: 'Selvi Nurse',
        body: 'Medical kit requested at East Hamlet',
        status: 'local',
        transport: 'nearby_ble',
        hopCount: 1,
        maxHops: 3,
        ttl: 3600,
        createdAt: 1700000000,
      );

      final map = msg.toMap();
      expect(map['hopCount'], 1);
      expect(map['maxHops'], 3);
      expect(map['ttl'], 3600);

      final copy = msg.copyWith(hopCount: msg.hopCount + 1, status: 'relayed');
      expect(copy.hopCount, 2);
      expect(copy.status, 'relayed');
      expect(copy.id, msg.id);
      expect(copy.toName, 'Selvi Nurse');
    });

    test('ResourceModel bilingual data model', () {
      final resource = ResourceModel(
        key: 'first-aid',
        category: 'first_aid',
        icon: '🩹',
        titleEn: 'Emergency First Aid Guide',
        titleTa: 'அவசர முதலுதவி வழிகாட்டி',
        bodyEn: 'Apply continuous pressure with a clean cloth.',
        bodyTa: 'சுத்தமான துணியால் தொடர்ந்து அழுத்தவும்.',
        lastUpdated: 1700000000,
      );

      final map = resource.toMap();
      expect(map['key'], 'first-aid');
      expect(map['category'], 'first_aid');
      expect(map['icon'], '🩹');

      final deserialized = ResourceModel.fromMap(map);
      expect(deserialized.titleEn, 'Emergency First Aid Guide');
      expect(deserialized.titleTa, 'அவசர முதலுதவி வழிகாட்டி');
      expect(deserialized.lastUpdated, 1700000000);
    });

    test('SosRecord truthful status tracking', () {
      final sos = SosRecord(
        id: 'sos-999',
        name: 'Ramu',
        village: 'Keeladi',
        phone: '+919444411111',
        lat: 9.8512,
        lon: 78.1884,
        locationNote: 'Near temple water tank',
        text: 'Snake bite emergency, need vehicle',
        status: 'saved_locally',
        createdAt: 1700000000,
      );

      final map = sos.toMap();
      expect(map['status'], 'saved_locally');
      expect(map['lat'], 9.8512);
      expect(map['lon'], 78.1884);

      final from = SosRecord.fromMap(map);
      expect(from.status, 'saved_locally');
      expect(from.locationNote, 'Near temple water tank');
    });
  });
}
