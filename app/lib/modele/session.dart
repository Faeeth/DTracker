/// Etat de la session de suivi.
///
/// Accumule ce qu'un personnage a gagne depuis le debut de la session, et
/// retient son etat courant pour afficher sa progression dans le niveau.
///
/// Une seule source par grandeur, pour ne rien compter deux fois. L'experience
/// est prise dans les recapitulatifs de fin de combat et dans les succes,
/// jamais dans les gains bruts : ceux-ci accompagnent les memes evenements et
/// doubleraient le total. Les kamas suivent la meme regle, et distinguent ce
/// qui tombe en piece de ce qui vient de la revente du butin.
///
/// Le prix demande un rattrapage. La bibliotheque valorise un objet au moment
/// ou elle le rend, avec les prix qu'elle connait alors, et ne conserve rien
/// d'un evenement a l'autre. Or la table des prix n'est diffusee qu'a la
/// connexion ou a l'ouverture d'une interface marchande : elle arrive souvent
/// apres plusieurs combats, qui restent alors sans valeur. Le suivi revalorise
/// donc tout son historique des qu'il la recoit.
library;

import 'dart:collection';

/// Forme comparable d'un nom de personnage : casse et espaces ignores.
///
/// La casse d'un pseudo ne se devine pas. Un joueur qui suit les personnages
/// d'un ami tape ce qu'il lit dans le chat, et « Kaska-osa » ne rencontrait
/// jamais « Kaska-Osa » : la ligne restait vide sans que rien ne signale
/// l'ecart.
String cleDe(String? nom) => (nom ?? '').trim().toLowerCase();

/// Delai au-dela duquel un mouvement d'inventaire ne peut plus etre rapproche
/// d'un recapitulatif. Les deux se suivent d'ordinaire de quelques centiemes
/// de seconde ; la marge couvre un suivi qui vient de demarrer.
const double fenetreRapprochement = 8;

/// Un intervalle pendant lequel l'outil ecoutait pour le compte d'une session.
///
/// Une session peut s'etaler sur plusieurs jours et une dizaine de lancements.
/// Sa duree est la somme de ces intervalles, jamais l'ecart entre le premier
/// et le dernier : les nuits, les pauses et les fermetures de l'outil n'en
/// font pas partie. Une cadence calculee sur l'ecart brut serait fausse d'un
/// ordre de grandeur.
///
/// `fin` reste nulle tant que la periode court.
class Periode {
  Periode(this.debut, [this.fin]);

  double debut;
  double? fin;

  bool get ouverte => fin == null;

  double ecoulee(double maintenant) =>
      ((fin ?? maintenant) - debut).clamp(0, double.infinity);

  Map<String, dynamic> versJson() => {
    'debut': debut,
    if (fin != null) 'fin': fin,
  };

  static Periode depuisJson(Map<String, dynamic> j) => Periode(
    (j['debut'] as num?)?.toDouble() ?? 0,
    (j['fin'] as num?)?.toDouble(),
  );
}

/// Un type d'objet accumule sur la session.
class Lot {
  Lot(this.itemId);

  final int itemId;
  int quantite = 0;
  int? prixUnitaire;

  int get valeur => (prixUnitaire ?? 0) * quantite;
}

/// Un challenge du combat en cours.
///
/// `reussi` reste nul tant que l'issue n'est pas connue : le serveur ne
/// l'annonce qu'a la fin, parfois a la toute derniere action.
///
/// `origine` dit d'ou il vient, ce qui repond a la question qu'on se pose en
/// voyant deux challenges alors qu'on n'en a choisi qu'un :
///
///   choisi   le groupe l'a retenu parmi la paire proposee ;
///   ecarte   l'autre proposition, que le serveur garde en jeu malgre tout —
///            observe sur un combat de boss, ou les deux ont recu un resultat ;
///   impose   jamais propose : c'est le donjon qui l'ajoute ;
///   objectif propre a un combat de boss, sans pourcentage.
class Challenge {
  Challenge(
    this.challengeId, {
    this.bonus,
    this.reussi,
    this.origine = 'impose',
  });

  final int challengeId;
  int? bonus;
  bool? reussi;
  String origine;

  bool get objectifDeBoss => bonus == null;

  String get etat =>
      reussi == null ? 'en cours' : (reussi! ? 'reussi' : 'echoue');
}

/// Un participant, tel que le recapitulatif de fin de combat le decrit.
///
/// L'experience totale et les seuils sont ceux de **cet instant** : c'est ce
/// qui permet de reafficher le recapitulatif plus tard a l'identique, barre de
/// progression comprise, plutot que de le recalculer avec l'etat courant.
class ParticipantCombat {
  ParticipantCombat({
    required this.nom,
    required this.niveau,
    required this.xp,
    required this.xpTotal,
    required this.xpSeuilBas,
    required this.xpSeuilHaut,
    required this.kamas,
    required this.butin,
    this.gagnant = true,
    this.suivi = true,
  });

  final String nom;
  final int? niveau;

  /// A-t-il gagne ce combat ?
  ///
  /// Le recapitulatif donne l'issue de chacun : deux chez les gagnants, rien
  /// chez les autres. Un personnage qui abandonne y figure quand meme, avec
  /// zero experience et zero kamas — il apparaissait sous « GAGNANTS ».
  ///
  /// Vrai par defaut : les archives ecrites avant que l'issue ne soit lue
  /// n'en portent pas, et leurs combats etaient gagnes dans leur immense
  /// majorite.
  final bool gagnant;
  /// Ce personnage est-il l'un de ceux que l'outil suit ?
  ///
  /// Un combat mene avec des amis porte leurs personnages au recapitulatif :
  /// c'est ce que le jeu montre, et c'est ce qu'on veut revoir. Mais leur
  /// experience et leur butin ne sont pas les notres — les compter gonflait
  /// les totaux de la session, et avec eux les cadences.
  ///
  /// Vrai par defaut : les archives ecrites avant cette distinction n'en
  /// portent pas, et leurs combats etaient les notres.
  final bool suivi;

  final int xp;
  final int xpTotal;
  final int xpSeuilBas;
  final int xpSeuilHaut;
  final int kamas;

  /// Type d'objet -> (quantite, prix unitaire connu alors).
  final Map<int, (int, int?)> butin;

  int get unites => butin.values.fold(0, (somme, l) => somme + l.$1);
  int get valeurButin =>
      butin.values.fold(0, (somme, l) => somme + (l.$2 ?? 0) * l.$1);
  int get kamasTotal => kamas + valeurButin;

  double get progression {
    final etendue = xpSeuilHaut - xpSeuilBas;
    return etendue > 0
        ? ((xpTotal - xpSeuilBas) / etendue).clamp(0.0, 1.0)
        : 0.0;
  }

