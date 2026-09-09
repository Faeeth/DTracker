/// Ce qui s'ouvre depuis la page Organizer : nommer une equipe, decrire un
/// personnage, capturer une touche.
///
/// Des fenetres et non des pages, contrairement au reste de la vue standard :
/// ce sont des questions fermees, on y repond et on revient a la liste.
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shadcn_ui/shadcn_ui.dart' hide Cache;

import '../../../i18n/textes.dart';
import '../../../modele/organizer.dart';
import '../../../source/organizer.dart';
import '../../../source/ressources.dart';
import '../briques.dart';

// ---------------------------------------------------------------- equipes

Future<void> nouvelleEquipe(BuildContext context, Organizer organizer) async {
  final nom = await demandeUnNom(context, T.nouvelleEquipe);
  if (nom != null) organizer.ajouteEquipe(nom);
}

/// Renommer ou supprimer : deux gestes rares, sortis de la barre de titre pour
/// ne pas l'encombrer.
Future<void> menuEquipe(
  BuildContext context,
  Organizer organizer,
  EquipeOrganizer equipe,
) async {
  final choix = await showShadDialog<String>(
    context: context,
    builder: (contexte) => ShadDialog(
      title: Text(equipe.nom),
      actions: [
        ShadButton.ghost(
          onPressed: () => Navigator.of(contexte).pop(),
          child: Text(T.annuler),
        ),
        ShadButton.outline(
          onPressed: () => Navigator.of(contexte).pop('renomme'),
          child: Text(T.renommerEquipe),
        ),
        ShadButton.destructive(
          onPressed: () => Navigator.of(contexte).pop('supprime'),
          child: Text(T.supprimerEquipe),
        ),
      ],
      child: const SizedBox.shrink(),
    ),
  );
  if (!context.mounted || choix == null) return;

  if (choix == 'renomme') {
    final nom = await demandeUnNom(context, T.renommerEquipe, equipe.nom);
    if (nom != null) organizer.renommeEquipe(equipe.id, nom);
    return;
  }

  final confirme = await showShadDialog<bool>(
    context: context,
    builder: (contexte) => ShadDialog.alert(
      title: Text(T.supprimerEquipe),
      description: Padding(
        padding: const EdgeInsets.only(top: Pas.s),
        child: Text(
          T.supprimerEquipeDetail(equipe.nom, equipe.personnages.length),
        ),
      ),
      actions: [
        ShadButton.ghost(
          onPressed: () => Navigator.of(contexte).pop(false),
          child: Text(T.annuler),
        ),
        ShadButton.destructive(
          onPressed: () => Navigator.of(contexte).pop(true),
          child: Text(T.supprimer),
        ),
      ],
      child: const SizedBox.shrink(),
    ),
  );
  if (confirme ?? false) organizer.supprimeEquipe(equipe.id);
}

/// Une saisie de nom, pour l'equipe qu'on cree comme pour celle qu'on renomme.
Future<String?> demandeUnNom(
  BuildContext context,
  String titre, [
  String initial = '',
]) {
  final saisie = TextEditingController(text: initial);
  return showShadDialog<String>(
    context: context,
    builder: (contexte) {
      void valide() {
        final nom = saisie.text.trim();
        if (nom.isNotEmpty) Navigator.of(contexte).pop(nom);
      }

      return ShadDialog(
        title: Text(titre),
        actions: [
          ShadButton.ghost(
            onPressed: () => Navigator.of(contexte).pop(),
            child: Text(T.annuler),
          ),
          ShadButton(onPressed: valide, child: Text(T.valider)),
        ],
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: Pas.m),
          child: SizedBox(
            width: 320,
            child: ShadInput(
              controller: saisie,
              autofocus: true,
              placeholder: Text(T.nom),
              onSubmitted: (_) => valide(),
            ),
          ),
        ),
      );
    },
  );
}

// ------------------------------------------------------------ personnages

