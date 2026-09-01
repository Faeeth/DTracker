/// Les quelques briques que shadcn ne fournit pas.
///
/// Volontairement peu nombreuses. Le paquet donne la carte, l'etiquette, le
/// bouton, le tableau, les onglets ; tout ce qu'on rajoute ici est une dette
/// de plus a tenir en accord avec eux. Ne restent donc que trois choses qui
/// n'ont pas d'equivalent : le pas d'espacement, le chiffre d'un bandeau de
/// resume, et le message d'un ecran vide.
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart' hide Cache;

import '../../theme.dart';

/// Le pas d'espacement, en multiples de quatre.
///
/// Un espacement pris au hasard entre deux panneaux se voit — pas
/// consciemment, mais il se voit.
class Pas {
  static const xs = 4.0;
  static const s = 8.0;
  static const m = 12.0;
  static const l = 20.0;
  static const xl = 32.0;
}

/// Un chiffre et son libelle, pour les bandeaux de resume.
///
/// Le chiffre est gros et le libelle petit : c'est le chiffre qu'on vient
/// chercher, et l'ecart entre les deux tailles fait tout le travail.
class Chiffre extends StatelessWidget {
  const Chiffre(
    this.libelle,
    this.valeur, {
    super.key,
    this.couleur,
    this.icone,
    this.detail,
    this.kamas,
    this.souple = false,
  });

  final String libelle;
  final String valeur;
  final Color? couleur;
  final IconData? icone;
  final String? detail;

  /// Chemin de l'icone des kamas, quand le chiffre en est. Un montant sans
  /// son symbole se lit comme un compte d'objets.
  final String? kamas;

  /// Laisse le libelle et la valeur se raccourcir quand la place manque.
  ///
  /// Faux par defaut, et volontairement : `Flexible` exige une largeur bornee,
  /// or un chiffre se pose parfois dans une rangee qui s'ajuste a son contenu.
  /// Seuls les bandeaux serres — quatre chiffres et une date sur une ligne —
  /// en ont besoin, et eux savent qu'ils sont bornes.
  final bool souple;

  Widget _souple(Widget enfant) => souple ? Flexible(child: enfant) : enfant;

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            if (icone != null) ...[
              Icon(icone, size: 12, color: theme.colorScheme.mutedForeground),
              const SizedBox(width: Pas.xs + 2),
            ],
            // Le libelle cede avant la valeur : dans un bandeau serre, mieux
            // vaut « VALEUR ESTIMÉE DES RESS… » qu'un debordement.
            _souple(
              Text(
                libelle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.muted.copyWith(
                  fontSize: 10,
                  letterSpacing: 0.8,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: Pas.xs + 1),
        Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            _souple(
              Text(
                valeur,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.h4.copyWith(
                  color: couleur ?? theme.colorScheme.foreground,
                  letterSpacing: -0.4,
                  height: 1,
                ),
              ),
            ),
            if (kamas != null) ...[
              const SizedBox(width: Pas.xs + 1),
              SizedBox(
                width: 13,
                height: 13,
                child: Image.file(
                  File(kamas!),
                  color: couleur ?? theme.colorScheme.foreground,
                  colorBlendMode: BlendMode.srcIn,
                  filterQuality: FilterQuality.medium,
                  errorBuilder: (_, _, _) => const SizedBox.shrink(),
                ),
              ),
            ],
          ],
        ),
        if (detail != null) ...[
          const SizedBox(height: 2),
          Text(detail!, style: theme.textTheme.muted.copyWith(fontSize: 10)),
        ],
      ],
    );
  }
}

/// Un ecran vide qui dit **pourquoi** il l'est.
///
/// « Aucune donnee » laisse chercher un reglage qui n'y est pour rien.
class Vide extends StatelessWidget {
  const Vide(this.titre, {super.key, this.icone, this.detail, this.action});

  final String titre;
  final IconData? icone;
  final String? detail;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(Pas.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icone != null) ...[
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: theme.colorScheme.muted,
                  shape: BoxShape.circle,
                  border: Border.all(color: theme.colorScheme.border),
                ),
                child: Icon(
                  icone,
                  size: 22,
                  color: theme.colorScheme.mutedForeground,
                ),
              ),
              const SizedBox(height: Pas.m),
            ],
            Text(
              titre,
              textAlign: TextAlign.center,
              style: theme.textTheme.large.copyWith(fontSize: 14),
            ),
            if (detail != null) ...[
              const SizedBox(height: Pas.s),
              Text(
                detail!,
                textAlign: TextAlign.center,
                style: theme.textTheme.muted.copyWith(height: 1.5),
              ),
            ],
            if (action != null) ...[const SizedBox(height: Pas.l), action!],
          ],
        ),
      ),
    );
  }
}

