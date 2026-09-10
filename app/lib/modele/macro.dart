/// Une macro : une suite de gestes qu'une touche declenche.
///
/// Cinq gestes : ecrire du texte, appuyer sur une touche, cliquer, attendre,
/// et repeter. C'est ce qu'on ecrivait jusqu'ici en AutoHotkey pour jouer
/// plusieurs clients — inviter son groupe, changer de canal, repeter une
/// commande sur chacun.
///
/// Une macro porte aussi des **variables** : un nom, une ou plusieurs valeurs.
/// Une boucle les parcourt, et `{nom}` vaut alors la valeur du tour. C'est ce
/// qui remplace la liste `NomsAInviter` d'un script.
///
/// Hors d'une boucle, `{nom}` n'est pas remplace : c'est du texte, et c'est du
/// texte qui part. Substituer partout aurait fait d'une accolade un caractere
/// qu'on ne peut plus taper, alors que le jeu en accepte.
///
/// Il n'y a toujours ni condition, ni calcul, ni imbrication de portees : ce
/// n'est pas un langage, et le jour ou il en faudrait un, c'est qu'on ne fait
/// plus la meme chose.
///
/// Une macro peut viser un personnage. Sa fenetre passe alors devant avant que
/// le premier geste parte, faute de quoi la suite s'ecrirait dans la fenetre
/// qui se trouvait la — un navigateur, ou un autre client.
library;

import 'package:flutter/foundation.dart';

import 'raccourci.dart';

/// Ce qu'une macro sait faire.
///
/// Scellee : l'affichage, l'ecriture dans les reglages et l'execution
/// traitent les trois cas, et le compilateur signale celui qu'on aurait
/// oublie en ajoutant un quatrieme.
@immutable
sealed class Etape {
  const Etape();

  Map<String, Object?> versJson();

  static Etape? depuisJson(Object? json) {
    if (json is! Map) return null;
    return switch (json['type']) {
      'text' => EtapeTexte(
        json['text'] is String ? json['text'] as String : '',
        cadence: json['pace'] is int
            ? (json['pace'] as int).clamp(1, 500)
            : EtapeTexte.cadenceParDefaut,
      ),
      'key' => EtapeTouche(
        Raccourci.depuisJson(json['key']) ?? const Raccourci(touche: 0x0D),
      ),
      'sleep' => EtapePause(
        json['ms'] is int ? (json['ms'] as int).clamp(0, 60000) : 100,
      ),
      'click' => EtapeClic(
        json['x'] is int ? json['x'] as int : 0,
        json['y'] is int ? json['y'] as int : 0,
        droit: json['right'] is bool ? json['right'] as bool : false,
      ),
      'window' => EtapeFenetre(
        json['title'] is String ? json['title'] as String : '',
      ),
      'loop' => EtapeBoucle(
        etapes: etapesDepuisJson(json['steps']),
        repetitions: json['times'] is int
            ? (json['times'] as int).clamp(1, 1000)
            : 2,
        liste: json['each'] is String ? json['each'] as String : '',
      ),
      _ => null,
    };
  }
}

/// Du texte, ecrit lettre a lettre.
///
/// Le caractere voyage dans le message et non dans un code de touche : le
/// texte arrive donc identique quelle que soit la disposition du clavier, ce
/// qui n'est pas vrai d'un `a` envoye comme touche a qui joue en azerty.
///
/// Le collage a existe ici, et n'existe plus : le presse-papiers puis
/// `WM_PASTE` ecrivait parfaitement dans une fenetre ordinaire et n'ecrivait
/// **rien** dans le jeu, qui dessine son tchat lui-meme et laisse le message
/// tomber. Une option qui echoue en silence dans le seul cas qui compte vaut
/// moins que pas d'option.
class EtapeTexte extends Etape {
  const EtapeTexte(this.texte, {this.cadence = cadenceParDefaut});

  /// Le temps entre deux lettres, en millisecondes.
  ///
  /// Trois rythmes, et rien entre les deux.
  ///
  /// Un nombre libre demandait a l'utilisateur de deviner ce qu'il ne peut pas
  /// savoir : la vitesse a laquelle la fenetre d'en face absorbe une frappe.
  /// Trois choix nommes disent ce qu'ils font, et couvrent ce qu'on a
  /// rencontre — du tchat qui suit sans broncher a celui qui perd une lettre
  /// sur deux.
  static const int cadenceRapide = 20;
  static const int cadenceNormale = 30;
  static const int cadenceLente = 50;