Future<void> nouveauPersonnage(
  BuildContext context,
  Organizer organizer,
  Ressources res,
  String equipeId,
) async {
  final brouillon = await _editePersonnage(context, organizer, res);
  if (brouillon == null) return;
  organizer.ajoutePersonnage(
    equipeId,
    nom: brouillon.nom,
    titre: brouillon.titre,
    raccourci: brouillon.raccourci,
    classe: brouillon.classe,
    feminin: brouillon.feminin,
  );
}

Future<void> modifiePersonnage(
  BuildContext context,
  Organizer organizer,
  Ressources res,
  String equipeId,
  PersonnageOrganizer personnage,
) async {
  final brouillon = await _editePersonnage(
    context,
    organizer,
    res,
    personnage: personnage,
  );
  if (brouillon == null) return;
  organizer.modifiePersonnage(
    equipeId,
    personnage.id,
    nom: brouillon.nom,
    titre: brouillon.titre,
    raccourci: brouillon.raccourci,
    effaceRaccourci: brouillon.raccourci == null,
    classe: brouillon.classe,
    effaceClasse: brouillon.classe == null,
    feminin: brouillon.feminin,
  );
}

/// Change la touche d'un personnage sans passer par la fiche entiere.
Future<void> changeRaccourci(
  BuildContext context,
  Organizer organizer,
  String equipeId,
  PersonnageOrganizer personnage,
) async {
  final choix = await captureUnRaccourci(
    context,
    organizer,
    titre: T.raccourciDe(personnage.nom),
    initial: personnage.raccourci,
  );
  if (choix == null) return;
  organizer.modifiePersonnage(
    equipeId,
    personnage.id,
    raccourci: choix.raccourci,
    effaceRaccourci: choix.raccourci == null,
  );
}

class _Brouillon {
  const _Brouillon(
    this.nom,
    this.titre,
    this.raccourci,
    this.classe,
    this.feminin,
  );
  final String nom;
  final String titre;
  final Raccourci? raccourci;
  final int? classe;
  final bool feminin;
}

Future<_Brouillon?> _editePersonnage(
  BuildContext context,
  Organizer organizer,
  Ressources res, {
  PersonnageOrganizer? personnage,
}) {
  return showShadDialog<_Brouillon>(
    context: context,
    builder: (contexte) => _FichePersonnage(
      organizer: organizer,
      res: res,
      personnage: personnage,
    ),
  );
}

class _FichePersonnage extends StatefulWidget {
  const _FichePersonnage({
    required this.organizer,
    required this.res,
    this.personnage,
  });

  final Organizer organizer;
  final Ressources res;
  final PersonnageOrganizer? personnage;

  @override
  State<_FichePersonnage> createState() => _FichePersonnageState();
}

class _FichePersonnageState extends State<_FichePersonnage> {
  late final TextEditingController _nom = TextEditingController(
    text: widget.personnage?.nom ?? '',
  );
  late final TextEditingController _titre = TextEditingController(
    text: widget.personnage?.titre ?? '',
  );
  late Raccourci? _raccourci = widget.personnage?.raccourci;
  late int? _classe = widget.personnage?.classe;
  late bool _feminin = widget.personnage?.feminin ?? false;

  /// Tant que le titre n'a pas ete saisi, il suit le nom : c'est ce que le
  /// client affiche dans la plupart des installations.
  late bool _titreSuitLeNom = widget.personnage == null;

  String? _essai;

  @override
  void dispose() {
    _nom.dispose();
    _titre.dispose();
    super.dispose();
  }

  String get _titreEffectif {
    final saisi = _titre.text.trim();
    return saisi.isEmpty ? _nom.text.trim() : saisi;
  }

  Future<void> _choisitRaccourci() async {
    final nom = _nom.text.trim();
    final choix = await captureUnRaccourci(
      context,
      widget.organizer,
      titre: T.raccourciDe(nom.isEmpty ? T.nouveauPersonnage : nom),
      initial: _raccourci,
    );
    if (choix == null || !mounted) return;
    setState(() => _raccourci = choix.raccourci);
  }

  Future<void> _teste() async {
    final titre = _titreEffectif;
    if (titre.isEmpty) return;
    final trouve = await widget.organizer.essaie(titre);
    if (!mounted) return;
    setState(
      () => _essai = trouve ? T.fenetreTrouvee : T.fenetreIntrouvable(titre),
    );
  }

