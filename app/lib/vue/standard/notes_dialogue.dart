/// La fenetre des nouveautes, au premier lancement d'une version.
///
/// Elle repond a une question que la mise a jour automatique avait rendue
/// muette : l'outil se remplace tout seul, se relance tout seul, et rien ne
/// disait ce qui avait change. Le lien vers la page de la release existait
/// bien, mais il fallait le suivre avant la mise a jour, au moment ou l'on
/// n'a justement pas encore envie de lire.
///
/// Trois rubriques, un bouton, et rien d'autre : elle s'ouvre une fois par
/// version et ne doit pas se faire remarquer plus que ca.
library;

import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart' hide Cache;

import '../../i18n/notes.dart';
import '../../i18n/textes.dart';
import '../../theme.dart';
import 'briques.dart';

Future<void> montreLesNouveautes(
  BuildContext context,
  String version,
  NotesVersion notes,
) => showShadDialog<void>(
  context: context,
  builder: (contexte) => _Dialogue(version: version, notes: notes),
);

class _Dialogue extends StatelessWidget {
  const _Dialogue({required this.version, required this.notes});

  final String version;
  final NotesVersion notes;

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);
    return ShadDialog.alert(
      title: Text(T.notesTitre(version)),
      description: Padding(
        padding: const EdgeInsets.only(top: Pas.s, bottom: Pas.xs),
        child: ConstrainedBox(
          // Un plafond et un ascenseur : une version bavarde ne doit pas
          // pousser le bouton hors de l'ecran.
          constraints: const BoxConstraints(maxHeight: 420, maxWidth: 460),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  T.notesSousTitre,
                  style: theme.textTheme.muted.copyWith(fontSize: 12),
                ),
                _rubrique(
                  theme,
                  T.notesNouveautes,
                  LucideIcons.sparkles,
                  theme.colorScheme.primary,
                  notes.nouveautes,
                ),
                _rubrique(
                  theme,
                  T.notesCorrectifs,
                  LucideIcons.wrench,
                  Palette.vert,
                  notes.correctifs,
                ),
                _rubrique(
                  theme,
                  T.notesAjustements,
                  LucideIcons.slidersHorizontal,
                  theme.colorScheme.mutedForeground,
                  notes.ajustements,
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        ShadButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(T.notesContinuer),
        ),
      ],
    );
  }

  /// Une rubrique et ses lignes. Rien du tout si elle est vide : une version
  /// sans correctif ne doit pas afficher un titre suivi de blanc.
  Widget _rubrique(
    ShadThemeData theme,
    String titre,
    IconData icone,
    Color couleur,
    List<String> lignes,
  ) {
    if (lignes.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: Pas.m),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(icone, size: 13, color: couleur),
              const SizedBox(width: Pas.s),
              Text(
                titre.toUpperCase(),
                style: theme.textTheme.muted.copyWith(
                  fontSize: 10,
                  letterSpacing: 0.9,
                  fontWeight: FontWeight.w600,
                  color: couleur,
                ),
              ),
            ],
          ),
          for (final ligne in lignes)
            Padding(
              padding: const EdgeInsets.only(top: Pas.xs + 1, left: Pas.l),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Une puce posee a la main : la liste n'a que deux niveaux
                  // et un widget de liste couterait plus qu'il ne rendrait.
                  Text(
                    '·',
                    style: theme.textTheme.small.copyWith(
                      fontSize: 13,
                      height: 1.35,
                      color: theme.colorScheme.mutedForeground,
                    ),
                  ),
                  const SizedBox(width: Pas.s),
                  Expanded(
                    child: Text(
                      ligne,
                      style: theme.textTheme.small.copyWith(
                        fontSize: 12,
                        height: 1.35,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
