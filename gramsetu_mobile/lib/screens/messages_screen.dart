import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import '../database/vault_database.dart';
import '../models/models.dart';
import '../transport/transport_manager.dart';

class MessagesScreen extends StatefulWidget {
  final String lang;
  final String? initialToId;
  final String? initialToName;

  const MessagesScreen({
    super.key,
    required this.lang,
    this.initialToId,
    this.initialToName,
  });

  @override
  State<MessagesScreen> createState() => _MessagesScreenState();
}

class _MessagesScreenState extends State<MessagesScreen> {
  List<MessageModel> messages = [];
  List<ContactModel> contacts = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
    if (widget.initialToId != null && widget.initialToName != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _showComposeDialog(toId: widget.initialToId, toName: widget.initialToName);
      });
    }
  }

  Future<void> _loadData() async {
    setState(() => isLoading = true);
    final msgs = await VaultDatabase.instance.getMessages();
    final cts = await VaultDatabase.instance.getContacts();
    setState(() {
      messages = msgs;
      contacts = cts;
      isLoading = false;
    });
  }

  void _showComposeDialog({String? toId, String? toName}) {
    String selectedToId = toId ?? (contacts.isNotEmpty ? contacts.first.id : '');
    String selectedToName = toName ?? (contacts.isNotEmpty ? contacts.first.name : '');
    final bodyCtrl = TextEditingController();
    final isTa = widget.lang == 'ta';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
            left: 16,
            right: 16,
            top: 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                isTa ? 'செய்தி எழுதவும் (Offline Outbox)' : 'Write Offline Message',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              if (contacts.isEmpty)
                Text(
                  isTa ? 'முதலில் கிராம தொடர்பைச் சேர்க்கவும்.' : 'Please add a contact first in My Village Contacts.',
                  style: const TextStyle(color: Colors.red),
                )
              else
                DropdownButtonFormField<String>(
                  initialValue: selectedToId.isEmpty ? null : selectedToId,
                  decoration: InputDecoration(
                    labelText: isTa ? 'பெறுநர் *' : 'Recipient *',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  items: contacts.map((c) => DropdownMenuItem(
                    value: c.id,
                    child: Text('${c.name} (${c.category})'),
                  )).toList(),
                  onChanged: (val) {
                    if (val != null) {
                      final c = contacts.firstWhere((x) => x.id == val);
                      setModalState(() {
                        selectedToId = c.id;
                        selectedToName = c.name;
                      });
                    }
                  },
                ),
              const SizedBox(height: 12),
              TextField(
                controller: bodyCtrl,
                maxLines: 4,
                decoration: InputDecoration(
                  labelText: isTa ? 'செய்தி *' : 'Message Body *',
                  hintText: isTa ? 'செய்தியை இங்கே எழுதவும்...' : 'Type your message...',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size.fromHeight(48),
                  backgroundColor: const Color(0xFF1E3A8A),
                  foregroundColor: Colors.white,
                ),
                onPressed: () async {
                  final body = bodyCtrl.text.trim();
                  if (body.isEmpty || selectedToId.isEmpty) return;

                  final newMsg = MessageModel(
                    id: 'msg-${const Uuid().v4()}',
                    toId: selectedToId,
                    toName: selectedToName,
                    body: body,
                    status: 'local',
                    transport: 'backend',
                    createdAt: DateTime.now().millisecondsSinceEpoch,
                  );

                  await VaultDatabase.instance.saveMessage(newMsg);
                  if (ctx.mounted) {
                    Navigator.pop(ctx);
                  }
                  _loadData();

                  // Attempt transmission
                  TransportManager.instance.sendNearbyPacket(newMsg);
                },
                icon: const Icon(Icons.send),
                label: Text(isTa ? 'அவுட்பாக்ஸில் சேமித்து அனுப்புக' : 'Save to Outbox & Send'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _statusPill(String status, int hopCount, bool isTa) {
    Color bg = Colors.grey.shade200;
    Color fg = Colors.grey.shade800;
    String label = status;

    switch (status) {
      case 'local':
        bg = Colors.red.shade50;
        fg = Colors.red.shade800;
        label = isTa ? '📱 போனில் சேமிக்கப்பட்டது (அவுட்பாக்ஸ்)' : '📱 Saved locally · Outbox';
        break;
      case 'queued':
        bg = Colors.amber.shade50;
        fg = Colors.amber.shade900;
        label = isTa ? '⏳ சிங்கிங்கிற்காக காத்திருக்கிறது' : '⏳ Queued to sync';
        break;
      case 'sending':
        bg = Colors.blue.shade50;
        fg = Colors.blue.shade800;
        label = isTa ? '🔄 அனுப்பப்படுகிறது...' : '🔄 Sending...';
        break;
      case 'delivered_device':
        bg = Colors.green.shade50;
        fg = Colors.green.shade800;
        label = isTa ? '🟢 சாதனத்திற்கு சென்றடைந்தது' : '🟢 Delivered to device';
        break;
      case 'relayed':
        bg = Colors.purple.shade50;
        fg = Colors.purple.shade800;
        label = isTa ? '🔁 தொடர் தடம் ($hopCount)' : '🔁 Relayed (Hop $hopCount)';
        break;
      case 'acknowledged':
        bg = Colors.teal.shade50;
        fg = Colors.teal.shade800;
        label = isTa ? '✓ உறுதி செய்யப்பட்டது' : '✓ Acknowledged';
        break;
      case 'failed':
        bg = Colors.red.shade100;
        fg = Colors.red.shade900;
        label = isTa ? '⚠️ தோல்வி' : '⚠️ Delivery failed';
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(12)),
      child: Text(label, style: TextStyle(color: fg, fontSize: 11, fontWeight: FontWeight.bold)),
    );
  }

  String _formatDate(int ms) {
    final dt = DateTime.fromMillisecondsSinceEpoch(ms);
    return DateFormat('dd MMM, hh:mm a').format(dt);
  }

  @override
  Widget build(BuildContext context) {
    final isTa = widget.lang == 'ta';

    return Scaffold(
      appBar: AppBar(
        title: Text(isTa ? 'செய்தி அவுட்பாக்ஸ்' : 'Offline Messages & Outbox'),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            tooltip: isTa ? 'செய்தி எழுது' : 'Compose Message',
            onPressed: () => _showComposeDialog(),
          )
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : messages.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.mark_chat_unread_outlined, size: 48, color: Colors.grey),
                      const SizedBox(height: 12),
                      Text(
                        isTa ? 'அவுட்பாக்ஸ் காலியாக உள்ளது.' : 'Your offline outbox is empty.',
                        style: const TextStyle(color: Colors.grey),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        onPressed: () => _showComposeDialog(),
                        icon: const Icon(Icons.edit),
                        label: Text(isTa ? 'செய்தி எழுதுங்கள்' : 'Compose Message'),
                      )
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: messages.length,
                  itemBuilder: (ctx, i) {
                    final m = messages[i];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                CircleAvatar(
                                  backgroundColor: Colors.blue.shade100,
                                  child: const Icon(Icons.chat_bubble, size: 18, color: Colors.blue),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    '${isTa ? "பெறுநர்:" : "To:"} ${m.toName}',
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                                  ),
                                ),
                                _statusPill(m.status, m.hopCount, isTa),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Text(m.body, style: const TextStyle(fontSize: 14)),
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                Text(_formatDate(m.createdAt), style: const TextStyle(color: Colors.grey, fontSize: 11)),
                                const Spacer(),
                                TextButton.icon(
                                  onPressed: () async {
                                    await TransportManager.instance.sendNearbyPacket(m);
                                    _loadData();
                                  },
                                  icon: const Icon(Icons.refresh, size: 14),
                                  label: Text(isTa ? 'மீண்டும் முயற்சி' : 'Retry'),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete_outline, size: 18, color: Colors.grey),
                                  onPressed: () async {
                                    await VaultDatabase.instance.deleteMessage(m.id);
                                    _loadData();
                                  },
                                )
                              ],
                            )
                          ],
                        ),
                      ),
                    );
                  },
                ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showComposeDialog(),
        child: const Icon(Icons.edit),
      ),
    );
  }
}
