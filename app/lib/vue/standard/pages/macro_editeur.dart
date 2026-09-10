/// L'editeur d'une macro : son nom, sa cible, sa touche, ses variables et ses
/// gestes.
///
/// Une page et non une fenetre : ecrire une suite de gestes n'est pas une
/// question fermee. On l'essaie, on la corrige, on revient — et une popup
/// n'aurait ni adresse ni retour en arriere.
///
/// Tout se modifie sur place, sans bouton « Enregistrer ». Ce qui est ecrit est
/// ce qui est range : un editeur qui garderait un brouillon perdrait l'unique
/// chose que l'utilisateur croit avoir faite. Les champs de texte attendent une
/// pause de frappe avant d'ecrire, pour ne pas reecrire les reglages a chaque
/// lettre.
///
/// Les gestes forment un arbre : une boucle en contient d'autres. Chaque liste
/// connait son **chemin** — la suite des rangs des boucles qui la contiennent —
/// et toute modification passe par lui. C'est ce qui evite de tenir un etat
/// parallele a celui de la macro, qui aurait vieilli au premier changement.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart' hide Cache;

import '../../../i18n/textes.dart';
import '../../../modele/macro.dart';
import '../../../source/macros.dart';
import '../briques.dart';
import 'organizer_dialogues.dart' show EtiquetteRaccourci, captureUnRaccourci;

/// Le temps de silence apres lequel une saisie est rangee.
const Duration _reposClavier = Duration(milliseconds: 400);

class PageMacro extends StatefulWidget {
  const PageMacro({super.key, required this.macros, required this.id});

  final Macros macros;

  /// La macro est relue a chaque image plutot que prise telle qu'elle etait a
  /// l'ouverture : elle change sous nos yeux, c'est le propre d'un editeur.
  final String id;

  @override
  State<PageMacro> createState() => _PageMacroState();
}

class _PageMacroState extends State<PageMacro> {
  late final TextEditingController _nom;
  late final TextEditingController _cible;
  Timer? _repos;
  String? _essai;

  Macro? get _macro => widget.macros.parId(widget.id);

  @override
  void initState() {
    super.initState();
    final macro = _macro;
    _nom = TextEditingController(text: macro?.nom ?? '');
    _cible = TextEditingController(text: macro?.cible ?? '');
  }

  @override
  void dispose() {
    // Ce qui a ete tape dans la derniere demi-seconde ne doit pas se perdre
    // parce qu'on a quitte la page — mais rien d'autre ne doit etre reecrit.
    final enAttente = _repos?.isActive ?? false;
    _repos?.cancel();
    if (enAttente) _range();
    _nom.dispose();
    _cible.dispose();
    super.dispose();
  }

  void _apresLaFrappe() {
    _repos?.cancel();
    _repos = Timer(_reposClavier, () {
      if (mounted) setState(_range);
    });
  }

  void _range() {
    final macro = _macro;
    if (macro == null) return;
    final nom = _nom.text.trim();
    widget.macros.modifie(
      macro.id,
      nom: nom.isEmpty ? macro.nom : nom,
      cible: _cible.text.trim(),
    );
  }

  Future<void> _teste() async {
    final titre = _cible.text.trim();
    if (titre.isEmpty) return;
    final trouve = await widget.macros.essaie(titre);
    if (!mounted) return;
    setState(
      () => _essai = trouve ? T.fenetreTrouvee : T.fenetreIntrouvable(titre),
    );
  }

  Future<void> _changeRaccourci() async {
    final macro = _macro;
    if (macro == null) return;
    final choix = await captureUnRaccourci(
      context,
      widget.macros.raccourcis,
      titre: T.raccourciDe(macro.nom),
      initial: macro.raccourci,
    );
    if (choix == null) return;
    widget.macros.modifie(
      macro.id,
      raccourci: choix.raccourci,
      effaceRaccourci: choix.raccourci == null,
    );
  }

  // --- Les gestes, par leur chemin -----------------------------------------

