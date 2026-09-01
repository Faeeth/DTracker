/// La fenetre qui propose une mise a jour, et la fait.
///
/// Trois gestes en un : telecharger l'installateur, le lancer, et se retirer
/// pour qu'il puisse remplacer les fichiers. Sans cela il fallait ouvrir le
/// navigateur, telecharger, decompresser, lancer — quatre etapes pour ce qui
/// tient en un bouton.
///
/// L'ancienne voie reste ouverte : si le telechargement echoue, ou si la
/// release ne porte pas d'installateur, on renvoie vers sa page, qui marche
/// toujours.
library;

import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart' hide Cache;

import '../../i18n/textes.dart';
import '../../config.dart';
import '../../source/emplacements.dart';
import '../../source/maj.dart';
import 'briques.dart';

/// Ce que la fenetre demande a l'appelant de faire ensuite.
enum SuiteMaj {
  /// Rien : on verra plus tard.
  rien,

  /// L'installateur tourne — il faut fermer l'application, maintenant.
  installe,
}

Future<SuiteMaj> proposeMiseAJour(
  BuildContext context,
  MiseAJour maj,
) async {
  final suite = await showShadDialog<SuiteMaj>(
    context: context,
    // Pas de fermeture par la touche d'echappement pendant un
    // telechargement : l'installateur serait lance sans que rien ne l'attende.
    barrierDismissible: false,
    builder: (contexte) => _Dialogue(maj: maj),
  );
  return suite ?? SuiteMaj.rien;
}

class _Dialogue extends StatefulWidget {
  const _Dialogue({required this.maj});

  final MiseAJour maj;

  @override
  State<_Dialogue> createState() => _DialogueState();
}

class _DialogueState extends State<_Dialogue> {
  double? _part;
  bool _rate = false;

  Future<void> _lance() async {
    setState(() {
      _part = 0;
      _rate = false;
    });
    String? fichier;
    await for (final part in telecharge(widget.maj, (p) => fichier = p)) {
      if (!mounted) return;
      setState(() => _part = part);
    }
    if (!mounted) return;
    final chemin = fichier;
    if (chemin == null || !await lanceInstallateur(chemin)) {
      if (!mounted) return;
      setState(() {
        _part = null;
        _rate = true;
      });
      return;
    }
    if (mounted) Navigator.of(context).pop(SuiteMaj.installe);
  }

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);
    final enCours = _part != null;
    return ShadDialog.alert(
      title: Text(T.majTitre(widget.maj.version)),
      description: Padding(
        padding: const EdgeInsets.symmetric(vertical: Pas.s),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(T.majDetail(versionApp)),
            const SizedBox(height: Pas.s),
            // Un lien plutot qu'un bouton : voir ce qu'on installe est une
            // curiosite, pas une action au meme rang que la mise a jour. Et
            // il reste la porte de secours quand le telechargement echoue.
            _Lien(
              texte: T.majOuvrir,
              onTap: () => ouvreAdresse(widget.maj.adresse),
            ),
            if (enCours) ...[
              const SizedBox(height: Pas.m),
              ShadProgress(value: _part, minHeight: 6),
              const SizedBox(height: Pas.xs),
              Text(
                _part! >= 1 ? T.majLancement : T.majTelechargement(
                  (_part! * 100).round(),
                ),
                style: theme.textTheme.muted.copyWith(fontSize: 11),
              ),
            ],
            if (_rate) ...[
              const SizedBox(height: Pas.m),
              Text(
                T.majRate,
                style: theme.textTheme.small.copyWith(
                  fontSize: 12,
                  color: theme.colorScheme.destructive,
                ),
              ),
            ],
          ],
        ),
      ),
      actions: enCours
          ? const []
          : [
              ShadButton.ghost(
                onPressed: () => Navigator.of(context).pop(SuiteMaj.rien),
                child: Text(T.majPlusTard),
              ),
              if (widget.maj.telechargeable)
                ShadButton(
                  leading: const Icon(LucideIcons.download, size: 14),
                  onPressed: _lance,
                  child: Text(_rate ? T.majReessayer : T.majInstaller),
                ),
            ],
    );
  }
}

/// Un texte qui mene quelque part.
///
/// Souligne et de la couleur d'accent : sans l'un ni l'autre, rien ne dit
/// qu'on peut cliquer, et le curseur seul ne se decouvre qu'en passant
/// dessus par hasard.
class _Lien extends StatelessWidget {
  const _Lien({required this.texte, required this.onTap});

  final String texte;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        child: Text(
          texte,
          style: theme.textTheme.small.copyWith(
            fontSize: 12,
            color: theme.colorScheme.primary,
            decoration: TextDecoration.underline,
            decorationColor: theme.colorScheme.primary.withValues(alpha: 0.5),
          ),
        ),
      ),
    );
  }
}
