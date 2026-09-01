/// Verrous sur la pile de navigation.
///
/// Elle est volontairement separee de l'affichage : c'est la partie ou l'on se
/// trompe, et elle se verifie sans monter le moindre widget.
library;

import 'package:dofus_tracker/modele/session.dart';
import 'package:dofus_tracker/source/archives.dart';
import 'package:dofus_tracker/vue/standard/navigation.dart';
import 'package:flutter_test/flutter_test.dart';

Archive archiveDeTest({String nom = 'Donjon Bouftou'}) => Archive(
      nom: nom,
      numero: 3,
      periodes: [Periode(1000, 1300)],
      enCours: false,
      personnages: const [],
      challenges: const [],
      journal: const [],
      combats: const [],
      fichier: 'session-1.json',
    );

Combat combatDeTest() =>
    Combat(fin: 5, duree: 4, participants: const []);

void main() {
  test('la racine est le suivi', () {
    final n = Navigation();
    expect(n.courant, isA<EcranSuivi>());
    expect(n.onglet, Onglet.suivi);
    expect(n.peutRevenir, isFalse);
    expect(n.chemin, ['Suivi']);
  });

  test('ouvrir empile, revenir depile', () {
    final n = Navigation();
    n.ouvre(const EcranPersonnage('Kaska-nini'));
    expect(n.courant.titre, 'Kaska-nini');
    expect(n.peutRevenir, isTrue);

    n.revient();
    expect(n.courant, isA<EcranSuivi>());
    expect(n.peutRevenir, isFalse);
    // Revenir a la racine ne fait rien de plus.
    n.revient();
    expect(n.courant, isA<EcranSuivi>());
  });

  test('une sous-page garde son onglet allume', () {
    final n = Navigation();
    n.ouvre(const EcranPersonnage('Kaska-nini'));
    // La page d'un personnage appartient au suivi : c'est de la qu'on y vient,
    // et c'est la que le rail doit rester allume.
    expect(n.onglet, Onglet.suivi);

    n.choisit(Onglet.sessions);
    n.ouvre(EcranSession(archiveDeTest()));
    expect(n.onglet, Onglet.sessions);
    n.ouvre(EcranCombat(combatDeTest()));
    expect(n.onglet, Onglet.sessions);
  });

  test('un combat ouvert depuis le suivi reste au suivi', () {
    final n = Navigation();
    n.ouvre(const EcranPersonnage('Kaska-nini'));
    n.ouvre(EcranCombat(combatDeTest(), onglet: Onglet.suivi));
    // Le meme recapitulatif se lit depuis deux endroits ; l'onglet allume doit
    // etre celui d'ou l'on vient, sinon le rail saute sous les yeux.
    expect(n.onglet, Onglet.suivi);
  });

  test('choisir un onglet remet sa racine', () {
    final n = Navigation();
    n.ouvre(const EcranPersonnage('Kaska-nini'));
    n.ouvre(EcranCombat(combatDeTest()));

    n.choisit(Onglet.reglages);
    expect(n.courant, isA<EcranReglages>());
    expect(n.peutRevenir, isFalse, reason: 'la pile repart de zero');
  });

  test('recliquer sur l\'onglet courant ramene a sa racine', () {
    final n = Navigation();
    n.choisit(Onglet.sessions);
    n.ouvre(EcranSession(archiveDeTest()));
    expect(n.peutRevenir, isTrue);

    // C'est le geste qu'on fait sans y penser quand on s'est enfonce dans un
    // detail : recliquer l'onglet ou l'on est deja.
    n.choisit(Onglet.sessions);
    expect(n.courant, isA<EcranSessions>());
    expect(n.peutRevenir, isFalse);
  });

  test('le titre d\'une session vient de son nom', () {
    expect(EcranSession(archiveDeTest()).titre, 'Donjon Bouftou');
    // Une archive sans nom ne doit pas afficher un titre vide.
    expect(EcranSession(archiveDeTest(nom: '')).titre, 'Session');
  });

  test('les combats et l\'inventaire se rattachent au suivi', () {
    expect(Onglet.mesCombats.racine, Onglet.suivi);
    expect(Onglet.monInventaire.racine, Onglet.suivi);
    expect(Onglet.mesCombats.estSousMenu, isTrue);
    // Une racine se rattache a elle-meme : c'est ce qui la distingue.
    expect(Onglet.suivi.racine, Onglet.suivi);
    expect(Onglet.suivi.estSousMenu, isFalse);
    expect(Onglet.sessions.estSousMenu, isFalse);
    expect(Onglet.reglages.estSousMenu, isFalse);
  });

  test('chaque onglet mene a son ecran', () {
    final n = Navigation();
    for (final onglet in Onglet.values) {
      n.choisit(onglet);
      expect(n.courant.onglet, onglet,
          reason: '${onglet.libelle} n\'ouvre pas son propre ecran');
      expect(n.peutRevenir, isFalse);
    }
  });

  test('une sous-page du personnage garde le suivi allume', () {
    final n = Navigation()..ouvre(const EcranPersonnage('Kaska-yopette'));
    // Le personnage s'ouvre depuis le tableau du suivi : c'est cette entree
    // du rail qui doit rester allumee, pas une autre.
    expect(n.onglet, Onglet.suivi);
    expect(n.courant.sousTitre, 'Son butin sur cette session');
  });
}
