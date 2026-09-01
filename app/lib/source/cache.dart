/// Ce que le suivi retient d'une session a l'autre.
///
/// La bibliotheque ne conserve rien : elle rend ce qu'elle lit et laisse a
/// l'appelant le soin de garder ce qui merite de l'etre. C'est ici que ce
/// choix se paie, et ici qu'on l'assume.
///
/// Deux tables, chacune pour une raison precise :
///
///   - **classes** — elles n'arrivent qu'avec la description d'une entite sur
///     la carte. Une soiree passee en donjon d'un bout a l'autre ne les verrait
///     jamais, et les portraits resteraient vides ;
///   - **prix** — diffuses en une fois a la connexion ou a l'ouverture d'une
///     interface marchande. Sans eux, le butin des premiers combats ne peut pas
///     etre valorise, et il faudrait attendre la table pour tout rattraper.
///
/// Le fichier reste lisible a la main, comme les reglages. Il porte les memes
/// noms de cles que celui de la version Python, dont il peut donc reprendre le
/// contenu : ce qu'elle a appris n'est pas perdu.
library;

import 'dart:convert';
import 'dart:io';

class Cache {
  Cache(this.chemin);

  final String chemin;

  /// Nom de personnage -> classe.
  final Map<String, int> classes = {};

  /// Type d'objet -> prix moyen.
  final Map<int, int> prix = {};

  bool _modifie = false;

  File get _fichier => File(chemin);

  /// Relit le cache, ou celui d'un ancien emplacement s'il est vide.
  ///
  /// La reprise sert une fois : au premier lancement apres la bascule vers
  /// cette application, elle evite de repartir aveugle alors que la version
  /// precedente savait deja tout.
  Future<void> charge({List<String> reprises = const []}) async {
    if (await _lit(chemin)) return;
    for (final ancien in reprises) {
      if (await _lit(ancien)) {
        _modifie = true; // pour le recopier a notre emplacement
        return;
      }
    }
  }

  Future<bool> _lit(String ou) async {
    try {
      final fichier = File(ou);
      if (!await fichier.exists()) return false;
      final objet = jsonDecode(await fichier.readAsString());
      if (objet is! Map<String, dynamic>) return false;

      // Les classes sont indexees par identifiant dans le fichier de la
      // version Python, par nom dans le notre : les deux formes sont lues.
      final parNom = objet['breeds'] as Map<String, dynamic>? ?? {};
      parNom.forEach((nom, classe) {
        if (classe is num) classes[nom] = classe.toInt();
      });
      final noms = objet['character_names'] as Map<String, dynamic>? ?? {};
      final parIdentifiant =
          objet['character_breeds'] as Map<String, dynamic>? ?? {};
      noms.forEach((identifiant, nom) {
        final classe = parIdentifiant[identifiant];
        if (classe is num) classes['$nom'] = classe.toInt();
      });

      final tarifs = objet['prices'] as Map<String, dynamic>? ?? {};
      tarifs.forEach((item, valeur) {
        final id = int.tryParse(item);
        if (id != null && valeur is num) prix[id] = valeur.toInt();
      });
      return classes.isNotEmpty || prix.isNotEmpty;
    } on Exception {
      return false;
    }
  }

  /// Note une classe apprise. Rend vrai si elle etait inconnue.
  bool apprendClasse(String nom, int? classe) {
    if (classe == null || nom.isEmpty || classes[nom] == classe) return false;
    classes[nom] = classe;
    _modifie = true;
    return true;
  }

  /// Note une table de prix. Rend vrai si quelque chose a change.
  bool apprendPrix(Map<int, int> tarifs) {
    var change = false;
    tarifs.forEach((item, valeur) {
      if (prix[item] != valeur) {
        prix[item] = valeur;
        change = true;
      }
    });
    _modifie = _modifie || change;
    return change;
  }

  /// Ecrit le cache s'il a change depuis la derniere fois.
  ///
  /// Rien a fusionner ici, contrairement aux reglages : ce fichier n'est pas
  /// fait pour etre edite a la main, et deux instances qui captureraient en
  /// meme temps auraient un probleme plus grave que leur cache.
  Future<void> enregistre() async {
    if (!_modifie) return;
    try {
      await _fichier.writeAsString(
        const JsonEncoder.withIndent('  ').convert({
          'breeds': classes,
          'prices': {for (final e in prix.entries) '${e.key}': e.value},
        }),
      );
      _modifie = false;
    } on Exception {
      // Disque en lecture seule : on ne perd qu'un cache, pas la session.
    }
  }

  @override
  String toString() => '<Cache ${classes.length} classes, ${prix.length} prix>';
}
