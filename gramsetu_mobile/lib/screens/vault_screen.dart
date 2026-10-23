import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../database/vault_database.dart';
import '../models/models.dart';
import '../transport/transport_manager.dart';

class VaultScreen extends StatefulWidget {
  final String lang;
  const VaultScreen({super.key, required this.lang});

  @override
  State<VaultScreen> createState() => _VaultScreenState();
}

class _VaultScreenState extends State<VaultScreen> {
  List<ResourceModel> resources = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadResources();
  }

  Future<void> _loadResources() async {
    setState(() => isLoading = true);
    final data = await VaultDatabase.instance.getResources();
    setState(() {
      resources = data;
      isLoading = false;
    });
  }

  String _formatDate(int ms) {
    if (ms == 0) return '—';
    final dt = DateTime.fromMillisecondsSinceEpoch(ms);
    return DateFormat('dd MMM yyyy, hh:mm a').format(dt);
  }

  @override
  Widget build(BuildContext context) {
    final isTa = widget.lang == 'ta';

    return Scaffold(
      appBar: AppBar(
        title: Text(isTa ? 'ஆஃப்லைன் பெட்டகம்' : 'Offline Vault'),
        actions: [
          IconButton(
            icon: const Icon(Icons.sync),
            tooltip: isTa ? 'புதுப்பிக்கவும்' : 'Refresh / Download',
            onPressed: () async {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(isTa ? 'வழிகாட்டிகள் புதுப்பிக்கப்படுகின்றன...' : 'Refreshing offline vault...')),
              );
              await TransportManager.instance.syncWithServer();
              await _loadResources();
            },
          )
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.teal.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.teal.shade200),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.download_done, color: Colors.teal, size: 32),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              isTa ? 'அனைத்து வழிகாட்டிகளும் பதிவிறக்கம் செய்யப்பட்டன' : 'All Guides Downloaded for Offline Use',
                              style: TextStyle(color: Colors.teal.shade900, fontWeight: FontWeight.bold, fontSize: 14),
                            ),
                            Text(
                              isTa ? 'இணையம் முற்றிலும் இல்லாவிட்டாலும் திறக்கலாம்.' : 'Instant opening without mobile network or Wi-Fi.',
                              style: TextStyle(color: Colors.teal.shade700, fontSize: 12),
                            ),
                          ],
                        ),
                      )
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  isTa ? 'சேமிக்கப்பட்ட வழிகாட்டிகள் (${resources.length})' : 'Saved Resources (${resources.length})',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                ...resources.map((r) => _resourceCard(context, r, isTa)),
              ],
            ),
    );
  }

  Widget _resourceCard(BuildContext context, ResourceModel r, bool isTa) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ExpansionTile(
        leading: CircleAvatar(
          backgroundColor: Colors.teal.shade100,
          child: Text(r.icon, style: const TextStyle(fontSize: 20)),
        ),
        title: Text(
          r.title(widget.lang),
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
        ),
        subtitle: Row(
          children: [
            Container(
              margin: const EdgeInsets.only(top: 4),
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: Colors.green.shade300),
              ),
              child: Text(
                isTa ? 'ஆஃப்லைனில் உள்ளது ✓' : 'Downloaded Offline ✓',
                style: const TextStyle(color: Colors.green, fontSize: 10, fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(width: 8),
            Text(_formatDate(r.lastUpdated), style: const TextStyle(fontSize: 11, color: Colors.grey)),
          ],
        ),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Text(
              r.body(widget.lang),
              style: const TextStyle(fontSize: 13, height: 1.5),
            ),
          )
        ],
      ),
    );
  }
}