  Map<String, dynamic> versJson() => {
    'nom': nom,
    if (niveau != null) 'niveau': niveau,
    'xp': xp,
    'xp_total': xpTotal,
    'xp_seuil_bas': xpSeuilBas,
    'xp_seuil_haut': xpSeuilHaut,
    'kamas': kamas,
    if (!gagnant) 'perdu': true,
    if (!suivi) 'invite': true,
    'butin': {
      for (final e in butin.entries)
        '${e.key}': {
          'quantite': e.value.$1,
          if (e.value.$2 != null) 'prix': e.value.$2,
        },
    },
  };

  static ParticipantCombat depuisJson(Map<String, dynamic> j) =>
      ParticipantCombat(
        nom: '${j['nom'] ?? ''}',
        niveau: (j['niveau'] as num?)?.toInt(),
        xp: (j['xp'] as num?)?.toInt() ?? 0,
        xpTotal: (j['xp_total'] as num?)?.toInt() ?? 0,
        xpSeuilBas: (j['xp_seuil_bas'] as num?)?.toInt() ?? 0,
        xpSeuilHaut: (j['xp_seuil_haut'] as num?)?.toInt() ?? 0,
        kamas: (j['kamas'] as num?)?.toInt() ?? 0,
        gagnant: j['perdu'] != true,
        suivi: j['invite'] != true,
        butin: {
          for (final e in (j['butin'] as Map<String, dynamic>? ?? {}).entries)
            if (int.tryParse(e.key) != null && e.value is Map)
              int.parse(e.key): (
                ((e.value as Map)['quantite'] as num?)?.toInt() ?? 0,
                ((e.value as Map)['prix'] as num?)?.toInt(),
              ),
        },
      );
}

/// Un combattant d'en face.
///
/// `monstre` est nul quand le combat avait commence avant l'ecoute : le
/// recapitulatif designe les perdants par un numero propre au combat, et ce
/// numero ne prend un sens qu'avec les annonces de placement. On sait alors
/// combien ils etaient, pas ce qu'ils etaient — et on le dit.
class Adversaire {
  const Adversaire({this.monstre, this.grade});

  final int? monstre;
  final int? grade;

  bool get connu => monstre != null;

  Map<String, dynamic> versJson() => {
    if (monstre != null) 'monstre': monstre,
    if (grade != null) 'grade': grade,
  };

  static Adversaire depuisJson(Map<String, dynamic> j) => Adversaire(
    monstre: (j['monstre'] as num?)?.toInt(),
    grade: (j['grade'] as num?)?.toInt(),
  );
}

/// Un combat termine, conserve en entier.
///
/// Le recapitulatif est garde tel que le serveur l'a rendu, participants
/// compris — y compris ceux qu'on ne suit pas. C'est ce qui permet de le
/// rouvrir plus tard tel qu'on l'a vu en jeu, et ce sur quoi s'appuieront les
/// statistiques qu'on voudra en tirer.
class Combat {
  Combat({
    required this.fin,
    required this.duree,
    required this.participants,
    this.challenges = const [],
    this.adversaires = const [],
  });

  /// Horodatage de fin : c'est la reference de temps d'un combat. C'est cet
  /// instant-la qu'on a en tete, pas celui de l'engagement.
  final double fin;

  /// Duree du combat, en secondes.
  final double duree;

  /// Instant de l'engagement, deduit de la fin et de la duree.
  double get debut => fin - duree;
  final List<ParticipantCombat> participants;

  /// Les challenges de ce combat et leur issue.
  ///
  /// Ils sont rattaches au combat plutot que ranges dans une liste a part :
  /// « ce donjon-la, ai-je passe l'Elitiste ? » est une question qui porte sur
  /// un combat, et une liste separee obligeait a rapprocher deux horodatages
  /// de tete.
  final List<ChallengeFait> challenges;

  /// Les perdants — les monstres, le plus souvent.
  ///
  /// Ils sont a part des participants : le jeu ne leur donne ni experience ni
  /// butin, et les melanger fausserait tous les totaux.
  final List<Adversaire> adversaires;

  DateTime get quand =>
      DateTime.fromMillisecondsSinceEpoch((fin * 1000).round());

  ParticipantCombat? pour(String nom) {
    final cle = cleDe(nom);
    for (final p in participants) {
      if (cleDe(p.nom) == cle) return p;
    }
    return null;
  }

  /// Ce que **nos** personnages ont tire de ce combat.
  ///
  /// Les combattants hors liste sont ecartes : ils figurent au
  /// recapitulatif — le jeu les montre, et on veut les revoir — mais leur
  /// experience n'est pas la notre.
  Iterable<ParticipantCombat> get notres =>
      participants.where((p) => p.suivi);

  int get xp => notres.fold(0, (somme, p) => somme + p.xp);
  int get kamas => notres.fold(0, (somme, p) => somme + p.kamasTotal);
  int get unites => notres.fold(0, (somme, p) => somme + p.unites);

  /// Y a-t-il, dans ce combat, quelqu'un que l'outil ne suit pas ?
  bool get avecDesInvites => participants.any((p) => !p.suivi);

  /// Les challenges du combat, objectifs de boss exclus.
  List<ChallengeFait> get challengesSeuls => [
    for (final c in challenges)
      if (c.estChallenge) c,
  ];

  /// Sans passer par [challengesSeuls] : ce getter sert de clef de tri, et
  /// n'a pas besoin de la liste qu'il aurait fallu construire pour la jeter.
  int get challengesReussis {
    var n = 0;
    for (final c in challenges) {
      if (c.estChallenge && c.reussi) n++;
    }
    return n;
  }

  /// Ceux qui ont gagne, et ceux qui ont perdu ou abandonne.
  ///
  /// Le jeu les separe a la fin d'un combat, et pour cause : les seconds n'ont
  /// ni experience ni butin, et les afficher sous « GAGNANTS » etait faux.
  List<ParticipantCombat> get gagnants => [
    for (final p in participants)
      if (p.gagnant) p,
  ];
  List<ParticipantCombat> get perdants => [
    for (final p in participants)
      if (!p.gagnant) p,
  ];

  Map<String, dynamic> versJson() => {
    'fin': fin,
    'duree': duree,
    'participants': [for (final p in participants) p.versJson()],
    if (challenges.isNotEmpty)
      'challenges': [for (final c in challenges) c.versJson()],
    if (adversaires.isNotEmpty)
      'adversaires': [for (final a in adversaires) a.versJson()],
  };