  /// Applique [operation] a la liste de gestes que designe [chemin].
  ///
  /// Un chemin vide designe la liste de premier niveau ; `[2]` celle de la
  /// boucle qui s'y trouve au rang 2, et ainsi de suite.
  List<Etape> _dans(
    List<Etape> etapes,
    List<int> chemin,
    List<Etape> Function(List<Etape>) operation,
  ) {
    if (chemin.isEmpty) return operation(etapes);
    final rang = chemin.first;
    final reste = chemin.sublist(1);
    final refaite = <Etape>[];
    for (var i = 0; i < etapes.length; i++) {
      final etape = etapes[i];
      if (i == rang && etape is EtapeBoucle) {
        refaite.add(
          EtapeBoucle(
            etapes: _dans(etape.etapes, reste, operation),
            repetitions: etape.repetitions,
            liste: etape.liste,
          ),
        );
      } else {
        refaite.add(etape);
      }
    }
    return refaite;
  }

  void _edite(List<int> chemin, List<Etape> Function(List<Etape>) operation) {
    final macro = _macro;
    if (macro == null) return;
    widget.macros.modifie(
      macro.id,
      etapes: _dans(macro.etapes, chemin, operation),
    );
  }

  void _ajoute(List<int> chemin, Etape etape) =>
      _edite(chemin, (liste) => [...liste, etape]);

  void _remplace(List<int> chemin, int rang, Etape etape) => _edite(
    chemin,
    (liste) => [
      for (var i = 0; i < liste.length; i++)
        if (i == rang) etape else liste[i],
    ],
  );

  void _supprime(List<int> chemin, int rang) => _edite(
    chemin,
    (liste) => [
      for (var i = 0; i < liste.length; i++)
        if (i != rang) liste[i],
    ],
  );

  void _deplace(List<int> chemin, int rang, int pas) => _edite(chemin, (liste) {
    final vers = rang + pas;
    if (vers < 0 || vers >= liste.length) return liste;
    final refaite = [...liste];
    refaite.insert(vers, refaite.removeAt(rang));
    return refaite;
  });

  Future<void> _ajouteTouche(List<int> chemin) async {
    final choix = await captureUnRaccourci(
      context,
      widget.macros.raccourcis,
      titre: T.ajouterTouche,
    );
    final raccourci = choix?.raccourci;
    if (raccourci == null) return;
    _ajoute(chemin, EtapeTouche(raccourci));
  }

  /// Ouvre le pointeur de visee, et range le point choisi.
  Future<void> _vise({List<int>? chemin, int? rang, bool droit = false}) async {
    final point = await widget.macros.vise();
    if (point == null || !mounted) return;
    final (x, y) = point;
    if (chemin == null || rang == null) return;
    _remplace(chemin, rang, EtapeClic(x, y, droit: droit));
  }

  Future<void> _ajouteClic(List<int> chemin) async {
    final point = await widget.macros.vise();
    if (point == null || !mounted) return;
    final (x, y) = point;
    _ajoute(chemin, EtapeClic(x, y));
  }

  // --- Les variables -------------------------------------------------------

