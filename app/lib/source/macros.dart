/// Les macros, et ce qui les joue.
///
/// Contrairement a l'Organizer, dont l'appui de touche est traite entierement
/// du cote natif, une macro se deroule **ici** : elle attend, elle enchaine,
/// elle peut s'arreter en cours. La latence n'a pas la meme importance — ce
/// qui compte est de tenir des pauses de cent millisecondes, pas d'en gagner
/// deux — et le derouler en Dart le rend lisible et verifiable, ce qu'une
/// boucle dans un fil natif n'aurait pas ete.
library;

import 'package:flutter/foundation.dart';

import '../config.dart';
import '../modele/macro.dart';
import '../modele/raccourci.dart';
import 'organizer.dart';
import 'raccourcis.dart';

/// Ce que la derniere execution a donne, pour le dire dans l'interface.
@immutable
class DernierJeu {
  const DernierJeu({
    required this.macro,
    required this.a,
    this.fenetreIntrouvable,
    this.obstacle = '',
    this.horsDuJeu = false,
  });

  final String macro;
  final DateTime a;

  /// Le titre cherche en vain, quand la fenetre visee n'a pas pu etre mise
  /// devant. Une macro qui n'a pas sa cible au premier plan ne joue rien : ses
  /// frappes iraient dans la fenetre qui s'y trouvait.
  final String? fenetreIntrouvable;

  /// Ce qui tenait le clavier a la place. Vide quand la fenetre n'existe pas
  /// du tout.
  final String obstacle;

  /// La macro s'est arretee parce que le premier plan n'appartenait pas au
  /// jeu.
  final bool horsDuJeu;

  bool get reussi => fenetreIntrouvable == null;
}

/// Le nombre de tours qu'une boucle ne depassera pas.
///
/// Une macro n'a pas de condition d'arret : sans borne, une boucle mal reglee
/// taperait jusqu'a ce qu'on ferme l'outil. Mille tours est au-dela de tout
/// usage raisonnable et en-deca de ce qui fait perdre la main.
const int _toursMaximum = 1000;

/// Le temps d'attente entre l'activation d'une fenetre et la premiere frappe.
///
/// Windows rend la main des que la fenetre est au premier plan, mais le jeu,
/// lui, met quelques images a prendre le clavier. Sans cette pause, la premiere
/// touche d'une macro se perdait une fois sur deux.
const Duration _delaiApresFocus = Duration(milliseconds: 150);

class Macros extends ChangeNotifier {
  Macros({
    required this.config,
    required this.raccourcis,
    this.enregistre,
    Future<void> Function(Duration)? attend,
  }) : attend = attend ?? _attendVraiment {
    raccourcis.addListener(notifyListeners);
  }

  final Config config;

  /// La table des touches, partagee avec l'Organizer.
  final Raccourcis raccourcis;

  /// Appele apres chaque modification, pour que les reglages soient ecrits.
  final VoidCallback? enregistre;

  /// L'attente entre deux gestes. Injectee pour que les cas de test jouent
  /// une macro sans passer une seconde a la regarder.
  final Future<void> Function(Duration) attend;

  /// Le nom sous lequel les macros declarent leurs touches. Elles se
  /// declarent apres l'Organizer : a touche egale, un personnage passe avant.
  static const String source = 'macros';

  static Future<void> _attendVraiment(Duration duree) => Future.delayed(duree);

  PontOrganizer get pont => raccourcis.pont;

  Macro? _enCours;
  DernierJeu? _dernier;
  bool _interrompt = false;
  int _compteur = 0;

  List<Macro> get macros => config.macros;

  /// La touche qui arrete la macro en cours. Nulle tant qu'on ne lui en a pas
  /// donne.
  Raccourci? get arret => config.arretMacros;

  void changeArret(Raccourci? raccourci) {
    config.arretMacros = raccourci;
    notifyListeners();
    enregistre?.call();
    _pousse();
  }

  /// La macro qui se joue en ce moment, s'il y en a une.
  Macro? get enCours => _enCours;

  DernierJeu? get dernierJeu => _dernier;