  static Combat depuisJson(Map<String, dynamic> j) => Combat(
    fin: (j['fin'] as num?)?.toDouble() ?? 0,
    duree: (j['duree'] as num?)?.toDouble() ?? 0,
    participants: [
      for (final p in j['participants'] as List? ?? [])
        if (p is Map<String, dynamic>) ParticipantCombat.depuisJson(p),
    ],
    adversaires: [
      for (final a in j['adversaires'] as List? ?? [])
        if (a is Map<String, dynamic>) Adversaire.depuisJson(a),
    ],
    challenges: [
      for (final c in j['challenges'] as List? ?? [])
        if (c is Map<String, dynamic>) ChallengeFait.depuisJson(c),
    ],
  );
}

/// Un challenge et son issue, garde pour l'historique de la session.
///
/// Le protocole n'attribue pas une reussite ni un echec a un joueur : les
/// quatre clients d'un meme groupe recoivent des messages strictement
/// identiques. On note donc qui **combattait** au moment ou l'issue est tombee,
/// ce qui est la reponse la plus proche que le flux permette.
class ChallengeFait {
  ChallengeFait({
    required this.ts,
    required this.challengeId,
    required this.bonus,
    required this.origine,
    required this.reussi,
    required this.combattants,
  });

  final double ts;
  final int challengeId;
  final int? bonus;
  final String origine;

  /// Un challenge, et non un objectif de boss.
  ///
  /// Le combat d'un boss porte, a cote de ses challenges, des objectifs
  /// propres a lui : ne pas laisser mourir d'allie, finir en dix tours. Le
  /// serveur les annonce par les memes messages, et l'outil les comptait donc
  /// comme des challenges — « 3/5 » sur un combat qui n'en proposait que
  /// deux. Ils se reconnaissent a l'absence de pourcentage de bonus.
  ///
  /// Ils restent archives : ce sont des faits du combat, et les effacer pour
  /// corriger un libelle serait perdre plus qu'on ne repare.
  bool get estChallenge => origine != 'objectif';
  final bool reussi;
  final List<String> combattants;

  /// Qui a fait echouer le challenge.
  ///
  /// **Toujours nul en l'etat.** Le champ existe parce que la question se
  /// pose a chaque echec, et pour que rien n'ait a bouger le jour ou la
  /// reponse deviendrait accessible. Le flux ne la porte pas : verifie sur
  /// huit captures, le message d'issue (`kwl`) ne contient que l'identifiant
  /// du challenge et un drapeau de reussite, et les quatre clients d'un
  /// groupe recoivent le meme octet pour octet. Le jeu designe le fautif en
  /// rejouant les actions du combat cote client — c'est une deduction, pas
  /// une donnee.
  String? fautif;

  Map<String, dynamic> versJson() => {
    'ts': ts,
    'challenge_id': challengeId,
    if (bonus != null) 'bonus': bonus,
    'origine': origine,
    'reussi': reussi,
    'combattants': combattants,
    if (fautif != null) 'fautif': fautif,
  };

  static ChallengeFait depuisJson(Map<String, dynamic> j) => ChallengeFait(
    ts: (j['ts'] as num?)?.toDouble() ?? 0,
    challengeId: (j['challenge_id'] as num?)?.toInt() ?? 0,
    bonus: (j['bonus'] as num?)?.toInt(),
    origine: '${j['origine'] ?? 'impose'}',
    reussi: j['reussi'] == true,
    combattants: [for (final n in j['combattants'] as List? ?? []) '$n'],
  )..fautif = j['fautif'] as String?;
}

/// Un fait digne d'etre montre dans le journal.
///
/// Volontairement sans texte : le journal garde des identifiants, l'affichage
/// les traduit. C'est ce qui permet a ce fichier de ne rien savoir des
/// libelles ni de l'interface.
class Fait {
  Fait(
    this.ts,
    this.genre, {
    this.personnage = '',
    this.xp = 0,
    this.kamas = 0,
    this.objets = 0,
    this.identifiant,
    this.reussi,
    this.duree = 0,
  });

  double ts;
  final String genre; // combat | succes | recolte | challenge
  String personnage;
  int xp;
  int kamas;
  int objets;
  final int? identifiant;
  final bool? reussi;
  double duree;

  /// Detail par personnage d'un combat : un combat fait une seule ligne, les
  /// participants tenant dans son infobulle.
  final List<(String, int, int)> parts = [];
}

/// Ce qu'on sait d'un personnage, et ce qu'il a gagne.
///
/// `nom` est un libelle d'affichage, pas une identite : il est repris de ce
/// qu'on a tape dans les reglages, puis remplace par l'orthographe exacte du
/// serveur des qu'un combat la donne. C'est `cle` qui sert a s'y retrouver.
class Suivi {
  Suivi(this.nom);

  String nom;
  int? classe; // numerotation `breeds` du client
  int? niveau;
  int xpTotal = 0;
  int xpSeuilBas = 0;
  int xpSeuilHaut = 0;

  int xpGagnee = 0;
  int kamasPiece = 0;
  final Map<int, Lot> butin = {};

  int combats = 0;
  int succes = 0;
  bool enCombat = false;
  int meilleurCombat = 0;

  /// Le personnage a-t-il donne signe de vie pendant cette session ?
  ///
  /// Un tableau qui affiche d'emblee tous les personnages configures ment :
  /// on suit huit personnages mais on n'en joue que quatre ce soir, et les
  /// quatre autres restent a zero sans rien dire. Une ligne n'apparait donc
  /// qu'une fois son personnage rencontre.
  bool vu = false;

  String get cle => cleDe(nom);

  int get xpDansNiveau => (xpTotal - xpSeuilBas).clamp(0, 1 << 62);
  int get xpDuNiveau => (xpSeuilHaut - xpSeuilBas).clamp(0, 1 << 62);
  double get progression =>
      xpDuNiveau > 0 ? (xpDansNiveau / xpDuNiveau).clamp(0.0, 1.0) : 0.0;

  /// Deux totaux tenus au lieu d'etre refaits.
  ///
  /// Le butin d'une soiree compte facilement quelques centaines de types
  /// d'objets, et sa valeur est demandee plusieurs fois par image — par la
  /// ligne du personnage, par le pied, par chaque tableau. Le tri, lui, coute
  /// un `sort` complet a chaque ouverture d'un inventaire.
  ///
  /// Les deux sont invalides d'un seul endroit, [_oublie], appele par les
  /// trois seules facons de toucher au butin : [ajouteLot], [revalorise] et
  /// [remetAZero].
  int? _kamasButin;
  List<Lot>? _lots;

  void _oublie() {
    _kamasButin = null;
    _lots = null;
  }

  int get kamasButin =>
      _kamasButin ??= butin.values.fold<int>(0, (s, lot) => s + lot.valeur);
  int get kamasTotal => kamasPiece + kamasButin;