  void _changeVariables(List<Variable> variables) {
    final macro = _macro;
    if (macro == null) return;
    widget.macros.modifie(macro.id, variables: variables);
  }

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);
    return ListenableBuilder(
      listenable: widget.macros,
      builder: (context, _) {
        final macro = _macro;
        // Supprimee ailleurs pendant qu'on la regardait.
        if (macro == null) {
          return Vide(T.aucuneMacro, icone: LucideIcons.zap);
        }
        final joue = widget.macros.enCours?.id == macro.id;
        return ListView(
          padding: const EdgeInsets.only(top: Pas.m, bottom: Pas.l),
          children: [
            ShadCard(
              padding: const EdgeInsets.all(Pas.m),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Section(T.nom),
                  ShadInput(
                    controller: _nom,
                    onChanged: (_) => _apresLaFrappe(),
                    onSubmitted: (_) => setState(_range),
                  ),
                  const SizedBox(height: Pas.m),
                  Section(T.personnageCible),
                  Row(
                    children: [
                      Expanded(
                        child: ShadInput(
                          controller: _cible,
                          placeholder: Text(T.fenetreAuPremierPlan),
                          onChanged: (_) => _apresLaFrappe(),
                          onSubmitted: (_) => setState(_range),
                        ),
                      ),
                      const SizedBox(width: Pas.s),
                      ShadButton.ghost(
                        leading: const Icon(LucideIcons.crosshair, size: 14),
                        onPressed: _cible.text.trim().isEmpty ? null : _teste,
                        child: Text(T.tester),
                      ),
                    ],
                  ),
                  const SizedBox(height: Pas.xs),
                  Text(T.personnageCibleAide, style: theme.textTheme.muted),
                  if (_essai != null) ...[
                    const SizedBox(height: Pas.xs),
                    Text(_essai!, style: theme.textTheme.muted),
                  ],
                  const SizedBox(height: Pas.m),
                  Row(
                    children: [
                      Text(T.raccourci, style: theme.textTheme.muted),
                      const SizedBox(width: Pas.m),
                      EtiquetteRaccourci(
                        raccourci: macro.raccourci,
                        enConflit:
                            widget.macros.enConflit(macro) ||
                            widget.macros.prisAilleurs(macro),
                        onTap: _changeRaccourci,
                      ),
                      if (widget.macros.prisAilleurs(macro)) ...[
                        const SizedBox(width: Pas.s),
                        Text(
                          T.toucheDejaPrise,
                          style: theme.textTheme.muted.copyWith(
                            color: theme.colorScheme.destructive,
                          ),
                        ),
                      ],
                      const Spacer(),
                      ShadButton.outline(
                        leading: Icon(
                          joue ? LucideIcons.square : LucideIcons.play,
                          size: 14,
                        ),
                        onPressed: macro.etapes.isEmpty
                            ? null
                            : () => widget.macros.joue(macro),
                        child: Text(joue ? T.arreterMacro : T.jouerMacro),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: Pas.m),
            _CarteVariables(
              variables: macro.variables,
              onChange: _changeVariables,
            ),
            const SizedBox(height: Pas.m),
            ShadCard(
              padding: const EdgeInsets.all(Pas.m),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Section(T.actionsMacro),
                  _ListeEtapes(
                    etapes: macro.etapes,
                    chemin: const [],
                    variables: macro.variables,
                    onAjoute: _ajoute,
                    onAjouteTouche: _ajouteTouche,
                    onAjouteClic: _ajouteClic,
                    onRemplace: _remplace,
                    onSupprime: _supprime,
                    onDeplace: _deplace,
                    onVise: _vise,
                    raccourcis: widget.macros,
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

/// Une suite de gestes, et de quoi en ajouter.
///
/// Se rappelle elle-meme pour le contenu d'une boucle, avec un chemin d'un
/// cran plus long.
class _ListeEtapes extends StatelessWidget {
  const _ListeEtapes({
    required this.etapes,
    required this.chemin,
    required this.variables,
    required this.onAjoute,
    required this.onAjouteTouche,
    required this.onAjouteClic,
    required this.onRemplace,
    required this.onSupprime,
    required this.onDeplace,
    required this.onVise,
    required this.raccourcis,
  });

  final List<Etape> etapes;
  final List<int> chemin;
  final List<Variable> variables;
  final void Function(List<int>, Etape) onAjoute;
  final Future<void> Function(List<int>) onAjouteTouche;
  final Future<void> Function(List<int>) onAjouteClic;
  final void Function(List<int>, int, Etape) onRemplace;
  final void Function(List<int>, int) onSupprime;
  final void Function(List<int>, int, int) onDeplace;
  final Future<void> Function({List<int>? chemin, int? rang, bool droit}) onVise;

  /// Pour la capture d'une touche depuis une ligne.
  final Macros raccourcis;

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (etapes.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: Pas.s),
            child: Text(T.macroVide, style: theme.textTheme.muted),
          )
        else
          for (var i = 0; i < etapes.length; i++)
            if (etapes[i] case final EtapeBoucle boucle)
              _CarteBoucle(
                key: ValueKey('${chemin.join('.')}#$i'),
                boucle: boucle,
                rang: i,
                chemin: chemin,
                variables: variables,
                dernier: i == etapes.length - 1,
                onAjoute: onAjoute,
                onAjouteTouche: onAjouteTouche,
                onAjouteClic: onAjouteClic,
                onRemplace: onRemplace,
                onSupprime: onSupprime,
                onDeplace: onDeplace,
                onVise: onVise,
                raccourcis: raccourcis,
              )
            else
              _LigneEtape(
                // Le chemin et le rang, non le contenu : deux pauses de cent
                // millisecondes se ressemblent, et l'etat de saisie doit
                // suivre la ligne, pas la valeur.
                key: ValueKey('${chemin.join('.')}#$i'),
                rang: i,
                etape: etapes[i],
                dernier: i == etapes.length - 1,
                onChange: (e) => onRemplace(chemin, i, e),
                onSupprime: () => onSupprime(chemin, i),
                onMonte: () => onDeplace(chemin, i, -1),
                onDescend: () => onDeplace(chemin, i, 1),
                onTouche: () async {
                  final courant = etapes[i];
                  final choix = await captureUnRaccourci(
                    context,
                    raccourcis.raccourcis,
                    titre: T.ajouterTouche,
                    initial: courant is EtapeTouche ? courant.raccourci : null,
                  );
                  final raccourci = choix?.raccourci;
                  if (raccourci != null) {
                    onRemplace(chemin, i, EtapeTouche(raccourci));
                  }
                },
                onVise: (droit) =>
                    onVise(chemin: chemin, rang: i, droit: droit),
              ),
        const SizedBox(height: Pas.s),
        Wrap(
          children: [
            _Ajout(
              icone: LucideIcons.type,
              libelle: T.ajouterTexte,
              onTap: () => onAjoute(chemin, const EtapeTexte('')),
            ),
            _Ajout(
              icone: LucideIcons.keyboard,
              libelle: T.ajouterTouche,
              onTap: () => onAjouteTouche(chemin),
            ),
            _Ajout(
              icone: LucideIcons.mousePointerClick,
              libelle: T.ajouterClic,
              onTap: () => onAjouteClic(chemin),
            ),
            _Ajout(
              icone: LucideIcons.timer,
              libelle: T.ajouterPause,
              onTap: () => onAjoute(chemin, const EtapePause(100)),
            ),
            _Ajout(
              icone: LucideIcons.appWindow,
              libelle: T.ajouterFenetre,
              onTap: () => onAjoute(chemin, const EtapeFenetre('')),
            ),
            _Ajout(
              icone: LucideIcons.repeat,
              libelle: T.ajouterBoucle,
              onTap: () => onAjoute(chemin, const EtapeBoucle()),
            ),
          ],
        ),
      ],
    );
  }
}

class _Ajout extends StatelessWidget {
  const _Ajout({
    required this.icone,
    required this.libelle,
    required this.onTap,
  });

  final IconData icone;
  final String libelle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: Pas.s, bottom: Pas.xs),
      child: ShadButton.outline(
        size: ShadButtonSize.sm,
        leading: Icon(icone, size: 14),
        onPressed: onTap,
        child: Text(libelle),
      ),
    );
  }
}

/// Une boucle : son reglage, et ce qu'elle repete.
class _CarteBoucle extends StatelessWidget {
  const _CarteBoucle({
    super.key,
    required this.boucle,
    required this.rang,
    required this.chemin,
    required this.variables,
    required this.dernier,
    required this.onAjoute,
    required this.onAjouteTouche,
    required this.onAjouteClic,
    required this.onRemplace,
    required this.onSupprime,
    required this.onDeplace,
    required this.onVise,
    required this.raccourcis,
  });

  final EtapeBoucle boucle;
  final int rang;
  final List<int> chemin;
  final List<Variable> variables;
  final bool dernier;
  final void Function(List<int>, Etape) onAjoute;
  final Future<void> Function(List<int>) onAjouteTouche;
  final Future<void> Function(List<int>) onAjouteClic;
  final void Function(List<int>, int, Etape) onRemplace;
  final void Function(List<int>, int) onSupprime;
  final void Function(List<int>, int, int) onDeplace;
  final Future<void> Function({List<int>? chemin, int? rang, bool droit}) onVise;
  final Macros raccourcis;

  /// Le nombre de valeurs de la variable parcourue. Zero quand elle a ete
  /// renommee ou supprimee depuis : la boucle ne fera alors aucun tour, et le
  /// libelle le dit avant qu'on la joue.
  int _combien() {
    for (final variable in variables) {
      if (variable.nom == boucle.liste) return variable.valeurs.length;
    }
    return 0;
  }

  Future<void> _regle(BuildContext context) async {
    final choisi = await regleUneBoucle(context, boucle, variables);
    if (choisi == null) return;
    onRemplace(chemin, rang, choisi);
  }

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: Pas.xs),
      child: Container(
        decoration: BoxDecoration(
          border: Border(
            left: BorderSide(
              color: theme.colorScheme.primary.withValues(alpha: 0.45),
              width: 2,
            ),
          ),
        ),
        padding: const EdgeInsets.only(left: Pas.m),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(
                  LucideIcons.repeat,
                  size: 14,
                  color: theme.colorScheme.mutedForeground,
                ),
                const SizedBox(width: Pas.s),
                Text(T.etapeBoucle, style: theme.textTheme.muted),
                const SizedBox(width: Pas.s),
                ShadButton.ghost(
                  size: ShadButtonSize.sm,
                  onPressed: () => _regle(context),
                  child: Text(
                    boucle.parcourt
                        ? T.pourChaque(boucle.liste, _combien())
                        : T.repeterNFois(boucle.repetitions),
                  ),
                ),
                const Spacer(),
                ShadTooltip(
                  builder: (_) => Text(T.monter),
                  child: ShadIconButton.ghost(
                    icon: const Icon(LucideIcons.chevronUp, size: 14),
                    onPressed: rang == 0
                        ? null
                        : () => onDeplace(chemin, rang, -1),
                  ),
                ),
                ShadTooltip(
                  builder: (_) => Text(T.descendre),
                  child: ShadIconButton.ghost(
                    icon: const Icon(LucideIcons.chevronDown, size: 14),
                    onPressed: dernier
                        ? null
                        : () => onDeplace(chemin, rang, 1),
                  ),
                ),
                ShadIconButton.ghost(
                  icon: const Icon(LucideIcons.trash2, size: 14),
                  onPressed: () => onSupprime(chemin, rang),
                ),
              ],
            ),
            _ListeEtapes(
              etapes: boucle.etapes,
              chemin: [...chemin, rang],
              variables: variables,
              onAjoute: onAjoute,
              onAjouteTouche: onAjouteTouche,
              onAjouteClic: onAjouteClic,
              onRemplace: onRemplace,
              onSupprime: onSupprime,
              onDeplace: onDeplace,
              onVise: onVise,
              raccourcis: raccourcis,
            ),
          ],
        ),
      ),
    );
  }
}

