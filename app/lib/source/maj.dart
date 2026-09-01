/// Y a-t-il une version plus recente que celle qui tourne ?
///
/// L'outil interroge les releases du depot au demarrage, une fois, et se tait
/// dans tous les cas sauf un : une version publiee plus recente que la sienne.
/// Pas de reseau, depot injoignable, reponse illisible, rien de neuf — on ne
/// dit rien. Un avertissement au lancement d'un outil qu'on ouvre pour jouer
/// doit se meriter.
///
/// **Le depot doit etre public.** L'API de GitHub repond 404 sur un depot
/// prive sans jeton, et un jeton embarque dans l'executable se lit en clair :
/// ce serait donner acces au depot a qui installe l'outil. Tant qu'il est
/// prive, la verification echoue donc silencieusement — exactement comme
/// lorsqu'il n'y a pas de reseau — et se mettra a fonctionner le jour ou il
/// s'ouvrira, sans rien changer ici.
library;

import 'dart:convert';
import 'dart:io';

/// Ou se demandent les releases.
const _api = 'https://api.github.com/repos/Faeeth/DTracker/releases/latest';

/// Au-dela, on renonce : le lancement ne doit pas attendre apres GitHub.
const _delai = Duration(seconds: 4);

/// Une version publiee, plus recente que la notre.
class MiseAJour {
  const MiseAJour({
    required this.version,
    required this.adresse,
    this.installateur = '',
    this.taille = 0,
  });

  /// Le numero, sans le `v` du tag.
  final String version;

  /// La page de la release, ou l'on prend l'archive a la main.
  final String adresse;

  /// L'installateur lui-meme, quand la release en porte un.
  ///
  /// C'est lui qu'on telecharge : l'archive ne contient que ce fichier et un
  /// mode d'emploi, et la decompresser pour rien ferait un detour de plus.
  final String installateur;

  /// Ce que pese l'installateur, pour montrer une progression qui avance.
  final int taille;

  bool get telechargeable => installateur.isNotEmpty;
}

/// Demande a GitHub s'il y a mieux. Rend nul si non, ou en cas de pepin.
Future<MiseAJour?> cherche({
  String courante = '',
  HttpClient? client,
  // Injectable pour les cas de test : sans cela, ils interrogeraient la
  // vraie API et passeraient pour la mauvaise raison — un depot prive
  // repondant 404, on croirait verifier le silence alors qu'on ne verifie
  // que l'etat du depot.
  String adresse = _api,
}) async {
  // Une version de developpement n'est en retard sur rien : elle est en
  // avance sur tout, et se le faire dire a chaque lancement serait penible.
  if (courante.isEmpty || courante == 'dev') return null;
  final http = client ?? HttpClient();
  http.connectionTimeout = _delai;
  try {
    final requete = await http.getUrl(Uri.parse(adresse)).timeout(_delai);
    // GitHub demande un agent ; sans lui il repond 403.
    requete.headers.set(HttpHeaders.userAgentHeader, 'DTracker/$courante');
    requete.headers.set(HttpHeaders.acceptHeader,
        'application/vnd.github+json');
    final reponse = await requete.close().timeout(_delai);
    if (reponse.statusCode != 200) return null;
    final corps = await reponse.transform(utf8.decoder).join().timeout(_delai);
    final objet = jsonDecode(corps);
    if (objet is! Map) return null;
    // Une release en brouillon ou marquee « avant-premiere » n'est pas
    // proposee : elle n'est pas encore faite pour etre installee.
    if (objet['draft'] == true || objet['prerelease'] == true) return null;
    final tag = '${objet['tag_name'] ?? ''}';
    final publiee = tag.startsWith('v') ? tag.substring(1) : tag;
    if (publiee.isEmpty || !plusRecente(publiee, courante)) return null;
    // L'installateur parmi les fichiers joints. Une release qui n'en porte
    // pas reste proposee : on renverra alors vers sa page.
    var installateur = '';
    var taille = 0;
    for (final joint in objet['assets'] as List? ?? []) {
      if (joint is! Map) continue;
      final nom = '${joint['name'] ?? ''}';
      if (nom.endsWith('.exe') && nom.contains('installateur')) {
        installateur = '${joint['browser_download_url'] ?? ''}';
        taille = (joint['size'] as num?)?.toInt() ?? 0;
        break;
      }
    }
    return MiseAJour(
      version: publiee,
      adresse:
          '${objet['html_url'] ?? 'https://github.com/Faeeth/DTracker/releases'}',
      installateur: installateur,
      taille: taille,
    );
  } on Exception {
    return null;
  } finally {
    if (client == null) http.close(force: true);
  }
}