  /// Butin trie par valeur decroissante, le plus parlant en premier.
  List<Lot> get lots {
    final connu = _lots;
    if (connu != null) return connu;
    final liste = butin.values.toList();
    liste.sort((a, b) {
      final parValeur = b.valeur.compareTo(a.valeur);
      return parValeur != 0 ? parValeur : a.itemId.compareTo(b.itemId);
    });
    return _lots = liste;
  }

  /// Verse d'un coup le butin d'un bilan archive : type -> (quantite, prix).
  void ajouteTout(Map<int, (int, int?)> butin) {
    butin.forEach((id, lot) => ajouteLot(id, lot.$1, lot.$2));
  }

  void ajouteLot(int itemId, int quantite, int? prix) {
    final lot = butin.putIfAbsent(itemId, () => Lot(itemId));
    lot.quantite += quantite;
    if (prix != null) lot.prixUnitaire = prix;
    _oublie();
  }

  /// Applique une table de prix au butin deja accumule.
  ///
  /// Un objet ramasse avant que la table n'arrive vaut zero faute de mieux ;
  /// il faut pouvoir lui rendre sa valeur plus tard.
  bool revalorise(Map<int, int> prix) {
    var change = false;
    for (final lot in butin.values) {
      final p = prix[lot.itemId];
      if (p != null && lot.prixUnitaire != p) {
        lot.prixUnitaire = p;
        change = true;
      }
    }
    if (change) _oublie();
    return change;
  }

  /// Remet les compteurs a zero sans oublier ce qu'on sait du personnage.
  ///
  /// L'etat de combat n'est pas touche : remettre a zero pendant un combat ne
  /// doit pas faire croire qu'on en est sorti.
  void remetAZero() {
    xpGagnee = 0;
    kamasPiece = 0;
    butin.clear();
    _oublie();
    combats = 0;
    succes = 0;
    meilleurCombat = 0;
    // Une session neuve repart d'un tableau vide : les lignes reviendront a
    // mesure que les personnages rejouent.
    vu = false;
  }
}

/// Un mouvement d'inventaire recent, en attente d'un eventuel recapitulatif.
class _Entree {
  _Entree(this.ts, this.personnage, this.itemId, this.quantite);

  final double ts;
  final String personnage;
  final int itemId;
  int quantite;
}

/// Agrege les evenements pour les personnages suivis.
///
/// Les autres sont ignores : jouer avec des inconnus ne doit pas remplir le
/// tableau de lignes sans interet.
class Session {
  Session([List<String> personnages = const []]) {
    definitPersonnages(personnages);
  }

  List<String> suivisChoisis = [];
  final Map<String, Suivi> suivis = {};
  final Map<int, int> prix = {};

  /// Nom de la session. « Session 7 » par defaut, renommable.
  ///
  /// Un horodatage ne dit pas ce qu'on a fait ce soir-la. « Donjon Bouftou »
  /// se retrouve dans une liste, « 31/08 a 21:04 » non.
  String nom = '';

  /// Numero d'ordre, qui sert a fabriquer le nom par defaut et a en donner un
  /// au suivant.
  int numero = 0;

  /// Les succes comptent-ils dans les totaux de la session ?
  ///
  /// Un succes rend d'un coup ce que plusieurs heures de farm rapportent : le
  /// laisser entrer dans les totaux fausse la cadence, et c'est la cadence
  /// qu'on regarde en montant un donjon. On peut donc le desactiver, ce qui
  /// ecarte du meme geste son experience, ses kamas et ses ressources.
  ///
  /// Actif par defaut : ces gains sont reels, et les cacher par defaut
  /// surprendrait davantage.
  bool compteLesSucces = true;

  bool _enPause = false;

  /// En pause, la session cesse d'ecouter **et** de compter le temps.
  ///
  /// Mettre en pause ferme la periode en cours, reprendre en ouvre une neuve.
  /// C'est ce qui permet a une session etalee sur quatre jours et douze
  /// lancements de totaliser douze intervalles, et non les quatre jours.
  bool get enPause => _enPause;

  set enPause(bool valeur) {
    if (valeur == _enPause) return;
    _enPause = valeur;
    final maintenant = DateTime.now().millisecondsSinceEpoch / 1000;
    if (valeur) {
      derniereActivite = maintenant;
      for (final p in periodes) {
        p.fin ??= maintenant;
      }
    } else {
      periodes.add(Periode(maintenant));
    }
  }

  /// Etat du combat en cours, commun a tous les personnages suivis : ils
  /// jouent ensemble, et l'affichage bascule pour l'ensemble.
  bool enCombat = false;
  List<Challenge> challenges = [];
  final Map<int, int> propositions = {}; // identifiant -> bonus propose
  final Set<int> choisis = {};
  final List<Set<int>> paires = [];
  double debutCombat = 0;
  int tour = 0;

  /// Journal des faits recents. Borne : c'est un fil d'actualite, pas un
  /// historique — au-dela d'une quarantaine de lignes personne ne remonte.
  final Queue<Fait> journal = Queue<Fait>();
  static const int tailleJournal = 40;

  /// Les intervalles pendant lesquels l'outil a ecoute pour cette session.
  final List<Periode> periodes = [
    Periode(DateTime.now().millisecondsSinceEpoch / 1000),
  ];

  /// Instant du debut de la session : le debut de sa premiere periode.
  double get debut => periodes.first.debut;

  set debut(double t) => periodes.first.debut = t;

  /// Temps reellement passe sur la session, pauses et fermetures deduites.
  double get duree {
    final maintenant = DateTime.now().millisecondsSinceEpoch / 1000;
    return periodes.fold(0.0, (somme, p) => somme + p.ecoulee(maintenant));
  }

  /// Tous les challenges de la session, avec leur issue. Contrairement a
  /// `challenges`, qui ne porte que le combat en cours, celui-ci s'accumule.
  final List<ChallengeFait> historiqueChallenges = [];

  /// Tous les combats de la session, recapitulatif complet compris.
  final List<Combat> combats = [];

  /// Les challenges tombes depuis le debut du combat en cours, en attente
  /// d'etre rattaches a son recapitulatif.
  final List<ChallengeFait> _challengesDuCombat = [];

  /// Instant du dernier fait retenu. C'est lui qui borne une session mise en
  /// pause ou rechargee : sans quoi sa duree grandirait en la regardant.
  double derniereActivite = DateTime.now().millisecondsSinceEpoch / 1000;

  /// Fin de la session : maintenant tant qu'elle tourne, la fermeture de sa
  /// derniere periode sinon.
  double get fin =>
      periodes.last.fin ?? DateTime.now().millisecondsSinceEpoch / 1000;

  final List<_Entree> _entrees = [];

  /// Classes vues pendant cette session, y compris pour des personnages qui ne
  /// sont pas suivis : l'appelant les conserve, on peut les suivre plus tard.
  final Map<String, int> classesApprises = {};

  // ------------------------------------------------------------------ reglages