/// Le reglage d'une boucle : un nombre de tours, ou une variable a parcourir.
///
/// Une question fermee : c'est le seul endroit de l'editeur ou une fenetre se
/// justifie.
Future<EtapeBoucle?> regleUneBoucle(
  BuildContext context,
  EtapeBoucle boucle,
  List<Variable> variables,
) {
  final tours = TextEditingController(text: '${boucle.repetitions}');
  return showShadDialog<EtapeBoucle>(
    context: context,
    builder: (contexte) {
      final theme = ShadTheme.of(contexte);
      return ShadDialog(
        title: Text(T.reglerBoucle),
        actions: [
          ShadButton.ghost(
            onPressed: () => Navigator.of(contexte).pop(),
            child: Text(T.annuler),
          ),
          ShadButton(
            onPressed: () {
              final n = int.tryParse(tours.text.trim()) ?? boucle.repetitions;
              Navigator.of(contexte).pop(
                EtapeBoucle(
                  etapes: boucle.etapes,
                  repetitions: n.clamp(1, 1000),
                ),
              );
            },
            child: Text(T.valider),
          ),
        ],
        child: SizedBox(
          width: 360,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: Pas.m),
              Section(T.nombreDeTours),
              ShadInput(
                controller: tours,
                keyboardType: TextInputType.number,
                autofocus: true,
              ),
              const SizedBox(height: Pas.l),
              Section(T.parcourirVariable),
              if (variables.isEmpty)
                Text(T.aucuneVariable, style: theme.textTheme.muted)
              else
                for (final variable in variables)
                  Padding(
                    padding: const EdgeInsets.only(bottom: Pas.xs),
                    child: ShadButton.outline(
                      size: ShadButtonSize.sm,
                      onPressed: () => Navigator.of(contexte).pop(
                        EtapeBoucle(
                          etapes: boucle.etapes,
                          repetitions: boucle.repetitions,
                          liste: variable.nom,
                        ),
                      ),
                      child: Text(
                        '${variable.nom} · ${T.valeurs(variable.valeurs.length)}',
                      ),
                    ),
                  ),
            ],
          ),
        ),
      );
    },
  );
}

