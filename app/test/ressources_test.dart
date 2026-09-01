/// Verrous sur la resolution des noms et des images.
///
/// Le protocole ne transporte que des identifiants, et plusieurs series de
/// numeros se cotoient : l'objet, son icone, le monstre, son sprite. Prendre
/// l'un pour l'autre ne donne pas une image manquante mais une **autre
/// image** — ce qui ne proteste jamais.
library;

import 'dart:convert';
import 'dart:io';

import 'package:dofus_tracker/source/ressources.dart';
import 'package:flutter_test/flutter_test.dart';

/// Un dossier `data/` minimal, avec ce qu'il faut pour resoudre un monstre.
///
/// Les numeros sont ceux qui ont revele la confusion en jeu : le Moskito porte
/// l'identifiant 61 et le sprite 22, tandis que le sprite 61 appartient a « La
/// Folle ». Les deux fichiers existent, et c'est bien la le piege.
Directory racineDeTest() {
  final d = Directory.systemTemp.createTempSync('res_test');
  final monstres = Directory('${d.path}/images/monster/2x')
    ..createSync(recursive: true);
  File('${monstres.path}/index.json').writeAsStringSync(jsonEncode({
    '22': 'moskito.png',
    '61': 'la_folle.png',
    '21': 'champ_champ.png',
    '59': 'boo.png',
  }));
  File('${d.path}/monstres.json').writeAsStringSync(jsonEncode({
    '61': {
      'g': 22,
      'n': {'1': 16, '4': 19},
    },
    '59': {
      'g': 21,
      'n': {'1': 16},
    },
    // Un monstre sans sprite connu : il ne doit pas en emprunter un autre.
    '999': {
      'n': {'1': 5},
    },
  }));
  return d;
}

void main() {
  late Directory racine;
  late Ressources res;

  setUp(() {
    racine = racineDeTest();
    res = Ressources(racine.path);
  });

  tearDown(() => racine.deleteSync(recursive: true));

  test('l\'image d\'un monstre passe par son sprite', () {
    // 61 est le Moskito ; son dessin est le 22. Le fichier « 61.png » existe
    // aussi — c'est « La Folle » — et c'est lui qui s'affichait.
    expect(res.imageMonstre(61), endsWith('moskito.png'));
    expect(res.imageMonstre(61), isNot(contains('la_folle')));
    expect(res.imageMonstre(59), endsWith('champ_champ.png'));
    expect(res.imageMonstre(59), isNot(contains('boo')));
  });

  test('un monstre sans sprite n\'en emprunte pas un autre', () {
    expect(res.imageMonstre(999), isNull);
    expect(res.imageMonstre(1234), isNull);
  });

  test('le niveau suit le grade', () {
    expect(res.niveauMonstre(61, 1), 16);
    expect(res.niveauMonstre(61, 4), 19);
    // Grade inconnu : on retombe sur le premier plutot que sur rien.
    expect(res.niveauMonstre(61, 3), 16);
    expect(res.niveauMonstre(1234, 1), isNull);
  });

  test('sans index, tout se tait proprement', () {
    // L'extraction est facultative : l'affichage doit s'en passer sans
    // casser, et se contenter de ce qu'il sait.
    final vide = Ressources('${racine.path}/absent');
    expect(vide.imageMonstre(61), isNull);
    expect(vide.niveauMonstre(61, 1), isNull);
    expect(vide.monstre(61), 'Monstre 61');
  });
}
