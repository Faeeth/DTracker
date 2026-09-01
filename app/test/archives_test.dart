/// Verrous sur les sessions archivees.
///
/// Une soiree de farm ne vaut pas que sur le moment : on veut pouvoir y
/// revenir. Ces cas verifient qu'elle survit a l'ecriture, qu'elle se relit
/// telle quelle, et que la session en cours se distingue des autres.
library;

import 'dart:io';

import 'package:dofus_tracker/modele/session.dart';
import 'package:dofus_tracker/source/archives.dart';
import 'package:flutter_test/flutter_test.dart';

Directory dossierTemporaire() =>
    Directory.systemTemp.createTempSync('dofus_tracker_archives');

Session sessionJouee() {
  final s = Session(['Kaska-yopette', 'Kaska-nini']);
  s.recoit({'ts': 1, 'type': 'FightStart', 'character': 'Kaska-yopette'});
  s.recoit({'ts': 1, 'type': 'FightStart', 'character': 'Kaska-nini'});
  s.recoit({
    'ts': 1.1,
    'type': 'ChallengeOffer',
    'character': 'Kaska-yopette',
    'offers': [
      [20, 60],
      [45, 90],
    ],
  });
  s.recoit({
    'ts': 1.2,
    'type': 'ChallengeSelected',
    'character': 'Kaska-yopette',
    'challenge_id': 20,
  });
  s.recoit({
    'ts': 2,
    'type': 'ChallengeActive',
    'character': 'Kaska-yopette',
    'challenges': [
      [20, 60],
      [973, 85],
    ],
  });
  s.recoit({
    'ts': 3,
    'type': 'ChallengeResult',
    'character': 'Kaska-yopette',
    'challenge_id': 973,
    'succeeded': false,
  });
  s.recoit({
    'ts': 4,
    'type': 'ChallengeResult',
    'character': 'Kaska-yopette',
    'challenge_id': 20,
    'succeeded': true,
  });
  s.recoit({
    'ts': 5,
    'type': 'FightEnd',
    'participants': [
      {
        'name': 'Kaska-yopette',
        'level': 60,
        'xp': 53652,
        'kamas': 255,
        // L'issue telle que la bibliotheque la rend : deux chez les gagnants,
        // absente chez ceux qui ont perdu ou abandonne.
        'outcome': 2,
        'loot': [
          {'item_id': 2663, 'quantity': 2, 'unit_price': 1567},
        ],
      },
      {
        'name': 'Kaska-nini',
        'level': 60,
        'xp': 53652,
        'kamas': 42,
        'outcome': 2,
        'loot': [],
      },
    ],
  });
  return s;
}

