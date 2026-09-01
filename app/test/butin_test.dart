/// Verrous sur la grille d'inventaire : son tri, ce qu'elle contient, la
/// gouttiere reservee a son ascenseur, et la liste des personnages comptes
/// dans l'inventaire du groupe — qui repose sur la meme grille.
library;

import 'package:dofus_tracker/modele/session.dart';
import 'package:dofus_tracker/source/ressources.dart';
import 'package:dofus_tracker/theme.dart';
import 'package:dofus_tracker/vue/standard/pages/butin.dart';
import 'package:dofus_tracker/vue/standard/pages/inventaire.dart';
import 'package:dofus_tracker/vue/standard/pages/objets.dart';
import 'package:dofus_tracker/vue/theme_shad.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shadcn_ui/shadcn_ui.dart' hide Cache;

/// Des ressources qui savent peser et nommer.
///
/// Le poids ne circule pas sur le reseau : il vient de l'index extrait du
/// client, absent du depot de test. Sans lui, deux des tris proposes ne
/// trieraient rien et le cas ne prouverait rien.
class ResPesees extends Ressources {
  ResPesees() : super('.');

  static const _poids = {10: 1, 20: 30, 30: 5};
  static const _noms = {10: 'Cuir', 20: 'Bois', 30: 'Amande'};

  @override
  DetailObjet detailObjet(int id) => DetailObjet(poids: _poids[id] ?? 0);

  @override
  String objet(int id) => _noms[id] ?? 'Objet $id';

  @override
  String? imageClasse(int? classe) =>
      classe == null ? null : 'images/class/2x/Head_${classe * 10}.png';
}

/// Trois lots choisis pour que chaque tri donne un ordre different.
///
///     id  nom      quantite  poids  poids du lot  prix  prix du lot
///     10  Cuir           40      1            40    12          480
///     20  Bois            2     30            60     5           10
///     30  Amande          7      5            35   100          700
Suivi butin() => Suivi('Kaska-yopette')
  ..kamasPiece = 5000
  ..ajouteLot(10, 40, 12)
  ..ajouteLot(20, 2, 5)
  ..ajouteLot(30, 7, 100);

Future<void> monte(WidgetTester tester, {Suivi? suivi}) async {
  await tester.binding.setSurfaceSize(const Size(900, 620));
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
            child: PageButin(suivi: suivi ?? butin(), res: ResPesees()),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
}

Future<void> monteInventaire(WidgetTester tester, Session session) async {
  await tester.binding.setSurfaceSize(const Size(900, 620));
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
            child: PageInventaire(suivis: session.lignes, res: ResPesees()),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
}

/// Les objets de la grille, dans leur ordre d'affichage.
List<int> ordre(WidgetTester tester) => tester
    .widgetList<SurvolObjet>(find.byType(SurvolObjet))
    .map((c) => c.lot.$1)
    .toList();

Future<void> trie(WidgetTester tester, String libelle) async {
  await tester.tap(find.byType(ShadSelect<TriButin>));
  await tester.pumpAndSettle();
  await tester.tap(find.text(libelle).last);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('les kamas ne sont plus une case de l\'inventaire', (
    tester,
  ) async {
    await monte(tester);
    // Trois objets, pas quatre : les kamas en piece ne sont pas un objet, ils
    // n'ont ni poids ni prix, et aucun tri ne saurait ou les ranger.
    expect(find.byType(SurvolObjet), findsNWidgets(3));
    expect(ordre(tester).contains(0), isFalse);
    // Leur montant reste lisible sous la grille.
    expect(find.text('EN PIÈCE'), findsOneWidget);
    expect(find.text(formateNombre(5000)), findsWidgets);
  });

  testWidgets('sans tri, la grille garde l\'ordre du jeu', (tester) async {
    await monte(tester);
    // Par valeur decroissante : 700, 480, 10.
    expect(ordre(tester), [30, 10, 20]);
  });

  testWidgets('chaque tri range la grille comme il l\'annonce', (tester) async {
    await monte(tester);

    await trie(tester, 'Trier par nom');
    expect(ordre(tester), [30, 20, 10], reason: 'Amande, Bois, Cuir');

    await trie(tester, 'Trier par quantité');
    expect(ordre(tester), [10, 30, 20], reason: '40, 7, 2');

    await trie(tester, 'Trier par poids');
    expect(ordre(tester), [20, 30, 10], reason: '30, 5, 1');

    await trie(tester, 'Trier par poids du lot');
    expect(ordre(tester), [20, 10, 30], reason: '60, 40, 35');

    await trie(tester, 'Trier par prix moyen');
    expect(ordre(tester), [30, 10, 20], reason: '100, 12, 5');

    await trie(tester, 'Trier par prix moyen du lot');
    expect(ordre(tester), [30, 10, 20], reason: '700, 480, 10');

    await trie(tester, 'Aucun tri');
    expect(ordre(tester), [30, 10, 20]);
  });

  testWidgets('l\'ascenseur a sa gouttiere, hors de la grille', (tester) async {
    await monte(tester);
    final barre = tester.getRect(find.byType(Scrollbar));
    final carte = tester.getRect(find.byType(ShadCard).first);
    // Pose sur la grille, l'ascenseur recouvrait la derniere colonne d'objets
    // et masquait justement ce qu'on venait survoler.
    expect(carte.right, lessThan(barre.right - 8));
  });

  testWidgets('un inventaire vide le dit', (tester) async {
    // Des kamas mais aucun objet : la grille n'a rien a montrer.
    await monte(tester, suivi: Suivi('Kaska-nini')..kamasPiece = 300);
    expect(find.textContaining('Aucun item trouvé'), findsOneWidget);
    expect(find.byType(SurvolObjet), findsNothing);
  });

  testWidgets('la liste des personnages comptes porte leur portrait',
      (tester) async {
    final session = Session(['Kaska-yopette', 'Kaska-nini'])
      ..definitClasses(const {'Kaska-yopette': 12, 'Kaska-nini': 4});
    session.recoit(
        {'ts': 1, 'type': 'FightStart', 'character': 'Kaska-yopette'});
    session.recoit({
      'ts': 10,
      'type': 'FightEnd',
      'participants': [
        {
          'name': 'Kaska-yopette',
          'level': 60,
          'xp': 10,
          'kamas': 3,
          'loot': [
            {'item_id': 10, 'quantity': 4, 'unit_price': 12},
          ],
        },
        {'name': 'Kaska-nini', 'level': 60, 'xp': 8, 'kamas': 2, 'loot': []},
      ],
    });

    await monteInventaire(tester, session);

    expect(find.text('Kaska-yopette'), findsOneWidget);
    expect(find.text('Kaska-nini'), findsOneWidget);
    // Une liste de pseudos se parcourt mal quand on cherche « le Sadida » :
    // un portrait par case, et la bonne se trouve sans lire.
    expect(find.byType(Image), findsNWidgets(2));

    // Decocher retire le personnage du total, et la grille suit.
    expect(find.text('2 sur 2'), findsOneWidget);
    await tester.tap(find.byType(ShadCheckbox).first);
    await tester.pump();
    expect(find.text('1 sur 2'), findsOneWidget);
  });
}
