/// Les textes de l'interface, une classe par langue.
///
/// **Pourquoi pas des fichiers ARB et `gen-l10n`.** La voie officielle de
/// Flutter suppose un `BuildContext` a chaque libelle. Or ici la moitie des
/// textes vivent hors de l'arbre des widgets : le titre d'un ecran est une
/// propriete de `Ecran`, l'intitule d'une carte reseau une propriete de
/// `Interface`, les diagnostics de capture une fonction de la fenetre. Les
/// faire tous passer par un contexte demandait de remanier ces classes pour
/// une raison qui n'a rien a voir avec elles.
///
/// Ici, [T] donne la langue courante de n'importe ou. Le revers est qu'un
/// changement de langue n'est pas propage par le framework : c'est
/// [changeLangue] qui s'en charge, et l'appelant rebatit.
///
/// **L'avantage decisif** : la classe est abstraite. Une langue a qui manque
/// un texte ne compile pas — une traduction ne peut pas etre oubliee a
/// moitie, ni prendre du retard en silence.
library;

import 'en.dart';
import 'es.dart';
import 'fr.dart';
import 'pt.dart';

/// Les langues offertes, dans l'ordre du menu.
enum Langue {
  fr('fr', 'Français'),
  en('en', 'English'),
  es('es', 'Español'),
  pt('pt', 'Português');

  const Langue(this.code, this.nom);

  /// Le code ISO, tel qu'il est ecrit dans les reglages.
  final String code;

  /// Le nom de la langue **dans cette langue** : on cherche le sien, pas sa
  /// traduction dans une langue qu'on ne lit pas.
  final String nom;

  static Langue depuisCode(String? code) {
    for (final l in values) {
      if (l.code == code) return l;
    }
    return fr;
  }
}

/// Les textes de la langue courante.
///
/// Une variable et non un `of(context)` : voir l'en-tete de la bibliotheque.
Textes T = const TextesFr();

Langue _langue = Langue.fr;
Langue get langueCourante => _langue;

/// Change la langue de toute l'application.
///
/// Ne rebatit rien de lui-meme : l'appelant le fait, ce qui evite d'imposer
/// un mecanisme de notification a un reglage qui change trois fois dans la
/// vie de l'outil.
void changeLangue(Langue langue) {
  _langue = langue;
  T = switch (langue) {
    Langue.fr => const TextesFr(),
    Langue.en => const TextesEn(),
    Langue.es => const TextesEs(),
    Langue.pt => const TextesPt(),
  };
}

/// Tout ce qui s'affiche, en une seule declaration.
///
/// Les libelles sont des champs, ce qui prend une valeur est une methode. Les
/// noms suivent l'ecran : `suiviTitre`, `reglagesLangue`. Ajouter un texte,
/// c'est l'ajouter ici puis dans les quatre langues — le compilateur dira
/// lesquelles manquent.
abstract class Textes {
  const Textes();

  // ------------------------------------------------------------------ commun
  String get marque;
  String get pause;
  String get reprendre;
  String get reset;
  String get resetInfobulle;
  String get quitter;
  String get reduire;
  String get sessions;
  String get reglages;
  String get vueCompacte;
  String get vueComplete;
  String get renommerSession;
  String get fenetreBloquee;
  String get fenetreLibre;
  String get enPause;
  String get enCours;
  String sessionNumero(int numero);

  // ---------------------------------------------------------------- colonnes
  String get colPersonnage;
  String get colNiveau;
  String get colExperience;
  String get colButin;
  String get colObjets;
  String get colCombats;
  String get colChallenges;
  String get colDuree;
  String get colFinDuCombat;
  String get colTotal;
  String get colXp;
  String get colPrix;
  String get colQuantite;
  String get colPoids;
  String get colType;

  // -------------------------------------------------------------- navigation
  String get suivi;
  String get suiviSousTitre;
  String get mesCombats;
  String get mesCombatsSousTitre;
  String get monInventaire;
  String get monInventaireSousTitre;
  String get sessionsSousTitre;
  String get reglagesSousTitre;
  String butinDe(String personnage);
  String get finDuCombat;
  String get retour;

