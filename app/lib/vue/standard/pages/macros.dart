/// La liste des macros.
///
/// Une macro ne se modifie pas ici : la ligne dit ce qu'elle fait et la touche
/// qui la declenche, et l'ouvrir mene a son editeur — une **page**, pas une
/// fenetre surgissante. Ecrire une suite de gestes n'est pas une question
/// fermee : on y revient, on essaie, on corrige.
library;

import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart' hide Cache;

import '../../../i18n/textes.dart';
import '../../../modele/macro.dart';
import '../../../source/macros.dart';
import '../briques.dart';
import 'organizer_dialogues.dart'
    show EtiquetteRaccourci, captureUnRaccourci, demandeUnNom;

class PageMacros extends StatefulWidget {
  const PageMacros({super.key, required this.macros, required this.onOuvre});

  final Macros macros;

  /// Ouvre l'editeur d'une macro.
  final void Function(Macro) onOuvre;

  @override
  State<PageMacros> createState() => _PageMacrosState();
}

class _PageMacrosState extends State<PageMacros> {
  @override
  void initState() {
    super.initState();
    // Comme pour l'Organizer : une touche refusee l'est presque toujours parce
    // qu'une autre application la tenait, et revenir ici est le moment ou l'on
    // vient s'en plaindre.
    widget.macros.raccourcis.reessaie();
  }

  Future<void> _changeArret() async {
    final choix = await captureUnRaccourci(
      context,
      widget.macros.raccourcis,
      titre: T.arretMacros,
      initial: widget.macros.arret,
    );
    if (choix == null) return;
    widget.macros.changeArret(choix.raccourci);
  }

  Future<void> _nouvelle() async {
    final nom = await demandeUnNom(context, T.nouvelleMacro);
    if (nom == null) return;
    widget.onOuvre(widget.macros.ajoute(nom));
  }

  @override
  Widget build(BuildContext context) {
    final macros = widget.macros;
    return ListenableBuilder(
      listenable: macros,
      builder: (context, _) {
        if (macros.macros.isEmpty) {
          return Vide(
            T.aucuneMacro,
            icone: LucideIcons.zap,
            detail: T.aucuneMacroDetail,
            action: ShadButton(
              leading: const Icon(LucideIcons.plus, size: 16),
              onPressed: _nouvelle,
              child: Text(T.creerMacro),
            ),
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: Pas.m),
            _Bandeau(
              macros: macros,
              onNouvelle: _nouvelle,
              onArret: _changeArret,
            ),
            const SizedBox(height: Pas.m),
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.only(bottom: Pas.l),
                itemCount: macros.macros.length,
                separatorBuilder: (_, _) => const SizedBox(height: Pas.s),
                itemBuilder: (context, index) => _Ligne(
                  macros: macros,
                  macro: macros.macros[index],
                  onOuvre: widget.onOuvre,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _Bandeau extends StatelessWidget {
  const _Bandeau({
    required this.macros,
    required this.onNouvelle,
    required this.onArret,
  });

  final Macros macros;
  final VoidCallback onNouvelle;
  final VoidCallback onArret;

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);
    final enCours = macros.enCours;
    final dernier = macros.dernierJeu;
    final rate = dernier != null && (!dernier.reussi || dernier.horsDuJeu);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: enCours != null
                    ? theme.colorScheme.primary
                    : (macros.actives > 0
                          ? const Color(0xFF4ADE80)
                          : theme.colorScheme.mutedForeground),
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: Pas.s),
            Text(
              enCours != null
                  ? T.macroEnCours(enCours.nom)
                  : T.macrosActives(macros.actives),
              style: theme.textTheme.muted,
            ),
            if (enCours != null) ...[
              const SizedBox(width: Pas.s),
              ShadButton.ghost(
                size: ShadButtonSize.sm,
                leading: const Icon(LucideIcons.square, size: 13),
                onPressed: macros.arrete,
                child: Text(T.arreterMacro),
              ),
            ],
            const Spacer(),
            // Le reglage general de la page : une touche qui reprend la main.
            ShadTooltip(
              builder: (_) => Text(T.arretMacrosAide),
              child: Row(
                children: [
                  Icon(
                    LucideIcons.octagonX,
                    size: 14,
                    color: theme.colorScheme.mutedForeground,
                  ),
                  const SizedBox(width: Pas.xs),
                  Text(T.arretMacros, style: theme.textTheme.muted),
                  const SizedBox(width: Pas.s),
                  EtiquetteRaccourci(
                    raccourci: macros.arret,
                    onTap: onArret,
                  ),
                ],
              ),
            ),
            const SizedBox(width: Pas.m),
            ShadButton.outline(
              leading: const Icon(LucideIcons.plus, size: 14),
              onPressed: onNouvelle,
              child: Text(T.nouvelleMacro),
            ),
          ],
        ),
        if (rate)
          Padding(
            padding: const EdgeInsets.only(top: Pas.xs, left: 16),
            child: Text(
              dernier.horsDuJeu
                  ? T.horsDuJeu(dernier.obstacle)
                  : dernier.obstacle.isEmpty
                  ? T.aucuneFenetreTrouvee(dernier.fenetreIntrouvable!)
                  : T.fenetrePasDevant(
                      dernier.fenetreIntrouvable!,
                      dernier.obstacle,
                    ),
              style: theme.textTheme.muted.copyWith(
                color: theme.colorScheme.destructive,
              ),
            ),
          ),
      ],
    );
  }
}