  static const int cadenceParDefaut = cadenceNormale;

  /// Les trois, du plus lent au plus rapide : c'est l'ordre d'une barre qu'on
  /// pousse.
  static const List<int> cadences = [
    cadenceLente,
    cadenceNormale,
    cadenceRapide,
  ];

  final String texte;
  final int cadence;

  @override
  Map<String, Object?> versJson() => {
    'type': 'text',
    'text': texte,
    if (cadence != cadenceParDefaut) 'pace': cadence,
  };

  @override
  bool operator ==(Object other) =>
      other is EtapeTexte && other.texte == texte && other.cadence == cadence;

  @override
  int get hashCode => Object.hash(texte, cadence);
}

/// Une touche, avec ses modificateurs.
///
/// C'est ce qu'il faut pour Entree, Echap, une touche de fonction ou un
/// Ctrl+quelque chose — tout ce qui n'est pas un caractere a ecrire.
class EtapeTouche extends Etape {
  const EtapeTouche(this.raccourci);

  final Raccourci raccourci;

  @override
  Map<String, Object?> versJson() => {
    'type': 'key',
    'key': raccourci.versJson(),
  };

  @override
  bool operator ==(Object other) =>
      other is EtapeTouche && other.raccourci == raccourci;

  @override
  int get hashCode => raccourci.hashCode;
}

/// Un clic a un endroit de l'ecran.
///
/// Les coordonnees sont celles de l'ecran entier, pas de la fenetre : c'est ce
/// que Windows attend, et c'est ce que le pointeur de visee montre au moment
/// ou on les prend. Une fenetre deplacee depuis rend donc le clic faux — c'est
/// la limite d'un clic par coordonnees, et il n'y en a pas d'autre sans lire
/// l'interieur du jeu.
class EtapeClic extends Etape {
  const EtapeClic(this.x, this.y, {this.droit = false});

  final int x;
  final int y;

  /// Le bouton droit plutot que le gauche.
  final bool droit;

  @override
  Map<String, Object?> versJson() => {
    'type': 'click',
    'x': x,
    'y': y,
    if (droit) 'right': true,
  };

  @override
  bool operator ==(Object other) =>
      other is EtapeClic && other.x == x && other.y == y && other.droit == droit;

  @override
  int get hashCode => Object.hash(x, y, droit);
}

/// Le passage a une autre fenetre du jeu.
///
/// Une macro qui invite depuis un personnage puis accepte depuis un autre a
/// besoin de changer de fenetre en cours de route. La cible se nomme comme
/// celle de la macro : un fragment du titre, donc le nom du personnage.
///
/// Seules les fenetres du jeu repondent. Un navigateur ouvert sur le nom d'un
/// personnage porterait le meme titre, et ecrire dedans serait pire que ne
/// rien faire.
class EtapeFenetre extends Etape {
  const EtapeFenetre(this.titre);

  final String titre;

  @override
  Map<String, Object?> versJson() => {'type': 'window', 'title': titre};

  @override
  bool operator ==(Object other) =>
      other is EtapeFenetre && other.titre == titre;

  @override
  int get hashCode => titre.hashCode;
}

/// Une repetition.
///
/// Deux facons de la borner, et une seule a la fois : un nombre de tours, ou
/// une variable a parcourir. Parcourir une variable est le cas courant —
/// « pour chacun de mes personnages » — et le nom de la variable y designe
/// tour a tour chaque valeur.
class EtapeBoucle extends Etape {
  const EtapeBoucle({
    this.etapes = const [],
    this.repetitions = 2,
    this.liste = '',
  });

  final List<Etape> etapes;

  /// Le nombre de tours quand aucune variable n'est parcourue.
  final int repetitions;

  /// Le nom de la variable parcourue. Vide : c'est [repetitions] qui borne.
  final String liste;

  bool get parcourt => liste.isNotEmpty;

  @override
  Map<String, Object?> versJson() => {
    'type': 'loop',
    if (parcourt) 'each': liste else 'times': repetitions,
    'steps': [for (final e in etapes) e.versJson()],
  };

  @override
  bool operator ==(Object other) =>
      other is EtapeBoucle &&
      other.repetitions == repetitions &&
      other.liste == liste &&
      listEquals(other.etapes, etapes);

  @override
  int get hashCode => Object.hash(repetitions, liste, Object.hashAll(etapes));
}

