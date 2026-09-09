/// Les equipes, leurs personnages et les touches qui les ramenent au premier
/// plan.
///
/// Un raccourci ne vise pas une fenetre mais **une liste de fragments de
/// titre**, dans l'ordre : celui dont la fenetre existe repond. C'est ce qui
/// permet a deux equipes de partager `F1` a `F4` sans se marcher dessus — on
/// change d'equipe dans le jeu, pas dans l'outil.
library;

import 'package:flutter/foundation.dart';

/// Les indicateurs `MOD_*` que `RegisterHotKey` accepte.
abstract final class Modificateur {
  static const int alt = 0x0001;
  static const int ctrl = 0x0002;
  static const int maj = 0x0004;
  static const int windows = 0x0008;
}

/// Un raccourci global, dit dans le vocabulaire de Win32 pour n'avoir aucune
/// traduction a faire avant `RegisterHotKey`.
@immutable
class Raccourci {
  const Raccourci({required this.touche, this.modificateurs = 0, this.libelle});

  /// Code de touche virtuelle (`VK_*`).
  final int touche;

  /// Masque de [Modificateur].
  final int modificateurs;

  /// Le libelle releve a la capture.
  ///
  /// Le code virtuel des touches de ponctuation depend de la disposition du
  /// clavier : on garde la touche telle que l'utilisateur l'a vue plutot que
  /// de tenter de la redeviner.
  final String? libelle;

  /// Ce qui identifie le raccourci cote natif : tous les personnages qui
  /// partagent ces touches partagent un seul enregistrement.
  String get signature => '$modificateurs:$touche';

  bool get valide => touche != 0;

  String get nom {
    final capture = libelle;
    if (capture != null && capture.isNotEmpty) return capture;
    return nomDeTouche(touche);
  }

  String get affichage => [
    if (modificateurs & Modificateur.ctrl != 0) 'Ctrl',
    if (modificateurs & Modificateur.alt != 0) 'Alt',
    if (modificateurs & Modificateur.maj != 0) 'Maj',
    if (modificateurs & Modificateur.windows != 0) 'Win',
    nom,
  ].join(' + ');

  Map<String, Object?> versJson() => {
    'key_code': touche,
    'modifiers': modificateurs,
    if (libelle != null) 'key_name': libelle,
  };

  static Raccourci? depuisJson(Object? json) {
    if (json is! Map) return null;
    final touche = json['key_code'];
    if (touche is! int || touche == 0) return null;
    final mods = json['modifiers'];
    final nom = json['key_name'];
    return Raccourci(
      touche: touche,
      modificateurs: mods is int ? mods : 0,
      libelle: nom is String && nom.isNotEmpty ? nom : null,
    );
  }

  /// L'egalite ignore le libelle : ce qui identifie un raccourci est ce qui
  /// s'enregistre dans Windows.
  @override
  bool operator ==(Object other) =>
      other is Raccourci &&
      other.touche == touche &&
      other.modificateurs == modificateurs;

  @override
  int get hashCode => Object.hash(touche, modificateurs);

  @override
  String toString() => affichage;
}

/// Le nom lisible d'un code de touche virtuelle.
String nomDeTouche(int touche) {
  if (touche >= 0x70 && touche <= 0x87) return 'F${touche - 0x6F}';
  if (touche >= 0x60 && touche <= 0x69) return 'Num ${touche - 0x60}';
  if ((touche >= 0x41 && touche <= 0x5A) || (touche >= 0x30 && touche <= 0x39)) {
    return String.fromCharCode(touche);
  }
  return _nomsFixes[touche] ?? 'Touche $touche';
}

const Map<int, String> _nomsFixes = {
  0x08: 'Retour',
  0x09: 'Tab',
  0x0D: 'Entrée',
  0x13: 'Pause',
  0x14: 'Verr maj',
  0x1B: 'Échap',
  0x20: 'Espace',
  0x21: 'Page haut',
  0x22: 'Page bas',
  0x23: 'Fin',
  0x24: 'Début',
  0x25: 'Gauche',
  0x26: 'Haut',
  0x27: 'Droite',
  0x28: 'Bas',
  0x2C: 'Impr écran',
  0x2D: 'Inser',
  0x2E: 'Suppr',
  0x5D: 'Menu',
  0x6A: 'Num *',
  0x6B: 'Num +',
  0x6D: 'Num -',
  0x6E: 'Num .',
  0x6F: 'Num /',
  0x90: 'Verr num',
  0x91: 'Arrêt défil',
};

/// Un client identifie par un fragment de son titre de fenetre.
@immutable
class PersonnageOrganizer {
  const PersonnageOrganizer({
    required this.id,
    required this.nom,
    required this.titre,
    this.raccourci,
    this.classe,
    this.feminin = false,
    this.actif = true,
  });

  final String id;

  /// Nom affiche, libre.
  final String nom;

