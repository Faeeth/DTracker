/// Les textes en anglais.
///
/// Genere par `tools/langues.py` : corriger la table plutot que ce
/// fichier, sans quoi la correction sera perdue au prochain passage.
library;

import 'textes.dart';

class TextesEn extends Textes {
  const TextesEn();

  // ------------------------------------------------------------ commun
  @override
  String get marque => 'DTracker';

  @override
  String get pause => 'Pause';

  @override
  String get reprendre => 'Resume';

  @override
  String get reset => 'Reset';

  @override
  String get resetInfobulle => 'Close this session and start a new one';

  @override
  String get quitter => 'Quit';

  @override
  String get sessions => 'Sessions';

  @override
  String get reglages => 'Settings';

  @override
  String get vueCompacte => 'Switch to compact view';

  @override
  String get vueComplete => 'Back to full view';

  @override
  String get renommerSession => 'Click to rename the session';

  @override
  String get fenetreBloquee => 'Window locked — click to be able to move it';

  @override
  String get fenetreLibre => 'Window unlocked — grab it anywhere to move it';

  @override
  String get enPause => 'paused';

  @override
  String get enCours => 'running';

  @override
  String sessionNumero(int numero) => 'Session $numero';

  // ---------------------------------------------------------- colonnes
  @override
  String get colPersonnage => 'CHARACTER';

  @override
  String get colNiveau => 'LEVEL';

  @override
  String get colExperience => 'EXPERIENCE';

  @override
  String get colButin => 'LOOT';

  @override
  String get colObjets => 'ITEMS';

  @override
  String get colCombats => 'FIGHTS';

  @override
  String get colChallenges => 'CHALLENGES';

  @override
  String get colDuree => 'DURATION';

  @override
  String get colFinDuCombat => 'FIGHT ENDED';

  @override
  String get colTotal => 'TOTAL';

  @override
  String get colXp => 'XP';

  @override
  String get colPrix => 'AVG. PRICE';

  @override
  String get colQuantite => 'QUANTITY';

  @override
  String get colPoids => 'WEIGHT';

  @override
  String get colType => 'TYPE';

  // -------------------------------------------------------- navigation
  @override
  String get suivi => 'Overview';

  @override
  String get suiviSousTitre => 'Current session overview';

  @override
  String get mesCombats => 'My fights';

  @override
  String get mesCombatsSousTitre => 'This session\'s fights, newest first';

  @override
  String get monInventaire => 'My inventory';

  @override
  String get monInventaireSousTitre => 'Everything the party picked up';

  @override
  String get sessionsSousTitre => 'List of saved sessions';

  @override
  String get reglagesSousTitre => 'What the tool tracks, and how it looks';

  @override
  String butinDe(String personnage) => '$personnage\'s loot';

  @override
  String get finDuCombat => 'Fight ended';

  @override
  String get retour => 'Back';

  // ------------------------------------------------------------- suivi
  @override
  String get horsCombat => 'Out of combat';

  @override
  String enCombatDepuis(String duree) => 'In combat  ·  $duree';

  @override
  String tour(int numero) => 'turn $numero';

  @override
  String get cadenceXp => 'xp/h';

  @override
  String get cadenceKamas => 'kamas/h';

  @override
  String get aucunPersonnageSuivi => 'No character tracked';

  @override
  String get aucunPersonnageDetail => 'Add some in the settings to see their gains appear here.';

  @override
  String get ouvrirLesReglages => 'Open the settings';

  @override
  String get enAttenteDuJeu => 'Waiting for the game';

  @override
  String aucunNaJoue(int suivis) => 'None of the $suivis tracked characters has played yet.';

  @override
  String get progressionInconnue => 'Progress unknown — no state received for this character';

  @override
  String progression(String dans, String du, String pourcent, String niveau, String gagne) => '$dans / $du XP\n$pourcent % of level $niveau\nincluding $gagne earned this session';

  @override
  String get cliquerPourCombats => 'Click to see their fights';

  @override
  String get classeInconnue => 'Class unknown — it will show up on the next map change';

  @override
  String get ecarte => 'discarded';

  @override
  String get impose => 'imposed';

  // ----------------------------------------------------------- combats
  @override
  String get aucunCombat => 'No fight in this session';

  @override
  String get aucunCombatDetail => 'The list fills up at the end of each fight.';

  @override
  String get gagnants => 'WINNERS';

  @override
  String get perdants => 'LOSERS';

  @override
  String get adversaireInconnu => 'Unknown opponent';

  @override
  String get personneNaGagne => 'Nobody won this fight';

  @override
  String nbCombats(int n) => '$n fights';

