/// Verrous sur la coquille : le rail, l'en-tete, et le passage d'une page a
/// l'autre.
///
/// Plus de fenetres surgissantes : ces cas verifient qu'un clic sur le butin
/// d'une ligne **change de page** au lieu d'ouvrir un dialogue, et que le
/// retour ramene d'un cran.
///
/// Ils montent la coquille sous un `ShadApp.custom`, comme le fait
/// `main.dart` : les composants shadcn exigent un `ShadTheme` au-dessus
/// d'eux, et l'application Material dessous pour `Scaffold` et consorts.
library;

import 'package:dofus_tracker/config.dart';
import 'package:dofus_tracker/modele/session.dart';
import 'package:dofus_tracker/source/archives.dart';
import 'package:dofus_tracker/source/flux.dart';
import 'package:dofus_tracker/source/ressources.dart';
import 'package:dofus_tracker/theme.dart';
import 'package:dofus_tracker/vue/compacte.dart';
import 'package:dofus_tracker/vue/standard/briques.dart';
import 'package:dofus_tracker/vue/standard/coquille.dart';
import 'package:dofus_tracker/vue/standard/navigation.dart' show Onglet;
import 'package:dofus_tracker/vue/standard/pages/reglages.dart' show Interface;
import 'package:dofus_tracker/vue/standard/rail.dart';
import 'package:dofus_tracker/vue/theme_shad.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dofus_tracker/source/emplacements.dart';
import 'package:dofus_tracker/i18n/textes.dart';
import 'package:shadcn_ui/shadcn_ui.dart' hide Cache;

import 'archives_test.dart' show dossierTemporaire, sessionJouee;

final res = Ressources('.');

Future<void> monte(
  WidgetTester tester, {
  required Session session,
  required Archives archives,
  required Config config,
  VoidCallback? onReglageChange,
  VoidCallback? onPause,
  EtatFlux etat = EtatFlux.connecte,
  String? diagnostic,
  // Rend au cas le moyen de reconstruire, comme le fait la fenetre quand on
  // met la session en pause : la coquille ne se rebatit pas d'elle-meme.
  void Function(StateSetter)? capteur,
  int secondes = 3661,
  // Fournies ici : sans elles, la page de reglages lance un sous-processus
  // Python et laisse un minuteur en suspens apres la fin du cas.
  List<Interface> interfaces = const [
    Interface(numero: '5', libelle: 'Ethernet', device: 'devEthernet'),
    Interface(
      numero: '7',
      libelle: 'OpenVPN Connect DCO Adapter',
      device: 'devVpn',
      physique: false,
    ),
  ],
  Size taille = const Size(1280, 800),
}) async {
  await tester.binding.setSurfaceSize(taille);
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
        home: StatefulBuilder(
          builder: (context, rebatit) {
            capteur?.call(rebatit);
            return Coquille(
              config: config,
              session: session,
              archives: archives,
              res: res,
              ou: const Emplacements(
                donnees: '.',
                programme: '.',
                installe: false,
              ),
              classes: const {},
              secondes: secondes,
              etat: etat,
              diagnostic: diagnostic ?? 'La capture répond.',
              eclatDe: (_) => 0,
              onPause: onPause ?? () {},
              onReset: () {},
              onRenomme: (_) {},
              onCompact: () {},
              onQuitte: () {},
        onReduire: () {},
              onReglageChange: onReglageChange ?? () {},
              onBascule: (_) async {},
              interfaces: interfaces,
            );
          },
        ),
      ),
    ),
  );
  await tester.pump();
}

