/// Verrous sur les langues.
///
/// Deux choses valent d'etre tenues dans le temps. D'abord qu'aucune langue
/// ne prenne du retard : la classe [Textes] est abstraite, donc le
/// compilateur refuse une traduction incomplete, mais rien n'empeche d'y
/// laisser le texte francais recopie. Ensuite que le reglage traduise
/// vraiment l'ecran, et pas seulement le fichier de langue.
library;

import 'dart:io';

import 'package:dofus_tracker/config.dart';
import 'package:dofus_tracker/i18n/en.dart';
import 'package:dofus_tracker/i18n/es.dart';
import 'package:dofus_tracker/i18n/fr.dart';
import 'package:dofus_tracker/i18n/pt.dart';
import 'package:dofus_tracker/i18n/textes.dart';
import 'package:dofus_tracker/modele/session.dart';
import 'package:dofus_tracker/source/archives.dart';
import 'package:dofus_tracker/vue/standard/navigation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';

import 'archives_test.dart' show dossierTemporaire, sessionJouee;
import 'coquille_test.dart' show monte;

void main() {
  tearDown(() => changeLangue(Langue.fr));

  test('les quatre langues sont completes et distinctes', () {
    // Un echantillon large plutot que quelques libelles : c'est la ou une
    // traduction bacle se voit — le francais recopie tel quel.
    const langues = [TextesFr(), TextesEn(), TextesEs(), TextesPt()];
    final fr = langues.first;
    for (final autre in langues.skip(1)) {
      final identiques = <String>[];
      // « Pause » n'y figure pas : le mot est le meme en anglais, et une
      // coincidence n'est pas un oubli.
      for (final (nom, a, b) in [
        ('reset', fr.resetInfobulle, autre.resetInfobulle),
        ('colPersonnage', fr.colPersonnage, autre.colPersonnage),
        ('colExperience', fr.colExperience, autre.colExperience),
        ('colButin', fr.colButin, autre.colButin),
        ('suiviSousTitre', fr.suiviSousTitre, autre.suiviSousTitre),
        ('aucunItem', fr.aucunItem, autre.aucunItem),
        ('horsCombat', fr.horsCombat, autre.horsCombat),
        ('triNom', fr.triNom, autre.triNom),
        ('gagnants', fr.gagnants, autre.gagnants),
        ('ongletFenetre', fr.ongletFenetre, autre.ongletFenetre),
        ('transparenceDetail', fr.transparenceDetail, autre.transparenceDetail),
        ('diagAucuneCapture', fr.diagAucuneCapture, autre.diagAucuneCapture),
        ('combatDejaCommence', fr.combatDejaCommence, autre.combatDejaCommence),
      ]) {
        if (a == b) identiques.add(nom);
      }
      expect(identiques, isEmpty,
          reason: 'non traduits en ${autre.runtimeType} : $identiques');
    }
  });

  testWidgets('les quatre drapeaux se peignent', (tester) async {
    // Dessines et non emojis : Windows n'a pas les glyphes des indicatifs
    // regionaux et rendrait « FR » en lettres. Et un SVG mal forme se charge
    // sans erreur sans rien peindre — verifier que le fichier existe ne
    // suffit donc pas.
    for (final l in Langue.values) {
      expect(File(l.drapeau).existsSync(), isTrue,
          reason: 'le drapeau de ${l.nom} manque');
      await tester.pumpWidget(MaterialApp(
        home: Center(
          child: SizedBox(
            width: 21,
            height: 14,
            child: SvgPicture.asset(l.drapeau, fit: BoxFit.cover),
          ),
        ),
      ));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: 'drapeau ${l.code}');
    }
  });

  test('un code inconnu retombe sur le francais', () {
    // Un fichier de reglages edite a la main, ou ecrit par une version qui
    // proposait une langue de plus.
    expect(Langue.depuisCode('kl'), Langue.fr);
    expect(Langue.depuisCode(null), Langue.fr);
    expect(Langue.depuisCode('pt'), Langue.pt);
  });

  test('chaque langue s\'annonce dans la sienne', () {
    // « Spanish » dans une liste en francais n'aide pas qui cherche
    // « Español ».
    expect(Langue.es.nom, 'Español');
    expect(Langue.pt.nom, 'Português');
    expect(Langue.en.nom, 'English');
  });

  test('changer de langue change les textes partout', () {
    expect(T.colPersonnage, 'PERSONNAGE');
    expect(Onglet.suivi.libelle, 'Suivi');

    changeLangue(Langue.en);
    expect(T.colPersonnage, 'CHARACTER');
    // Jusque dans les enumerations : leurs libelles sont des getters, sans
    // quoi ils resteraient figes a la valeur posee au chargement de la classe.
    expect(Onglet.suivi.libelle, 'Overview');
    expect(Onglet.monInventaire.libelle, 'My inventory');

    changeLangue(Langue.es);
    expect(T.colPersonnage, 'PERSONAJE');
    expect(langueCourante, Langue.es);
  });

  testWidgets('le reglage traduit l\'ecran', (tester) async {
    final d = dossierTemporaire();
    final config = Config(personnages: const ['Kaska-yopette']);
    late StateSetter rebatit;
    await monte(tester,
        session: sessionJouee(),
        archives: Archives(d.path),
        config: config,
        // Comme le fait la fenetre : elle se rebatit quand un reglage change.
        onReglageChange: () => rebatit(() {}),
        capteur: (setter) => rebatit = setter);

    expect(find.text('PERSONNAGE'), findsWidgets);

    await tester.tap(find.text('Réglages'));
    await tester.pump();
    await tester.tap(find.text('Langue'));
    await tester.pump();
    await tester.tap(find.text('English'));
    await tester.pumpAndSettle();

    // Le reglage est ecrit, et l'ecran suit sans qu'on ait a rouvrir la
    // fenetre.
    expect(config.langue, 'en');
    expect(find.text('Settings'), findsWidgets);
    expect(find.text('Réglages'), findsNothing);

    d.deleteSync(recursive: true);
  });

  testWidgets('la session garde son nom traduit a la bascule', (tester) async {
    final d = dossierTemporaire();
    final session = Session(['Kaska-yopette']);
    await monte(tester,
        session: session,
        archives: Archives(d.path),
        config: Config(personnages: const ['Kaska-yopette']));

    // Le nom par defaut vient de la langue : une session jamais renommee doit
    // le refleter, sans quoi « Session 3 » resterait en francais pour qui a
    // choisi l'anglais.
    changeLangue(Langue.pt);
    expect(T.sessionNumero(3), 'Sessão 3');

    d.deleteSync(recursive: true);
  });
}