  /// Applique une nouvelle liste de personnages.
  ///
  /// Ceux qui restent gardent leurs compteurs ; ceux qu'on retire sont
  /// effaces, y compris de la memoire — c'est ce qu'attend l'utilisateur qui
  /// les enleve de sa liste.
  void definitPersonnages(List<String> noms) {
    final garde = noms.map(cleDe).toSet();
    suivis.removeWhere((cle, _) => !garde.contains(cle));
    for (final nom in noms) {
      suivis.putIfAbsent(cleDe(nom), () => Suivi(nom));
    }
    suivisChoisis = List.of(noms);
  }

  /// Renseigne la classe des personnages suivis, par leur nom.
  void definitClasses(Map<String, int> classes) {
    classes.forEach((nom, classe) {
      final suivi = suivis[cleDe(nom)];
      if (suivi != null) suivi.classe = classe;
    });
  }

  void remetAZero() {
    for (final suivi in suivis.values) {
      suivi.remetAZero();
    }
    challenges.clear();
    journal.clear();
    historiqueChallenges.clear();
    _challengesDuCombat.clear();
    combats.clear();
    final maintenant = DateTime.now().millisecondsSinceEpoch / 1000;
    periodes
      ..clear()
      ..add(Periode(maintenant));
    _enPause = false;
    derniereActivite = maintenant;
  }

  /// Lignes a afficher : les personnages rencontres, dans l'ordre choisi.
  ///
  /// Ceux qui n'ont pas joue de la session n'y figurent pas. Ils restent
  /// suivis — la ligne apparaitra d'elle-meme des qu'ils se manifesteront.
  List<Suivi> get lignes => [
    for (final cle in suivisChoisis.map(cleDe))
      if (suivis[cle]?.vu ?? false) suivis[cle]!,
  ];

  /// Tous les personnages suivis, vus ou non. Sert a ce qui doit les connaitre
  /// avant qu'ils ne se manifestent.
  List<Suivi> get tousLesSuivis => [
    for (final cle in suivisChoisis.map(cleDe))
      if (suivis.containsKey(cle)) suivis[cle]!,
  ];

  int get xpTotale => suivis.values.fold(0, (somme, s) => somme + s.xpGagnee);
  int get kamasTotaux =>
      suivis.values.fold(0, (somme, s) => somme + s.kamasTotal);

  /// Le nombre de combats de la session.
  ///
  /// La liste, et non la somme des compteurs de chaque personnage : ceux-ci
  /// comptent des **participations**, et un combat mene a quatre en valait
  /// quatre. Le bandeau annoncait 79 combats pour les 11 d'une soiree.
  /// La distinction reste utile ailleurs — la vue compacte dit bien, par
  /// personnage, a combien de combats il a pris part.
  int get combatsTotaux => combats.length;
  int get succesTotaux => suivis.values.fold(0, (somme, s) => somme + s.succes);

  /// Secondes ecoulees depuis l'engagement, 0 hors combat.
  double get dureeCombat {
    if (!enCombat || debutCombat == 0) return 0;
    final maintenant = DateTime.now().millisecondsSinceEpoch / 1000;
    return (maintenant - debutCombat).clamp(0, double.infinity);
  }

  // -------------------------------------------------------------- alimentation

  /// Integre un evenement. Rend vrai si l'affichage doit etre rafraichi.
  bool recoit(Map<String, dynamic> e) {
    if (enPause) return false;
    final ts = (e['ts'] as num?)?.toDouble() ?? 0;
    final change = _integre(e, ts);
    if (change) derniereActivite = DateTime.now().millisecondsSinceEpoch / 1000;
    return change;
  }

  bool _integre(Map<String, dynamic> e, double ts) {
    switch (e['type'] as String?) {
      case 'FightEnd':
        return _finDeCombat(e, ts);
      case 'AchievementUnlocked':
        return _succes(e, ts);
      case 'CharacterState':
        return _etat(e);
      case 'ItemGained':
        return _objet(e, ts);
      case 'PriceTable':
        return _prix(e);
      case 'ChallengeOffer':
        return _proposition(e);
      case 'ChallengeActive':
        final change = _combatImplicite();
        return _challengesActifs(e) || change;
      case 'TurnStart':
        return _tour(e);
      case 'ChallengeSelected':
        return _challengeChoisi(e);
      case 'ChallengeResult':
        return _challengeResultat(e, ts);
      case 'FightStart':
        return _entreeEnCombat(e, ts);
      case 'FightLeave':
        return _sortieDeCombat(e);
      case 'CharacterInfo':
        return _fiche(e);
    }
    return false;
  }

  /// Fiche d'un personnage croise : son nom, sa classe.
  ///
  /// La classe n'arrive qu'au passage sur une carte. Elle est notee ici et
  /// conservee par l'appelant d'une session a l'autre, sans quoi une soiree
  /// entiere en donjon laisserait les portraits vides.
  bool _fiche(Map<String, dynamic> e) {
    final nom = e['name'] as String?;
    final classe = (e['breed'] as num?)?.toInt();
    if (nom == null || classe == null) return false;
    classesApprises[nom] = classe;
    final connu = suivis[cleDe(nom)];
    final nouveau = connu != null && !connu.vu;
    final suivi = _suivi(nom);
    if (suivi == null) return false;
    if (suivi.classe == classe) return nouveau;
    suivi.classe = classe;
    return true;
  }

  Suivi? _suivi(String? nom) {
    if (nom == null || nom.isEmpty) return null;
    final suivi = suivis[cleDe(nom)];
    if (suivi == null) return null;
    if (suivi.nom != nom) {
      // Le serveur fait foi sur l'orthographe : on adopte la sienne, ce qui
      // corrige au passage la casse tapee dans les reglages.
      suivi.nom = nom;
    }
    // Le voir suffit a lui donner sa ligne : c'est ici que passe tout ce qui
    // le concerne, d'un gain a un simple changement de carte.
    suivi.vu = true;
    return suivi;
  }

  void _noteAuJournal(Fait fait) {
    journal.addFirst(fait);
    while (journal.length > tailleJournal) {
      journal.removeLast();
    }
  }

  /// La table des prix vient d'arriver : on rattrape tout l'historique.
  bool _prix(Map<String, dynamic> e) {
    final table = e['prices'] as Map<String, dynamic>? ?? {};
    table.forEach((cle, valeur) {
      final id = int.tryParse(cle);
      if (id != null && valeur is num) prix[id] = valeur.toInt();
    });
    var touche = false;
    for (final suivi in suivis.values) {
      touche = suivi.revalorise(prix) || touche;
    }
    return touche;
  }

