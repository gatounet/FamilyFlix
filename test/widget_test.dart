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

  testWidgets('reste lisible sur un écran de smartphone', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const FamilyFlixApp());
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.text('Ajouter un film ou une série'), findsOneWidget);
  });

  testWidgets('présente les API dans les mentions légales', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: LegalNoticesPage()));

    expect(
      find.text('TMDB — métadonnées cinéma et télévision'),
      findsOneWidget,
    );
    await tester.scrollUntilVisible(
      find.text('Autres services et API'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Autres services et API'), findsOneWidget);
    expect(find.textContaining('Supabase fournit'), findsOneWidget);
  });

  testWidgets('fait défiler la vidéothèque avec les flèches latérales', (
    tester,
  ) async {
    final movies = List.generate(
      6,
      (index) => LibraryMovie(
        copyId: 'copy-$index',
        ownerId: 'owner',
        id: 'media-$index',
        tmdbId: index,
        mediaType: 'movie',
        title: 'Film $index',
        overview: '',
        releaseDate: '2026-01-01',
        posterPath: null,
        member: 'Famille',
        format: '',
        sourceName: '',
        ownershipScope: 'movie',
        seasonNumbers: const [],
      ),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 390,
            child: MovieStrip(movies: movies, wish: true),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final state = tester.state<MovieStripState>(find.byType(MovieStrip));
    expect(state.scrollController.offset, 0);
    await tester.tap(find.byIcon(Icons.chevron_right));
    await tester.pumpAndSettle();

    expect(state.scrollController.offset, greaterThan(0));
    expect(find.byIcon(Icons.chevron_left), findsOneWidget);
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
    expect(
      FamilyCatalogPageState.formatPrintDate(DateTime(2026, 8, 20)),
      '20/08/2026',
    );
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

  testWidgets('génère une jaquette au format DVD sur une page A4', (
    tester,
  ) async {
    const movie = LibraryMovie(
      copyId: 'copy',
      ownerId: 'owner',
      id: 'media',
      tmdbId: 157336,
      mediaType: 'movie',
      title: 'Interstellar',
      overview:
          'Une équipe d’explorateurs voyage à travers un trou de ver afin de chercher un nouveau foyer pour l’humanité.',
      releaseDate: '2014-11-05',
      posterPath: null,
      member: 'Famille',
      format: 'dvd',
      sourceName: 'Salon',
      ownershipScope: 'movie',
      seasonNumbers: [],
    );

    final bytes = await DvdCoverPdf.build(movie);
    final directory = Directory('tmp/pdfs')..createSync(recursive: true);
    final file = File('${directory.path}/familyflix_dvd_cover_test.pdf');
    file.writeAsBytesSync(bytes);

    expect(bytes.take(4).toList(), [0x25, 0x50, 0x44, 0x46]);
    expect(bytes.length, greaterThan(1000));
  });
}
