import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:congres/main.dart';

void main() {
  setUpAll(() async {
    // Supabase doit être initialisé même en test (AuthProvider.stub() ne
    // l'appelle pas, mais AdminProvider/GuestProvider en auraient besoin
    // s'ils étaient instanciés — ici ils ne le sont pas en mode isTest).
    // On garde l'init pour éviter une erreur si Supabase.instance est
    // accédé indirectement.
    try {
      await Supabase.initialize(
        url: 'https://placeholder.supabase.co',
        anonKey: 'placeholder-anon-key',
      );
    } catch (_) {
      // Déjà initialisé dans un run précédent — ignoré.
    }
  });

  testWidgets('App loads', (tester) async {
    // isTest: true → pas d'init Firebase, AuthProvider.stub(), router minimal
    await tester.pumpWidget(const CongressOranApp(isTest: true));
    await tester.pump();

    expect(find.byType(CongressOranApp), findsOneWidget);
  });
}