  /// Reconnait un combat en cours sans avoir vu son engagement.
  ///
  /// Le suivi peut demarrer alors qu'un combat est deja lance, ou manquer le
  /// message d'entree ; certains signaux ne surviennent qu'en combat et
  /// suffisent a conclure. Le chronometre part alors de cet instant, faute de
  /// mieux.
  bool _combatImplicite() {
    if (enCombat) return false;
    enCombat = true;
    debutCombat = DateTime.now().millisecondsSinceEpoch / 1000;
    tour = 0;
    return true;
  }

  bool _tour(Map<String, dynamic> e) {
    var change = _combatImplicite();
    final t = (e['turn'] as num?)?.toInt() ?? 0;
    if (t != 0 && t != tour) {
      tour = t;
      change = true;
    }
    return change;
  }

  bool _proposition(Map<String, dynamic> e) {
    final offres = e['offers'] as List? ?? [];
    final paire = <int>{};
    for (final offre in offres) {
      if (offre is List && offre.isNotEmpty) {
        final id = (offre[0] as num).toInt();
        paire.add(id);
        if (offre.length > 1 && offre[1] is num) {
          propositions[id] = (offre[1] as num).toInt();
        }
      }
    }
    if (paire.isNotEmpty && !paires.any((p) => p.containsAll(paire))) {
      paires.add(paire);
    }
    return false;
  }

  /// D'ou vient un challenge declare en jeu.
  String _origine(int id, int? bonus) {
    if (choisis.contains(id)) return 'choisi';
    if (bonus == null) return 'objectif';
    if (propositions.containsKey(id)) return 'ecarte';
    return 'impose';
  }

  /// Liste des challenges reellement en jeu, qui fait autorite.
  ///
  /// C'est bien elle qu'il faut suivre, et non les selections : un donjon
  /// ajoute les siens, jamais proposes ni choisis, et un combat de boss garde
  /// en jeu la proposition ecartee.
  bool _challengesActifs(Map<String, dynamic> e) {
    final connus = {for (final c in challenges) c.challengeId: c};
    final nouveaux = <Challenge>[];
    final presents = <int>{};
    for (final actif in e['challenges'] as List? ?? []) {
      if (actif is! List || actif.isEmpty) continue;
      final id = (actif[0] as num).toInt();
      final bonus = actif.length > 1 && actif[1] is num
          ? (actif[1] as num).toInt()
          : null;
      presents.add(id);
      final existant = connus[id];
      if (existant != null) {
        if (bonus != null) existant.bonus = bonus;
        existant.origine = _origine(id, existant.bonus);
        nouveaux.add(existant);
      } else {
        nouveaux.add(Challenge(id, bonus: bonus, origine: _origine(id, bonus)));
      }
    }
    // Un challenge deja resolu mais absent de la liste reste affiche : son
    // issue vaut d'etre montree jusqu'a la fin du combat. Un absent non
    // resolu, lui, s'efface — c'est le serveur qui a raison.
    for (final c in challenges) {
      if (!presents.contains(c.challengeId) && c.reussi != null) {
        nouveaux.add(c);
      }
    }
    final avant = challenges
        .map((c) => '${c.challengeId}/${c.bonus}/${c.origine}')
        .join(',');
    final apres = nouveaux
        .map((c) => '${c.challengeId}/${c.bonus}/${c.origine}')
        .join(',');
    challenges = nouveaux;
    return avant != apres;
  }

  /// Le groupe a retenu un challenge. On le note, sans l'afficher.
  ///
  /// Afficher la selection serait une erreur : on peut changer d'avis. Un
  /// joueur avait clique sur Duel puis bascule sur Elitiste ; les deux
  /// restaient a l'ecran, alors que le serveur n'en a jamais mis qu'un en jeu.
  /// C'est la liste des actifs qui decide — la selection ne sert qu'a savoir,
  /// ensuite, lequel est celui du groupe.
  bool _challengeChoisi(Map<String, dynamic> e) {
    final id = (e['challenge_id'] as num?)?.toInt();
    if (id == null) return false;
    for (final paire in paires) {
      if (paire.contains(id)) choisis.removeAll(paire.difference({id}));
    }
    choisis.add(id);
    return false;
  }

  /// Issue d'un challenge.
  ///
  /// Le message arrive une fois par client : avec quatre personnages, le meme
  /// fait est annonce quatre fois. C'est une propriete du combat, pas du
  /// personnage — on ne le note donc qu'au premier.
  bool _challengeResultat(Map<String, dynamic> e, double ts) {
    final id = (e['challenge_id'] as num?)?.toInt();
    if (id == null) return false;
    final reussi = e['succeeded'] == true;
    for (final c in challenges) {
      if (c.challengeId == id) {
        if (c.reussi == reussi) return false; // deja connu, autre client
        c.reussi = reussi;
        _archiveChallenge(ts, c, reussi);
        _noteAuJournal(Fait(ts, 'challenge', identifiant: id, reussi: reussi));
        return true;
      }
    }
    final bonus = propositions[id];
    final challenge = Challenge(
      id,
      bonus: bonus,
      reussi: reussi,
      origine: _origine(id, bonus),
    );
    challenges.add(challenge);
    _archiveChallenge(ts, challenge, reussi);
    _noteAuJournal(Fait(ts, 'challenge', identifiant: id, reussi: reussi));
    return true;
  }

  /// Note l'issue dans l'historique, avec qui combattait alors.
  ///
  /// Si l'engagement n'a pas ete vu — suivi demarre en cours de combat — on ne
  /// sait pas qui est engage : on cite alors tous les personnages suivis
  /// plutot que de laisser la liste vide. Le repli passe par `tousLesSuivis`
  /// et non par les lignes : au premier combat d'une session, personne n'a
  /// encore ete rencontre et la liste serait vide.
  void _archiveChallenge(double ts, Challenge c, bool reussi) {
    var combattants = [
      for (final s in tousLesSuivis)
        if (s.enCombat) s.nom,
    ];
    if (combattants.isEmpty) {
      combattants = [for (final s in tousLesSuivis) s.nom];
    }
    final fait = ChallengeFait(
      ts: ts,
      challengeId: c.challengeId,
      bonus: c.bonus,
      origine: c.origine,
      reussi: reussi,
      combattants: combattants,
    );
    historiqueChallenges.add(fait);
    _challengesDuCombat.add(fait);
  }

  bool _entreeEnCombat(Map<String, dynamic> e, double ts) {
    _suivi(e['character'] as String?)?.enCombat = true;
    if (enCombat) return false;
    enCombat = true;
    challenges.clear();
    _challengesDuCombat.clear();
    propositions.clear();
    choisis.clear();
    paires.clear();
    // Horloge du poste, pas horodatage du paquet : en rejeu, le chronometre
    // doit compter depuis l'instant ou le combat passe a l'ecran.
    debutCombat = DateTime.now().millisecondsSinceEpoch / 1000;
    tour = 0;
    return true;
  }