  // -------------------------------------------------------- inventaire
  @override
  String get aucunItem => 'No item found in this session\'s inventory';

  @override
  String get triAucun => 'No sorting';

  @override
  String get triNom => 'Sort by name';

  @override
  String get triPoids => 'Sort by weight';

  @override
  String get triPoidsLot => 'Sort by stack weight';

  @override
  String get triQuantite => 'Sort by quantity';

  @override
  String get triPrix => 'Sort by average price';

  @override
  String get triPrixLot => 'Sort by average stack price';

  @override
  String get prixNonDisponible => 'Price not available';

  @override
  String get lot => 'Stack';

  @override
  String get unitaire => 'Unit';

  @override
  String get valeurEstimee => 'Estimated value of resources';

  @override
  String get kamasEnPiece => 'Kamas in coin';

  // ---------------------------------------------------------- sessions
  @override
  String get aucuneSession => 'No saved session';

  @override
  String get aucuneSessionDetail => 'The current session will show up on its first gain.';

  @override
  String dureeEcoute(String duree) => '$duree of listening';

  @override
  String dureeEcouteReprises(String duree, int reprises) => '$duree of listening, over $reprises runs\nNights and pauses are not counted.';

  @override
  String nbReprises(int n) => '$n runs';

  @override
  String get reprendreSession => 'Resume this session: it becomes the current one again';

  @override
  String get supprimerSession => 'Delete this session';

  @override
  String get supprimerConfirme => 'This session will be permanently deleted.';

  @override
  String get annuler => 'Cancel';

  @override
  String get supprimer => 'Delete';

  // ---------------------------------------------------------- reglages
  @override
  String get ongletPersonnages => 'Characters';

  @override
  String ongletPersonnagesAvecNombre(int n) => 'Characters ($n)';

  @override
  String get ongletComptage => 'Counting';

  @override
  String get ongletCapture => 'Capture';

  @override
  String get ongletFenetre => 'Window';

  @override
  String get ongletLangue => 'Language';

  @override
  String get nomDuPersonnage => 'Character name';

  @override
  String get ajouter => 'Add';

  @override
  String get retirer => 'Remove — its counters are cleared';

  @override
  String get compterLesSucces => 'Count achievements';

  @override
  String get compterLesSuccesDetail => 'Experience, kamas and resources from achievements will be\ncounted in the session.';

  @override
  String get interfaceEcoute => 'NETWORK CAPTURE INTERFACE';

  @override
  String get toutesLesInterfaces => 'All interfaces';

  @override
  String get toutesLesInterfacesRecommande => 'All interfaces (recommended)';

  @override
  String introuvable(String valeur) => '$valeur (not found)';

  @override
  String get toujoursDevant => 'Always on top';

  @override
  String get transparence => 'COMPACT VIEW TRANSPARENCY';

  @override
  String get transparenceDetail => 'The background cannot be more opaque than the text.';

  @override
  String get fond => 'Background';

  @override
  String get texte => 'Text';

  @override
  String get apercu => 'PREVIEW';

  @override
  String get langue => 'LANGUAGE';

  @override
  String get langueDetail => 'The change takes effect at once.';

  // -------------------------------------------------------------- flux
  @override
  String get fluxConnecte => 'Connected';

  @override
  String get fluxEnAttente => 'Waiting for the game';

  @override
  String get fluxInjoignable => 'Capture unreachable';

  @override
  String get fluxIndisponible => 'Capture unavailable';

  @override
  String get fluxDeconnecte => 'Disconnected';

  @override
  String diagEcouteSur(String carte) => 'Game events are coming in.\nListening on $carte.';

  @override
  String diagRienEntendu(String carte) => 'The capture is running and answering, but has heard nothing yet.\nListening on $carte.\n\nNormal if no character is connected. If the game is running,\nthe listened card does not carry its traffic: set it to\n"All interfaces", in Settings.';

  @override
  String get diagNeRepondPas => 'The stream is not answering yet.\n\nIt is starting up — a few seconds — or it stopped along the way.\nThe link re-establishes itself as soon as it answers.';

  @override
  String get diagNaPasDemarre => 'The capture could not start.\nThe npcap driver is missing.';

  @override
  String get diagAucuneCapture => 'No capture running.';

  @override
  String get carteToutesPhysiques => 'all physical interfaces';

  @override
  String carteNommee(String nom) => 'the $nom interface';

  // ------------------------------------------------------------- reste
  @override
  String get xp => 'XP';

  @override
  String get aucunPersonnageCompacte => 'No character tracked — switch to full view to add some';

