/// Les macros : ce qui s'ecrit dans les reglages, ce qui part au clavier, et
/// le partage des touches avec l'Organizer.
library;

import 'dart:convert';
import 'dart:io';

import 'package:dofus_tracker/config.dart';
import 'package:dofus_tracker/modele/macro.dart';
import 'package:dofus_tracker/modele/raccourci.dart';
import 'package:dofus_tracker/source/macros.dart';
import 'package:dofus_tracker/source/organizer.dart';
import 'package:dofus_tracker/source/raccourcis.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Retient ce qui serait parti au clavier, au lieu de le taper.
class _PontEspion extends PontOrganizer {
  _PontEspion() : super(canal: const MethodChannel('test/macros'));

  List<LiaisonNative> dernieres = const [];

  /// Les tables successives, par signature : c'est ainsi qu'on voit ce qui
  /// reste enregistre pendant qu'une macro joue.
  final List<List<String>> tables = [];
  Set<String> refuses = <String>{};

  /// Les fenetres qui existent, pour `window.focus`.
  Set<String> fenetres = {'Kaska-yopette'};

  /// Ce qui tient le clavier, quand le cas veut l'imposer — pour jouer le
  /// refus de Windows de changer le premier plan.
  String? devant;

  /// Ce que la derniere activation a reellement mis devant.
  String _devantReel = '';

  /// Le premier plan appartient-il au jeu ? Faux fait tout refuser, comme le
  /// natif.
  bool jeuDevant = true;

  /// La cadence demandee pour chaque texte, en millisecondes.
  final List<int> cadences = [];

  /// Ce qui a ete fait, dans l'ordre : `texte:...`, `touche:...`,
  /// `fenetre:...`, `suspendu:...`.
  final List<String> gestes = [];

  @override
  void ecoute() {}

  @override
  Future<Set<String>> applique(List<LiaisonNative> liaisons) async {
    dernieres = liaisons;
    tables.add([for (final l in liaisons) l.id]);
    return refuses;
  }

  @override
  Future<void> suspend({required bool suspendu}) async {
    gestes.add('suspendu:$suspendu');
  }

  @override
  Future<bool> active(String titre) async {
    gestes.add('fenetre:$titre');
    if (fenetres.contains(titre)) {
      _devantReel = titre;
      return true;
    }
    return false;
  }

  @override
  Future<String> fenetreDevant() async => devant ?? _devantReel;

  @override
  Future<bool> premierPlanEstLeJeu() async => jeuDevant;

  @override
  Future<bool> envoieTexte(String texte, {int cadence = 0}) async {
    if (!jeuDevant) return false;
    gestes.add('texte:$texte');
    cadences.add(cadence);
    return true;
  }

  @override
  Future<bool> envoieTouche(Raccourci raccourci) async {
    gestes.add('touche:${raccourci.affichage}');
    return true;
  }

  @override
  Future<bool> clique(int x, int y, {bool droit = false}) async {
    if (!jeuDevant) return false;
    gestes.add('clic:$x,$y${droit ? ':droit' : ''}');
    return true;
  }
}

const _f10 = Raccourci(touche: 0x79, libelle: 'F10');
const _f1 = Raccourci(touche: 0x70, libelle: 'F1');
const _entree = Raccourci(touche: 0x0D, libelle: 'Entrée');