  Future<void> _choisitClasse() async {
    final choix = await choisitUneClasse(
      context,
      widget.res,
      classe: _classe,
      feminin: _feminin,
    );
    if (choix == null || !mounted) return;
    setState(() {
      _classe = choix.classe;
      _feminin = choix.feminin;
    });
  }

  void _valide() {
    final nom = _nom.text.trim();
    if (nom.isEmpty) return;
    Navigator.of(
      context,
    ).pop(_Brouillon(nom, _titreEffectif, _raccourci, _classe, _feminin));
  }

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);
    final nouveau = widget.personnage == null;
    return ShadDialog(
      title: Text(nouveau ? T.nouveauPersonnage : T.modifierPersonnage),
      actions: [
        ShadButton.ghost(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(T.annuler),
        ),
        ShadButton(
          onPressed: _nom.text.trim().isEmpty ? null : _valide,
          child: Text(nouveau ? T.ajouter : T.enregistrer),
        ),
      ],
      child: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: Pas.m),
            Section(T.nom),
            ShadInput(
              controller: _nom,
              autofocus: true,
              onChanged: (valeur) {
                if (_titreSuitLeNom) _titre.text = valeur;
                setState(() {});
              },
              onSubmitted: (_) => _valide(),
            ),
            const SizedBox(height: Pas.m),
            Section(T.titreFenetre),
            ShadInput(
              controller: _titre,
              onChanged: (valeur) {
                _titreSuitLeNom = valeur.trim().isEmpty;
                setState(() {});
              },
              onSubmitted: (_) => _valide(),
            ),
            const SizedBox(height: Pas.xs),
            Text(T.titreFenetreAide, style: theme.textTheme.muted),
            // Sans images extraites, il n'y a rien a montrer ni a choisir :
            // la fiche se passe alors de la classe plutot que d'afficher une
            // grille vide.
            if (widget.res.classesConnues.isNotEmpty) ...[
              const SizedBox(height: Pas.l),
              Row(
                children: [
                  Text(T.classePersonnage, style: theme.textTheme.muted),
                  const SizedBox(width: Pas.m),
                  PortraitClasse(
                    res: widget.res,
                    classe: _classe,
                    feminin: _feminin,
                    taille: 32,
                  ),
                  const SizedBox(width: Pas.s),
                  Text(
                    widget.res.classe(_classe) ?? T.sansClasse,
                    style: theme.textTheme.small,
                  ),
                  const Spacer(),
                  ShadButton.ghost(
                    onPressed: _choisitClasse,
                    child: Text(_classe == null ? T.choisir : T.changer),
                  ),
                ],
              ),
            ],
            const SizedBox(height: Pas.l),
            Row(
              children: [
                Text(T.raccourci, style: theme.textTheme.muted),
                const SizedBox(width: Pas.m),
                EtiquetteRaccourci(
                  raccourci: _raccourci,
                  onTap: _choisitRaccourci,
                ),
                const Spacer(),
                ShadButton.ghost(
                  leading: const Icon(LucideIcons.crosshair, size: 14),
                  onPressed: _titreEffectif.isEmpty ? null : _teste,
                  child: Text(T.tester),
                ),
              ],
            ),
            if (_essai != null) ...[
              const SizedBox(height: Pas.s),
              Text(_essai!, style: theme.textTheme.muted),
            ],
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------- classes

/// Le portrait d'un personnage, ou un pictogramme quand il n'a pas de classe.
///
/// Les images ne sont pas embarquees : quand l'extraction manque, le fichier
/// est absent et l'on retombe sur le meme pictogramme.
class PortraitClasse extends StatelessWidget {
  const PortraitClasse({
    super.key,
    required this.res,
    required this.classe,
    this.feminin = false,
    this.taille = 26,
    this.eteint = false,
  });

  final Ressources res;
  final int? classe;
  final bool feminin;
  final double taille;