  @override
  String enAttenteCompacte(int suivis) => 'Waiting: none of the $suivis tracked characters has played yet';

  @override
  String get suiviOnglet => 'The character table';

  @override
  String get mesCombatsOnglet => 'All the session\'s fights';

  @override
  String get monInventaireOnglet => 'The party\'s loot, character by character';

  @override
  String get sonButin => 'Their loot in this session';

  @override
  String get termineLe => 'ENDED ON';

  @override
  String get combatDejaCommence => 'The fight had started before the tool was listening.\nThe summary does not name the opponents.';

  @override
  String get reussi => 'passed';

  @override
  String get echoue => 'failed';

  @override
  String nbObjets(int n) => '$n items';

  @override
  String surTotal(int retenus, int total) => '$retenus of $total';

  @override
  String get inventaire => 'INVENTORY';

  @override
  String get gainsComptesDetail => 'Gains are only counted for the characters listed here — yours,\nand your friends\' if you want to follow the party.';

  @override
  String portraitIntrouvable(String classe) => '$classe — portrait not found, have the images been extracted?';

  @override
  String classeNumero(int classe) => 'Class $classe';

  // ------------------------------------------------- sessions et butin
  @override
  String get colSession => 'SESSION';

  @override
  String get enregistrees => 'SAVED';

  @override
  String get valeur => 'VALUE';

  @override
  String get enPiece => 'IN COIN';

  @override
  String get valeurRessources => 'ESTIMATED VALUE OF RESOURCES';

  @override
  String get butinComplet => 'Full loot';

  @override
  String get butinSession => 'The session\'s loot, characters of your choosing';

  @override
  String get supprimerCetteSession => 'Delete this session?';

  @override
  String resumeSession(String combats, String xp, String kamas) => '$combats fights  ·  $xp xp  ·  $kamas kamas';

  @override
  String get aucuneSessionNaitDetail => 'A session is born on its first fight. Starting the tool then closing it\nleaves no trace.';

  @override
  String get reprendreDetail => 'Resume this session: it becomes the current one and starts again\nright away.';

  @override
  String get aucunPersonnageSession => 'No character in this session';

  @override
  String rapport(int reussis, int total) => '$reussis/$total';

  @override
  String invitePasCompte(String nom) => '$nom is not one of the tracked characters.\nTheir experience and loot are not counted in the session.';

  @override
  String get reduire => 'Minimise the window';

  @override
  String get fluxSansPilote => 'npcap missing';

  @override
  String get fluxSansCarte => 'No card to listen on';

  @override
  String get diagSansPilote => 'The npcap driver is not installed.\n\nReading network traffic happens in the Windows kernel: it takes a driver,\nand no program can do without one. npcap is free and weighs a megabyte;\nit only needs installing once.\n\n→ npcap.com';

  @override
  String diagSansCarte(String carte) => 'The driver is there, but no network card can be listened on.\nCurrent setting: $carte.\n\nPick « All interfaces » in Settings → Capture.';

  @override
  String majTitre(String version) => 'DTracker $version is available';

  @override
  String majDetail(String courante) => 'You have version $courante.\n\nThe download page will open in your browser. Your settings, history and\nsessions are kept by the update.';

  @override
  String get majOuvrir => 'View the page';

  @override
  String get majPlusTard => 'Later';

  @override
  String get premiereFoisTitre => 'The names and pictures are missing';

  @override
  String get premiereFoisDetail => 'Item names, portraits and icons belong to Ankama: they cannot ship with\nDTracker. They are taken from your own client.\n\nWithout them the tool still counts right — experience, kamas and rates are\nexact — but an item shows up as « Item 1731 ».';

  @override
  String get premiereFoisLancer => 'Extract now';

  @override
  String get premiereFoisReessayer => 'Try again';

  @override
  String get premiereFoisPlusTard => 'Later';

  @override
  String get premiereFoisDuree => 'About two minutes, and 265 MB. The game can stay closed.';

  @override
  String get premiereFoisRecherche => 'Looking for the Dofus client…';

  @override
  String get premiereFoisFaite => 'Done. Names and pictures are in place.';

  @override
  String get premiereFoisSansClient => 'The Dofus_Data folder was not found. Is the game installed on this machine?';

  @override
  String premiereFoisEchec(String detail) => 'Extraction stopped: $detail';

  @override
  String get majInstaller => 'Update';

  @override
  String get majReessayer => 'Try again';

  @override
  String majTelechargement(int pourcent) => 'Downloading… $pourcent %';

  @override
  String get majLancement => 'Starting the installer. DTracker will close.';

  @override
  String get majRate => 'The download did not complete. The release page is still available.';

}