/// Un geste simple, tel qu'il se modifie sur place.
class _LigneEtape extends StatefulWidget {
  const _LigneEtape({
    super.key,
    required this.rang,
    required this.etape,
    required this.dernier,
    required this.onChange,
    required this.onSupprime,
    required this.onMonte,
    required this.onDescend,
    required this.onTouche,
    required this.onVise,
  });

  final int rang;
  final Etape etape;
  final bool dernier;
  final void Function(Etape) onChange;
  final VoidCallback onSupprime;
  final VoidCallback onMonte;
  final VoidCallback onDescend;
  final VoidCallback onTouche;
  final Future<void> Function(bool droit) onVise;

  @override
  State<_LigneEtape> createState() => _LigneEtapeState();
}

class _LigneEtapeState extends State<_LigneEtape> {
  late final TextEditingController _saisie = TextEditingController(
    text: _contenu(widget.etape),
  );

  Timer? _repos;

  static String _contenu(Etape etape) => switch (etape) {
    EtapeTexte(:final texte) => texte,
    EtapePause(:final millisecondes) => '$millisecondes',
    EtapeFenetre(:final titre) => titre,
    EtapeTouche() || EtapeClic() || EtapeBoucle() => '',
  };

  /// La ligne a change de contenu sans qu'on ait tape dedans : c'est un
  /// deplacement ou une suppression plus haut dans la liste, et le champ doit
  /// suivre.
  ///
  /// Les cles des lignes sont leur **position**. Une ligne qui garderait le
  /// texte de celle qu'elle etait avant le rendrait a la premiere occasion, et
  /// c'est ainsi qu'un texte se dupliquait quand on montait une boucle
  /// par-dessus lui.
  @override
  void didUpdateWidget(covariant _LigneEtape ancien) {
    super.didUpdateWidget(ancien);
    if (widget.etape == ancien.etape) return;
    if (_repos?.isActive ?? false) return;
    final attendu = _contenu(widget.etape);
    if (attendu != _saisie.text) _saisie.text = attendu;
  }

