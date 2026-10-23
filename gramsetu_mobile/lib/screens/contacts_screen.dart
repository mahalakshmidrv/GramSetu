import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:uuid/uuid.dart';
import '../database/vault_database.dart';
import '../models/models.dart';

class ContactsScreen extends StatefulWidget {
  final String lang;
  final Function(String toId, String toName)? onMessage;

  const ContactsScreen({super.key, required this.lang, this.onMessage});

  @override
  State<ContactsScreen> createState() => _ContactsScreenState();
}

class _ContactsScreenState extends State<ContactsScreen> {
  List<ContactModel> contacts = [];
  String selectedCategory = 'all';
  String searchQuery = '';
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadContacts();
  }

  Future<void> _loadContacts() async {
    setState(() => isLoading = true);
    final data = await VaultDatabase.instance.getContacts(
      query: searchQuery,
      category: selectedCategory,
    );
    setState(() {
      contacts = data;
      isLoading = false;
    });
  }

  Future<void> _makePhoneCall(String phoneNumber) async {
    if (phoneNumber.isEmpty) return;
    final clean = phoneNumber.replaceAll(RegExp(r'[^+\d]'), '');
    final uri = Uri(scheme: 'tel', path: clean);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open phone dialer.')),
        );
      }
    }
  }

  void _showAddContactDialog() {
    final nameCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    final noteCtrl = TextEditingController();
    String category = 'neighbour';
    bool isPriority = false;
    final isTa = widget.lang == 'ta';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text(isTa ? 'புதிய தொடர்பு சேர்க்க' : 'Add Village Contact'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameCtrl,
                  decoration: InputDecoration(
                    labelText: isTa ? 'பெயர் *' : 'Name *',
                    hintText: isTa ? 'எ.கா. ரமேஷ் குமார்' : 'e.g. Ramesh Kumar',
                  ),
                ),
                TextField(
                  controller: phoneCtrl,
                  keyboardType: TextInputType.phone,
                  decoration: InputDecoration(
                    labelText: isTa ? 'தொலைபேசி எண்' : 'Phone Number',
                    hintText: '+91 98765 43210',
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: category,
                  decoration: InputDecoration(labelText: isTa ? 'வகை' : 'Category'),
                  items: [
                    DropdownMenuItem(value: 'neighbour', child: Text(isTa ? 'அண்டை வீட்டார்' : 'Neighbour')),
                    DropdownMenuItem(value: 'health_worker', child: Text(isTa ? 'சுகாதாரப் பணியாளர் (ASHA/Doctor)' : 'Health Worker (ASHA/Doctor)')),
                    DropdownMenuItem(value: 'farmer', child: Text(isTa ? 'விவசாயி' : 'Farmer')),
                    DropdownMenuItem(value: 'family', child: Text(isTa ? 'குடும்ப உறுப்பினர்' : 'Family Member')),
                    DropdownMenuItem(value: 'emergency', child: Text(isTa ? 'அவசர உதவியாளர்' : 'Emergency Responder')),
                  ],
                  onChanged: (val) => setDialogState(() => category = val ?? 'neighbour'),
                ),
                TextField(
                  controller: noteCtrl,
                  decoration: InputDecoration(
                    labelText: isTa ? 'இருப்பிடம் / குறிப்பு' : 'House / Location Note',
                    hintText: isTa ? 'எ.கா. தெற்கு கிணறு அருகே' : 'e.g. Near South Well',
                  ),
                ),
                CheckboxListTile(
                  title: Text(
                    isTa ? '⭐ அவசர முன்னுரிமை 1' : '⭐ Emergency Priority 1',
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                  ),
                  value: isPriority,
                  onChanged: (val) => setDialogState(() => isPriority = val ?? false),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(isTa ? 'ரத்து' : 'Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                final name = nameCtrl.text.trim();
                if (name.isEmpty) return;
                final now = DateTime.now().millisecondsSinceEpoch;
                final newContact = ContactModel(
                  id: 'c-${const Uuid().v4()}',
                  name: name,
                  phone: phoneCtrl.text.trim(),
                  category: category,
                  note: noteCtrl.text.trim(),
                  priority: isPriority ? 1 : 0,
                  trusted: true,
                  createdAt: now,
                  updatedAt: now,
                );
                await VaultDatabase.instance.saveContact(newContact);
                if (ctx.mounted) {
                  Navigator.pop(ctx);
                }
                _loadContacts();
              },
              child: Text(isTa ? 'சேமி' : 'Save'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isTa = widget.lang == 'ta';

    return Scaffold(
      appBar: AppBar(
        title: Text(isTa ? 'கிராம தொடர்புகள்' : 'My Village Contacts'),
        actions: [
          IconButton(
            icon: const Icon(Icons.person_add),
            tooltip: isTa ? 'தொடர்பு சேர்' : 'Add Contact',
            onPressed: _showAddContactDialog,
          )
        ],
      ),
      body: Column(
        children: [
          // Search Bar
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: TextField(
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.search),
                hintText: isTa ? 'பெயர் அல்லது இருப்பிடம் தேடவும்...' : 'Search by name, phone or landmark...',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              ),
              onChanged: (val) {
                searchQuery = val;
                _loadContacts();
              },
            ),
          ),

          // Category Chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Row(
              children: [
                _chip('all', isTa ? 'அனைத்தும்' : 'All'),
                _chip('neighbour', isTa ? 'அண்டை வீட்டார்' : 'Neighbours'),
                _chip('health_worker', isTa ? 'மருத்துவ பணியாளர்' : 'Health Workers'),
                _chip('farmer', isTa ? 'விவசாயிகள்' : 'Farmers'),
                _chip('family', isTa ? 'குடும்பம்' : 'Family'),
                _chip('emergency', isTa ? 'அவசரம்' : 'Emergency'),
              ],
            ),
          ),
          const Divider(),

          // Contacts List
          Expanded(
            child: isLoading
                ? const Center(child: CircularProgressIndicator())
                : contacts.isEmpty
                    ? Center(
                        child: Text(
                          isTa ? 'தொடர்புகள் எதுவும் இல்லை. சேர்க்கவும்.' : 'No contacts found. Tap + to add.',
                          style: const TextStyle(color: Colors.grey),
                        ),
                      )
                    : ListView.builder(
                        itemCount: contacts.length,
                        padding: const EdgeInsets.all(12),
                        itemBuilder: (ctx, i) => _contactCard(contacts[i], isTa),
                      ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddContactDialog,
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _chip(String cat, String label) {
    final selected = selectedCategory == cat;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        selected: selected,
        label: Text(label),
        onSelected: (_) {
          setState(() => selectedCategory = cat);
          _loadContacts();
        },
      ),
    );
  }

  Widget _contactCard(ContactModel c, bool isTa) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: c.priority == 1 ? const BorderSide(color: Colors.amber, width: 2) : BorderSide.none,
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: c.priority == 1 ? Colors.amber.shade100 : Colors.blue.shade100,
                  child: Text(c.priority == 1 ? '⭐' : '👤'),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        c.name,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      Text(
                        c.category.toUpperCase(),
                        style: TextStyle(color: Colors.grey.shade600, fontSize: 11, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.green.shade300),
                  ),
                  child: const Text('Offline ✓', style: TextStyle(color: Colors.green, fontSize: 10, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
            if (c.phone.isNotEmpty) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.phone, size: 16, color: Colors.grey),
                  const SizedBox(width: 6),
                  Text(c.phone, style: const TextStyle(fontWeight: FontWeight.w600)),
                ],
              ),
            ],
            if (c.note.isNotEmpty) ...[
              const SizedBox(height: 4),
              Row(
                children: [
                  const Icon(Icons.location_on, size: 16, color: Colors.grey),
                  const SizedBox(width: 6),
                  Expanded(child: Text(c.note, style: TextStyle(color: Colors.grey.shade700, fontSize: 13))),
                ],
              ),
            ],
            const SizedBox(height: 12),
            Row(
              children: [
                if (c.phone.isNotEmpty)
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green.shade700,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                    onPressed: () => _makePhoneCall(c.phone),
                    icon: const Icon(Icons.call, size: 16),
                    label: Text(isTa ? 'அழைக்கவும்' : 'Call'),
                  ),
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  onPressed: () {
                    if (widget.onMessage != null) {
                      widget.onMessage!(c.id, c.name);
                    }
                  },
                  icon: const Icon(Icons.chat_bubble_outline, size: 16),
                  label: Text(isTa ? 'செய்தி' : 'Message'),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.delete_outline, color: Colors.grey),
                  onPressed: () async {
                    await VaultDatabase.instance.deleteContact(c.id);
                    _loadContacts();
                  },
                ),
              ],
            )
          ],
        ),
      ),
    );
  }
}