  /// Personnage ou equipe ecarte : le portrait s'efface comme le reste de la
  /// ligne.
  final bool eteint;

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);
    final chemin = res.imageClasse(classe, feminin: feminin);
    final Widget image = chemin == null
        ? Center(
            child: Icon(
              LucideIcons.user,
              size: taille * 0.55,
              color: theme.colorScheme.mutedForeground,
            ),
          )
        : Image.file(
            File(chemin),
            filterQuality: FilterQuality.medium,
            errorBuilder: (_, _, _) => const SizedBox.shrink(),
          );
    return Opacity(
      opacity: eteint ? 0.45 : 1,
      child: SizedBox(width: taille, height: taille, child: image),
    );
  }
}

/// Ce que la grille a produit. Un resultat nul veut dire qu'on a renonce.
class ChoixClasse {
  const ChoixClasse(this.classe, this.feminin);
  final int? classe;
  final bool feminin;
}

Future<ChoixClasse?> choisitUneClasse(
  BuildContext context,
  Ressources res, {
  int? classe,
  bool feminin = false,
}) {
  return showShadDialog<ChoixClasse>(
    context: context,
    builder: (contexte) =>
        _Classes(res: res, initiale: classe, feminin: feminin),
  );
}

/// Toutes les classes en portraits, dans l'ordre du jeu.
///
/// Le sexe se choisit avant : les deux portraits d'une meme classe se
/// ressemblent assez pour qu'on veuille voir celui qu'on prendra.
class _Classes extends StatefulWidget {
  const _Classes({required this.res, this.initiale, this.feminin = false});

  final Ressources res;
  final int? initiale;
  final bool feminin;

  @override
  State<_Classes> createState() => _ClassesState();
}

class _ClassesState extends State<_Classes> {
  late int? _classe = widget.initiale;
  late bool _feminin = widget.feminin;

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);
    final classes = widget.res.classesConnues;
    return ShadDialog(
      title: Text(T.classePersonnage),
      actions: [
        ShadButton.ghost(
          onPressed: () =>
              Navigator.of(context).pop(const ChoixClasse(null, false)),
          child: Text(T.sansClasse),
        ),
        ShadButton.ghost(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(T.annuler),
        ),
        ShadButton(
          onPressed: _classe == null
              ? null
              : () => Navigator.of(context).pop(ChoixClasse(_classe, _feminin)),
          child: Text(T.valider),
        ),
      ],
      child: SizedBox(
        width: 460,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: Pas.m),
            Row(
              children: [
                for (final (feminin, libelle) in [
                  (false, T.masculin),
                  (true, T.feminin),
                ]) ...[
                  if (feminin == _feminin)
                    ShadButton(
                      size: ShadButtonSize.sm,
                      onPressed: () {},
                      child: Text(libelle),
                    )
                  else
                    ShadButton.outline(
                      size: ShadButtonSize.sm,
                      onPressed: () => setState(() => _feminin = feminin),
                      child: Text(libelle),
                    ),
                  const SizedBox(width: Pas.s),
                ],
              ],
            ),
            const SizedBox(height: Pas.m),
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 320),
              child: SingleChildScrollView(
                child: Wrap(
                  spacing: Pas.s,
                  runSpacing: Pas.s,
                  children: [
                    for (final id in classes)
                      _Vignette(
                        res: widget.res,
                        classe: id,
                        feminin: _feminin,
                        choisie: id == _classe,
                        onTap: () => setState(() => _classe = id),
                      ),
                  ],
                ),
              ),
            ),
            if (classes.isEmpty) ...[
              const SizedBox(height: Pas.s),
              Text(T.sansClasse, style: theme.textTheme.muted),
            ],
          ],
        ),
      ),
    );
  }
}

class _Vignette extends StatelessWidget {
  const _Vignette({
    required this.res,
    required this.classe,
    required this.feminin,
    required this.choisie,
    required this.onTap,
  });

