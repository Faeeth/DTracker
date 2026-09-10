/// Le pont vers le moteur de raccourcis, et ce qui le tient a jour.
///
/// Seule la configuration traverse le canal. L'appui de touche, lui, est
/// traite entierement du cote natif — `WM_HOTKEY`, resolution du titre,
/// premier plan — si bien que la latence ne depend pas de l'isolat Dart, ni de
/// ce que la capture est en train de faire.
library;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../config.dart';
import '../modele/organizer.dart';
import 'raccourcis.dart';

/// Un raccourci et les titres qu'il peut activer, par ordre de priorite.
@immutable
class LiaisonNative {
  const LiaisonNative({
    required this.id,
    required this.modificateurs,
    required this.touche,
    required this.cibles,
  });

  final String id;
  final int modificateurs;
  final int touche;
  final List<String> cibles;

  Map<String, Object?> versMap() => {
    'id': id,
    'modifiers': modificateurs,
    'keyCode': touche,
    'targets': cibles,
  };
}

/// Ce que la derniere activation a donne, pour le dire dans l'interface.
@immutable
class DernierAppel {
  const DernierAppel({
    required this.personnage,
    required this.cherches,
    required this.trouve,
    required this.a,
  });

  /// Le personnage active, quand il y en a eu un.
  final String? personnage;

  /// Ce qui a ete cherche. Un echec qui ne dit pas quelle fenetre il n'a pas
  /// trouvee laisse deviner.
  final List<String> cherches;

  final bool trouve;
  final DateTime a;
}

/// Facade Dart du moteur natif.
class PontOrganizer {
  PontOrganizer({MethodChannel? canal})
    : _canal = canal ?? const MethodChannel('dtracker/organizer');

  final MethodChannel _canal;

  /// Appele apres qu'un raccourci a active une fenetre. L'index est celui de
  /// la cible retenue, ou -1 quand aucune fenetre n'a repondu.
  void Function(String id, int cible)? surRaccourci;

  void ecoute() {
    _canal.setMethodCallHandler((appel) async {
      if (appel.method == 'onHotkey') {
        final args = appel.arguments;
        if (args is Map) {
          final id = args['id'];
          final cible = args['targetIndex'];
          if (id is String) {
            surRaccourci?.call(id, cible is int ? cible : -1);
          }
        }
      }
      return null;
    });
  }

  /// Remplace tout le jeu de raccourcis. Rend les identifiants que Windows a
  /// refuses, en general parce que la touche appartient deja a quelqu'un.
  Future<Set<String>> applique(List<LiaisonNative> liaisons) async {
    try {
      final refuses = await _canal.invokeListMethod<String>(
        'hotkeys.apply',
        [for (final l in liaisons) l.versMap()],
      );
      return refuses?.toSet() ?? <String>{};
    } on PlatformException catch (erreur) {
      debugPrint('Raccourcis non appliques : ${erreur.message}');
      return <String>{};
    } on MissingPluginException {
      // Hors Windows, ou dans les tests : l'interface reste utilisable.
      return <String>{};
    }
  }

  /// Relache les raccourcis pour que les touches parviennent a l'application
  /// au premier plan, ce qu'il faut pendant une capture de raccourci.
  Future<void> suspend({required bool suspendu}) async {
    try {
      await _canal.invokeMethod<void>('hotkeys.setSuspended', suspendu);
    } on MissingPluginException {
      // Rien a relacher.
    }
  }

  /// Active la premiere fenetre dont le titre contient [titre].
  Future<bool> active(String titre) async {
    try {
      return await _canal.invokeMethod<bool>('window.focus', titre) ?? false;
    } on MissingPluginException {
      return false;
    }
  }

  /// Le titre de la fenetre qui a le clavier en ce moment.
  ///
  /// Sert de garde avant qu'une macro ne tape : Windows refuse parfois de
  /// changer le premier plan sans le dire, et les frappes partiraient dans la
  /// fenetre qui s'y trouvait.
  Future<String> fenetreDevant() async {
    try {
      return await _canal.invokeMethod<String>('window.foreground') ?? '';
    } on MissingPluginException {
      return '';
    }
  }

