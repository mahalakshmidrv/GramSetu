import 'package:flutter/material.dart';
import 'database/vault_database.dart';
import 'screens/contacts_screen.dart';
import 'screens/farmer_screen.dart';
import 'screens/health_screen.dart';
import 'screens/home_screen.dart';
import 'screens/messages_screen.dart';
import 'screens/nearby_screen.dart';
import 'screens/sos_screen.dart';
import 'screens/sync_screen.dart';
import 'screens/vault_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const GramSetuApp());
}

class GramSetuApp extends StatefulWidget {
  const GramSetuApp({super.key});

  @override
  State<GramSetuApp> createState() => _GramSetuAppState();
}

class _GramSetuAppState extends State<GramSetuApp> {
  String _lang = 'en';

  @override
  void initState() {
    super.initState();
    _loadLang();
  }

  Future<void> _loadLang() async {
    final saved = await VaultDatabase.instance.getSetting('lang', defaultVal: 'en');
    setState(() {
      _lang = saved;
    });
  }

  Future<void> _setLang(String newLang) async {
    await VaultDatabase.instance.setSetting('lang', newLang);
    setState(() {
      _lang = newLang;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'GramSetu 2.0',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF1E3A8A), // High contrast deep blue
          primary: const Color(0xFF1E3A8A),
          secondary: const Color(0xFF0D9488), // High visibility teal
        ),
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFFF8FAFC),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF1E3A8A),
          foregroundColor: Colors.white,
          elevation: 2,
          centerTitle: false,
        ),
        bottomNavigationBarTheme: const BottomNavigationBarThemeData(
          selectedItemColor: Color(0xFF1E3A8A),
          unselectedItemColor: Colors.black54,
          showUnselectedLabels: true,
          type: BottomNavigationBarType.fixed,
        ),
      ),
      home: MainShell(
        lang: _lang,
        onLanguageChanged: _setLang,
      ),
    );
  }
}

class MainShell extends StatefulWidget {
  final String lang;
  final Function(String) onLanguageChanged;

  const MainShell({
    super.key,
    required this.lang,
    required this.onLanguageChanged,
  });

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _currentIndex = 0;
  String? _targetMessageId;
  String? _targetMessageName;

  void _navigateTo(int index) {
    setState(() {
      _currentIndex = index;
    });
  }

  void _startDirectMessage(String toId, String toName) {
    setState(() {
      _targetMessageId = toId;
      _targetMessageName = toName;
      _currentIndex = 4; // Messages tab
    });
  }

