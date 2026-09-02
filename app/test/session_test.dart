/// Verrous sur la comptabilite du suivi.
///
/// Chaque cas vient d'une erreur constatee en jeu, pas d'une inquietude
/// theorique. Ils sont repris un a un de la version Python, dont ils gardaient
/// deja le meme role : la logique a ete portee, ses pieges avec elle.
library;

import 'package:dofus_tracker/modele/session.dart';
import 'package:dofus_tracker/theme.dart';
import 'package:flutter_test/flutter_test.dart';

const qui = 'Kaska-yopette';
final cle = cleDe(qui);

Map<String, dynamic> combat(double ts, List<Map<String, dynamic>> participants) =>
    {'ts': ts, 'type': 'FightEnd', 'participants': participants};

Map<String, dynamic> participant(String nom,
        {int xp = 0,
        int kamas = 0,
        List<Map<String, dynamic>> loot = const [],
        int? issue = 2}) =>
    {
      'name': nom,
      'level': 60,
      'xp': xp,
      'kamas': kamas,
      'loot': loot,
      // L'issue telle que la bibliotheque la rend : deux chez les gagnants,
      // absente chez ceux qui ont perdu ou abandonne.
      'outcome': ?issue,
    };

Map<String, dynamic> objet(double ts, int itemId, int quantite,
        {int? prix, String personnage = qui}) =>
    {
      'ts': ts,
      'type': 'ItemGained',
      'character': personnage,
      'item_id': itemId,
      'quantity': quantite,
      'unit_price': ?prix,
    };

Session enCombat() {
  final s = Session([qui]);
  s.recoit({'ts': 1, 'type': 'FightStart', 'character': qui});
  return s;
}

List<(int, String, String)> etat(Session s) =>
    [for (final c in s.challenges) (c.challengeId, c.origine, c.etat)];

