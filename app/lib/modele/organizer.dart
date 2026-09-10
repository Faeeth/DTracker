/// Les equipes, leurs personnages et les touches qui les ramenent au premier
/// plan.
///
/// Un raccourci ne vise pas une fenetre mais **une liste de fragments de
/// titre**, dans l'ordre : celui dont la fenetre existe repond. C'est ce qui
/// permet a deux equipes de partager `F1` a `F4` sans se marcher dessus — on
/// change d'equipe dans le jeu, pas dans l'outil.
library;

import 'package:flutter/foundation.dart';

import 'raccourci.dart';

// Le raccourci fait partie de ce qu'un personnage expose : qui lit une equipe
// le lit aussi, et n'a pas a savoir dans quel fichier il a ete range.
export 'raccourci.dart';

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
