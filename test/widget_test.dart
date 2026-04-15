// test/widget_test.dart
//
// Smoke test CI — vérifie que l'app se construit et affiche le premier widget
// sans déclencher Firebase, Supabase, SharedPreferences ni aucun plugin natif.
//
// Stratégie :
//   • On instancie CongressOranApp(isTest: true) directement,
//     ce qui court-circuite Supabase.initialize() et Firebase.initializeApp().
//   • AuthProvider.stub() évite tout appel à FirebaseAuth.instance.
//   • GoRouter de test pointe sur '/test' → Scaffold simple.

import 'package:congres/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

void main() {
  testWidgets('Smoke test — app démarre sans crash', (WidgetTester tester) async {
    // On n'appelle PAS main() pour ne pas déclencher Supabase.initialize().
    // On monte directement le widget en mode test.
    await tester.pumpWidget(const CongressOranApp(isTest: true));

    // Laisse Flutter résoudre les frames et les futures synchrones.
    await tester.pump();

    // Vérifie qu'un Scaffold est bien rendu (la route /test l'affiche).
    expect(find.byType(Scaffold), findsOneWidget);

    // Vérifie le texte attendu dans la route de test.
    expect(find.text('Test OK'), findsOneWidget);
  });
}