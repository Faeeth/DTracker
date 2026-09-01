/// Verrous sur les adversaires affiches a la fin d'un combat.
///
/// Le jeu montre deux blocs : les gagnants, avec ce qu'ils ont gagne, puis les
/// perdants. Le second manquait entierement.
library;

import 'package:dofus_tracker/modele/session.dart';
import 'package:dofus_tracker/source/ressources.dart';
import 'package:dofus_tracker/vue/standard/pages/combats.dart';
import 'package:dofus_tracker/vue/theme_shad.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shadcn_ui/shadcn_ui.dart' hide Cache;

/// Des ressources qui savent nommer un monstre.
///
/// Les vraies lisent `labels/monsters.json` et `monstres.json`, absents du
/// depot de test. Ce qu'on verifie ici n'est pas l'extraction mais l'usage
/// qu'en fait l'ecran.
class ResMonstres extends Ressources {
  ResMonstres() : super('.');

  static const _noms = {78: 'Rose Démoniaque', 4820: 'Épouvanteur'};

  @override
  String monstre(int id) => _noms[id] ?? 'Monstre $id';

  @override
  int? niveauMonstre(int id, int? grade) => id == 78 ? 15 + (grade ?? 1) : null;

  @override
  String? imageMonstre(int id) => 'images/monster/2x/$id.png';
}

ParticipantCombat joueur(String nom, {bool gagnant = true}) =>
    ParticipantCombat(
      nom: nom,
      niveau: 60,
      xp: gagnant ? 2789 : 0,
      xpTotal: 0,
      xpSeuilBas: 0,
      xpSeuilHaut: 0,
      kamas: gagnant ? 63 : 0,
      gagnant: gagnant,
      butin: const {},
    );

Combat combatAvec(List<Adversaire> adversaires,
        {List<ParticipantCombat>? participants}) =>
    Combat(
      fin: 1700000000,
      duree: 42,
      participants: participants ?? [joueur('Kaska-yopette')],
      adversaires: adversaires,
    );

Future<void> monte(WidgetTester tester, Combat combat) async {
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
            child: PageRecapitulatif(combat: combat, res: ResMonstres()),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
}

void main() {
  testWidgets('les deux camps sont annonces', (tester) async {
    await monte(
      tester,
      combatAvec(const [Adversaire(monstre: 78, grade: 2)]),
    );
    expect(find.text('GAGNANTS'), findsOneWidget);
    expect(find.text('PERDANTS'), findsOneWidget);
    expect(find.text('Rose Démoniaque'), findsOneWidget);
    // Le niveau depend du grade : une Rose Demoniaque va du 16 au 20.
    expect(find.text('Niv. 17'), findsOneWidget);
  });

  testWidgets('les adversaires identiques se comptent', (tester) async {
    await monte(
      tester,
      combatAvec(const [
        Adversaire(monstre: 78, grade: 2),
        Adversaire(monstre: 78, grade: 2),
        Adversaire(monstre: 78, grade: 3),
        Adversaire(monstre: 4820, grade: 1),
      ]),
    );
    // Trois Roses ne font pas trois vignettes jumelles : deux au grade 2, une
    // au grade 3 — le niveau differe, donc la vignette aussi.
    expect(find.text('Rose Démoniaque'), findsNWidgets(2));
    expect(find.text('x2'), findsOneWidget);
    expect(find.text('Niv. 17'), findsOneWidget);
    expect(find.text('Niv. 18'), findsOneWidget);
    expect(find.text('Épouvanteur'), findsOneWidget);
    // Le compte annonce est celui des adversaires, pas celui des vignettes.
    expect(find.text('4'), findsOneWidget);
  });

  testWidgets('un adversaire non nomme se dit tel quel', (tester) async {
    await monte(
      tester,
      combatAvec(const [Adversaire(), Adversaire(), Adversaire(monstre: 78)]),
    );
    expect(find.text('Adversaire inconnu'), findsOneWidget);
    expect(find.text('x2'), findsOneWidget);
    // Nommer ce qu'on ignore serait pire que de l'avouer.
    expect(find.text('Monstre null'), findsNothing);
  });

  testWidgets('sans adversaire, aucun bloc ne s\'ouvre', (tester) async {
    await monte(tester, combatAvec(const []));
    expect(find.text('PERDANTS'), findsNothing);
    expect(find.text('GAGNANTS'), findsOneWidget);
  });

  testWidgets('un personnage qui abandonne rejoint les perdants', (
    tester,
  ) async {
    await monte(
      tester,
      combatAvec(
        const [Adversaire(monstre: 78, grade: 2)],
        participants: [
          joueur('Kaska-nini'),
          joueur('Kaska-yopette', gagnant: false),
        ],
      ),
    );

    // Le tableau des gagnants ne porte que celui qui a gagne.
    expect(find.text('Kaska-nini'), findsOneWidget);
    // Le fuyard est en bas, avec les monstres, et non sous « GAGNANTS ».
    final gagnants = tester.getRect(find.text('GAGNANTS'));
    final fuyard = tester.getRect(find.text('Kaska-yopette'));
    final perdants = tester.getRect(find.text('PERDANTS'));
    expect(fuyard.top, greaterThan(gagnants.top));
    expect(fuyard.top, greaterThan(perdants.top));
    // Deux perdants : le monstre et lui.
    expect(find.text('2'), findsOneWidget);
  });
  testWidgets("la ligne d'un invite passe entiere en retrait", (tester) async {
    // Le pseudo seul ne suffisait pas : l'experience, les kamas et les objets
    // restaient aussi francs que ceux des notres, et l'oeil additionnait des
    // chiffres qui n'entrent dans aucun total.
    await monte(
      tester,
      combatAvec(const [], participants: [
        joueur('Kaska-yopette'),
        ParticipantCombat(
          nom: 'Ami-iop',
          niveau: 200,
          xp: 9000,
          xpTotal: 0,
          xpSeuilBas: 0,
          xpSeuilHaut: 0,
          kamas: 900,
          butin: const {2663: (3, 100)},
          suivi: false,
        ),
      ]),
    );

    // Sa ligne porte la marque, et l'explication au survol.
    expect(find.byIcon(LucideIcons.userMinus), findsOneWidget);

    // Et tout ce qui la compose est attenue — a la moitie, ce qui laisse aux
    // icones d'objets assez de couleur pour se reconnaitre.
    final voiles = tester
        .widgetList<Opacity>(find.byType(Opacity))
        .where((o) => (o.opacity - 0.5).abs() < 0.001)
        .length;
    expect(voiles, greaterThanOrEqualTo(4),
        reason: 'niveau, experience, butin et objets doivent l\'etre');
    // Ses chiffres restent lisibles dans sa ligne — c'est ce que le jeu
    // affichait — mais le total du combat, lui, les ignore.
    expect(find.textContaining('9\u00A0000'), findsOneWidget,
        reason: "sa ligne montre bien ce qu'il a gagne");
  });

}
