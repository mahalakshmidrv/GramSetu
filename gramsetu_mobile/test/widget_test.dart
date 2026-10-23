import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gramsetu_mobile/screens/farmer_screen.dart';
import 'package:gramsetu_mobile/screens/health_screen.dart';

void main() {
  group('GramSetu 2.0 UI Smoke Tests', () {
    testWidgets('HealthScreen renders English healthcare directory and emergency helplines', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: HealthScreen(lang: 'en'),
        ),
      );

      expect(find.text('Healthcare Services & Facilities'), findsOneWidget);
      expect(find.text('Emergency Helplines'), findsOneWidget);
      expect(find.text('108'), findsOneWidget);
      expect(find.text('102'), findsOneWidget);
      expect(find.text('112'), findsOneWidget);
      expect(find.text('Ambulance (All Emergencies 24/7)'), findsOneWidget);
    });

    testWidgets('HealthScreen renders Tamil translations and services', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: HealthScreen(lang: 'ta'),
        ),
      );

      expect(find.text('மருத்துவ சேவைகள்'), findsOneWidget);
      expect(find.text('அவசர ஆம்புலன்ஸ் எண்கள்'), findsOneWidget);
      expect(find.text('108'), findsOneWidget);
      expect(find.text('அவசர ஆம்புலன்ஸ் (அனைத்து அவசரநிலைகள்)'), findsOneWidget);
    });

    testWidgets('FarmerScreen renders crop care guides and Kisan helpline', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: FarmerScreen(lang: 'en'),
        ),
      );

      expect(find.text('Farmer Support & Crop Care'), findsOneWidget);
      expect(find.text('Agricultural Helplines'), findsOneWidget);
      expect(find.text('1800-180-1551'), findsOneWidget);
      expect(find.text('Kisan Call Centre (Toll Free 6 AM - 10 PM)'), findsOneWidget);
      expect(find.text('Kharif (Monsoon) Crops'), findsOneWidget);
    });
  });
}
