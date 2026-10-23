import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class HealthScreen extends StatelessWidget {
  final String lang;
  const HealthScreen({super.key, required this.lang});

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
        title: Text(isTa ? 'மருத்துவ சேவைகள்' : 'Healthcare Services & Facilities'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.green.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.green.shade200),
            ),
            child: Row(
              children: [
                const Icon(Icons.verified_user, color: Colors.green, size: 28),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    isTa
                        ? 'கிராம ஆரம்ப சுகாதார நிலையத் தகவல்கள் மற்றும் அவசர ஆம்புலன்ஸ் எண்கள் ஆஃப்லைனில் உள்ளன.'
                        : 'Offline village health directory, PHC/CHC contacts, and emergency ambulance helplines.',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                )
              ],
            ),
          ),
          const SizedBox(height: 16),
          Text(isTa ? 'அவசர ஆம்புலன்ஸ் எண்கள்' : 'Emergency Helplines', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 8),
          _helplineTile('108', isTa ? 'அவசர ஆம்புலன்ஸ் (அனைத்து அவசரநிலைகள்)' : 'Ambulance (All Emergencies 24/7)', Icons.medical_services, Colors.red),
          _helplineTile('102', isTa ? 'தாய்-சேய் ஆம்புலன்ஸ் (கர்ப்பிணிகள்/குழந்தைகள்)' : 'Maternal & Child Ambulance (Free)', Icons.pregnant_woman, Colors.pink),
          _helplineTile('112', isTa ? 'தேசிய அவசர உதவி எண்' : 'National Emergency Unified Line', Icons.shield, Colors.blue),
          _helplineTile('14555', isTa ? 'ஆயுஷ்மான் பாரத் உதவி எண்' : 'Ayushman Bharat PM-JAY Helpline', Icons.credit_card, Colors.teal),
          const SizedBox(height: 16),
          Text(isTa ? 'கிராம சுகாதார நிலையங்கள்' : 'Village Health Facilities', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 8),
          _facilityCard(
            isTa ? 'ஆரம்ப சுகாதார துணை நிலையம் (Sub-Centre)' : 'Health Sub-Centre',
            isTa ? 'திங்கள்-சனி காலை 9 - மாலை 4 வரை. ஏஎன்எம் செவிலியர் மற்றும் ஆஷா பணியாளர்.' : 'First point of care in village: ANM nurse, vaccination, mother and child care.',
            '🏥',
          ),
          _facilityCard(
            isTa ? 'ஆரம்ப சுகாதார நிலையம் (PHC)' : 'Primary Health Centre (PHC)',
            isTa ? '24 மணி நேரமும் செயல்படுகிறது. அவசர சிகிச்சை, பிரசவம் மற்றும் மருத்துவர்.' : 'Open 24/7 for emergency delivery & doctor consultation.',
            '🏨',
          ),
          _facilityCard(
            isTa ? 'சமூக சுகாதார மையம் (CHC)' : 'Community Health Centre (CHC)',
            isTa ? '30 படுக்கைகள் கொண்ட மருத்துவமனை; அறுவை சிகிச்சை மற்றும் குழந்தை மருத்துவர்.' : '30-bed hospital with surgeon, physician, gynecologist, and pediatric care.',
            '🏢',
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
        title: Text(num, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        subtitle: Text(desc, style: const TextStyle(fontSize: 12)),
        trailing: ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: color, foregroundColor: Colors.white),
          onPressed: () => _call(num),
          child: const Text('Call'),
        ),
      ),
    );
  }

  Widget _facilityCard(String title, String desc, String icon) {
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
                  Text(desc, style: TextStyle(color: Colors.grey.shade700, fontSize: 12)),
                ],
              ),
            )
          ],
        ),
      ),
    );
  }
}
