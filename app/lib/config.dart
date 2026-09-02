/// Reglages du suivi, conserves entre deux lancements.
///
/// Le fichier vit a cote du programme et reste lisible a la main : c'est un
/// outil personnel, pas une application distribuee, et pouvoir corriger un
/// reglage dans un editeur vaut mieux qu'un format opaque.
///
/// Encore faut-il que la retouche survive. L'ecriture ne touche donc qu'aux
/// reglages que le programme a lui-meme changes, en comparant a trois : l'etat
/// lu au demarrage, le sien, et celui du disque. Sans quoi une modification
/// faite pendant que la fenetre est ouverte disparait en la fermant, sans un
/// mot — c'est arrive.
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter/widgets.dart' show Size;

/// Le texte ne descend pas sous ce seuil : en dessous il devient illisible sur
/// un fond clair, et l'outil n'aurait plus d'usage.
const int opaciteTexteMin = 20;

/// La version, telle qu'elle s'affiche et telle qu'on la compare.
///
/// Posee a la construction — `--dart-define=DTRACKER_VERSION=1.0.0`, ce que
/// fait le workflow depuis le tag. Depuis les sources elle vaut `dev` : c'est
/// aussi ce qui empeche une version de developpement de se croire en retard
/// sur la derniere publiee.
const versionApp = String.fromEnvironment(
  'DTRACKER_VERSION',
  defaultValue: 'dev',
);

/// Taille minimale de chaque vue.
///
/// Elles ne se confondent pas. La vue compacte tient dans une bande etroite :
/// c'est tout son interet, et ses boutons sont serres pour cela. La vue
/// standard aere ses colonnes et affiche un nom de personnage entier — sous
/// une certaine largeur, sa rangee deborde, ce qui n'est pas un defaut
/// d'apparence mais une erreur de rendu.
///
/// Ces valeurs sont posees comme minimum de la fenetre au moment ou l'on
/// change de vue, et servent de bornes aux tailles conservees.
/// Seule la largeur y fait plancher.
///
/// La hauteur de la vue compacte suit son contenu : un personnage tient en
/// cent-vingt pixels, huit en trois cents. Un plancher fixe a cent-quatre-
/// vingts laissait, pour un seul personnage, l'equivalent de deux lignes de
/// vide entre lui et ses totaux — Windows refusant de rapetisser la fenetre
/// en deca. La hauteur donnee ici ne sert donc qu'au tout premier passage,
/// avant que le contenu ne soit connu.
const Size tailleMiniCompacte = Size(500, 90);
// 224 pixels pour le rail, une quarantaine pour les marges et l'ascenseur, et
// le tableau en demande environ 760 : sous cette largeur, la rangee deborde.
const Size tailleMiniStandard = Size(1040, 560);

class Config {
  Config({
    this.personnages = const [],
    this.interface = '',
    this.opaciteFond = 55,
    this.opaciteTexte = 95,
    this.toujoursDevant = true,
    this.journalVisible = true,
    this.x = 80,
    this.y = 80,
    this.largeur = 540,
    this.largeurStandard = 1100,
    this.hauteurStandard = 680,
    this.compact = false,
    this.verrouille = false,
    this.succesComptes = true,
    this.langue = 'fr',
    this.versionVue = '',
  });

  List<String> personnages;
  String interface; // interface de capture ; vide = detection
  int opaciteFond; // de 0 a 100
  int opaciteTexte; // de opaciteTexteMin a 100

  bool toujoursDevant;
  bool journalVisible;
  double x;
  double y;

  /// Largeur de la vue compacte. Sa hauteur se cale sur son contenu.
  double largeur;

  /// La vue standard, elle, se dimensionne comme une fenetre ordinaire : on la
  /// redimensionne a la souris et sa taille est conservee.
  double largeurStandard;
  double hauteurStandard;

  /// Vue compacte ou vue standard.
  bool compact;

  /// Les succes entrent-ils dans les totaux de la session ?
  bool succesComptes;

  /// Code ISO de la langue de l'interface : `fr`, `en`, `es`, `pt`.
  String langue;

  /// Le numero de version dont les nouveautes ont deja ete annoncees.
  ///
  /// C'est ce qui fait que la fenetre des nouveautes s'ouvre une fois et pas
  /// deux. Vide au tout premier lancement, ce qui la montre : quelqu'un qui
  /// installe l'outil apprend au passage ce qu'il vient de recevoir, et
  /// quelqu'un qui l'avait deja voit enfin ce qu'il a manque.
  String versionVue;

  /// La vue compacte est-elle clouee sur place ?
  ///
  /// Deverrouillee, toute la fenetre se saisit a la souris — c'est pratique
  /// pour la poser, genant quand on la deplace sans le vouloir en visant un
  /// bouton. Le cadenas tranche, et se voit.
  bool verrouille;

  /// Etat lu au demarrage, pour ne reecrire que ce qu'on aura change.
  Map<String, dynamic> _origine = {};

  static File fichier(String racine) => File('$racine/settings.json');