/// Une attente, en millisecondes.
///
/// Indispensable et non decorative : le jeu ouvre sa zone de tchat en quelques
/// dizaines de millisecondes, et le texte envoye avant qu'elle ne soit la se
/// perd — ou pire, se lit comme des raccourcis de jeu.
class EtapePause extends Etape {
  const EtapePause(this.millisecondes);

  final int millisecondes;

  @override
  Map<String, Object?> versJson() => {
    'type': 'sleep',
    'ms': millisecondes,
  };

  @override
  bool operator ==(Object other) =>
      other is EtapePause && other.millisecondes == millisecondes;

  @override
  int get hashCode => millisecondes.hashCode;
}

/// Une variable : un nom, et ce qu'il vaut.
///
/// Une valeur ou plusieurs, c'est la meme chose ici : un texte est une liste
/// d'une valeur, et une liste d'une valeur est un texte. Ce qui les separe
/// n'est pas leur nature mais l'usage qu'on en fait — parcourir, ou inserer.
@immutable
class Variable {
  const Variable({required this.nom, this.valeurs = const []});

  final String nom;
  final List<String> valeurs;

  bool get estListe => valeurs.length > 1;

  Variable copie({String? nom, List<String>? valeurs}) =>
      Variable(nom: nom ?? this.nom, valeurs: valeurs ?? this.valeurs);

  Map<String, Object?> versJson() => {'name': nom, 'values': valeurs};

  static Variable? depuisJson(Object? json) {
    if (json is! Map) return null;
    final nom = json['name'];
    if (nom is! String || nom.isEmpty) return null;
    final brutes = json['values'];
    return Variable(
      nom: nom,
      valeurs: [
        if (brutes is List)
          for (final v in brutes)
            if (v is String) v,
      ],
    );
  }

  @override
  bool operator ==(Object other) =>
      other is Variable && other.nom == nom && listEquals(other.valeurs, valeurs);

  @override
  int get hashCode => Object.hash(nom, Object.hashAll(valeurs));
}

/// Remplace les `{nom}` d'un texte par ce que valent les variables du tour.
///
/// Seule une boucle en fournit : ailleurs la table est vide, et le texte part
/// donc tel qu'il est ecrit. Un nom inconnu reste lui aussi tel quel — c'est
/// plus utile que de le faire disparaitre, et cela se voit tout de suite.
String remplaceVariables(String texte, Map<String, String> valeurs) {
  if (!texte.contains('{')) return texte;
  return texte.replaceAllMapped(
    RegExp(r'\{([^{}]+)\}'),
    (trouve) => valeurs[trouve.group(1)!.trim()] ?? trouve.group(0)!,
  );
}

@immutable
class Macro {
  const Macro({
    required this.id,
    required this.nom,
    this.etapes = const [],
    this.variables = const [],
    this.raccourci,
    this.cible = '',
    this.actif = true,
  });

  final String id;
  final String nom;
  final List<Etape> etapes;

  /// Les variables de la macro, dans l'ordre ou on les a ecrites.
  final List<Variable> variables;

  /// La touche qui la declenche. Nulle tant qu'on ne lui en a pas donne.
  final Raccourci? raccourci;

  /// Le fragment de titre de la fenetre a activer avant de commencer. Vide :
  /// la macro part dans la fenetre qui est deja devant.
  final String cible;

  final bool actif;

  /// Une macro qui peut partir : une touche, et quelque chose a faire.
  bool get lie => raccourci != null && etapes.isNotEmpty && actif;

  /// La duree que la macro passera a attendre, en millisecondes.
  ///
  /// Ce n'est pas sa duree reelle — les frappes prennent leur temps — mais
  /// c'est celle que l'on a ecrite, et la seule qu'on puisse annoncer avant de
  /// l'avoir jouee.
  int get attente => _attenteDe(etapes);

  static int _attenteDe(List<Etape> etapes) {
    var somme = 0;
    for (final etape in etapes) {
      switch (etape) {
        case EtapePause(:final millisecondes):
          somme += millisecondes;
        case EtapeBoucle(etapes: final dedans, :final repetitions, :final liste):
          // Une boucle sur une variable ne se compte pas ici : le nombre de
          // tours depend de ce qu'elle contient au moment ou l'on joue.
          somme += _attenteDe(dedans) * (liste.isEmpty ? repetitions : 1);
        case EtapeTexte() || EtapeTouche() || EtapeClic() || EtapeFenetre():
          break;
      }
    }
    return somme;
  }

