/// La navigation de la vue standard.
///
/// Des **pages**, pas des fenetres surgissantes. Une popup convient a une
/// question fermee — « supprimer ? » — et convient mal a tout le reste : elle
/// n'a pas d'adresse, on ne peut pas revenir en arriere dedans, et elle
/// empeche de regarder autre chose en attendant.
///
/// Le modele est une **pile**. Le rail pose la racine — Suivi, Sessions,
/// Reglages — et le contenu empile ce qu'on ouvre depuis lui. Revenir, c'est
/// depiler ; changer d'onglet, c'est remplacer la pile.
///
/// Elle est volontairement separee de l'affichage : c'est la partie ou l'on se
/// trompe, et elle se verifie sans monter le moindre widget.
library;

import '../../modele/session.dart';
import '../../source/archives.dart';
import '../../i18n/textes.dart';

/// Les trois racines, celles que le rail propose.
/// Les icones vivent dans le rail, pas ici : ce fichier ne connait que le
/// modele, et l'y faire dependre de la bibliotheque de composants pour trois
/// glyphes serait payer cher une commodite.
enum Onglet {
  suivi,
  mesCombats,
  monInventaire,
  sessions,
  reglages;

  /// Libelle et description suivent la langue : des getters, non des valeurs
  /// posees a la construction de l'enumeration.
  String get libelle => switch (this) {
    Onglet.suivi => T.suivi,
    Onglet.mesCombats => T.mesCombats,
    Onglet.monInventaire => T.monInventaire,
    Onglet.sessions => T.sessions,
    Onglet.reglages => T.reglages,
  };

  String get description => switch (this) {
    Onglet.suivi => T.suiviOnglet,
    Onglet.mesCombats => T.mesCombatsOnglet,
    Onglet.monInventaire => T.monInventaireOnglet,
    Onglet.sessions => T.sessionsSousTitre,
    Onglet.reglages => T.reglagesSousTitre,
  };

  /// L'entree de premier niveau a laquelle celle-ci se rattache.
  ///
  /// Les combats et l'inventaire du groupe sont deux facons de regarder la
  /// session en cours : ils appartiennent au suivi, et le rail les montre en
  /// retrait sous lui plutot que d'allonger la liste des racines.
  Onglet get racine => switch (this) {
    Onglet.mesCombats || Onglet.monInventaire => Onglet.suivi,
    _ => this,
  };

  bool get estSousMenu => racine != this;
}

/// Un ecran affichable.
sealed class Ecran {
  const Ecran();

  /// L'onglet du rail auquel l'ecran appartient : c'est lui qui reste allume.
  Onglet get onglet;

  /// Le titre en tete de la page.
  String get titre;

  /// La ligne qui precise le titre, quand elle apporte quelque chose.
  String? get sousTitre => null;
}

class EcranSuivi extends Ecran {
  const EcranSuivi();
  @override
  Onglet get onglet => Onglet.suivi;
  @override
  String get titre => T.suivi;
  @override
  String? get sousTitre => T.suiviSousTitre;
}

class EcranSessions extends Ecran {
  const EcranSessions();
  @override
  Onglet get onglet => Onglet.sessions;
  @override
  String get titre => T.sessions;
  @override
  String? get sousTitre => T.sessionsSousTitre;
}

class EcranReglages extends Ecran {
  const EcranReglages();
  @override
  Onglet get onglet => Onglet.reglages;
  @override
  String get titre => T.reglages;
}

/// La page d'un personnage : son butin, et rien d'autre.
///
/// Ses combats y ont eu leur onglet. Cliquer un personnage, c'est vouloir
/// voir ce qu'il a ramasse ; les combats se regardent pour la session entiere,
/// et ils ont desormais leur propre entree dans le rail.
///
/// `ShadTable` installe ses propres detecteurs sur ses lignes : une seconde
/// cible glissee dans une cellule n'y recevait jamais le clic, et le symptome
/// etait muet — la cellule paraissait simplement inerte. D'ou une seule cible
/// par ligne.
class EcranPersonnage extends Ecran {
  const EcranPersonnage(this.personnage);
  final String personnage;
  @override
  Onglet get onglet => Onglet.suivi;
  @override
  String get titre => personnage;
  @override
  String? get sousTitre => T.sonButin;
}

/// Tous les combats de la session, sans distinction de personnage.
///
/// La page d'un personnage ne montre plus que son butin : ses combats se
/// lisaient dans un onglet qu'il fallait deviner. Ils sont ici, entiers, avec
/// les totaux du groupe.
class EcranMesCombats extends Ecran {
  const EcranMesCombats();
  @override
  Onglet get onglet => Onglet.mesCombats;
  @override
  String get titre => T.mesCombats;
  @override
  String? get sousTitre => T.mesCombatsOnglet;
}

/// Le butin du groupe, avec le choix de qui y entre.
class EcranMonInventaire extends Ecran {
  const EcranMonInventaire();
  @override
  Onglet get onglet => Onglet.monInventaire;
  @override
  String get titre => T.monInventaire;
  @override
  String? get sousTitre => T.butinSession;
}

/// Le detail d'une session archivee.
class EcranSession extends Ecran {
  const EcranSession(this.archive);
  final Archive archive;
  @override
  Onglet get onglet => Onglet.sessions;
  @override
  String get titre => archive.nom.isEmpty ? 'Session' : archive.nom;
}

/// L'inventaire d'un personnage sur une session archivee.
class EcranButinArchive extends Ecran {
  const EcranButinArchive(this.archive, this.personnage);
  final Archive archive;
  final String personnage;
  @override
  Onglet get onglet => Onglet.sessions;
  @override
  String get titre => T.butinDe(personnage);
  @override
  String? get sousTitre => archive.nom.isEmpty ? 'Session' : archive.nom;
}

/// Le recapitulatif d'un combat, tel qu'on l'a vu en jeu.
class EcranCombat extends Ecran {
  const EcranCombat(
    this.combat, {
    this.onglet = Onglet.sessions,
    this.surligne,
  });
  final Combat combat;
  final String? surligne;
  @override
  final Onglet onglet;
  @override
  String get titre => T.finDuCombat;
}

/// La pile de navigation.
class Navigation {
  Navigation([Ecran racine = const EcranSuivi()]) : _pile = [racine];

  final List<Ecran> _pile;

  Ecran get courant => _pile.last;
  Onglet get onglet => courant.onglet;
  bool get peutRevenir => _pile.length > 1;

  /// Les titres des ecrans empiles, de la racine au courant.
  List<String> get chemin => [for (final e in _pile) e.titre];

  void ouvre(Ecran ecran) => _pile.add(ecran);

  /// Revient d'un cran. Sans effet a la racine.
  void revient() {
    if (peutRevenir) _pile.removeLast();
  }

  /// Choisit un onglet.
  ///
  /// Recliquer sur l'onglet courant ramene a sa racine : c'est le geste qu'on
  /// fait sans y penser quand on s'est enfonce dans un detail.
  void choisit(Onglet onglet) {
    _pile
      ..clear()
      ..add(switch (onglet) {
        Onglet.suivi => const EcranSuivi(),
        Onglet.mesCombats => const EcranMesCombats(),
        Onglet.monInventaire => const EcranMonInventaire(),
        Onglet.sessions => const EcranSessions(),
        Onglet.reglages => const EcranReglages(),
      });
  }
}
