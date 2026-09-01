/// Verrous sur ce que le suivi retient d'une session a l'autre.
///
/// Classes et prix n'arrivent qu'a des moments precis — un passage sur la
/// carte, une connexion. Les perdre, c'est repartir aveugle : portraits vides
/// et butin sans valeur jusqu'a ce que le jeu veuille bien les redonner.
library;

import 'dart:convert';
import 'dart:io';

import 'package:dofus_tracker/modele/session.dart';
import 'package:dofus_tracker/source/cache.dart';
import 'package:dofus_tracker/config.dart';
import 'package:flutter_test/flutter_test.dart';

Directory dossierTemporaire() =>
    Directory.systemTemp.createTempSync('dofus_tracker_test');

void main() {
  test('un cache vide ne fait pas echouer la lecture', () async {
    final d = dossierTemporaire();
    final cache = Cache('${d.path}/cache.json');
    await cache.charge();
    expect(cache.classes, isEmpty);
    expect(cache.prix, isEmpty);
    d.deleteSync(recursive: true);
  });

  test('aller-retour : ce qui est appris se relit', () async {
    final d = dossierTemporaire();
    final cache = Cache('${d.path}/cache.json');
    expect(cache.apprendClasse('Kaska-yopette', 8), isTrue);
    expect(cache.apprendClasse('Kaska-yopette', 8), isFalse,
        reason: 'deja connu, rien a reecrire');
    cache.apprendPrix({303: 25, 2663: 1567});
    await cache.enregistre();

    final relu = Cache('${d.path}/cache.json');
    await relu.charge();
    expect(relu.classes['Kaska-yopette'], 8);
    expect(relu.prix[2663], 1567);
    d.deleteSync(recursive: true);
  });

  test('le cache de la version Python est repris', () async {
    // Il indexe les classes par identifiant ; le notre par nom. Les deux
    // formes sont lues, sans quoi la bascule perdrait tout ce qui etait su.
    final d = dossierTemporaire();
    File('${d.path}/ancien.json').writeAsStringSync(jsonEncode({
      'character_names': {'913174429986': 'Kaska-yopette'},
      'character_breeds': {'913174429986': 8},
      'prices': {'303': 25},
    }));
    final cache = Cache('${d.path}/cache.json');
    await cache.charge(reprises: ['${d.path}/ancien.json']);
    expect(cache.classes['Kaska-yopette'], 8);
    expect(cache.prix[303], 25);

    // Et il est recopie a notre emplacement, pour n'avoir plus a y revenir.
    await cache.enregistre();
    expect(File('${d.path}/cache.json').existsSync(), isTrue);
    d.deleteSync(recursive: true);
  });

  test('le notre l\'emporte sur l\'ancien', () async {
    final d = dossierTemporaire();
    File('${d.path}/cache.json')
        .writeAsStringSync(jsonEncode({'breeds': {'Kaska-nini': 7}}));
    File('${d.path}/ancien.json').writeAsStringSync(jsonEncode({
      'character_names': {'1': 'Kaska-nini'},
      'character_breeds': {'1': 99},
    }));
    final cache = Cache('${d.path}/cache.json');
    await cache.charge(reprises: ['${d.path}/ancien.json']);
    expect(cache.classes['Kaska-nini'], 7);
    d.deleteSync(recursive: true);
  });

  test('la fiche d\'un personnage renseigne sa classe', () {
    final s = Session(['Kaska-yopette']);
    // Il est suivi mais pas encore vu : sa ligne n'existe pas.
    expect(s.lignes, isEmpty);
    expect(s.tousLesSuivis.first.classe, isNull);
    final change = s.recoit({
      'ts': 1,
      'type': 'CharacterInfo',
      'character_id': 913174429986,
      'name': 'Kaska-yopette',
      'breed': 8,
    });
    expect(change, isTrue);
    expect(s.lignes.first.classe, 8);
  });

  test('une fiche deja connue ne demande pas de repeindre', () {
    final s = Session(['Kaska-yopette']);
    const fiche = {
      'ts': 1.0,
      'type': 'CharacterInfo',
      'character_id': 1,
      'name': 'Kaska-yopette',
      'breed': 8,
    };
    expect(s.recoit(Map.of(fiche)), isTrue);
    expect(s.recoit(Map.of(fiche)), isFalse);
  });

  test('la classe d\'un personnage non suivi est retenue quand meme', () {
    // On peut decider de le suivre plus tard ; l'avoir croise suffit.
    final s = Session(['Kaska-nini']);
    s.recoit({
      'ts': 1,
      'type': 'CharacterInfo',
      'character_id': 2,
      'name': 'Kaska-Osa',
      'breed': 2,
    });
    expect(s.classesApprises['Kaska-Osa'], 2);
  });

  test('le fond ne peut pas etre plus opaque que le texte', () {
    // La fenetre porte l'opacite du texte et le fond se peint dessous : un
    // fond plus opaque que le texte est physiquement hors d'atteinte, et le
    // borner vaut mieux que de le laisser demander l'impossible.
    final config = Config()
      ..opaciteTexte = 40
      ..opaciteFond = 90
      ..borne();
    expect(config.opaciteFond, 40);

    // En dessous, il garde sa valeur.
    config
      ..opaciteFond = 20
      ..borne();
    expect(config.opaciteFond, 20);

    // Et le texte garde son plancher : illisible, la vue ne sert plus a rien.
    config
      ..opaciteTexte = 0
      ..borne();
    expect(config.opaciteTexte, opaciteTexteMin);
  });
}
