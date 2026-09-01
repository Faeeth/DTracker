/// Les sessions passees, conservees sur le disque.
///
/// Une session de farm ne vaut pas que sur le moment : on veut pouvoir y
/// revenir, comparer une soiree a une autre, retrouver ce qu'un donjon a
/// rapporte. Chaque session est donc ecrite dans son propre fichier, sous son
/// horodatage, et relue telle quelle.
///
/// Le format est le meme a l'ecriture et a la lecture : ce que l'archive
/// contient est exactement ce que l'affichage montre. Il reste lisible a la
/// main, comme le reste des fichiers de cet outil.
///
/// La session en cours est ecrite au fil de l'eau plutot qu'a la fermeture :
/// une mise en veille ou une coupure ne doit pas emporter la soiree.
library;

import 'dart:convert';
import 'dart:io';

import '../modele/session.dart';

/// Ce qu'on garde d'un personnage a la fin d'une session.
class BilanPersonnage {
  BilanPersonnage({
    required this.nom,
    required this.classe,
    required this.niveau,
    required this.xp,
    required this.kamasPiece,
    required this.butin,
  });

  final String nom;
  final int? classe;
  final int? niveau;
  final int xp;
  final int kamasPiece;

  /// Type d'objet -> (quantite, prix unitaire connu).
  final Map<int, (int, int?)> butin;

  int get kamasButin =>
      butin.values.fold(0, (somme, lot) => somme + (lot.$2 ?? 0) * lot.$1);
  int get kamasTotal => kamasPiece + kamasButin;
  int get unites => butin.values.fold(0, (somme, lot) => somme + lot.$1);

  Map<String, dynamic> versJson() => {
    'nom': nom,
    if (classe != null) 'classe': classe,
    if (niveau != null) 'niveau': niveau,
    'xp': xp,
    'kamas_piece': kamasPiece,
    'butin': {
      for (final e in butin.entries)
        '${e.key}': {
          'quantite': e.value.$1,
          if (e.value.$2 != null) 'prix': e.value.$2,
        },
    },
  };

  static BilanPersonnage depuisJson(Map<String, dynamic> j) => BilanPersonnage(
    nom: '${j['nom'] ?? ''}',
    classe: (j['classe'] as num?)?.toInt(),
    niveau: (j['niveau'] as num?)?.toInt(),
    xp: (j['xp'] as num?)?.toInt() ?? 0,
    kamasPiece: (j['kamas_piece'] as num?)?.toInt() ?? 0,
    butin: {
      for (final e in (j['butin'] as Map<String, dynamic>? ?? {}).entries)
        if (int.tryParse(e.key) != null && e.value is Map)
          int.parse(e.key): (
            ((e.value as Map)['quantite'] as num?)?.toInt() ?? 0,
            ((e.value as Map)['prix'] as num?)?.toInt(),
          ),
    },
  );

  static BilanPersonnage depuisSuivi(Suivi s) => BilanPersonnage(
    nom: s.nom,
    classe: s.classe,
    niveau: s.niveau,
    xp: s.xpGagnee,
    kamasPiece: s.kamasPiece,
    butin: {
      for (final lot in s.butin.values)
        lot.itemId: (lot.quantite, lot.prixUnitaire),
    },
  );
}

/// Une session, en cours ou terminee.
class Archive {
  Archive({
    required this.nom,
    required this.numero,
    required this.periodes,
    required this.enCours,
    required this.personnages,
    required this.challenges,
    required this.journal,
    required this.combats,
    this.fichier,
  });

  /// Nom du fichier d'ou elle a ete relue. Nul pour un instantane de la
  /// session en cours, qui n'a pas encore forcement de fichier.
  final String? fichier;

  /// Le nom donne a la session, ou son nom par defaut.
  final String nom;

  /// Son numero d'ordre, qui sert a numeroter la suivante.
  final int numero;

  /// Les intervalles d'ecoute. Une session de quatre jours relancee douze fois
  /// en a douze : sa duree est leur somme, pas l'ecart entre les extremes.
  final List<Periode> periodes;

  final bool enCours;
  final List<BilanPersonnage> personnages;
  final List<ChallengeFait> challenges;
  final List<Fait> journal;

  /// Les combats, recapitulatif complet compris : c'est ce qui permet de
  /// rouvrir l'un d'eux tel qu'on l'a vu en jeu.
  final List<Combat> combats;

  double get debut => periodes.isEmpty ? 0 : periodes.first.debut;

