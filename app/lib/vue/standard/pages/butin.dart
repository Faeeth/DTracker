/// Le butin d'un personnage : la grille, et la bourse.
///
/// Une grille de cases a la maniere de l'inventaire du jeu, les kamas en piece
/// en tete, puis les ressources par valeur decroissante. Le total est sous la
/// grille, la ou l'on regarde apres avoir compte.
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart' hide Cache;

import '../../../modele/session.dart';
import '../../../source/archives.dart';
import '../../../source/ressources.dart';
import '../../../theme.dart';
import '../briques.dart';
import 'objets.dart';
import '../../../i18n/textes.dart';

/// Les ordres proposes pour la grille.
///
/// « Aucun tri » n'est pas l'absence d'ordre mais celui du jeu : par valeur
/// decroissante, ce qui met en tete ce qui vaut la peine. Les autres repondent
/// a des questions precises — qu'est-ce qui me remplit, qu'est-ce qui rapporte.
enum TriButin {
  aucun,
  nom,
  poids,
  poidsLot,
  quantite,
  prix,
  prixLot;

  /// Le libelle suit la langue : un getter, non un champ pose a la
  /// construction de l'enumeration.
  String get libelle => switch (this) {
    TriButin.aucun => T.triAucun,
    TriButin.nom => T.triNom,
    TriButin.poids => T.triPoids,
    TriButin.poidsLot => T.triPoidsLot,
    TriButin.quantite => T.triQuantite,
    TriButin.prix => T.triPrix,
    TriButin.prixLot => T.triPrixLot,
  };
}

class PageButin extends StatefulWidget {
  const PageButin({super.key, required this.suivi, required this.res});

  final Suivi suivi;
  final Ressources res;

  static const taille = 54.0;

  @override
  State<PageButin> createState() => _PageButinState();
}

class _PageButinState extends State<PageButin> {
  TriButin _tri = TriButin.aucun;

  Suivi get suivi => widget.suivi;
  Ressources get res => widget.res;

