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
  const MiseAJour({required this.version, required this.adresse});

  /// Le numero, sans le `v` du tag.
  final String version;

  /// La page de la release, ou l'on prend l'archive.
  final String adresse;
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
    return MiseAJour(
      version: publiee,
      adresse: '${objet['html_url'] ?? 'https://github.com/Faeeth/DTracker/releases'}',
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
