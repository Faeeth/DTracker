/// Les equipes, leurs personnages et les touches qui les ramenent au premier
/// plan.
///
/// Independant du suivi : rien de ce qui est ici ne lit une session ni un
/// combat. C'est un outil de fenetres qui partage la fenetre du tracker, pas
/// une vue de plus sur ses donnees.
///
/// Une equipe reste activee meme quand on ne la joue pas. Plusieurs
/// personnages partagent la meme touche et c'est celui dont la fenetre existe
/// qui repond : changer d'equipe se fait dans le jeu, pas ici. Les
/// interrupteurs servent a ecarter ce qu'on ne joue plus, pas a jongler.
library;

import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart' hide Cache;

import '../../../i18n/textes.dart';
import '../../../modele/organizer.dart';
import '../../../source/organizer.dart';
import '../../../source/ressources.dart';
import '../briques.dart';
import 'organizer_dialogues.dart';

class PageOrganizer extends StatefulWidget {
  const PageOrganizer({super.key, required this.organizer, required this.res});

  final Organizer organizer;

  /// Les portraits de classe, partages avec le suivi.
  final Ressources res;

  @override
  State<PageOrganizer> createState() => _PageOrganizerState();
}

class _PageOrganizerState extends State<PageOrganizer> {
  @override
  void initState() {
    super.initState();
    // Une touche refusee l'est presque toujours parce qu'une autre application
    // la tenait au demarrage. Revenir sur la page est le moment ou l'on vient
    // constater le probleme : autant retenter d'abord, la plainte disparait
    // souvent d'elle-meme.
    widget.organizer.reessaie();
  }

  @override
  Widget build(BuildContext context) {
    final organizer = widget.organizer;
    return ListenableBuilder(
      listenable: organizer,
      builder: (context, _) {
        if (organizer.equipes.isEmpty) {
          return Vide(
            T.aucuneEquipe,
            icone: LucideIcons.users,
            detail: T.aucuneEquipeDetail,
            action: ShadButton(
              leading: const Icon(LucideIcons.plus, size: 16),
              onPressed: () => nouvelleEquipe(context, organizer),
              child: Text(T.creerEquipe),
            ),
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Le contenu des pages commence contre l'en-tete : ailleurs c'est
            // une carte qui l'absorbe, ici c'est un bouton, qui s'y collait.
            const SizedBox(height: Pas.m),
            _Bandeau(organizer: organizer),
            const SizedBox(height: Pas.m),
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.only(bottom: Pas.l),
                itemCount: organizer.equipes.length,
                separatorBuilder: (_, _) => const SizedBox(height: Pas.m),
                itemBuilder: (context, index) => _CarteEquipe(
                  organizer: organizer,
                  res: widget.res,
                  equipe: organizer.equipes[index],
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

/// Ce que font les raccourcis en ce moment, et le bouton qui ajoute une
/// equipe.
class _Bandeau extends StatelessWidget {
  const _Bandeau({required this.organizer});

  final Organizer organizer;

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);
    final appel = organizer.dernierAppel;
    // Seuls les appels sans reponse remontent ici : dire quel personnage a
    // repondu n'apprend rien, la fenetre est deja devant les yeux.
    final manque = appel != null && !appel.trouve;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            _Pastille(
              couleur: organizer.enCapture
                  ? theme.colorScheme.primary
                  : (organizer.actifs > 0
                        ? const Color(0xFF4ADE80)
                        : theme.colorScheme.mutedForeground),
            ),
            const SizedBox(width: Pas.s),
            Text(
              organizer.enCapture
                  ? T.captureEnCours
                  : T.raccourcisActifs(organizer.actifs),
              style: theme.textTheme.muted,
            ),
            if (organizer.aDesConflits) ...[
              const SizedBox(width: Pas.m),
              Icon(
                LucideIcons.triangleAlert,
                size: 14,
                color: theme.colorScheme.destructive,
              ),
              const SizedBox(width: Pas.xs),
              Text(
                T.raccourcisRefuses(organizer.refuses),
                style: theme.textTheme.muted.copyWith(
                  color: theme.colorScheme.destructive,
                ),
              ),
              const SizedBox(width: Pas.xs),
              ShadButton.ghost(
                size: ShadButtonSize.sm,
                leading: const Icon(LucideIcons.refreshCw, size: 13),
                onPressed: organizer.reessaie,
                child: Text(T.reessayer),
              ),
            ],
            const Spacer(),
            ShadButton.outline(
              leading: const Icon(LucideIcons.plus, size: 14),
              onPressed: () => nouvelleEquipe(context, organizer),
              child: Text(T.equipe),
            ),
          ],
        ),
        // Sur sa propre ligne : c'est le nom cherche qui compte, et il etait
        // le premier a disparaitre quand la phrase partageait la largeur avec
        // le reste du bandeau.
        if (manque)
          Padding(
            padding: const EdgeInsets.only(top: Pas.xs, left: 16),
            child: Text(
              T.aucuneFenetreTrouvee(appel.cherches.join(', ')),
              style: theme.textTheme.muted.copyWith(
                color: theme.colorScheme.destructive,
              ),
            ),
          ),
      ],
    );
  }
}

class _Pastille extends StatelessWidget {
  const _Pastille({required this.couleur});