  /// Le nombre de macros qu'on a laissees actives.
  ///
  /// Ni plus ni moins : celle qui n'a pas encore de touche ou d'action est
  /// comptee comme les autres. L'interrupteur dit ce que l'utilisateur veut,
  /// et c'est cela qu'on lui rend — ce qui manque pour qu'elle parte se voit
  /// sur sa ligne.
  int get actives => macros.where((m) => m.actif).length;

  /// Vrai quand Windows a refuse la touche de cette macro.
  bool enConflit(Macro macro) {
    final raccourci = macro.raccourci;
    return raccourci != null && raccourcis.refuses.contains(raccourci.signature);
  }

  /// Vrai quand un personnage de l'Organizer tient deja cette touche.
  ///
  /// Ce n'est pas un refus de Windows : la touche est bien enregistree, mais
  /// c'est l'autre qui repond. Le dire vaut mieux que de laisser croire a une
  /// panne.
  bool prisAilleurs(Macro macro) {
    final raccourci = macro.raccourci;
    return raccourci != null &&
        raccourcis.prisesAilleurs(source).contains(raccourci.signature);
  }

  Future<void> get synchronise => raccourcis.synchronise;

  Future<void> demarre() async {
    raccourcis.ecoute();
    _pousse();
    await synchronise;
  }

  @override
  void dispose() {
    raccourcis.removeListener(notifyListeners);
    super.dispose();
  }

  // --- Les macros ----------------------------------------------------------

  Macro ajoute(String nom) {
    final macro = Macro(id: _nouvelId(), nom: nom);
    _change([...macros, macro]);
    return macro;
  }

  void modifie(
    String id, {
    String? nom,
    List<Etape>? etapes,
    List<Variable>? variables,
    Raccourci? raccourci,
    bool effaceRaccourci = false,
    String? cible,
    bool? actif,
  }) {
    _change([
      for (final m in macros)
        if (m.id == id)
          m.copie(
            nom: nom,
            etapes: etapes,
            variables: variables,
            raccourci: raccourci,
            effaceRaccourci: effaceRaccourci,
            cible: cible,
            actif: actif,
          )
        else
          m,
    ]);
  }

  void supprime(String id) =>
      _change([for (final m in macros) if (m.id != id) m]);

  /// [versIndex] est la position finale, deja ajustee du retrait.
  void deplace(int depuis, int versIndex) {
    if (depuis < 0 || depuis >= macros.length) return;
    final liste = [...macros];
    liste.insert(versIndex.clamp(0, liste.length - 1), liste.removeAt(depuis));
    _change(liste);
  }

  /// La macro telle qu'elle est rangee, ou nulle si elle a disparu.
  Macro? parId(String id) {
    for (final macro in macros) {
      if (macro.id == id) return macro;
    }
    return null;
  }

  // --- L'execution ---------------------------------------------------------

  /// Duplique une macro, sa touche exceptee.
  ///
  /// Deux macros sur la meme touche ne se partagent pas : la premiere repond,
  /// et la copie paraitrait inerte. Elle arrive donc sans touche, ce qui se
  /// voit et se corrige d'un clic.
  Macro? duplique(String id, String nom) {
    final modele = parId(id);
    if (modele == null) return null;
    final copie = Macro(
      id: _nouvelId(),
      nom: nom,
      etapes: modele.etapes,
      variables: modele.variables,
      cible: modele.cible,
      actif: modele.actif,
    );
    final rang = macros.indexOf(modele);
    _change([
      for (var i = 0; i < macros.length; i++) ...[
        macros[i],
        if (i == rang) copie,
      ],
    ]);
    return copie;
  }

  /// Arrete la macro en cours, s'il y en a une.
  void arrete() {
    if (_enCours == null) return;
    _interrompt = true;
    notifyListeners();
  }

