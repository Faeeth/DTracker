/// La barre de titre : le nom de la session, le chronometre, les boutons.
///
/// Deux pieges de mise en page se sont manifestes ici, et c'est ce qui lui vaut
/// son propre fichier — un widget public se monte dans un test, et ces deux
/// proprietes valent d'etre tenues dans le temps.
///
/// **`DragToMoveArea` intercepte le pointeur des sa descente.** Un bouton place
/// dessous ne recoit jamais son clic, et le symptome est muet : les boutons
/// paraissent inertes. Ils restent donc en dehors.
///
/// **Les boutons doivent rester colles au bord droit.** Un `Flexible` lache
/// pour le nom ne le permet pas : il reserve sa part de l'espace libre et n'en
/// rend pas le surplus, qui restait en fin de rangee. Les boutons flottaient a
/// un endroit qui dependait de la longueur du nom. Le nom est donc pose
/// **par-dessus** une zone de deplacement qui occupe tout le reste : il n'en
/// prend que sa largeur, la bande continue de saisir la fenetre partout
/// ailleurs, et les boutons ne bougent plus.
library;

import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart' hide Cache;
import 'package:window_manager/window_manager.dart';

import '../theme.dart';
import 'theme_shad.dart';
import '../i18n/textes.dart';

class BarreDeTitre extends StatefulWidget {
  const BarreDeTitre({
    super.key,
    required this.nom,
    required this.secondes,
    required this.opacites,
    this.combats = 0,
    this.defisReussis = 0,
    this.defisTenus = 0,
    required this.enCombat,
    required this.enPause,
    required this.onRenomme,
    required this.onPause,
    required this.onReset,
    required this.onSessions,
    required this.onReglages,
    required this.onQuitte,
    required this.onVue,
    this.compacte = false,
    this.verrouille = false,
    this.onVerrou,
  });

  final String nom;
  final int secondes;
  final Opacites opacites;
  final bool enCombat;
  final bool enPause;

  /// Le nom saisi. Vide si l'on a tout efface : c'est a l'appelant de decider
  /// ce que vaut un nom vide, lui seul connait le nom par defaut.
  final void Function(String) onRenomme;

  final VoidCallback onPause;
  final VoidCallback onReset;
  final VoidCallback onSessions;
  final VoidCallback onReglages;
  final VoidCallback onQuitte;

  /// Bascule entre la vue standard et la vue compacte.
  final VoidCallback onVue;

  /// La barre est-elle celle de la vue compacte ?
  ///
  /// Elle y perd les sessions et les reglages : on ne vient pas y regler
  /// quoi que ce soit, et deux boutons de moins font deux occasions de moins
  /// de cliquer a cote pendant un combat.
  final bool compacte;

  /// L'etat du cadenas, en vue compacte.
  final bool verrouille;

  /// Le nombre de combats de la session, a cote du chronometre.
  final int combats;

  /// Les challenges de la session : ceux qui sont tombes, et combien on en a
  /// tenus. Zero les fait disparaitre — la vue standard les porte ailleurs.
  final int defisReussis;
  final int defisTenus;

  final VoidCallback? onVerrou;

  /// La vue standard s'offre une barre plus haute : ses boutons doivent
  /// s'atteindre sans viser.
  static const hauteur = 30.0;
  static const hauteurStandard = 42.0;

  double get hauteurUtile => compacte ? hauteur : hauteurStandard;

  @override
  State<BarreDeTitre> createState() => _BarreDeTitreState();
}

class _BarreDeTitreState extends State<BarreDeTitre> {
  /// Le nom est-il en cours d'edition ?
  bool _renomme = false;
  final TextEditingController _champ = TextEditingController();

  Opacites get o => widget.opacites;

  @override
  void dispose() {
    _champ.dispose();
    super.dispose();
  }

  /// Une zone par laquelle la fenetre se saisit — sauf cadenas ferme.
  ///
  /// Le verrou ne portait que sur le corps de la vue : la barre de titre
  /// gardait ses deux zones de deplacement, et la fenetre suivait toujours la
  /// souris. Un cadenas qui ne verrouille qu'une partie ne verrouille rien.
  Widget _deplacable(Widget enfant) =>
      widget.verrouille ? enfant : DragToMoveArea(child: enfant);