  final Ressources res;
  final int classe;
  final bool feminin;
  final bool choisie;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);
    return ShadTooltip(
      builder: (_) => Text(res.classe(classe) ?? T.classeNumero(classe)),
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTap: onTap,
          child: Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: choisie
                  ? theme.colorScheme.primary.withValues(alpha: 0.12)
                  : theme.colorScheme.muted,
              border: Border.all(
                color: choisie
                    ? theme.colorScheme.primary
                    : theme.colorScheme.border,
                width: choisie ? 2 : 1,
              ),
              borderRadius: BorderRadius.circular(8),
            ),
            padding: const EdgeInsets.all(4),
            child: PortraitClasse(
              res: res,
              classe: classe,
              feminin: feminin,
              taille: 48,
            ),
          ),
        ),
      ),
    );
  }
}

// ------------------------------------------------------------- raccourcis

/// Ce que la capture a produit : un raccourci, ou rien quand on l'a efface.
/// Un resultat nul, lui, veut dire qu'on a renonce.
class ChoixRaccourci {
  const ChoixRaccourci(this.raccourci);
  final Raccourci? raccourci;
}

Future<ChoixRaccourci?> captureUnRaccourci(
  BuildContext context,
  Organizer organizer, {
  required String titre,
  Raccourci? initial,
}) {
  return showShadDialog<ChoixRaccourci>(
    context: context,
    barrierDismissible: false,
    builder: (contexte) =>
        _Capture(organizer: organizer, titre: titre, initial: initial),
  );
}

/// Saisit une combinaison.
///
/// Les raccourcis globaux sont relaches pendant ce temps : sans cela Windows
/// avalerait les touches deja enregistrees au lieu de les laisser arriver
/// jusqu'ici.
class _Capture extends StatefulWidget {
  const _Capture({required this.organizer, required this.titre, this.initial});

  final Organizer organizer;
  final String titre;
  final Raccourci? initial;

  @override
  State<_Capture> createState() => _CaptureState();
}

class _CaptureState extends State<_Capture> {
  final FocusNode _focus = FocusNode();
  late Raccourci? _capture = widget.initial;
  String? _erreur;

  @override
  void initState() {
    super.initState();
    widget.organizer.debuteCapture();
  }

  @override
  void dispose() {
    widget.organizer.termineCapture();
    _focus.dispose();
    super.dispose();
  }

  /// Toutes les touches sont acceptees : c'est l'utilisateur qui decide, et
  /// Windows tranchera a l'enregistrement. Seule Echap est reservee.
  KeyEventResult _touche(FocusNode noeud, KeyEvent evenement) {
    if (evenement is KeyDownEvent) {
      if (evenement.logicalKey == LogicalKeyboardKey.escape) {
        Navigator.of(context).pop();
      } else if (!estModificateur(evenement.logicalKey)) {
        _saisit(evenement.logicalKey);
      }
    }
    // Rien ne s'echappe pendant la capture, pas meme la tabulation.
    return KeyEventResult.handled;
  }

  Future<void> _saisit(LogicalKeyboardKey touche) async {
    var code = toucheVirtuelle(touche);
    // Ponctuation et touches mortes : leur code depend de la disposition, on
    // demande a Windows quelle touche produit ce caractere.
    if (code == null && touche.keyLabel.isNotEmpty) {
      final resolu = await widget.organizer.toucheDuCaractere(touche.keyLabel);
      if (resolu != 0) code = resolu;
    }
    if (!mounted) return;
    if (code == null) {
      setState(() => _erreur = T.raccourciImpossible);
      return;
    }
    final clavier = HardwareKeyboard.instance;
    var modificateurs = 0;
    if (clavier.isControlPressed) modificateurs |= Modificateur.ctrl;
    if (clavier.isAltPressed) modificateurs |= Modificateur.alt;
    if (clavier.isShiftPressed) modificateurs |= Modificateur.maj;
    if (clavier.isMetaPressed) modificateurs |= Modificateur.windows;
    setState(() {
      _capture = Raccourci(
        touche: code!,
        modificateurs: modificateurs,
        libelle: touche.keyLabel.isEmpty ? null : touche.keyLabel,
      );
      _erreur = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);
    return ShadDialog(
      title: Text(widget.titre),
      actions: [
        ShadButton.ghost(
          onPressed: () =>
              Navigator.of(context).pop(const ChoixRaccourci(null)),
          child: Text(T.effacer),
        ),
        ShadButton.ghost(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(T.annuler),
        ),
        ShadButton(
          onPressed: _capture == null
              ? null
              : () => Navigator.of(context).pop(ChoixRaccourci(_capture)),
          child: Text(T.valider),
        ),
      ],
      child: Focus(
        focusNode: _focus,
        autofocus: true,
        onKeyEvent: _touche,
        child: SizedBox(
          width: 360,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: Pas.m),
              Text(T.raccourciInvite, style: theme.textTheme.muted),
              const SizedBox(height: Pas.m),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: Pas.l),
                decoration: BoxDecoration(
                  color: theme.colorScheme.muted,
                  border: Border.all(color: theme.colorScheme.border),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Center(child: EtiquetteRaccourci(raccourci: _capture)),
              ),
              if (_erreur != null) ...[
                const SizedBox(height: Pas.s),
                Text(
                  _erreur!,
                  style: theme.textTheme.muted.copyWith(
                    color: theme.colorScheme.destructive,
                  ),
                ),
              ],
              const SizedBox(height: Pas.s),
              Text(T.raccourciAide, style: theme.textTheme.muted),
            ],
          ),
        ),
      ),
    );
  }
}

