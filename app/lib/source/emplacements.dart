/// Ou vivent les fichiers, selon la facon dont l'outil a ete lance.
///
/// Trois choses n'ont pas le meme cycle de vie et ne peuvent pas partager un
/// dossier :
///
/// - **Ce que l'utilisateur produit** — reglages, cache, sessions. Ca doit
///   survivre a une mise a jour, et un installateur ne doit jamais y toucher.
/// - **Ce que le programme embarque** — la diffusion de capture, gelee en
///   executable. Remplacee a chaque version.
/// - **Ce qui est extrait du client du jeu** — noms d'objets, images. Ca ne
///   peut pas etre redistribue : c'est le contenu d'Ankama, et il faut le
///   tirer du client installe sur la machine.
///
/// Jusqu'ici les trois vivaient a cote du projet, ce qui allait tant que
/// l'outil ne quittait pas la machine ou il a ete ecrit. Installe dans
/// `Program Files`, il n'aurait meme pas le droit d'y ecrire ses reglages.
library;

import 'dart:io';

/// Le nom du dossier de l'application dans les donnees de l'utilisateur.
const marque = 'DTracker';

/// Emplacements retenus pour cette execution.
class Emplacements {
  const Emplacements({
    required this.donnees,
    required this.programme,
    required this.installe,
  });

  /// Ce que l'utilisateur produit : reglages, cache, sessions.
  ///
  /// `%APPDATA%\DTracker` pour une version installee. Un installateur n'y
  /// touche pas, une desinstallation peut le laisser en place, et une mise a
  /// jour ne peut pas l'ecraser.
  final String donnees;

  /// Ce que le programme embarque : la diffusion de capture, les donnees
  /// extraites du jeu.
  final String programme;

  /// Vrai quand l'outil tourne depuis une installation, faux quand il tourne
  /// depuis les sources.
  ///
  /// La difference tient a un fichier : `pubspec.yaml` a cote de
  /// l'executable, ou au-dessus, veut dire qu'on est en developpement.
  final bool installe;

  String get sessions => '$donnees/sessions';
  String get cache => '$donnees/cache.json';

  /// Les donnees extraites du jeu.
  ///
  /// Dans le dossier de l'utilisateur meme pour une version installee : c'est
  /// lui qui les extrait de son client, elles ne viennent pas avec le
  /// programme et ne doivent pas disparaitre a la mise a jour suivante.
  String get ressources => installe ? '$donnees/data' : '$programme/data';

  /// La diffusion de capture. Gelee a cote de l'executable une fois
  /// installee ; lancee par Python depuis les sources.
  String get diffusion => '$programme/dtracker-capture.exe';

  /// Reconnait la situation et rend les emplacements qui vont avec.
  static Emplacements reconnait() {
    final exe = Directory(Platform.resolvedExecutable).parent;
    final sources = _enRemontant(
      exe,
      (d) => File('${d.path}/pubspec.yaml').existsSync(),
    );
    if (sources != null) {
      // Depuis les sources : tout reste dans le projet, comme avant. On ne
      // veut pas d'un aller-retour vers `%APPDATA%` pendant la mise au point,
      // ni voir les sessions de test se meler aux vraies.
      final lib =
          _enRemontant(
            exe,
            (d) => Directory('${d.path}/dofus_stats').existsSync(),
          ) ??
          sources;
      return Emplacements(
        donnees: sources,
        programme: '$lib/dofus_stats',
        installe: false,
      );
    }
    return Emplacements(
      donnees: _dossierUtilisateur(),
      programme: exe.path,
      installe: true,
    );
  }

  /// `%APPDATA%\DTracker`, ou son equivalent ailleurs.
  ///
  /// `APPDATA` plutot que `LOCALAPPDATA` : ce sont des reglages et un
  /// historique, pas un cache jetable — sur un profil itinerant, ils suivent
  /// l'utilisateur.
  static String _dossierUtilisateur() {
    final env = Platform.environment;
    for (final clef in ['APPDATA', 'XDG_CONFIG_HOME', 'HOME']) {
      final base = env[clef];
      if (base != null && base.isNotEmpty) {
        final suffixe = clef == 'HOME' ? '/.config' : '';
        return '$base$suffixe/$marque'.replaceAll(r'\', '/');
      }
    }
    // Aucun dossier personnel : plutot que d'echouer, on ecrit a cote de
    // l'executable. Une installation par utilisateur y a droit.
    return Directory(Platform.resolvedExecutable).parent.path;
  }

  static String? _enRemontant(Directory depart, bool Function(Directory) test) {
    var dossier = depart;
    for (var i = 0; i < 8; i++) {
      if (test(dossier)) return dossier.path;
      final parent = dossier.parent;
      if (parent.path == dossier.path) break;
      dossier = parent;
    }
    return null;
  }

  /// Cree ce qui manque, et reprend ce qu'une version precedente avait laisse.
  ///
  /// La reprise ne recopie que ce qui n'existe pas encore : relancer apres
  /// avoir joue ne doit pas revenir a l'etat d'avant la migration.
  Future<void> prepare({List<String> reprises = const []}) async {
    await Directory(donnees).create(recursive: true);
    await Directory(sessions).create(recursive: true);
    for (final ancien in reprises) {
      await _reprend(ancien);
    }
  }

  Future<void> _reprend(String ancien) async {
    final source = Directory(ancien);
    if (!await source.exists()) return;
    for (final nom in ['settings.json', 'cache.json']) {
      final avant = File('$ancien/$nom');
      final apres = File('$donnees/$nom');
      if (await avant.exists() && !await apres.exists()) {
        await avant.copy(apres.path);
      }
    }
    final anciennes = Directory('$ancien/sessions');
    if (!await anciennes.exists()) return;
    await for (final entree in anciennes.list()) {
      if (entree is! File) continue;
      final cible = File('$sessions/${entree.uri.pathSegments.last}');
      if (!await cible.exists()) await entree.copy(cible.path);
    }
  }
}