  /// Le nombre d'actions, boucles comprises.
  ///
  /// « Action » est le mot de l'interface ; `Etape` reste celui du modele, ou
  /// il designe la place dans la suite autant que ce qu'on y fait.
  int get nombreDActions => _compte(etapes);

  static int _compte(List<Etape> etapes) {
    var total = 0;
    for (final etape in etapes) {
      total++;
      if (etape case EtapeBoucle(etapes: final dedans)) total += _compte(dedans);
    }
    return total;
  }

  Macro copie({
    String? nom,
    List<Etape>? etapes,
    List<Variable>? variables,
    Raccourci? raccourci,
    bool effaceRaccourci = false,
    String? cible,
    bool? actif,
  }) {
    return Macro(
      id: id,
      nom: nom ?? this.nom,
      etapes: etapes ?? this.etapes,
      variables: variables ?? this.variables,
      raccourci: effaceRaccourci ? null : (raccourci ?? this.raccourci),
      cible: cible ?? this.cible,
      actif: actif ?? this.actif,
    );
  }

  Map<String, Object?> versJson() => {
    'id': id,
    'name': nom,
    'enabled': actif,
    if (cible.isNotEmpty) 'window_title': cible,
    if (raccourci != null) 'shortcut': raccourci!.versJson(),
    if (variables.isNotEmpty)
      'variables': [for (final v in variables) v.versJson()],
    'steps': [for (final e in etapes) e.versJson()],
  };

  static Macro? depuisJson(Object? json) {
    if (json is! Map) return null;
    final id = json['id'];
    final nom = json['name'];
    if (id is! String || id.isEmpty || nom is! String) return null;
    final cible = json['window_title'];
    final brutesVariables = json['variables'];
    return Macro(
      id: id,
      nom: nom,
      etapes: etapesDepuisJson(json['steps']),
      variables: [
        if (brutesVariables is List)
          for (final brute in brutesVariables) ?Variable.depuisJson(brute),
      ],
      raccourci: Raccourci.depuisJson(json['shortcut']),
      cible: cible is String ? cible : '',
      actif: json['enabled'] is bool ? json['enabled'] as bool : true,
    );
  }
}

/// La macro livree avec l'outil, en exemple.
///
/// Desactivee et sans touche : elle est la pour se lire, pas pour partir. Elle
/// montre ce qu'on ne devine pas — une variable parcourue par une boucle, le
/// nom du tour insere dans un texte, le passage d'une fenetre a l'autre — sur
/// le cas qui a motive tout ceci, inviter son groupe.
///
/// Livree une seule fois : au premier lancement, quand les reglages n'ont
/// encore rien a dire des macros. Qui la supprime ne la voit pas revenir.
List<Macro> macrosParDefaut() => [
  const Macro(
    id: 'exemple-invitation',
    nom: 'Inviter dans le groupe',
    actif: false,
    variables: [
      Variable(nom: 'mes_persos', valeurs: ['perso1', 'perso2', 'perso3']),
    ],
    etapes: [
      EtapeBoucle(
        liste: 'mes_persos',
        etapes: [
          EtapeTouche(Raccourci(touche: 0x0D, libelle: 'Enter')),
          EtapeTexte('/invite {mes_persos}'),
          EtapeTouche(Raccourci(touche: 0x0D, libelle: 'Enter')),
          EtapeFenetre('{mes_persos}'),
          EtapeClic(372, 560),
          EtapeFenetre('perso_principal'),
          EtapePause(30),
        ],
      ),
    ],
  ),
];

/// Lit une suite de gestes, en ignorant ceux qu'on ne sait pas lire.
///
/// Un fichier venu d'une version plus recente ne doit pas emporter la macro
/// entiere pour un geste inconnu.
List<Etape> etapesDepuisJson(Object? json) {
  if (json is! List) return const [];
  final etapes = <Etape>[];
  for (final entree in json) {
    final etape = Etape.depuisJson(entree);
    if (etape != null) etapes.add(etape);
  }
  return etapes;
}

/// Lit la liste des macros telle qu'elle est rangee dans les reglages.
List<Macro> macrosDepuisJson(Object? json) {
  if (json is! List) return const [];
  final macros = <Macro>[];
  for (final entree in json) {
    final macro = Macro.depuisJson(entree);
    if (macro != null) macros.add(macro);
  }
  return macros;
}