  /// Fin de la derniere periode, ou maintenant si elle court encore.
  double get fin => periodes.isEmpty
      ? 0
      : periodes.last.fin ?? DateTime.now().millisecondsSinceEpoch / 1000;

  DateTime get quand =>
      DateTime.fromMillisecondsSinceEpoch((debut * 1000).round());

  /// Temps reellement passe dessus, pauses et fermetures deduites.
  int get duree {
    final maintenant = DateTime.now().millisecondsSinceEpoch / 1000;
    return periodes
        .fold(0.0, (somme, p) => somme + p.ecoulee(maintenant))
        .round()
        .clamp(0, 1 << 30);
  }

  /// Nombre de fois que l'outil a ete lance pour cette session.
  int get reprises => periodes.length;

  int get xp => personnages.fold(0, (somme, p) => somme + p.xp);
  int get kamas => personnages.fold(0, (somme, p) => somme + p.kamasTotal);
  int get nombreCombats => combats.length;

  /// Les challenges de la session, objectifs de boss exclus.
  List<ChallengeFait> get challengesSeuls => [
    for (final c in challenges)
      if (c.estChallenge) c,
  ];

  int get challengesReussis => challengesSeuls.where((c) => c.reussi).length;

  /// Rien ne s'est passe : lancer l'outil puis le fermer ne doit pas laisser
  /// de fichier. Une session ne nait qu'au premier fait.
  bool get estVide =>
      combats.isEmpty &&
      challenges.isEmpty &&
      journal.isEmpty &&
      xp == 0 &&
      kamas == 0;

  /// Les challenges d'un combat.
  ///
  /// Les archives ecrites avant que le combat ne porte les siens n'ont qu'une
  /// liste globale : on les rapproche alors par le temps, entre la fin du
  /// combat precedent et celle de celui-ci. Approximatif mais juste dans la
  /// pratique — les challenges tombent pendant leur propre combat.
  List<ChallengeFait> challengesDe(int index) {
    final combat = combats[index];
    if (combat.challenges.isNotEmpty) return combat.challenges;
    final depuis = index > 0 ? combats[index - 1].fin : debut;
    return [
      for (final c in challenges)
        if (c.ts > depuis && c.ts <= combat.fin) c,
    ];
  }

  /// Nom de fichier : l'horodatage du debut, trie donc chronologiquement.
  String get nomFichier {
    final d = quand;
    String n(int v, [int l = 2]) => v.toString().padLeft(l, '0');
    return 'session-${n(d.year, 4)}${n(d.month)}${n(d.day)}'
        '-${n(d.hour)}${n(d.minute)}${n(d.second)}.json';
  }

  Map<String, dynamic> versJson() => {
    'nom': nom,
    'numero': numero,
    'periodes': [for (final p in periodes) p.versJson()],
    // Redondants avec les periodes, mais c'est par eux qu'on se repere en
    // ouvrant le fichier a la main.
    'debut': debut,
    'fin': fin,
    'en_cours': enCours,
    'personnages': [for (final p in personnages) p.versJson()],
    'challenges': [for (final c in challenges) c.versJson()],
    'combats': [for (final c in combats) c.versJson()],
    'journal': [
      for (final f in journal)
        {
          'ts': f.ts,
          'genre': f.genre,
          if (f.personnage.isNotEmpty) 'personnage': f.personnage,
          if (f.xp != 0) 'xp': f.xp,
          if (f.kamas != 0) 'kamas': f.kamas,
          if (f.objets != 0) 'objets': f.objets,
          if (f.identifiant != null) 'identifiant': f.identifiant,
          if (f.reussi != null) 'reussi': f.reussi,
          if (f.duree != 0) 'duree': f.duree,
          if (f.parts.isNotEmpty)
            'parts': [
              for (final (nom, xp, kamas) in f.parts)
                {'nom': nom, 'xp': xp, 'kamas': kamas},
            ],
        },
    ],
  };

