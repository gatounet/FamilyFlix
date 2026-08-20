import 'dart:io';

import 'package:familyflix/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pdf/pdf.dart';

void main() {
  testWidgets('affiche l’accueil FamilyFlix', (tester) async {
    await tester.pumpWidget(const FamilyFlixApp());
    expect(find.byType(Logo), findsOneWidget);
    expect(
      find.text('Tous vos films.\nToute votre famille.', findRichText: true),
      findsOneWidget,
    );
    expect(find.text('Ajouter un film ou une série'), findsOneWidget);
  });

  test('l’avatar familial évolue avec la collection', () {
    expect(const FamilyAvatar(filmCount: 0).stage.label, 'L’aventure commence');
    expect(const FamilyAvatar(filmCount: 10).stage.label, 'Soirée popcorn');
    expect(const FamilyAvatar(filmCount: 100).stage.label, 'Légende familiale');
  });

  test('décrit les trois formes de possession d’une série', () {
    LibraryMovie series(String scope, List<int> seasons) => LibraryMovie(
      copyId: 'copy',
      ownerId: 'owner',
      id: 'media',
      tmdbId: 1399,
      mediaType: 'tv',
      title: 'Game of Thrones',
      overview: '',
      releaseDate: '2011-04-17',
      posterPath: null,
      member: 'Famille',
      format: 'bluray',
      sourceName: '',
      ownershipScope: scope,
      seasonNumbers: seasons,
    );

    expect(
      series('complete_series', const []).ownershipLabel,
      'Série complète',
    );
    expect(series('single_season', const [2]).ownershipLabel, 'Saison 2');
    expect(
      series('selected_seasons', const [1, 3, 4]).ownershipLabel,
      'Saisons 1, 3, 4',
    );
  });

  testWidgets('génère un catalogue PDF imprimable', (tester) async {
    final movie = LibraryMovie(
      copyId: 'copy',
      ownerId: 'owner',
      id: 'media',
      tmdbId: 157336,
      mediaType: 'movie',
      title: 'Interstellar',
      overview: '',
      releaseDate: '2014-11-05',
      posterPath: null,
      member: 'Nicolas',
      format: 'bluray',
      sourceName: 'Salon',
      ownershipScope: 'movie',
      seasonNumbers: const [],
    );
    await tester.pumpWidget(
      MaterialApp(
        home: FamilyCatalogPage(
          household: const HouseholdSummary(
            id: 'family',
            name: 'Famille test',
            displayName: 'Nicolas',
            role: 'owner',
            filmCount: 1,
          ),
          movies: [movie],
        ),
      ),
    );
    final state = tester.state<FamilyCatalogPageState>(
      find.byType(FamilyCatalogPage),
    );
    final bytes = await state.buildPdf(PdfPageFormat.a4.landscape);
    final directory = Directory('tmp/pdfs')..createSync(recursive: true);
    final file = File('${directory.path}/familyflix_catalog_test.pdf');
    file.writeAsBytesSync(bytes);
    expect(bytes.take(4).toList(), [0x25, 0x50, 0x44, 0x46]);
    expect(bytes.length, greaterThan(1000));
  });
}