/// Le titre d'une section.
class Section extends StatelessWidget {
  const Section(this.texte, {super.key, this.aDroite});

  final String texte;
  final Widget? aDroite;

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: Pas.s),
      child: Row(
        children: [
          Text(
            texte,
            style: theme.textTheme.muted.copyWith(
              fontSize: 10,
              letterSpacing: 1.1,
              fontWeight: FontWeight.w700,
            ),
          ),
          if (aDroite != null) ...[const Spacer(), aDroite!],
        ],
      ),
    );
  }
}

/// Des onglets dont le contenu occupe la hauteur restante.
///
/// `ShadTabs` place le contenu dans une colonne qui s'ajuste a lui : il lui
/// donne donc une hauteur **non bornee**, et tout ce qui veut occuper la place
/// disponible — un tableau, une liste — s'y casse. On ne garde donc que sa
/// barre, et le corps se rend dessous, dans un `Expanded` ou les contraintes
/// sont franches.
class Onglets extends StatefulWidget {
  const Onglets({super.key, required this.entrees});

  /// Une entree par onglet : sa clef, son libelle, son icone, son corps.
  final List<(String, String, IconData, Widget)> entrees;

  @override
  State<Onglets> createState() => _OngletsState();
}

class _OngletsState extends State<Onglets> {
  late String _choisi = widget.entrees.first.$1;

  @override
  Widget build(BuildContext context) {
    final corps = widget.entrees
        .firstWhere((e) => e.$1 == _choisi, orElse: () => widget.entrees.first)
        .$4;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: ShadTabs<String>(
            value: _choisi,
            // La barre glisse plutot que de deborder : quatre onglets tiennent
            // sur une fenetre large, pas sur la plus etroite qu'on autorise.
            scrollable: true,
            onChanged: (v) => setState(() => _choisi = v),
            tabs: [
              for (final (clef, libelle, icone, _) in widget.entrees)
                ShadTab(
                  value: clef,
                  leading: Icon(icone, size: 14),
                  child: Text(libelle),
                ),
            ],
          ),
        ),
        const SizedBox(height: Pas.m),
        Expanded(child: corps),
      ],
    );
  }
}

/// Une colonne de tableau.
class Colonne {
  const Colonne(
    this.libelle,
    this.largeur, [
    this.alignement = Alignment.centerLeft,
  ]);

  final String libelle;

  /// Largeur en pixels. **Zero** vaut « prend la place restante ».
  final double largeur;

  final Alignment alignement;
}

/// Les largeurs effectives, la colonne souple prenant ce qui reste.
///
/// `RemainingTableSpanExtent` ne convient pas pour cela. Il rend
/// `viewportExtent - precedingExtent`, ou `precedingExtent` ne compte que les
/// colonnes **qui precedent**. Place ailleurs qu'en dernier, il avale donc la
/// place des suivantes, qui sortent du champ — sans erreur, sans debordement
/// signale, sans rien : la colonne est construite, mesurable par un test, et
/// simplement invisible. C'est ainsi qu'une colonne entiere a disparu de cinq
/// tableaux sans que rien ne le dise.
///
/// Le calcul se fait donc ici, a partir de la largeur reelle du tableau.
List<double> largeursDe(List<Colonne> colonnes, double disponible) {
  final fixes = colonnes.fold(0.0, (somme, c) => somme + c.largeur);
  final souples = colonnes.where((c) => c.largeur == 0).length;
  // Un plancher : sous cette largeur le texte n'a plus de place, et mieux vaut
  // un tableau qui defile qu'une colonne ecrasee a rien.
  final reste = souples == 0
      ? 0.0
      : ((disponible - fixes) / souples).clamp(120.0, double.infinity);
  return [for (final c in colonnes) c.largeur == 0 ? reste : c.largeur];
}

/// Un tableau dont les colonnes sont mesurees sur la largeur reelle.
class Tableau extends StatelessWidget {
  const Tableau({
    super.key,
    required this.colonnes,
    required this.lignes,
    this.hauteurLigne = 46,
    this.onLigne,
    this.fondDeLigne,
  });