  final Color couleur;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 8,
      height: 8,
      decoration: BoxDecoration(color: couleur, shape: BoxShape.circle),
    );
  }
}

class _CarteEquipe extends StatelessWidget {
  const _CarteEquipe({
    required this.organizer,
    required this.res,
    required this.equipe,
  });

  final Organizer organizer;
  final Ressources res;
  final EquipeOrganizer equipe;

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);
    final vivants = equipe.vivants.length;
    return ShadCard(
      padding: const EdgeInsets.all(Pas.m),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              ShadSwitch(
                value: equipe.active,
                onChanged: (v) => organizer.activeEquipe(equipe.id, v),
              ),
              const SizedBox(width: Pas.s),
              // Tout l'en-tete plie et deplie, pas seulement le chevron :
              // viser une fleche de seize pixels pour refermer une equipe
              // serait une precision inutile.
              Expanded(
                child: ShadTooltip(
                  builder: (_) => Text(
                    equipe.replie ? T.deplierEquipe : T.replierEquipe,
                  ),
                  child: MouseRegion(
                    cursor: SystemMouseCursors.click,
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () =>
                          organizer.replieEquipe(equipe.id, !equipe.replie),
                      child: Row(
                        children: [
                          AnimatedRotation(
                            turns: equipe.replie ? -0.25 : 0,
                            duration: const Duration(milliseconds: 150),
                            child: Icon(
                              LucideIcons.chevronDown,
                              size: 16,
                              color: theme.colorScheme.mutedForeground,
                            ),
                          ),
                          const SizedBox(width: Pas.s),
                          Flexible(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Flexible(
                                      child: Text(
                                        equipe.nom,
                                        overflow: TextOverflow.ellipsis,
                                        style: theme.textTheme.large.copyWith(
                                          fontSize: 14,
                                          color: equipe.active
                                              ? theme.colorScheme.foreground
                                              : theme
                                                    .colorScheme
                                                    .mutedForeground,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: Pas.m),
                                    _Composition(
                                      res: res,
                                      equipe: equipe,
                                    ),
                                  ],
                                ),
                                Text(
                                  equipe.active
                                      ? T.resumeEquipe(
                                          vivants,
                                          equipe.personnages.length,
                                        )
                                      : T.equipeDesactivee,
                                  style: theme.textTheme.muted,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              ShadTooltip(
                builder: (_) => Text(T.isolerEquipe),
                child: ShadIconButton.ghost(
                  icon: const Icon(LucideIcons.zap, size: 15),
                  onPressed: () => organizer.isoleEquipe(equipe.id),
                ),
              ),
              ShadTooltip(
                builder: (_) => Text(T.ajouterPersonnage),
                child: ShadIconButton.ghost(
                  icon: const Icon(LucideIcons.userPlus, size: 15),
                  onPressed: () =>
                      nouveauPersonnage(context, organizer, res, equipe.id),
                ),
              ),
              _MenuEquipe(organizer: organizer, equipe: equipe),
            ],
          ),
          if (!equipe.replie)
            if (equipe.personnages.isEmpty)
              Padding(
                padding: const EdgeInsets.only(top: Pas.m, left: Pas.xs),
                child: Text(T.equipeVide, style: theme.textTheme.muted),
              )
            else ...[
              const SizedBox(height: Pas.s),
              for (final personnage in equipe.personnages)
                _LignePersonnage(
                  organizer: organizer,
                  res: res,
                  equipe: equipe,
                  personnage: personnage,
                ),
            ],
        ],
      ),
    );
  }
}

/// Les classes de l'equipe en petit, a cote de son nom.
///
/// C'est ce qui la nomme vraiment : « les pandas », « les cras ». Utile
/// surtout quand elle est repliee, ou il ne reste que cette ligne.
///
/// Les personnages sans classe n'y figurent pas : un pictogramme generique
/// repete n'apprendrait rien et brouillerait la lecture.
class _Composition extends StatelessWidget {
  const _Composition({required this.res, required this.equipe});

  final Ressources res;
  final EquipeOrganizer equipe;

  @override
  Widget build(BuildContext context) {
    final classes = [
      for (final p in equipe.personnages)
        if (p.classe != null) p,
    ];
    if (classes.isEmpty) return const SizedBox.shrink();
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final p in classes)
          Padding(
            padding: const EdgeInsets.only(right: 2),
            child: PortraitClasse(
              res: res,
              classe: p.classe,
              feminin: p.feminin,
              taille: 20,
              eteint: !equipe.active || !p.actif,
            ),
          ),
      ],
    );
  }
}