  /// La fenetre au premier plan appartient-elle au jeu ?
  ///
  /// Le natif refuse de taper ou de cliquer ailleurs ; ceci sert a le dire.
  Future<bool> premierPlanEstLeJeu() async {
    try {
      return await _canal.invokeMethod<bool>('window.isGame') ?? false;
    } on MissingPluginException {
      return false;
    }
  }

  /// Ecrit du texte dans la fenetre au premier plan.
  ///
  /// Sert aux macros, et a rien d'autre. Rend faux quand Windows n'a pas
  /// accepte la frappe — une fenetre elevee en droits, par exemple, qui
  /// n'accepte pas l'entree d'un programme ordinaire.
  Future<bool> envoieTexte(String texte, {int cadence = 0}) async {
    try {
      return await _canal.invokeMethod<bool>('input.text', {
            'text': texte,
            'pace': cadence,
          }) ??
          false;
    } on MissingPluginException {
      return false;
    }
  }

  /// Appuie et relache une touche dans la fenetre au premier plan.
  Future<bool> envoieTouche(Raccourci raccourci) async {
    try {
      return await _canal.invokeMethod<bool>('input.key', {
            'keyCode': raccourci.touche,
            'modifiers': raccourci.modificateurs,
          }) ??
          false;
    } on MissingPluginException {
      return false;
    }
  }

  /// Clique a un endroit de l'ecran.
  Future<bool> clique(int x, int y, {bool droit = false}) async {
    try {
      return await _canal.invokeMethod<bool>('input.click', {
            'x': x,
            'y': y,
            'right': droit,
          }) ??
          false;
    } on MissingPluginException {
      return false;
    }
  }

  /// Ouvre le pointeur de visee et rend le point choisi, ou rien.
  ///
  /// Bloque tant que la visee est ouverte : c'est une question fermee, posee a
  /// l'ecran entier.
  Future<(int, int)?> pointe() async {
    try {
      final point = await _canal.invokeMapMethod<String, int>('mouse.pick');
      if (point == null) return null;
      return (point['x'] ?? 0, point['y'] ?? 0);
    } on MissingPluginException {
      return null;
    }
  }

  /// Rend le code de touche virtuelle qui produit [caractere] sur la
  /// disposition courante, ou 0. Sert aux touches de ponctuation, dont le code
  /// depend du clavier.
  Future<int> toucheDuCaractere(String caractere) async {
    try {
      return await _canal.invokeMethod<int>(
            'keys.virtualKeyForCharacter',
            caractere,
          ) ??
          0;
    } on MissingPluginException {
      return 0;
    }
  }
}

/// Tient les equipes et garde le moteur natif en accord avec elles.
class Organizer extends ChangeNotifier {
  Organizer({required this.config, required this.raccourcis, this.enregistre}) {
    // Les refus et la suspension appartiennent a la table, pas a l'Organizer :
    // il les affiche, il ne les tient pas.
    raccourcis.addListener(notifyListeners);
  }

  final Config config;

  /// La table des touches, partagee avec les macros.
  final Raccourcis raccourcis;

  /// Appele apres chaque modification, pour que les reglages soient ecrits.
  final VoidCallback? enregistre;

  /// Le nom sous lequel l'Organizer declare ses touches. Il se declare le
  /// premier : a touche egale, un personnage passe avant une macro.
  static const String source = 'organizer';

  PontOrganizer get pont => raccourcis.pont;

  DernierAppel? _dernier;

  @override
  void dispose() {
    raccourcis.removeListener(notifyListeners);
    super.dispose();
  }

  List<EquipeOrganizer> get equipes => config.equipes;
  DernierAppel? get dernierAppel => _dernier;

  /// Vrai pendant une capture de raccourci : les raccourcis globaux sont
  /// relaches pour que les touches parviennent au champ de saisie.
  bool get enCapture => raccourcis.enCapture;

  /// Le nombre de raccourcis reellement enregistres dans Windows.
  int get actifs =>
      _liaisons().where((l) => !_refuses.contains(l.id)).length;