  bool _sortieDeCombat(Map<String, dynamic> e) {
    _suivi(e['character'] as String?)?.enCombat = false;
    // Le combat n'est fini que lorsque plus aucun personnage suivi n'y est.
    if (enCombat && !suivis.values.any((s) => s.enCombat)) {
      enCombat = false;
      return true;
    }
    return false;
  }

  bool _finDeCombat(Map<String, dynamic> e, double ts) {
    // La duree vient du serveur : c'est celle que le jeu affiche, phase de
    // placement exclue. Le chronometre local, lui, rendait zero — la fin de
    // combat est emise avec une seconde de retard, le temps que les noms
    // arrivent, et la sortie de combat l'avait deja arrete d'ici la.
    final duree = (e['duration'] as num?)?.toDouble() ?? dureeCombat;
    final bilan = Fait(ts, 'combat', duree: duree);
    // Le recapitulatif est archive en entier, participants non suivis compris :
    // c'est ce qui permet de le rouvrir plus tard tel qu'on l'a vu en jeu.
    final complet = <ParticipantCombat>[];
    var touche = false;
    for (final p in e['participants'] as List? ?? []) {
      if (p is! Map) continue;
      complet.add(_participantArchive(p));
      final suivi = _suivi(p['name'] as String?);
      if (suivi == null) continue;
      final xp = (p['xp'] as num?)?.toInt() ?? 0;
      final kamas = (p['kamas'] as num?)?.toInt() ?? 0;
      suivi.xpGagnee += xp;
      suivi.kamasPiece += kamas;
      suivi.combats += 1;
      if (xp > suivi.meilleurCombat) suivi.meilleurCombat = xp;

      var unites = 0;
      for (final lot in p['loot'] as List? ?? []) {
        if (lot is! Map) continue;
        final itemId = (lot['item_id'] as num?)?.toInt();
        final quantite = (lot['quantity'] as num?)?.toInt() ?? 0;
        if (itemId == null || quantite <= 0) continue;
        // Le butin est deja entre dans l'inventaire quelques centiemes de
        // seconde plus tot ; on ne recompte que ce qui manque.
        final restant = quantite - _dejaEntre(suivi.nom, itemId, quantite, ts);
        final prixUnitaire =
            (lot['unit_price'] as num?)?.toInt() ?? prix[itemId];
        suivi.ajouteLot(itemId, restant, prixUnitaire);
        unites += quantite;
      }
      final niveau = (p['level'] as num?)?.toInt();
      if (niveau != null) suivi.niveau = niveau;
      final total = (p['xp_total'] as num?)?.toInt() ?? 0;
      if (total != 0) {
        suivi.xpTotal = total;
        suivi.xpSeuilBas = (p['xp_floor'] as num?)?.toInt() ?? 0;
        suivi.xpSeuilHaut = (p['xp_next'] as num?)?.toInt() ?? 0;
      }
      bilan.xp += xp;
      bilan.kamas += kamas;
      bilan.objets += unites;
      bilan.parts.add((suivi.nom, xp, kamas));
      touche = true;
    }
    if (touche) {
      // Un seul nom s'il n'y a qu'un personnage suivi dans ce combat ; au-dela,
      // le journal annonce le groupe et detaille en infobulle.
      if (bilan.parts.length == 1) bilan.personnage = bilan.parts.first.$1;
      _noteAuJournal(bilan);
      combats.add(
        Combat(
          fin: ts,
          duree: duree,
          participants: complet,
          challenges: List.of(_challengesDuCombat),
          adversaires: [
            for (final o in e['opponents'] as List? ?? [])
              if (o is Map)
                Adversaire(
                  monstre: (o['monster_id'] as num?)?.toInt(),
                  grade: (o['grade'] as num?)?.toInt(),
                ),
          ],
        ),
      );
    }
    // Vide dans tous les cas : un combat sans personnage suivi ne doit pas
    // leguer ses challenges au suivant.
    _challengesDuCombat.clear();
    return touche;
  }

  /// Le participant tel que le recapitulatif le decrit, sans retouche.
  ///
  /// Le butin est celui du recapitulatif, entier : le rapprochement avec
  /// l'inventaire ne sert qu'a ne pas doubler les totaux de la session, il n'a
  /// pas a amputer ce que le combat a reellement rendu.
  /// Issue portee par le recapitulatif chez un gagnant. Les autres — perdants,
  /// abandons — n'en portent aucune.
  static const _issueGagnante = 2;

  ParticipantCombat _participantArchive(Map p) {
    final butin = <int, (int, int?)>{};
    for (final lot in p['loot'] as List? ?? []) {
      if (lot is! Map) continue;
      final itemId = (lot['item_id'] as num?)?.toInt();
      final quantite = (lot['quantity'] as num?)?.toInt() ?? 0;
      if (itemId == null || quantite <= 0) continue;
      final prixUnitaire = (lot['unit_price'] as num?)?.toInt() ?? prix[itemId];
      final connu = butin[itemId];
      butin[itemId] = ((connu?.$1 ?? 0) + quantite, prixUnitaire ?? connu?.$2);
    }
    return ParticipantCombat(
      nom: '${p['name'] ?? ''}',
      niveau: (p['level'] as num?)?.toInt(),
      xp: (p['xp'] as num?)?.toInt() ?? 0,
      xpTotal: (p['xp_total'] as num?)?.toInt() ?? 0,
      xpSeuilBas: (p['xp_floor'] as num?)?.toInt() ?? 0,
      xpSeuilHaut: (p['xp_next'] as num?)?.toInt() ?? 0,
      kamas: (p['kamas'] as num?)?.toInt() ?? 0,
      // L'issue n'est portee que par les gagnants. Son absence, chez un
      // personnage qui a fui ou qui est tombe, est justement l'information.
      gagnant: (p['outcome'] as num?)?.toInt() == _issueGagnante,
      // Suivi ou invite : la question se tranche maintenant, pendant que la
      // liste est sous la main. Plus tard, l'archive relue ne saura plus qui
      // etait des notres ce soir-la — la liste aura pu changer.
      suivi: suivis.containsKey(cleDe('${p['name'] ?? ''}')),
      butin: butin,
    );
  }

