/// Les combats d'un personnage, et le recapitulatif de l'un d'eux.
///
/// La liste porte l'heure de **fin** pour reference — c'est ce moment-la qu'on
/// a en tete, pas celui de l'engagement. Les colonnes se trient d'un clic :
/// « ou ai-je fait le plus de kamas », « le combat le plus long ». Recliquer
/// sur la meme colonne inverse l'ordre.
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart' hide Cache;

import '../../../modele/session.dart';
import '../../../source/ressources.dart';
import '../../../theme.dart';
import '../briques.dart';
import 'objets.dart';
import '../../../i18n/textes.dart';

/// Sur quoi la liste est triee.
enum Tri { issue, fin, duree, challenges, xp, kamas, objets }

class PageCombats extends StatefulWidget {
  const PageCombats({
    super.key,
    required this.combats,
    required this.personnage,
    required this.res,
    required this.onCombat,
    this.avecTitre = true,
  });

  final List<Combat> combats;

  /// Celui dont on a clique le nom : ses chiffres remplissent les colonnes.
  ///
  /// Nul pour la liste de la session entiere : les colonnes portent alors les
  /// totaux du combat, groupe compris. Une seule liste pour les deux usages —
  /// le tri, l'entete et les colonnes sont les memes, seule la source des
  /// chiffres change.
  final String? personnage;
  final Ressources res;
  final void Function(Combat) onCombat;

  /// Le bandeau « COMBATS · n combats » au-dessus de la liste.
  ///
  /// Efface dans le detail d'une session : le resume juste au-dessus donne
  /// deja le compte, et le redire coutait une bande de hauteur sur un ecran
  /// qui en manque.
  final bool avecTitre;

  @override
  State<PageCombats> createState() => _PageCombatsState();
}

class _PageCombatsState extends State<PageCombats> {
  Tri _tri = Tri.fin;
  bool _decroissant = true;

  // Un getter et non une constante : les libelles changent avec la langue.
  static List<(Colonne, Tri)> get _colonnes => [
    // En tete, etroite, et sans intitule : une coupe et un crane se
    // reconnaissent sans qu'on les annonce, et le nom de la colonne prenait
    // trois fois la largeur de ce qu'elle montre. L'en-tete reste cliquable
    // et porte alors la fleche du tri, qui suffit a dire ce qu'elle fait.
    //
    // Soixante-quatre et non quarante : la cellule se reserve seize pixels de
    // marge de chaque cote, si bien qu'une colonne de quarante n'en laissait
    // que douze — moins que l'icone qu'elle doit montrer.
    (const Colonne('', 64), Tri.issue),
    (Colonne(T.colFinDuCombat, 0), Tri.fin),
    (Colonne(T.colDuree, 110), Tri.duree),
    (Colonne(T.colChallenges, 116), Tri.challenges),
    (Colonne(T.colExperience, 132, Alignment.centerRight), Tri.xp),
    (Colonne(T.colButin, 122, Alignment.centerRight), Tri.kamas),
    (Colonne(T.colObjets, 90, Alignment.centerRight), Tri.objets),
  ];

  void _trie(Tri colonne) => setState(() {
    if (_tri == colonne) {
      _decroissant = !_decroissant;
    } else {
      _tri = colonne;
      _decroissant = true;
    }
  });

  int _valeur(Combat c, Tri tri) {
    final p = _part(c);
    return switch (tri) {
      // Les defaites d'abord en ordre decroissant : ce sont elles qu'on
      // cherche, une victoire n'ayant rien a expliquer.
      Tri.issue => c.victoire ? 0 : 1,
      Tri.fin => (c.fin * 1000).round(),
      Tri.duree => c.duree.round(),
      // Les reussis d'abord, le total ensuite : entre 1/1 et 1/2, le premier
      // est le meilleur combat, et trier sur le seul total les egalise.
      Tri.challenges => c.challengesReussis * 100 + c.challengesSeuls.length,
      Tri.xp => p?.xp ?? c.xp,
      Tri.kamas => p?.kamasTotal ?? c.kamas,
      Tri.objets => p?.unites ?? c.unites,
    };
  }