/// Le raccourci d'un personnage, tel qu'il se lit dans une liste.
class EtiquetteRaccourci extends StatelessWidget {
  const EtiquetteRaccourci({
    super.key,
    required this.raccourci,
    this.onTap,
    this.eteinte = false,
    this.enConflit = false,
  });

  final Raccourci? raccourci;
  final VoidCallback? onTap;

  /// Le raccourci existe mais ne repond pas : personnage ou equipe ecarte.
  final bool eteinte;

  /// Windows a refuse de l'enregistrer.
  final bool enConflit;

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);
    final Color texte;
    final Color bord;
    final Color fond;
    if (enConflit) {
      texte = theme.colorScheme.destructive;
      bord = theme.colorScheme.destructive;
      fond = theme.colorScheme.destructive.withValues(alpha: 0.12);
    } else if (raccourci == null || eteinte) {
      texte = theme.colorScheme.mutedForeground;
      bord = theme.colorScheme.border;
      fond = theme.colorScheme.muted;
    } else {
      texte = theme.colorScheme.primary;
      bord = theme.colorScheme.primary.withValues(alpha: 0.45);
      fond = theme.colorScheme.primary.withValues(alpha: 0.12);
    }

    final etiquette = Container(
      constraints: const BoxConstraints(minWidth: 64),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: fond,
        border: Border.all(color: bord),
        borderRadius: BorderRadius.circular(6),
      ),
      alignment: Alignment.center,
      child: Text(
        raccourci?.affichage ?? T.aucunRaccourci,
        style: theme.textTheme.small.copyWith(
          color: texte,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );

    if (onTap == null) return etiquette;
    return ShadTooltip(
      builder: (_) =>
          Text(enConflit ? T.raccourciRefuse : T.modifierRaccourci),
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(onTap: onTap, child: etiquette),
      ),
    );
  }
}

// ------------------------------------------------------------- clavier

/// Codes de touche virtuelle des touches sans caractere imprimable.
///
/// Non `const` : `LogicalKeyboardKey` redefinit `==`.
final Map<LogicalKeyboardKey, int> _touchesFixes = {
  LogicalKeyboardKey.backspace: 0x08,
  LogicalKeyboardKey.tab: 0x09,
  LogicalKeyboardKey.enter: 0x0D,
  LogicalKeyboardKey.pause: 0x13,
  LogicalKeyboardKey.capsLock: 0x14,
  LogicalKeyboardKey.escape: 0x1B,
  LogicalKeyboardKey.space: 0x20,
  LogicalKeyboardKey.pageUp: 0x21,
  LogicalKeyboardKey.pageDown: 0x22,
  LogicalKeyboardKey.end: 0x23,
  LogicalKeyboardKey.home: 0x24,
  LogicalKeyboardKey.arrowLeft: 0x25,
  LogicalKeyboardKey.arrowUp: 0x26,
  LogicalKeyboardKey.arrowRight: 0x27,
  LogicalKeyboardKey.arrowDown: 0x28,
  LogicalKeyboardKey.printScreen: 0x2C,
  LogicalKeyboardKey.insert: 0x2D,
  LogicalKeyboardKey.delete: 0x2E,
  LogicalKeyboardKey.contextMenu: 0x5D,
  LogicalKeyboardKey.numpadMultiply: 0x6A,
  LogicalKeyboardKey.numpadAdd: 0x6B,
  LogicalKeyboardKey.numpadSubtract: 0x6D,
  LogicalKeyboardKey.numpadDecimal: 0x6E,
  LogicalKeyboardKey.numpadDivide: 0x6F,
  LogicalKeyboardKey.numLock: 0x90,
  LogicalKeyboardKey.scrollLock: 0x91,
  // Le pave numerique partage `VK_RETURN` : Windows ne lui donne pas de code
  // distinct.
  LogicalKeyboardKey.numpadEnter: 0x0D,
};

