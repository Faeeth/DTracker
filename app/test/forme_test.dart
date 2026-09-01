/// Verrou sur la **forme** du fichier d'une session.
///
/// L'audit qui a mene a cette structure demandait qu'un combat porte tout ce
/// qu'il faut pour etre relu seul : ses participants avec leur experience,
/// leurs kamas et leur butin, ses challenges avec leur issue. Et que la
/// session ne soit rien de plus qu'une suite de combats, un nom, et les
/// intervalles pendant lesquels l'outil ecoutait.
///
/// Ce cas fige cette forme. Il echoue des qu'une clef disparait — c'est-a-dire
/// des qu'une archive deja ecrite deviendrait illisible.
library;

import 'dart:convert';

import 'package:dofus_tracker/modele/session.dart';
import 'package:dofus_tracker/source/archives.dart';
import 'package:flutter_test/flutter_test.dart';

import 'archives_test.dart' show sessionJouee;

void main() {
  test('une session archivee a la forme attendue', () {
    final session = sessionJouee()
      ..nom = 'Donjon Bouftou'
      ..numero = 7;
    session.periodes
      ..clear()
      ..addAll([Periode(1000, 1300), Periode(90000, 90600)]);

    final json = Archive.depuisSession(session).versJson();
    // Relu depuis son ecriture : ce qui est verifie ici est ce qui atterrit
    // sur le disque, pas la structure en memoire.
    final relu = jsonDecode(jsonEncode(json)) as Map<String, dynamic>;

    // ---- la session -------------------------------------------------------
    expect(relu['nom'], 'Donjon Bouftou');
    expect(relu['numero'], 7);
    expect(relu['periodes'], [
      {'debut': 1000, 'fin': 1300},
      {'debut': 90000, 'fin': 90600},
    ]);

    // ---- le combat, entier ------------------------------------------------
    final combat = (relu['combats'] as List).single as Map<String, dynamic>;
    expect(combat.keys.toSet(),
        {'fin', 'duree', 'participants', 'challenges'});

    final participants = combat['participants'] as List;
    expect(participants.length, 2, reason: 'les non suivis comptent aussi');
    final yopette = participants.first as Map<String, dynamic>;
    expect(yopette.keys.toSet(), {
      'nom',
      'niveau',
      'xp',
      // L'etat d'experience de cet instant : c'est lui qui permet de rendre
      // la barre de progression telle qu'elle etait, et non recalculee.
      'xp_total',
      'xp_seuil_bas',
      'xp_seuil_haut',
      'kamas',
      'butin',
    });
    expect(yopette['nom'], 'Kaska-yopette');
    expect(yopette['xp'], 53652);
    expect(yopette['kamas'], 255);
    expect(yopette['butin'], {
      '2663': {'quantite': 2, 'prix': 1567},
    });

    // ---- les challenges du combat ----------------------------------------
    final challenges = combat['challenges'] as List;
    expect(challenges.length, 2);
    final echoue = challenges.firstWhere((c) => c['reussi'] == false)
        as Map<String, dynamic>;
    expect(echoue['challenge_id'], 973);
    expect(echoue['origine'], 'impose');
    expect(echoue['combattants'], ['Kaska-yopette', 'Kaska-nini']);
    // `fautif` n'est pas ecrit : le flux ne le porte pas, et une clef nulle
    // dans chaque archive laisserait croire qu'on ne l'a pas remplie.
    expect(echoue.containsKey('fautif'), isFalse);
  });

  test('un combat se relit seul, sans sa session', () {
    final session = sessionJouee();
    final json = jsonDecode(jsonEncode(session.combats.single.versJson()))
        as Map<String, dynamic>;
    final combat = Combat.depuisJson(json);

    expect(combat.participants.length, 2);
    expect(combat.pour('Kaska-yopette')?.xp, 53652);
    expect(combat.pour('Kaska-yopette')?.butin[2663]?.$1, 2);
    expect(combat.challenges.length, 2);
    expect(combat.challengesReussis, 1);
    // La duree et l'engagement se deduisent l'un de l'autre.
    expect(combat.debut, combat.fin - combat.duree);
  });
}
