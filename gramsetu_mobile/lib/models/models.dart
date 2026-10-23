/// Represents a trusted village contact saved in the Offline Vault
class ContactModel {
  final String id;
  final String name;
  final String phone;
  final String category; // neighbour, health_worker, farmer, family, emergency
  final String note;
  final int priority; // 1 for emergency primary, 0 for regular
  final bool trusted;
  final int createdAt;
  final int updatedAt;

  ContactModel({
    required this.id,
    required this.name,
    this.phone = '',
    this.category = 'neighbour',
    this.note = '',
    this.priority = 0,
    this.trusted = true,
    required this.createdAt,
    required this.updatedAt,
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'name': name,
    'phone': phone,
    'category': category,
    'note': note,
    'priority': priority,
    'trusted': trusted ? 1 : 0,
    'createdAt': createdAt,
    'updatedAt': updatedAt,
  };

  factory ContactModel.fromMap(Map<String, dynamic> map) => ContactModel(
    id: map['id'] as String,
    name: map['name'] as String,
    phone: (map['phone'] ?? '') as String,
    category: (map['category'] ?? 'neighbour') as String,
    note: (map['note'] ?? '') as String,
    priority: (map['priority'] ?? 0) as int,
    trusted: (map['trusted'] ?? 1) == 1,
    createdAt: (map['createdAt'] ?? 0) as int,
    updatedAt: (map['updatedAt'] ?? 0) as int,
  );
}

/// Represents an offline peer or relay message
class MessageModel {
  final String id;
  final String toId;
  final String toName;
  final String body;
  final String status; // local, queued, sending, delivered_device, relayed, acknowledged, failed
  final String transport; // backend, nearby_ble, nearby_p2p, relay
  final int hopCount;
  final int maxHops;
  final int ttl;
  final int createdAt;
  final int? deliveredAt;
  final int? ackAt;

  MessageModel({
    required this.id,
    required this.toId,
    required this.toName,
    required this.body,
    this.status = 'local',
    this.transport = 'backend',
    this.hopCount = 0,
    this.maxHops = 3,
    this.ttl = 86400,
    required this.createdAt,
    this.deliveredAt,
    this.ackAt,
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'toId': toId,
    'toName': toName,
    'body': body,
    'status': status,
    'transport': transport,
    'hopCount': hopCount,
    'maxHops': maxHops,
    'ttl': ttl,
    'createdAt': createdAt,
    'deliveredAt': deliveredAt,
    'ackAt': ackAt,
  };

  factory MessageModel.fromMap(Map<String, dynamic> map) => MessageModel(
    id: map['id'] as String,
    toId: map['toId'] as String,
    toName: (map['toName'] ?? '') as String,
    body: map['body'] as String,
    status: (map['status'] ?? 'local') as String,
    transport: (map['transport'] ?? 'backend') as String,
    hopCount: (map['hopCount'] ?? 0) as int,
    maxHops: (map['maxHops'] ?? 3) as int,
    ttl: (map['ttl'] ?? 86400) as int,
    createdAt: (map['createdAt'] ?? 0) as int,
    deliveredAt: map['deliveredAt'] as int?,
    ackAt: map['ackAt'] as int?,
  );

  MessageModel copyWith({
    String? id,
    String? toId,
    String? toName,
    String? body,
    String? status,
    String? transport,
    int? hopCount,
    int? maxHops,
    int? ttl,
    int? createdAt,
    int? deliveredAt,
    int? ackAt,
  }) => MessageModel(
    id: id ?? this.id,
    toId: toId ?? this.toId,
    toName: toName ?? this.toName,
    body: body ?? this.body,
    status: status ?? this.status,
    transport: transport ?? this.transport,
    hopCount: hopCount ?? this.hopCount,
    maxHops: maxHops ?? this.maxHops,
    ttl: ttl ?? this.ttl,
    createdAt: createdAt ?? this.createdAt,
    deliveredAt: deliveredAt ?? this.deliveredAt,
    ackAt: ackAt ?? this.ackAt,
  );
}

/// Represents a Spotify-style downloaded resource in Offline Vault
class ResourceModel {
  final String key;
  final String category; // first_aid, health_centre, crop_care, government_service
  final String icon;
  final String titleEn;
  final String titleTa;
  final String bodyEn;
  final String bodyTa;
  final int lastUpdated;

  ResourceModel({
    required this.key,
    required this.category,
    required this.icon,
    required this.titleEn,
    required this.titleTa,
    required this.bodyEn,
    required this.bodyTa,
    required this.lastUpdated,
  });

  String title(String lang) => lang == 'ta' ? titleTa : titleEn;
  String body(String lang) => lang == 'ta' ? bodyTa : bodyEn;

  Map<String, dynamic> toMap() => {
    'key': key,
    'category': category,
    'icon': icon,
    'titleEn': titleEn,
    'titleTa': titleTa,
    'bodyEn': bodyEn,
    'bodyTa': bodyTa,
    'lastUpdated': lastUpdated,
  };

  factory ResourceModel.fromMap(Map<String, dynamic> map) => ResourceModel(
    key: map['key'] as String,
    category: map['category'] as String,
    icon: (map['icon'] ?? '📄') as String,
    titleEn: (map['titleEn'] ?? map['title_en'] ?? '') as String,
    titleTa: (map['titleTa'] ?? map['title_ta'] ?? '') as String,
    bodyEn: (map['bodyEn'] ?? map['body_en'] ?? '') as String,
    bodyTa: (map['bodyTa'] ?? map['body_ta'] ?? '') as String,
    lastUpdated: (map['lastUpdated'] ?? map['updated_at'] ?? 0) as int,
  );
}

/// Represents an emergency SOS event
class SosRecord {
  final String id;
  final String name;
  final String village;
  final String phone;
  final double? lat;
  final double? lon;
  final String locationNote;
  final String text;
  final String status; // saved_locally, relaying, transmitted_server, acknowledged_neighbour, cancelled
  final int createdAt;

  SosRecord({
    required this.id,
    this.name = 'Citizen',
    this.village = '',
    this.phone = '',
    this.lat,
    this.lon,
    this.locationNote = '',
    this.text = 'EMERGENCY: Urgent assistance needed!',
    this.status = 'saved_locally',
    required this.createdAt,
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'name': name,
    'village': village,
    'phone': phone,
    'lat': lat,
    'lon': lon,
    'locationNote': locationNote,
    'text': text,
    'status': status,
    'createdAt': createdAt,
  };

  factory SosRecord.fromMap(Map<String, dynamic> map) => SosRecord(
    id: map['id'] as String,
    name: (map['name'] ?? 'Citizen') as String,
    village: (map['village'] ?? '') as String,
    phone: (map['phone'] ?? '') as String,
    lat: (map['lat'] as num?)?.toDouble(),
    lon: (map['lon'] as num?)?.toDouble(),
    locationNote: (map['locationNote'] ?? '') as String,
    text: (map['text'] ?? '') as String,
    status: (map['status'] ?? 'saved_locally') as String,
    createdAt: (map['createdAt'] ?? 0) as int,
  );
}