  static Archive depuisJson(Map<String, dynamic> j, {String? fichier}) {
    final journal = <Fait>[];
    for (final f in j['journal'] as List? ?? []) {
      if (f is! Map) continue;
      final fait = Fait(
        (f['ts'] as num?)?.toDouble() ?? 0,
        '${f['genre'] ?? ''}',
        personnage: '${f['personnage'] ?? ''}',
        xp: (f['xp'] as num?)?.toInt() ?? 0,
        kamas: (f['kamas'] as num?)?.toInt() ?? 0,
        objets: (f['objets'] as num?)?.toInt() ?? 0,
        identifiant: (f['identifiant'] as num?)?.toInt(),
        reussi: f['reussi'] as bool?,
        duree: (f['duree'] as num?)?.toDouble() ?? 0,
      );
      for (final p in f['parts'] as List? ?? []) {
        if (p is Map) {
          fait.parts.add((
            '${p['nom'] ?? ''}',
            (p['xp'] as num?)?.toInt() ?? 0,
            (p['kamas'] as num?)?.toInt() ?? 0,
          ));
        }
      }
      journal.add(fait);
    }
    // Les archives ecrites avant les periodes n'ont que deux bornes : elles
    // valent une periode unique, ce qui est exactement ce qu'elles etaient.
    final periodes = [
      for (final p in j['periodes'] as List? ?? [])
        if (p is Map<String, dynamic>) Periode.depuisJson(p),
    ];
    if (periodes.isEmpty) {
      periodes.add(
        Periode(
          (j['debut'] as num?)?.toDouble() ?? 0,
          (j['fin'] as num?)?.toDouble(),
        ),
      );
    }
    return Archive(
      fichier: fichier,
      nom: '${j['nom'] ?? ''}',
      numero: (j['numero'] as num?)?.toInt() ?? 0,
      periodes: periodes,
      enCours: j['en_cours'] == true,
      personnages: [
        for (final p in j['personnages'] as List? ?? [])
          if (p is Map<String, dynamic>) BilanPersonnage.depuisJson(p),
      ],
      challenges: [
        for (final c in j['challenges'] as List? ?? [])
          if (c is Map<String, dynamic>) ChallengeFait.depuisJson(c),
      ],
      journal: journal,
      combats: [
        for (final c in j['combats'] as List? ?? [])
          if (c is Map<String, dynamic>) Combat.depuisJson(c),
      ],
    );
  }

  /// Reverse cette archive dans une session vivante.
  ///
  /// C'est ce qui permet de revenir sur une soiree passee et de la reprendre
  /// la ou on l'avait laissee : les compteurs, les combats, les challenges et
  /// le journal retrouvent leur etat, et la session **repart** — on y basculee
  /// pour continuer, pas pour la regarder. Une session rechargee en pause
  /// obligeait a un second geste dont personne ne voyait la raison.
  ///
  /// `enPause` reste disponible pour qui veut consulter sans enregistrer.
  ///
  /// Les personnages de l'archive qui ne sont plus suivis reprennent leur
  /// ligne le temps de la consultation. Les cacher serait pire : la session
  /// afficherait des totaux sans les lignes qui les composent.
  void rechargeDans(Session session) {
    session.remetAZero();
    session.enCombat = false;
    session.nom = nom;
    session.numero = numero;
    session.periodes
      ..clear()
      ..addAll([for (final p in periodes) Periode(p.debut, p.fin)]);
    // Les periodes heritees sont closes, et une neuve s'ouvre : c'est ainsi
    // que les douze lancements d'une meme session s'additionnent sans compter
    // les nuits ni le temps passe ailleurs.
    final maintenant = DateTime.now().millisecondsSinceEpoch / 1000;
    for (final p in session.periodes) {
      p.fin ??= maintenant;
    }
    session.periodes.add(Periode(maintenant));
    session.derniereActivite = fin;

    final noms = List.of(session.suivisChoisis);
    for (final p in personnages) {
      if (!noms.any((n) => cleDe(n) == cleDe(p.nom))) noms.add(p.nom);
    }
    session.definitPersonnages(noms);

    for (final p in personnages) {
      final suivi = session.suivis[cleDe(p.nom)];
      if (suivi == null) continue;
      suivi.nom = p.nom;
      suivi.vu = true;
      if (p.classe != null) suivi.classe = p.classe;
      suivi.niveau = p.niveau;
      suivi.xpGagnee = p.xp;
      suivi.kamasPiece = p.kamasPiece;
      p.butin.forEach((id, lot) => suivi.ajouteLot(id, lot.$1, lot.$2));
    }

    session.combats.addAll(combats);
    session.historiqueChallenges.addAll(challenges);
    session.journal.addAll(journal);

    // Ce que le bilan ne stocke pas se relit dans les combats : le nombre de
    // combats, le meilleur d'entre eux, et l'etat d'experience du dernier —
    // celui qui donne sa barre de progression a la ligne.
    for (final combat in combats) {
      for (final p in combat.participants) {
        final suivi = session.suivis[cleDe(p.nom)];
        if (suivi == null) continue;
        suivi.combats += 1;
        if (p.xp > suivi.meilleurCombat) suivi.meilleurCombat = p.xp;
        if (p.xpTotal != 0) {
          suivi.xpTotal = p.xpTotal;
          suivi.xpSeuilBas = p.xpSeuilBas;
          suivi.xpSeuilHaut = p.xpSeuilHaut;
          suivi.niveau = p.niveau ?? suivi.niveau;
        }
      }
    }
    for (final fait in journal) {
      if (fait.genre == 'succes') {
        session.suivis[cleDe(fait.personnage)]?.succes += 1;
      }
    }
  }

