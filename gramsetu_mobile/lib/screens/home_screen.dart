import 'package:flutter/material.dart';
import '../database/vault_database.dart';

class HomeScreen extends StatefulWidget {
  final Function(int) onNavigate;
  final String lang;

  const HomeScreen({super.key, required this.onNavigate, required this.lang});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int contactCount = 0;
  int resourceCount = 0;
  int messageCount = 0;
  bool isOnline = false;

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    final contacts = await VaultDatabase.instance.getContacts();
    final resources = await VaultDatabase.instance.getResources();
    final messages = await VaultDatabase.instance.getMessages();
    setState(() {
      contactCount = contacts.length;
      resourceCount = resources.length;
      messageCount = messages.length;
    });
  }

  @override
  Widget build(BuildContext context) {
    final isTa = widget.lang == 'ta';

    return Scaffold(
      appBar: AppBar(
        title: Text(isTa ? '🌾 கிராமசேது 2.0' : '🌾 GramSetu 2.0'),
        actions: [
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.green.shade100,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              children: [
                const Icon(Icons.download_done, color: Colors.green, size: 16),
                const SizedBox(width: 4),
                Text(
                  isTa ? 'ஆஃப்லைன் தயார்' : 'Offline Vault Ready',
                  style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 12),
                ),
              ],
            ),
          )
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadStats,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Hero / Vision Card
            Card(
              color: const Color(0xFF1E3A8A),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isTa ? 'கிராமப்புற அத்தியாவசிய சேவைகள்' : 'Offline-First Village Network',
                      style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      isTa
                          ? 'இணையம் இல்லாவிட்டாலும் அவசர உதவி, கிராம தொடர்புகள், மற்றும் மருத்துவ வழிகாட்டிகள் எப்போதும் கிடைக்கும்.'
                          : 'Spotify-inspired offline access for village emergency contacts, health centres, crop care guides, and neighbour messaging.',
                      style: const TextStyle(color: Colors.white70, fontSize: 14),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red.shade600,
                            foregroundColor: Colors.white,
                          ),
                          onPressed: () => widget.onNavigate(5), // Navigate to SOS
                          icon: const Icon(Icons.emergency),
                          label: Text(isTa ? 'அவசர SOS' : 'Emergency SOS'),
                        ),
                        const SizedBox(width: 10),
                        OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(foregroundColor: Colors.white),
                          onPressed: () => widget.onNavigate(1), // Navigate to Vault
                          icon: const Icon(Icons.offline_pin),
                          label: Text(isTa ? 'பெட்டகம்' : 'Open Vault'),
                        ),
                      ],
                    )
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Quick Stats Row
            Row(
              children: [
                Expanded(
                  child: _statCard(
                    context,
                    title: isTa ? 'சேமிக்கப்பட்டவை' : 'Saved Guides',
                    count: '$resourceCount',
                    icon: Icons.offline_pin,
                    color: Colors.teal,
                    onTap: () => widget.onNavigate(1),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _statCard(
                    context,
                    title: isTa ? 'கிராம தொடர்புகள்' : 'Village Contacts',
                    count: '$contactCount',
                    icon: Icons.people,
                    color: Colors.indigo,
                    onTap: () => widget.onNavigate(2),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _statCard(
                    context,
                    title: isTa ? 'செய்திகள்' : 'Outbox',
                    count: '$messageCount',
                    icon: Icons.chat_bubble_outline,
                    color: Colors.orange,
                    onTap: () => widget.onNavigate(4),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Module Navigation Tiles
            Text(
              isTa ? 'அத்தியாவசிய சேவைகள்' : 'Essential Rural Modules',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            _serviceTile(
              context,
              title: isTa ? 'ஆஃப்லைன் பெட்டகம் (Offline Vault)' : 'GramSetu Offline Vault',
              subtitle: isTa ? 'பதிவிறக்கம் செய்த அவசர கையேடுகள் மற்றும் வழிகாட்டிகள்' : 'Spotify-style local health, farming, and emergency resources',
              icon: Icons.save_alt,
              color: Colors.teal,
              onTap: () => widget.onNavigate(1),
            ),
            _serviceTile(
              context,
              title: isTa ? 'கிராம தொடர்புகள் (My Village Contacts)' : 'My Village Contacts',
              subtitle: isTa ? 'அண்டை வீட்டார் மற்றும் அவசர உதவி எண்கள் நேரடி அழைப்பு' : 'Trusted neighbours, health workers & emergency phone calling',
              icon: Icons.contacts,
              color: Colors.blue,
              onTap: () => widget.onNavigate(2),
            ),
            _serviceTile(
              context,
              title: isTa ? 'அருகிலுள்ள இணைப்பு (Nearby Connect)' : 'Nearby Connect (Bluetooth / P2P)',
              subtitle: isTa ? 'இணையம் இல்லாமல் அருகிலுள்ள சாதனங்களுடன் செய்தி பரிமாற்றம்' : 'Direct zero-internet device discovery & encrypted transfer',
              icon: Icons.bluetooth_searching,
              color: Colors.deepPurple,
              onTap: () => widget.onNavigate(3),
            ),
            _serviceTile(
              context,
              title: isTa ? 'அவசர SOS (Emergency SOS)' : 'Emergency SOS & Assistance',
              subtitle: isTa ? 'உடனடி இருப்பிடம் மற்றும் உதவி எச்சரிக்கை பதிவு' : 'Rapid emergency dispatch, location broadcast & cancellation',
              icon: Icons.warning_amber_rounded,
              color: Colors.red,
              onTap: () => widget.onNavigate(5),
            ),
            _serviceTile(
              context,
              title: isTa ? 'மருத்துவ சேவைகள் (Healthcare)' : 'Healthcare & Medical Directory',
              subtitle: isTa ? 'ஆரம்ப சுகாதார நிலையங்கள் மற்றும் ஆம்புலன்ஸ் எண்கள்' : 'PHC/CHC directory, maternity care, and first-aid guide',
              icon: Icons.local_hospital,
              color: Colors.green,
              onTap: () => widget.onNavigate(6),
            ),
            _serviceTile(
              context,
              title: isTa ? 'விவசாய சேவைகள் (Farmer Support)' : 'Farmer Support & Crop Care',
              subtitle: isTa ? 'பயிர் பாதுகாப்பு மற்றும் கிசான் உதவி எண்கள்' : 'Pest management, seasonal crop care, and PM-KISAN help',
              icon: Icons.agriculture,
              color: Colors.amber.shade800,
              onTap: () => widget.onNavigate(7),
            ),
          ],
        ),
      ),
    );
  }

  Widget _statCard(
    BuildContext context, {
    required String title,
    required String count,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 26),
            const SizedBox(height: 6),
            Text(count, style: TextStyle(color: color, fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 2),
            Text(title, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600), textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }

  Widget _serviceTile(
    BuildContext context, {
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: color.withValues(alpha: 0.15),
          child: Icon(icon, color: color),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
        subtitle: Text(subtitle, style: const TextStyle(fontSize: 12)),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}