  /// Ce qu'on cherche dans les titres de fenetres, sans tenir compte de la
  /// casse.
  final String titre;

  final Raccourci? raccourci;

  /// Identifiant de classe, tel que le jeu les numerote — le meme que celui
  /// du suivi, si bien que le nom et le portrait se prennent aux memes
  /// ressources. Nul quand le personnage n'en porte pas.
  final int? classe;

  /// Le sexe du personnage, qui choisit entre les deux portraits.
  ///
  /// Le suivi s'en passe : le reseau ne le dit pas. Ici, c'est l'utilisateur
  /// qui decrit ses propres personnages.
  final bool feminin;

  /// Le personnage entre-t-il dans la resolution ? Il faut aussi que son
  /// equipe soit active.
  final bool actif;

  bool get lie => raccourci?.valide ?? false;

  PersonnageOrganizer copie({
    String? nom,
    String? titre,
    Raccourci? raccourci,
    bool effaceRaccourci = false,
    int? classe,
    bool effaceClasse = false,
    bool? feminin,
    bool? actif,
  }) {
    return PersonnageOrganizer(
      id: id,
      nom: nom ?? this.nom,
      titre: titre ?? this.titre,
      raccourci: effaceRaccourci ? null : (raccourci ?? this.raccourci),
      classe: effaceClasse ? null : (classe ?? this.classe),
      feminin: feminin ?? this.feminin,
      actif: actif ?? this.actif,
    );
  }

  Map<String, Object?> versJson() => {
    'id': id,
    'name': nom,
    'window_title': titre,
    'enabled': actif,
    if (classe != null) 'class_id': classe,
    if (classe != null) 'female': feminin,
    if (raccourci != null) 'shortcut': raccourci!.versJson(),
  };

  static PersonnageOrganizer? depuisJson(Object? json) {
    if (json is! Map) return null;
    final id = json['id'];
    final nom = json['name'];
    if (id is! String || id.isEmpty || nom is! String) return null;
    final titre = json['window_title'];
    final classe = json['class_id'];
    return PersonnageOrganizer(
      id: id,
      nom: nom,
      titre: titre is String && titre.isNotEmpty ? titre : nom,
      classe: classe is int ? classe : null,
      feminin: json['female'] is bool ? json['female'] as bool : false,
      raccourci: Raccourci.depuisJson(json['shortcut']),
      actif: json['enabled'] is bool ? json['enabled'] as bool : true,
    );
  }
}

/// Une equipe : de quoi ecarter d'un coup les personnages qu'on ne joue pas.
@immutable
class EquipeOrganizer {
  const EquipeOrganizer({
    required this.id,
    required this.nom,
    this.personnages = const [],
    this.active = true,
    this.replie = false,
  });

  final String id;
  final String nom;
  final List<PersonnageOrganizer> personnages;
  final bool active;

  /// L'equipe est refermee sur son en-tete. Purement visuel : replier n'ecarte
  /// rien, les raccourcis d'une equipe fermee repondent toujours.
  final bool replie;

  /// Ceux qui entrent vraiment dans la resolution.
  Iterable<PersonnageOrganizer> get vivants =>
      active ? personnages.where((p) => p.actif && p.lie) : const [];

  EquipeOrganizer copie({
    String? nom,
    List<PersonnageOrganizer>? personnages,
    bool? active,
    bool? replie,
  }) {
    return EquipeOrganizer(
      id: id,
      nom: nom ?? this.nom,
      personnages: personnages ?? this.personnages,
      active: active ?? this.active,
      replie: replie ?? this.replie,
    );
  }

  Map<String, Object?> versJson() => {
    'id': id,
    'name': nom,
    'enabled': active,
    if (replie) 'collapsed': true,
    'characters': [for (final p in personnages) p.versJson()],
  };

  static EquipeOrganizer? depuisJson(Object? json) {
    if (json is! Map) return null;
    final id = json['id'];
    final nom = json['name'];
    if (id is! String || id.isEmpty || nom is! String) return null;
    final liste = json['characters'];
    final personnages = <PersonnageOrganizer>[];
    if (liste is List) {
      for (final entree in liste) {
        final p = PersonnageOrganizer.depuisJson(entree);
        if (p != null) personnages.add(p);
      }
    }
    return EquipeOrganizer(
      id: id,
      nom: nom,
      personnages: personnages,
      active: json['enabled'] is bool ? json['enabled'] as bool : true,
      replie: json['collapsed'] is bool ? json['collapsed'] as bool : false,
    );
  }
}

/// Lit la liste des equipes telle qu'elle est rangee dans les reglages.
List<EquipeOrganizer> equipesDepuisJson(Object? json) {
  if (json is! List) return const [];
  final equipes = <EquipeOrganizer>[];
  for (final entree in json) {
    final equipe = EquipeOrganizer.depuisJson(entree);
    if (equipe != null) equipes.add(equipe);
  }
  return equipes;
}