  Set<String> get _refuses => raccourcis.refuses;

  int get refuses =>
      _liaisons().where((l) => _refuses.contains(l.id)).length;

  bool get aDesConflits => refuses > 0;

  /// Vrai quand Windows a refuse le raccourci de ce personnage.
  bool enConflit(PersonnageOrganizer personnage) {
    final raccourci = personnage.raccourci;
    return raccourci != null && _refuses.contains(raccourci.signature);
  }

  /// Se termine quand le jeu de raccourcis pousse par la derniere
  /// modification est arrive au natif. C'est le point d'attente des tests.
  Future<void> get synchronise => raccourcis.synchronise;

  /// Redemande a Windows les raccourcis qu'il avait refuses.
  ///
  /// Un refus vient presque toujours d'une autre application qui tenait la
  /// touche ; une fois qu'elle est fermee, rien ne le rattraperait sans cela —
  /// il faudrait modifier une equipe pour que le jeu de raccourcis reparte.
  Future<void> reessaie() => raccourcis.reessaie();

  Future<void> demarre() async {
    raccourcis.ecoute();
    _pousse();
    await synchronise;
  }

  // --- Equipes -------------------------------------------------------------

  EquipeOrganizer ajouteEquipe(String nom) {
    final equipe = EquipeOrganizer(id: _nouvelId(), nom: nom);
    _change([...equipes, equipe]);
    return equipe;
  }

  void renommeEquipe(String id, String nom) =>
      _mapEquipe(id, (e) => e.copie(nom: nom));

  void activeEquipe(String id, bool active) =>
      _mapEquipe(id, (e) => e.copie(active: active));

  /// Referme ou rouvre une equipe.
  ///
  /// Sans repousser les raccourcis : replier ne change rien a ce qui est
  /// enregistre, et reenregistrer tout le jeu de touches pour un pli serait
  /// une fenetre — courte, mais reelle — pendant laquelle elles ne repondent
  /// pas.
  void replieEquipe(String id, bool replie) => _mapEquipe(
    id,
    (e) => e.copie(replie: replie),
    pousse: false,
  );

  void supprimeEquipe(String id) =>
      _change([for (final e in equipes) if (e.id != id) e]);

  /// N'active que cette equipe. Le geste existe encore parce qu'il rend
  /// service quand deux equipes se disputent une touche par erreur, mais il
  /// n'est plus la facon normale de changer d'equipe.
  void isoleEquipe(String id) =>
      _change([for (final e in equipes) e.copie(active: e.id == id)]);

  /// [versIndex] est la position finale, deja ajustee du retrait.
  void deplaceEquipe(int depuis, int versIndex) {
    if (depuis < 0 || depuis >= equipes.length) return;
    final liste = [...equipes];
    liste.insert(versIndex.clamp(0, liste.length - 1), liste.removeAt(depuis));
    _change(liste);
  }

  // --- Personnages ---------------------------------------------------------

  PersonnageOrganizer ajoutePersonnage(
    String equipeId, {
    required String nom,
    required String titre,
    Raccourci? raccourci,
    int? classe,
    bool feminin = false,
  }) {
    final personnage = PersonnageOrganizer(
      id: _nouvelId(),
      nom: nom,
      titre: titre,
      raccourci: raccourci,
      classe: classe,
      feminin: feminin,
    );
    _mapEquipe(
      equipeId,
      (e) => e.copie(personnages: [...e.personnages, personnage]),
    );
    return personnage;
  }

  void modifiePersonnage(
    String equipeId,
    String personnageId, {
    String? nom,
    String? titre,
    Raccourci? raccourci,
    bool effaceRaccourci = false,
    int? classe,
    bool effaceClasse = false,
    bool? feminin,
    bool? actif,
  }) {
    _mapPersonnage(
      equipeId,
      personnageId,
      (p) => p.copie(
        nom: nom,
        titre: titre,
        raccourci: raccourci,
        effaceRaccourci: effaceRaccourci,
        classe: classe,
        effaceClasse: effaceClasse,
        feminin: feminin,
        actif: actif,
      ),
    );
  }