  @override
  Widget build(BuildContext context) {
    final isTa = widget.lang == 'ta';

    // 0: Home, 1: Vault, 2: Contacts, 3: Nearby, 4: Messages, 5: SOS, 6: Health, 7: Farmer, 8: Sync
    final List<Widget> screens = [
      HomeScreen(
        lang: widget.lang,
        onNavigate: _navigateTo,
      ),
      VaultScreen(lang: widget.lang),
      ContactsScreen(
        lang: widget.lang,
        onMessage: (toId, toName) => _startDirectMessage(toId, toName),
      ),
      NearbyScreen(
        lang: widget.lang,
        onDirectMessage: (peerId, peerName) => _startDirectMessage(peerId, peerName),
      ),
      MessagesScreen(
        lang: widget.lang,
        initialToId: _targetMessageId,
        initialToName: _targetMessageName,
      ),
      SosScreen(lang: widget.lang),
      HealthScreen(lang: widget.lang),
      FarmerScreen(lang: widget.lang),
      SyncScreen(
        lang: widget.lang,
        onLanguageChanged: widget.onLanguageChanged,
      ),
    ];

    // Navigation titles for drawer
    final List<Map<String, dynamic>> menuItems = [
      {'title': isTa ? 'முகப்பு' : 'Home', 'icon': Icons.home, 'index': 0},
      {'title': isTa ? 'ஆஃப்லைன் பெட்டகம்' : 'Offline Vault', 'icon': Icons.offline_pin, 'index': 1},
      {'title': isTa ? 'கிராம தொடர்புகள்' : 'Village Contacts', 'icon': Icons.contacts, 'index': 2},
      {'title': isTa ? 'அருகிலுள்ள இணைப்பு (P2P)' : 'Nearby Connect (P2P)', 'icon': Icons.bluetooth_searching, 'index': 3},
      {'title': isTa ? 'அவுட்பாக்ஸ் செய்திகள்' : 'Outbox Messages', 'icon': Icons.chat_bubble_outline, 'index': 4},
      {'title': isTa ? 'அவசர SOS' : 'Emergency SOS', 'icon': Icons.warning_amber_rounded, 'index': 5},
      {'title': isTa ? 'மருத்துவ சேவைகள்' : 'Healthcare Services', 'icon': Icons.local_hospital, 'index': 6},
      {'title': isTa ? 'விவசாய சேவைகள்' : 'Farmer Support', 'icon': Icons.agriculture, 'index': 7},
      {'title': isTa ? 'ஒத்திசைவு & அமைப்புகள்' : 'Sync & Settings', 'icon': Icons.sync, 'index': 8},
    ];

    return Scaffold(
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            DrawerHeader(
              decoration: const BoxDecoration(
                color: Color(0xFF1E3A8A),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Row(
                    children: [
                      Text('🌾', style: TextStyle(fontSize: 28)),
                      SizedBox(width: 10),
                      Text(
                        'GramSetu 2.0',
                        style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    isTa ? 'ஆஃப்லைன் கிராமப்புற தகவல் தொடர்பு' : 'Offline-First Village Communication',
                    style: const TextStyle(color: Colors.white70, fontSize: 13),
                  ),
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.white24,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      isTa ? 'ஆஃப்லைன் பயன்முறை தயார்' : 'Offline Vault Active',
                      style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),
            for (final item in menuItems)
              ListTile(
                leading: Icon(
                  item['icon'] as IconData,
                  color: _currentIndex == item['index'] ? const Color(0xFF1E3A8A) : Colors.black87,
                ),
                title: Text(
                  item['title'] as String,
                  style: TextStyle(
                    fontWeight: _currentIndex == item['index'] ? FontWeight.bold : FontWeight.normal,
                    color: _currentIndex == item['index'] ? const Color(0xFF1E3A8A) : Colors.black87,
                  ),
                ),
                selected: _currentIndex == item['index'],
                selectedTileColor: Colors.blue.shade50,
                onTap: () {
                  Navigator.pop(context);
                  _navigateTo(item['index'] as int);
                },
              ),
            const Divider(),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  const Icon(Icons.language, size: 20, color: Colors.grey),
                  const SizedBox(width: 8),
                  Text(
                    isTa ? 'மொழி / Language:' : 'Language:',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                  const Spacer(),
                  ChoiceChip(
                    label: const Text('EN'),
                    selected: !isTa,
                    onSelected: (val) {
                      if (val) widget.onLanguageChanged('en');
                    },
                  ),
                  const SizedBox(width: 6),
                  ChoiceChip(
                    label: const Text('தமிழ்'),
                    selected: isTa,
                    onSelected: (val) {
                      if (val) widget.onLanguageChanged('ta');
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      body: IndexedStack(
        index: _currentIndex,
        children: screens,
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex <= 4 ? _currentIndex : 0,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
            // Clear message prefill when explicitly clicking on tab
            if (index != 4) {
              _targetMessageId = null;
              _targetMessageName = null;
            }
          });
        },
        items: [
          BottomNavigationBarItem(
            icon: const Icon(Icons.home_outlined),
            activeIcon: const Icon(Icons.home),
            label: isTa ? 'முகப்பு' : 'Home',
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.offline_pin_outlined),
            activeIcon: const Icon(Icons.offline_pin),
            label: isTa ? 'பெட்டகம்' : 'Vault',
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.contacts_outlined),
            activeIcon: const Icon(Icons.contacts),
            label: isTa ? 'தொடர்புகள்' : 'Contacts',
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.bluetooth_searching),
            activeIcon: const Icon(Icons.bluetooth_connected),
            label: isTa ? 'அருகில்' : 'Nearby',
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.chat_bubble_outline),
            activeIcon: const Icon(Icons.chat_bubble),
            label: isTa ? 'செய்திகள்' : 'Outbox',
          ),
        ],
      ),
    );
  }
}