  /// Instantane de la session en cours.
  static Archive depuisSession(Session session) => Archive(
    nom: session.nom,
    numero: session.numero,
    // Copiees : l'archive est un instantane, la session continue de vivre.
    periodes: [for (final p in session.periodes) Periode(p.debut, p.fin)],
    enCours: true,
    personnages: [
      for (final s in session.lignes) BilanPersonnage.depuisSuivi(s),
    ],
    challenges: List.of(session.historiqueChallenges),
    journal: session.journal.toList(),
    combats: List.of(session.combats),
  );
}

/// Le dossier des sessions.
class Archives {
  Archives(this.dossier);

  final String dossier;

  /// Nom du fichier de la session en cours, fige a son premier
  /// enregistrement : sans cela, une session qui dure changerait de fichier a
  /// chaque ecriture.
  String? _enCours;

  Directory get _repertoire => Directory(dossier);

  /// Le fichier auquel la session est rattachee, s'il en a un.
  String? get courant => _enCours;

  /// Rattache la session a un fichier existant : c'est ce qui fait qu'une
  /// session rechargee se reecrit chez elle, au lieu de se dedoubler.
  void reprend(String fichier) => _enCours = fichier;

  /// Ecrit la session en cours. Sans rien a montrer, on n'ecrit rien : une
  /// session naissante n'existe qu'en memoire, et ne prend un fichier qu'au
  /// premier fait — lancer l'outil puis basculer ailleurs ne doit pas semer
  /// des sessions vides.
  /// Ce qui, dans une session, peut avoir bouge depuis la derniere ecriture.
  ///
  /// La sauvegarde revient toutes les vingt secondes, qu'on joue ou non, et
  /// serialise alors toute la soiree — combats, journal, challenges — en JSON
  /// indente, sur le fil qui dessine la fenetre. Une soiree qui dure, c'est
  /// plusieurs mega-octets refaits pour rien pendant qu'on est en ville.
  ///
  /// Cette empreinte ne coute que quelques additions et suffit a le voir : un
  /// combat, un fait, un challenge, une piece, une pause ou un renommage la
  /// changent tous.
  String? _empreinte;

  static String _signe(Session session) {
    final s = StringBuffer()
      // L'identite d'abord : deux sessions differentes peuvent tres bien
      // porter les memes compteurs, et la seconde doit s'ecrire quand meme.
      ..write(session.numero)
      ..write('/')
      ..write(session.debut)
      ..write('/')
      ..write(session.nom)
      ..write('/')
      ..write(session.combats.length)
      ..write('/')
      ..write(session.journal.length)
      ..write('/')
      ..write(session.historiqueChallenges.length)
      ..write('/')
      ..write(session.periodes.length)
      ..write('/')
      ..write(session.xpTotale)
      ..write('/')
      ..write(session.kamasTotaux);
    for (final suivi in session.lignes) {
      s
        ..write('/')
        ..write(suivi.nom)
        ..write(':')
        ..write(suivi.xpTotal)
        ..write(':')
        ..write(suivi.succes);
    }
    return s.toString();
  }

  Future<void> enregistre(Session session, {bool force = false}) async {
    final empreinte = _signe(session);
    if (!force && empreinte == _empreinte) return;
    final archive = Archive.depuisSession(session);
    if (archive.estVide) return;
    _enCours ??= archive.nomFichier;
    await _ecrit(_enCours!, archive);
    _empreinte = empreinte;
  }