/// `a` est-elle plus recente que `b` ?
///
/// Nombre a nombre, et non par ordre alphabetique : `1.0.10` vient apres
/// `1.0.9`, ce qu'une comparaison de chaines dit exactement a l'envers.
///
/// Un suffixe — `1.1.0-beta` — est ecarte avant comparaison : il ne sert qu'a
/// nommer, et `beta` ne se compare a rien.
bool plusRecente(String a, String b) {
  List<int> parts(String v) => v
      .split('-')
      .first
      .split('.')
      .map((n) => int.tryParse(n.trim()) ?? 0)
      .toList();
  final x = parts(a);
  final y = parts(b);
  for (var i = 0; i < 3; i++) {
    final ai = i < x.length ? x[i] : 0;
    final bi = i < y.length ? y[i] : 0;
    if (ai != bi) return ai > bi;
  }
  return false;
}

/// Telecharge l'installateur et rend l'avancement, de 0 a 1.
///
/// Le fichier va dans le dossier temporaire du systeme : Windows le nettoie
/// tout seul, et personne n'a a se souvenir de l'effacer.
///
/// Rend le chemin du fichier a la fin, ou nul si quelque chose a echoue —
/// auquel cas l'appelant renvoie vers la page, qui marche toujours.
Stream<double> telecharge(MiseAJour maj, void Function(String?) fini) async* {
  final http = HttpClient();
  File? sortie;
  try {
    final cible = File(
      '${Directory.systemTemp.path}/DTracker-${maj.version}-installateur.exe',
    );
    var requete = await http.getUrl(Uri.parse(maj.installateur));
    requete.headers.set(HttpHeaders.userAgentHeader, 'DTracker/${maj.version}');
    var reponse = await requete.close();
    // GitHub sert ses fichiers depuis un autre domaine : la redirection se
    // suit a la main, `HttpClient` ne la franchit pas seule quand elle change
    // d'hote.
    var sauts = 0;
    while (reponse.isRedirect && sauts < 5) {
      final vers = reponse.headers.value(HttpHeaders.locationHeader);
      if (vers == null) break;
      await reponse.drain<void>();
      requete = await http.getUrl(Uri.parse(vers));
      requete.headers.set(HttpHeaders.userAgentHeader, 'DTracker');
      reponse = await requete.close();
      sauts++;
    }
    if (reponse.statusCode != 200) {
      fini(null);
      return;
    }
    final total = reponse.contentLength > 0 ? reponse.contentLength : maj.taille;
    final flux = cible.openWrite();
    var recu = 0;
    var dernier = 0.0;
    await for (final morceau in reponse) {
      flux.add(morceau);
      recu += morceau.length;
      final part = total > 0 ? (recu / total).clamp(0.0, 1.0) : 0.0;
      // Un pour cent a la fois : rendre la main a chaque paquet ferait
      // repeindre la fenetre des centaines de fois pour rien.
      if (part - dernier >= 0.01 || part >= 1) {
        dernier = part;
        yield part;
      }
    }
    await flux.close();
    sortie = cible;
  } on Exception {
    sortie = null;
  } finally {
    http.close(force: true);
    fini(sortie?.path);
  }
}

/// Lance l'installateur et rend la main tout de suite.
///
/// `/SILENT` montre la progression sans les pages de l'assistant : une mise a
/// jour n'a rien a demander qu'on n'ait deja demande.
///
/// `/CLOSEAPPLICATIONS` laisse l'installateur fermer ce qui tient encore les
/// fichiers. L'appelant se ferme juste apres, mais l'ordre exact des deux ne
/// se controle pas : mieux vaut que l'installateur sache le faire aussi.
///
/// Detache, sans quoi il mourrait avec l'application qui vient de le lancer.
Future<bool> lanceInstallateur(String chemin) async {
  try {
    await Process.start(
      chemin,
      ['/SILENT', '/CLOSEAPPLICATIONS', '/NORESTART'],
      mode: ProcessStartMode.detached,
    );
    return true;
  } on Exception {
    return false;
  }
}