  @override
  Widget build(BuildContext context) {
    final unites = suivi.butin.values.fold(0, (n, lot) => n + lot.quantite);
    if (suivi.butin.isEmpty) {
      return Vide(T.aucunItem, icone: LucideIcons.package);
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Section(
          T.inventaire,
          aDroite: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _choixDeTri(context),
              const SizedBox(width: Pas.s),
              ShadBadge.secondary(child: Text(T.nbObjets(unites))),
            ],
          ),
        ),
        Expanded(
          // L'ascenseur est **dehors**, dans une gouttiere reservee a droite :
          // pose sur la grille, il recouvrait la derniere colonne d'objets et
          // masquait justement ce qu'on venait survoler.
          child: Scrollbar(
            thumbVisibility: true,
            child: Padding(
              padding: const EdgeInsets.only(right: Pas.m + Pas.xs),
              child: ShadCard(
                padding: const EdgeInsets.all(Pas.m),
                child: SingleChildScrollView(
                  child: Wrap(
                    spacing: Pas.s,
                    runSpacing: Pas.s,
                    children: _cases(context),
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: Pas.m),
        _bourse(context),
      ],
    );
  }

  Widget _choixDeTri(BuildContext context) => SizedBox(
    width: 210,
    child: ShadSelect<TriButin>(
      initialValue: _tri,
      placeholder: Text(TriButin.aucun.libelle),
      selectedOptionBuilder: (_, valeur) => Text(valeur.libelle),
      options: [
        for (final tri in TriButin.values)
          ShadOption(value: tri, child: Text(tri.libelle)),
      ],
      onChanged: (tri) => setState(() => _tri = tri ?? TriButin.aucun),
    ),
  );

  /// Les lots dans l'ordre demande.
  ///
  /// Le poids et le prix d'un objet ne sont pas dans le flux : ils viennent de
  /// l'index extrait du client. Un objet dont on ignore le poids passe donc
  /// derriere ceux qu'on connait plutot que de se poser en tete avec un zero.
  List<Lot> get _lots {
    if (_tri == TriButin.aucun) return suivi.lots;
    // La clef est calculee une fois par lot, non a chaque comparaison. Un
    // inventaire de trois cents objets demande deux mille comparaisons : par
    // nom, c'etait autant d'allers-retours a l'index et de mises en
    // minuscules, a chaque construction de la page.
    int poids(Lot l) => res.detailObjet(l.itemId).poids;
    final avecClef = <(Comparable<Object>, Lot)>[
      for (final l in suivi.lots)
        (
          switch (_tri) {
            TriButin.nom => res.objet(l.itemId).toLowerCase(),
            TriButin.poids => -poids(l),
            TriButin.poidsLot => -poids(l) * l.quantite,
            TriButin.quantite => -l.quantite,
            TriButin.prix => -(l.prixUnitaire ?? 0),
            TriButin.prixLot => -l.valeur,
            TriButin.aucun => 0,
          },
          l,
        ),
    ];
    avecClef.sort((a, b) => a.$1.compareTo(b.$1));
    return [for (final (_, l) in avecClef) l];
  }

  List<Widget> _cases(BuildContext context) {
    // Les kamas en piece n'y sont plus : ce ne sont pas des objets, ils
    // n'ont ni poids ni prix, et aucun des tris proposes ne sait ou les
    // ranger. Leur montant se lit sous la grille, dans la bourse.
    return [
      for (final lot in _lots)
        SurvolObjet(
          lot: (lot.itemId, lot.quantite, lot.prixUnitaire),
          res: res,
          child: _case(
            context,
            image: res.imageObjet(lot.itemId),
            quantite: lot.quantite,
          ),
        ),
    ];
  }

  Widget _case(
    BuildContext context, {
    String? image,
    Color? teinte,
    int? quantite,
    String? infobulle,
  }) {
    final theme = ShadTheme.of(context);
    final case_ = Container(
      width: PageButin.taille,
      height: PageButin.taille,
      decoration: BoxDecoration(
        color: theme.colorScheme.muted,
        borderRadius: theme.radius,
        border: Border.all(color: theme.colorScheme.border),
      ),
      child: Stack(
        children: [
          Center(
            child: SizedBox(
              width: PageButin.taille - 18,
              height: PageButin.taille - 18,
              child: image == null
                  ? Icon(
                      LucideIcons.package,
                      size: 18,
                      color: theme.colorScheme.mutedForeground,
                    )
                  : Image.file(
                      File(image),
                      color: teinte,
                      colorBlendMode: teinte == null ? null : BlendMode.srcIn,
                      filterQuality: FilterQuality.medium,
                      errorBuilder: (_, _, _) => const SizedBox.shrink(),
                    ),
            ),
          ),
          if (quantite != null)
            Positioned(
              right: 3,
              bottom: 2,
              child: Text(
                formateNombre(quantite),
                style: theme.textTheme.small.copyWith(
                  fontSize: 10,
                  height: 1,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
        ],
      ),
    );
    return infobulle == null
        ? case_
        : Infobulle(builder: (_) => Text(infobulle), child: case_);
  }

  Widget _bourse(BuildContext context) {
    final theme = ShadTheme.of(context);
    return ShadCard(
      padding: const EdgeInsets.symmetric(horizontal: Pas.l, vertical: Pas.m),
      child: Row(
        children: [
          Chiffre(
            T.enPiece,
            formateNombre(suivi.kamasPiece),
            icone: LucideIcons.coins,
            kamas: res.imageKamas,
          ),
          const SizedBox(width: Pas.xl),
          Chiffre(
            T.valeurRessources,
            formateNombre(suivi.kamasButin),
            icone: LucideIcons.package,
            kamas: res.imageKamas,
          ),
          const Spacer(),
          Chiffre(
            T.colTotal,
            formateNombre(suivi.kamasTotal),
            couleur: theme.colorScheme.primary,
            kamas: res.imageKamas,
          ),
        ],
      ),
    );
  }
}

/// L'inventaire d'un personnage sur une session archivee.
///
/// Il lit un `BilanPersonnage` et non un `Suivi` : une session close n'a plus
/// de compteurs vivants, seulement ce qu'elle a conserve.
class PageButinArchive extends StatelessWidget {
  const PageButinArchive({super.key, required this.bilan, required this.res});

  final BilanPersonnage bilan;
  final Ressources res;

  @override
  Widget build(BuildContext context) {
    // Le meme rendu que pour la session en cours : on reconstitue le suivi
    // que le bilan represente, plutot que de dupliquer la grille.
    final suivi = Suivi(bilan.nom)
      ..classe = bilan.classe
      ..niveau = bilan.niveau
      ..kamasPiece = bilan.kamasPiece;
    bilan.butin.forEach((id, lot) => suivi.ajouteLot(id, lot.$1, lot.$2));
    return PageButin(suivi: suivi, res: res);
  }
}