  @override
  void dispose() {
    // Uniquement ce qui vient d'etre tape. Ecrire dans tous les cas rendait la
    // ligne a sa **position**, qui ne designe plus le meme geste des qu'on
    // supprime ou deplace : le geste voisin s'en trouvait ecrase.
    final enAttente = _repos?.isActive ?? false;
    _repos?.cancel();
    if (enAttente) _range();
    _saisie.dispose();
    super.dispose();
  }

  void _apresLaFrappe() {
    _repos?.cancel();
    _repos = Timer(_reposClavier, _range);
  }

  void _range() {
    switch (widget.etape) {
      case EtapeTexte(:final cadence):
        widget.onChange(EtapeTexte(_saisie.text, cadence: cadence));
      case EtapePause():
        final ms = int.tryParse(_saisie.text.trim());
        if (ms != null) widget.onChange(EtapePause(ms.clamp(0, 60000)));
      case EtapeFenetre():
        widget.onChange(EtapeFenetre(_saisie.text.trim()));
      case EtapeTouche() || EtapeClic() || EtapeBoucle():
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);
    final (libelle, icone) = switch (widget.etape) {
      EtapeTexte() => (T.etapeTexte, LucideIcons.type),
      EtapeTouche() => (T.etapeTouche, LucideIcons.keyboard),
      EtapeClic() => (T.etapeClic, LucideIcons.mousePointerClick),
      EtapePause() => (T.etapePause, LucideIcons.timer),
      EtapeFenetre() => (T.etapeFenetre, LucideIcons.appWindow),
      EtapeBoucle() => (T.etapeBoucle, LucideIcons.repeat),
    };
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          SizedBox(
            width: 22,
            child: Text(
              '${widget.rang + 1}',
              style: theme.textTheme.muted.copyWith(fontSize: 11),
            ),
          ),
          Icon(icone, size: 14, color: theme.colorScheme.mutedForeground),
          const SizedBox(width: Pas.s),
          SizedBox(
            width: 64,
            child: Text(libelle, style: theme.textTheme.muted),
          ),
          const SizedBox(width: Pas.s),
          Expanded(child: _corps(theme)),
          ShadTooltip(
            builder: (_) => Text(T.monter),
            child: ShadIconButton.ghost(
              icon: const Icon(LucideIcons.chevronUp, size: 14),
              onPressed: widget.rang == 0 ? null : widget.onMonte,
            ),
          ),
          ShadTooltip(
            builder: (_) => Text(T.descendre),
            child: ShadIconButton.ghost(
              icon: const Icon(LucideIcons.chevronDown, size: 14),
              onPressed: widget.dernier ? null : widget.onDescend,
            ),
          ),
          ShadIconButton.ghost(
            icon: const Icon(LucideIcons.trash2, size: 14),
            onPressed: widget.onSupprime,
          ),
        ],
      ),
    );
  }

  Widget _corps(ShadThemeData theme) {
    switch (widget.etape) {
      case EtapeTexte(:final cadence):
        return Row(
          children: [
            Expanded(
              child: ShadInput(
                controller: _saisie,
                placeholder: Text(T.texteAEcrire),
                onChanged: (_) => _apresLaFrappe(),
                onSubmitted: (_) => _range(),
              ),
            ),
            const SizedBox(width: Pas.s),
            ShadTooltip(
              builder: (_) => Text(T.cadenceProfil),
              child: _Cadence(
                cadence: cadence,
                onChange: (choisie) => widget.onChange(
                  EtapeTexte(_saisie.text, cadence: choisie),
                ),
              ),
            ),
          ],
        );
      case EtapeTouche(:final raccourci):
        return Row(
          children: [
            EtiquetteRaccourci(raccourci: raccourci, onTap: widget.onTouche),
            const Spacer(),
          ],
        );
      case EtapePause():
        return Row(
          children: [
            SizedBox(
              width: 96,
              child: ShadInput(
                controller: _saisie,
                keyboardType: TextInputType.number,
                onChanged: (_) => _apresLaFrappe(),
                onSubmitted: (_) => _range(),
              ),
            ),
            const SizedBox(width: Pas.s),
            Text('ms', style: theme.textTheme.muted),
          ],
        );
      case EtapeClic(:final x, :final y, :final droit):
        return Row(
          children: [
            Text('$x, $y', style: theme.textTheme.small),
            const SizedBox(width: Pas.m),
            ShadButton.ghost(
              size: ShadButtonSize.sm,
              onPressed: () =>
                  widget.onChange(EtapeClic(x, y, droit: !droit)),
              child: Text(droit ? T.clicDroit : T.clicGauche),
            ),
            const SizedBox(width: Pas.xs),
            ShadButton.ghost(
              size: ShadButtonSize.sm,
              leading: const Icon(LucideIcons.crosshair, size: 14),
              onPressed: () => widget.onVise(droit),
              child: Text(T.viser),
            ),
            const Spacer(),
          ],
        );
      case EtapeFenetre():
        return ShadInput(
          controller: _saisie,
          placeholder: Text(T.fenetreAide),
          onChanged: (_) => _apresLaFrappe(),
          onSubmitted: (_) => _range(),
        );
      case EtapeBoucle():
        // Une boucle a sa propre carte : cette ligne ne la rencontre pas.
        return const SizedBox.shrink();
    }
  }
}

