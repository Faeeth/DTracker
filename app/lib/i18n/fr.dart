/// Les textes en francais.
///
/// Genere par `tools/langues.py` : corriger la table plutot que ce
/// fichier, sans quoi la correction sera perdue au prochain passage.
library;

import 'textes.dart';

class TextesFr extends Textes {
  const TextesFr();

  // ------------------------------------------------------------ commun
  @override
  String get marque => 'DTracker';

  @override
  String get pause => 'Pause';

  @override
  String get reprendre => 'Reprendre';

  @override
  String get reset => 'Reset';

  @override
  String get resetInfobulle => 'Clore cette session et en ouvrir une neuve';

  @override
  String get quitter => 'Quitter';

  @override
  String get sessions => 'Sessions';

  @override
  String get reglages => 'Réglages';

  @override
  String get vueCompacte => 'Passer en vue compacte';

  @override
  String get vueComplete => 'Revenir à la vue complète';

  @override
  String get renommerSession => 'Cliquer pour renommer la session';

  @override
  String get fenetreBloquee => 'Fenêtre bloquée — cliquer pour pouvoir la déplacer';

  @override
  String get fenetreLibre => 'Fenêtre libre — la saisir n\'importe où la déplace';

  @override
  String get enPause => 'en pause';

  @override
  String get enCours => 'en cours';

  @override
  String sessionNumero(int numero) => 'Session $numero';

  // ---------------------------------------------------------- colonnes
  @override
  String get colPersonnage => 'PERSONNAGE';

  @override
  String get colNiveau => 'NIVEAU';

  @override
  String get colExperience => 'EXPÉRIENCE';

  @override
  String get colButin => 'BUTIN';

  @override
  String get colObjets => 'OBJETS';

  @override
  String get colCombats => 'COMBATS';

  @override
  String get colChallenges => 'CHALLENGES';

  @override
  String get colDuree => 'DURÉE';

  @override
  String get colFinDuCombat => 'FIN DU COMBAT';

  @override
  String get colTotal => 'TOTAL';

  @override
  String get colXp => 'XP';

  @override
  String get colPrix => 'PRIX MOYEN';

  @override
  String get colQuantite => 'QUANTITÉ';

  @override
  String get colPoids => 'POIDS';

  @override
  String get colType => 'TYPE';

  // -------------------------------------------------------- navigation
  @override
  String get suivi => 'Suivi';

  @override
  String get suiviSousTitre => 'Suivi de la session en cours';

  @override
  String get mesCombats => 'Mes combats';

  @override
  String get mesCombatsSousTitre => 'Les combats de la session, du plus récent au plus ancien';

  @override
  String get monInventaire => 'Mon inventaire';

  @override
  String get monInventaireSousTitre => 'Tout ce que le groupe a ramassé';

  @override
  String get sessionsSousTitre => 'Liste des sessions enregistrées';

  @override
  String get reglagesSousTitre => 'Ce que l\'outil suit, et comment il s\'affiche';

  @override
  String butinDe(String personnage) => 'Butin de $personnage';

  @override
  String get finDuCombat => 'Fin du combat';

  @override
  String get retour => 'Retour';

  // ------------------------------------------------------------- suivi
  @override
  String get horsCombat => 'Hors combat';

  @override
  String enCombatDepuis(String duree) => 'En combat  ·  $duree';

  @override
  String tour(int numero) => 'tour $numero';

  @override
  String get cadenceXp => 'xp/h';

  @override
  String get cadenceKamas => 'kamas/h';

  @override
  String get aucunPersonnageSuivi => 'Aucun personnage suivi';

  @override
  String get aucunPersonnageDetail => 'Ajoutez-en dans les réglages pour voir leurs gains apparaître ici.';

  @override
  String get ouvrirLesReglages => 'Ouvrir les réglages';

  @override
  String get enAttenteDuJeu => 'En attente du jeu';

  @override
  String aucunNaJoue(int suivis) => 'Aucun des $suivis personnages suivis n\'a encore joué.';

  @override
  String get progressionInconnue => 'Progression inconnue — aucun état reçu pour ce personnage';

  @override
  String progression(String dans, String du, String pourcent, String niveau, String gagne) => '$dans / $du XP\n$pourcent % du niveau $niveau\ndont $gagne gagnés cette session';

  @override
  String get cliquerPourCombats => 'Cliquer pour voir ses combats';

  @override
  String get classeInconnue => 'Classe inconnue — elle apparaîtra au prochain passage sur une carte';

  @override
  String get ecarte => 'écarté';

  @override
  String get impose => 'imposé';

  // ----------------------------------------------------------- combats
  @override
  String get aucunCombat => 'Aucun combat sur cette session';

  @override
  String get aucunCombatDetail => 'La liste se remplit à la fin de chaque combat.';

  @override
  String get gagnants => 'GAGNANTS';

  @override
  String get perdants => 'PERDANTS';

  @override
  String get adversaireInconnu => 'Adversaire inconnu';

  @override
  String get personneNaGagne => 'Personne n\'a gagné ce combat';

  @override
  String nbCombats(int n) => '$n combats';

