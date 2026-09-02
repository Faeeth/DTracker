/// Verrous sur la fenetre des nouveautes.
///
/// Deux choses valent d'etre tenues. Qu'elle s'ouvre une fois et pas deux —
/// une fenetre au demarrage qui revient chaque jour est une nuisance. Et que
/// la table des notes soit complete dans les quatre langues : c'est le seul
/// texte du projet qu'une traduction manquante ne fait pas echouer a la
/// compilation, l'abstraction de [Textes] ne le protegeant pas.
library;

import 'package:dofus_tracker/config.dart';
import 'package:dofus_tracker/i18n/notes.dart';
import 'package:dofus_tracker/i18n/textes.dart';
import 'package:dofus_tracker/vue/standard/notes_dialogue.dart';
import 'package:dofus_tracker/vue/theme_shad.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shadcn_ui/shadcn_ui.dart' hide Cache;

/// La version que la table connait, quelle qu'elle soit : le verrou ne doit
/// pas tomber a chaque publication.
final String connue = versionsAnnoncees.first;

void main() {
  group('ce qu\'il y a a annoncer', () {
    test('une version deja vue ne dit rien', () {
      expect(aAnnoncer(version: connue, vue: connue), isNull);
    });

    test('une version sans notes ne dit rien', () {
      // Le cas d'une version de developpement, et celui d'une publication
      // dont on n'aurait rien a dire : mieux vaut aucune fenetre qu'une
      // fenetre vide.
      expect(aAnnoncer(version: 'dev', vue: ''), isNull);
      expect(aAnnoncer(version: '0.0.1', vue: ''), isNull);
    });

    test('une version neuve donne ses notes', () {
      final notes = aAnnoncer(version: connue, vue: '1.0.4');
      expect(notes, isNotNull);
      expect(notes!.vide, isFalse);
    });

    test('un numero jamais vu les donne aussi', () {
      // Le cas de celui qui avait deja l'outil : rien n'est note dans ses
      // reglages, et il doit voir ce qu'il vient de recevoir.
      expect(aAnnoncer(version: connue, vue: ''), isNotNull);
    });

    test('une premiere installation ne dit rien', () {
      // Ce qui a change n'interesse que celui qui connaissait l'etat d'avant,
      // et ce lancement-la est deja occupe a chercher les donnees du jeu.
      expect(
        aAnnoncer(version: connue, vue: '', premiereInstallation: true),
        isNull,
      );
    });

    test('les reglages retiennent le numero annonce', () {
      // Sans ce champ, la fenetre reviendrait a chaque lancement.
      expect(Config().versionVue, '');
      expect(Config().versJson()['seen_version'], '');
    });
  });

  test('chaque version est annoncee dans les quatre langues', () {
    for (final version in versionsAnnoncees) {
      for (final langue in Langue.values) {
        final notes = notesDe(version, langue);
        expect(notes, isNotNull, reason: '$version manque en ${langue.code}');
        expect(
          notes!.vide,
          isFalse,
          reason: '$version est vide en ${langue.code}',
        );
        // Autant de lignes d'une langue a l'autre : une traduction a moitie
        // faite se voit ici, et nulle part ailleurs.
        final fr = notesDe(version, Langue.fr)!;
        expect(notes.nouveautes.length, fr.nouveautes.length,
            reason: '$version : nouveautes en ${langue.code}');
        expect(notes.correctifs.length, fr.correctifs.length,
            reason: '$version : correctifs en ${langue.code}');
        expect(notes.ajustements.length, fr.ajustements.length,
            reason: '$version : ajustements en ${langue.code}');
      }
    }
  });

  testWidgets('la fenetre porte la version et les trois rubriques', (
    tester,
  ) async {
    final notes = notesDe(connue, Langue.fr)!;
    await tester.pumpWidget(
      ShadApp.custom(
        themeMode: ThemeMode.dark,
        darkTheme: themeSombre(),
        appBuilder: (context) => MaterialApp(
          theme: themeMaterial(),
          localizationsDelegates: const [
            GlobalShadLocalizations.delegate,
            DefaultMaterialLocalizations.delegate,
            DefaultWidgetsLocalizations.delegate,
          ],
          builder: habille,
          home: Builder(
            builder: (contexte) => Scaffold(
              body: ShadButton(
                onPressed: () => montreLesNouveautes(contexte, connue, notes),
                child: const Text('ouvre'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('ouvre'));
    await tester.pumpAndSettle();

    expect(find.text('DTracker $connue'), findsOneWidget);
    // Les rubriques renseignees, et elles seules : un titre suivi de blanc
    // vaudrait moins que rien.
    for (final (libelle, lignes) in [
      ('NOUVEAUTÉS', notes.nouveautes),
      ('CORRECTIFS', notes.correctifs),
      ('AJUSTEMENTS', notes.ajustements),
    ]) {
      expect(
        find.text(libelle),
        lignes.isEmpty ? findsNothing : findsOneWidget,
        reason: libelle,
      );
    }
    // Et son contenu, pas seulement ses intitules. La rubrique regardee est
    // la premiere qui porte quelque chose : toutes les versions n'ont pas de
    // nouveaute a annoncer, et certaines n'ont que des correctifs.
    final lignes = [
      ...notes.nouveautes,
      ...notes.correctifs,
      ...notes.ajustements,
    ];
    expect(find.text(lignes.first), findsOneWidget);

    await tester.tap(find.text('Continuer'));
    await tester.pumpAndSettle();
    expect(find.text('DTracker $connue'), findsNothing);
  });
}
