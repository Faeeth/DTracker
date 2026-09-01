/// Verrous sur la vue compacte.
///
/// Elle se pose au-dessus du jeu : translucide, et sans reponse au clic — un
/// clic destine au jeu ne doit pas ouvrir une fenetre.
///
/// Le survol, lui, fait paraitre ce qu'on va chercher quand on s'arrete : la
/// barre de titre et ses commandes, l'etat de la capture, les cadences. Au
/// repos il ne reste que le tableau et les totaux, et ces cas verifient les
/// deux etats. Le reste porte sur la palette : les deux vues montrent la meme
/// chose et doivent la montrer de la meme facon.
library;

import 'package:dofus_tracker/config.dart';
import 'package:dofus_tracker/modele/session.dart';
import 'package:dofus_tracker/source/flux.dart';
import 'package:dofus_tracker/source/ressources.dart';
import 'package:dofus_tracker/theme.dart';
import 'package:dofus_tracker/vue/barre.dart';
import 'package:dofus_tracker/vue/compacte.dart';
import 'package:dofus_tracker/vue/ligne.dart';
import 'package:dofus_tracker/vue/theme_shad.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shadcn_ui/shadcn_ui.dart' hide Cache;
import 'package:window_manager/window_manager.dart';

const qui = 'Kaska-yopette';
final ressourcesNues = Ressources('.');

/// Des ressources qui savent ou est le symbole des kamas.
///
/// Le depot de test n'a pas les images du jeu ; sans cette doublure, aucun
/// symbole ne serait dessine et le cas ne prouverait rien.
class ResAvecSymbole extends Ressources {
  ResAvecSymbole() : super('.');

  @override
  String? get imageKamas => 'images/icons/2x/kamas.png';
}

/// Une session jouee, a deux personnages par defaut.
///
/// Deux et non un : le pied ne porte ses totaux qu'a partir de deux
/// personnages — a un seul, le total **est** sa ligne.
Session sessionJouee(
    {bool enCombat = false, int personnages = 2, bool defis = false}) {
  final noms = [qui, 'Kaska-nini'].take(personnages).toList();
  final s = Session(noms)..nom = 'Session 1';
  s.definitClasses({for (final n in noms) n: 1});
  if (enCombat) {
    s.recoit({'ts': 1, 'type': 'FightStart', 'character': qui});
  }
  // Deux challenges, dont un seul tenu : c'est le rapport que la barre
  // affiche, et 1/1 ne distinguerait pas un compte d'un rapport. Le bonus est
  // annonce d'abord : sans lui, l'issue passe pour un objectif de boss et ne
  // compte pas comme challenge.
  if (defis) {
    s.recoit({
      'ts': 2,
      'type': 'ChallengeActive',
      'character': qui,
      'challenges': [
        [20, 60],
        [973, 85],
      ],
    });
    s.recoit({
      'ts': 5,
      'type': 'ChallengeResult',
      'character': qui,
      'challenge_id': 20,
      'succeeded': true,
    });
    s.recoit({
      'ts': 6,
      'type': 'ChallengeResult',
      'character': qui,
      'challenge_id': 973,
      'succeeded': false,
    });
  }
  s.recoit({
    'ts': 10,
    'type': 'FightEnd',
    'duration': 30,
    'participants': [
      {
        'name': qui,
        'level': 200,
        'xp': 4200,
        'kamas': 63,
        'outcome': 2,
        'loot': [
          {'item_id': 2663, 'quantity': 2, 'unit_price': 1567},
        ],
      },
      if (personnages > 1)
        {
          'name': 'Kaska-nini',
          'level': 199,
          'xp': 800,
          'kamas': 40,
          'outcome': 2,
          'loot': const [],
        },
    ],
  });
  if (enCombat) {
    s.recoit({'ts': 20, 'type': 'FightStart', 'character': qui});
  }
  return s;
}

Future<void> monte(
  WidgetTester tester, {
  Session? session,
  Ressources? res,
  int secondes = 3600,
  bool verrouille = true,
  Size taille = const Size(560, 260),
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
        home: VueCompacte(
          session: session ?? sessionJouee(),
          res: res ?? ressourcesNues,
          opacites: const Opacites(),
          secondes: secondes,
          etat: EtatFlux.connecte,
          diagnostic: 'La capture répond.',
          eclatDe: (_) => 0,
          personnagesConfigures: 1,
          verrouille: verrouille,
          onPause: () {},
          onReset: () {},
          onRenomme: (_) {},
          onVue: () {},
          onVerrou: () {},
          onQuitte: () {},
        ),
      ),
    ),
  );
  await tester.pump();
}