void main() {
  test('une session se relit telle qu\'elle a ete ecrite', () async {
    final d = dossierTemporaire();
    final archives = Archives(d.path);
    final session = sessionJouee();
    await archives.enregistre(session);

    final liste = await archives.liste();
    expect(liste.length, 1);
    final a = liste.first;
    expect(a.enCours, isTrue);
    expect(a.xp, 53652 * 2);
    // 255 + 42 en piece, plus deux Engrais a 1 567.
    expect(a.kamas, 255 + 42 + 2 * 1567);
    expect(a.nombreCombats, 1);
    expect(a.personnages.length, 2);
    expect(a.personnages.first.butin[2663]?.$1, 2);
    d.deleteSync(recursive: true);
  });

  test('les challenges gardent leur issue et qui combattait', () async {
    final d = dossierTemporaire();
    final archives = Archives(d.path);
    await archives.enregistre(sessionJouee());

    final a = (await archives.liste()).first;
    expect(a.challenges.length, 2);
    final echoue = a.challenges.firstWhere((c) => !c.reussi);
    expect(echoue.challengeId, 973);
    expect(echoue.origine, 'impose');
    // Le protocole n'attribue pas l'issue a un joueur : on garde qui
    // combattait, ce qui est la reponse la plus proche que le flux permette.
    expect(echoue.combattants, ['Kaska-yopette', 'Kaska-nini']);
    final reussi = a.challenges.firstWhere((c) => c.reussi);
    expect(reussi.challengeId, 20);
    expect(reussi.origine, 'choisi');
    expect(a.challengesReussis, 1);
    d.deleteSync(recursive: true);
  });

  test('clore une session lui retire son « en cours »', () async {
    final d = dossierTemporaire();
    final archives = Archives(d.path);
    final session = sessionJouee();
    await archives.enregistre(session);
    await archives.clot(session);

    final liste = await archives.liste();
    expect(liste.length, 1, reason: 'clore ne cree pas un second fichier');
    expect(liste.first.enCours, isFalse);
    d.deleteSync(recursive: true);
  });

  test('la plus recente vient en tete', () async {
    final d = dossierTemporaire();
    final archives = Archives(d.path);

    final ancienne = sessionJouee()..debut = 1000;
    await archives.enregistre(ancienne);
    await archives.clot(ancienne);

    final recente = sessionJouee()..debut = 2000;
    await archives.enregistre(recente);

    final liste = await archives.liste();
    expect(liste.length, 2);
    expect(liste.first.debut, 2000);
    expect(liste.first.enCours, isTrue,
        reason: 'celle en cours est aussi la plus recente');
    d.deleteSync(recursive: true);
  });

  test('un challenge cite toujours des combattants', () async {
    // Le suivi peut demarrer en cours de combat : personne n'est alors marque
    // engage, et personne n'a encore ete rencontre. La liste ne doit pas
    // rester vide pour autant.
    final s = Session(['Kaska-yopette', 'Kaska-nini']);
    s.recoit({
      'ts': 2,
      'type': 'ChallengeActive',
      'character': 'Kaska-yopette',
      'challenges': [
        [20, 60],
      ],
    });
    s.recoit({
      'ts': 3,
      'type': 'ChallengeResult',
      'character': 'Kaska-yopette',
      'challenge_id': 20,
      'succeeded': false,
    });
    expect(s.historiqueChallenges.single.combattants,
        ['Kaska-yopette', 'Kaska-nini']);
  });

  test('une session sans rien a montrer ne laisse pas de trace', () async {
    final d = dossierTemporaire();
    final archives = Archives(d.path);
    await archives.enregistre(Session(['Kaska-nini']));
    expect(await archives.liste(), isEmpty);
    d.deleteSync(recursive: true);
  });

  test('une session qui dure garde le meme fichier', () async {
    final d = dossierTemporaire();
    final archives = Archives(d.path);
    final session = sessionJouee();
    await archives.enregistre(session);
    session.recoit({
      'ts': 9,
      'type': 'FightEnd',
      'participants': [
        {'name': 'Kaska-nini', 'level': 60, 'xp': 100, 'kamas': 5, 'loot': []},
      ],
    });
    await archives.enregistre(session);

    final liste = await archives.liste();
    expect(liste.length, 1);
    expect(liste.first.nombreCombats, 2);
    d.deleteSync(recursive: true);
  });

  test('les challenges sont rattaches a leur combat', () async {
    final d = dossierTemporaire();
    final archives = Archives(d.path);
    await archives.enregistre(sessionJouee());

    final a = (await archives.liste()).first;
    // Rattaches au combat, et non ranges dans une liste a part qu'il faudrait
    // rapprocher de tete.
    final combat = a.combats.single;
    expect(combat.challenges.map((c) => c.challengeId).toSet(), {20, 973});
    expect(combat.challengesReussis, 1);
    expect(a.challengesDe(0).length, 2);
    d.deleteSync(recursive: true);
  });

  test('un combat ne herite pas des challenges du precedent', () {
    final s = sessionJouee();
    s.recoit({
      'ts': 9,
      'type': 'FightEnd',
      'participants': [
        {'name': 'Kaska-nini', 'level': 60, 'xp': 100, 'kamas': 5, 'loot': []},
      ],
    });
    expect(s.combats.first.challenges.length, 2);
    expect(s.combats.last.challenges, isEmpty);
  });

  test('une vieille archive rapproche ses challenges par le temps', () {
    // Ecrite avant que le combat ne porte les siens : la liste globale est la
    // seule source, et le rapprochement se fait sur les horodatages.
    final archive = Archive.depuisJson({
      'debut': 0.0,
      'fin': 20.0,
      'en_cours': false,
      'personnages': [],
      'combats': [
        {'fin': 5.0, 'duree': 4.0, 'participants': []},
        {'fin': 15.0, 'duree': 4.0, 'participants': []},
      ],
      'challenges': [
        {'ts': 3.0, 'challenge_id': 20, 'reussi': true, 'combattants': []},
        {'ts': 12.0, 'challenge_id': 973, 'reussi': false, 'combattants': []},
      ],
      'journal': [],
    });
    expect(archive.challengesDe(0).single.challengeId, 20);
    expect(archive.challengesDe(1).single.challengeId, 973);
  });

  test('un lancement ne laisse pas deux sessions « en cours »', () async {
    final d = dossierTemporaire();
    final archives = Archives(d.path);
    // Une session laissee ouverte par une execution precedente.
    await archives.enregistre(sessionJouee()..debut = 1000);
    expect((await archives.liste()).single.enCours, isTrue);

    await Archives(d.path).clotLesOrphelines();
    expect((await archives.liste()).single.enCours, isFalse,
        reason: 'le marqueur dit quelle session est alimentee');
    d.deleteSync(recursive: true);
  });

  test('une session rechargee reprend ses compteurs, et repart', () async {
    final d = dossierTemporaire();
    final archives = Archives(d.path);
    await archives.enregistre(sessionJouee()..debut = 1000);
    final archive = (await archives.liste()).single;

    final vivante = Session(['Kaska-yopette', 'Kaska-nini']);
    archive.rechargeDans(vivante);

    // On y bascule pour continuer : un second geste pour la remettre en
    // marche n'avait de raison pour personne.
    expect(vivante.enPause, isFalse);
    expect(vivante.periodes.last.ouverte, isTrue);
    expect(vivante.debut, 1000);
    expect(vivante.xpTotale, 53652 * 2);
    expect(vivante.kamasTotaux, 255 + 42 + 2 * 1567);
    expect(vivante.combats.length, 1);
    expect(vivante.historiqueChallenges.length, 2);
    expect(vivante.lignes.map((l) => l.nom),
        ['Kaska-yopette', 'Kaska-nini']);
    expect(vivante.lignes.first.combats, 1);
    expect(vivante.lignes.first.butin[2663]?.quantite, 2);
    d.deleteSync(recursive: true);
  });

  test('un personnage plus suivi retrouve sa ligne le temps du detour',
      () async {
    final d = dossierTemporaire();
    final archives = Archives(d.path);
    await archives.enregistre(sessionJouee()..debut = 1000);
    final archive = (await archives.liste()).single;

    // On ne suit plus que l'un des deux. Cacher l'autre afficherait des
    // totaux sans les lignes qui les composent.
    final vivante = Session(['Kaska-nini']);
    archive.rechargeDans(vivante);
    expect(vivante.lignes.map((l) => l.nom).toSet(),
        {'Kaska-nini', 'Kaska-yopette'});
    d.deleteSync(recursive: true);
  });

  test('la duree est la somme des ecoutes, pas leur ecart', () {
    final session = sessionJouee();
    session.periodes
      ..clear()
      ..addAll([Periode(1000, 1300), Periode(90000, 90600)]);
    // Deux lancements espaces d'un jour : cinq minutes puis dix, soit quinze.
    // L'ecart entre les extremes en donnerait vingt-quatre heures, et toute
    // cadence calculee dessus serait fausse d'un ordre de grandeur.
    expect(session.duree.round(), 900);
    expect(Archive.depuisSession(session).duree, 900);
  });

  test('une pause ferme la periode, la reprise en ouvre une neuve', () {
    final session = sessionJouee();
    expect(session.periodes.single.ouverte, isTrue);
    session.enPause = true;
    expect(session.periodes.single.ouverte, isFalse);
    session.enPause = false;
    expect(session.periodes.length, 2);
    expect(session.periodes.last.ouverte, isTrue);
    // Une pause en pleine pause ne coupe rien.
    session.enPause = true;
    session.enPause = true;
    expect(session.periodes.length, 2);
  });

  test('une session en pause cesse de grandir', () async {
    final session = sessionJouee();
    session.periodes
      ..clear()
      ..addAll([Periode(1000, 1300)]);
    session.enPause = true;
    final avant = Archive.depuisSession(session).duree;
    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(Archive.depuisSession(session).duree, avant);
    expect(avant, 300);
  });

  test('les periodes se relisent, les vieilles archives aussi', () async {
    final d = dossierTemporaire();
    final archives = Archives(d.path);
    final session = sessionJouee();
    session.periodes
      ..clear()
      ..addAll([Periode(1000, 1300), Periode(90000, 90600)]);
    session.nom = 'Donjon Bouftou';
    session.numero = 7;
    await archives.enregistre(session);

    final a = (await archives.liste()).single;
    expect(a.nom, 'Donjon Bouftou');
    expect(a.numero, 7);
    expect(a.reprises, 2);
    expect(a.duree, 900);

    // Une archive ecrite avant les periodes n'a que deux bornes : elle vaut
    // une periode unique, ce qui est exactement ce qu'elle etait.
    final ancienne = Archive.depuisJson({
      'debut': 100.0,
      'fin': 250.0,
      'personnages': [],
      'combats': [],
      'challenges': [],
      'journal': [],
    });
    expect(ancienne.reprises, 1);
    expect(ancienne.duree, 150);
    d.deleteSync(recursive: true);
  });

  test('le numero suivant depasse tous ceux deja portes', () async {
    final d = dossierTemporaire();
    final archives = Archives(d.path);
    expect(await archives.prochainNumero(), 1);

    final premiere = sessionJouee()
      ..debut = 1000
      ..numero = 3;
    await archives.enregistre(premiere);
    await archives.clot(premiere);
    // Un increment, pas un compte : effacer une archive ne doit pas faire
    // reapparaitre un numero deja porte.
    expect(await archives.prochainNumero(), 4);
    d.deleteSync(recursive: true);
  });

  test('renommer une session archivee tient', () async {
    final d = dossierTemporaire();
    final archives = Archives(d.path);
    final session = sessionJouee()..debut = 1000;
    await archives.enregistre(session);
    await archives.clot(session);

    await archives.renomme((await archives.liste()).single, 'Soiree Frigost');
    final a = (await archives.liste()).single;
    expect(a.nom, 'Soiree Frigost');
    expect(a.enCours, isFalse, reason: 'renommer ne la rouvre pas');
    expect(a.xp, 53652 * 2, reason: 'ni ne perd son contenu');
    d.deleteSync(recursive: true);
  });

  test('recharger une session lui ouvre une periode neuve', () async {
    final d = dossierTemporaire();
    final archives = Archives(d.path);
    final session = sessionJouee();
    session.periodes
      ..clear()
      ..addAll([Periode(1000, 1300)]);
    await archives.enregistre(session);
    final archive = (await archives.liste()).single;

    final vivante = Session(['Kaska-yopette', 'Kaska-nini']);
    archive.rechargeDans(vivante);
    // Les cinq minutes deja passees dessus sont closes ; une periode neuve
    // s'ouvre. C'est ainsi que douze lancements s'additionnent sans compter
    // les nuits.
    expect(vivante.periodes.length, 2);
    expect(vivante.periodes.first.ouverte, isFalse);
    expect(vivante.periodes.last.ouverte, isTrue);
    expect(vivante.duree, greaterThanOrEqualTo(300));
    d.deleteSync(recursive: true);
  });

  test('basculer ecrit chez la session rechargee, sans la dedoubler',
      () async {
    final d = dossierTemporaire();
    final archives = Archives(d.path);
    final ancienne = sessionJouee()..debut = 1000;
    await archives.enregistre(ancienne);
    await archives.clot(ancienne);
    final archive = (await archives.liste()).single;

    final vivante = Session(['Kaska-yopette', 'Kaska-nini']);
    archive.rechargeDans(vivante);
    archives.reprend(archive.fichier!);
    await archives.enregistre(vivante);

    final liste = await archives.liste();
    expect(liste.length, 1, reason: 'la session revient chez elle');
    expect(liste.single.enCours, isTrue);
    expect(liste.single.xp, 53652 * 2);
    d.deleteSync(recursive: true);
  });

  test('supprimer une session archivee efface son fichier', () async {
    final d = dossierTemporaire();
    final archives = Archives(d.path);
    final session = sessionJouee()..debut = 1000;
    await archives.enregistre(session);
    await archives.clot(session);

    final archive = (await archives.liste()).single;
    expect(await archives.supprime(archive), isTrue);
    expect(await archives.liste(), isEmpty);
    // Une seconde fois ne trouve plus rien, et ne pretend pas le contraire.
    expect(await archives.supprime(archive), isFalse);
    d.deleteSync(recursive: true);
  });

  test('la session alimentee ne se supprime pas', () async {
    final d = dossierTemporaire();
    final archives = Archives(d.path);
    final session = sessionJouee()..debut = 1000;
    await archives.enregistre(session);

    final archive = (await archives.liste()).single;
    // Son fichier serait recree a la sauvegarde suivante : une suppression
    // qui se defait toute seule vaut moins qu'un refus franc.
    expect(await archives.supprime(archive), isFalse);
    expect((await archives.liste()).length, 1);

    // Close, elle redevient supprimable.
    await archives.clot(session);
    expect(await archives.supprime((await archives.liste()).single), isTrue);
    expect(await archives.liste(), isEmpty);
    d.deleteSync(recursive: true);
  });

  test('supprimer laisse les autres sessions tranquilles', () async {
    final d = dossierTemporaire();
    final archives = Archives(d.path);
    for (final debut in [1000.0, 2000.0, 3000.0]) {
      final s = sessionJouee()..debut = debut;
      await archives.enregistre(s);
      await archives.clot(s);
    }
    final liste = await archives.liste();
    expect(liste.length, 3);

    expect(await archives.supprime(liste[1]), isTrue);
    final restantes = await archives.liste();
    expect(restantes.map((a) => a.debut), [3000, 1000]);
    d.deleteSync(recursive: true);
  });
  test("une session qui n'a pas bouge ne se reecrit pas", () async {
    final d = dossierTemporaire();
    final archives = Archives(d.path);
    final session = sessionJouee();

    await archives.enregistre(session);
    final fichier = d.listSync().whereType<File>().single;
    final ecritLe = fichier.lastModifiedSync();
    final contenu = fichier.readAsStringSync();

    // Rien n'a bouge : la sauvegarde revient toutes les vingt secondes, qu'on
    // joue ou non, et resserialisait toute la soiree a chaque fois — sur le
    // fil qui dessine la fenetre.
    fichier.setLastModifiedSync(ecritLe.subtract(const Duration(minutes: 1)));
    await archives.enregistre(session);
    expect(fichier.lastModifiedSync().isBefore(ecritLe), isTrue,
        reason: 'le fichier a ete reecrit alors que rien ne changeait');

    // Un gain, en revanche, doit partir sur le disque.
    session.recoit({
      'ts': 40,
      'type': 'FightEnd',
      'duration': 12,
      'participants': [
        {
          'name': 'Kaska-yopette',
          'xp': 999,
          'kamas': 7,
          'outcome': 2,
          'loot': const [],
        },
      ],
    });
    await archives.enregistre(session);
    expect(fichier.readAsStringSync(), isNot(contenu));

    d.deleteSync(recursive: true);
  });

}