  // -------------------------------------------------------- inventaire
  @override
  String get aucunItem => 'Aucun item trouvé dans l\'inventaire de la session';

  @override
  String get triAucun => 'Aucun tri';

  @override
  String get triNom => 'Trier par nom';

  @override
  String get triPoids => 'Trier par poids';

  @override
  String get triPoidsLot => 'Trier par poids du lot';

  @override
  String get triQuantite => 'Trier par quantité';

  @override
  String get triPrix => 'Trier par prix moyen';

  @override
  String get triPrixLot => 'Trier par prix moyen du lot';

  @override
  String get prixNonDisponible => 'Prix non disponible';

  @override
  String get lot => 'Lot';

  @override
  String get unitaire => 'Unitaire';

  @override
  String get valeurEstimee => 'Valeur estimée des ressources';

  @override
  String get kamasEnPiece => 'Kamas en pièce';

  // ---------------------------------------------------------- sessions
  @override
  String get aucuneSession => 'Aucune session enregistrée';

  @override
  String get aucuneSessionDetail => 'La session en cours y figurera dès son premier gain.';

  @override
  String dureeEcoute(String duree) => '$duree d\'écoute';

  @override
  String dureeEcouteReprises(String duree, int reprises) => '$duree d\'écoute, en $reprises reprises\nLes nuits et les pauses n\'y sont pas comptées.';

  @override
  String nbReprises(int n) => '$n reprises';

  @override
  String get reprendreSession => 'Reprendre cette session : elle redevient la session en cours';

  @override
  String get supprimerSession => 'Supprimer cette session';

  @override
  String get supprimerConfirme => 'Cette session sera effacée définitivement.';

  @override
  String get annuler => 'Annuler';

  @override
  String get supprimer => 'Supprimer';

  // ---------------------------------------------------------- reglages
  @override
  String get ongletPersonnages => 'Personnages';

  @override
  String ongletPersonnagesAvecNombre(int n) => 'Personnages ($n)';

  @override
  String get ongletComptage => 'Comptage';

  @override
  String get ongletCapture => 'Capture';

  @override
  String get ongletFenetre => 'Fenêtre';

  @override
  String get ongletLangue => 'Langue';

  @override
  String get nomDuPersonnage => 'Nom du personnage';

  @override
  String get ajouter => 'Ajouter';

  @override
  String get retirer => 'Retirer — ses compteurs sont effacés';

  @override
  String get compterLesSucces => 'Compter les succès';

  @override
  String get compterLesSuccesDetail => 'L\'expérience, les kamas et les ressources liés aux succès seront\ncomptabilisés dans la session.';

  @override
  String get interfaceEcoute => 'INTERFACE D\'ÉCOUTE RÉSEAU';

  @override
  String get toutesLesInterfaces => 'Toutes les interfaces';

  @override
  String get toutesLesInterfacesRecommande => 'Toutes les interfaces (recommandé)';

  @override
  String introuvable(String valeur) => '$valeur (introuvable)';

  @override
  String get toujoursDevant => 'Toujours au premier plan';

  @override
  String get transparence => 'TRANSPARENCE DE LA VUE COMPACTE';

  @override
  String get transparenceDetail => 'Le fond ne peut pas être plus opaque que le texte.';

  @override
  String get fond => 'Fond';

  @override
  String get texte => 'Texte';

  @override
  String get apercu => 'APERÇU';

  @override
  String get langue => 'LANGUE';

  @override
  String get langueDetail => 'Le changement prend effet aussitôt.';

  // -------------------------------------------------------------- flux
  @override
  String get fluxConnecte => 'Connecté';

  @override
  String get fluxEnAttente => 'En attente du jeu';

  @override
  String get fluxInjoignable => 'Capture injoignable';

  @override
  String get fluxIndisponible => 'Capture indisponible';

  @override
  String get fluxDeconnecte => 'Déconnecté';

  @override
  String diagEcouteSur(String carte) => 'Les événements du jeu arrivent.\nÉcoute sur $carte.';

  @override
  String diagRienEntendu(String carte) => 'La capture tourne et répond, mais n\'a encore rien entendu.\nÉcoute sur $carte.\n\nNormal si aucun personnage n\'est connecté. Si le jeu tourne, c\'est\nque la carte écoutée ne porte pas son trafic : réglez-la sur\n« Toutes les interfaces », dans Réglages.';

  @override
  String get diagNeRepondPas => 'La diffusion ne répond pas encore.\n\nElle démarre — quelques secondes — ou elle s\'est arrêtée en chemin.\nLa liaison se rétablit d\'elle-même dès qu\'elle répond.';

  @override
  String get diagNaPasDemarre => 'La capture n\'a pas pu démarrer.\nLe pilote npcap manque à l\'appel.';

  @override
  String get diagAucuneCapture => 'Aucune capture en cours.';

  @override
  String get carteToutesPhysiques => 'toutes les interfaces physiques';

  @override
  String carteNommee(String nom) => 'l\'interface $nom';

  // ------------------------------------------------------------- reste
  @override
  String get xp => 'XP';

  @override
  String get aucunPersonnageCompacte => 'Aucun personnage suivi — passez en vue complète pour en ajouter';

