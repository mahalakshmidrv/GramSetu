import 'package:flutter/foundation.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi_web/sqflite_ffi_web.dart';
import '../models/models.dart';

class VaultDatabase {
  static final VaultDatabase instance = VaultDatabase._init();
  static Database? _database;

  VaultDatabase._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('gramsetu_vault.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    if (kIsWeb) {
      databaseFactory = databaseFactoryFfiWebNoWebWorker;
      return await openDatabase(
        inMemoryDatabasePath,
        version: 1,
        onCreate: _createDB,
      );
    }

    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(
      path,
      version: 1,
      onCreate: _createDB,
    );
  }

  Future<void> _createDB(Database db, int version) async {
    await db.execute('''
      CREATE TABLE contacts(
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        phone TEXT,
        category TEXT,
        note TEXT,
        priority INTEGER DEFAULT 0,
        trusted INTEGER DEFAULT 1,
        createdAt INTEGER NOT NULL,
        updatedAt INTEGER NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE messages(
        id TEXT PRIMARY KEY,
        toId TEXT NOT NULL,
        toName TEXT,
        body TEXT NOT NULL,
        status TEXT DEFAULT 'local',
        transport TEXT DEFAULT 'backend',
        hopCount INTEGER DEFAULT 0,
        maxHops INTEGER DEFAULT 3,
        ttl INTEGER DEFAULT 86400,
        createdAt INTEGER NOT NULL,
        deliveredAt INTEGER,
        ackAt INTEGER
      )
    ''');

    await db.execute('''
      CREATE TABLE resources(
        key TEXT PRIMARY KEY,
        category TEXT NOT NULL,
        icon TEXT,
        titleEn TEXT NOT NULL,
        titleTa TEXT NOT NULL,
        bodyEn TEXT NOT NULL,
        bodyTa TEXT NOT NULL,
        lastUpdated INTEGER NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE sos_records(
        id TEXT PRIMARY KEY,
        name TEXT,
        village TEXT,
        phone TEXT,
        lat REAL,
        lon REAL,
        locationNote TEXT,
        text TEXT,
        status TEXT DEFAULT 'saved_locally',
        createdAt INTEGER NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE settings(
        key TEXT PRIMARY KEY,
        val TEXT NOT NULL
      )
    ''');

    // Pre-populate default resources
    final now = DateTime.now().millisecondsSinceEpoch;
    final defaults = [
      ResourceModel(
        key: 'first-aid',
        category: 'first_aid',
        icon: '🩹',
        titleEn: 'Emergency First Aid Guide',
        titleTa: 'அவசர முதலுதவி வழிகாட்டி',
        bodyEn: '1. Heavy Bleeding: Apply firm continuous pressure with a clean cloth. Elevate the wounded limb.\n2. Heat Stroke: Move person to shade, loosen clothing, apply cool damp cloth. Give sips of cool water.\n3. Snake Bite: Keep victim calm and still. Immobilize bitten limb below heart level. DO NOT cut wound or suck venom. Call 108 ambulance immediately.\n4. Burns: Pour cool clean running water over burn for 10-15 minutes. Cover loosely.\n5. Choking: Give 5 back blows followed by upward abdominal thrusts.\n6. Dehydration: Prepare ORS (1 packet in 1L boiled water or 6 tsp sugar + 1/2 tsp salt in 1L water).',
        bodyTa: '1. அதிக ரத்தப்போக்கு: சுத்தமான துணியால் தொடர்ந்து அழுத்தவும். காயமடைந்த பகுதியை உயர்த்தவும்.\n2. வெப்ப பக்கவாதம்: நிழலில் படுக்க வைக்கவும், குளிர்ந்த நீர் தெளிக்கவும்.\n3. பாம்பு கடி: அமைதியாக இருக்கவும், காலையோ கையையோ அசைக்க வேண்டாம். காயத்தை வெட்டவோ உறிஞ்சவோ கூடாது. உடனடியாக 108 ஆம்புலன்ஸ் மூலம் மருத்துவமனைக்கு செல்லவும்.\n4. தீக்காயம்: 10-15 நிமிடம் குளிர்ந்த நீர் ஊற்றவும்.\n5. ஓ.ஆர்.எஸ் (ORS): 1 லிட்டர் நீரில் 6 தேக்கரண்டி சர்க்கரை + 1/2 தேக்கரண்டி உப்பு கலந்து குடிக்க கொடுக்கவும்.',
        lastUpdated: now,
      ),
      ResourceModel(
        key: 'health-centres',
        category: 'health_centre',
        icon: '🏥',
        titleEn: 'Village Health Centres & Medical Directory',
        titleTa: 'கிராம சுகாதார நிலையங்கள் மற்றும் மருத்துவ தொடர்புகள்',
        bodyEn: '• Primary Health Sub-Centre: Open Mon-Sat 9 AM - 4 PM. ANM Nurse & ASHA Worker available for immunization, maternal checkups, and basic medicines.\n• Primary Health Centre (PHC): Open 24/7 for emergency delivery & stabilization. Medical Officer on duty. Free medicines.\n• Community Health Centre (CHC): 30-bed hospital with surgeon, physician, and pediatric care.\n• Emergency Ambulance Helpline: Dial 108 (Toll Free, 24/7).\n• Pregnant Mother & Infant Ambulance: Dial 102.\n• National Emergency Helpline: Dial 112.',
        bodyTa: '• ஆரம்ப சுகாதார துணை நிலையம்: திங்கள்-சனி காலை 9 முதல் மாலை 4 வரை. ஏஎன்எம் செவிலியர் மற்றும் ஆஷா பணியாளர்.\n• ஆரம்ப சுகாதார நிலையம் (PHC): 24 மணி நேரமும் செயல்படுகிறது. அவசர சிகிச்சை மற்றும் பிரசவம்.\n• சமூக சுகாதார மையம் (CHC): 30 படுக்கைகள் மற்றும் சிறப்பு மருத்துவர்கள்.\n• அவசர ஆம்புலன்ஸ்: 108 (இலவசம், 24/7).\n• தாய்-சேய் ஆம்புலன்ஸ்: 102.\n• அவசர உதவி எண்: 112.',
        lastUpdated: now,
      ),
      ResourceModel(
        key: 'crop-care',
        category: 'crop_care',
        icon: '🌾',
        titleEn: 'Farmer Crop Care & Pest Advisory',
        titleTa: 'விவசாய பயிர் பாதுகாப்பு மற்றும் பூச்சி மேலாண்மை',
        bodyEn: '• Paddy (Rice): Watch for stem borer and leaf folder. Maintain 2-3 cm water level; drain water for 2 days if root rot appears. Use neem-based organic repellents.\n• Millets & Maize: Excellent drought tolerance. Ensure good drainage; avoid water stagnation. Apply organic farmyard manure before sowing.\n• Cotton: Inspect underside of leaves for whitefly. Install yellow sticky traps (5-6 traps per acre).\n• Pulses: Treat seeds with Rhizobium culture before sowing to enhance nitrogen fixation.\n• Soil Health Card Advisory: Test soil every 2 years. Reduce excess urea; balance with phosphorus, potassium and zinc.\n• Kisan Call Centre Helpline: 1800-180-1551 (Toll Free, 6 AM to 10 PM daily).',
        bodyTa: '• நெல்: தண்டு துளைப்பான் மற்றும் இலை சுருட்டுப் புழுவை கண்காணிக்கவும். வேப்ப எண்ணெய் கரைசல் தெளிக்கவும்.\n• சிறுதானியங்கள் மற்றும் மக்காச்சோளம்: குறைந்த நீரில் அதிக மகசூல் தரும். நீர் தேங்காமல் பார்த்துக் கொள்ளவும்.\n• பருத்தி: வெள்ளை ஈக்களை கட்டுப்படுத்த ஏக்கருக்கு 5-6 மஞ்சள் நிற ஒட்டும் பொறிகளை வைக்கவும்.\n• பயறு வகைகள்: விதைப்பதற்கு முன் ரைசோபியம் கொண்டு விதை நேர்த்தி செய்யவும்.\n• கிசான் கால் சென்டர்: 1800-180-1551 (காலை 6 முதல் இரவு 10 வரை).',
        lastUpdated: now,
      ),
      ResourceModel(
        key: 'gov-services',
        category: 'government_service',
        icon: '📋',
        titleEn: 'Key Government Welfare Schemes & Offline Guide',
        titleTa: 'முக்கிய அரசு நலத்திட்டங்கள் மற்றும் ஆஃப்லைன் வழிகாட்டி',
        bodyEn: '• PM-KISAN: Rs 6,000 yearly in 3 installments for farmer families. Requires Aadhaar-linked bank account.\n• Ayushman Bharat (PM-JAY): Up to Rs 5 lakh annual cashless health cover per eligible family for secondary and tertiary hospitalization.\n• MGNREGA: 100 days guaranteed wage employment per financial year for rural households.\n• Jal Jeevan Mission: Functional household tap water connection for every rural home.\n• NSAP Social Pensions: Monthly pensions for elderly (IGNOAPS), widows (IGNWPS), and persons with disabilities (IGNDPS).',
        bodyTa: '• பிஎம்-கிசான்: விவசாய குடும்பங்களுக்கு ஆண்டுக்கு ரூ.6,000 மூன்று தவணைகளில்.\n• ஆயுஷ்மான் பாரத்: குடும்பத்திற்கு ஆண்டுக்கு ரூ.5 லட்சம் வரை இலவச மருத்துவ சிகிச்சை.\n• மகாத்மா காந்தி வேலை உறுதி (100 நாள் வேலை): கிராமப்புற குடும்பங்களுக்கு உத்தரவாதமான வேலை.\n• ஜல் ஜீவன் மிஷன்: அனைத்து கிராம வீடுகளுக்கும் குழாய் குடிநீர்.\n• தேசிய ஓய்வூதியம்: முதியோர், விதவைகள் மற்றும் மாற்றுத்திறனாளிகளுக்கான மாத ஓய்வூதியம்.',
        lastUpdated: now,
      ),
    ];

    for (final r in defaults) {
      await db.insert('resources', r.toMap());
    }

    // Default settings
    await db.insert('settings', {'key': 'allowRelay', 'val': 'true'});
    await db.insert('settings', {'key': 'maxHops', 'val': '3'});
    await db.insert('settings', {'key': 'lang', 'val': 'en'});
  }

  // ---------- Contacts CRUD ----------
  Future<List<ContactModel>> getContacts({String? query, String? category}) async {
    final db = await instance.database;
    String where = '1=1';
    List<dynamic> args = [];

    if (category != null && category != 'all') {
      where += ' AND category = ?';
      args.add(category);
    }
    if (query != null && query.trim().isNotEmpty) {
      where += ' AND (name LIKE ? OR phone LIKE ? OR note LIKE ?)';
      final q = '%${query.trim()}%';
      args.addAll([q, q, q]);
    }

    final result = await db.query('contacts', where: where, whereArgs: args, orderBy: 'priority DESC, name ASC');
    return result.map((m) => ContactModel.fromMap(m)).toList();
  }

  Future<void> saveContact(ContactModel contact) async {
    final db = await instance.database;
    await db.insert('contacts', contact.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> deleteContact(String id) async {
    final db = await instance.database;
    await db.delete('contacts', where: 'id = ?', whereArgs: [id]);
  }

  // ---------- Messages CRUD ----------
  Future<List<MessageModel>> getMessages() async {
    final db = await instance.database;
    final result = await db.query('messages', orderBy: 'createdAt DESC');
    return result.map((m) => MessageModel.fromMap(m)).toList();
  }

  Future<void> saveMessage(MessageModel msg) async {
    final db = await instance.database;
    await db.insert('messages', msg.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> updateMessageStatus(String id, String status, {int? deliveredAt, int? ackAt}) async {
    final db = await instance.database;
    final Map<String, dynamic> vals = {'status': status};
    if (deliveredAt != null) vals['deliveredAt'] = deliveredAt;
    if (ackAt != null) vals['ackAt'] = ackAt;
    await db.update('messages', vals, where: 'id = ?', whereArgs: [id]);
  }

  Future<void> deleteMessage(String id) async {
    final db = await instance.database;
    await db.delete('messages', where: 'id = ?', whereArgs: [id]);
  }

  // ---------- Resources CRUD ----------
  Future<List<ResourceModel>> getResources() async {
    final db = await instance.database;
    final result = await db.query('resources', orderBy: 'category ASC, key ASC');
    return result.map((m) => ResourceModel.fromMap(m)).toList();
  }

  Future<void> saveResource(ResourceModel r) async {
    final db = await instance.database;
    await db.insert('resources', r.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
  }

  // ---------- SOS CRUD ----------
  Future<List<SosRecord>> getSosRecords() async {
    final db = await instance.database;
    final result = await db.query('sos_records', orderBy: 'createdAt DESC');
    return result.map((m) => SosRecord.fromMap(m)).toList();
  }

  Future<void> saveSosRecord(SosRecord s) async {
    final db = await instance.database;
    await db.insert('sos_records', s.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> cancelSos(String id) async {
    final db = await instance.database;
    await db.update('sos_records', {'status': 'cancelled'}, where: 'id = ?', whereArgs: [id]);
  }

  // ---------- Settings ----------
  Future<String> getSetting(String key, {String defaultVal = ''}) async {
    final db = await instance.database;
    final res = await db.query('settings', where: 'key = ?', whereArgs: [key]);
    if (res.isNotEmpty) return res.first['val'] as String;
    return defaultVal;
  }

  Future<void> setSetting(String key, String val) async {
    final db = await instance.database;
    await db.insert('settings', {'key': key, 'val': val}, conflictAlgorithm: ConflictAlgorithm.replace);
  }
}