  /// Au demarrage, plus rien n'est « en cours ».
  ///
  /// Le marqueur dit quelle session l'outil alimente. Une session restee
  /// marquee appartient a une execution precedente — fermeture brutale, mise
  /// en veille — et le nouveau lancement ouvre la sienne. Sans ce nettoyage,
  /// la liste finissait par afficher plusieurs sessions « en cours », dont
  /// une seule l'etait.
  Future<void> clotLesOrphelines() async {
    for (final archive in await liste()) {
      if (!archive.enCours || archive.fichier == null) continue;
      await _ecrit(archive.fichier!, _close(archive));
    }
  }

  static Archive _close(Archive a) => Archive(
    fichier: a.fichier,
    nom: a.nom,
    numero: a.numero,
    periodes: a.periodes,
    enCours: false,
    personnages: a.personnages,
    challenges: a.challenges,
    journal: a.journal,
    combats: a.combats,
  );

  /// Clot la session en cours : sa periode se ferme, et elle cesse d'etre
  /// celle que l'outil alimente.
  Future<void> clot(Session session) async {
    final maintenant = DateTime.now().millisecondsSinceEpoch / 1000;
    for (final p in session.periodes) {
      p.fin ??= maintenant;
    }
    if (_enCours == null) {
      await enregistre(session);
      if (_enCours == null) return;
    }
    await _ecrit(_enCours!, _close(Archive.depuisSession(session)));
    _enCours = null;
    // L'empreinte va avec le fichier : la session suivante doit s'ecrire des
    // son premier enregistrement, meme si elle porte les memes compteurs.
    _empreinte = null;
  }

  /// Oublie la session courante sans la clore : la suivante aura son fichier.
  void repart() {
    _enCours = null;
    _empreinte = null;
  }

  Future<void> _ecrit(String nom, Archive archive) async {
    try {
      await _repertoire.create(recursive: true);
      await File('$dossier/$nom').writeAsString(
        const JsonEncoder.withIndent('  ').convert(archive.versJson()),
      );
    } on Exception {
      // Disque plein ou en lecture seule : on ne perd qu'une archive.
    }
  }

  /// Le numero a donner a la prochaine session.
  ///
  /// Un increment plutot qu'un compte : effacer une archive ne doit pas faire
  /// reapparaitre un numero deja porte.
  Future<int> prochainNumero() async {
    var maximum = 0;
    for (final a in await liste()) {
      if (a.numero > maximum) maximum = a.numero;
    }
    return maximum + 1;
  }

  /// Supprime une session archivee.
  ///
  /// Refuse celle que l'outil alimente : son fichier serait recree a la
  /// sauvegarde suivante, quelques secondes plus tard. Une suppression qui se
  /// defait toute seule vaut moins qu'un refus franc.
  ///
  /// Rend vrai si le fichier a bien disparu.
  Future<bool> supprime(Archive archive) async {
    final fichier = archive.fichier;
    if (fichier == null || fichier == _enCours) return false;
    try {
      final cible = File('$dossier/$fichier');
      if (!await cible.exists()) return false;
      await cible.delete();
      return true;
    } on Exception {
      // Fichier verrouille ou dossier en lecture seule : on ne pretend pas.
      return false;
    }
  }

  /// Renomme une session archivee, sur place.
  Future<void> renomme(Archive archive, String nom) async {
    if (archive.fichier == null) return;
    await _ecrit(
      archive.fichier!,
      Archive(
        fichier: archive.fichier,
        nom: nom,
        numero: archive.numero,
        periodes: archive.periodes,
        enCours: archive.enCours,
        personnages: archive.personnages,
        challenges: archive.challenges,
        journal: archive.journal,
        combats: archive.combats,
      ),
    );
  }

  /// Les sessions, de la plus recente a la plus ancienne.
  ///
  /// L'ordre est celui du temps, pas celui du disque : c'est ainsi qu'on les
  /// cherche, et la session en cours se trouve donc toujours en tete.
  Future<List<Archive>> liste() async {
    if (!await _repertoire.exists()) return [];
    final archives = <Archive>[];
    await for (final entree in _repertoire.list()) {
      if (entree is! File || !entree.path.endsWith('.json')) continue;
      try {
        final objet = jsonDecode(await entree.readAsString());
        if (objet is Map<String, dynamic>) {
          archives.add(
            Archive.depuisJson(objet, fichier: entree.uri.pathSegments.last),
          );
        }
      } on Exception {
        // Archive illisible : on passe, les autres restent lisibles.
      }
    }
    archives.sort((a, b) => b.debut.compareTo(a.debut));
    return archives;
  }
}