void main() {
  group('challenges', () {
    test('combat ordinaire : une proposition retenue, un seul en jeu', () {
      final s = enCombat();
      s.recoit({
        'ts': 1.1, 'type': 'ChallengeOffer', 'character': qui,
        'offers': [[20, 60], [8, 85]],
      });
      s.recoit({'ts': 1.2, 'type': 'ChallengeSelected', 'character': qui,
        'challenge_id': 20});
      expect(etat(s), isEmpty, reason: "la selection seule n'affiche rien");
      s.recoit({'ts': 2, 'type': 'ChallengeActive', 'character': qui,
        'challenges': [[20, 60]]});
      expect(etat(s), [(20, 'choisi', 'en cours')]);
    });

    test('changement d\'avis : le premier clic ne laisse pas de trace', () {
      // Un joueur avait clique sur Duel puis bascule sur Elitiste ; les deux
      // restaient a l'ecran, alors que le serveur n'en met qu'un en jeu.
      final s = enCombat();
      s.recoit({'ts': 1.1, 'type': 'ChallengeOffer', 'character': qui,
        'offers': [[32, 50], [45, 90]]});
      s.recoit({'ts': 1.2, 'type': 'ChallengeSelected', 'character': qui,
        'challenge_id': 45});
      s.recoit({'ts': 1.3, 'type': 'ChallengeSelected', 'character': qui,
        'challenge_id': 32});
      s.recoit({'ts': 2, 'type': 'ChallengeActive', 'character': qui,
        'challenges': [[32, 50], [46, 85]]});
      expect(etat(s), [(32, 'choisi', 'en cours'), (46, 'impose', 'en cours')]);
    });

    test('le second challenge d\'un donjon n\'a jamais ete propose', () {
      final s = enCombat();
      s.recoit({'ts': 1.1, 'type': 'ChallengeOffer', 'character': qui,
        'offers': [[20, 60], [42, 85]]});
      s.recoit({'ts': 1.2, 'type': 'ChallengeSelected', 'character': qui,
        'challenge_id': 20});
      s.recoit({'ts': 2, 'type': 'ChallengeActive', 'character': qui,
        'challenges': [[20, 60], [973, 85]]});
      expect(etat(s), [(20, 'choisi', 'en cours'), (973, 'impose', 'en cours')]);
    });

    test('sur un boss, la proposition ecartee reste en jeu', () {
      final s = enCombat();
      s.recoit({'ts': 1.1, 'type': 'ChallengeOffer', 'character': qui,
        'offers': [[971, 80], [45, 90]]});
      s.recoit({'ts': 1.2, 'type': 'ChallengeSelected', 'character': qui,
        'challenge_id': 971});
      s.recoit({'ts': 2, 'type': 'ChallengeActive', 'character': qui,
        'challenges': [[971, 80], [45, 90], [127]]});
      expect(etat(s), [
        (971, 'choisi', 'en cours'),
        (45, 'ecarte', 'en cours'),
        (127, 'objectif', 'en cours'),
      ]);
    });

    test('deux paires successives : les deux choix sont en jeu', () {
      final s = enCombat();
      s.recoit({'ts': 1.1, 'type': 'ChallengeOffer', 'character': qui,
        'offers': [[32, 50], [36, 85]]});
      s.recoit({'ts': 1.2, 'type': 'ChallengeSelected', 'character': qui,
        'challenge_id': 32});
      s.recoit({'ts': 1.3, 'type': 'ChallengeOffer', 'character': qui,
        'offers': [[42, 85], [31, 60]]});
      s.recoit({'ts': 1.4, 'type': 'ChallengeSelected', 'character': qui,
        'challenge_id': 42});
      s.recoit({'ts': 2, 'type': 'ChallengeActive', 'character': qui,
        'challenges': [[32, 50], [42, 85]]});
      expect(etat(s), [(32, 'choisi', 'en cours'), (42, 'choisi', 'en cours')]);
    });

    test('le resolu reste, l\'absent sans issue suit la liste', () {
      final s = enCombat();
      s.recoit({'ts': 2, 'type': 'ChallengeActive', 'character': qui,
        'challenges': [[20, 60], [973, 85]]});
      s.recoit({'ts': 3, 'type': 'ChallengeResult', 'character': qui,
        'challenge_id': 20, 'succeeded': true});
      s.recoit({'ts': 4, 'type': 'ChallengeActive', 'character': qui,
        'challenges': [[973, 85]]});
      expect(etat(s), [(973, 'impose', 'en cours'), (20, 'impose', 'reussi')]);
    });

    test('l\'issue annoncee par quatre clients ne fait qu\'une ligne', () {
      final s = enCombat();
      s.recoit({'ts': 2, 'type': 'ChallengeActive', 'character': qui,
        'challenges': [[20, 60]]});
      for (var i = 0; i < 4; i++) {
        s.recoit({'ts': 3, 'type': 'ChallengeResult', 'character': qui,
          'challenge_id': 20, 'succeeded': true});
      }
      expect(s.journal.map((f) => f.genre).toList(), ['challenge']);
    });
  });

  group('formats', () {
    test('les milliers sont separes par une insecable', () {
      // L'espace fine insecable — U+202F, la convention — manque a Lexend,
      // qui la rend alors quasi nulle : « 1 050 067 » s'affichait
      // « 1050067 ». L'insecable ordinaire passe partout.
      expect(formateNombre(1050067), '1\u00A0050\u00A0067');
      expect(formateNombre(999), '999');
      expect(formateNombre(-1234), '-1\u00A0234');
      expect(formateNombre(0), '0');
    });

    test('un nombre s\'abrege quand la place manque', () {
      // Une cadence n'a pas besoin d'etre exacte a l'unite : ce qu'on lit
      // dans « 1,2 M/h », c'est l'ordre de grandeur.
      // L'espace avant le suffixe est insecable elle aussi : « 1,2 M »
      // ne doit pas se couper en fin de ligne.
      expect(formateCourt(1200000), '1,2\u00A0M');
      expect(formateCourt(12000000), '12\u00A0M');
      expect(formateCourt(1500), '1,5\u00A0k');
      expect(formateCourt(999), '999');
    });

    test('la duree se lit en heures, minutes, secondes', () {
      expect(formateDuree(0), '00:00:00');
      expect(formateDuree(3661), '01:01:01');
    });
  });

  test('la duree du combat vient du serveur', () {
    final session = Session(['Kaska-nini']);
    session.recoit(
        {'ts': 1, 'type': 'FightStart', 'character': 'Kaska-nini'});
    session.recoit({
      'ts': 100,
      'type': 'FightEnd',
      // Le champ 4 de `jyg`, rendu en secondes par la bibliotheque : c'est la
      // duree que le jeu affiche, phase de placement exclue.
      'duration': 134.362,
      'participants': [
        {'name': 'Kaska-nini', 'level': 60, 'xp': 100, 'kamas': 5, 'loot': []},
      ],
    });
    expect(session.combats.single.duree, closeTo(134.362, 0.001));
    // L'engagement se deduit de la fin et de la duree.
    expect(session.combats.single.debut, closeTo(100 - 134.362, 0.001));
  });

  test('sans duree annoncee, le chronometre local prend le relais', () {
    final session = Session(['Kaska-nini']);
    session.recoit({
      'ts': 100,
      'type': 'FightEnd',
      'participants': [
        {'name': 'Kaska-nini', 'level': 60, 'xp': 100, 'kamas': 5, 'loot': []},
      ],
    });
    // Hors combat, il ne sait rien : zero vaut mieux qu'un nombre invente.
    expect(session.combats.single.duree, 0);
  });

  test('les succes comptent, sauf si on les ecarte', () {
    Session avec({required bool compte}) {
      final s = Session(['Kaska-nini'])..compteLesSucces = compte;
      s.recoit({
        'ts': 1,
        'type': 'AchievementUnlocked',
        'character': 'Kaska-nini',
        'achievement_id': 42,
        'xp': 18649,
        'kamas': 500,
        'rewards': [
          {'item_id': 2663, 'quantity': 3, 'unit_price': 1567},
        ],
      });
      return s;
    }

    final compte = avec(compte: true);
    expect(compte.xpTotale, 18649);
    expect(compte.kamasTotaux, 500 + 3 * 1567);
    expect(compte.succesTotaux, 1);

    // Un succes rend d'un coup ce que plusieurs heures de farm rapportent :
    // le laisser entrer dans les totaux fausse la cadence, et c'est la cadence
    // qu'on regarde en montant un donjon.
    final ecarte = avec(compte: false);
    expect(ecarte.xpTotale, 0);
    expect(ecarte.kamasTotaux, 0);
    expect(ecarte.succesTotaux, 0);
    // Le personnage s'est tout de meme manifeste : sa ligne existe.
    expect(ecarte.lignes.single.nom, 'Kaska-nini');
  });

  test('les succes comptent par defaut', () {
    expect(Session().compteLesSucces, isTrue,
        reason: 'ces gains sont reels ; les cacher surprendrait davantage');
  });

  test('les adversaires du combat sont retenus et relus', () {
    final session = enCombat();
    session.recoit({
      'ts': 100.0,
      'type': 'FightEnd',
      'duration': 30.0,
      'participants': [participant(qui, xp: 100)],
      // Ce que la bibliotheque tire du placement : le recapitulatif, lui, ne
      // designe les perdants que par un numero propre au combat.
      'opponents': [
        {'fighter_id': -1, 'monster_id': 78, 'grade': 2},
        {'fighter_id': -2, 'monster_id': 78, 'grade': 2},
        // Un combat engage avant l\'ecoute : on compte sans nommer.
        {'fighter_id': -3},
      ],
    });

    final combat = session.combats.single;
    expect(combat.adversaires.length, 3);
    expect(combat.adversaires.first.monstre, 78);
    expect(combat.adversaires.first.grade, 2);
    expect(combat.adversaires.last.connu, isFalse);

    // Ils survivent a l\'archivage : une session relue montre le meme combat.
    final relu = Combat.depuisJson(combat.versJson());
    expect(relu.adversaires.length, 3);
    expect(relu.adversaires.first.monstre, 78);
    expect(relu.adversaires.last.monstre, isNull);
  });

  test('un combat entierement perdu figure dans la liste', () {
    // La forme la plus depouillee : personne ne gagne, donc aucune
    // experience, aucun kama, aucun objet. C'est exactement ce que la
    // bibliotheque laissait tomber — elle reconnaissait un participant a son
    // experience, et le protocole n'emet pas les zeros.
    final s = enCombat();
    s.recoit(combat(100, [participant(qui, xp: 0, kamas: 0, issue: null)]));

    expect(s.combats.length, 1, reason: 'un combat perdu reste un combat');
    final c = s.combats.single;
    expect(c.gagnants, isEmpty);
    expect(c.perdants.single.nom, qui);
    expect(c.xp, 0);
    // Il compte dans le total des combats du personnage : c'est du temps
    // passe, et le taux horaire serait flatte de l'ignorer.
    expect(s.suivis[cle]!.combats, 1);
  });

  test('un combat perdu retient les vainqueurs d\'en face', () {
    // Ils etaient ecartes pour la raison meme qui les designe : on ne
    // retenait ceux d'en face qu'a l'absence d'issue gagnante, et un combat
    // perdu est justement celui ou ils la portent. La defaite se rouvrait
    // donc sans adversaires.
    final s = enCombat();
    s.recoit({
      'ts': 100.0,
      'type': 'FightEnd',
      'duration': 12.0,
      'participants': [participant(qui, xp: 0, kamas: 0, issue: null)],
      'opponents': [
        {'fighter_id': -1, 'monster_id': 78, 'grade': 2, 'outcome': 2},
      ],
    });

    final c = s.combats.single;
    expect(c.victoire, isFalse);
    expect(c.adversairesGagnants.single.monstre, 78);
    expect(c.adversairesPerdants, isEmpty);

    // Et cela survit a l'archivage.
    final relu = Combat.depuisJson(c.versJson());
    expect(relu.victoire, isFalse);
    expect(relu.adversairesGagnants.single.monstre, 78);
  });

  test('la classe du personnage est archivee avec le combat', () {
    // Elle ne circule qu'au passage sur une carte : l'archive relue des mois
    // plus tard ne pourra plus la demander a personne.
    final s = enCombat();
    s.recoit({'ts': 2.0, 'type': 'CharacterInfo', 'name': qui, 'breed': 10});
    s.recoit(combat(100, [participant(qui, xp: 50)]));

    final c = s.combats.single;
    expect(c.participants.single.classe, 10);
    expect(Combat.depuisJson(c.versJson()).participants.single.classe, 10);
  });

  test('un abandon n\'est pas une victoire', () {
    final s = enCombat();
    s.recoit(combat(100, [
      participant(qui, xp: 0, kamas: 0, issue: null),
      participant('Kaska-nini', xp: 4000, kamas: 12),
    ]));

    final c = s.combats.single;
    // Les deux figurent au recapitulatif — le fuyard aussi, avec zero
    // partout. Seule l\'issue les separe.
    expect(c.participants.length, 2);
    expect(c.gagnants.single.nom, 'Kaska-nini');
    expect(c.perdants.single.nom, qui);

    // Et cela survit a l\'archivage.
    final relu = Combat.depuisJson(c.versJson());
    expect(relu.perdants.single.nom, qui);
    expect(relu.gagnants.single.nom, 'Kaska-nini');
  });

  test('un objectif de boss n\'est pas un challenge', () {
    final s = enCombat();
    // Un combat de boss : un challenge choisi, avec son pourcentage, et un
    // objectif propre au boss, qui n'en a pas.
    s.recoit({
      'ts': 2.0,
      'type': 'ChallengeActive',
      'character': qui,
      'challenges': [
        [20, 60],
        [127],
      ],
    });
    for (final id in [20, 127]) {
      s.recoit({
        'ts': 3.0,
        'type': 'ChallengeResult',
        'character': qui,
        'challenge_id': id,
        'succeeded': true,
      });
    }
    s.recoit(combat(100, [participant(qui, xp: 10)]));

    final c = s.combats.single;
    // Les deux sont archives — ce sont des faits du combat.
    expect(c.challenges.length, 2);
    // Mais un seul est un challenge : « 2/2 » sur un combat qui n'en
    // proposait qu'un se lisait comme une soiree parfaite.
    expect(c.challengesSeuls.length, 1);
    expect(c.challengesSeuls.single.challengeId, 20);
    expect(c.challengesReussis, 1);
    expect(s.historiqueChallenges.where((d) => d.estChallenge).length, 1);
  });

  test('les recompenses d\'un succes suivent son comptage', () {
    // L\'ordre du serveur, releve sur capture : la commande du joueur, puis
    // les recompenses qui entrent dans l\'inventaire, et **seulement ensuite**
    // l\'annonce du succes. Les ignorer a leur arrivee est le seul moyen de
    // les tenir a l\'ecart quand le comptage est desactive.
    Session avec({required bool compte}) {
      final s = Session([qui])..compteLesSucces = compte;
      s.recoit({
        ...objet(10, 27366, 10, prix: 200),
        'origin': 'achievement',
      });
      s.recoit({
        'ts': 10.1,
        'type': 'AchievementUnlocked',
        'character': qui,
        'achievement_id': 5910,
        'xp': 198758,
        'kamas': 3480,
        'rewards': [
          {'item_id': 27366, 'quantity': 10, 'unit_price': 200},
        ],
      });
      return s;
    }

    // Comptage actif : une fois, pas deux. Le lot ne doit pas etre compte a
    // son entree **et** a l\'annonce.
    final compte = avec(compte: true);
    expect(compte.xpTotale, 198758);
    expect(compte.kamasTotaux, 3480 + 10 * 200);
    expect(compte.suivis[cle]!.butin[27366]!.quantite, 10);

    // Comptage ecarte : rien, pas meme les objets.
    final ecarte = avec(compte: false);
    expect(ecarte.xpTotale, 0);
    expect(ecarte.kamasTotaux, 0,
        reason: 'le butin montait malgre le comptage desactive');
    expect(ecarte.suivis[cle]!.butin, isEmpty);
    // Le personnage s\'est tout de meme manifeste.
    expect(ecarte.lignes.single.nom, qui);
  });

  test('un objet repris dans un coffre n\'est pas un gain', () {
    final session = Session([qui]);
    // Ramassage : compte.
    session.recoit(objet(10, 2663, 3, prix: 100));
    expect(session.suivis[cle]!.kamasButin, 300);

    // Reprise dans un coffre, ou runes rendues par un brisage : le serveur
    // l'annonce par le meme message, mais l'objet ne fait que changer de
    // contenant.
    session.recoit({
      ...objet(20, 8139, 4, prix: 500),
      'origin': 'transfer',
    });
    expect(session.suivis[cle]!.kamasButin, 300,
        reason: 'quatre clefs sorties d\'un coffre ne sont pas un butin');
    expect(session.suivis[cle]!.butin.containsKey(8139), isFalse);

    // Une pochette ouverte : son contenu entre par le meme message qu'un
    // ramassage, et une pochette rend d'un coup ce que le farm met des
    // minutes a donner.
    session.recoit({
      ...objet(30, 1731, 10, prix: 200),
      'origin': 'use',
    });
    expect(session.suivis[cle]!.kamasButin, 300,
        reason: 'ce qui sort d\'un consommable n\'est pas un butin');
    expect(session.suivis[cle]!.butin.containsKey(1731), isFalse);
  });

  test('le bandeau compte les combats, pas les participations', () {
    const autre = 'Kaska-nini';
    final session = Session([qui, autre]);
    session.recoit({'ts': 1, 'type': 'FightStart', 'character': qui});
    // Deux combats menes a deux : quatre participations, deux combats.
    session.recoit(combat(100, [
      participant(qui, xp: 100),
      participant(autre, xp: 90),
    ]));
    session.recoit(combat(200, [
      participant(qui, xp: 80),
      participant(autre, xp: 70),
    ]));

    expect(session.combatsTotaux, 2,
        reason: 'le bandeau annoncait 79 combats pour les 11 d\'une soiree');
    // Le compteur par personnage garde son sens : il compte les combats
    // auxquels celui-la a pris part, et la vue compacte l'affiche ainsi.
    expect(session.suivis[cle]!.combats, 2);
    expect(session.suivis[cleDe(autre)]!.combats, 2);
  });

  test('un succès validé en combat n\'est pas un challenge', () {
    final session = enCombat();
    session.recoit({
      'ts': 50.0,
      'type': 'ChallengeResult',
      'challenge_id': 20,
      'succeeded': true,
    });
    session.recoit({
      'ts': 60.0,
      'type': 'AchievementUnlocked',
      'character': qui,
      'achievement_id': 42,
      'xp': 18649,
      'kamas': 1200,
    });
    session.recoit(combat(100, [participant(qui, xp: 100)]));

    // Le succès rapporte, et il est compté ailleurs. Mais la colonne des
    // challenges ne parle que des challenges : un combat qui en portait un
    // seul ne doit pas en afficher deux.
    expect(session.combats.single.challenges.length, 1);
    expect(session.combats.single.challenges.single.challengeId, 20);
    expect(session.suivis[cle]!.succes, 1);
  });

  test('un combat sans adversaire connu n\'alourdit pas l\'archive', () {
    final session = enCombat();
    session.recoit(combat(100, [participant(qui, xp: 10)]));
    // Rien a dire, rien d\'ecrit : la cle est absente, pas vide.
    expect(session.combats.single.versJson().containsKey('adversaires'), isFalse);
  });
  test('les totaux du butin suivent chaque facon de le toucher', () {
    // La valeur du butin et son tri sont retenus d'un appel a l'autre : le
    // butin d'une soiree compte des centaines de types d'objets, et son total
    // est demande plusieurs fois par image. Une valeur retenue qu'on oublie
    // d'invalider se voit mal — le chiffre reste juste jusqu'au premier gain,
    // puis se fige. Les trois facons de toucher au butin sont donc verifiees.
    final suivi = Suivi('Kaska-yopette');

    suivi.ajouteLot(2663, 2, 100);
    expect(suivi.kamasButin, 200);
    expect(suivi.lots.single.itemId, 2663);

    // Un gain de plus.
    suivi.ajouteLot(2663, 1, 100);
    expect(suivi.kamasButin, 300);

    // Un objet ramasse avant la table des prix vaut zero, puis retrouve sa
    // valeur : c'est la revalorisation.
    suivi.ajouteLot(311, 4, null);
    expect(suivi.kamasButin, 300);
    expect(suivi.revalorise({311: 100}), isTrue);
    expect(suivi.kamasButin, 700);
    // Et le tri se refait : a quatre cents kamas, le lot revalorise passe
    // devant les trois cents de l'autre.
    expect(suivi.lots.first.itemId, 311);

    // Une revalorisation sans effet ne doit rien changer non plus.
    expect(suivi.revalorise({311: 100}), isFalse);
    expect(suivi.kamasButin, 700);

    suivi.remetAZero();
    expect(suivi.kamasButin, 0);
    expect(suivi.lots, isEmpty);
  });

  test('ce qui sort d\'un consommable n\'entre pas dans les totaux', () {
    // Une pochette ramassee vaut ce qu'elle vaut ; l'ouvrir ne rapporte rien
    // de plus. Le contenu porte le meme message qu'un ramassage — seule la
    // commande que le client vient d'emettre les separe.
    final session = Session([qui]);
    session.recoit(objet(2, 9001, 1, prix: 1000));
    expect(session.suivis[cle]!.kamasButin, 1000);

    session.recoit({...objet(4, 1731, 10, prix: 200), 'origin': 'use'});
    expect(session.suivis[cle]!.kamasButin, 1000,
        reason: 'le contenu d\'une pochette n\'est pas un gain');

    // La pochette qui decroit porte le meme message, avec sa provenance a
    // elle : elle ne compte pas davantage.
    session.recoit({...objet(5, 9001, 1, prix: 1000), 'origin': 'consumed'});
    expect(session.suivis[cle]!.kamasButin, 1000);
  });

  test('les combattants hors liste ne comptent pas', () {
    // Un combat mene avec un ami : ses personnages figurent au recapitulatif,
    // le jeu les montre et on veut les revoir. Mais leur experience n'est pas
    // la notre — la compter gonflait les totaux de la session, et avec eux
    // les cadences.
    final session = Session([qui]);
    session.recoit({'ts': 1, 'type': 'FightStart', 'character': qui});
    session.recoit(combat(10, [
      participant(qui, xp: 1000, kamas: 50, loot: [
        {'item_id': 2663, 'quantity': 2, 'unit_price': 100},
      ]),
      participant('Ami-iop', xp: 9000, kamas: 900, loot: [
        {'item_id': 311, 'quantity': 40, 'unit_price': 500},
      ]),
    ]));

    // Les totaux de la session ne voient que les notres.
    expect(session.xpTotale, 1000);
    expect(session.kamasTotaux, 50 + 200);
    expect(session.suivis.containsKey(cleDe('Ami-iop')), isFalse);

    // Le combat archive garde tout le monde — c'est ce que le jeu affichait.
    final c = session.combats.single;
    expect(c.participants.length, 2);
    expect(c.participants.map((p) => p.nom), contains('Ami-iop'));

    // Mais ses totaux a lui ne comptent que les notres : c'est ce qui
    // s'affiche dans la liste des combats et en tete du detail.
    expect(c.xp, 1000, reason: 'l\'experience de l\'ami n\'est pas la notre');
    expect(c.kamas, 250);
    expect(c.unites, 2);
    expect(c.avecDesInvites, isTrue);

    // Et chaque ligne sait ce qu'elle est, pour le dire a l'ecran.
    final ami = c.participants.firstWhere((p) => p.nom == 'Ami-iop');
    expect(ami.suivi, isFalse);
    expect(c.participants.firstWhere((p) => p.nom == qui).suivi, isTrue);
  });

  test('une archive d\'avant la distinction compte comme avant', () {
    // Les combats ecrits avant que la question ne se pose n'en portent pas
    // trace : ils etaient les notres, et le relire ne doit pas les vider.
    final combat = Combat.depuisJson({
      'fin': 100.0,
      'duree': 30.0,
      'participants': [
        {'nom': 'Kaska-yopette', 'xp': 500, 'kamas': 10},
        {'nom': 'Kaska-nini', 'xp': 700, 'kamas': 20},
      ],
    });
    expect(combat.xp, 1200);
    expect(combat.avecDesInvites, isFalse);

    // Ecrit puis relu, un invite le reste.
    final avec = Combat.depuisJson(
      Combat(fin: 1, duree: 1, participants: [
        ParticipantCombat(
          nom: 'Ami-iop',
          niveau: 200,
          xp: 9000,
          xpTotal: 0,
          xpSeuilBas: 0,
          xpSeuilHaut: 0,
          kamas: 900,
          butin: const {},
          suivi: false,
        ),
      ]).versJson(),
    );
    expect(avec.participants.single.suivi, isFalse);
    expect(avec.xp, 0);
  });

}