void main() {
  late Directory dossier;
  late Config config;
  late _PontEspion pont;
  late Raccourcis raccourcis;
  late Macros macros;

  /// Les attentes demandees, plutot que subies : un cas ne doit pas passer une
  /// seconde a regarder une macro se derouler.
  late List<int> attentes;

  setUp(() async {
    dossier = await Directory.systemTemp.createTemp('macros_test');
    config = Config();
    pont = _PontEspion();
    raccourcis = Raccourcis(pont: pont);
    attentes = [];
    macros = Macros(
      config: config,
      raccourcis: raccourcis,
      attend: (duree) async => attentes.add(duree.inMilliseconds),
    );
    await macros.demarre();
  });

  tearDown(() async {
    macros.dispose();
    if (dossier.existsSync()) await dossier.delete(recursive: true);
  });

  /// La macro d'invitation de groupe, celle qu'on ecrivait en AutoHotkey.
  Macro invitation() {
    final macro = macros.ajoute('Inviter le groupe');
    macros.modifie(
      macro.id,
      raccourci: _f10,
      etapes: const [
        EtapeTouche(_entree),
        EtapePause(100),
        EtapeTexte('/invite Kaska-Feca'),
        EtapeTouche(_entree),
        EtapePause(200),
      ],
    );
    return macros.parId(macro.id)!;
  }

  group('l exemple livre', () {
    test('un premier lancement recoit la macro d exemple', () async {
      // Rien dans les reglages : personne n'a encore rien dit des macros.
      final neuve = await Config.charge(dossier.path);
      final exemple = neuve.macros.single;
      expect(exemple.nom, 'Inviter dans le groupe');
      expect(exemple.actif, isFalse, reason: 'elle se lit, elle ne part pas');
      expect(exemple.raccourci, isNull);
      expect(exemple.variables.single.nom, 'mes_persos');
    });

    test('une liste vide reste vide', () async {
      // Qui supprime l'exemple ne doit pas le voir revenir au lancement
      // suivant.
      await Config.fichier(dossier.path).writeAsString(jsonEncode({
        'macros': <Object>[],
      }));
      expect((await Config.charge(dossier.path)).macros, isEmpty);
    });
  });

  group('reglages', () {
    test('une macro se relit telle qu on l a ecrite', () async {
      final macro = invitation();
      macros.modifie(macro.id, cible: 'Kaska-yopette');
      await macros.synchronise;
      await config.enregistre(dossier.path);

      final relue = (await Config.charge(dossier.path)).macros.single;
      expect(relue.nom, 'Inviter le groupe');
      expect(relue.raccourci, _f10);
      expect(relue.cible, 'Kaska-yopette');
      expect(relue.etapes, [
        const EtapeTouche(_entree),
        const EtapePause(100),
        const EtapeTexte('/invite Kaska-Feca'),
        const EtapeTouche(_entree),
        const EtapePause(200),
      ]);
      expect(relue.attente, 300);
    });

    test('un fichier ecrit a la main est lu', () async {
      await Config.fichier(dossier.path).writeAsString(jsonEncode({
        'macros': [
          {
            'id': 'm1',
            'name': 'Inviter',
            'enabled': true,
            'shortcut': {'key_code': 121, 'modifiers': 0, 'key_name': 'F10'},
            'steps': [
              {'type': 'key', 'key': {'key_code': 13, 'key_name': 'Entrée'}},
              {'type': 'sleep', 'ms': 100},
              {'type': 'text', 'text': '/invite Kaska-Feca'},
            ],
          },
        ],
      }));

      final relue = (await Config.charge(dossier.path)).macros.single;
      expect(relue.etapes, hasLength(3));
      expect(relue.etapes.last, const EtapeTexte('/invite Kaska-Feca'));
      expect(relue.lie, isTrue);
    });

    test('un geste inconnu est ignore, le reste survit', () async {
      // Un fichier venu d'une version plus recente, ou edite de travers : on
      // ne veut pas perdre la macro entiere pour un geste qu'on ne sait pas
      // lire.
      await Config.fichier(dossier.path).writeAsString(jsonEncode({
        'macros': [
          {
            'id': 'm1',
            'name': 'Inviter',
            'steps': [
              {'type': 'clic', 'x': 10},
              {'type': 'text', 'text': 'bonjour'},
            ],
          },
        ],
      }));

      final relue = (await Config.charge(dossier.path)).macros.single;
      expect(relue.etapes, [const EtapeTexte('bonjour')]);
    });
  });

  group('ce qui part au clavier', () {
    test('les gestes partent dans l ordre', () async {
      await macros.joue(invitation());

      expect(pont.gestes, [
        'suspendu:true',
        'touche:Entrée',
        'texte:/invite Kaska-Feca',
        'touche:Entrée',
        'suspendu:false',
      ]);
      expect(attentes, [100, 200]);
    });

    test('les touches globales sont relachees pendant le jeu', () async {
      // Sans cela, une macro qui envoie Entree ou une touche de fonction se
      // declencherait elle-meme.
      await macros.joue(invitation());
      expect(pont.gestes.first, 'suspendu:true');
      expect(pont.gestes.last, 'suspendu:false');
    });

    test('la fenetre visee passe devant avant le premier geste', () async {
      final macro = invitation();
      macros.modifie(macro.id, cible: 'Kaska-yopette');
      await macros.joue(macros.parId(macro.id)!);

      expect(pont.gestes[1], 'fenetre:Kaska-yopette');
      expect(pont.gestes[2], 'touche:Entrée');
      // L'attente qui laisse le jeu prendre le clavier, avant celles ecrites
      // dans la macro.
      expect(attentes.first, greaterThan(0));
      expect(attentes.length, 3);
    });

    test('si la fenetre ne passe pas devant, rien n est tape', () async {
      // Windows refuse parfois le changement de premier plan sans le dire —
      // un jeu en plein ecran garde la main. Sans ce controle, les frappes
      // partaient dans la fenetre qui s'y trouvait, et une commande de jeu
      // est bel et bien partie dans le mauvais client.
      pont.devant = 'Dofus';
      final macro = invitation();
      macros.modifie(macro.id, cible: 'Kaska-yopette');
      await macros.joue(macros.parId(macro.id)!);

      expect(
        pont.gestes.where((g) => g.startsWith('texte:') || g.startsWith('touche:')),
        isEmpty,
      );
      expect(macros.dernierJeu!.reussi, isFalse);
      expect(macros.dernierJeu!.obstacle, 'Dofus');
    });

    test('sans la fenetre visee, rien n est tape', () async {
      final macro = invitation();
      macros.modifie(macro.id, cible: 'Personne');
      await macros.joue(macros.parId(macro.id)!);

      expect(pont.gestes, ['suspendu:true', 'fenetre:Personne', 'suspendu:false']);
      expect(macros.dernierJeu!.reussi, isFalse);
      expect(macros.dernierJeu!.fenetreIntrouvable, 'Personne');
    });

    test('un second appui arrete celle qui joue', () async {
      // La macro s'arrete a la premiere attente : c'est la que le second appui
      // arrive, et il ne doit pas en lancer une deuxieme.
      final macro = invitation();
      final joue = macros.joue(macro);
      await macros.joue(macro);
      await joue;

      expect(macros.enCours, isNull);
      expect(
        pont.gestes.where((g) => g.startsWith('texte:')),
        isEmpty,
        reason: 'le texte vient apres la premiere attente',
      );
    });
  });

  group('boucles et variables', () {
    test('une boucle parcourt les valeurs d une variable', () async {
      // C'est le script AutoHotkey d'origine, mot pour mot : trois noms, et
      // pour chacun la meme suite de gestes.
      final macro = macros.ajoute('Inviter');
      macros.modifie(
        macro.id,
        variables: const [
          Variable(
            nom: 'noms',
            valeurs: ['Kaska-Feca', 'Kaska-Enu', 'Kaska-Ougi'],
          ),
        ],
        etapes: const [
          EtapeBoucle(
            liste: 'noms',
            etapes: [
              EtapeTouche(_entree),
              EtapePause(100),
              EtapeTexte('/invite {noms}'),
              EtapeTouche(_entree),
              EtapePause(200),
            ],
          ),
        ],
      );
      await macros.joue(macros.parId(macro.id)!);

      expect(pont.gestes.where((g) => g.startsWith('texte:')), [
        'texte:/invite Kaska-Feca',
        'texte:/invite Kaska-Enu',
        'texte:/invite Kaska-Ougi',
      ]);
      expect(attentes, [100, 200, 100, 200, 100, 200]);
    });

    test('une boucle sans variable compte ses tours', () async {
      final macro = macros.ajoute('Trois fois');
      macros.modifie(macro.id, etapes: const [
        EtapeBoucle(repetitions: 3, etapes: [EtapeTexte('a')]),
      ]);
      await macros.joue(macros.parId(macro.id)!);
      expect(pont.gestes.where((g) => g == 'texte:a'), hasLength(3));
    });

    test('une variable inconnue ne fait aucun tour', () async {
      // Plutot qu'un tour a vide, qui enverrait le texte avec `{nom}` dedans.
      final macro = macros.ajoute('Perdue');
      macros.modifie(macro.id, etapes: const [
        EtapeBoucle(liste: 'personne', etapes: [EtapeTexte('/invite {personne}')]),
      ]);
      await macros.joue(macros.parId(macro.id)!);
      expect(pont.gestes.where((g) => g.startsWith('texte:')), isEmpty);
    });

    test('hors d une boucle, une variable n est pas interpretee', () async {
      // Une accolade est un caractere comme un autre, et le jeu en accepte :
      // substituer partout aurait rendu impossible d'en taper une.
      final macro = macros.ajoute('Bonjour');
      macros.modifie(
        macro.id,
        variables: const [Variable(nom: 'canal', valeurs: ['/b'])],
        etapes: const [EtapeTexte('{canal} bonjour')],
      );
      await macros.joue(macros.parId(macro.id)!);
      expect(pont.gestes, contains('texte:{canal} bonjour'));
    });

    test('dans la boucle qui la parcourt, la variable vaut le tour', () async {
      final macro = macros.ajoute('Deux');
      macros.modifie(
        macro.id,
        variables: const [Variable(nom: 'noms', valeurs: ['A', 'B'])],
        etapes: const [
          EtapeTexte('{noms} avant'),
          EtapeBoucle(liste: 'noms', etapes: [EtapeTexte('{noms} dedans')]),
        ],
      );
      await macros.joue(macros.parId(macro.id)!);
      expect(pont.gestes.where((g) => g.startsWith('texte:')), [
        'texte:{noms} avant',
        'texte:A dedans',
        'texte:B dedans',
      ]);
    });

    test('un nom inconnu reste tel quel', () async {
      // Le faire disparaitre laisserait croire a une macro qui marche.
      final macro = macros.ajoute('Trou');
      macros.modifie(macro.id, etapes: const [EtapeTexte('/invite {inconnu}')]);
      await macros.joue(macros.parId(macro.id)!);
      expect(pont.gestes, contains('texte:/invite {inconnu}'));
    });

    test('les boucles s imbriquent, la variable du dehors survit', () async {
      final macro = macros.ajoute('Deux niveaux');
      macros.modifie(
        macro.id,
        variables: const [Variable(nom: 'noms', valeurs: ['A', 'B'])],
        etapes: const [
          EtapeBoucle(
            liste: 'noms',
            etapes: [
              EtapeBoucle(repetitions: 2, etapes: [EtapeTexte('{noms}')]),
            ],
          ),
        ],
      );
      await macros.joue(macros.parId(macro.id)!);
      expect(pont.gestes.where((g) => g.startsWith('texte:')), [
        'texte:A',
        'texte:A',
        'texte:B',
        'texte:B',
      ]);
    });

    test('la cadence de frappe accompagne le texte', () async {
      // Une frappe humaine plutot qu'un bloc jete d'un coup : certaines
      // fenetres refusent la suite d'un texte arrive trop vite.
      final macro = macros.ajoute('Cadence');
      macros.modifie(macro.id, etapes: const [
        EtapeTexte('vite'),
        EtapeTexte('lentement', cadence: 60),
      ]);
      await macros.joue(macros.parId(macro.id)!);

      expect(pont.cadences, [EtapeTexte.cadenceParDefaut, 60]);
    });

    test('les trois rythmes sont ceux qu on propose', () async {
      // Un nombre libre demandait a l'utilisateur de deviner ce qu'il ne peut
      // pas savoir : trois choix nommes couvrent ce qu'on a rencontre.
      expect(EtapeTexte.cadences, [50, 30, 20], reason: 'du plus lent au plus rapide');
      expect(EtapeTexte.cadenceParDefaut, 30);

      final macro = macros.ajoute('Lent');
      macros.modifie(macro.id, etapes: const [
        EtapeTexte('a', cadence: EtapeTexte.cadenceLente),
      ]);
      await macros.joue(macros.parId(macro.id)!);
      expect(pont.cadences, [50]);
    });

    test('la cadence par defaut est le rythme normal', () async {
      final macro = macros.ajoute('Defaut');
      macros.modifie(macro.id, etapes: const [EtapeTexte('bonjour')]);
      await macros.joue(macros.parId(macro.id)!);
      expect(pont.cadences, [EtapeTexte.cadenceNormale]);
    });

    test('la cadence se relit dans les reglages', () async {
      final macro = macros.ajoute('Cadence');
      macros.modifie(macro.id, etapes: const [EtapeTexte('a', cadence: 40)]);
      await macros.synchronise;
      await config.enregistre(dossier.path);

      final relue = (await Config.charge(dossier.path)).macros.single;
      expect(relue.etapes.single, const EtapeTexte('a', cadence: 40));
    });

    test('un clic part avec ses coordonnees', () async {
      final macro = macros.ajoute('Clic');
      macros.modifie(macro.id, etapes: const [
        EtapeClic(120, 340),
        EtapeClic(10, 20, droit: true),
      ]);
      await macros.joue(macros.parId(macro.id)!);
      expect(pont.gestes, containsAllInOrder(['clic:120,340', 'clic:10,20:droit']));
    });

    test('la macro entiere se relit telle qu on l a ecrite', () async {
      final macro = macros.ajoute('Inviter');
      macros.modifie(
        macro.id,
        variables: const [Variable(nom: 'noms', valeurs: ['A', 'B'])],
        etapes: const [
          EtapeClic(5, 6, droit: true),
          EtapeBoucle(liste: 'noms', etapes: [EtapeTexte('{noms}')]),
          EtapeBoucle(repetitions: 4, etapes: [EtapePause(50)]),
        ],
      );
      await macros.synchronise;
      await config.enregistre(dossier.path);

      final relue = (await Config.charge(dossier.path)).macros.single;
      expect(relue.variables, [
        const Variable(nom: 'noms', valeurs: ['A', 'B']),
      ]);
      expect(relue.etapes, [
        const EtapeClic(5, 6, droit: true),
        const EtapeBoucle(liste: 'noms', etapes: [EtapeTexte('{noms}')]),
        const EtapeBoucle(repetitions: 4, etapes: [EtapePause(50)]),
      ]);
      expect(relue.nombreDActions, 5);
    });
  });

  group('le jeu seul', () {
    test('hors du jeu, la macro s arrete au premier geste', () async {
      // Une macro qui part alors qu'on a bascule ailleurs ecrirait sa commande
      // dans un navigateur ou une conversation. C'est arrive.
      pont.jeuDevant = false;
      pont.devant = 'Brave';
      final macro = macros.ajoute('Deux textes');
      macros.modifie(macro.id, etapes: const [
        EtapeTexte('premier'),
        EtapeTexte('second'),
      ]);
      await macros.joue(macros.parId(macro.id)!);

      expect(pont.gestes.where((g) => g.startsWith('texte:')), isEmpty);
      expect(macros.dernierJeu!.horsDuJeu, isTrue);
      expect(macros.dernierJeu!.obstacle, 'Brave');
    });

    test('un clic hors du jeu arrete aussi', () async {
      pont.jeuDevant = false;
      final macro = macros.ajoute('Clic');
      macros.modifie(macro.id, etapes: const [
        EtapeClic(10, 20),
        EtapeTexte('apres'),
      ]);
      await macros.joue(macros.parId(macro.id)!);

      expect(pont.gestes.where((g) => g.startsWith('texte:')), isEmpty);
      expect(macros.dernierJeu!.horsDuJeu, isTrue);
    });

    test('l action focus amene une fenetre puis continue', () async {
      pont.fenetres = {'Kaska-yopette', 'Kaska-nini'};
      final macro = macros.ajoute('Deux clients');
      macros.modifie(macro.id, etapes: const [
        EtapeFenetre('Kaska-yopette'),
        EtapeTexte('bonjour'),
      ]);
      await macros.joue(macros.parId(macro.id)!);

      expect(pont.gestes, containsAllInOrder([
        'fenetre:Kaska-yopette',
        'texte:bonjour',
      ]));
    });

    test('le focus suit la variable de la boucle', () async {
      // C'est l'usage meme de l'action : un tour par personnage, et la fenetre
      // de celui du tour.
      pont.fenetres = {'Clandestin', 'Oqtf'};
      final macro = macros.ajoute('Chacun son tour');
      macros.modifie(
        macro.id,
        variables: const [
          Variable(nom: 'mes_persos', valeurs: ['Clandestin', 'Oqtf']),
        ],
        etapes: const [
          EtapeBoucle(
            liste: 'mes_persos',
            etapes: [
              EtapeFenetre('{mes_persos}'),
              EtapeTexte('/invite {mes_persos}'),
            ],
          ),
        ],
      );
      await macros.joue(macros.parId(macro.id)!);

      expect(pont.gestes, containsAllInOrder([
        'fenetre:Clandestin',
        'texte:/invite Clandestin',
        'fenetre:Oqtf',
        'texte:/invite Oqtf',
      ]));
    });

    test('un focus qui echoue arrete la macro', () async {
      final macro = macros.ajoute('Absent');
      macros.modifie(macro.id, etapes: const [
        EtapeFenetre('Personne'),
        EtapeTexte('bonjour'),
      ]);
      await macros.joue(macros.parId(macro.id)!);

      expect(pont.gestes.where((g) => g.startsWith('texte:')), isEmpty);
      expect(macros.dernierJeu!.fenetreIntrouvable, 'Personne');
    });

    test('le focus se relit dans les reglages', () async {
      final macro = macros.ajoute('Focus');
      macros.modifie(macro.id, etapes: const [EtapeFenetre('Kaska-sadi')]);
      await macros.synchronise;
      await config.enregistre(dossier.path);

      final relue = (await Config.charge(dossier.path)).macros.single;
      expect(relue.etapes.single, const EtapeFenetre('Kaska-sadi'));
    });
  });

  group('l arret', () {
    const stop = Raccourci(touche: 0x7B, libelle: 'F12');

    test('la touche d arret reste seule enregistree pendant le jeu', () async {
      // Suspendre tout, comme pour les autres macros, aurait rendu la touche
      // d'arret muette au moment ou elle sert.
      macros.changeArret(stop);
      final macro = invitation();
      await macros.synchronise;
      pont.tables.clear();

      await macros.joue(macro);

      expect(pont.tables.first, [stop.signature]);
      expect(pont.tables.last, containsAll([stop.signature, _f10.signature]));
    });

    test('la touche d arret coupe la macro en cours', () async {
      macros.changeArret(stop);
      final macro = invitation();
      final joue = macros.joue(macro);
      pont.surRaccourci!(stop.signature, -1);
      await joue;

      expect(macros.enCours, isNull);
      expect(
        pont.gestes.where((g) => g.startsWith('texte:')),
        isEmpty,
        reason: 'le texte vient apres la premiere attente',
      );
    });

    test('la touche d arret se relit dans les reglages', () async {
      macros.changeArret(stop);
      await macros.synchronise;
      await config.enregistre(dossier.path);

      final relue = await Config.charge(dossier.path);
      expect(relue.arretMacros, stop);
    });

    test('elle ne declenche aucune macro', () async {
      // Une macro pourrait porter la meme touche : l'arret passe avant.
      macros.changeArret(stop);
      final macro = macros.ajoute('Sur F12');
      macros.modifie(macro.id, raccourci: stop, etapes: const [
        EtapeTexte('rien'),
      ]);
      await macros.synchronise;
      pont.surRaccourci!(stop.signature, -1);
      await macros.synchronise;

      expect(pont.gestes.where((g) => g.startsWith('texte:')), isEmpty);
    });
  });

  group('la duplication', () {
    test('la copie garde tout, sauf la touche', () async {
      // Deux macros sur la meme touche ne se partagent pas : la copie
      // paraitrait inerte.
      final macro = macros.ajoute('Inviter');
      macros.modifie(
        macro.id,
        raccourci: _f10,
        cible: 'Kaska-yopette',
        variables: const [Variable(nom: 'noms', valeurs: ['A'])],
        etapes: const [EtapeTexte('{noms}')],
      );
      final copie = macros.duplique(macro.id, 'Inviter (copie)')!;

      expect(macros.macros.map((m) => m.nom), ['Inviter', 'Inviter (copie)']);
      expect(copie.etapes, macros.parId(macro.id)!.etapes);
      expect(copie.variables, macros.parId(macro.id)!.variables);
      expect(copie.cible, 'Kaska-yopette');
      expect(copie.raccourci, isNull);
      expect(copie.id, isNot(macro.id));
    });
  });

  group('le compte', () {
    test('une macro activee compte, meme sans touche ni action', () async {
      // L'interrupteur dit ce que l'utilisateur veut ; ce qui manque pour
      // qu'elle parte se lit sur sa ligne.
      final vide = macros.ajoute('Vide');
      invitation();
      await macros.synchronise;
      expect(macros.actives, 2);

      macros.modifie(vide.id, actif: false);
      expect(macros.actives, 1);
    });
  });

  group('le partage des touches', () {
    test('seules les macros liees et actives sont poussees', () async {
      final macro = macros.ajoute('Vide');
      await macros.synchronise;
      expect(pont.dernieres, isEmpty, reason: 'sans geste ni touche');

      macros.modifie(macro.id, raccourci: _f10, etapes: const [
        EtapeTexte('bonjour'),
      ]);
      await macros.synchronise;
      expect(pont.dernieres, hasLength(1));
      expect(pont.dernieres.single.cibles, isEmpty,
          reason: 'une macro n active aucune fenetre par elle-meme');

      macros.modifie(macro.id, actif: false);
      await macros.synchronise;
      expect(pont.dernieres, isEmpty);
    });

    test('l Organizer et les macros tiennent la meme table', () async {
      final organizer = Organizer(config: config, raccourcis: raccourcis);
      addTearDown(organizer.dispose);
      await organizer.demarre();
      final equipe = organizer.ajouteEquipe('Kaska');
      organizer.ajoutePersonnage(
        equipe.id,
        nom: 'Kaska-yopette',
        titre: 'Kaska-yopette',
        raccourci: _f1,
      );
      invitation();
      await macros.synchronise;

      // Les deux, et non l'une ou l'autre : c'etait tout l'objet de l'arbitre.
      expect(
        pont.dernieres.map((l) => l.id).toSet(),
        {_f1.signature, _f10.signature},
      );
      expect(organizer.actifs, 1);
      expect(macros.actives, 1);
    });

    test('a touche egale, le personnage passe avant la macro', () async {
      final organizer = Organizer(config: config, raccourcis: raccourcis);
      addTearDown(organizer.dispose);
      await organizer.demarre();
      final equipe = organizer.ajouteEquipe('Kaska');
      organizer.ajoutePersonnage(
        equipe.id,
        nom: 'Kaska-yopette',
        titre: 'Kaska-yopette',
        raccourci: _f10,
      );
      final macro = invitation();
      await macros.synchronise;

      expect(pont.dernieres, hasLength(1));
      expect(pont.dernieres.single.cibles, ['Kaska-yopette'],
          reason: 'c est la liaison du personnage qui est enregistree');
      expect(macros.prisAilleurs(macro), isTrue);
      expect(
        macros.actives,
        1,
        reason: 'elle reste activee : c est sa touche qui ne repond pas',
      );
    });
  });
}
