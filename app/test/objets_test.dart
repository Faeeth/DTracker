/// Verrous sur la rangee d'objets d'une ligne de butin.
library;

import 'package:dofus_tracker/modele/session.dart';
import 'package:dofus_tracker/source/ressources.dart';
import 'package:dofus_tracker/vue/standard/pages/butin.dart';
import 'package:dofus_tracker/theme.dart';
import 'package:dofus_tracker/vue/standard/briques.dart';
import 'package:dofus_tracker/vue/standard/pages/objets.dart';
import 'package:dofus_tracker/vue/theme_shad.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shadcn_ui/shadcn_ui.dart' hide Cache;

/// Ressources vides : aucune image n'est lue, les libelles retombent sur les
/// identifiants, et `detailObjet` rend un detail vide. L'infobulle doit rester
/// utile dans ces conditions.
final res = Ressources('.');

/// Des ressources qui savent ou est le dessin d'un objet.
///
/// Les vraies lisent un index d'icones que le depot de test n'a pas. On ne
/// veut pas verifier ici que l'extraction a eu lieu, seulement que
/// l'infobulle reclame le dessin quand il existe.
class ResAvecDessin extends Ressources {
  ResAvecDessin() : super('.');

  @override
  String? imageObjet(int itemId) => 'images/items/$itemId.png';

  @override
  String? get imagePods => 'images/icons/2x/weight.png';

  @override
  String? get imageKamas => 'images/icons/2x/kamas.png';

  @override
  DetailObjet detailObjet(int itemId) =>
      const DetailObjet(niveau: 195, poids: 10, type: 'Galet');
}

Future<void> monte(WidgetTester tester, Widget enfant) async {
  await tester.binding.setSurfaceSize(const Size(800, 400));
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
        home: Scaffold(body: Center(child: enfant)),
      ),
    ),
  );
  await tester.pump();
}