  final List<Colonne> colonnes;
  final List<List<Widget>> lignes;
  final double hauteurLigne;

  /// Le rang recu est celui du **corps**, en-tete deduit.
  final void Function(int)? onLigne;
  final TableSpanDecoration? Function(int)? fondDeLigne;

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);
    return LayoutBuilder(
      builder: (context, contraintes) {
        final mesures = largeursDe(colonnes, contraintes.maxWidth);
        return ShadTable.list(
          header: [
            for (final c in colonnes)
              ShadTableCell.header(
                alignment: c.alignement,
                child: Text(
                  c.libelle,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.muted.copyWith(
                    fontSize: 10,
                    letterSpacing: 0.9,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
          ],
          columnSpanExtent: (index) => FixedTableSpanExtent(mesures[index]),
          rowSpanExtent: (_) => FixedTableSpanExtent(hauteurLigne),
          // L'en-tete reste en place quand on defile : sans lui, on ne sait
          // plus a la troisieme page quelle colonne on regarde.
          pinnedRowCount: 1,
          // Le rang 0 est l'en-tete : le corps commence a 1.
          onRowTap: onLigne == null
              ? null
              : (rang) {
                  if (rang >= 1 && rang <= lignes.length) onLigne!(rang - 1);
                },
          rowSpanBackgroundDecoration: fondDeLigne == null
              ? null
              : (rang) => rang >= 1 && rang <= lignes.length
                    ? fondDeLigne!(rang - 1)
                    : null,
          children: [
            for (final ligne in lignes)
              [
                for (var i = 0; i < ligne.length; i++)
                  ShadTableCell(
                    alignment: colonnes[i].alignement,
                    // Une cellule deja emballee ne l'est pas deux fois : le
                    // second emballage peignait un aplat gris sur toute la
                    // colonne, et le tableau paraissait vide.
                    child: ligne[i] is ShadTableCell
                        ? (ligne[i] as ShadTableCell).child
                        : ligne[i],
                  ),
              ],
          ],
        );
      },
    );
  }
}

/// Une somme en kamas, suivie du symbole du jeu.
///
/// Le glyphe est blanc dans les fichiers du client : on le teinte, ce qui
/// evite d'embarquer une seconde image. Sa place est reservee meme quand
/// l'image manque, sinon les colonnes se decalent selon que les images ont
/// ete extraites ou non.
class Kamas extends StatelessWidget {
  const Kamas(
    this.valeur, {
    super.key,
    required this.image,
    this.couleur,
    this.taille = 13,
  });

  final int valeur;
  final String? image;
  final Color? couleur;
  final double taille;

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);
    final teinte = couleur ?? theme.colorScheme.primary;
    return Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Text(
          formateNombre(valeur),
          style: theme.textTheme.small.copyWith(
            fontSize: taille,
            color: teinte,
          ),
        ),
        const SizedBox(width: Pas.xs + 1),
        SizedBox(
          width: taille - 2,
          height: taille - 2,
          child: image == null
              ? null
              : Image.file(
                  File(image!),
                  color: teinte,
                  colorBlendMode: BlendMode.srcIn,
                  filterQuality: FilterQuality.medium,
                  errorBuilder: (_, _, _) => const SizedBox.shrink(),
                ),
        ),
      ],
    );
  }
}

/// Une infobulle qui s'affiche vraiment au survol.
///
/// `ShadTooltip` ne guette pas le survol lui-meme : il depose ses
/// `hoverStrategies` dans le theme et attend qu'un `ShadGestureDetector`
/// descendant le rappelle. Avec un enfant ordinaire — un texte, une image, un
/// `Container` — personne ne rappelle jamais, et l'infobulle ne parait pas.
/// Sans erreur, sans avertissement : elle est simplement muette.
///
/// On pose donc le detecteur manquant. Il n'a aucun rappel de geste, donc sa
/// table de reconnaisseurs reste vide et il ne dispute rien a ce qu'il
/// enveloppe : un bouton en dessous garde ses clics.
class Infobulle extends StatelessWidget {
  const Infobulle({
    super.key,
    required this.builder,
    required this.child,
    this.anchor,
  });

  final WidgetBuilder builder;
  final Widget child;
  final ShadAnchorBase? anchor;

  @override
  Widget build(BuildContext context) => ShadTooltip(
    builder: builder,
    anchor: anchor,
    child: ShadGestureDetector(child: child),
  );
}
