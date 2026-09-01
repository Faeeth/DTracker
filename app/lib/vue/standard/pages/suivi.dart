/// La page de suivi : le tableau des personnages.
///
/// C'est la page d'accueil, et celle qu'on regarde en jouant. Elle porte le
/// bandeau des totaux, l'etat du combat, le tableau, et rien d'autre — tout ce
/// qui demande a etre lu au calme est ailleurs.
///
/// Le tableau est un `ShadTable`, bati sur `two_dimensional_scrollables` :
/// lignes et colonnes se construisent paresseusement, et l'en-tete reste
/// epingle quand on defile. Huit personnages n'exigeaient pas cela ; le
/// prendre coute pourtant moins cher que de le redessiner, et il tiendra si la
/// liste s'allonge.
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart' hide Cache;

import '../../../modele/session.dart';
import '../../../source/ressources.dart';
import '../../../theme.dart';
import '../briques.dart';
import '../../../i18n/textes.dart';

class PageSuivi extends StatelessWidget {
  const PageSuivi({
    super.key,
    required this.session,
    required this.res,
    required this.secondes,
    required this.eclatDe,
    required this.personnagesConfigures,
    required this.onPersonnage,
    required this.onReglages,
  });

  final Session session;
  final Ressources res;
  final int secondes;

  /// De 1 a 0 dans la seconde qui suit un gain. C'est ce qui allume la ligne.
  final double Function(Suivi) eclatDe;

  final int personnagesConfigures;
  final void Function(Suivi) onPersonnage;
  final VoidCallback onReglages;

  /// Les colonnes, dans l'ordre. La largeur nulle vaut « prend le reste ».
  ///
  /// Une seule colonne pour le butin : les kamas tombes en piece **et** la
  /// valeur estimee des ressources. C'est le chiffre qu'on vient chercher ;
  /// sa composition tient dans l'infobulle, et le detail dans la page du
  /// personnage.
  // Un getter et non une constante : les libelles changent avec la langue.
  static List<Colonne> get _colonnes => [
    Colonne(T.colPersonnage, 210),
    Colonne(T.colNiveau, 132),
    Colonne(T.colExperience, 0, Alignment.centerRight),
    Colonne(T.colButin, 150, Alignment.centerRight),
  ];