  @override
  String enAttenteCompacte(int suivis) => 'En attente : aucun des $suivis personnages suivis n\'a encore joué';

  @override
  String get suiviOnglet => 'Le tableau des personnages';

  @override
  String get mesCombatsOnglet => 'Tous les combats de la session';

  @override
  String get monInventaireOnglet => 'Le butin du groupe, personnage par personnage';

  @override
  String get sonButin => 'Son butin sur cette session';

  @override
  String get termineLe => 'TERMINÉ LE';

  @override
  String get combatDejaCommence => 'Le combat avait commencé avant que l\'outil n\'écoute.\nLe récapitulatif ne nomme pas les adversaires.';

  @override
  String get reussi => 'réussi';

  @override
  String get echoue => 'échoué';

  @override
  String nbObjets(int n) => '$n objets';

  @override
  String surTotal(int retenus, int total) => '$retenus sur $total';

  @override
  String get inventaire => 'INVENTAIRE';

  @override
  String get gainsComptesDetail => 'Les gains ne sont comptés que pour les personnages\nlistés ici — les vôtres, et ceux de vos amis si vous voulez suivre le groupe.';

  @override
  String portraitIntrouvable(String classe) => '$classe — portrait introuvable, les images ont-elles été extraites ?';

  @override
  String classeNumero(int classe) => 'Classe $classe';

  // ------------------------------------------------- sessions et butin
  @override
  String get colSession => 'SESSION';

  @override
  String get enregistrees => 'ENREGISTRÉES';

  @override
  String get valeur => 'VALEUR';

  @override
  String get enPiece => 'EN PIÈCE';

  @override
  String get valeurRessources => 'VALEUR ESTIMÉE DES RESSOURCES';

  @override
  String get butinComplet => 'Butin complet';

  @override
  String get butinSession => 'Le butin de la session, personnages au choix';

  @override
  String get supprimerCetteSession => 'Supprimer cette session ?';

  @override
  String resumeSession(String combats, String xp, String kamas) => '$combats combats  ·  $xp xp  ·  $kamas kamas';

  @override
  String get aucuneSessionNaitDetail => 'Une session naît à son premier combat. Lancer l\'outil puis le fermer\nne laisse donc aucune trace.';

  @override
  String get reprendreDetail => 'Reprendre cette session : elle redevient la session courante\net repart aussitôt.';

  @override
  String get aucunPersonnageSession => 'Aucun personnage sur cette session';

  @override
  String rapport(int reussis, int total) => '$reussis/$total';

  @override
  String invitePasCompte(String nom) => '$nom ne fait pas partie des personnages suivis.\nSon expérience et son butin ne sont pas comptés dans la session.';

  @override
  String get reduire => 'Réduire la fenêtre';

  @override
  String get fluxSansPilote => 'npcap manquant';

  @override
  String get fluxSansCarte => 'Aucune carte à écouter';

  @override
  String get diagSansPilote => 'Le pilote npcap n\'est pas installé.\n\nLire le trafic réseau se fait dans le noyau de Windows : il y faut un pilote,\net aucun programme ne peut s\'en passer. npcap est gratuit et pèse un\nmégaoctet ; son installation ne se demande qu\'une fois.\n\n→ npcap.com';

  @override
  String diagSansCarte(String carte) => 'Le pilote est là, mais aucune carte réseau n\'est écoutable.\nRéglage courant : $carte.\n\nChoisissez « Toutes les interfaces » dans Réglages → Capture.';

  @override
  String majTitre(String version) => 'DTracker $version est disponible';

  @override
  String majDetail(String courante) => 'Vous avez la version $courante.\n\nLa page de téléchargement s\'ouvrira dans votre navigateur. Vos réglages,\nvotre historique et vos sessions sont conservés par la mise à jour.';

  @override
  String get majOuvrir => 'Télécharger';

  @override
  String get majPlusTard => 'Plus tard';

  @override
  String get premiereFoisTitre => 'Il manque les noms et les images';

  @override
  String get premiereFoisDetail => 'Les noms d\'objets, les portraits et les icônes appartiennent à Ankama : ils ne\npeuvent pas être livrés avec DTracker. Ils se prennent dans votre propre client.\n\nSans eux, l\'outil compte juste — l\'expérience, les kamas et les cadences sont\nexacts — mais un objet s\'affiche « Objet 1731 ».';

  @override
  String get premiereFoisLancer => 'Extraire maintenant';

  @override
  String get premiereFoisReessayer => 'Réessayer';

  @override
  String get premiereFoisPlusTard => 'Plus tard';

  @override
  String get premiereFoisDuree => 'Environ deux minutes, et 265 Mo. Le jeu peut rester fermé.';

  @override
  String get premiereFoisRecherche => 'Recherche du client Dofus…';

  @override
  String get premiereFoisFaite => 'Terminé. Les noms et les images sont en place.';

  @override
  String get premiereFoisSansClient => 'Le dossier Dofus_Data n\'a pas été trouvé. Le jeu est-il installé sur cette machine ?';

  @override
  String premiereFoisEchec(String detail) => 'L\'extraction s\'est arrêtée : $detail';

}
