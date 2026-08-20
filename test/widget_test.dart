import 'package:familyflix/main.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('affiche l’accueil FamilyFlix', (tester) async {
    await tester.pumpWidget(const FamilyFlixApp());
    expect(find.byType(Logo), findsOneWidget);
    expect(
      find.text('Tous vos films.\nToute votre famille.', findRichText: true),
      findsOneWidget,
    );
    expect(find.text('Ajouter un film'), findsOneWidget);
  });

  test('l’avatar familial évolue avec la collection', () {
    expect(const FamilyAvatar(filmCount: 0).stage.label, 'L’aventure commence');
    expect(const FamilyAvatar(filmCount: 10).stage.label, 'Soirée popcorn');
    expect(const FamilyAvatar(filmCount: 100).stage.label, 'Légende familiale');
  });
}
