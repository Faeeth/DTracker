/// Tire du client du jeu les noms et les images.
///
/// Ils ne sont pas livres avec l'outil et ne peuvent pas l'etre : ce sont les
/// fichiers d'Ankama. La seule voie qui tienne est de les prendre dans le
/// client installe sur la machine — ce que fait la diffusion, appelee ici avec
/// `--extraire`.
///
/// Deux minutes environ, et deux cent soixante-cinq mega-octets. C'est long,
/// donc ca se montre : chaque etape que la diffusion annonce remonte ici.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'emplacements.dart';

/// Ou en est l'extraction.
enum EtapeExtraction {
  /// Rien n'a commence.
  attente,

  /// Le client du jeu est cherche.
  recherche,

  /// Les noms, les tables, les images.
  travail,

  /// Fini, et les fichiers sont la.
  faite,

  /// Le dossier `Dofus_Data` n'a pas ete trouve.
  clientIntrouvable,

  /// Autre chose s'est mal passe.
  echec,
}

/// L'avancement, tel qu'il s'affiche.
class Avancement {
  const Avancement(this.etape, [this.detail = '']);

  final EtapeExtraction etape;

  /// La derniere ligne annoncee par la diffusion, telle quelle.
  final String detail;
}

/// Les donnees du jeu sont-elles deja la ?
///
/// On regarde ce dont l'affichage se sert vraiment, et non la seule presence
/// du dossier : une extraction interrompue laisse un dossier a moitie rempli,
/// qui donnerait des noms sans images.
bool donneesPresentes(String racine) =>
    File('$racine/labels/items.json').existsSync() &&
    File('$racine/icons/items.json').existsSync() &&
    File('$racine/images/item/2x/index.json').existsSync();

/// Lance l'extraction et rend son avancement au fil de l'eau.
///
/// Le flux se ferme sur [EtapeExtraction.faite] ou sur un echec. L'appelant
/// n'a rien a arreter : la diffusion se termine d'elle-meme.
Stream<Avancement> extrait(Emplacements ou, {String? client}) async* {
  yield const Avancement(EtapeExtraction.recherche);

  final gelee = File(ou.diffusion).existsSync();
  final Process processus;
  try {
    processus = await Process.start(
      gelee ? ou.diffusion : 'python',
      [
        if (!gelee) ...['tools/_lanceur_capture.py'],
        '--extraire',
        ou.ressources,
        ?client,
      ],
      workingDirectory: ou.programme,
    );
  } on ProcessException catch (e) {
    yield Avancement(EtapeExtraction.echec, e.message);
    return;
  }

  // La diffusion prefixe chaque diagnostic d'un `#`, et nomme ses ennuis
  // d'un mot convenu : on les reconnait a ce mot plutot qu'a une phrase.
  final lignes = processus.stderr
      .transform(utf8.decoder)
      .transform(const LineSplitter());
  var dernier = const Avancement(EtapeExtraction.travail);
  await for (final ligne in lignes) {
    final texte = ligne.replaceFirst(RegExp(r'^#\s*'), '').trim();
    if (texte.isEmpty) continue;
    if (texte.startsWith('client-introuvable')) {
      dernier = Avancement(EtapeExtraction.clientIntrouvable, texte);
    } else if (texte.contains('-en-echec') ||
        texte.startsWith('extraction-impossible')) {
      dernier = Avancement(EtapeExtraction.echec, texte);
    } else if (texte.startsWith('extraction-terminee')) {
      dernier = const Avancement(EtapeExtraction.faite);
    } else if (texte.startsWith('etape ')) {
      dernier = Avancement(EtapeExtraction.travail, texte);
    } else {
      continue;
    }
    yield dernier;
  }
  final code = await processus.exitCode;
  if (dernier.etape != EtapeExtraction.faite) {
    yield Avancement(
      dernier.etape == EtapeExtraction.travail
          ? EtapeExtraction.echec
          : dernier.etape,
      dernier.detail.isEmpty ? 'code $code' : dernier.detail,
    );
  }
}