/// Le rythme de la frappe : trois etats, du plus lent au plus rapide.
///
/// Une barre plutot qu'un nombre : ce qui se regle ici n'est pas une duree
/// mais un compromis, et il n'y a que trois reponses utiles.
class _Cadence extends StatelessWidget {
  const _Cadence({required this.cadence, required this.onChange});

  final int cadence;
  final void Function(int) onChange;

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);
    return Container(
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: theme.colorScheme.muted,
        border: Border.all(color: theme.colorScheme.border),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final rang in EtapeTexte.cadences)
            if (rang == cadence)
              ShadButton(
                size: ShadButtonSize.sm,
                onPressed: () {},
                child: Text(T.cadenceFrappe(rang)),
              )
            else
              ShadButton.ghost(
                size: ShadButtonSize.sm,
                onPressed: () => onChange(rang),
                child: Text(T.cadenceFrappe(rang)),
              ),
        ],
      ),
    );
  }
}

/// Les variables de la macro.
class _CarteVariables extends StatelessWidget {
  const _CarteVariables({required this.variables, required this.onChange});

  final List<Variable> variables;
  final void Function(List<Variable>) onChange;

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);
    return ShadCard(
      padding: const EdgeInsets.all(Pas.m),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Section(T.variablesMacro),
          if (variables.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: Pas.s),
              child: Text(T.aucuneVariable, style: theme.textTheme.muted),
            )
          else
            for (var i = 0; i < variables.length; i++)
              _LigneVariable(
                key: ValueKey('variable#$i'),
                variable: variables[i],
                onChange: (v) => onChange([
                  for (var k = 0; k < variables.length; k++)
                    if (k == i) v else variables[k],
                ]),
                onSupprime: () => onChange([
                  for (var k = 0; k < variables.length; k++)
                    if (k != i) variables[k],
                ]),
              ),
          const SizedBox(height: Pas.s),
          Row(
            children: [
              ShadButton.outline(
                size: ShadButtonSize.sm,
                leading: const Icon(LucideIcons.plus, size: 14),
                onPressed: () => onChange([
                  ...variables,
                  Variable(nom: 'liste${variables.length + 1}'),
                ]),
                child: Text(T.ajouterVariable),
              ),
              const SizedBox(width: Pas.m),
              Expanded(
                child: Text(T.valeursAide, style: theme.textTheme.muted),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _LigneVariable extends StatefulWidget {
  const _LigneVariable({
    super.key,
    required this.variable,
    required this.onChange,
    required this.onSupprime,
  });

  final Variable variable;
  final void Function(Variable) onChange;
  final VoidCallback onSupprime;

  @override
  State<_LigneVariable> createState() => _LigneVariableState();
}

class _LigneVariableState extends State<_LigneVariable> {
  late final TextEditingController _nom = TextEditingController(
    text: widget.variable.nom,
  );
  late final TextEditingController _valeurs = TextEditingController(
    text: widget.variable.valeurs.join('\n'),
  );
  Timer? _repos;

  @override
  void didUpdateWidget(covariant _LigneVariable ancien) {
    super.didUpdateWidget(ancien);
    if (widget.variable == ancien.variable) return;
    if (_repos?.isActive ?? false) return;
    if (_nom.text != widget.variable.nom) _nom.text = widget.variable.nom;
    final valeurs = widget.variable.valeurs.join('\n');
    if (_valeurs.text != valeurs) _valeurs.text = valeurs;
  }

  @override
  void dispose() {
    // Comme pour un geste : ecrire depuis `dispose` rendait la variable qu'on
    // venait de supprimer, la ligne etant designee par son rang.
    final enAttente = _repos?.isActive ?? false;
    _repos?.cancel();
    if (enAttente) _range();
    _nom.dispose();
    _valeurs.dispose();
    super.dispose();
  }

  void _apresLaFrappe() {
    _repos?.cancel();
    _repos = Timer(_reposClavier, _range);
  }

  void _range() {
    final nom = _nom.text.trim();
    widget.onChange(
      Variable(
        nom: nom.isEmpty ? widget.variable.nom : nom,
        valeurs: [
          for (final ligne in _valeurs.text.split('\n'))
            if (ligne.trim().isNotEmpty) ligne.trim(),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 160,
            child: ShadInput(
              controller: _nom,
              placeholder: Text(T.nomVariable),
              onChanged: (_) => _apresLaFrappe(),
              onSubmitted: (_) => _range(),
            ),
          ),
          const SizedBox(width: Pas.s),
          Expanded(
            child: ShadInput(
              controller: _valeurs,
              placeholder: Text(T.valeursVariable),
              maxLines: 4,
              minLines: 1,
              onChanged: (_) => _apresLaFrappe(),
            ),
          ),
          ShadIconButton.ghost(
            icon: const Icon(LucideIcons.trash2, size: 14),
            onPressed: widget.onSupprime,
          ),
        ],
      ),
    );
  }
}