  bool _succes(Map<String, dynamic> e, double ts) {
    final suivi = _suivi(e['character'] as String?);
    if (suivi == null) return false;
    // Le personnage est tout de meme reconnu — il vient de se manifester, sa
    // ligne doit apparaitre — mais rien de ce que le succes rend n'est
    // compte.
    if (!compteLesSucces) return false;
    final xp = (e['xp'] as num?)?.toInt() ?? 0;
    final kamas = (e['kamas'] as num?)?.toInt() ?? 0;
    suivi.xpGagnee += xp;
    suivi.kamasPiece += kamas;
    suivi.succes += 1;
    for (final lot in e['rewards'] as List? ?? []) {
      if (lot is! Map) continue;
      final itemId = (lot['item_id'] as num?)?.toInt();
      final quantite = (lot['quantity'] as num?)?.toInt() ?? 0;
      if (itemId == null || quantite <= 0) continue;
      final restant = quantite - _dejaEntre(suivi.nom, itemId, quantite, ts);
      suivi.ajouteLot(
        itemId,
        restant,
        (lot['unit_price'] as num?)?.toInt() ?? prix[itemId],
      );
    }
    _noteAuJournal(
      Fait(
        ts,
        'succes',
        personnage: e['character'] as String? ?? '',
        xp: xp,
        kamas: kamas,
        identifiant: (e['achievement_id'] as num?)?.toInt(),
      ),
    );
    return true;
  }

  bool _etat(Map<String, dynamic> e) {
    final suivi = _suivi(e['character'] as String?);
    if (suivi == null) return false;
    final niveau = (e['level'] as num?)?.toInt();
    final total = (e['xp_total'] as num?)?.toInt() ?? 0;
    final change = suivi.niveau != niveau || suivi.xpTotal != total;
    suivi.niveau = niveau;
    suivi.xpTotal = total;
    suivi.xpSeuilBas = (e['xp_floor'] as num?)?.toInt() ?? 0;
    suivi.xpSeuilHaut = (e['xp_next'] as num?)?.toInt() ?? 0;
    return change;
  }

  /// Objet entrant dans l'inventaire.
  ///
  /// Ignore pendant un combat : le butin y sera annonce par le recapitulatif,
  /// et le compter ici le doublerait. Hors combat, c'est une recolte, qui
  /// merite d'etre suivie au meme titre.
  bool _objet(Map<String, dynamic> e, double ts) {
    final suivi = _suivi(e['character'] as String?);
    if (suivi == null || suivi.enCombat) return false;
    // Un objet repris dans un coffre, les runes d'un brisage, les recompenses
    // d'un succes : tous entrent dans l'inventaire par le meme message qu'un
    // ramassage, et aucun n'est un gain de la session.
    //
    // Les recompenses d'un succes arrivent **avant** l'annonce du succes : les
    // ignorer ici est le seul moyen de les tenir a l'ecart quand leur comptage
    // est desactive. Quand il est actif, `_succes` les compte a partir de ce
    // que porte l'annonce — une fois, pas deux.
    //
    // Le personnage est tout de meme reconnu : il vient de se manifester, sa
    // ligne doit apparaitre.
    if (e['origin'] != null && e['origin'] != 'pickup') return false;
    final itemId = (e['item_id'] as num?)?.toInt();
    final quantite = (e['quantity'] as num?)?.toInt() ?? 0;
    if (itemId == null || quantite <= 0) return false;
    final prixUnitaire = (e['unit_price'] as num?)?.toInt() ?? prix[itemId];
    suivi.ajouteLot(itemId, quantite, prixUnitaire);
    _entrees.add(_Entree(ts, suivi.nom, itemId, quantite));
    _recolteAuJournal(ts, suivi.nom, itemId, quantite, prixUnitaire);
    return true;
  }

  /// Note une recolte, en fusionnant les repetitions proches.
  ///
  /// Recolter un champ produit une dizaine de messages en quelques secondes,
  /// tous pour la meme ressource. Les empiler tels quels chasserait tout le
  /// reste du journal ; on les regroupe donc en une seule ligne tant qu'ils se
  /// suivent.
  void _recolteAuJournal(
    double ts,
    String qui,
    int itemId,
    int quantite,
    int? prixUnitaire,
  ) {
    for (final fait in journal) {
      if (fait.genre != 'recolte') break; // un autre fait s'est intercale
      if (fait.identifiant == itemId &&
          cleDe(fait.personnage) == cleDe(qui) &&
          ts - fait.ts < 90) {
        fait.objets += quantite;
        fait.kamas += (prixUnitaire ?? 0) * quantite;
        fait.ts = ts;
        return;
      }
    }
    _noteAuJournal(
      Fait(
        ts,
        'recolte',
        personnage: qui,
        kamas: (prixUnitaire ?? 0) * quantite,
        objets: quantite,
        identifiant: itemId,
      ),
    );
  }

  /// Combien d'unites de ce lot sont deja entrees par l'inventaire.
  ///
  /// Un butin est annonce deux fois : le serveur pousse d'abord le mouvement
  /// d'inventaire, puis un recapitulatif — de combat ou de succes — le repete.
  /// Les compter aux deux endroits double le butin.
  ///
  /// L'inventaire arrivant en premier, on ne peut pas l'ignorer sur le moment :
  /// rien ne le distingue alors d'une recolte. On retient donc les entrees
  /// recentes, et le recapitulatif consomme celles qui lui correspondent. Le
  /// decompte se fait a l'unite : le recapitulatif groupe les lots — `486 x2` —
  /// la ou l'inventaire les envoie un par un.
  ///
  /// Sans correspondance — mouvement non recu, suivi demarre entre les deux
  /// messages — le lot est ajoute normalement, ce qui vaut mieux que de le
  /// perdre.
  int _dejaEntre(String personnage, int itemId, int quantite, double ts) {
    final cle = cleDe(personnage);
    _entrees.removeWhere((e) => e.ts < ts - fenetreRapprochement);
    var consommees = 0;
    for (final entree in List.of(_entrees)) {
      if (consommees >= quantite) break;
      if (cleDe(entree.personnage) != cle || entree.itemId != itemId) continue;
      final pris = entree.quantite < quantite - consommees
          ? entree.quantite
          : quantite - consommees;
      consommees += pris;
      entree.quantite -= pris;
      if (entree.quantite <= 0) _entrees.remove(entree);
      _retireDuJournal(entree.personnage, itemId, pris);
    }
    return consommees;
  }

  /// Defait la ligne de recolte d'un lot qui s'avere etre du butin.
  void _retireDuJournal(String personnage, int itemId, int quantite) {
    final cle = cleDe(personnage);
    var reste = quantite;
    for (final fait in List.of(journal)) {
      if (fait.genre != 'recolte' ||
          fait.identifiant != itemId ||
          cleDe(fait.personnage) != cle ||
          fait.objets <= 0) {
        continue;
      }
      final pris = fait.objets < reste ? fait.objets : reste;
      final part = fait.objets > 0 ? fait.kamas ~/ fait.objets : 0;
      fait.objets -= pris;
      fait.kamas = (fait.kamas - part * pris).clamp(0, 1 << 62);
      if (fait.objets <= 0) journal.remove(fait);
      reste -= pris;
      if (reste <= 0) return;
    }
  }
}
