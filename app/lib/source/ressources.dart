/// Libelles et icones du jeu, pour que l'affichage montre autre chose que des
/// nombres.
///
/// Le protocole ne transporte que des identifiants : un butin arrive comme
/// `303 x2`, un challenge comme `20`. Les noms et les images correspondants
/// sont extraits des fichiers du client par les deux outils de `dofus_stats`
/// (`extract_data.py`, `extract_images.py`) et deposes dans son dossier
/// `data/`. On les relit ici.
///
/// Trois tables suffisent a relier un identifiant a son image :
///
///     identifiant --(data/icons/)--> iconId --(index.json)--> fichier PNG
///
/// Le detour par `iconId` n'est pas gratuit : plusieurs objets partagent une
/// meme icone, et le nom du fichier n'est pas toujours un nombre nu — les
/// sorts sortent en `sort_11830`. L'index ecrit a l'extraction absorbe ces
/// deux ecarts.
///
/// Les images ne sont pas embarquees dans l'application : elles pesent un
/// gigaoctet et demi et changent a chaque mise a jour du jeu. Elles sont lues
/// sur le disque, a la demande.
///
/// Rien de tout cela n'est indispensable. Si le dossier manque, l'objet se
/// declare indisponible et l'affichage retombe sur les identifiants.
library;

import 'dart:convert';
import 'dart:io';

/// Categorie de donnees -> dossier d'images. La resolution 2x est preferee :
/// les icones sont reduites a l'affichage, et partir du double donne un bord
/// net.
const _dossiers = <String, (String, List<String>)>{
  'items': ('item', ['2x', '1x']),
  'breeds': ('class', ['2x', '1x', 'base']),
  'challenges': ('challenge', ['2x', '1x']),
  'achievements': ('achievement', ['all']),
  'monsters': ('monster', ['2x', '1x']),
};

/// Ce qu'on sait d'un objet au-dela de son nom.
class DetailObjet {
  const DetailObjet({this.niveau = 0, this.poids = 0, this.type = ''});

  final int niveau;

  /// En pods, comme le jeu les compte.
  final int poids;

  final String type;

  bool get vide => niveau == 0 && poids == 0 && type.isEmpty;
}

class Ressources {
  Ressources(this.racine);

  /// Dossier `data/` de la bibliotheque.
  final String racine;

  final Map<String, Map<String, String>> _libelles = {};
  final Map<String, Map<String, int>> _icones = {};
  final Map<String, (String, Map<String, String>)> _index = {};
  final Map<int, String> _enonces = {};
  bool _enoncesLus = false;

  Map<String, dynamic>? _objets;
  Map<String, dynamic>? _monstres;

  bool get disponible =>
      (_libelles['items']?.isNotEmpty ?? false) ||
      (_libelles['challenges']?.isNotEmpty ?? false);

  Future<void> charge() async {
    for (final categorie in _dossiers.keys) {
      _libelles[categorie] = (await _lit('labels/$categorie.json'))
          .map((c, v) => MapEntry(c, '$v'));
      _icones[categorie] = (await _lit('icons/$categorie.json'))
          .map((c, v) => MapEntry(c, (v as num).toInt()));
    }
  }

  Future<Map<String, dynamic>> _lit(String relatif) async {
    try {
      final fichier = File('$racine/$relatif');
      if (!await fichier.exists()) return {};
      final objet = jsonDecode(await fichier.readAsString());
      return objet is Map<String, dynamic> ? objet : {};
    } on Exception {
      return {};
    }
  }

  // ------------------------------------------------------------------ libelles

  String objet(int id) => _libelles['items']?['$id'] ?? 'Objet $id';

  String challenge(int id) =>
      _libelles['challenges']?['$id'] ?? 'Challenge $id';

  String succes(int id) => _libelles['achievements']?['$id'] ?? 'Succès $id';

  /// Nom de la classe : Iop, Sadida, Eniripsa...
  String? classe(int? id) => id == null ? null : _libelles['breeds']?['$id'];

