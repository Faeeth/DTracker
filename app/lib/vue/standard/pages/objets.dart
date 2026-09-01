/// Le butin d'une ligne : les objets, leur quantite, leur valeur.
///
/// Reprend la maniere du jeu. Un objet y porte sa quantite en bas a gauche de
/// son icone, et son infobulle donne le nom, ce qu'on sait de l'objet, puis
/// les prix — a l'unite et pour le lot. C'est cette derniere ligne qu'on vient
/// chercher : un lot de mille galets ne vaut pas son prix unitaire.
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart' hide Cache;

import '../../../source/ressources.dart';
import '../../../theme.dart';
import '../briques.dart';
import '../../../i18n/textes.dart';

/// Un lot : l'objet, combien, et a quel prix unitaire s'il est connu.
/// Nomme `LotObjet` et non `Lot` : le modele a deja un `Lot`, et deux types
/// du meme nom dans deux bibliotheques importees ensemble ne se departagent
/// pas.
typedef LotObjet = (int itemId, int quantite, int? prixUnitaire);

/// La rangee d'objets d'une ligne de tableau.
///
/// Elle en montre quelques-uns, puis un « +n » qui **ouvre le reste**. Sans
/// lui, une ligne chargee cachait son butin sans dire combien il en restait.
class RangeeObjets extends StatelessWidget {
  const RangeeObjets({
    super.key,
    required this.lots,
    required this.res,
    this.visibles = 5,
    this.titrePopover,
  });

  final List<LotObjet> lots;
  final Ressources res;
  final int visibles;

  /// Nul vaut « Butin complet », dans la langue courante : une valeur par
  /// defaut ne peut pas etre traduite, le constructeur etant constant.
  final String? titrePopover;
  String get titre => titrePopover ?? T.butinComplet;

  @override
  Widget build(BuildContext context) {
    if (lots.isEmpty) return const SizedBox.shrink();
    final montres = lots.take(visibles).toList();
    final reste = lots.length - montres.length;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final lot in montres)
          Padding(
            padding: const EdgeInsets.only(right: Pas.xs),
            child: CaseObjet(lot: lot, res: res),
          ),
        if (reste > 0) _reste(context, reste),
      ],
    );
  }

  Widget _reste(BuildContext context, int reste) =>
      _PlusObjets(reste: reste, lots: lots, res: res, titre: titre);
}

/// Pose l'infobulle d'objet sur n'importe quoi.
///
/// Une case d'inventaire, une ligne de tableau, une vignette : partout ou l'on
/// montre un objet, on doit pouvoir survoler et lire le meme detail. Sans ce
/// raccourci, chaque vue reecrivait son propre texte, et aucune ne disait la
/// meme chose que sa voisine.
class SurvolObjet extends StatelessWidget {
  const SurvolObjet({
    super.key,
    required this.lot,
    required this.res,
    required this.child,
  });

  final LotObjet lot;
  final Ressources res;
  final Widget child;

  @override
  Widget build(BuildContext context) => Infobulle(
    builder: (_) => InfobulleObjet(lot: lot, res: res),
    child: child,
  );
}

/// Une case d'objet : l'icone, la quantite, l'infobulle.
class CaseObjet extends StatelessWidget {
  const CaseObjet({
    super.key,
    required this.lot,
    required this.res,
    this.taille = 26,
  });