/// La couleur d'un texte de la ligne.
///
/// Cherche dans la ligne et non dans toute la fenetre : le pied reprend les
/// memes totaux, et un `find.text` nu en trouverait deux.
Color? teinteDeLaLigne(WidgetTester tester, String texte) => tester
    .widget<Text>(find.descendant(
        of: find.byType(LigneSuivi), matching: find.text(texte)))
    .style
    ?.color;

/// La couleur d'un texte unique dans la fenetre — un en-tete de colonne.
Color? teinteDe(WidgetTester tester, String texte) =>
    tester.widget<Text>(find.text(texte)).style?.color;

/// Amene la souris sur la vue, et l'y laisse.
Future<void> survole(WidgetTester tester) async {
  final souris = TestPointer(1, PointerDeviceKind.mouse);
  await tester.sendEventToBinding(souris.hover(const Offset(1, 1)));
  await tester.sendEventToBinding(
      souris.hover(tester.getCenter(find.byType(VueCompacte))));
  await tester.pumpAndSettle();
}

/// Des ressources qui savent aussi ou est le portrait de classe.
class ResAvecPortrait extends ResAvecSymbole {
  @override
  String? imageClasse(int? classe) => 'images/breeds/10.png';
}

/// Monte la vue avec des opacites choisies, comme le fait l'apercu des
/// reglages : chaque element porte alors la sienne, la ou la vraie fenetre
/// s'en remet a son opacite globale.
Future<void> monteAvecOpacites(WidgetTester tester, Opacites opacites) async {
  await tester.binding.setSurfaceSize(const Size(560, 260));
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
        home: VueCompacte(
          session: sessionJouee(),
          res: ResAvecPortrait(),
          opacites: opacites,
          secondes: 3600,
          etat: EtatFlux.connecte,
          diagnostic: '',
          eclatDe: (_) => 0,
          personnagesConfigures: 2,
          verrouille: true,
          onPause: () {},
          onReset: () {},
          onRenomme: (_) {},
          onVue: () {},
          onVerrou: () {},
          onQuitte: () {},
        ),
      ),
    ),
  );
  await tester.pump();
}

