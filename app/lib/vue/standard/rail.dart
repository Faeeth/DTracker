/// Le rail de navigation, a gauche.
///
/// `ShadTabs` ne conviendrait pas ici : il est horizontal en dur — son
/// `scrollDirection` vaut `Axis.horizontal` dans le paquet. Le rail est donc
/// bati en `ShadButton.ghost`, qui donne le survol, le focus et le curseur
/// sans qu'on ait a les redessiner ; seul l'etat actif est peint a la main,
/// parce qu'un bouton ne connait pas la notion de « selectionne ».
///
/// Il ne se replie pas : un rail qu'on ouvre et referme est un rail dont on ne
/// sait jamais dans quel etat il est, et la fenetre est assez large pour le
/// porter.
library;

import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart' hide Cache;

import '../../source/flux.dart';
import '../../theme.dart';
import 'briques.dart';
import 'navigation.dart';
import '../../i18n/textes.dart';

class Rail extends StatelessWidget {
  const Rail({
    super.key,
    required this.actif,
    required this.onChoisit,
    required this.etat,
    required this.diagnostic,
    required this.nomSession,
    required this.duree,
    required this.enPause,
    required this.onRenomme,
    required this.onPause,
    required this.onReset,
    required this.onCompact,
  });

  final Onglet actif;
  final void Function(Onglet) onChoisit;
  final EtatFlux etat;
  final String diagnostic;
  final String nomSession;
  final String duree;
  final bool enPause;
  final void Function(String) onRenomme;
  final VoidCallback onPause;
  final VoidCallback onReset;
  final VoidCallback onCompact;

  /// Deux sous-menus se sont ajoutes sous « Suivi », en retrait : le rail a
  /// pris de quoi les porter sans que leur libelle ne soit tronque.
  static const largeur = 244.0;