  /// Enonce d'un challenge, tire des enregistrements complets.
  ///
  /// Charge au premier appel seulement : le fichier est petit, mais il n'y a
  /// aucune raison de le lire si l'on n'entre jamais en combat.
  Future<String?> enonceChallenge(int id) async {
    if (!_enoncesLus) {
      _enoncesLus = true;
      try {
        final fichier = File('$racine/records/challenges.json');
        if (await fichier.exists()) {
          final liste = jsonDecode(await fichier.readAsString());
          if (liste is List) {
            for (final enregistrement in liste) {
              if (enregistrement is Map &&
                  enregistrement['id'] is num &&
                  enregistrement['description'] is String) {
                _enonces[(enregistrement['id'] as num).toInt()] =
                    enregistrement['description'] as String;
              }
            }
          }
        }
      } on Exception {
        // Sans enonce, l'infobulle se contente du nom.
      }
    }
    return _enonces[id];
  }

  // -------------------------------------------------------------------- images

  /// Dossier d'images retenu pour une categorie, et son index.
  ///
  /// Les variantes sont essayees dans l'ordre : la premiere qui existe gagne,
  /// ce qui laisse le programme fonctionner si seule la resolution simple a
  /// ete extraite.
  (String, Map<String, String>) _dossier(String categorie) {
    final connu = _index[categorie];
    if (connu != null) return connu;
    final (nom, variantes) = _dossiers[categorie]!;
    for (final variante in variantes) {
      final chemin = '$racine/images/$nom/$variante';
      final fichier = File('$chemin/index.json');
      if (fichier.existsSync()) {
        try {
          final objet = jsonDecode(fichier.readAsStringSync());
          if (objet is Map<String, dynamic> && objet.isNotEmpty) {
            return _index[categorie] = (
              chemin,
              objet.map((c, v) => MapEntry(c, '$v')),
            );
          }
        } on Exception {
          // Index illisible : on essaie la variante suivante.
        }
      }
    }
    return _index[categorie] = ('', <String, String>{});
  }

  /// Chemin du fichier portant un numero d'icone donne, s'il existe.
  String? _fichier(String categorie, int iconId) {
    final (chemin, index) = _dossier(categorie);
    final nom = index['$iconId'];
    return nom == null ? null : '$chemin/$nom';
  }

  /// Chemin de l'image d'une entite. Nul si introuvable.
  ///
  /// Retenu : une case d'inventaire demande son image a chaque construction,
  /// et chacune valait deux recherches dans les index plus une concatenation
  /// de chemin. Les index ne changent pas une fois lus.
  final Map<String, String?> _chemins = {};

  String? image(String categorie, int id) {
    final clef = '$categorie:$id';
    final connu = _chemins[clef];
    if (connu != null || _chemins.containsKey(clef)) return connu;
    final iconId = _icones[categorie]?['$id'];
    return _chemins[clef] = iconId == null ? null : _fichier(categorie, iconId);
  }

  String? imageObjet(int itemId) => image('items', itemId);

  String? imageChallenge(int challengeId) => image('challenges', challengeId);

  /// Portrait de classe.
  ///
  /// Les fichiers s'appellent `Head_<classe><sexe>` — `Head_120` pour un
  /// Pandawa masculin, `Head_121` pour une Pandawa. Le sexe ne circule pas sur
  /// le reseau : on prend le portrait masculin, la classe etant la meme dans
  /// les deux.
  String? imageClasse(int? classe) =>
      classe == null ? null : _fichier('breeds', classe * 10);

  /// Un index annexe, lu d'un bloc au premier besoin.
  ///
  /// Rend une table vide si le fichier manque : l'extraction est facultative,
  /// et l'affichage se contente alors de ce qu'il sait deja.
  Map<String, dynamic> _lu(String nom) {
    try {
      final fichier = File('$racine/$nom');
      if (!fichier.existsSync()) return {};
      final objet = jsonDecode(fichier.readAsStringSync());
      return objet is Map<String, dynamic> ? objet : {};
    } on Exception {
      return {};
    }
  }

  String monstre(int id) => _libelles['monsters']?['$id'] ?? 'Monstre $id';

  /// Le dessin d'un monstre.
  ///
  /// Par le `gfxId`, jamais par l'identifiant du monstre : le dossier
  /// `images/monster/` est range par sprite, et les deux series de numeros se
  /// recouvrent. Prendre l'un pour l'autre ne donnait donc pas une image
  /// manquante mais une **autre image** — un Moskito paraissait en « La
  /// Folle », un Champ Champ en « Boo ». Les deux numeros existent, aucun ne
  /// proteste.
  String? imageMonstre(int id) {
    final gfx = (_fiche(id)?['g'] as num?)?.toInt();
    return gfx == null ? null : _fichier('monsters', gfx);
  }

