import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class FarmerScreen extends StatelessWidget {
  final String lang;
  const FarmerScreen({super.key, required this.lang});

  Future<void> _call(String number) async {
    final clean = number.replaceAll(RegExp(r'[^+\d]'), '');
    final uri = Uri(scheme: 'tel', path: clean);
    if (await canLaunchUrl(uri)) await launchUrl(uri);
  }

  @override
  Widget build(BuildContext context) {
    final isTa = lang == 'ta';

    return Scaffold(
      appBar: AppBar(
        title: Text(isTa ? 'விவசாய சேவைகள்' : 'Farmer Support & Crop Care'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.amber.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.amber.shade300),
            ),
            child: Row(
              children: [
                const Icon(Icons.eco, color: Colors.green, size: 28),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    isTa
                        ? 'பயிர் பாதுகாப்பு வழிகாட்டிகள், பூச்சி மேலாண்மை மற்றும் கிசான் எண்கள் ஆஃப்லைனில் உள்ளன.'
                        : 'Offline crop advisories, organic pest control, and Kisan Call Centre numbers.',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                )
              ],
            ),
          ),
          const SizedBox(height: 16),
          Text(isTa ? 'விவசாய உதவி எண்கள்' : 'Agricultural Helplines', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 8),
          _helplineTile('1800-180-1551', isTa ? 'கிசான் கால் சென்டர் (காலை 6 - இரவு 10)' : 'Kisan Call Centre (Toll Free 6 AM - 10 PM)', Icons.headset_mic, Colors.green),
          _helplineTile('155261', isTa ? 'பிஎம்-கிசான் உதவி எண்' : 'PM-KISAN Scheme Helpline', Icons.account_balance, Colors.blue),
          const SizedBox(height: 16),
          Text(isTa ? 'பருவமழை பயிர் வழிகாட்டிகள்' : 'Seasonal Crop Guidelines', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 8),
          _cropCard(
            isTa ? 'கரீஃப் (பருவமழை) பயிர்கள்' : 'Kharif (Monsoon) Crops',
            isTa ? 'விதைப்பு ஜூன்-ஜூலை; அறுவடை செப்டம்பர்-அக்டோபர். நெல், மக்காச்சோளம், சிறுதானியங்கள், பருத்தி.' : 'Sown June–July, harvested Sept–Oct: Rice, maize, millets (jowar, bajra, ragi), cotton, groundnut.',
            '🌧️',
          ),
          _cropCard(
            isTa ? 'ராபி (குளிர்கால) பயிர்கள்' : 'Rabi (Winter) Crops',
            isTa ? 'விதைப்பு அக்டோபர்-டிசம்பர்; அறுவடை மார்ச்-ஏப்ரல். கோதுமை, பார்லி, கடுகு, கொண்டைக்கடலை.' : 'Sown Oct–Dec, harvested March–April: Wheat, barley, mustard, gram (chana), peas.',
            '❄️',
          ),
          _cropCard(
            isTa ? 'பூச்சி மேலாண்மை & மண் பரிசோதனை' : 'Pest Management & Soil Testing',
            isTa ? 'வேப்ப எண்ணெய் கரைசல் மற்றும் மஞ்சள் ஒட்டும் பொறிகளைப் பயன்படுத்தவும். 2 ஆண்டுகளுக்கு ஒருமுறை மண் பரிசோதனை செய்யவும்.' : 'Inspect undersides of leaves. Install yellow sticky traps for aphids. Test soil every 2 years before urea application.',
            '🧪',
          ),
        ],
      ),
    );
  }

  Widget _helplineTile(String num, String desc, IconData icon, Color color) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(backgroundColor: color.withValues(alpha: 0.15), child: Icon(icon, color: color)),
        title: Text(num, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        subtitle: Text(desc, style: const TextStyle(fontSize: 12)),
        trailing: ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: color, foregroundColor: Colors.white),
          onPressed: () => _call(num),
          child: const Text('Call'),
        ),
      ),
    );
  }

  Widget _cropCard(String title, String desc, String icon) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(icon, style: const TextStyle(fontSize: 24)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  const SizedBox(height: 4),
                  Text(desc, style: TextStyle(color: Colors.grey.shade700, fontSize: 12, height: 1.4)),
                ],
              ),
            )
          ],
        ),
      ),
    );
  }
}