  /// La part du personnage regarde, ou rien quand on regarde le groupe.
  ParticipantCombat? _part(Combat c) {
    final nom = widget.personnage;
    return nom == null ? null : c.pour(nom);
  }

  /// La liste triee, la clef de tri calculee une fois par combat.
  ///
  /// Un comparateur qui appelle [_valeur] la recalculait deux fois par
  /// comparaison, soit quelques milliers de fois pour une centaine de
  /// combats — et chacune cherchait le participant regarde et reconstruisait
  /// la liste des challenges. Ici, une passe suffit.
  List<Combat> get _tries {
    final avecClef = [for (final c in widget.combats) (_valeur(c, _tri), c)];
    avecClef.sort((a, b) {
      final ordre = a.$1.compareTo(b.$1);
      return _decroissant ? -ordre : ordre;
    });
    return [for (final (_, c) in avecClef) c];
  }

  @override
  Widget build(BuildContext context) {
    if (widget.combats.isEmpty) {
      return Vide(
        T.aucunCombat,
        icone: LucideIcons.shield,
        detail: T.aucunCombatDetail,
      );
    }
    final theme = ShadTheme.of(context);
    final tries = _tries;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (widget.avecTitre)
          Section(
            T.colCombats,
            aDroite: ShadBadge.secondary(
              child: Text(T.nbCombats(widget.combats.length)),
            ),
          ),
        Expanded(
          child: LayoutBuilder(
            builder: (context, contraintes) {
              final colonnes = [for (final (c, _) in _colonnes) c];
              final mesures = largeursDe(colonnes, contraintes.maxWidth);
              return ShadTable.list(
                header: [
                  for (var i = 0; i < _colonnes.length; i++)
                    ShadTableCell.header(
                      child: _entete(
                        theme,
                        _colonnes[i].$1.libelle,
                        _colonnes[i].$2,
                        _colonnes[i].$1.alignement,
                      ),
                    ),
                ],
                columnSpanExtent: (i) => FixedTableSpanExtent(mesures[i]),
                rowSpanExtent: (_) => const FixedTableSpanExtent(46),
                // L'en-tete porte le tri : le perdre en defilant, c'est
                // perdre le seul moyen de reordonner la liste.
                pinnedRowCount: 1,
                onRowTap: (rang) {
                  if (rang >= 1 && rang <= tries.length) {
                    widget.onCombat(tries[rang - 1]);
                  }
                },
                children: [for (final c in tries) _rang(theme, c)],
              );
            },
          ),
        ),
      ],
    );
  }

  /// Une colonne cliquable. Elle porte sa fleche quand elle mene le tri : sans
  /// elle, on ne sait pas ce qu'on regarde.
  ///
  /// Le clic porte sur toute la cellule, non sur le libelle. Une rangee serree
  /// autour de son texte laissait la colonne d'issue, qui n'en a pas, sans la
  /// moindre surface a viser — et de facon generale, viser un mot de dix
  /// pixels de haut pour trier n'a jamais rien apporte.
  Widget _entete(
    ShadThemeData theme,
    String libelle,
    Tri tri,
    Alignment alignement,
  ) {
    final mene = _tri == tri;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => _trie(tri),
        child: Align(
          alignment: alignement,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Le libelle plie plutot que de deborder : la fleche occupe des
              // pixels qui ne lui etaient pas comptes.
              Flexible(
                child: Text(
                  libelle,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.muted.copyWith(
                    fontSize: 10,
                    letterSpacing: 0.9,
                    fontWeight: FontWeight.w600,
                    color: mene
                        ? theme.colorScheme.foreground
                        : theme.colorScheme.mutedForeground,
                  ),
                ),
              ),
              if (mene)
                Icon(
                  _decroissant
                      ? LucideIcons.chevronDown
                      : LucideIcons.chevronUp,
                  size: 12,
                  color: theme.colorScheme.foreground,
                ),
            ],
          ),
        ),
      ),
    );
  }

  /// L'issue du combat, en une icone.
  ///
  /// Celle de **nos** personnages — voir `Combat.victoire`. Le mot au survol :
  /// une coupe et un crane se distinguent d'un coup d'oeil, mais rien ne dit
  /// lequel est la bonne nouvelle a qui ne les a jamais vus.
  Widget _issue(ShadThemeData theme, Combat c) {
    final gagne = c.victoire;
    return Align(
      alignment: Alignment.centerLeft,
      child: Infobulle(
        builder: (_) => Text(gagne ? T.victoire : T.defaite),
        child: Icon(
          gagne ? LucideIcons.trophy : LucideIcons.skull,
          size: 15,
          color: gagne ? Palette.vert : theme.colorScheme.destructive,
        ),
      ),
    );
  }

  /// Les challenges du combat, verts ou rouges selon l'issue.
  ///
  /// Les icones seules, sans leur nom : la colonne dit s'ils sont passes, et
  /// le detail du combat dit lesquels. Il y en a un ou deux — le jeu n'en
  /// propose pas davantage.
  ///
  /// Seuls les challenges y figurent. Les succes valides pendant le combat
  /// rapportent eux aussi de l'experience et des kamas, et le combat d'un boss
  /// porte ses propres objectifs — ne pas laisser mourir d'allie, finir en dix
  /// tours. Ni les uns ni les autres ne sont des challenges, et ils n'ont rien
  /// a faire dans cette colonne.
  Widget _challenges(ShadThemeData theme, Combat c) {
    final defis = c.challengesSeuls;
    if (defis.isEmpty) {
      return Text('—', style: theme.textTheme.muted.copyWith(fontSize: 11));
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final defi in defis)
          Padding(
            padding: const EdgeInsets.only(right: Pas.xs),
            child: _pastille(theme, defi),
          ),
      ],
    );
  }

  Widget _pastille(ShadThemeData theme, ChallengeFait defi) {
    final couleur = defi.reussi ? Palette.vert : theme.colorScheme.destructive;
    final chemin = widget.res.imageChallenge(defi.challengeId);
    return Infobulle(
      builder: (_) => Text(
        '${widget.res.challenge(defi.challengeId)} — '
        '${defi.reussi ? T.reussi : T.echoue}'
        '${defi.bonus != null ? ' (+${defi.bonus}%)' : ''}',
      ),
      child: Container(
        width: 22,
        height: 22,
        decoration: BoxDecoration(
          // Un fond teinte, pas un aplat : l'icone est une silhouette, et sur
          // un rouge plein elle disparaitrait.
          color: couleur.withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(5),
          border: Border.all(color: couleur.withValues(alpha: 0.45)),
        ),
        child: chemin == null
            ? Icon(
                defi.reussi ? LucideIcons.check : LucideIcons.x,
                size: 12,
                color: couleur,
              )
            : Padding(
                padding: const EdgeInsets.all(3),
                // Les icones de challenge sont des silhouettes sombres,
                // invisibles telles quelles : le jeu les teinte selon l'issue.
                child: Image.file(
                  File(chemin),
                  color: couleur,
                  colorBlendMode: BlendMode.srcIn,
                  filterQuality: FilterQuality.medium,
                  errorBuilder: (_, _, _) => Icon(
                    defi.reussi ? LucideIcons.check : LucideIcons.x,
                    size: 12,
                    color: couleur,
                  ),
                ),
              ),
      ),
    );
  }

  List<ShadTableCell> _rang(ShadThemeData theme, Combat c) {
    final p = _part(c);
    final d = c.quand;
    String n(int v) => v.toString().padLeft(2, '0');
    return [
      ShadTableCell(child: _issue(theme, c)),
      ShadTableCell(
        child: Text(
          '${n(d.day)}/${n(d.month)}  '
          '${n(d.hour)}:${n(d.minute)}:${n(d.second)}',
          style: theme.textTheme.small.copyWith(fontSize: 12),
        ),
      ),
      ShadTableCell(
        child: Text(
          formateDuree(c.duree.round()),
          style: theme.textTheme.muted.copyWith(fontSize: 11),
        ),
      ),
      ShadTableCell(child: _challenges(theme, c)),
      ShadTableCell(
        alignment: Alignment.centerRight,
        child: Text(
          '${formateNombre(p?.xp ?? c.xp)} ${T.xp}',
          style: theme.textTheme.small.copyWith(fontSize: 12),
        ),
      ),
      ShadTableCell(
        alignment: Alignment.centerRight,
        child: Kamas(
          p?.kamasTotal ?? c.kamas,
          image: widget.res.imageKamas,
          taille: 12,
        ),
      ),
      ShadTableCell(
        alignment: Alignment.centerRight,
        child: Text(
          '${p?.unites ?? c.unites}',
          style: theme.textTheme.muted.copyWith(fontSize: 11),
        ),
      ),
    ];
  }
}

