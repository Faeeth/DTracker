/// L'arbitre des touches globales.
///
/// `RegisterHotKey` ne connait qu'une seule table par processus, et le natif la
/// remplace en entier a chaque envoi. Deux pages qui poussent chacune la
/// sienne se seraient donc effacees l'une l'autre : l'Organizer enregistrant
/// ses equipes aurait desenregistre les macros, et reciproquement.
///
/// Ce qui suit tient donc la table. Chaque source y **declare** ce qu'elle
/// veut, l'union part au natif, et l'appui revient a celle qui l'avait
/// demande. Deux sources qui demandent la meme touche ne se battent pas : la
/// premiere declaree l'emporte, et la seconde peut le dire a l'utilisateur
/// plutot que de paraitre inerte.
library;

import 'package:flutter/foundation.dart';

import 'organizer.dart' show LiaisonNative, PontOrganizer;

/// Ce qu'une source a declare, et a qui rendre compte.
class _Source {
  _Source(this.priorite, this.liaisons, this.surAppel);

  /// Le plus petit sert en premier. Une priorite ecrite plutot que deduite de
  /// l'ordre des appels : celui-ci depend de qui demarre le premier, ce qui
  /// n'est pas une regle qu'on veuille voir changer avec le montage de la
  /// fenetre.
  final int priorite;

  List<LiaisonNative> liaisons;
  void Function(String signature, int cible) surAppel;
}

class Raccourcis extends ChangeNotifier {
  Raccourcis({required this.pont});

  final PontOrganizer pont;

  final Map<String, _Source> _sources = {};

  /// Les sources dans l'ordre de service : c'est lui qui tranche quand deux
  /// veulent la meme touche.
  Iterable<MapEntry<String, _Source>> get _ordonnees {
    final liste = _sources.entries.toList()
      ..sort((a, b) => a.value.priorite.compareTo(b.value.priorite));
    return liste;
  }

  Set<String> _refuses = {};
  int _suspensions = 0;
  bool _capture = false;

  /// La touche laissee active pendant une suspension, s'il y en a une.
  String? _sauf;
  Future<void>? _synchro;

  /// Les signatures que Windows a refusees.
  Set<String> get refuses => _refuses;

  /// Vrai tant qu'une capture de touche ou une macro tient les raccourcis
  /// relaches.
  bool get suspendu => _suspensions > 0;

  /// Se termine quand la derniere table poussee est arrivee au natif. C'est le
  /// point d'attente des tests.
  Future<void> get synchronise => _synchro ?? Future<void>.value();

  void ecoute() {
    pont
      ..surRaccourci = _distribue
      ..ecoute();
  }

  /// Ce qu'une source veut voir enregistre. Remplace sa declaration
  /// precedente, et repousse la table.
  void declare(
    String source,
    List<LiaisonNative> liaisons, {
    required void Function(String signature, int cible) surAppel,
    int priorite = 0,
  }) {
    final connue = _sources[source];
    if (connue == null) {
      _sources[source] = _Source(priorite, liaisons, surAppel);
    } else {
      connue
        ..liaisons = liaisons
        ..surAppel = surAppel;
    }
    _synchro = _pousse();
  }

  /// Les signatures qu'une autre source tient deja, et que celle-ci n'aura
  /// donc pas.
  Set<String> prisesAilleurs(String source) {
    final prises = <String>{};
    for (final entree in _ordonnees) {
      if (entree.key == source) break;
      prises.addAll(entree.value.liaisons.map((l) => l.id));
    }
    return prises;
  }

  /// Redemande les touches que Windows avait refusees.
  ///
  /// Un refus vient presque toujours d'une autre application qui tenait la
  /// touche ; une fois qu'elle est fermee, rien ne le rattraperait sans cela.
  Future<void> reessaie() async {
    if (_refuses.isEmpty) return;
    _synchro = _pousse();
    await _synchro;
  }

  /// Vrai pendant qu'une fenetre de saisie attend une touche.
  ///
  /// Distinct de [suspendu] : une macro qui joue relache aussi les touches,
  /// et ce n'est pas la meme chose a dire.
  bool get enCapture => _capture;

  /// Ouvre une saisie de touche : les raccourcis sont relaches pour que la
  /// frappe parvienne au champ plutot qu'a Windows.
  Future<void> debuteCapture() async {
    if (_capture) return;
    _capture = true;
    notifyListeners();
    await suspend(suspendu: true);
  }

  Future<void> termineCapture() async {
    if (!_capture) return;
    _capture = false;
    notifyListeners();
    await suspend(suspendu: false);
  }

  /// Le code de touche virtuelle qui produit ce caractere sur la disposition
  /// courante.
  Future<int> toucheDuCaractere(String caractere) =>
      pont.toucheDuCaractere(caractere);

  /// Relache les touches, ou les reprend.
  ///
  /// Compte les demandes plutot que de tenir un booleen : une macro qui joue
  /// pendant qu'une capture est ouverte les reprendrait au milieu de la
  /// saisie.
  ///
  /// [sauf] laisse une touche enregistree — celle qui arrete les macros. Elle
  /// ne peut pas passer par la suspension du natif, qui est globale : la table
  /// est donc reduite a cette seule touche, puis rendue entiere.
  Future<void> suspend({required bool suspendu, String? sauf}) async {
    final avant = _suspensions;
    _suspensions = suspendu ? _suspensions + 1 : (_suspensions - 1).clamp(0, 99);
    if ((avant > 0) == (_suspensions > 0)) return;
    if (_suspensions > 0) {
      _sauf = sauf;
      if (sauf == null) {
        await pont.suspend(suspendu: true);
      } else {
        await pont.applique([
          for (final liaison in table())
            if (liaison.id == sauf) liaison,
        ]);
      }
    } else {
      final reduite = _sauf;
      _sauf = null;
      if (reduite == null) {
        await pont.suspend(suspendu: false);
      } else {
        await pont.applique(table());
      }
    }
    notifyListeners();
  }

  /// La table telle qu'elle part au natif : l'union, premiere source servie.
  List<LiaisonNative> table() {
    final table = <String, LiaisonNative>{};
    for (final entree in _ordonnees) {
      for (final liaison in entree.value.liaisons) {
        table.putIfAbsent(liaison.id, () => liaison);
      }
    }
    return table.values.toList();
  }

  Future<void> _pousse() async {
    final refuses = await pont.applique(table());
    if (!setEquals(refuses, _refuses)) {
      _refuses = refuses;
      notifyListeners();
    }
  }

  /// Rend l'appui a la source qui detient la touche.
  void _distribue(String signature, int cible) {
    for (final entree in _ordonnees) {
      if (entree.value.liaisons.any((l) => l.id == signature)) {
        entree.value.surAppel(signature, cible);
        return;
      }
    }
  }
}

