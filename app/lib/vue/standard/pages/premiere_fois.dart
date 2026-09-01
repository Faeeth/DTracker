/// L'ecran du premier lancement : aller chercher les noms et les images.
///
/// Il ne barre pas la route. L'outil compte juste, meme sans rien de tout
/// cela : l'experience, les kamas, les combats et les cadences sont exacts.
/// Ce qui manque, ce sont les noms et les dessins — un objet s'affiche alors
/// « Objet 1731 ». On propose donc, on n'impose pas.
library;

import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart' hide Cache;

import '../../../i18n/textes.dart';
import '../../../source/emplacements.dart';
import '../../../source/extraction.dart';
import '../briques.dart';

class PagePremiereFois extends StatefulWidget {
  const PagePremiereFois({
    super.key,
    required this.ou,
    required this.onFini,
    required this.onPlusTard,
  });

  final Emplacements ou;

  /// Appele quand les fichiers sont la : l'appelant relit ses ressources.
  final VoidCallback onFini;

  /// Appele quand on renonce : l'outil s'ouvre sans les noms.
  final VoidCallback onPlusTard;

  @override
  State<PagePremiereFois> createState() => _PagePremiereFoisState();
}

class _PagePremiereFoisState extends State<PagePremiereFois> {
  Avancement _ou = const Avancement(EtapeExtraction.attente);
  bool _enCours = false;

  Future<void> _lance() async {
    setState(() {
      _enCours = true;
      _ou = const Avancement(EtapeExtraction.recherche);
    });
    await for (final pas in extrait(widget.ou)) {
      if (!mounted) return;
      setState(() => _ou = pas);
    }
    if (!mounted) return;
    setState(() => _enCours = false);
    if (_ou.etape == EtapeExtraction.faite) widget.onFini();
  }

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: ShadCard(
          padding: const EdgeInsets.all(Pas.xl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Icon(
                    LucideIcons.packageOpen,
                    size: 20,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(width: Pas.s),
                  Text(
                    T.premiereFoisTitre,
                    style: theme.textTheme.h4.copyWith(fontSize: 17),
                  ),
                ],
              ),
              const SizedBox(height: Pas.m),
              Text(
                T.premiereFoisDetail,
                style: theme.textTheme.muted.copyWith(height: 1.6),
              ),
              const SizedBox(height: Pas.l),
              _etat(theme),
              const SizedBox(height: Pas.l),
              Row(
                children: [
                  if (!_enCours) ...[
                    ShadButton(
                      leading: const Icon(LucideIcons.download, size: 14),
                      onPressed: _lance,
                      child: Text(
                        _ou.etape == EtapeExtraction.attente
                            ? T.premiereFoisLancer
                            : T.premiereFoisReessayer,
                      ),
                    ),
                    const SizedBox(width: Pas.s),
                    ShadButton.ghost(
                      onPressed: widget.onPlusTard,
                      child: Text(T.premiereFoisPlusTard),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _etat(ShadThemeData theme) {
    final (texte, couleur) = switch (_ou.etape) {
      EtapeExtraction.attente => (T.premiereFoisDuree, theme.colorScheme.mutedForeground),
      EtapeExtraction.recherche => (T.premiereFoisRecherche, theme.colorScheme.foreground),
      EtapeExtraction.travail => (_ou.detail, theme.colorScheme.foreground),
      EtapeExtraction.faite => (T.premiereFoisFaite, theme.colorScheme.primary),
      EtapeExtraction.clientIntrouvable =>
        (T.premiereFoisSansClient, theme.colorScheme.destructive),
      EtapeExtraction.echec =>
        (T.premiereFoisEchec(_ou.detail), theme.colorScheme.destructive),
    };
    return Row(
      children: [
        if (_enCours) ...[
          const SizedBox(
            width: 14,
            height: 14,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          const SizedBox(width: Pas.s),
        ],
        Expanded(
          child: Text(
            texte,
            style: theme.textTheme.small.copyWith(fontSize: 12, color: couleur),
          ),
        ),
      ],
    );
  }
}