/// Le recapitulatif d'un combat, tel qu'il etait en jeu.
///
/// Tous les participants, suivis ou non, avec le niveau et la barre de
/// progression **de cet instant** — non recalculee avec l'etat courant. C'est
/// ce que l'archive conserve, et c'est ce qui permet de rouvrir un combat
/// d'hier tel qu'on l'a vu.
class PageRecapitulatif extends StatelessWidget {
  const PageRecapitulatif({
    super.key,
    required this.combat,
    required this.res,
    this.surligne,
  });

  final Combat combat;
  final Ressources res;

  /// Le personnage par lequel on est arrive, mis en avant.
  final String? surligne;

  // Un getter : les libelles changent avec la langue.
  static List<Colonne> get _colonnes => [
    Colonne(T.colPersonnage, 0),
    Colonne(T.colNiveau, 132),
    Colonne(T.colExperience, 132, Alignment.centerRight),
    Colonne(T.colButin, 128, Alignment.centerRight),
    Colonne(T.colObjets, 168),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);
    final d = combat.quand;
    String n(int v) => v.toString().padLeft(2, '0');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ShadCard(
          padding: const EdgeInsets.symmetric(
            horizontal: Pas.l,
            vertical: Pas.m,
          ),
          // Chaque chiffre est souple : le bandeau porte quatre libelles et
          // une date, et sur une fenetre etroite le tout debordait.
          child: Row(
            children: [
              Flexible(
                child: Chiffre(
                  T.termineLe,
                  '${n(d.day)}/${n(d.month)} à '
                  '${n(d.hour)}:${n(d.minute)}:${n(d.second)}',
                  icone: LucideIcons.clock,
                  souple: true,
                ),
              ),
              const SizedBox(width: Pas.l),
              Flexible(
                child: Chiffre(
                  T.colDuree,
                  formateDuree(combat.duree.round()),
                  icone: LucideIcons.timer,
                  souple: true,
                ),
              ),
              const SizedBox(width: Pas.l),
              Flexible(
                child: Chiffre(
                  T.colExperience,
                  formateNombre(combat.xp),
                  icone: LucideIcons.trendingUp,
                  souple: true,
                ),
              ),
              const SizedBox(width: Pas.l),
              Flexible(
                child: Chiffre(
                  T.colButin,
                  formateNombre(combat.kamas),
                  couleur: theme.colorScheme.primary,
                  icone: LucideIcons.coins,
                  kamas: res.imageKamas,
                  souple: true,
                ),
              ),
              const Spacer(),
              ShadBadge.secondary(
                child: Text('${combat.participants.length} participants'),
              ),
            ],
          ),
        ),
        if (combat.challengesSeuls.isNotEmpty) ...[
          const SizedBox(height: Pas.m),
          Wrap(
            spacing: Pas.s,
            runSpacing: Pas.s,
            children: [
              for (final c in combat.challengesSeuls) _challenge(context, c),
            ],
          ),
        ],
        // Les vainqueurs en haut, quels qu'ils soient.
        //
        // Le bloc du haut portait nos personnages et celui du bas les
        // monstres, ce qui ne tenait qu'aussi longtemps qu'on gagnait : un
        // combat perdu rangeait les vainqueurs en second, sous le titre
        // « perdants ». Les deux blocs suivent desormais la seule question qui
        // les separe — qui l'a emporte — et chacun porte ce qui lui revient,
        // un tableau pour les personnages, des vignettes pour ceux d'en face.
        ..._bloc(
          context,
          titre: T.gagnants,
          personnages: combat.gagnants,
          enFace: combat.adversairesGagnants,
          siVide: T.personneNaGagne,
        ),
        ..._bloc(
          context,
          titre: T.perdants,
          personnages: combat.perdants,
          enFace: combat.adversairesPerdants,
        ),
      ],
    );
  }

  /// Un bloc d'issue : son titre, son compte, et ce qu'il contient.
  ///
  /// Rien du tout quand il est vide, sauf a porter un texte de remplacement —
  /// c'est le cas du bloc des vainqueurs, ou le silence serait ambigu : on ne
  /// saurait pas si personne n'a gagne ou si l'outil n'en sait rien.
  ///
  /// Le tableau prend la hauteur qui reste, les vignettes se contentent de la
  /// leur. Quand les deux blocs portent des personnages — l'un a fui, les
  /// autres ont gagne — les deux tableaux se partagent la place.
  List<Widget> _bloc(
    BuildContext context, {
    required String titre,
    required List<ParticipantCombat> personnages,
    required List<Adversaire> enFace,
    String? siVide,
  }) {
    final vide = personnages.isEmpty && enFace.isEmpty;
    if (vide && siVide == null) return const [];
    return [
      const SizedBox(height: Pas.m),
      Section(
        titre,
        aDroite: vide
            ? null
            : ShadBadge.secondary(
                child: Text('${personnages.length + enFace.length}'),
              ),
      ),
      // Sans `Expanded` : le message prend la hauteur de son texte et laisse
      // la place au bloc d'en dessous, qui porte alors tout le monde.
      if (vide)
        Vide(siVide!, icone: LucideIcons.shieldOff)
      else ...[
        if (personnages.isNotEmpty)
          Expanded(
            child: Tableau(
              colonnes: _colonnes,
              hauteurLigne: 52,
              lignes: [for (final p in personnages) _rang(context, p)],
            ),
          ),
        if (enFace.isNotEmpty)
          Padding(
            padding: EdgeInsets.only(top: personnages.isEmpty ? 0 : Pas.s),
            child: _vignettes(context, enFace),
          ),
      ],
    ];
  }

  /// Les combattants d'en face, groupes comme le jeu les groupe.
  ///
  /// Deux Krokilles identiques font une vignette portant « x2 » : quatre
  /// vignettes jumelles cote a cote se lisent mal, et le compte est ce qu'on
  /// veut savoir.
  Widget _vignettes(BuildContext context, List<Adversaire> enFace) {
    final compte = <(int?, int?), int>{};
    for (final a in enFace) {
      final cle = (a.monstre, a.grade);
      compte[cle] = (compte[cle] ?? 0) + 1;
    }
    final lots = compte.entries.toList()
      // Les inconnus en dernier : ils n'apprennent rien, ils constatent.
      ..sort((a, b) {
        if ((a.key.$1 == null) != (b.key.$1 == null)) {
          return a.key.$1 == null ? 1 : -1;
        }
        return b.value.compareTo(a.value);
      });
    return Wrap(
      spacing: Pas.s,
      runSpacing: Pas.s,
      children: [
        for (final lot in lots)
          _vignette(context, lot.key.$1, lot.key.$2, lot.value),
      ],
    );
  }

  Widget _vignette(
    BuildContext context,
    int? monstre,
    int? grade,
    int combien,
  ) {
    final theme = ShadTheme.of(context);
    final chemin = monstre == null ? null : res.imageMonstre(monstre);
    final niveau = monstre == null ? null : res.niveauMonstre(monstre, grade);
    final vignette = Container(
      padding: const EdgeInsets.fromLTRB(Pas.s, Pas.xs, Pas.m, Pas.xs),
      decoration: BoxDecoration(
        color: theme.colorScheme.muted,
        borderRadius: theme.radius,
        border: Border.all(color: theme.colorScheme.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 30,
            height: 30,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Positioned.fill(
                  child: chemin == null
                      ? Icon(
                          LucideIcons.swords,
                          size: 16,
                          color: theme.colorScheme.mutedForeground,
                        )
                      : Image.file(
                          File(chemin),
                          filterQuality: FilterQuality.medium,
                          errorBuilder: (_, _, _) => const SizedBox.shrink(),
                        ),
                ),
                if (combien > 1)
                  Positioned(
                    left: -2,
                    top: -2,
                    child: Text(
                      'x$combien',
                      style: theme.textTheme.small.copyWith(
                        fontSize: 9,
                        height: 1.2,
                        fontWeight: FontWeight.w700,
                        color: theme.colorScheme.mutedForeground,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: Pas.s),
          Text(
            monstre == null ? T.adversaireInconnu : res.monstre(monstre),
            style: theme.textTheme.small.copyWith(
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (niveau != null) ...[
            const SizedBox(width: Pas.s),
            Text(
              'Niv. $niveau',
              style: theme.textTheme.muted.copyWith(fontSize: 12),
            ),
          ],
        ],
      ),
    );
    if (monstre != null) return vignette;
    // Un adversaire sans nom n'est pas une donnee perdue mais une donnee
    // jamais recue : on dit laquelle, et pourquoi.
    return Infobulle(
      builder: (_) => const Text(
        'Le combat avait commencé avant que l\'outil n\'écoute.\n'
        'Le récapitulatif ne nomme pas les perdants : leur espèce\n'
        'est annoncée au placement, qui a eu lieu sans nous.',
      ),
      child: vignette,
    );
  }

  Widget _challenge(BuildContext context, ChallengeFait c) {
    final theme = ShadTheme.of(context);
    final couleur = c.reussi ? Palette.vert : theme.colorScheme.destructive;
    final chemin = res.imageChallenge(c.challengeId);
    return Infobulle(
      // Le protocole n'attribue pas l'issue a un joueur : les quatre clients
      // recoivent le meme message. On cite donc qui combattait.
      builder: (_) => Text(
        '${res.challenge(c.challengeId)} — '
        '${c.reussi ? T.reussi : T.echoue}'
        '${c.bonus != null ? ' (+${c.bonus}%)' : ''}\n'
        'Combattants : ${c.combattants.join(', ')}',
      ),
      child: ShadBadge.outline(
        foregroundColor: couleur,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (chemin != null) ...[
              SizedBox(
                width: 12,
                height: 12,
                child: Image.file(
                  File(chemin),
                  color: couleur,
                  colorBlendMode: BlendMode.srcIn,
                  errorBuilder: (_, _, _) => const SizedBox.shrink(),
                ),
              ),
              const SizedBox(width: Pas.xs + 1),
            ],
            Text(res.challenge(c.challengeId)),
            Text(c.reussi ? '  ✓' : '  ✕'),
          ],
        ),
      ),
    );
  }

  List<Widget> _rang(BuildContext context, ParticipantCombat p) {
    final theme = ShadTheme.of(context);
    final sien = surligne != null && cleDe(p.nom) == cleDe(surligne!);
    // Par valeur decroissante : les cinq montres sont alors les cinq qui
    // comptent, et le « +n » ne cache que du menu fretin.
    final lots = <LotObjet>[
      for (final e in p.butin.entries) (e.key, e.value.$1, e.value.$2),
    ]..sort((a, b) => ((b.$3 ?? 0) * b.$2).compareTo((a.$3 ?? 0) * a.$2));
    final nom = Text(
      p.nom,
      overflow: TextOverflow.ellipsis,
      style: theme.textTheme.small.copyWith(
        fontSize: 13,
        color: p.suivi
            ? (sien ? theme.colorScheme.primary : theme.colorScheme.foreground)
            // En demi-teinte : il a combattu avec nous, mais ses gains ne
            // sont pas dans nos totaux, et la ligne doit le dire avant qu'on
            // ne cherche pourquoi la somme ne tombe pas juste.
            : theme.colorScheme.mutedForeground,
        fontWeight: sien ? FontWeight.w600 : FontWeight.w500,
      ),
    );
    final identite = p.suivi
        ? nom
        : Infobulle(
            builder: (_) => Text(T.invitePasCompte(p.nom)),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(child: nom),
                const SizedBox(width: Pas.xs + 1),
                Icon(
                  LucideIcons.userMinus,
                  size: 12,
                  color: theme.colorScheme.mutedForeground,
                ),
              ],
            ),
          );
    return [
      Row(
        children: [
          // La case est reservee meme vide : la classe n'arrive qu'au passage
          // sur une carte, et les pseudos ne doivent pas se decaler d'une
          // ligne a l'autre selon que l'on connait celle-ci ou non.
          _enRetrait(p, SizedBox(width: 26, height: 26, child: _portrait(p))),
          const SizedBox(width: Pas.s),
          Flexible(child: identite),
        ],
      ),
      _enRetrait(
        p,
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '${p.niveau ?? '—'}',
              style: theme.textTheme.small.copyWith(fontSize: 13),
            ),
            const SizedBox(height: Pas.xs + 1),
            SizedBox(
              width: 96,
              child: ShadProgress(
                value: p.progression,
                minHeight: 5,
                color: theme.colorScheme.primary,
              ),
            ),
          ],
        ),
      ),
      _enRetrait(
        p,
        Text(
          '${formateNombre(p.xp)} ${T.xp}',
          style: theme.textTheme.small.copyWith(fontSize: 12),
        ),
      ),
      _enRetrait(
        p,
        Infobulle(
          builder: (_) => Text(
            '${T.kamasEnPiece} : ${formateNombre(p.kamas)}\n'
            '${T.valeurEstimee} : '
            '${formateNombre(p.valeurButin)}',
          ),
          child: Kamas(p.kamasTotal, image: res.imageKamas, taille: 12),
        ),
      ),
      _enRetrait(
        p,
        RangeeObjets(lots: lots, res: res, titrePopover: T.butinDe(p.nom)),
      ),
    ];
  }

  /// Le portrait de sa classe, s'il est connu.
  ///
  /// La classe est celle notee au moment du combat : l'archive la porte, et
  /// c'est ce qui permet de rouvrir un combat d'hier avec les bons visages.
  /// Elle manque pour un personnage croise sans l'avoir vu hors combat — la
  /// case reste alors vide plutot que de montrer un portrait au hasard.
  Widget? _portrait(ParticipantCombat p) {
    final chemin = res.imageClasse(p.classe);
    return chemin == null
        ? null
        : Image.file(
            File(chemin),
            filterQuality: FilterQuality.medium,
            errorBuilder: (_, _, _) => const SizedBox.shrink(),
          );
  }

  /// Ce qui n'entre pas dans les totaux se lit en retrait.
  ///
  /// Le pseudo seul ne suffisait pas : la ligne restait aussi franche que les
  /// autres, et l'oeil additionnait des chiffres qui ne comptent pas.
  ///
  /// La moitie et non moins : les icones d'objets gardent alors assez de
  /// couleur pour se reconnaitre, ce qui est tout leur interet — on veut
  /// toujours voir ce que l'ami a ramasse, simplement pas le compter.
  Widget _enRetrait(ParticipantCombat p, Widget enfant) =>
      p.suivi ? enfant : Opacity(opacity: 0.5, child: enfant);
}