  // ------------------------------------------------------------------- suivi
  String get horsCombat;
  String enCombatDepuis(String duree);
  String tour(int numero);
  String get cadenceXp;
  String get cadenceKamas;
  String get aucunPersonnageSuivi;
  String get aucunPersonnageDetail;
  String get ouvrirLesReglages;
  String get enAttenteDuJeu;
  String aucunNaJoue(int suivis);
  String get progressionInconnue;
  String progression(
    String dans,
    String du,
    String pourcent,
    String niveau,
    String gagne,
  );
  String get cliquerPourCombats;
  String get classeInconnue;
  String get ecarte;
  String get impose;

  // ---------------------------------------------------------------- combats
  String get aucunCombat;
  String get aucunCombatDetail;
  String get gagnants;
  String get perdants;
  String get adversaireInconnu;
  String invitePasCompte(String nom);
  String get personneNaGagne;
  String nbCombats(int n);

  // -------------------------------------------------------------- inventaire
  String get aucunItem;
  String get triAucun;
  String get triNom;
  String get triPoids;
  String get triPoidsLot;
  String get triQuantite;
  String get triPrix;
  String get triPrixLot;
  String get prixNonDisponible;
  String get lot;
  String get unitaire;
  String get valeurEstimee;
  String get kamasEnPiece;

  // ---------------------------------------------------------------- sessions
  String get aucuneSession;
  String get aucuneSessionDetail;
  String dureeEcoute(String duree);
  String dureeEcouteReprises(String duree, int reprises);
  String nbReprises(int n);
  String get reprendreSession;
  String get supprimerSession;
  String get supprimerConfirme;
  String get annuler;
  String get supprimer;

  // ---------------------------------------------------------------- reglages
  String get ongletPersonnages;
  String ongletPersonnagesAvecNombre(int n);
  String get ongletComptage;
  String get ongletCapture;
  String get ongletFenetre;
  String get ongletLangue;
  String get nomDuPersonnage;
  String get ajouter;
  String get retirer;
  String get compterLesSucces;
  String get compterLesSuccesDetail;
  String get interfaceEcoute;
  String get toutesLesInterfaces;
  String get toutesLesInterfacesRecommande;
  String introuvable(String valeur);
  String get toujoursDevant;
  String get transparence;
  String get transparenceDetail;
  String get fond;
  String get texte;
  String get apercu;
  String get langue;
  String get langueDetail;

  // ---------------------------------------------------------- etat du flux
  String get fluxConnecte;
  String get fluxEnAttente;
  String get fluxInjoignable;
  String get fluxIndisponible;
  String get fluxDeconnecte;
  String get fluxSansPilote;
  String get fluxSansCarte;
  String get diagSansPilote;
  String diagSansCarte(String carte);
  String diagEcouteSur(String carte);
  String diagRienEntendu(String carte);
  String get diagNeRepondPas;
  String get diagNaPasDemarre;
  String get diagAucuneCapture;
  String get carteToutesPhysiques;
  String carteNommee(String nom);

  // ------------------------------------------------------ le reste
  String get xp;
  String get aucunPersonnageCompacte;
  String enAttenteCompacte(int suivis);
  String get suiviOnglet;
  String get mesCombatsOnglet;
  String get monInventaireOnglet;
  String get sonButin;
  String get termineLe;
  String get combatDejaCommence;
  String get reussi;
  String get echoue;
  String nbObjets(int n);
  String surTotal(int retenus, int total);
  String get inventaire;
  String get gainsComptesDetail;
  String portraitIntrouvable(String classe);
  String classeNumero(int classe);

  // --------------------------------------- sessions et butin
  String get colSession;
  String get enregistrees;
  String get valeur;
  String get enPiece;
  String get valeurRessources;
  String get butinComplet;
  String get butinSession;
  String get supprimerCetteSession;
  String resumeSession(String combats, String xp, String kamas);
  String get aucuneSessionNaitDetail;
  String get reprendreDetail;
  String get aucunPersonnageSession;
  String rapport(int reussis, int total);
}