/// Une macro dans la liste : son nom, ce qu'elle fait, sa touche.
class _Ligne extends StatelessWidget {
  const _Ligne({
    required this.macros,
    required this.macro,
    required this.onOuvre,
  });

  final Macros macros;
  final Macro macro;
  final void Function(Macro) onOuvre;

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);
    final joue = macros.enCours?.id == macro.id;
    final pris = macros.prisAilleurs(macro);
    return ShadCard(
      padding: const EdgeInsets.symmetric(horizontal: Pas.m, vertical: Pas.s),
      child: Row(
        children: [
          ShadTooltip(
            builder: (_) =>
                Text(macro.actif ? T.desactiverMacro : T.activerMacro),
            child: ShadSwitch(
              value: macro.actif,
              onChanged: (v) => macros.modifie(macro.id, actif: v),
            ),
          ),
          const SizedBox(width: Pas.m),
          Expanded(
            child: MouseRegion(
              cursor: SystemMouseCursors.click,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => onOuvre(macro),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      macro.nom,
                      style: theme.textTheme.p.copyWith(
                        fontSize: 13,
                        color: macro.actif
                            ? theme.colorScheme.foreground
                            : theme.colorScheme.mutedForeground,
                      ),
                    ),
                    Text(
                      [
                        if (!macro.actif) T.macroDesactivee,
                        T.actions(macro.nombreDActions),
                        if (macro.cible.isNotEmpty)
                          '→ ${macro.cible}'
                        else
                          T.fenetreAuPremierPlan,
                      ].join(' · '),
                      style: theme.textTheme.muted.copyWith(fontSize: 11),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (pris) ...[
            ShadTooltip(
              builder: (_) => Text(T.toucheDejaPrise),
              child: Icon(
                LucideIcons.triangleAlert,
                size: 14,
                color: theme.colorScheme.destructive,
              ),
            ),
            const SizedBox(width: Pas.xs),
          ],
          EtiquetteRaccourci(
            raccourci: macro.raccourci,
            eteinte: !macro.actif,
            enConflit: macros.enConflit(macro) || pris,
          ),
          const SizedBox(width: Pas.xs),
          ShadTooltip(
            builder: (_) => Text(joue ? T.arreterMacro : T.jouerMacro),
            child: ShadIconButton.ghost(
              icon: Icon(
                joue ? LucideIcons.square : LucideIcons.play,
                size: 14,
              ),
              onPressed: macro.etapes.isEmpty ? null : () => macros.joue(macro),
            ),
          ),
          ShadIconButton.ghost(
            icon: const Icon(LucideIcons.pencil, size: 14),
            onPressed: () => onOuvre(macro),
          ),
          ShadTooltip(
            builder: (_) => Text(T.dupliquerMacro),
            child: ShadIconButton.ghost(
              icon: const Icon(LucideIcons.copy, size: 14),
              onPressed: () =>
                  macros.duplique(macro.id, T.copieDe(macro.nom)),
            ),
          ),
          ShadIconButton.ghost(
            icon: const Icon(LucideIcons.trash2, size: 14),
            onPressed: () => _supprime(context),
          ),
        ],
      ),
    );
  }

  Future<void> _supprime(BuildContext context) async {
    final confirme = await showShadDialog<bool>(
      context: context,
      builder: (contexte) => ShadDialog.alert(
        title: Text(T.supprimerMacro),
        description: Padding(
          padding: const EdgeInsets.only(top: Pas.s),
          child: Text(
            T.supprimerMacroDetail(macro.nom, macro.nombreDActions),
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
    if (confirme ?? false) macros.supprime(macro.id);
  }
}