void main() {
  testWidgets('la quantite ne s\'ecrit qu\'au-dela de un', (tester) async {
    await monte(
      tester,
      Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          CaseObjet(lot: (2663, 1, 1567), res: res),
          CaseObjet(lot: (311, 12, 40), res: res),
        ],
      ),
    );
    // Ecrire « 1 » sur chaque case ferait du bruit pour une information que
    // l'absence de chiffre donne deja.
    expect(find.text('1'), findsNothing);
    expect(find.text('12'), findsOneWidget);
  });

  testWidgets('l\'infobulle donne le prix unitaire et celui du lot', (
    tester,
  ) async {
    await monte(tester, InfobulleObjet(lot: (2663, 3, 1567), res: res));
    expect(find.text('PRIX MOYEN '), findsOneWidget);
    expect(find.text(formateNombre(1567)), findsOneWidget);
    // Le lot, c'est ce qu'on vient chercher : trois Engrais a 1 567.
    expect(find.text(formateNombre(3 * 1567)), findsOneWidget);
  });

  testWidgets('la quantite se colle au nom, espacee', (tester) async {
    final res = ResAvecDessin();
    await monte(tester, InfobulleObjet(lot: (2663, 1248, 12), res: res));
    // Comme le jeu l\'ecrit : « Fémur du Chafer Ronin x1 248 ».
    expect(find.text('${res.objet(2663)}  x${formateNombre(1248)}'),
        findsOneWidget);
  });

  testWidgets('un objet seul n\'a ni lot ni x1', (tester) async {
    final res = ResAvecDessin();
    await monte(tester, InfobulleObjet(lot: (2663, 1, 1567), res: res));
    // Le nom nu : un « x1 » ne dit que ce que l\'absence disait deja.
    expect(find.text(res.objet(2663)), findsOneWidget);
    expect(find.textContaining('x1'), findsNothing);
    // Et pas de moitie droite : « POIDS 10 · LOT 10 » repete le meme chiffre
    // deux fois sous deux noms.
    expect(find.text('LOT '), findsNothing);
    expect(find.text('POIDS '), findsOneWidget);
    expect(find.text('PRIX MOYEN '), findsOneWidget);
  });

  testWidgets('un prix inconnu se dit, il ne s\'ecrit pas zero', (
    tester,
  ) async {
    await monte(tester, InfobulleObjet(lot: (2663, 3, null), res: res));
    expect(find.text('Prix non disponible'), findsOneWidget);
    expect(find.text('0'), findsNothing);
    // Une ligne, rien de plus : pas de mode d'emploi de la table des prix.
    expect(find.textContaining('table des prix'), findsNothing);
  });

  testWidgets('au-dela de cinq objets, un « +n » deploie le reste', (
    tester,
  ) async {
    final lots = [for (var i = 0; i < 8; i++) (2663 + i, i + 1, 100)];
    await monte(tester, RangeeObjets(lots: lots, res: res));

    // Cinq cases visibles, et le compte de ce qui reste.
    expect(find.byType(CaseObjet), findsNWidgets(5));
    expect(find.text('+3'), findsOneWidget);

    await tester.tap(find.text('+3'));
    await tester.pumpAndSettle();

    // Le panneau montre le butin entier, pas seulement le reste.
    expect(find.text('8 objets'), findsOneWidget);
    expect(find.byType(CaseObjet), findsNWidgets(5 + 8));
  });

  testWidgets('cinq objets ou moins n\'ouvrent rien', (tester) async {
    final lots = [for (var i = 0; i < 4; i++) (2663 + i, 1, 100)];
    await monte(tester, RangeeObjets(lots: lots, res: res));
    expect(find.byType(CaseObjet), findsNWidgets(4));
    expect(find.textContaining('+'), findsNothing);
  });
  testWidgets('l\'infobulle parait au survol de l\'icone', (tester) async {
    // Le vrai geste, souris comprise. Un test qui monte `InfobulleObjet`
    // seule passe alors que rien ne parait en vrai : `ShadTooltip` ne guette
    // pas le survol, il l'attend d'un `ShadGestureDetector` descendant.
    await monte(tester, CaseObjet(lot: (2663, 3, 1567), res: res));
    expect(find.text('PRIX MOYEN '), findsNothing);

    final souris = TestPointer(1, PointerDeviceKind.mouse);
    await tester.sendEventToBinding(souris.hover(const Offset(1, 1)));
    await tester.sendEventToBinding(
      souris.hover(tester.getCenter(find.byType(CaseObjet))),
    );
    await tester.pumpAndSettle();

    expect(find.text('PRIX MOYEN '), findsOneWidget);
    expect(find.text(formateNombre(3 * 1567)), findsOneWidget);
  });

  /// Amene la souris sur le premier objet trouve.
  Future<void> survole(WidgetTester tester, Finder cible) async {
    final souris = TestPointer(1, PointerDeviceKind.mouse);
    await tester.sendEventToBinding(souris.hover(const Offset(1, 1)));
    await tester.sendEventToBinding(souris.hover(tester.getCenter(cible)));
    await tester.pumpAndSettle();
  }

  testWidgets('l\'inventaire d\'un personnage survole le meme detail', (
    tester,
  ) async {
    final suivi = Suivi('Iop')
      ..kamasPiece = 4200
      ..ajouteLot(2663, 3, 1567);
    await monte(
      tester,
      SizedBox(
        width: 700,
        height: 380,
        child: PageButin(suivi: suivi, res: res),
      ),
    );

    expect(find.text('PRIX MOYEN '), findsNothing);
    await survole(tester, find.byType(SurvolObjet).first);

    // Le detail complet, pas un texte ecrit a part pour cette vue-ci.
    expect(find.text('PRIX MOYEN '), findsOneWidget);
    // La valeur du lot parait deux fois : dans l'infobulle, et dans la bourse
    // sous la grille. C'est voulu — on la cherche aux deux endroits.
    expect(find.text(formateNombre(3 * 1567)), findsWidgets);
  });

  testWidgets('l\'infobulle porte le dessin de l\'objet', (tester) async {
    final res = ResAvecDessin();
    await monte(tester, InfobulleObjet(lot: (2663, 3, 1567), res: res));
    // Le dessin d'abord, le nom ensuite : on reconnait un objet a son icone
    // bien avant d'avoir lu son nom. Les autres images de l'infobulle sont
    // les pods et les kamas, plus bas.
    expect(find.byType(Image), findsWidgets);
    final dessin = tester.getRect(find.byType(Image).first);
    final nom =
        tester.getRect(find.text('${res.objet(2663)}  x${formateNombre(3)}'));
    expect(dessin.left, lessThan(nom.left));
  });

  testWidgets('la bourse chiffre en entier et porte ses kamas', (tester) async {
    final suivi = Suivi('Iop')
      ..kamasPiece = 1954
      ..ajouteLot(2663, 3, 1567);
    await monte(
      tester,
      SizedBox(
        width: 700,
        height: 380,
        child: PageButin(suivi: suivi, res: ResAvecDessin()),
      ),
    );

    // En entier, pas arrondi : « 2,0 k » cache les pieces qu'on est venu
    // compter.
    expect(find.text(formateNombre(1954)), findsWidgets);
    expect(find.text(formateCourt(1954)), findsNothing);

    // Les trois chiffres de la bourse sont des montants : chacun porte
    // l'icone. Le compte d'objets, lui, n'en a pas.
    final chiffres = tester.widgetList<Chiffre>(find.byType(Chiffre));
    expect(chiffres.length, 3);
    expect(chiffres.every((c) => c.kamas != null), isTrue);
  });

  testWidgets('le poids porte son icone de pods', (tester) async {
    // Prix inconnu : la seule ligne chiffree est celle du poids, donc les
    // icones comptees sont bien les pods, pas les kamas.
    await monte(
      tester,
      InfobulleObjet(lot: (2663, 3, null), res: ResAvecDessin()),
    );
    expect(find.text('POIDS '), findsOneWidget);
    // Le dessin de l'objet, puis les pods derriere chacun des deux chiffres.
    expect(find.byType(Image), findsNWidgets(3));
    final pods = tester.getRect(find.byType(Image).at(1));
    final chiffre = tester.getRect(find.text('10'));
    expect(pods.left, greaterThan(chiffre.left));
  });
}