  /// Le niveau d'un monstre a un grade donne.
  ///
  /// Un monstre n'a pas un niveau mais cinq, un par grade — une Rose
  /// Demoniaque va du niveau 16 au niveau 20. Le combat annonce le grade,
  /// l'index donne le niveau.
  int? niveauMonstre(int id, int? grade) {
    final niveaux = _fiche(id)?['n'];
    if (niveaux is! Map) return null;
    final niveau = niveaux['${grade ?? 1}'] ?? niveaux['1'];
    return (niveau as num?)?.toInt();
  }

  /// La fiche d'un monstre : son sprite, ses niveaux. Lue au premier besoin,
  /// comme celle des objets.
  Map? _fiche(int id) {
    _monstres ??= _lu('monstres.json');
    final brut = _monstres!['$id'];
    return brut is Map ? brut : null;
  }

  /// Le niveau, le poids et le type d'un objet.
  ///
  /// L'index est lu au premier besoin, et une seule fois. Il est tire de
  /// `records/items.json` par l'extracteur : ce dernier pese quarante-quatre
  /// megaoctets, l'index moins d'un — le charger d'emblee pour une infobulle
  /// qu'on n'ouvrira peut-etre jamais serait un mauvais echange.
  ///
  /// Rend un detail vide si l'index n'a pas ete extrait : l'infobulle se
  /// contente alors du nom et des prix, ce qui reste utile.
  /// Retenu par objet : le detail sert de clef de tri a l'inventaire et
  /// d'appui a chaque infobulle. Le construire a chaque fois revenait a
  /// relire la table et a rebatir la meme chaine de type.
  final Map<int, DetailObjet> _details = {};

  DetailObjet detailObjet(int itemId) {
    final connu = _details[itemId];
    if (connu != null) return connu;
    _objets ??= _lu('objets.json');
    final brut = _objets!['$itemId'];
    if (brut is! Map) return _details[itemId] = const DetailObjet();
    return _details[itemId] = DetailObjet(
      niveau: (brut['n'] as num?)?.toInt() ?? 0,
      poids: (brut['p'] as num?)?.toInt() ?? 0,
      type: '${brut['t'] ?? ''}',
    );
  }

  /// Le symbole des kamas : le « K » seul, sans son disque.
  ///
  /// Le jeu en dessine deux. Celui des etats de sort est une piece complete,
  /// fond jaune compris, qui fait une pastille de trop dans un tableau deja
  /// dense. Celui des icones est le glyphe nu, en blanc : on le teinte a la
  /// couleur des kamas, comme le fait le jeu.
  ///
  /// Retenu au premier appel : il est demande une fois par ligne de tableau,
  /// et chercher le fichier sur le disque a chaque construction coutait une
  /// poignee d'appels systeme par image affichee.
  String? _kamas;
  bool _kamasCherche = false;

  String? get imageKamas {
    if (_kamasCherche) return _kamas;
    _kamasCherche = true;
    for (final chemin in [
      '$racine/images/icons/2x/kamas.png',
      '$racine/images/icons/1x/kamas.png',
      '$racine/images/spellstate/all/stateKama0.png',
    ]) {
      if (File(chemin).existsSync()) return _kamas = chemin;
    }
    return null;
  }

  /// L'icone des pods, retenue au premier appel comme celle des kamas.
  ///
  /// On prend le glyphe monochrome et non le dessin en couleurs de
  /// `spriteassets` : teint comme le chiffre qu'il suit, il se tient dans le
  /// theme sombre au lieu d'y faire une tache.
  String? _pods;
  bool _podsCherche = false;

  String? get imagePods {
    if (_podsCherche) return _pods;
    _podsCherche = true;
    for (final chemin in [
      '$racine/images/icons/2x/weight.png',
      '$racine/images/icons/1x/weight.png',
    ]) {
      if (File(chemin).existsSync()) return _pods = chemin;
    }
    return null;
  }
}