  final LotObjet lot;
  final Ressources res;
  final double taille;

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);
    final (itemId, quantite, prix) = lot;
    final chemin = res.imageObjet(itemId);
    return SurvolObjet(
      lot: lot,
      res: res,
      child: SizedBox(
        width: taille,
        height: taille,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned.fill(
              child: chemin == null
                  ? Icon(
                      LucideIcons.package,
                      size: taille * 0.7,
                      color: theme.colorScheme.mutedForeground,
                    )
                  : Image.file(
                      File(chemin),
                      filterQuality: FilterQuality.medium,
                      errorBuilder: (_, _, _) => const SizedBox.shrink(),
                    ),
            ),
            // La quantite en bas a gauche, comme dans l'inventaire du jeu, et
            // seulement au-dela de un : ecrire « 1 » sur chaque case ferait du
            // bruit pour une information que l'absence de chiffre donne deja.
            if (quantite > 1)
              Positioned(
                left: -2,
                bottom: -3,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 3),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.background,
                    borderRadius: BorderRadius.circular(3),
                    border: Border.all(color: theme.colorScheme.border),
                  ),
                  child: Text(
                    formateNombre(quantite),
                    style: theme.textTheme.small.copyWith(
                      fontSize: 9,
                      height: 1.3,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            if (prix == null)
              // Un prix inconnu se signale : sans cela, un butin sans valeur
              // et un butin dont on ignore le prix se ressemblent.
              Positioned(
                right: -2,
                top: -2,
                child: Icon(
                  LucideIcons.circleHelp,
                  size: 9,
                  color: theme.colorScheme.mutedForeground,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// L'infobulle d'un objet, a la maniere du jeu.
class InfobulleObjet extends StatelessWidget {
  const InfobulleObjet({super.key, required this.lot, required this.res});

  final LotObjet lot;
  final Ressources res;

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);
    final (itemId, quantite, prix) = lot;
    final detail = res.detailObjet(itemId);
    final chemin = res.imageObjet(itemId);
    final sousTitre = [
      if (detail.niveau > 0) 'Niveau ${detail.niveau}',
      if (detail.type.isNotEmpty) detail.type,
    ].join('  ·  ');

    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 360),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // L'icone en tete, comme dans le jeu : on reconnait un objet a son
          // dessin bien avant d'avoir lu son nom.
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (chemin != null) ...[
                SizedBox(
                  width: 34,
                  height: 34,
                  child: Image.file(
                    File(chemin),
                    filterQuality: FilterQuality.medium,
                    errorBuilder: (_, _, _) => const SizedBox.shrink(),
                  ),
                ),
                const SizedBox(width: Pas.s),
              ],
              Flexible(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // La quantite est collee au nom, comme le jeu l'ecrit :
                    // « Fémur du Chafer Ronin x47 ». Rien au-dessous de deux
                    // — un « x1 » ne dit que ce que l'absence disait deja.
                    Text(
                      quantite > 1
                          ? '${res.objet(itemId)}  x${formateNombre(quantite)}'
                          : res.objet(itemId),
                      style: theme.textTheme.small.copyWith(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                    if (sousTitre.isNotEmpty)
                      Text(
                        sousTitre,
                        style: theme.textTheme.muted.copyWith(fontSize: 11),
                      ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: Pas.s),
          Container(height: 1, color: theme.colorScheme.border),
          const SizedBox(height: Pas.s),
          if (detail.poids > 0)
            _paire(
              theme,
              T.colPoids,
              '${detail.poids}',
              // Un objet seul n'a pas de lot : « POIDS 10 · LOT 10 » repete
              // le meme chiffre deux fois sous deux noms.
              quantite > 1 ? T.lot : null,
              '${detail.poids * quantite}',
              icone: res.imagePods,
            ),
          if (prix == null)
            // Une seule ligne, sans explication : qui survole un objet veut
            // son prix, pas un cours sur la table des prix du jeu.
            Text(
              T.prixNonDisponible,
              style: theme.textTheme.muted.copyWith(fontSize: 11),
            )
          else
            _paire(
              theme,
              T.colPrix,
              formateNombre(prix),
              quantite > 1 ? T.lot : null,
              formateNombre(prix * quantite),
              icone: res.imageKamas,
              teinte: theme.colorScheme.primary,
            ),
        ],
      ),
    );
  }

  /// « POIDS 10 · LOT 1000 », sur une ligne.
  ///
  /// La moitie droite tombe quand `droite` est nul : c'est le cas d'un objet
  /// ramasse a l'unite, ou le lot vaut l'unite.
  Widget _paire(
    ShadThemeData theme,
    String gauche,
    String valeurGauche,
    String? droite,
    String valeurDroite, {
    String? icone,
    Color? teinte,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 2),
    // Un `Wrap` et non un `Row` : « PRIX MOYEN 608 597 · LOT 60 859 700 »
    // ne tient pas toujours sur une ligne, et une infobulle qui deborde
    // masque la moitie de ce qu'on est venu lire.
    child: Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        _etiquette(theme, gauche),
        _valeur(theme, valeurGauche, icone, teinte),
        if (droite != null) ...[
          Text('  ·  ', style: theme.textTheme.muted.copyWith(fontSize: 11)),
          _etiquette(theme, droite),
          _valeur(theme, valeurDroite, icone, teinte),
        ],
      ],
    ),
  );

  Widget _etiquette(ShadThemeData theme, String texte) => Text(
    '$texte ',
    style: theme.textTheme.muted.copyWith(
      fontSize: 10,
      letterSpacing: 0.6,
      fontWeight: FontWeight.w600,
    ),
  );

  /// Un chiffre suivi de son icone : les pods pour un poids, les kamas pour un
  /// prix. Deux nombres de meme allure se confondent sans elle.
  Widget _valeur(
    ShadThemeData theme,
    String texte,
    String? icone,
    Color? teinte,
  ) {
    final couleur = teinte ?? theme.colorScheme.foreground;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          texte,
          style: theme.textTheme.small.copyWith(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: couleur,
          ),
        ),
        if (icone != null) ...[
          const SizedBox(width: 3),
          SizedBox(
            width: 10,
            height: 10,
            child: Image.file(
              File(icone),
              color: couleur,
              colorBlendMode: BlendMode.srcIn,
              filterQuality: FilterQuality.medium,
              errorBuilder: (_, _, _) => const SizedBox.shrink(),
            ),
          ),
        ],
      ],
    );
  }
}