final Set<LogicalKeyboardKey> _modificateurs = {
  LogicalKeyboardKey.control,
  LogicalKeyboardKey.controlLeft,
  LogicalKeyboardKey.controlRight,
  LogicalKeyboardKey.alt,
  LogicalKeyboardKey.altLeft,
  LogicalKeyboardKey.altRight,
  LogicalKeyboardKey.shift,
  LogicalKeyboardKey.shiftLeft,
  LogicalKeyboardKey.shiftRight,
  LogicalKeyboardKey.meta,
  LogicalKeyboardKey.metaLeft,
  LogicalKeyboardKey.metaRight,
};

const List<LogicalKeyboardKey> _fonctions = [
  LogicalKeyboardKey.f1, LogicalKeyboardKey.f2, LogicalKeyboardKey.f3,
  LogicalKeyboardKey.f4, LogicalKeyboardKey.f5, LogicalKeyboardKey.f6,
  LogicalKeyboardKey.f7, LogicalKeyboardKey.f8, LogicalKeyboardKey.f9,
  LogicalKeyboardKey.f10, LogicalKeyboardKey.f11, LogicalKeyboardKey.f12,
  LogicalKeyboardKey.f13, LogicalKeyboardKey.f14, LogicalKeyboardKey.f15,
  LogicalKeyboardKey.f16, LogicalKeyboardKey.f17, LogicalKeyboardKey.f18,
  LogicalKeyboardKey.f19, LogicalKeyboardKey.f20, LogicalKeyboardKey.f21,
  LogicalKeyboardKey.f22, LogicalKeyboardKey.f23, LogicalKeyboardKey.f24,
];

const List<LogicalKeyboardKey> _pave = [
  LogicalKeyboardKey.numpad0, LogicalKeyboardKey.numpad1,
  LogicalKeyboardKey.numpad2, LogicalKeyboardKey.numpad3,
  LogicalKeyboardKey.numpad4, LogicalKeyboardKey.numpad5,
  LogicalKeyboardKey.numpad6, LogicalKeyboardKey.numpad7,
  LogicalKeyboardKey.numpad8, LogicalKeyboardKey.numpad9,
];

/// Le code de touche virtuelle Win32 d'une touche logique, ou nul quand il
/// faudra le demander a Windows.
int? toucheVirtuelle(LogicalKeyboardKey touche) {
  final fonction = _fonctions.indexOf(touche);
  if (fonction >= 0) return 0x70 + fonction;
  final pave = _pave.indexOf(touche);
  if (pave >= 0) return 0x60 + pave;
  final fixe = _touchesFixes[touche];
  if (fixe != null) return fixe;
  // Lettres et chiffres : le code est la valeur ASCII du caractere majuscule
  // que la touche produit sur la disposition courante.
  final libelle = touche.keyLabel;
  if (libelle.length == 1) {
    final code = libelle.codeUnitAt(0);
    if ((code >= 0x41 && code <= 0x5A) || (code >= 0x30 && code <= 0x39)) {
      return code;
    }
  }
  return null;
}

/// Vrai quand la touche ne fait que modifier une autre et ne peut pas etre
/// capturee seule.
bool estModificateur(LogicalKeyboardKey touche) =>
    _modificateurs.contains(touche);