  Map<String, dynamic> versJson() => {
    'characters': personnages,
    'interface': interface,
    'background_opacity': opaciteFond,
    'text_opacity': opaciteTexte,
    'always_on_top': toujoursDevant,
    'show_journal': journalVisible,
    'window_x': x,
    'window_y': y,
    'window_width': largeur,
    'standard_width': largeurStandard,
    'standard_height': hauteurStandard,
    'compact_view': compact,
    'locked': verrouille,
    'count_achievements': succesComptes,
    'language': langue,
    'seen_version': versionVue,
  };

  /// Ramene les valeurs dans leurs bornes, un fichier edite a la main pouvant
  /// contenir n'importe quoi.
  void borne() {
    opaciteTexte = opaciteTexte.clamp(opaciteTexteMin, 100);
    // Le fond ne depasse pas le texte. Ce n'est pas un caprice : la fenetre
    // porte l'opacite du texte et le fond est peint dessous, si bien qu'un
    // fond plus opaque que le texte est physiquement hors d'atteinte. Le
    // borner ici vaut mieux que de le laisser demander l'impossible et rendre
    // autre chose.
    opaciteFond = opaciteFond.clamp(0, opaciteTexte);
    // Une fenetre plus petite que cela deborde, et une taille aberrante venue
    // d'un fichier edite a la main la rendrait introuvable a l'ecran.
    largeurStandard = largeurStandard.clamp(tailleMiniStandard.width, 4000);
    hauteurStandard = hauteurStandard.clamp(tailleMiniStandard.height, 3000);
    largeur = largeur.clamp(tailleMiniCompacte.width, 4000);
    final vus = <String>{};
    personnages = [
      for (final nom in personnages)
        if (nom.trim().isNotEmpty && vus.add(nom.trim().toLowerCase()))
          nom.trim(),
    ];
  }

  static Future<Config> charge(String racine) async {
    Map<String, dynamic> donnees = {};
    try {
      final f = fichier(racine);
      if (await f.exists()) {
        final objet = jsonDecode(await f.readAsString());
        if (objet is Map<String, dynamic>) donnees = objet;
      }
    } on Exception {
      // Fichier illisible : on repart des valeurs par defaut.
    }
    final config = Config(
      personnages: [for (final n in donnees['characters'] as List? ?? []) '$n'],
      interface: '${donnees['interface'] ?? ''}',
      opaciteFond: (donnees['background_opacity'] as num?)?.toInt() ?? 55,
      opaciteTexte: (donnees['text_opacity'] as num?)?.toInt() ?? 95,
      toujoursDevant: donnees['always_on_top'] as bool? ?? true,
      journalVisible: donnees['show_journal'] as bool? ?? true,
      x: (donnees['window_x'] as num?)?.toDouble() ?? 80,
      y: (donnees['window_y'] as num?)?.toDouble() ?? 80,
      largeur: (donnees['window_width'] as num?)?.toDouble() ?? 540,
      largeurStandard: (donnees['standard_width'] as num?)?.toDouble() ?? 1100,
      hauteurStandard: (donnees['standard_height'] as num?)?.toDouble() ?? 680,
      compact: donnees['compact_view'] as bool? ?? false,
      verrouille: donnees['locked'] as bool? ?? false,
      succesComptes: donnees['count_achievements'] as bool? ?? true,
      langue: '${donnees['language'] ?? 'fr'}',
      versionVue: '${donnees['seen_version'] ?? ''}',
    )..borne();
    config._origine = Map.of(config.versJson());
    return config;
  }

  /// Ecrit les reglages en ne touchant qu'a ce que ce programme a change.
  ///
  /// On compare a trois : l'etat lu au demarrage, le notre, et celui du
  /// disque. Un reglage que nous n'avons pas touche garde la valeur du disque ;
  /// les autres passent. Les cles inconnues — reglage d'une version plus
  /// recente — sont conservees.
  Future<void> enregistre(String racine) async {
    final courant = versJson();
    Map<String, dynamic> disque = {};
    try {
      final f = fichier(racine);
      if (await f.exists()) {
        final objet = jsonDecode(await f.readAsString());
        if (objet is Map<String, dynamic>) disque = objet;
      }
    } on Exception {
      // Illisible : notre etat fera foi.
    }

    final fusion = Map<String, dynamic>.of(disque);
    courant.forEach((cle, valeur) {
      final inconnue = !disque.containsKey(cle) || !_origine.containsKey(cle);
      if (inconnue || !_egal(valeur, _origine[cle])) fusion[cle] = valeur;
    });

    try {
      await fichier(racine)
          .writeAsString(const JsonEncoder.withIndent('  ').convert(fusion));
      _origine = fusion;
    } on Exception {
      // Disque en lecture seule : on ne perd qu'un reglage, pas la session.
    }
  }

  static bool _egal(dynamic a, dynamic b) {
    if (a is List && b is List) {
      return a.length == b.length &&
          List.generate(
            a.length,
            (i) => '${a[i]}' == '${b[i]}',
          ).every((x) => x);
    }
    return a == b;
  }
}