  static const _icones = {
    Onglet.suivi: LucideIcons.layoutDashboard,
    Onglet.mesCombats: LucideIcons.swords,
    Onglet.monInventaire: LucideIcons.package,
    Onglet.sessions: LucideIcons.history,
    Onglet.reglages: LucideIcons.settings,
  };

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);
    return Container(
      width: largeur,
      padding: const EdgeInsets.all(Pas.m),
      decoration: BoxDecoration(
        color: theme.colorScheme.card,
        border: Border(right: BorderSide(color: theme.colorScheme.border)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _marque(context),
          const SizedBox(height: Pas.m),
          _session(context),
          const SizedBox(height: Pas.l),
          for (final onglet in Onglet.values) ...[
            _Destination(
              icone: _icones[onglet]!,
              onglet: onglet,
              // Un sous-menu s'allume seul. Sa racine reste en demi-teinte
              // quand on est dans l'une de ses branches : elle situe sans
              // pretendre etre l'ecran ouvert.
              choisi: onglet == actif,
              rattachee: onglet != actif && onglet == actif.racine,
              onTap: () => onChoisit(onglet),
            ),
            const SizedBox(height: Pas.xs),
          ],
          const Spacer(),
          _commandes(),
          const SizedBox(height: Pas.m),
          _liaison(context),
        ],
      ),
    );
  }

  Widget _marque(BuildContext context) {
    final theme = ShadTheme.of(context);
    return Row(
      children: [
        Icon(LucideIcons.swords, size: 15, color: theme.colorScheme.primary),
        const SizedBox(width: Pas.s),
        Text(
          T.marque,
          style: theme.textTheme.small.copyWith(
            fontSize: 12,
            letterSpacing: 0.2,
            fontWeight: FontWeight.w700,
          ),
        ),
        const Spacer(),
        // L'icone seule ne dit pas ou elle mene : deux fleches qui se
        // rapprochent peuvent aussi bien reduire la fenetre que replier un
        // panneau.
        Infobulle(
          builder: (_) => Text(T.vueCompacte),
          child: ShadIconButton.ghost(
            icon: const Icon(LucideIcons.shrink, size: 14),
            height: 26,
            width: 26,
            onPressed: onCompact,
          ),
        ),
      ],
    );
  }

  /// Ce que prend un `ShadBadge` de haut, badge absent ou non.
  static const hauteurBadge = 20.0;

  /// La session dans sa propre carte : c'est l'objet auquel tout le reste se
  /// rapporte, et le sortir du flot le dit sans un mot.
  Widget _session(BuildContext context) {
    final theme = ShadTheme.of(context);
    return ShadCard(
      padding: const EdgeInsets.all(Pas.s + 2),
      backgroundColor: theme.colorScheme.background,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          _NomSession(nom: nomSession, onRenomme: onRenomme),
          const SizedBox(height: Pas.xs + 2),
          // Hauteur fixee : le badge « en pause » est plus haut que le
          // chronometre qu'il accompagne, et son apparition faisait grandir la
          // carte — tout le rail descendait de quelques pixels au moment ou
          // l'on clique sur Pause.
          SizedBox(
            height: hauteurBadge,
            child: Row(
              children: [
                Icon(
                  enPause ? LucideIcons.pause : LucideIcons.timer,
                  size: 12,
                  color: theme.colorScheme.mutedForeground,
                ),
                const SizedBox(width: Pas.xs + 1),
                Text(
                  duree,
                  style: theme.textTheme.small.copyWith(
                    fontSize: 12,
                    letterSpacing: 0.4,
                    color: theme.colorScheme.mutedForeground,
                  ),
                ),
                if (enPause) ...[
                  const Spacer(),
                  // Serre plutot que deborde : le rail est etroit, et un badge
                  // a sa taille naturelle sortait de la carte des que la duree
                  // passait l'heure.
                  Flexible(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerRight,
                      child: ShadBadge.secondary(child: Text(T.enPause)),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Les deux commandes de la session, a parts egales.
  ///
  /// Reset etait une icone nue, large de trente-deux pixels : il fallait
  /// s'arreter dessus pour apprendre ce qu'elle faisait — or elle clot la
  /// session, ce qui ne se decouvre pas apres coup. Nomme, et de meme
  /// largeur que Pause.
  ///
  /// Le rail est etroit : sans reduire leurs marges, les deux libelles et
  /// leurs deux glyphes debordaient d'une dizaine de pixels.
  Widget _commandes() {
    const marge = EdgeInsets.symmetric(horizontal: Pas.xs + 1);
    const ecart = 6.0;
    return Row(
      children: [
        Expanded(
          child: enPause
              ? ShadButton(
                  size: ShadButtonSize.sm,
                  padding: marge,
                  gap: ecart,
                  expands: true,
                  leading: const Icon(LucideIcons.play, size: 14),
                  onPressed: onPause,
                  child: _libelle(T.reprendre),
                )
              : ShadButton.outline(
                  size: ShadButtonSize.sm,
                  padding: marge,
                  gap: ecart,
                  expands: true,
                  leading: const Icon(LucideIcons.pause, size: 14),
                  onPressed: onPause,
                  child: _libelle(T.pause),
                ),
        ),
        const SizedBox(width: Pas.s),
        Expanded(
          child: Infobulle(
            builder: (_) => Text(T.resetInfobulle),
            child: ShadButton.outline(
              size: ShadButtonSize.sm,
              padding: marge,
              gap: ecart,
              expands: true,
              leading: const Icon(LucideIcons.rotateCcw, size: 14),
              onPressed: onReset,
              child: _libelle(T.reset),
            ),
          ),
        ),
      ],
    );
  }

  /// Un libelle de commande, qui se serre plutot que de deborder.
  ///
  /// « Reprendre » est nettement plus long que « Pause » : a deux boutons de
  /// meme largeur dans un rail de deux cent vingt pixels, il debordait d'une
  /// trentaine. Il se reduit donc de lui-meme, et les libelles courts gardent
  /// leur taille.
  Widget _libelle(String texte) =>
      FittedBox(fit: BoxFit.scaleDown, child: Text(texte, maxLines: 1));

  Widget _liaison(BuildContext context) {
    final theme = ShadTheme.of(context);
    final (libelle, couleur) = switch (etat) {
      EtatFlux.connecte => (T.fluxConnecte, Palette.vert),
      EtatFlux.liee => (T.fluxEnAttente, Palette.jaune),
      EtatFlux.attente => (T.fluxInjoignable, theme.colorScheme.destructive),
      EtatFlux.erreur => (T.fluxIndisponible, theme.colorScheme.destructive),
      EtatFlux.arrete => (T.fluxDeconnecte, theme.colorScheme.destructive),
    };
    return Infobulle(
      builder: (_) => Text(diagnostic),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: Pas.s, vertical: Pas.s),
        decoration: BoxDecoration(
          color: theme.colorScheme.background,
          borderRadius: theme.radius,
          border: Border.all(color: couleur.withValues(alpha: 0.28)),
        ),
        child: Row(
          children: [
            // La pastille a son halo : sur un fond sombre, huit pixels de
            // couleur plate se remarquent moins qu'on ne le croit.
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: couleur,
                boxShadow: [
                  BoxShadow(
                    color: couleur.withValues(alpha: 0.5),
                    blurRadius: 8,
                  ),
                ],
              ),
            ),
            const SizedBox(width: Pas.s),
            Expanded(
              child: Text(
                libelle,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.small.copyWith(fontSize: 11),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Une entree du rail.
///
/// L'etat actif se signale par trois choses a la fois : le fond teinte, la
/// couleur de l'icone et celle du libelle, en gras. Une seule ne suffirait
/// pas — le fond seul se confond avec le survol, la couleur seule se rate
/// dans un coup d'oeil rapide.
class _Destination extends StatelessWidget {
  const _Destination({
    required this.icone,
    required this.onglet,
    required this.choisi,
    required this.onTap,
    this.rattachee = false,
  });

  final IconData icone;
  final Onglet onglet;
  final bool choisi;

  /// La racine de la branche ouverte, sans etre l'ecran courant.
  final bool rattachee;

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);
    final sous = onglet.estSousMenu;
    final teinte = choisi
        ? theme.colorScheme.primary
        : theme.colorScheme.mutedForeground;
    return ShadButton.ghost(
      // Un sous-menu est plus bas et plus court : le retrait se lit avant le
      // libelle, et c'est ce qui dit qu'il depend de l'entree du dessus.
      height: sous ? 32 : 38,
      width: double.infinity,
      mainAxisAlignment: MainAxisAlignment.start,
      backgroundColor: choisi
          ? theme.colorScheme.primary.withValues(alpha: 0.12)
          : rattachee
          ? theme.colorScheme.accent.withValues(alpha: 0.5)
          : null,
      hoverBackgroundColor: theme.colorScheme.accent,
      padding: EdgeInsets.only(
        left: sous ? Pas.l + Pas.xs : Pas.m,
        right: Pas.m,
      ),
      decoration: ShadDecoration(border: ShadBorder(radius: theme.radius)),
      leading: Icon(icone, size: sous ? 14 : 16, color: teinte),
      onPressed: onTap,
      // `Flexible` et non `Align` : la rangee interne du bouton s'ajuste a son
      // contenu, et un libelle un peu long — « Mon inventaire », en retrait —
      // la faisait deborder. Le rail a une largeur fixe, la contrainte est
      // donc bornee et le texte peut ceder.
      child: Flexible(
        child: Text(
          onglet.libelle,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.small.copyWith(
            fontSize: sous ? 12 : 13,
            color: choisi
                ? theme.colorScheme.foreground
                : theme.colorScheme.mutedForeground,
            fontWeight: choisi ? FontWeight.w600 : FontWeight.w500,
          ),
        ),
      ),
    );
  }
}

/// Le nom de la session, modifiable sur place.
class _NomSession extends StatefulWidget {
  const _NomSession({required this.nom, required this.onRenomme});

  final String nom;
  final void Function(String) onRenomme;

  @override
  State<_NomSession> createState() => _NomSessionState();
}

class _NomSessionState extends State<_NomSession> {
  bool _edite = false;
  final _champ = TextEditingController();

  @override
  void dispose() {
    _champ.dispose();
    super.dispose();
  }

  void _valide() {
    if (!_edite) return;
    setState(() => _edite = false);
    widget.onRenomme(_champ.text.trim());
  }

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);
    if (_edite) {
      return ShadInput(
        controller: _champ,
        autofocus: true,
        style: theme.textTheme.small.copyWith(
          fontSize: 13,
          color: theme.colorScheme.primary,
        ),
        onSubmitted: (_) => _valide(),
        // `onPressedOutside` et non `onTapOutside` : c'est le nom que
        // `ShadInput` donne au clic hors du champ.
        onPressedOutside: (_) => _valide(),
      );
    }
    return Infobulle(
      builder: (_) => Text(T.renommerSession),
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => setState(() {
            _edite = true;
            _champ.text = widget.nom;
            _champ.selection = TextSelection(
              baseOffset: 0,
              extentOffset: widget.nom.length,
            );
          }),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  widget.nom,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.large.copyWith(
                    fontSize: 14,
                    color: theme.colorScheme.primary,
                  ),
                ),
              ),
              Icon(
                LucideIcons.pencil,
                size: 11,
                color: theme.colorScheme.mutedForeground,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
