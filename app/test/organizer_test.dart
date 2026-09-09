/// Les equipes, leur ecriture dans les reglages, et ce qui part au natif.
library;

import 'dart:convert';
import 'dart:io';

import 'package:dofus_tracker/config.dart';
import 'package:dofus_tracker/modele/organizer.dart';
import 'package:dofus_tracker/source/organizer.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Retient ce que le controleur pousse, au lieu de le passer au natif.
class _PontEspion extends PontOrganizer {
  _PontEspion() : super(canal: const MethodChannel('test/organizer'));

  List<LiaisonNative> dernieres = const [];
  Set<String> refuses = <String>{};

  @override
  void ecoute() {}

  @override
  Future<Set<String>> applique(List<LiaisonNative> liaisons) async {
    dernieres = liaisons;
    return refuses;
  }

  @override
  Future<void> suspend({required bool suspendu}) async {}
}

const _f1 = Raccourci(touche: 0x70, libelle: 'F1');
const _f2 = Raccourci(touche: 0x71, libelle: 'F2');

void main() {
  late Directory dossier;
  late Config config;
  late _PontEspion pont;
  late Organizer organizer;

  setUp(() async {
    dossier = await Directory.systemTemp.createTemp('organizer_test');
    config = Config();
    pont = _PontEspion();
    organizer = Organizer(config: config, pont: pont);
    await organizer.demarre();
  });

  tearDown(() async {
    organizer.dispose();
    if (dossier.existsSync()) await dossier.delete(recursive: true);
  });

  Future<void> pousse() => organizer.synchronise;

  group('reglages', () {
    test('les equipes se relisent telles qu on les a ecrites', () async {
      final equipe = organizer.ajouteEquipe('Kaska');
      organizer.ajoutePersonnage(
        equipe.id,
        nom: 'Kaska-yopette',
        titre: 'Kaska-yopette',
        raccourci: _f1,
      );
      await pousse();
      await config.enregistre(dossier.path);

      final relue = await Config.charge(dossier.path);
      expect(relue.equipes, hasLength(1));
      expect(relue.equipes.single.nom, 'Kaska');
      final personnage = relue.equipes.single.personnages.single;
      expect(personnage.nom, 'Kaska-yopette');
      expect(personnage.raccourci, _f1);
      expect(personnage.raccourci!.nom, 'F1');
    });

    test('la classe et le sexe survivent a l ecriture', () async {
      final equipe = organizer.ajouteEquipe('Kaska');
      organizer.ajoutePersonnage(
        equipe.id,
        nom: 'Kaska-yopette',
        titre: 'Kaska-yopette',
        classe: 7,
        feminin: true,
      );
      await pousse();
      await config.enregistre(dossier.path);

      final relu = (await Config.charge(dossier.path))
          .equipes
          .single
          .personnages
          .single;
      expect(relu.classe, 7);
      expect(relu.feminin, isTrue);
    });

    test('un personnage sans classe n en gagne pas a la relecture', () async {
      final equipe = organizer.ajouteEquipe('Kaska');
      organizer.ajoutePersonnage(equipe.id, nom: 'A', titre: 'A');
      await pousse();
      await config.enregistre(dossier.path);

      final relu = (await Config.charge(dossier.path))
          .equipes
          .single
          .personnages
          .single;
      expect(relu.classe, isNull);
      expect(relu.feminin, isFalse);
    });

    test('une equipe repliee se retrouve repliee', () async {
      final equipe = organizer.ajouteEquipe('Kaska');
      organizer.replieEquipe(equipe.id, true);
      await pousse();
      await config.enregistre(dossier.path);

      final relue = await Config.charge(dossier.path);
      expect(relue.equipes.single.replie, isTrue);
    });

    test('un fichier ecrit a la main est lu', () async {
      // C'est ainsi que la configuration arrive quand on la prepare ailleurs,
      // et c'est le format que le fichier doit accepter.
      await Config.fichier(dossier.path).writeAsString(jsonEncode({
        'organizer_teams': [
          {
            'id': 'kaska',
            'name': 'Kaska',
            'enabled': true,
            'characters': [
              {
                'id': 'c1',
                'name': 'Kaska-yopette',
                'window_title': 'Kaska-yopette',
                'enabled': true,
                'shortcut': {'key_code': 112, 'modifiers': 0, 'key_name': 'F1'},
              },
            ],
          },
        ],
      }));

      final relue = await Config.charge(dossier.path);
      expect(relue.equipes, hasLength(1));
      expect(relue.equipes.single.personnages.single.titre, 'Kaska-yopette');
      expect(relue.equipes.single.vivants, hasLength(1));
    });

    test('ecrire les equipes ne touche pas aux autres reglages', () async {
      await Config.fichier(dossier.path).writeAsString(jsonEncode({
        'language': 'es',
        'un_reglage_inconnu': 42,
      }));
      final chargee = await Config.charge(dossier.path);
      final organizerBis = Organizer(config: chargee, pont: _PontEspion());
      organizerBis.ajouteEquipe('Kaska');
      await organizerBis.synchronise;
      await chargee.enregistre(dossier.path);
      organizerBis.dispose();

      final brut = jsonDecode(
        await Config.fichier(dossier.path).readAsString(),
      ) as Map<String, dynamic>;
      expect(brut['language'], 'es');
      expect(brut['un_reglage_inconnu'], 42,
          reason: 'une clef inconnue doit survivre');
      expect((brut['organizer_teams'] as List), hasLength(1));
    });
  });

  group('ce qui part au natif', () {
    test('seuls les personnages lies et actifs sont pousses', () async {
      final equipe = organizer.ajouteEquipe('Kaska');
      organizer.ajoutePersonnage(equipe.id, nom: 'A', titre: 'A');
      await pousse();
      expect(pont.dernieres, isEmpty, reason: 'sans touche, rien a enregistrer');

      final lie = organizer.ajoutePersonnage(
        equipe.id,
        nom: 'B',
        titre: 'B',
        raccourci: _f1,
      );
      await pousse();
      expect(pont.dernieres, hasLength(1));

      organizer.activePersonnage(equipe.id, lie.id, false);
      await pousse();
      expect(pont.dernieres, isEmpty);
    });

    test('une equipe desactivee sort de la resolution', () async {
      final equipe = organizer.ajouteEquipe('Kaska');
      organizer.ajoutePersonnage(
        equipe.id,
        nom: 'A',
        titre: 'A',
        raccourci: _f1,
      );
      await pousse();
      expect(pont.dernieres, hasLength(1));

      organizer.activeEquipe(equipe.id, false);
      await pousse();
      expect(pont.dernieres, isEmpty);
    });

    test('deux equipes sur la meme touche font une seule liaison', () async {
      final une = organizer.ajouteEquipe('Kaska');
      final deux = organizer.ajouteEquipe('Equipe 2');
      organizer.ajoutePersonnage(
        une.id,
        nom: 'Kaska-yopette',
        titre: 'Kaska-yopette',
        raccourci: _f1,
      );
      organizer.ajoutePersonnage(
        deux.id,
        nom: 'Douanopuncture',
        titre: 'Douanopuncture',
        raccourci: _f1,
      );
      await pousse();

      expect(pont.dernieres, hasLength(1));
      // Les deux equipes restent actives : c'est la fenetre ouverte qui
      // tranche, et l'ordre des equipes donne la priorite.
      expect(pont.dernieres.single.cibles, [
        'Kaska-yopette',
        'Douanopuncture',
      ]);
      expect(pont.dernieres.single.touche, _f1.touche);
    });

    test('deux touches font deux liaisons', () async {
      final equipe = organizer.ajouteEquipe('Kaska');
      organizer.ajoutePersonnage(
        equipe.id,
        nom: 'A',
        titre: 'A',
        raccourci: _f1,
      );
      organizer.ajoutePersonnage(
        equipe.id,
        nom: 'B',
        titre: 'B',
        raccourci: _f2,
      );
      await pousse();
      expect(pont.dernieres, hasLength(2));
      expect(organizer.actifs, 2);
    });

    test('une touche refusee est signalee sur son personnage', () async {
      final equipe = organizer.ajouteEquipe('Kaska');
      pont.refuses = {_f1.signature};
      final personnage = organizer.ajoutePersonnage(
        equipe.id,
        nom: 'A',
        titre: 'A',
        raccourci: _f1,
      );
      await pousse();

      final relu = organizer.equipes.single.personnages.single;
      expect(relu.id, personnage.id);
      expect(organizer.enConflit(relu), isTrue);
      expect(organizer.actifs, 0);
      expect(organizer.aDesConflits, isTrue);
    });
  });

  group('reprise', () {
    test('reessayer reprend les touches qu on a liberees', () async {
      final equipe = organizer.ajouteEquipe('Kaska');
      pont.refuses = {_f1.signature};
      organizer.ajoutePersonnage(
        equipe.id,
        nom: 'A',
        titre: 'A',
        raccourci: _f1,
      );
      await pousse();
      expect(organizer.aDesConflits, isTrue);

      // L'application qui tenait la touche vient de fermer.
      pont.refuses = <String>{};
      await organizer.reessaie();
      expect(organizer.aDesConflits, isFalse);
      expect(organizer.actifs, 1);
    });

    test('sans conflit, reessayer ne repousse rien', () async {
      final equipe = organizer.ajouteEquipe('Kaska');
      organizer.ajoutePersonnage(
        equipe.id,
        nom: 'A',
        titre: 'A',
        raccourci: _f1,
      );
      await pousse();
      pont.dernieres = const [];
      await organizer.reessaie();
      expect(pont.dernieres, isEmpty);
    });
  });

  group('pli', () {
    test('replier ne touche pas aux touches enregistrees', () async {
      final equipe = organizer.ajouteEquipe('Kaska');
      organizer.ajoutePersonnage(
        equipe.id,
        nom: 'A',
        titre: 'A',
        raccourci: _f1,
      );
      await pousse();
      expect(pont.dernieres, hasLength(1));

      // Reenregistrer tout le jeu pour un pli ouvrirait une fenetre pendant
      // laquelle les touches ne repondent pas.
      pont.dernieres = const [];
      organizer.replieEquipe(equipe.id, true);
      await pousse();
      expect(pont.dernieres, isEmpty);
      expect(organizer.equipes.single.replie, isTrue);
      expect(organizer.actifs, 1, reason: 'une equipe repliee repond encore');
    });
  });

  group('raccourcis', () {
    test('la signature ne depend que de ce qui s enregistre', () {
      const a = Raccourci(touche: 0x70, libelle: 'F1');
      const b = Raccourci(touche: 0x70, libelle: 'autre chose');
      expect(a, b);
      expect(a.signature, b.signature);

      const avecCtrl = Raccourci(touche: 0x70, modificateurs: Modificateur.ctrl);
      expect(avecCtrl == a, isFalse);
      expect(avecCtrl.affichage, 'Ctrl + F1');
    });

    test('le libelle capture survit a l ecriture', () async {
      // Le code d une touche de ponctuation depend de la disposition : sans le
      // libelle, on ne saurait pas le reafficher.
      const oem = Raccourci(touche: 0xBA, libelle: r'$');
      final equipe = organizer.ajouteEquipe('Kaska');
      organizer.ajoutePersonnage(
        equipe.id,
        nom: 'A',
        titre: 'A',
        raccourci: oem,
      );
      await pousse();
      await config.enregistre(dossier.path);

      final relue = await Config.charge(dossier.path);
      expect(relue.equipes.single.personnages.single.raccourci!.nom, r'$');
    });

    test('les touches sans libelle se nomment depuis leur code', () {
      expect(nomDeTouche(0x70), 'F1');
      expect(nomDeTouche(0x7B), 'F12');
      expect(nomDeTouche(0x41), 'A');
      expect(nomDeTouche(0x60), 'Num 0');
      expect(nomDeTouche(0x2E), 'Suppr');
    });
  });
}