void main() {
  testWidgets('le rail porte les trois destinations et l\'etat de la liaison', (
    tester,
  ) async {
    final d = dossierTemporaire();
    await monte(
      tester,
      session: sessionJouee(),
      archives: Archives(d.path),
      config: Config(personnages: const ['Kaska-yopette']),
    );

    expect(find.byType(Rail), findsOneWidget);
    for (final onglet in Onglet.values) {
      expect(
        find.text(onglet.libelle),
        findsWidgets,
        reason: '${onglet.libelle} manque au rail',
      );
    }
    // L'etat de la capture est visible en permanence, pas cache dans un pied
    // qu'une page pourrait remplacer.
    expect(find.text('Connecté'), findsOneWidget);
    expect(find.text(formateDuree(3661)), findsOneWidget);

    d.deleteSync(recursive: true);
  });

  testWidgets('la page d\'accueil est le suivi, avec ses totaux', (
    tester,
  ) async {
    final d = dossierTemporaire();
    await monte(
      tester,
      session: sessionJouee(),
      archives: Archives(d.path),
      config: Config(personnages: const ['Kaska-yopette']),
    );

    // Les totaux en tete : c'est le chiffre qu'on cherche en revenant.
    expect(find.text('EXPÉRIENCE'), findsWidgets);
    expect(find.text(formateNombre(53652 * 2)), findsWidgets);
    expect(find.text('Kaska-yopette'), findsOneWidget);
    // Aucun retour a la racine.
    expect(find.byIcon(LucideIcons.arrowLeft), findsNothing);

    d.deleteSync(recursive: true);
  });

  testWidgets('une ligne ouvre la page du personnage, le retour ramene', (
    tester,
  ) async {
    final d = dossierTemporaire();
    await monte(
      tester,
      session: sessionJouee(),
      archives: Archives(d.path),
      config: Config(personnages: const ['Kaska-yopette']),
    );

    // Une seule cible par ligne : `ShadTable` installe ses propres detecteurs
    // sur ses lignes, et une seconde cible glissee dans une cellule n'y
    // recevrait jamais le clic.
    await tester.tap(find.text('Kaska-yopette'));
    await tester.pump();

    // Une page, pas un dialogue : le rail est toujours la.
    expect(find.byType(ShadDialog), findsNothing);
    expect(find.byType(Rail), findsOneWidget);

    // Son butin, et rien d'autre : c'est ce qu'on venait chercher en cliquant
    // sur sa ligne. Ses combats avaient ici un onglet qu'il fallait deviner ;
    // ils se regardent pour la session entiere, depuis le rail.
    expect(find.text('INVENTAIRE'), findsOneWidget);
    expect(find.text('FIN DU COMBAT'), findsNothing);
    expect(find.textContaining('Combats ('), findsNothing);

    await tester.tap(find.byIcon(LucideIcons.arrowLeft));
    await tester.pump();
    expect(find.text('INVENTAIRE'), findsNothing);
    expect(find.byIcon(LucideIcons.arrowLeft), findsNothing);

    d.deleteSync(recursive: true);
  });

  testWidgets('la cadence attend cinq minutes, et se dit en entier', (
    tester,
  ) async {
    final d = dossierTemporaire();
    // Quatre minutes : un seul combat donnerait des chiffres a l'heure qui ne
    // veulent rien dire, on se tait.
    await monte(
      tester,
      session: sessionJouee(),
      archives: Archives(d.path),
      config: Config(personnages: const ['Kaska-yopette']),
      secondes: 240,
    );
    expect(find.textContaining('xp/h'), findsNothing);

    // Une heure pile : l'experience de la session est la cadence horaire.
    await monte(
      tester,
      session: sessionJouee(),
      archives: Archives(d.path),
      config: Config(personnages: const ['Kaska-yopette']),
      secondes: 3600,
    );
    final xp = sessionJouee().xpTotale;
    expect(
      find.text('${formateNombre(xp)} xp/h'),
      findsOneWidget,
      reason: 'en entier : « 140 m xp/h » cache l\'ordre de grandeur',
    );
    expect(find.textContaining(' m xp/h'), findsNothing);

    d.deleteSync(recursive: true);
  });

  testWidgets('la cadence ne bouge pas entre deux paliers de dix secondes', (
    tester,
  ) async {
    final d = dossierTemporaire();
    String lu(WidgetTester t) =>
        t.widgetList<Text>(find.textContaining('xp/h')).first.data!;

    await monte(
      tester,
      session: sessionJouee(),
      archives: Archives(d.path),
      config: Config(personnages: const ['Kaska-yopette']),
      secondes: 3600,
    );
    final a = lu(tester);

    // Trois secondes plus tard : le denominateur est fige, le chiffre aussi.
    await monte(
      tester,
      session: sessionJouee(),
      archives: Archives(d.path),
      config: Config(personnages: const ['Kaska-yopette']),
      secondes: 3603,
    );
    expect(lu(tester), a);

    // Au palier suivant, il bouge.
    await monte(
      tester,
      session: sessionJouee(),
      archives: Archives(d.path),
      config: Config(personnages: const ['Kaska-yopette']),
      secondes: 3610,
    );
    expect(lu(tester), isNot(a));

    d.deleteSync(recursive: true);
  });

  testWidgets('le rail mene aux combats et a l\'inventaire du groupe', (
    tester,
  ) async {
    final d = dossierTemporaire();
    await monte(
      tester,
      session: sessionJouee(),
      archives: Archives(d.path),
      config: Config(personnages: const ['Kaska-yopette', 'Kaska-nini']),
    );

    await tester.tap(find.text('Mes combats'));
    await tester.pump();
    // La liste de la session entiere, pas celle d'un personnage.
    expect(find.text('FIN DU COMBAT'), findsOneWidget);
    expect(find.text('CHALLENGES'), findsWidgets);

    await tester.tap(find.text('Mon inventaire'));
    await tester.pump();
    expect(find.text('INVENTAIRE'), findsOneWidget);
    // Les deux personnages sont comptes par defaut : celui qui apparait en
    // cours de session doit entrer dans le total sans qu'on aille le cocher.
    expect(find.text('2 sur 2'), findsOneWidget);

    d.deleteSync(recursive: true);
  });

  testWidgets('decocher un personnage le retire du butin du groupe', (
    tester,
  ) async {
    final d = dossierTemporaire();
    final session = sessionJouee();
    await monte(
      tester,
      session: session,
      archives: Archives(d.path),
      config: Config(personnages: const ['Kaska-yopette', 'Kaska-nini']),
    );

    await tester.tap(find.text('Mon inventaire'));
    await tester.pump();
    final total = session.kamasTotaux;
    expect(find.text(formateNombre(total)), findsWidgets);

    await tester.tap(find.byType(ShadCheckbox).first);
    await tester.pump();
    expect(find.text('1 sur 2'), findsOneWidget);
    // Le total tombe : c'est tout l'interet de la case.
    expect(find.text(formateNombre(total)), findsNothing);

    d.deleteSync(recursive: true);
  });

  testWidgets('le butin du tableau ne repete pas sa composition au survol', (
    tester,
  ) async {
    final d = dossierTemporaire();
    await monte(
      tester,
      session: sessionJouee(),
      archives: Archives(d.path),
      config: Config(personnages: const ['Kaska-yopette']),
    );

    final souris = TestPointer(1, PointerDeviceKind.mouse);
    await tester.sendEventToBinding(souris.hover(const Offset(1, 1)));
    await tester.sendEventToBinding(
      souris.hover(tester.getCenter(find.byType(Kamas).first)),
    );
    await tester.pumpAndSettle();

    // Le detail — pieces, ressources, lots — se lit en entier d'un clic sur
    // la ligne. Le redire au survol n'apprenait rien et couvrait le tableau
    // des qu'on le parcourait.
    expect(find.textContaining('Kamas en pièce'), findsNothing);

    d.deleteSync(recursive: true);
  });

  testWidgets('chaque onglet des reglages porte son icone', (tester) async {
    final d = dossierTemporaire();
    await monte(
      tester,
      session: sessionJouee(),
      archives: Archives(d.path),
      config: Config(personnages: const ['Kaska-yopette']),
    );

    await tester.tap(find.text('Réglages'));
    await tester.pump();

    // Une icone par onglet. Sans ce compte, un glyphe absent passe pour un
    // choix de mise en page.
    for (final icone in [
      LucideIcons.users,
      LucideIcons.trendingUp,
      LucideIcons.antenna,
      LucideIcons.appWindow,
    ]) {
      expect(find.byIcon(icone), findsOneWidget);
    }

    d.deleteSync(recursive: true);
  });

  testWidgets('le bouton de la vue compacte dit ou il mene', (tester) async {
    final d = dossierTemporaire();
    await monte(
      tester,
      session: sessionJouee(),
      archives: Archives(d.path),
      config: Config(personnages: const ['Kaska-yopette']),
    );

    final souris = TestPointer(1, PointerDeviceKind.mouse);
    await tester.sendEventToBinding(souris.hover(const Offset(1, 1)));
    await tester.sendEventToBinding(
      souris.hover(tester.getCenter(find.byIcon(LucideIcons.shrink))),
    );
    await tester.pumpAndSettle();

    // Deux fleches qui se rapprochent peuvent aussi bien reduire la fenetre
    // que replier un panneau : l'icone seule ne dit pas ou elle mene.
    expect(find.textContaining('vue compacte'), findsOneWidget);

    d.deleteSync(recursive: true);
  });

  testWidgets('les reglages sont une page du rail, pas une popup', (
    tester,
  ) async {
    final d = dossierTemporaire();
    await monte(
      tester,
      session: sessionJouee(),
      archives: Archives(d.path),
      config: Config(personnages: const ['Kaska-yopette']),
    );

    await tester.tap(find.text('Réglages'));
    await tester.pump();

    expect(find.byType(ShadDialog), findsNothing);
    expect(find.byType(Rail), findsOneWidget);
    // Les reglages sont eux-memes en onglets.
    expect(find.byType(ShadTabs<String>), findsOneWidget);
    expect(find.text('Capture'), findsOneWidget);
    expect(find.text('Comptage'), findsOneWidget);
    expect(find.text('Nom du personnage'), findsOneWidget);

    d.deleteSync(recursive: true);
  });

  testWidgets('un reglage donne par numero retrouve sa carte', (tester) async {
    // Les versions precedentes conservaient le numero. Il se decale des qu'une
    // carte apparait : on le ramene au nom de peripherique, qui ne bouge pas.
    final config = Config(personnages: const ['Kaska-yopette'])
      ..interface = '5';
    final d = dossierTemporaire();
    await monte(
      tester,
      session: sessionJouee(),
      archives: Archives(d.path),
      config: config,
    );

    await tester.tap(find.text('Réglages'));
    await tester.pump();
    await tester.tap(find.text('Capture'));
    await tester.pump();

    expect(
      config.interface,
      'devEthernet',
      reason: 'le numero devait etre ramene au peripherique',
    );
    expect(find.text('Ethernet'), findsWidgets);
    expect(find.textContaining('introuvable'), findsNothing);

    d.deleteSync(recursive: true);
  });

  testWidgets('les cartes virtuelles ne sont pas proposees', (tester) async {
    final d = dossierTemporaire();
    await monte(
      tester,
      session: sessionJouee(),
      archives: Archives(d.path),
      config: Config(personnages: const ['Kaska-yopette']),
    );

    await tester.tap(find.text('Réglages'));
    await tester.pump();
    await tester.tap(find.text('Capture'));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(ShadSelect<String>).first);
    await tester.pumpAndSettle();

    // Le jeu ne passe ni par un VPN ni par le Bluetooth : les proposer
    // n'offre que des facons de se tromper.
    expect(find.text('Ethernet'), findsWidgets);
    expect(find.textContaining('OpenVPN'), findsNothing);

    d.deleteSync(recursive: true);
  });

  testWidgets('les curseurs de transparence ont leur apercu', (tester) async {
    final d = dossierTemporaire();
    final config = Config(personnages: const ['Kaska-yopette'])
      ..opaciteFond = 60;
    await monte(
      tester,
      session: sessionJouee(),
      archives: Archives(d.path),
      config: config,
    );

    await tester.tap(find.text('Réglages'));
    await tester.pump();
    await tester.tap(find.text('Fenêtre'));
    await tester.pump();

    // La vue compacte elle-meme, sur une maquette : quatre lignes remplies,
    // pour juger un reglage sans basculer de vue, juger, revenir, corriger.
    expect(find.byType(VueCompacte), findsOneWidget);

    // Et posee sur un decor du jeu : une transparence se juge sur ce qui
    // passera vraiment dessous, pas sur un damier ni sur un aplat.
    final decors = tester
        .widgetList<DecoratedBox>(find.byType(DecoratedBox))
        .map((d) => d.decoration)
        .whereType<BoxDecoration>()
        .map((d) => d.image?.image)
        .whereType<AssetImage>()
        .map((a) => a.assetName)
        .toList();
    expect(decors, contains('assets/apercu_jeu.jpg'));
    for (final nom in ['Perso 1', 'Perso 2', 'Perso 3', 'Perso 4']) {
      expect(find.text(nom), findsOneWidget);
    }
    final avant = tester
        .widget<VueCompacte>(find.byType(VueCompacte))
        .opacites
        .fond;
    expect(avant, closeTo(0.6, 0.001));

    // Elle suit le curseur : c'est tout l\'interet.
    await tester.drag(find.byType(ShadSlider).first, const Offset(-200, 0));
    await tester.pump();
    final apres = tester
        .widget<VueCompacte>(find.byType(VueCompacte))
        .opacites
        .fond;
    expect(apres, lessThan(avant));

    // Verrouillee : sinon l\'apercu poserait ses zones de deplacement et la
    // fenetre des reglages suivrait la souris.
    expect(
      tester.widget<VueCompacte>(find.byType(VueCompacte)).verrouille,
      isTrue,
    );

    d.deleteSync(recursive: true);
  });

  testWidgets("le fond suit le texte quand celui-ci descend", (tester) async {
    final d = dossierTemporaire();
    final config = Config(personnages: const ['Kaska-yopette'])
      ..opaciteFond = 80
      ..opaciteTexte = 100;
    await monte(
      tester,
      session: sessionJouee(),
      archives: Archives(d.path),
      config: config,
    );

    await tester.tap(find.text('Réglages'));
    await tester.pump();
    await tester.tap(find.text('Fenêtre'));
    await tester.pump();

    // Le texte tombe au plancher ; le fond, qui ne peut pas le depasser, est
    // entraine avec lui.
    await tester.drag(find.byType(ShadSlider).last, const Offset(-400, 0));
    await tester.pump();
    expect(config.opaciteTexte, opaciteTexteMin);
    expect(config.opaciteFond, lessThanOrEqualTo(config.opaciteTexte));

    // Et la poignee du fond le montre. Sans cela, la barre annoncait 80 %
    // pendant que la valeur en valait 20.
    final poignees = tester
        .widgetList<ShadSlider>(find.byType(ShadSlider))
        .map((c) => c.controller?.value)
        .toList();
    expect(poignees.first, config.opaciteFond.toDouble());

    // Les parts hors d'atteinte se voient, voilees, aux deux bouts : sous le
    // plancher du texte, et au-dela du texte pour le fond.
    final voiles = tester
        .widgetList<FractionallySizedBox>(
          find.descendant(
            of: find.byType(IgnorePointer),
            matching: find.byType(FractionallySizedBox),
          ),
        )
        .map((v) => v.widthFactor)
        .toList();
    expect(voiles, contains(closeTo(opaciteTexteMin / 100, 0.001)));

    d.deleteSync(recursive: true);
  });

  testWidgets("le curseur se glisse, pas seulement se clique", (tester) async {
    final d = dossierTemporaire();
    final config = Config(personnages: const ['Kaska-yopette'])
      ..opaciteFond = 100
      ..opaciteTexte = 100;
    await monte(
      tester,
      session: sessionJouee(),
      archives: Archives(d.path),
      config: config,
    );

    await tester.tap(find.text('Réglages'));
    await tester.pump();
    await tester.tap(find.text('Fenêtre'));
    await tester.pump();

    // Un vrai glissement : on appuie, on avance par etapes, on relache. La
    // clef qui reconstruisait le curseur a chaque valeur remplacait son etat
    // en cours de route, et le geste mourait au premier pixel — il ne restait
    // qu'a cliquer sur une position.
    final barre = find.byType(ShadSlider).first;
    final geste = await tester.startGesture(tester.getCenter(barre));
    final large = tester.getSize(barre).width;
    var suivi = <int>[];
    for (var i = 0; i < 6; i++) {
      await geste.moveBy(Offset(-large / 12, 0));
      await tester.pump();
      suivi.add(config.opaciteFond);
    }
    await geste.up();
    await tester.pump();

    // La valeur descend etape par etape, et pas d'un seul bond : le premier
    // deplacement franchit le seuil de reconnaissance, les suivants suivent
    // le pointeur.
    expect(suivi.last, 0);
    expect(suivi.toSet().length, greaterThan(3));
    for (var i = 2; i < suivi.length; i++) {
      expect(suivi[i], lessThan(suivi[i - 1]));
    }

    d.deleteSync(recursive: true);
  });

  testWidgets("l'apercu s'arrete au bas de la fenetre", (tester) async {
    final d = dossierTemporaire();
    await monte(
      tester,
      session: sessionJouee(),
      archives: Archives(d.path),
      config: Config(personnages: const ['Kaska-yopette']),
      // La plus petite fenetre autorisee : c'est la que la place manque.
      taille: tailleMiniStandard,
    );

    await tester.tap(find.text('Réglages'));
    await tester.pump();
    await tester.tap(find.text('Fenêtre'));
    await tester.pump();

    // Le decor se cale sur la place restante au lieu d'une hauteur fixe :
    // sinon son bas passait sous le bord de la fenetre, et la page n'a pas
    // d'ascenseur pour aller l'y chercher.
    final decor = find.ancestor(
      of: find.byType(VueCompacte),
      matching: find.byType(ClipRRect),
    );
    final bas = tester.getRect(decor.first).bottom;
    expect(bas, lessThanOrEqualTo(tailleMiniStandard.height));

    d.deleteSync(recursive: true);
  });

  testWidgets("Pause et Reset se partagent la largeur", (tester) async {
    final d = dossierTemporaire();
    await monte(
      tester,
      session: sessionJouee(),
      archives: Archives(d.path),
      config: Config(personnages: const ['Kaska-yopette']),
    );

    // Reset etait une icone nue de trente-deux pixels : il fallait s'arreter
    // dessus pour apprendre qu'elle clot la session.
    expect(find.text('Reset'), findsOneWidget);
    expect(find.byIcon(LucideIcons.rotateCcw), findsOneWidget);
    final pause = tester.getSize(
      find.ancestor(of: find.text('Pause'), matching: find.byType(ShadButton)),
    );
    final reset = tester.getSize(
      find.ancestor(of: find.text('Reset'), matching: find.byType(ShadButton)),
    );
    expect(reset.width, closeTo(pause.width, 0.5));

    d.deleteSync(recursive: true);
  });

  testWidgets("en pause, les commandes tiennent encore dans le rail", (
    tester,
  ) async {
    final d = dossierTemporaire();
    final session = sessionJouee()..enPause = true;
    await monte(
      tester,
      session: session,
      archives: Archives(d.path),
      config: Config(personnages: const ['Kaska-yopette']),
    );

    // « Reprendre » est le plus long des deux libelles : c'est lui qui dit si
    // le rail est assez large pour deux boutons nommes.
    expect(find.text('Reprendre'), findsOneWidget);
    expect(tester.takeException(), isNull);

    d.deleteSync(recursive: true);
  });

  testWidgets("mettre en pause ne decale pas le rail", (tester) async {
    final d = dossierTemporaire();
    final session = sessionJouee();
    late StateSetter rebatit;
    await monte(
      tester,
      session: session,
      archives: Archives(d.path),
      config: Config(personnages: const ['Kaska-yopette']),
      // La pause appartient a la fenetre, pas a la coquille : on la joue
      // ici comme elle le fait, en reconstruisant apres coup.
      onPause: () => rebatit(() => session.enPause = true),
      capteur: (setter) => rebatit = setter,
    );

    final avant = tester.getRect(find.text('Sessions'));
    final commandes = tester.getRect(find.text('Reset'));

    await tester.tap(find.text('Pause'));
    await tester.pumpAndSettle();

    // Le badge « en pause » est plus haut que le chronometre qu'il rejoint :
    // sans hauteur reservee, la carte de session grandissait et tout ce qui
    // suit descendait de quelques pixels au moment du clic.
    expect(find.text('en pause'), findsOneWidget);
    expect(tester.getRect(find.text('Sessions')), avant);
    expect(tester.getRect(find.text('Reset')), commandes);

    d.deleteSync(recursive: true);
  });

  testWidgets("une interface porte son adresse materielle", (tester) async {
    final d = dossierTemporaire();
    await monte(
      tester,
      session: sessionJouee(),
      archives: Archives(d.path),
      config: Config(personnages: const ['Kaska-yopette'])
        ..interface = 'devWifi4',
      interfaces: const [
        Interface(
          numero: '2',
          libelle: 'Wi-Fi 4',
          device: 'devWifi4',
          mac: 'C2-BF-BE-6F-03-98',
        ),
      ],
    );

    await tester.tap(find.text('Réglages'));
    await tester.pump();
    await tester.tap(find.text('Capture'));
    await tester.pump();

    // Un pilote Wi-Fi moderne expose « Wi-Fi », « Wi-Fi 3 » et « Wi-Fi 4 » :
    // le nom seul ne dit pas laquelle porte le trafic, l'adresse se retrouve
    // dans l'interface du routeur.
    expect(find.textContaining('C2-BF-BE-6F-03-98'), findsWidgets);

    d.deleteSync(recursive: true);
  });

  testWidgets("sans pilote, le voyant le dit et mene a npcap", (tester) async {
    final d = dossierTemporaire();
    await monte(tester,
        session: sessionJouee(),
        archives: Archives(d.path),
        config: Config(personnages: const ['Kaska-yopette']),
        etat: EtatFlux.sansPilote,
        diagnostic: T.diagSansPilote);

    // Le libelle nomme ce qui manque, au lieu de « Capture indisponible » qui
    // laissait chercher.
    expect(find.text(T.fluxSansPilote), findsOneWidget);

    // Et le voyant devient une porte : c'est le seul etat que l'utilisateur
    // puisse corriger lui-meme.
    final cliquable = find.ancestor(
        of: find.text(T.fluxSansPilote), matching: find.byType(GestureDetector));
    expect(cliquable, findsWidgets);

    d.deleteSync(recursive: true);
  });

  testWidgets("connecte, le voyant n'est pas cliquable", (tester) async {
    final d = dossierTemporaire();
    await monte(tester,
        session: sessionJouee(),
        archives: Archives(d.path),
        config: Config(personnages: const ['Kaska-yopette']));

    expect(find.text(T.fluxConnecte), findsOneWidget);
    // Rien a ouvrir : un voyant vert qui reagit au clic ferait croire a une
    // action possible.
    expect(
        find.ancestor(
            of: find.text(T.fluxConnecte),
            matching: find.byType(GestureDetector)),
        findsNothing);

    d.deleteSync(recursive: true);
  });

  testWidgets('changer d\'onglet abandonne la sous-page', (tester) async {
    final d = dossierTemporaire();
    await monte(
      tester,
      session: sessionJouee(),
      archives: Archives(d.path),
      config: Config(personnages: const ['Kaska-yopette']),
    );

    await tester.tap(find.text('Kaska-yopette'));
    await tester.pump();
    expect(find.byIcon(LucideIcons.arrowLeft), findsOneWidget);

    await tester.tap(find.text('Réglages'));
    await tester.pump();
    // La pile repart de zero : plus rien ou revenir.
    expect(find.byIcon(LucideIcons.arrowLeft), findsNothing);

    d.deleteSync(recursive: true);
  });

  testWidgets('sans personnage, la page dit lequel des deux vides c\'est', (
    tester,
  ) async {
    final d = dossierTemporaire();
    await monte(
      tester,
      session: Session(),
      archives: Archives(d.path),
      config: Config(),
    );
    expect(find.text('Aucun personnage suivi'), findsOneWidget);

    await monte(
      tester,
      session: Session(const ['Kaska-nini', 'Kaska-panda']),
      archives: Archives(d.path),
      config: Config(personnages: const ['Kaska-nini', 'Kaska-panda']),
    );
    // Deux raisons differentes d'avoir un tableau vide, et les confondre
    // laisserait chercher un reglage qui n'y est pour rien.
    expect(find.text('En attente du jeu'), findsOneWidget);
    expect(find.textContaining('Aucun des 2 personnages'), findsOneWidget);

    d.deleteSync(recursive: true);
  });

  testWidgets('rien ne deborde a la taille minimale', (tester) async {
    final d = dossierTemporaire();
    await monte(
      tester,
      session: sessionJouee(),
      archives: Archives(d.path),
      config: Config(personnages: const ['Kaska-yopette', 'Kaska-nini']),
      taille: tailleMiniStandard,
    );
    expect(tester.takeException(), isNull);
    expect(find.byType(Rail), findsOneWidget);
    d.deleteSync(recursive: true);
  });

  testWidgets('les colonnes du tableau tiennent toutes dans le champ', (
    tester,
  ) async {
    final d = dossierTemporaire();
    await monte(
      tester,
      session: sessionJouee(),
      archives: Archives(d.path),
      config: Config(personnages: const ['Kaska-yopette']),
    );

    // Verifier la **presence** ne suffit pas : une colonne poussee hors du
    // champ reste construite et trouvable. On mesure donc son rectangle.
    final tableau = tester.getRect(find.byType(ShadTable));
    for (final libelle in ['PERSONNAGE', 'NIVEAU', 'EXPÉRIENCE', 'BUTIN']) {
      final entete = find.descendant(
        of: find.byType(ShadTable),
        matching: find.text(libelle),
      );
      expect(entete, findsOneWidget, reason: '$libelle manque');
      final rect = tester.getRect(entete);
      expect(
        rect.right,
        lessThanOrEqualTo(tableau.right + 1),
        reason: '$libelle sort du champ à droite',
      );
      expect(
        rect.left,
        greaterThanOrEqualTo(tableau.left - 1),
        reason: '$libelle sort du champ à gauche',
      );
    }

    d.deleteSync(recursive: true);
  });

  testWidgets('le butin regroupe les kamas et les ressources', (tester) async {
    final d = dossierTemporaire();
    final session = sessionJouee();
    await monte(
      tester,
      session: session,
      archives: Archives(d.path),
      config: Config(personnages: const ['Kaska-yopette']),
    );

    final suivi = session.suivis[cleDe('Kaska-yopette')]!;
    // 255 kamas en piece et deux Engrais a 1 567 : une seule colonne, qui
    // porte leur somme. La composition tient dans l'infobulle.
    expect(suivi.kamasPiece, 255);
    expect(suivi.kamasButin, 2 * 1567);
    expect(suivi.kamasTotal, 255 + 2 * 1567);
    expect(
      find.descendant(
        of: find.byType(ShadTable),
        matching: find.text(formateNombre(suivi.kamasTotal)),
      ),
      findsOneWidget,
    );
    // Les deux parts ne s'affichent pas a part dans le tableau.
    expect(
      find.descendant(
        of: find.byType(ShadTable),
        matching: find.text(formateNombre(suivi.kamasPiece)),
      ),
      findsNothing,
    );

    d.deleteSync(recursive: true);
  });

  testWidgets('le comptage des succes se regle et prend effet', (tester) async {
    final d = dossierTemporaire();
    final config = Config(personnages: const ['Kaska-yopette']);
    var applique = 0;
    await monte(
      tester,
      session: sessionJouee(),
      archives: Archives(d.path),
      config: config,
      onReglageChange: () => applique++,
    );

    expect(
      config.succesComptes,
      isTrue,
      reason: 'ces gains sont reels ; les cacher surprendrait davantage',
    );

    await tester.tap(find.text('Réglages'));
    await tester.pump();
    await tester.tap(find.text('Comptage'));
    await tester.pump();
    await tester.tap(find.byType(ShadSwitch));
    await tester.pump();

    // Chaque geste s'applique aussitot : il n'y a rien a valider.
    expect(config.succesComptes, isFalse);
    expect(applique, greaterThan(0));

    d.deleteSync(recursive: true);
  });

  testWidgets('les totaux comptent les challenges, pas les succes', (
    tester,
  ) async {
    final d = dossierTemporaire();
    final session = sessionJouee();
    await monte(
      tester,
      session: session,
      archives: Archives(d.path),
      config: Config(personnages: const ['Kaska-yopette']),
    );

    // Ce sont les challenges qu'on suit d'un combat a l'autre, et leur
    // rapport dit tout de suite si la soiree se passe bien.
    expect(find.text('CHALLENGES'), findsOneWidget);
    expect(find.text('SUCCÈS'), findsNothing);
    // La session jouee en a passe un sur deux.
    expect(session.historiqueChallenges.length, 2);
    expect(session.historiqueChallenges.where((c) => c.reussi).length, 1);
    expect(find.text('1/2'), findsOneWidget);

    d.deleteSync(recursive: true);
  });
}