void main() {
  testWidgets('trois colonnes, sans le niveau', (tester) async {
    await monte(tester);
    for (final libelle in ['PERSONNAGE', 'EXPÉRIENCE', 'BUTIN']) {
      expect(find.text(libelle), findsOneWidget);
    }
    // Le niveau et sa barre ne se lisent pas d'un coup d'oeil au milieu d'un
    // combat, et prenaient un tiers de la largeur pour cela.
    expect(find.text('NIVEAU'), findsNothing);
    expect(find.text('200'), findsNothing);
    // En clair, et non dans le sourd du schema : la vue standard peut se
    // permettre un gris, elle a un fond a elle. Ici le decor du jeu passe
    // dessous, et le gris s'y noie des qu'on baisse le fond.
    expect(teinteDe(tester, 'PERSONNAGE')?.withValues(alpha: 1),
        schemaSombre.foreground);
  });

  testWidgets('tous les textes portent leur ombre', (tester) async {
    await monte(tester, secondes: 3600);
    await survole(tester);

    // La vue est posee sur un jeu, pas sur un fond connu : selon la carte, un
    // texte nu se detache ou se noie. C'est aussi ce qui permet de renoncer
    // aux bordures, qui tranchaient a faible opacite.
    final nus = tester
        .widgetList<Text>(find.byType(Text))
        .where((t) => (t.data ?? '').trim().isNotEmpty)
        .where((t) => t.style?.shadows == null || t.style!.shadows!.isEmpty)
        .map((t) => t.data)
        .toList();
    expect(nus, isEmpty, reason: 'ces textes sont sans ombre : $nus');
  });

  testWidgets('aucun filet ne cerne la vue ni ses lignes', (tester) async {
    await monte(tester);
    // A dix ou vingt pour cent de fond, un filet tranche plus qu'il ne
    // delimite : c'est l'ombre des textes qui pose les surfaces.
    final cernes = tester
        .widgetList<Container>(find.byType(Container))
        .map((c) => c.decoration)
        .whereType<BoxDecoration>()
        .where((d) => d.border != null)
        .toList();
    expect(cernes, isEmpty);
  });

  testWidgets('le butin est en or, l\'experience en clair', (tester) async {
    await monte(tester);
    // Les memes couleurs que les colonnes du tableau : ce qu'on compte est en
    // or, le reste se lit sans appeler.
    expect(
        teinteDeLaLigne(tester, formateNombre(63 + 2 * 1567))
            ?.withValues(alpha: 1),
        schemaSombre.primary);
    expect(teinteDeLaLigne(tester, formateNombre(4200))?.withValues(alpha: 1),
        TeinteCompacte.texte);
  });

  testWidgets('aucune infobulle ne surgit sur une ligne', (tester) async {
    await monte(tester);
    final souris = TestPointer(1, PointerDeviceKind.mouse);
    await tester.sendEventToBinding(souris.hover(const Offset(1, 1)));
    await tester.sendEventToBinding(
      souris.hover(tester.getCenter(find.byType(LigneSuivi).first)),
    );
    await tester.pumpAndSettle();

    // Une infobulle par-dessus le terrain de combat gene plus qu'elle
    // n'aide : la ligne se lit, elle ne se manipule pas. Le survol fait
    // paraitre le titre et l'etat, pas des bulles sur les chiffres.
    expect(find.textContaining('Kamas en pièce'), findsNothing);
    expect(find.textContaining('du niveau'), findsNothing);
  });

  testWidgets('au repos, rien que le tableau et les totaux', (tester) async {
    await monte(tester, secondes: 3600);

    // Le tableau et ce qu'il a rapporte : c'est tout ce qu'on regarde en
    // jouant.
    expect(find.text('PERSONNAGE'), findsOneWidget);
    expect(find.textContaining('XP'), findsWidgets);

    // Les cadences aussi : c'est le chiffre qu'on surveille en farmant, et le
    // releguer au survol obligeait a poser la souris pour savoir si la soiree
    // avance bien.
    expect(find.textContaining('xp/h'), findsOneWidget);
    expect(find.textContaining('kamas/h'), findsOneWidget);

    // Mais ni la barre de titre ni l'etat de la capture : on va les chercher
    // quand on s'arrete, et les laisser a l'ecran encombre la seule vue faite
    // pour ne pas encombrer.
    expect(find.byType(BarreDeTitre), findsNothing);
    expect(find.text('Connecté'), findsNothing);

    // La bande de combat a disparu pour de bon : cette vue n'est pas faite
    // pour suivre un combat.
    expect(find.textContaining('Hors combat'), findsNothing);
    expect(find.textContaining('En combat'), findsNothing);
  });

  testWidgets('au survol, le titre et l\'etat paraissent', (tester) async {
    await monte(tester, secondes: 3600);
    await survole(tester);

    expect(find.byType(BarreDeTitre), findsOneWidget);
    // En glyphes, non en toutes lettres : la barre compacte loge deja la
    // marque, le minuteur, deux compteurs et le nom de la session.
    expect(find.byIcon(Icons.pause), findsOneWidget);
    expect(find.byIcon(Icons.refresh), findsOneWidget);
    expect(find.text('Connecté'), findsOneWidget);
    // Abregee : le pied fait cinq cents pixels et porte deja l'etat et les
    // totaux. « 1,2 M xp/h » y dit l'essentiel.
    expect(find.textContaining('${formateCourt(5000)} xp/h'), findsOneWidget);
  });

  testWidgets('le titre compte les combats de la session', (tester) async {
    await monte(tester, secondes: 3600);
    await survole(tester);

    // Le chronometre et le compte disent la meme chose — ce que la soiree a
    // dure, et ce qu'elle a enchaine — et se lisent cote a cote.
    expect(find.text('1'), findsOneWidget);
    expect(find.byIcon(LucideIcons.swords), findsOneWidget);
    final chrono = tester.getRect(find.text(formateDuree(3600)));
    final compte = tester.getRect(find.text('1'));
    final session = tester.getRect(find.text('Session 1'));
    expect(compte.left, greaterThan(chrono.left));
    expect(compte.left, lessThan(session.left));
  });

  testWidgets('la marque s\'appelle DTracker', (tester) async {
    await monte(tester);
    await survole(tester);
    expect(find.text('DTracker'), findsOneWidget);
    expect(find.text('DOFUS'), findsNothing);
  });

  testWidgets('la cadence attend cinq minutes', (tester) async {
    // Le meme seuil que la vue standard : sur quatre minutes, un seul combat
    // donne des chiffres a l'heure qui ne veulent rien dire.
    await monte(tester, secondes: 240);
    await survole(tester);
    expect(find.textContaining('xp/h'), findsNothing);
  });

  testWidgets('les totaux ne bougent pas au survol', (tester) async {
    await monte(tester, secondes: 3600);
    final repos = tester.getRect(find.text('${formateNombre(5000)} XP'));

    await survole(tester);
    final anime = tester.getRect(find.text('${formateNombre(5000)} XP'));

    // L'etat et les cadences paraissent a gauche : ils ne doivent pas
    // deplacer le seul chiffre qu'on est en train de lire.
    expect(anime, repos);
  });

  testWidgets('la hauteur ne bouge pas au survol', (tester) async {
    await monte(tester, secondes: 3600);
    final repos = tester.getRect(find.byType(LigneSuivi).first);

    await survole(tester);
    final anime = tester.getRect(find.byType(LigneSuivi).first);

    // La bande du titre est reservee dans les deux etats : la faire
    // apparaitre en poussant le tableau ferait sauter ce qu'on est en train
    // de lire.
    expect(anime, repos);
  });

  testWidgets('le cadenas ferme empeche tout deplacement', (tester) async {
    // Ouvert : la fenetre se saisit par le corps **et** par la barre de
    // titre. C'est le sens du cadenas ouvert.
    await monte(tester, verrouille: false);
    expect(find.byType(DragToMoveArea), findsWidgets);

    // Et le corps entier, pas seulement une bande : une zone posee **sous**
    // le contenu ne recevait rien — le fond de la vue est opaque au pointeur
    // et l'interceptait le premier.
    final vue = tester.getRect(find.byType(VueCompacte));
    final prises = tester
        .widgetList<DragToMoveArea>(find.byType(DragToMoveArea))
        .length;
    expect(prises, greaterThan(0));
    final surface = find
        .byType(DragToMoveArea)
        .evaluate()
        .map((e) => tester.getRect(find.byWidget(e.widget)))
        .fold<double>(0, (somme, r) => somme + r.height);
    expect(surface, greaterThanOrEqualTo(vue.height - 1),
        reason: 'la fenetre ne se saisit que par une partie de sa surface');

    // Ferme : plus aucune prise. Le verrou ne portait que sur le corps, et la
    // barre de titre gardait les siennes — un cadenas qui ne verrouille
    // qu'une partie ne verrouille rien.
    await monte(tester);
    expect(find.byType(DragToMoveArea), findsNothing);
  });

  testWidgets('le total des kamas porte son symbole', (tester) async {
    await monte(tester, res: ResAvecSymbole());

    // Deux lignes et un total : trois symboles, chacun peint deux fois — une
    // ombre noire floutee, puis le glyphe dore par-dessus.
    expect(find.byType(Image), findsNWidgets(6));

    // Le symbole ferme la ligne : il vient apres le chiffre, pas avant.
    final total = formateNombre(63 + 2 * 1567 + 40);
    final pied = tester.getRect(find.text(total));
    final symbole = tester.getRect(find.byType(Image).last);
    expect(symbole.left, greaterThan(pied.left));
  });

  testWidgets('a un seul personnage, pas de total', (tester) async {
    await monte(tester, session: sessionJouee(personnages: 1));
    // Le total **est** sa ligne : le repeter dessous n'ajoute rien et prend
    // la place qu'on economise ailleurs.
    expect(find.text('${formateNombre(4200)} XP'), findsNothing);
    expect(find.byType(LigneSuivi), findsOneWidget);

    // Des deux personnages, il reparait.
    await monte(tester);
    expect(find.text('${formateNombre(5000)} XP'), findsOneWidget);
  });

  testWidgets('rien d\'opaque ne se glisse derriere la vue', (tester) async {
    await monte(tester);

    // `ShadAppBuilder` peint un fond **opaque** par defaut, derriere toute
    // l'application. La vue compacte avait beau peindre le sien a vingt pour
    // cent, ce bleu-la restait dessous : le curseur « Fond » ne semblait agir
    // que sur les bordures. L'habillage partage le rend transparent, et ce
    // cas monte le meme habillage que l'application — c'est la divergence
    // entre les deux qui avait laisse passer le defaut.
    final opaques = tester
        .widgetList<ColoredBox>(find.byType(ColoredBox))
        .where((b) => b.color.a == 1.0)
        .toList();
    expect(opaques, isEmpty,
        reason: 'un aplat opaque derriere la vue annule la transparence');
  });

  testWidgets('les textes sont gras', (tester) async {
    await monte(tester, secondes: 3600);
    await survole(tester);
    final maigres = tester
        .widgetList<Text>(find.byType(Text))
        .where((t) => (t.data ?? '').trim().isNotEmpty)
        .where((t) => (t.style?.fontWeight?.value ?? 0) < grasCompacte.value)
        .map((t) => t.data)
        .toList();
    // Les traits fins se hachent sur un decor charge : la lettre garde sa
    // forme mais perd son trait, et le chiffre devient penible a lire d'un
    // coup d'oeil — le seul usage de cette vue.
    expect(maigres, isEmpty, reason: 'textes trop maigres : $maigres');
  });

  testWidgets("l'ombre et les portraits suivent l'opacite du texte", (
    tester,
  ) async {
    await monteAvecOpacites(tester, const Opacites(fond: 0.8, texte: 0.3));

    // L'ombre s'efface avec la lettre. Fixe, elle restait noire et pleine
    // pendant que le texte palissait : le glyphe virait au gris puis au noir
    // au lieu de disparaitre.
    final ombre = tester
        .widget<Text>(find.text(formateNombre(4200)))
        .style!
        .shadows!
        .first;
    expect(ombre.color.a, lessThan(0.35));

    // Le portrait aussi : c'est une donnee qu'on lit, au meme titre qu'un nom.
    final voiles = tester.widgetList<Opacity>(find.descendant(
        of: find.byType(LigneSuivi), matching: find.byType(Opacity)));
    expect(voiles.any((o) => (o.opacity - 0.3).abs() < 0.001), isTrue);
  });

  testWidgets("au survol, le fond englobe la barre de titre", (tester) async {
    await monte(tester);
    final auRepos = tester.getRect(find.byType(VueCompacte));

    await survole(tester);
    final fond = tester.widgetList<Container>(find.byType(Container)).firstWhere(
        (c) => c.decoration is BoxDecoration &&
            (c.decoration! as BoxDecoration).color != null);

    // Les quatre coins restent arrondis. Peindre le corps seul et compter sur
    // la barre pour coiffer le haut donnait deux pointes carrees sous une
    // barre restee transparente : la barre n'a pas de fond a elle.
    final coins = (fond.decoration! as BoxDecoration).borderRadius!
        .resolve(TextDirection.ltr);
    expect(coins.topLeft.y, greaterThan(0));
    expect(coins.topRight.y, greaterThan(0));

    // Et il monte jusqu'a la barre : le titre, le minuteur et les boutons se
    // lisent sur le fond, pas sur le jeu.
    final peint = tester.getRect(find.byWidget(fond));
    final barre = tester.getRect(find.byType(BarreDeTitre));
    expect(peint.top, lessThanOrEqualTo(barre.top));
    expect(peint.top, closeTo(auRepos.top, 0.5));
  });

  testWidgets("la barre porte les challenges de la session", (tester) async {
    // A la plus petite fenetre autorisee : c'est la que la barre est le plus
    // chargee — marque, minuteur, combats, challenges, nom et six boutons.
    await monte(tester,
        session: sessionJouee(defis: true),
        taille: Size(tailleMiniCompacte.width, 260));
    await survole(tester);
    expect(tester.takeException(), isNull);

    // A cote du compte de combats, et sous la meme forme qu'en vue standard :
    // ce qu'on a tenu sur ce qui est tombe.
    expect(find.text('1/2'), findsOneWidget);
    expect(find.byIcon(LucideIcons.target), findsOneWidget);
  });

  testWidgets("aucune marque de combat sur la ligne", (tester) async {
    await monte(tester, session: sessionJouee(enCombat: true));

    // Le fond de la fenetre dit deja que le groupe se bat. Un lisere par
    // personnage faisait une tache de couleur de plus sur une surcouche qui
    // doit se faire oublier.
    final liseres = tester
        .widgetList<ColoredBox>(find.descendant(
            of: find.byType(LigneSuivi), matching: find.byType(ColoredBox)))
        .where((b) => b.color.a > 0)
        .toList();
    expect(liseres, isEmpty);
  });

  testWidgets('le combat se voit au fond et au lisere', (tester) async {
    await monte(tester);
    final horsCombat = fondDeLaFenetre(tester);

    await monte(tester, session: sessionJouee(enCombat: true));
    final enCombat = fondDeLaFenetre(tester);

    // Faute de place pour l'ecrire, c'est le fond qui le dit.
    expect(enCombat, isNot(horsCombat));
    expect(enCombat?.withValues(alpha: 1), TeinteCompacte.combat);
  });
}

/// Le fond de la fenetre compacte : le premier `Container` decore.
Color? fondDeLaFenetre(WidgetTester tester) => tester
    .widgetList<Container>(find.byType(Container))
    .map((c) => c.decoration)
    .whereType<BoxDecoration>()
    .map((d) => d.color)
    .firstOrNull;
