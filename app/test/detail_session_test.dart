/// Verrous sur le detail d'une session archivee.
///
/// Le tableau des combats s'y affichait en aplats gris : chaque cellule etait
/// emballee deux fois dans un `ShadTableCell`, une fois par l'appelant et une
/// fois par `Tableau`. Rien ne protestait — le tableau se dessinait, ses
/// valeurs simplement recouvertes.
library;

import 'package:dofus_tracker/modele/session.dart';
import 'package:dofus_tracker/source/archives.dart';
import 'package:dofus_tracker/source/ressources.dart';
import 'package:dofus_tracker/theme.dart';
import 'package:dofus_tracker/vue/standard/briques.dart';
import 'package:dofus_tracker/vue/standard/pages/objets.dart';
import 'package:dofus_tracker/vue/standard/pages/sessions.dart';
import 'package:dofus_tracker/vue/theme_shad.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shadcn_ui/shadcn_ui.dart' hide Cache;

final res = Ressources('.');

Archive archiveDeTest() => Archive(
  nom: 'Session 4',
  numero: 4,
  periodes: [Periode(1700000000, 1700003600)],
  enCours: false,
  personnages: [
    BilanPersonnage(
      nom: 'Kaska-yopette',
      classe: 12,
      niveau: 200,
      xp: 4596601,
      kamasPiece: 938046,
      butin: {2663: (3, 1567)},
    ),
    BilanPersonnage(
      nom: 'Kaska-nini',
      classe: 4,
      niveau: 199,
      xp: 12,
      kamasPiece: 40,
      butin: {311: (2, 40)},
    ),
  ],
  challenges: const [],
  journal: const [],
  combats: [
    Combat(
      fin: 1700003000,
      duree: 42,
      participants: [
        ParticipantCombat(
          nom: 'Kaska-yopette',
          niveau: 200,
          xp: 2789,
          xpTotal: 0,
          xpSeuilBas: 0,
          xpSeuilHaut: 0,
          kamas: 63,
          butin: const {2663: (3, 1567)},
        ),
      ],
    ),
  ],
);

Future<void> monte(WidgetTester tester, Archive archive) async {
  await tester.binding.setSurfaceSize(const Size(1000, 700));
  addTearDown(() => tester.binding.setSurfaceSize(null));
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
        home: Scaffold(
          body: Padding(
            padding: const EdgeInsets.all(12),
            child: PageDetailSession(
              archive: archive,
              res: res,
              onCombat: (_) {},
              onPersonnage: (_) {},
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
}

void main() {
  testWidgets('le tableau des combats montre ses valeurs', (tester) async {
    await monte(tester, archiveDeTest());

    // La meme liste que « Mes combats » : ses colonnes, son tri, ses icones.
    expect(find.text('FIN DU COMBAT'), findsOneWidget);
    expect(find.text('OBJETS'), findsOneWidget);
    // Les en-tetes se dessinaient deja ; c'est le corps qui disparaissait.
    expect(find.text(formateDuree(42)), findsOneWidget);
    expect(find.text('${formateNombre(2789)} XP'), findsOneWidget);
    expect(find.text(formateNombre(63 + 3 * 1567)), findsOneWidget);
  });

  testWidgets('une cellule deja emballee reste lisible', (tester) async {
    // La cause exacte du tableau gris : l'appelant posait un `ShadTableCell`
    // que `Tableau` emballait dans un second. Le cas ci-dessus ne pourrait
    // plus l'attraper — `Tableau` deballe maintenant — alors on verifie la
    // tolerance elle-meme, sur la brique.
    await tester.binding.setSurfaceSize(const Size(600, 300));
    addTearDown(() => tester.binding.setSurfaceSize(null));
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
          home: const Scaffold(
            body: Tableau(
              colonnes: [Colonne('NU', 0), Colonne('EMBALLÉ', 200)],
              lignes: [
                [Text('sans cellule'), ShadTableCell(child: Text('avec'))],
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('sans cellule'), findsOneWidget);
    expect(find.text('avec'), findsOneWidget);
    // Et pas de cellule dans une cellule, qui peignait l'aplat gris.
    for (final cellule in tester.widgetList<ShadTableCell>(
      find.byType(ShadTableCell),
    )) {
      expect(cellule.child, isNot(isA<ShadTableCell>()));
    }
  });

  testWidgets('le butin d\'un personnage ne se redit pas au survol', (
    tester,
  ) async {
    await monte(tester, archiveDeTest());
    await tester.tap(find.textContaining('Personnages'));
    await tester.pump();

    expect(find.text('Kaska-yopette'), findsOneWidget);
    // La composition se lit d'un clic sur la ligne : la redire au survol
    // couvrait le tableau des qu'on le parcourait.
    expect(find.byType(Infobulle), findsNothing);
  });

  testWidgets('l\'inventaire est une grille, avec choix et tri', (
    tester,
  ) async {
    await monte(tester, archiveDeTest());
    await tester.tap(find.text('Inventaire'));
    await tester.pump();

    // La meme grille que dans le suivi, et non un tableau de lignes.
    expect(find.text('2 sur 2'), findsOneWidget);
    expect(find.text('INVENTAIRE'), findsOneWidget);
    expect(find.byType(SurvolObjet), findsNWidgets(2));
    expect(find.byType(ShadCheckbox), findsNWidgets(2));

    // Decocher un personnage retire son butin du total.
    await tester.tap(find.byType(ShadCheckbox).first);
    await tester.pump();
    expect(find.text('1 sur 2'), findsOneWidget);
    expect(find.byType(SurvolObjet), findsOneWidget);
  });
}