  /// Joue une macro, du premier geste au dernier.
  ///
  /// Une seule a la fois : deux suites de frappes entrelacees n'ecriraient ni
  /// l'une ni l'autre. Un second appui pendant qu'elle joue **l'arrete** au
  /// lieu d'en lancer une autre — c'est le geste qu'on fait quand une macro
  /// part de travers, et il n'y en avait aucun autre.
  Future<void> joue(Macro macro) async {
    if (_enCours != null) {
      _interrompt = true;
      return;
    }
    if (macro.etapes.isEmpty) return;

    _enCours = macro;
    _interrompt = false;
    notifyListeners();

    // Les touches globales sont relachees le temps du jeu : une macro qui
    // envoie Entree ou une touche de fonction se declencherait elle-meme, et
    // la suite partirait en cascade.
    await raccourcis.suspend(suspendu: true, sauf: arret?.signature);
    try {
      // La fenetre visee passe devant, et l'on verifie qu'elle y est :
      // `SetForegroundWindow` echoue en silence quand Windows refuse le
      // changement, et sans ce controle les frappes partaient dans la fenetre
      // qui s'y trouvait. Ce n'est pas une precaution de principe : c'est
      // arrive, et une commande de jeu est partie dans le mauvais client.
      if (!await _active(macro.cible)) return;
      if (!await _dansLeJeu()) return;

      // L'environnement part vide : une variable ne vaut quelque chose que
      // dans la boucle qui la parcourt. Ailleurs, `{nom}` n'est pas un nom de
      // variable mais du texte — et c'est du texte qu'il faut taper.
      // Le compte rendu de reussite n'est ecrit que si rien ne l'a arretee :
      // sans cela il effacait la raison de l'arret, et la macro paraissait
      // s'etre bien deroulee.
      if (await _joue(macro.etapes, const {})) {
        _dernier = DernierJeu(macro: macro.nom, a: DateTime.now());
      }
    } finally {
      _enCours = null;
      _interrompt = false;
      await raccourcis.suspend(suspendu: false);
      notifyListeners();
    }
  }

  /// Joue une suite de gestes dans un environnement de variables donne.
  ///
  /// Recursive : une boucle rejoue les memes gestes avec, en plus, la valeur
  /// du tour. L'environnement est copie a chaque tour plutot que modifie, si
  /// bien qu'une boucle imbriquee ne peut pas ecraser la variable de celle qui
  /// la contient.
  /// Rend faux quand une garde a arrete la macro — elle a alors ecrit
  /// elle-meme ce qui s'est passe.
  Future<bool> _joue(List<Etape> etapes, Map<String, String> valeurs) async {
    for (final etape in etapes) {
      if (_interrompt) return true;
      switch (etape) {
        case EtapeTexte(:final texte, :final cadence):
          final parti = await pont.envoieTexte(
            remplaceVariables(texte, valeurs),
            cadence: cadence,
          );
          if (!parti && !await _dansLeJeu()) return false;
        case EtapeTouche(:final raccourci):
          await pont.envoieTouche(raccourci);
        case EtapePause(:final millisecondes):
          await attend(Duration(milliseconds: millisecondes));
        case EtapeClic(:final x, :final y, :final droit):
          final parti = await pont.clique(x, y, droit: droit);
          if (!parti && !await _dansLeJeu()) return false;
        case EtapeFenetre(:final titre):
          // Comme un texte : c'est dans une boucle que l'action prend tout son
          // sens, un tour par personnage, et « {mes_persos} » doit donc y
          // valoir le nom du tour.
          if (!await _active(remplaceVariables(titre, valeurs))) return false;
        case EtapeBoucle():
          if (!await _boucle(etape, valeurs)) return false;
      }
    }
    return true;
  }

  /// Verifie que le jeu est bien devant, et arrete la macro sinon.
  ///
  /// Le natif refuse deja de taper ailleurs : ceci ne fait que le constater et
  /// le dire. Une macro qui s'arrete sans expliquer pourquoi se signale comme
  /// une panne.
  Future<bool> _dansLeJeu() async {
    if (await pont.premierPlanEstLeJeu()) return true;
    _interrompt = true;
    _dernier = DernierJeu(
      macro: _enCours?.nom ?? '',
      a: DateTime.now(),
      obstacle: await pont.fenetreDevant(),
      horsDuJeu: true,
    );
    return false;
  }