  void activePersonnage(String equipeId, String personnageId, bool actif) =>
      _mapPersonnage(equipeId, personnageId, (p) => p.copie(actif: actif));

  void supprimePersonnage(String equipeId, String personnageId) {
    _mapEquipe(
      equipeId,
      (e) => e.copie(
        personnages: [
          for (final p in e.personnages)
            if (p.id != personnageId) p,
        ],
      ),
    );
  }

  /// L'ordre au sein d'une equipe est la priorite de resolution quand
  /// plusieurs personnages partagent une touche.
  void deplacePersonnage(String equipeId, int depuis, int versIndex) {
    _mapEquipe(equipeId, (e) {
      if (depuis < 0 || depuis >= e.personnages.length) return e;
      final liste = [...e.personnages];
      liste.insert(
        versIndex.clamp(0, liste.length - 1),
        liste.removeAt(depuis),
      );
      return e.copie(personnages: liste);
    });
  }

  // --- Capture de raccourci -------------------------------------------------

  /// Active la fenetre d'un personnage sans passer par son raccourci.
  Future<bool> essaie(String titre) => pont.active(titre);

  // --- Interne -------------------------------------------------------------

  void _surRaccourci(String id, int cible) {
    final candidats = _parSignature()[id] ?? const [];
    final trouve = cible >= 0 && cible < candidats.length;
    _dernier = DernierAppel(
      personnage: trouve ? candidats[cible].nom : null,
      cherches: [for (final p in candidats) p.titre],
      trouve: trouve,
      a: DateTime.now(),
    );
    notifyListeners();
  }

  /// Les personnages vivants par signature de raccourci, l'ordre des equipes
  /// puis celui des personnages faisant la priorite.
  Map<String, List<PersonnageOrganizer>> _parSignature() {
    final table = <String, List<PersonnageOrganizer>>{};
    for (final equipe in equipes) {
      for (final personnage in equipe.vivants) {
        table
            .putIfAbsent(
              personnage.raccourci!.signature,
              () => <PersonnageOrganizer>[],
            )
            .add(personnage);
      }
    }
    return table;
  }

  List<LiaisonNative> _liaisons() {
    final liaisons = <LiaisonNative>[];
    _parSignature().forEach((signature, personnages) {
      final raccourci = personnages.first.raccourci!;
      liaisons.add(
        LiaisonNative(
          id: signature,
          modificateurs: raccourci.modificateurs,
          touche: raccourci.touche,
          cibles: [for (final p in personnages) p.titre],
        ),
      );
    });
    return liaisons;
  }

  void _pousse() => raccourcis.declare(
    source,
    _liaisons(),
    surAppel: _surRaccourci,
    priorite: 0,
  );

  void _change(List<EquipeOrganizer> equipes, {bool pousse = true}) {
    config.equipes = equipes;
    notifyListeners();
    enregistre?.call();
    if (pousse) _pousse();
  }

  void _mapEquipe(
    String id,
    EquipeOrganizer Function(EquipeOrganizer) map, {
    bool pousse = true,
  }) {
    _change([
      for (final e in equipes) if (e.id == id) map(e) else e,
    ], pousse: pousse);
  }

  void _mapPersonnage(
    String equipeId,
    String personnageId,
    PersonnageOrganizer Function(PersonnageOrganizer) map,
  ) {
    _mapEquipe(
      equipeId,
      (e) => e.copie(
        personnages: [
          for (final p in e.personnages)
            if (p.id == personnageId) map(p) else p,
        ],
      ),
    );
  }

  /// Un identifiant qui ne se repete pas.
  ///
  /// L'horodatage seul ne suffit pas : deux equipes creees coup sur coup
  /// tombent dans la meme microseconde, se retrouvent avec le meme
  /// identifiant, et toute modification de l'une s'applique aux deux.
  int _compteur = 0;

  String _nouvelId() {
    final t = DateTime.now().microsecondsSinceEpoch;
    return '${t.toRadixString(36)}-${(_compteur++).toRadixString(36)}';
  }
}