class _MenuEquipe extends StatelessWidget {
  const _MenuEquipe({required this.organizer, required this.equipe});

  final Organizer organizer;
  final EquipeOrganizer equipe;

  @override
  Widget build(BuildContext context) {
    return ShadContextMenuRegion(
      visible: false,
      items: const [],
      child: ShadIconButton.ghost(
        icon: const Icon(LucideIcons.ellipsisVertical, size: 15),
        onPressed: () => menuEquipe(context, organizer, equipe),
      ),
    );
  }
}

/// Une ligne : de quoi activer, reconnaitre, et changer la touche.
class _LignePersonnage extends StatelessWidget {
  const _LignePersonnage({
    required this.organizer,
    required this.res,
    required this.equipe,
    required this.personnage,
  });

  final Organizer organizer;
  final Ressources res;
  final EquipeOrganizer equipe;
  final PersonnageOrganizer personnage;

  bool get _vivant => equipe.active && personnage.actif;

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          ShadTooltip(
            builder: (_) => Text(
              personnage.actif ? T.desactiverPersonnage : T.activerPersonnage,
            ),
            child: ShadCheckbox(
              value: personnage.actif,
              onChanged: (v) =>
                  organizer.activePersonnage(equipe.id, personnage.id, v),
            ),
          ),
          const SizedBox(width: Pas.m),
          // Le portrait vient avant le nom : dans une liste de huit
          // personnages, c'est lui qu'on reconnait d'abord.
          PortraitClasse(
            res: res,
            classe: personnage.classe,
            feminin: personnage.feminin,
            eteint: !_vivant,
          ),
          const SizedBox(width: Pas.s),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  personnage.nom,
                  style: theme.textTheme.p.copyWith(
                    fontSize: 13,
                    color: _vivant
                        ? theme.colorScheme.foreground
                        : theme.colorScheme.mutedForeground,
                  ),
                ),
                Text(
                  '« ${personnage.titre} »',
                  style: theme.textTheme.muted.copyWith(fontSize: 11),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          EtiquetteRaccourci(
            raccourci: personnage.raccourci,
            eteinte: !_vivant,
            enConflit: organizer.enConflit(personnage),
            onTap: () => changeRaccourci(
              context,
              organizer,
              equipe.id,
              personnage,
            ),
          ),
          const SizedBox(width: Pas.xs),
          ShadIconButton.ghost(
            icon: const Icon(LucideIcons.pencil, size: 14),
            onPressed: () => modifiePersonnage(
              context,
              organizer,
              res,
              equipe.id,
              personnage,
            ),
          ),
          ShadIconButton.ghost(
            icon: const Icon(LucideIcons.trash2, size: 14),
            onPressed: () =>
                organizer.supprimePersonnage(equipe.id, personnage.id),
          ),
        ],
      ),
    );
  }
}