  /// Amene une fenetre du jeu devant, et s'assure qu'elle y est.
  Future<bool> _active(String titre) async {
    if (titre.isEmpty) return true;
    final trouve = await pont.active(titre);
    if (!trouve) {
      _interrompt = true;
      _dernier = DernierJeu(
        macro: _enCours?.nom ?? '',
        a: DateTime.now(),
        fenetreIntrouvable: titre,
      );
      return false;
    }
    await attend(_delaiApresFocus);
    final devant = await pont.fenetreDevant();
    if (devant.toLowerCase().contains(titre.toLowerCase())) return true;
    _interrompt = true;
    _dernier = DernierJeu(
      macro: _enCours?.nom ?? '',
      a: DateTime.now(),
      fenetreIntrouvable: titre,
      obstacle: devant,
    );
    return false;
  }

  Future<bool> _boucle(EtapeBoucle boucle, Map<String, String> valeurs) async {
    if (boucle.etapes.isEmpty) return true;
    if (boucle.parcourt) {
      final liste = _variable(boucle.liste);
      // Une variable inconnue ne fait aucun tour : c'est plus sur que d'en
      // faire un a vide, qui enverrait le texte avec `{nom}` dedans.
      if (liste == null) return true;
      for (final valeur in liste.valeurs.take(_toursMaximum)) {
        if (_interrompt) return true;
        if (!await _joue(boucle.etapes, {...valeurs, boucle.liste: valeur})) {
          return false;
        }
      }
      return true;
    }
    final tours = boucle.repetitions.clamp(0, _toursMaximum);
    for (var i = 0; i < tours; i++) {
      if (_interrompt) return true;
      if (!await _joue(boucle.etapes, valeurs)) return false;
    }
    return true;
  }

  Variable? _variable(String nom) {
    for (final macro in macros) {
      for (final variable in macro.variables) {
        if (variable.nom == nom) return variable;
      }
    }
    return null;
  }

  /// Active la fenetre visee sans jouer la macro, pour verifier qu'elle
  /// existe.
  Future<bool> essaie(String titre) => pont.active(titre);

  /// Ouvre le pointeur de visee et rend le point choisi.
  ///
  /// Les raccourcis sont relaches pendant ce temps : la visee attend un clic,
  /// et une touche enregistree partirait par-dessus.
  Future<(int, int)?> vise() async {
    await raccourcis.suspend(suspendu: true);
    try {
      return await pont.pointe();
    } finally {
      await raccourcis.suspend(suspendu: false);
    }
  }

  // --- Interne -------------------------------------------------------------

  void _surRaccourci(String signature, int _) {
    // L'arret d'abord : c'est la seule touche qui repond pendant qu'une macro
    // joue, et elle ne doit rien declencher d'autre.
    if (signature == arret?.signature) {
      arrete();
      return;
    }
    for (final macro in macros) {
      if (macro.lie && macro.raccourci!.signature == signature) {
        joue(macro);
        return;
      }
    }
  }

  List<LiaisonNative> _liaisons() {
    final table = <String, LiaisonNative>{};
    final stop = arret;
    if (stop != null) {
      table[stop.signature] = LiaisonNative(
        id: stop.signature,
        modificateurs: stop.modificateurs,
        touche: stop.touche,
        cibles: const [],
      );
    }
    for (final macro in macros) {
      if (!macro.lie) continue;
      final raccourci = macro.raccourci!;
      // Sans cible : une macro n'active aucune fenetre par elle-meme, c'est
      // ici qu'on decide de la suite. Deux macros sur la meme touche donnent
      // une seule liaison, et c'est la premiere qui repond.
      table.putIfAbsent(
        raccourci.signature,
        () => LiaisonNative(
          id: raccourci.signature,
          modificateurs: raccourci.modificateurs,
          touche: raccourci.touche,
          cibles: const [],
        ),
      );
    }
    return table.values.toList();
  }

  void _pousse() => raccourcis.declare(
    source,
    _liaisons(),
    surAppel: _surRaccourci,
    // Apres l'Organizer : a touche egale, un personnage passe avant.
    priorite: 1,
  );

  void _change(List<Macro> liste) {
    config.macros = liste;
    notifyListeners();
    enregistre?.call();
    _pousse();
  }

  /// Un identifiant qui ne se repete pas, meme cree en rafale.
  String _nouvelId() {
    final t = DateTime.now().microsecondsSinceEpoch;
    return '${t.toRadixString(36)}-${(_compteur++).toRadixString(36)}';
  }
}