  @override
  Widget build(BuildContext context) {
    return Container(
      height: widget.hauteurUtile,
      padding: EdgeInsets.only(left: widget.compacte ? 10 : 14, right: 5),
      // Sans decor : le fond de la fenetre passe dessous, d'un seul tenant.
      // Une surface propre a la barre dessinait une bande plus claire en haut
      // de la surcouche — deux plans la ou il n'en faut qu'un.
      child: Row(
        children: [
          _deplacable(
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  T.marque,
                  style: TextStyle(
                    color: o.surTexte(TeinteCompacte.texte),
                    fontSize: 11,
                    fontWeight: grasCompacte,
                    letterSpacing: 0.2,
                    shadows: ombreSelon(o),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  formateDuree(widget.secondes),
                  style: TextStyle(
                    color: o.surTexte(TeinteCompacte.texte),
                    fontSize: 12,
                    fontWeight: grasCompacte,
                    shadows: ombreSelon(o),
                  ),
                ),
                // Le compte des combats suit le chronometre : les deux disent
                // la meme chose — ce que la soiree a dure, et ce qu'elle a
                // enchaine — et se lisent d'un seul regard cote a cote.
                if (widget.combats > 0) ...[
                  const SizedBox(width: 8),
                  Icon(
                    LucideIcons.swords,
                    size: 12,
                    color: o.surTexte(TeinteCompacte.texte),
                    shadows: TeinteCompacte.ombre,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '${widget.combats}',
                    style: TextStyle(
                      color: o.surTexte(TeinteCompacte.texte),
                      fontSize: 12,
                      fontWeight: grasCompacte,
                      shadows: ombreSelon(o),
                    ),
                  ),
                ],
                // Les challenges a la suite, et la meme cible qu'en vue
                // standard : c'est le rapport, pas le compte, qui dit si la
                // soiree se passe bien.
                if (widget.defisTenus > 0) ...[
                  const SizedBox(width: 8),
                  Icon(
                    LucideIcons.target,
                    size: 12,
                    color: o.surTexte(TeinteCompacte.texte),
                    shadows: TeinteCompacte.ombre,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '${widget.defisReussis}/${widget.defisTenus}',
                    style: TextStyle(
                      color: o.surTexte(TeinteCompacte.texte),
                      fontSize: 12,
                      fontWeight: grasCompacte,
                      shadows: ombreSelon(o),
                    ),
                  ),
                ],
                const SizedBox(width: 8),
              ],
            ),
          ),
          // Tout l'espace restant part ici : c'est ce qui garde les boutons
          // colles au bord droit, quelle que soit la longueur du nom.
          Expanded(
            child: Stack(
              children: [
                Positioned.fill(child: _deplacable(const SizedBox.expand())),
                Align(alignment: Alignment.centerLeft, child: _nom()),
              ],
            ),
          ),
          // En vue compacte, les deux commandes sont des glyphes : nommees,
          // elles prenaient une cinquantaine de pixels chacune sur une barre
          // qui doit encore loger la marque, le minuteur, deux compteurs, le
          // nom de la session et quatre boutons — a la plus petite fenetre,
          // la rangee debordait.
          if (widget.compacte) ...[
            _icone(
              widget.enPause ? Icons.play_arrow : Icons.pause,
              widget.onPause,
              widget.enPause ? T.reprendre : T.pause,
            ),
            _ecart,
            _icone(Icons.refresh, widget.onReset, T.resetInfobulle),
          ] else ...[
            _bouton(widget.enPause ? T.reprendre : T.pause, widget.onPause),
            _ecart,
            _bouton(T.reset, widget.onReset),
          ],
          _ecart,
          // La vue compacte n'a ni sessions ni reglages : on ne vient pas y
          // regler quoi que ce soit. A leur place, le cadenas et le retour a
          // la vue standard.
          if (widget.compacte) ...[
            _icone(
              widget.verrouille ? Icons.lock_outline : Icons.lock_open,
              widget.onVerrou ?? () {},
              widget.verrouille ? T.fenetreBloquee : T.fenetreLibre,
            ),
            _ecart,
            _icone(Icons.open_in_full, widget.onVue, T.vueComplete),
          ] else ...[
            _icone(Icons.list_alt, widget.onSessions, T.sessions),
            _ecart,
            _icone(Icons.settings, widget.onReglages, T.reglages),
            _ecart,
            _icone(Icons.close_fullscreen, widget.onVue, T.vueCompacte),
          ],
          _ecart,
          _icone(Icons.close, widget.onQuitte, T.quitter, rouge: true),
        ],
      ),
    );
  }

  /// Le nom de la session, modifiable d'un clic.
  Widget _nom() {
    if (_renomme) {
      // Une largeur explicite : le nom n'est pas dans une boite flexible, et
      // un champ de saisie sans contrainte prendrait toute la bande.
      return SizedBox(
        height: widget.compacte ? 20 : 26,
        width: widget.compacte ? 190 : 240,
        child: TextField(
          controller: _champ,
          autofocus: true,
          style: TextStyle(
            color: o.surTexte(TeinteCompacte.texte),
            fontSize: 12,
            fontWeight: grasCompacte,
          ),
          cursorColor: Palette.or,
          decoration: InputDecoration(
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(horizontal: 6),
            filled: true,
            fillColor: TeinteCompacte.puits.withValues(alpha: 0.7),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(3),
              borderSide: BorderSide(color: Palette.or.withValues(alpha: 0.5)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(3),
              borderSide: BorderSide(color: Palette.or.withValues(alpha: 0.5)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(3),
              borderSide: const BorderSide(color: Palette.or),
            ),
          ),
          onSubmitted: (_) => _valide(),
          onTapOutside: (_) => _valide(),
        ),
      );
    }
    return Tooltip(
      message: T.renommerSession,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTap: () => setState(() {
            _renomme = true;
            _champ.text = widget.nom;
            _champ.selection = TextSelection(
              baseOffset: 0,
              extentOffset: widget.nom.length,
            );
          }),
          child: Text(
            widget.nom,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: o.surTexte(TeinteCompacte.texte),
              fontSize: widget.compacte ? 12 : 14,
              fontWeight: grasCompacte,
              shadows: ombreSelon(o),
            ),
          ),
        ),
      ),
    );
  }

  void _valide() {
    if (!_renomme) return;
    setState(() => _renomme = false);
    widget.onRenomme(_champ.text.trim());
  }

  Widget get _ecart => SizedBox(width: widget.compacte ? 5 : 8);

  /// Un bouton, dont la cible est plus large que son dessin.
  ///
  /// Les croix et les fleches de navigation etaient des glyphes nus : leur
  /// zone sensible se limitait a l'encre, et il fallait viser. Ce qui repond
  /// au clic est desormais la boite entiere, et elle a une taille minimale.
  Widget _cible(
    Widget dessin,
    VoidCallback action,
    String infobulle, {
    bool rouge = false,
    EdgeInsets? marge,
  }) => Tooltip(
    message: infobulle,
    waitDuration: const Duration(milliseconds: 600),
    child: MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: action,
        // Opaque : le clic s'arrete ici, y compris sur la partie
        // transparente de la boite, et n'atteint pas la zone de
        // deplacement qui se trouve derriere.
        behavior: HitTestBehavior.opaque,
        child: Container(
          constraints: BoxConstraints(
            minWidth: widget.compacte ? 26 : 34,
            minHeight: widget.compacte ? 20 : 28,
          ),
          alignment: Alignment.center,
          padding:
              marge ??
              EdgeInsets.symmetric(
                horizontal: widget.compacte ? 8 : 12,
                vertical: widget.compacte ? 3 : 5,
              ),
          // Sans decor : un seul fond pour toute la fenetre. Les
          // boutons se distinguent par leur libelle — et le rouge par sa
          // couleur — non par une plaque sous eux : a faible opacite, ces
          // plaques faisaient autant de rectangles flottants.
          child: dessin,
        ),
      ),
    ),
  );

  Widget _bouton(String texte, VoidCallback action, {bool rouge = false}) =>
      _cible(
        Text(
          texte,
          style: TextStyle(
            color: o.surTexte(
              rouge ? schemaSombre.destructive : TeinteCompacte.texte,
            ),
            fontSize: widget.compacte ? 11 : 12,
            fontWeight: grasCompacte,
            shadows: ombreSelon(o),
          ),
        ),
        action,
        texte,
      );

  Widget _icone(
    IconData glyphe,
    VoidCallback action,
    String infobulle, {
    bool rouge = false,
  }) => _cible(
    Icon(
      glyphe,
      size: widget.compacte ? 13 : 16,
      color: o.surTexte(
        rouge ? schemaSombre.destructive : TeinteCompacte.texte,
      ),
    ),
    action,
    infobulle,
    rouge: rouge,
    marge: EdgeInsets.symmetric(
      horizontal: widget.compacte ? 6 : 9,
      vertical: widget.compacte ? 3 : 5,
    ),
  );
}
