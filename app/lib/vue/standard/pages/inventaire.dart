/// L'inventaire du groupe, personnages au choix.
///
/// Le butin de la session, fusionne. Chaque personnage se coche : on veut
/// souvent savoir ce qu'a rapporte la moitie du groupe, ou ce qu'un seul
/// personnage a ramasse sans quitter la vue d'ensemble.
///
/// La grille elle-meme est celle d'un personnage — on reconstitue un `Suivi`
/// qui porte la somme des choisis, plutot que de dupliquer l'inventaire et sa
/// bourse.
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart' hide Cache;

import '../../../modele/session.dart';
import '../../../source/ressources.dart';
import '../briques.dart';
import 'butin.dart';
import '../../../i18n/textes.dart';

class PageInventaire extends StatefulWidget {
  const PageInventaire({super.key, required this.suivis, required this.res});

  /// Les personnages a fusionner.
  ///
  /// Des `Suivi`, et non une session : l'inventaire d'une soiree archivee se
  /// regarde de la meme facon que celui de la session en cours, et une archive
  /// n'a pas de compteurs vivants a offrir. L'appelant reconstitue le suivi
  /// que chaque bilan represente.
  final List<Suivi> suivis;

  final Ressources res;

  @override
  State<PageInventaire> createState() => _PageInventaireState();
}

class _PageInventaireState extends State<PageInventaire> {
  /// Les personnages **ecartes**, et non ceux retenus : un personnage qui
  /// apparait en cours de session doit entrer dans le total sans qu'on ait a
  /// aller le cocher.
  final Set<String> _ecartes = {};

  List<Suivi> get _lignes => widget.suivis;

  Suivi get _fusion {
    final total = Suivi('Groupe');
    for (final s in _lignes) {
      if (_ecartes.contains(cleDe(s.nom))) continue;
      total.kamasPiece += s.kamasPiece;
      for (final lot in s.lots) {
        total.ajouteLot(lot.itemId, lot.quantite, lot.prixUnitaire);
      }
    }
    return total;
  }

  @override
  Widget build(BuildContext context) {
    final lignes = _lignes;
    if (lignes.isEmpty) {
      return Vide(T.aucunItem, icone: LucideIcons.package);
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _choix(context, lignes),
        const SizedBox(height: Pas.s),
        Expanded(
          child: PageButin(suivi: _fusion, res: widget.res),
        ),
      ],
    );
  }

  /// Le choix des personnages, sur une seule bande.
  ///
  /// Il avait sa carte et son titre de rubrique. Quatre bandes se succedaient
  /// alors avant la premiere rangee d'objets — le resume de la session, les
  /// onglets, ce choix, puis le titre de l'inventaire — et il n'en restait
  /// que deux visibles la ou le suivi en montrait cinq.
  ///
  /// Elle glisse plutot que de deborder : huit personnages ne tiennent pas
  /// toujours sur une ligne, et se replier en deux rangees reprendrait la
  /// hauteur qu'on vient de gagner.
  Widget _choix(BuildContext context, List<Suivi> lignes) {
    final theme = ShadTheme.of(context);
    final retenus = lignes.length - _ecartes.length;
    return SizedBox(
      height: 28,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          for (final s in lignes)
            Padding(
              padding: const EdgeInsets.only(right: Pas.l),
              child: ShadCheckbox(
                value: !_ecartes.contains(cleDe(s.nom)),
                onChanged: (coche) => setState(() {
                  if (coche) {
                    _ecartes.remove(cleDe(s.nom));
                  } else {
                    _ecartes.add(cleDe(s.nom));
                  }
                }),
                label: _etiquette(theme, s),
              ),
            ),
          Center(
            child: ShadBadge.secondary(
              child: Text(T.surTotal(retenus, lignes.length)),
            ),
          ),
        ],
      ),
    );
  }

  /// Le portrait et le nom.
  ///
  /// Une liste de pseudos se parcourt mal quand on cherche « le Sadida » ;
  /// avec le portrait, la case se trouve sans lire.
  Widget _etiquette(ShadThemeData theme, Suivi s) {
    final portrait = widget.res.imageClasse(s.classe);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // La case reste reservee sans portrait : la classe n'arrive qu'au
        // passage sur une carte, et les noms ne doivent pas se decaler quand
        // elle finit par arriver.
        SizedBox(
          width: 22,
          height: 22,
          child: portrait == null
              ? null
              : Image.file(
                  File(portrait),
                  filterQuality: FilterQuality.medium,
                  errorBuilder: (_, _, _) => const SizedBox.shrink(),
                ),
        ),
        const SizedBox(width: Pas.xs + 2),
        Text(s.nom, style: theme.textTheme.small.copyWith(fontSize: 13)),
      ],
    );
  }
}