  @override
  Widget build(BuildContext context) {
    final lignes = session.lignes;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _totaux(context),
        const SizedBox(height: Pas.m),
        _etatCombat(context),
        const SizedBox(height: Pas.m),
        Expanded(child: lignes.isEmpty ? _vide() : _tableau(context, lignes)),
      ],
    );
  }

  // ------------------------------------------------------------- les totaux

  /// Ce qu'on cherche en premier en revenant a la fenetre.
  Widget _totaux(BuildContext context) {
    final theme = ShadTheme.of(context);
    final xp = session.xpTotale;
    final kamas = session.kamasTotaux;
    // La cadence n'est honnete qu'apres cinq minutes : sur une soiree qui
    // debute, un seul combat donne des « 40 000 000 xp/h » qui ne veulent
    // rien dire.
    //
    // Le palier de dix secondes fige le denominateur entre deux mesures :
    // sans lui, le chiffre changeait a chaque battement d'horloge, et un
    // nombre qui bouge sans cesse ne se lit pas.
    final assise = secondes - secondes % 10;
    final cadence = secondes >= 300 && assise > 0 && (xp > 0 || kamas > 0);
    // Les challenges plutot que les succes : ce sont eux qu'on suit d'un
    // combat a l'autre, et leur rapport dit tout de suite si la soiree se
    // passe bien.
    // Objectifs de boss exclus : ils ne sont pas des challenges, et les
    // compter donnait « 3/5 » sur une soiree qui n'en proposait que deux.
    // Une passe, sans liste intermediaire : ce bandeau se refait a chaque
    // image et l'historique grandit toute la soiree.
    var challenges = 0;
    var reussis = 0;
    for (final c in session.historiqueChallenges) {
      if (!c.estChallenge) continue;
      challenges++;
      if (c.reussi) reussis++;
    }
    return ShadCard(
      padding: const EdgeInsets.symmetric(horizontal: Pas.l, vertical: Pas.m),
      // Chaque chiffre est souple : quatre libelles et deux badges de cadence
      // sur une ligne, et la fenetre peut descendre a mille pixels.
      child: Row(
        children: [
          Flexible(
            child: Chiffre(
              T.colExperience,
              formateNombre(xp),
              icone: LucideIcons.trendingUp,
              souple: true,
            ),
          ),
          const SizedBox(width: Pas.l),
          Flexible(
            child: Chiffre(
              T.colButin,
              formateNombre(kamas),
              couleur: theme.colorScheme.primary,
              icone: LucideIcons.coins,
              kamas: res.imageKamas,
              souple: true,
            ),
          ),
          const SizedBox(width: Pas.l),
          Flexible(
            child: Chiffre(
              T.colCombats,
              '${session.combatsTotaux}',
              icone: LucideIcons.swords,
              souple: true,
            ),
          ),
          const SizedBox(width: Pas.l),
          Flexible(
            child: Chiffre(
              T.colChallenges,
              '$reussis/$challenges',
              icone: LucideIcons.target,
              souple: true,
            ),
          ),
          const Spacer(),
          if (cadence)
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisSize: MainAxisSize.min,
              children: [
                // En entier, pas abrege : « 140 m xp/h » cache l'ordre de
                // grandeur qu'on est venu comparer d'une soiree a l'autre.
                ShadBadge.secondary(
                  child: Text(
                    '${formateNombre((xp * 3600 / assise).round())} ${T.cadenceXp}',
                  ),
                ),
                const SizedBox(height: Pas.xs + 1),
                ShadBadge(
                  child: Text(
                    '${formateNombre((kamas * 3600 / assise).round())} ${T.cadenceKamas}',
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  // --------------------------------------------------------- l'etat du combat

  /// La bande d'etat est **toujours presente**.
  ///
  /// Elle n'apparaissait qu'a l'entree en combat, et poussait alors tout le
  /// tableau d'un cran vers le bas — au moment precis ou l'on regarde
  /// ailleurs, et ou une ligne qui bouge fait cliquer a cote.
  Widget _etatCombat(BuildContext context) {
    final theme = ShadTheme.of(context);
    if (!session.enCombat) {
      return Row(
        children: [
          Icon(
            LucideIcons.moon,
            size: 13,
            color: theme.colorScheme.mutedForeground,
          ),
          const SizedBox(width: Pas.s),
          Text(T.horsCombat, style: theme.textTheme.muted),
        ],
      );
    }
    final duree = session.dureeCombat;
    final m = (duree ~/ 60).toString().padLeft(2, '0');
    final s = (duree.toInt() % 60).toString().padLeft(2, '0');
    // Un combat de boss aligne quatre challenges avec leur nom et leur bonus :
    // la bande glisse plutot que de deborder.
    return SizedBox(
      height: 26,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          const Icon(LucideIcons.swords, size: 13, color: Palette.bleu),
          const SizedBox(width: Pas.s),
          Text(
            T.enCombatDepuis(
              '$m:$s${session.tour > 0 ? '  ·  ${T.tour(session.tour)}' : ''}',
            ),
            style: theme.textTheme.small.copyWith(
              fontSize: 12,
              color: Palette.bleu,
            ),
          ),
          const SizedBox(width: Pas.m),
          for (final defi in _defis) ...[
            _challenge(context, defi),
            const SizedBox(width: Pas.s),
          ],
        ],
      ),
    );
  }

  /// Celui que le groupe a choisi en tete : c'est le sien qu'on cherche du
  /// regard. Les objectifs de boss ferment la marche.
  List<Challenge> get _defis => [...session.challenges]
    ..sort((a, b) {
      final parOrigine = (a.origine != 'choisi' ? 1 : 0).compareTo(
        b.origine != 'choisi' ? 1 : 0,
      );
      if (parOrigine != 0) return parOrigine;
      final parNature = (a.objectifDeBoss ? 1 : 0).compareTo(
        b.objectifDeBoss ? 1 : 0,
      );
      return parNature != 0
          ? parNature
          : a.challengeId.compareTo(b.challengeId);
    });

  Widget _challenge(BuildContext context, Challenge defi) {
    final couleur = switch (defi.etat) {
      'reussi' => Palette.vert,
      'echoue' => ShadTheme.of(context).colorScheme.destructive,
      _ => Palette.bleu,
    };
    final mentions = {'ecarte': T.ecarte, 'impose': T.impose};
    final chemin = res.imageChallenge(defi.challengeId);
    return ShadBadge.outline(
      foregroundColor: couleur,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (chemin != null) ...[
            // Les icones de challenge sont des silhouettes sombres,
            // invisibles telles quelles : le jeu les teinte selon l'issue.
            SizedBox(
              width: 11,
              height: 11,
              child: Image.file(
                File(chemin),
                color: couleur,
                colorBlendMode: BlendMode.srcIn,
                errorBuilder: (_, _, _) => const SizedBox.shrink(),
              ),
            ),
            const SizedBox(width: Pas.xs + 1),
          ],
          Text(res.challenge(defi.challengeId)),
          if (defi.bonus != null) Text('  +${defi.bonus}%'),
          if (mentions[defi.origine] != null)
            Text(
              '  ${mentions[defi.origine]}',
              style: const TextStyle(fontStyle: FontStyle.italic),
            ),
        ],
      ),
    );
  }

  // ------------------------------------------------------------- le tableau

  Widget _tableau(BuildContext context, List<Suivi> lignes) {
    final theme = ShadTheme.of(context);
    return Tableau(
      colonnes: _colonnes,
      hauteurLigne: 52,
      // La ligne entiere ouvre la page du personnage : `ShadTable` installe
      // ses propres detecteurs sur ses lignes, et une seconde cible glissee
      // dans une cellule n'y recevrait jamais le clic.
      onLigne: (rang) => onPersonnage(lignes[rang]),
      // Elle s'allume une seconde quand son personnage encaisse.
      fondDeLigne: (rang) {
        final eclat = eclatDe(lignes[rang]);
        return eclat <= 0
            ? null
            : TableSpanDecoration(
                color: theme.colorScheme.primary.withValues(
                  alpha: 0.16 * eclat,
                ),
              );
      },
      lignes: [
        for (final suivi in lignes)
          [
            _identite(context, suivi),
            _niveau(context, suivi),
            Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: formateNombre(suivi.xpGagnee),
                    style: theme.textTheme.small.copyWith(fontSize: 14),
                  ),
                  TextSpan(
                    text: '  ${T.xp}',
                    style: theme.textTheme.muted.copyWith(fontSize: 10),
                  ),
                ],
              ),
            ),
            _butin(suivi),
          ],
      ],
    );
  }

  /// Sans infobulle : la composition du butin — pieces, ressources, detail des
  /// lots — se lit en entier d'un clic sur la ligne. La redire au survol
  /// n'apprenait rien et couvrait le tableau des qu'on le parcourait.
  Widget _butin(Suivi suivi) =>
      Kamas(suivi.kamasTotal, image: res.imageKamas, taille: 14);

  /// Le portrait, le nom, et la pastille des points a distribuer.
  Widget _identite(BuildContext context, Suivi suivi) {
    final theme = ShadTheme.of(context);
    final portrait = res.imageClasse(suivi.classe);
    final classe = res.classe(suivi.classe);
    return Row(
      children: [
        // La case est reservee meme vide : la classe n'arrive qu'au passage
        // sur une carte, et les pseudos ne doivent pas se decaler quand elle
        // finit par arriver.
        SizedBox(
          width: 26,
          height: 26,
          child: portrait == null
              ? null
              : Image.file(
                  File(portrait),
                  filterQuality: FilterQuality.medium,
                  errorBuilder: (_, _, _) => const SizedBox.shrink(),
                ),
        ),
        const SizedBox(width: Pas.s),
        Flexible(
          child: Infobulle(
            builder: (_) => Text(
              '${classe == null ? suivi.nom : '${suivi.nom} — $classe'}'
              '\n\n${T.cliquerPourCombats}',
            ),
            child: MouseRegion(
              cursor: SystemMouseCursors.click,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => onPersonnage(suivi),
                child: Text(
                  suivi.nom,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.small.copyWith(
                    fontSize: 13,
                    color: theme.colorScheme.primary,
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// Le niveau et la progression dans ce niveau.
  Widget _niveau(BuildContext context, Suivi suivi) {
    final theme = ShadTheme.of(context);
    return Infobulle(
      builder: (_) => Text(
        suivi.xpDuNiveau > 0
            ? T.progression(
                formateNombre(suivi.xpDansNiveau),
                formateNombre(suivi.xpDuNiveau),
                (suivi.progression * 100).toStringAsFixed(1),
                '${suivi.niveau ?? '?'}',
                formateNombre(suivi.xpGagnee),
              )
            : T.progressionInconnue,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Text(
                suivi.niveau?.toString() ?? '—',
                style: theme.textTheme.small.copyWith(
                  fontSize: 13,
                  color: theme.colorScheme.primary,
                ),
              ),
              // Sans marque de combat a cote : la bande du haut annonce deja
              // « En combat », et la pastille se lisait comme une donnee du
              // personnage alors qu'elle n'en est pas une.
            ],
          ),
          const SizedBox(height: Pas.xs + 1),
          SizedBox(
            width: 96,
            child: ShadProgress(
              value: suivi.progression,
              minHeight: 5,
              color: theme.colorScheme.primary,
            ),
          ),
        ],
      ),
    );
  }

  /// Le tableau vide dit **pourquoi** il l'est : aucun personnage configure, ou
  /// aucun d'eux n'a encore joue. Ce sont deux raisons differentes, et les
  /// confondre laisserait chercher un reglage qui n'y est pour rien.
  Widget _vide() => personnagesConfigures == 0
      ? Vide(
          T.aucunPersonnageSuivi,
          icone: LucideIcons.userX,
          detail: T.aucunPersonnageDetail,
          action: ShadButton.outline(
            leading: const Icon(LucideIcons.settings, size: 15),
            onPressed: onReglages,
            child: Text(T.ouvrirLesReglages),
          ),
        )
      : Vide(
          T.enAttenteDuJeu,
          icone: LucideIcons.hourglass,
          detail: T.aucunNaJoue(personnagesConfigures),
        );
}
