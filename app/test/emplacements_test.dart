/// Verrous sur l'emplacement des fichiers.
///
/// Ce sont les cas qui decident si une mise a jour perd la soiree de
/// quelqu'un. Ils ne peuvent pas dependre de la machine : chacun se joue dans
/// un dossier temporaire, avec des emplacements construits a la main.
library;

import 'dart:io';

import 'package:dofus_tracker/source/emplacements.dart';
import 'package:flutter_test/flutter_test.dart';

Directory dossierTemporaire() =>
    Directory.systemTemp.createTempSync('dtracker_ou_');

void main() {
  test('reprendre ne recouvre jamais ce qui est deja la', () async {
    final d = dossierTemporaire();
    addTearDown(() => d.deleteSync(recursive: true));

    // Une installation precedente, a cote de l'executable.
    final ancien = Directory('${d.path}/ancien')..createSync();
    File('${ancien.path}/settings.json').writeAsStringSync('{"ancien":1}');
    File('${ancien.path}/cache.json').writeAsStringSync('{"prix":1}');
    Directory('${ancien.path}/sessions').createSync();
    File('${ancien.path}/sessions/session-1.json').writeAsStringSync('vieux');
    File('${ancien.path}/sessions/session-2.json').writeAsStringSync('vieux');

    // Le nouvel emplacement, ou l'utilisateur a deja joue.
    final ou = Emplacements(
      donnees: '${d.path}/neuf',
      programme: '${d.path}/programme',
      installe: true,
    );
    await Directory(ou.sessions).create(recursive: true);
    File('${ou.donnees}/settings.json').writeAsStringSync('{"neuf":1}');
    File('${ou.sessions}/session-1.json').writeAsStringSync('recent');

    await ou.prepare(reprises: [ancien.path]);

    // Ce qui existait ici a la priorite : la reprise n'est pas une
    // restauration, c'est un rattrapage de ce qui manque.
    expect(File('${ou.donnees}/settings.json').readAsStringSync(),
        '{"neuf":1}');
    expect(File('${ou.sessions}/session-1.json').readAsStringSync(), 'recent');
    // Et ce qui manquait est recupere.
    expect(File('${ou.donnees}/cache.json').readAsStringSync(), '{"prix":1}');
    expect(File('${ou.sessions}/session-2.json').readAsStringSync(), 'vieux');
  });

  test('prepare cree ce qu\'il faut, et supporte d\'etre relance', () async {
    final d = dossierTemporaire();
    addTearDown(() => d.deleteSync(recursive: true));
    final ou = Emplacements(
      donnees: '${d.path}/donnees',
      programme: d.path,
      installe: true,
    );

    await ou.prepare();
    expect(Directory(ou.sessions).existsSync(), isTrue);

    // Relance : l'outil s'ouvre plusieurs fois par soiree, et un dossier deja
    // la n'est pas une erreur.
    File('${ou.sessions}/session-1.json').writeAsStringSync('garde');
    await ou.prepare(reprises: ['${d.path}/inexistant']);
    expect(File('${ou.sessions}/session-1.json').readAsStringSync(), 'garde');
  });

  test('installe ou non, les donnees ne vont pas au meme endroit', () {
    const installe = Emplacements(
      donnees: 'C:/Users/x/AppData/Roaming/DTracker',
      programme: 'C:/Program Files/DTracker',
      installe: true,
    );
    // Les images extraites du client suivent l'utilisateur : elles ne
    // viennent pas avec le programme, et une mise a jour ne doit pas les
    // emporter.
    expect(installe.ressources, 'C:/Users/x/AppData/Roaming/DTracker/data');
    // Rien n'est ecrit dans `Program Files` : l'outil n'y aurait meme pas le
    // droit sans elevation.
    expect(installe.cache.startsWith(installe.donnees), isTrue);
    expect(installe.sessions.startsWith(installe.donnees), isTrue);

    const sources = Emplacements(
      donnees: 'D:/projet',
      programme: 'D:/projet/dofus_stats',
      installe: false,
    );
    // Depuis les sources, rien ne part vers le dossier de l'utilisateur : on
    // ne veut pas des sessions de mise au point melees aux vraies.
    expect(sources.ressources, 'D:/projet/dofus_stats/data');
  });

  test('la reconnaissance trouve les sources depuis les tests', () {
    // Le harnais de test tourne depuis le projet : `pubspec.yaml` est
    // au-dessus, donc on doit etre reconnu comme non installe.
    final ou = Emplacements.reconnait();
    expect(ou.installe, isFalse,
        reason: 'un test ne doit jamais ecrire dans %APPDATA%');
    expect(File('${ou.donnees}/pubspec.yaml').existsSync(), isTrue);
  });
}