/// Le « +n » qui deploie le butin entier.
class _PlusObjets extends StatefulWidget {
  const _PlusObjets({
    required this.reste,
    required this.lots,
    required this.res,
    required this.titre,
  });

  final int reste;
  final List<LotObjet> lots;
  final Ressources res;
  final String titre;

  @override
  State<_PlusObjets> createState() => _PlusObjetsState();
}

class _PlusObjetsState extends State<_PlusObjets> {
  final _controleur = ShadPopoverController();

  @override
  void dispose() {
    _controleur.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);
    final valeur = widget.lots.fold(
      0,
      (somme, l) => somme + (l.$3 ?? 0) * l.$2,
    );
    return ShadPopover(
      controller: _controleur,
      // Au-dessus : la rangee est en bas d'un tableau qui defile, et un
      // panneau qui s'ouvre vers le bas sortirait de la fenetre.
      anchor: const ShadAnchorAuto(
        offset: Offset(0, -8),
        followerAnchor: Alignment.bottomCenter,
        targetAnchor: Alignment.topCenter,
      ),
      popover: (_) => ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 380),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Text(
                  widget.titre,
                  style: theme.textTheme.small.copyWith(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const Spacer(),
                ShadBadge.secondary(
                  child: Text(T.nbObjets(widget.lots.length)),
                ),
              ],
            ),
            const SizedBox(height: Pas.s),
            Wrap(
              spacing: Pas.s,
              runSpacing: Pas.s,
              children: [
                for (final lot in widget.lots)
                  CaseObjet(lot: lot, res: widget.res, taille: 30),
              ],
            ),
            if (valeur > 0) ...[
              const SizedBox(height: Pas.m),
              Row(
                children: [
                  Text(
                    T.valeur,
                    style: theme.textTheme.muted.copyWith(
                      fontSize: 10,
                      letterSpacing: 0.8,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Spacer(),
                  Kamas(valeur, image: widget.res.imageKamas, taille: 13),
                ],
              ),
            ],
          ],
        ),
      ),
      child: ShadButton.ghost(
        size: ShadButtonSize.sm,
        padding: const EdgeInsets.symmetric(horizontal: Pas.s),
        onPressed: _controleur.toggle,
        child: Text(
          '+${widget.reste}',
          style: theme.textTheme.small.copyWith(
            fontSize: 11,
            color: theme.colorScheme.mutedForeground,
          ),
        ),
      ),
    );
  }
}
