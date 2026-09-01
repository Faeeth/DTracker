/// Le theme shadcn de l'application, en sombre.
///
/// `shadcn_ui` ne fournit pas d'ancetre Material : son `ShadApp` construit un
/// `WidgetsApp`. Or l'outil se sert de `Scaffold`, `TextField`, `Tooltip` et
/// `Scrollbar`, qui exigent tous `MaterialLocalizations`. On passe donc par
/// `ShadApp.custom`, la voie que la documentation du paquet reserve a ce cas :
/// il pose le `ShadTheme`, et l'application Material se construit dessous.
///
/// La palette part de `slate`, la base sombre de shadcn, et n'en retouche que
/// ce qui porte l'identite du jeu : l'or des kamas en couleur primaire, et un
/// fond legerement indigo plutot que le bleu-noir d'origine. Le reste — les
/// gris, les bordures, les etats — vient du systeme, et c'est tout l'interet
/// d'en prendre un.
library;

import 'dart:io';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../theme.dart';

/// Les couleurs de l'application, en sombre.
///
/// Les noms sont ceux de shadcn — `background`, `card`, `muted`, `border`… —
/// et non les notres : c'est le vocabulaire des composants, et le traduire
/// obligerait a le retraduire a chaque usage.
const schemaSombre = ShadSlateColorScheme.dark(
  // Le fond de l'outil, un cran plus indigo que le slate d'origine : il se
  // pose au-dessus d'un jeu qui l'est, et un bleu-noir neutre y jurait.
  background: Color(0xFF12141F),
  foreground: Color(0xFFE8EAF2),

  // Les cartes se detachent du fond sans l'eclaircir franchement : c'est
  // l'ombre qui fait le relief, pas la valeur.
  card: Color(0xFF191C2A),
  cardForeground: Color(0xFFE8EAF2),
  popover: Color(0xFF191C2A),
  popoverForeground: Color(0xFFE8EAF2),

  // L'or des kamas est la couleur primaire. C'est ce que l'outil compte, et
  // ce que l'oeil vient chercher.
  primary: Palette.or,
  primaryForeground: Color(0xFF1A1600),

  secondary: Color(0xFF232739),
  secondaryForeground: Color(0xFFE8EAF2),

  // Le sourd : en-tetes de colonne, dates, libelles.
  muted: Color(0xFF1E2130),
  mutedForeground: Color(0xFF8C90A8),

  accent: Color(0xFF232739),
  accentForeground: Color(0xFFE8EAF2),

  destructive: Palette.rouge,
  destructiveForeground: Color(0xFFFFF5F5),

  border: Color(0xFF2A2E42),
  input: Color(0xFF2A2E42),
  ring: Palette.or,
  selection: Color(0x33FFC700),
);

/// L'ombre portee des textes de la vue compacte.
///
/// Elle est posee sur un jeu, pas sur un fond connu : selon la carte, le texte
/// se detache ou se noie. Une ombre noire tres douce le decolle de tout ce qui
/// peut passer dessous, sans se voir elle-meme.
///
/// C'est aussi ce qui permet de renoncer aux bordures : elles tranchaient trop
/// a dix ou vingt pour cent de fond, la ou l'ombre travaille a toutes les
/// opacites.
/// Deux ombres et non une : la premiere, serree et pleine, detache le trait
/// de la lettre ; la seconde, large et douce, creuse un halo sous elle. Une
/// seule ombre moyenne ne fait ni l'un ni l'autre, et le texte se noyait sur
/// un decor clair.
const ombreTexte = [
  Shadow(color: Color(0xFF000000), blurRadius: 2),
  Shadow(color: Color(0xCC000000), blurRadius: 7, offset: Offset(0, 1)),
];

/// Le meme traitement pour un glyphe dessine, que le style de texte n'atteint
/// pas : on le peint une fois en noir, floute, puis par-dessus a sa couleur.
Widget symboleOmbre(
  String chemin,
  Color teinte,
  double taille, [
  List<Shadow> ombre = ombreTexte,
]) => SizedBox(
  width: taille,
  height: taille,
  child: Stack(
    children: [
      ImageFiltered(
        imageFilter: ImageFilter.blur(sigmaX: 1.4, sigmaY: 1.4),
        child: Image.file(
          File(chemin),
          color: ombre.first.color,
          colorBlendMode: BlendMode.srcIn,
          errorBuilder: (_, _, _) => const SizedBox.shrink(),
        ),
      ),
      Image.file(
        File(chemin),
        color: teinte,
        colorBlendMode: BlendMode.srcIn,
        filterQuality: FilterQuality.medium,
        errorBuilder: (_, _, _) => const SizedBox.shrink(),
      ),
    ],
  ),
);

/// La graisse des textes de la vue compacte.
///
/// Franchement grasse, dans les deux modes. Les traits fins d'une graisse
/// moyenne se hachent sur un decor charge : la lettre garde sa forme mais
/// perd son trait, et le chiffre devient penible a lire d'un coup d'oeil —
/// ce qui est pourtant le seul usage de cette vue.
const grasCompacte = FontWeight.w700;

/// L'ombre des textes, a l'opacite du texte.
///
/// Elle doit **s'effacer avec lui**. Fixe, elle restait noire et pleine
/// pendant que la lettre palissait : le glyphe virait au gris puis au noir au
/// lieu de disparaitre, et le curseur du texte semblait assombrir au lieu
/// d'effacer.
List<Shadow> ombreSelon(Opacites opacites) => [
  for (final o in ombreTexte)
    Shadow(
      color: opacites.surTexte(o.color, o.color.a),
      blurRadius: o.blurRadius,
      offset: o.offset,
    ),
];

/// Les couleurs de la vue compacte.
///
/// Un seul jeu, clair sur fond sombre. Un mode inverse a ete essaye — texte
/// noir sur fond pale, pour les cartes enneigees — puis retire : il demandait
/// une seconde ombre, une seconde teinte de damier, un reglage de plus, et
/// personne ne s'en servait.
///
/// L'or ne bouge pas. C'est la couleur des kamas dans le jeu comme dans
/// l'outil.
class TeinteCompacte {
  const TeinteCompacte._();

  /// Le fond de la fenetre, et sa variante de combat.
  ///
  /// Le combat se dit par la teinte du fond, faute de place pour l'ecrire :
  /// le meme bleu-noir, decale vers le bleu.
  static const fond = Color(0xFF12141F);
  static const combat = Color(0xFF141A2E);

  static const texte = Color(0xFFE8EAF2);

  /// Le creux d'un champ de saisie : plus sombre que le fond.
  static const puits = Color(0xFF0C0E16);

  static const ombre = ombreTexte;
}

/// L'habillage pose sous l'arbre Material.
///
/// `ShadAppBuilder` installe ce dont les composants shadcn ont besoin : sans
/// lui, ils se construisent mais leurs portails et leurs animations n'ont pas
/// d'hote.
///
/// **Sans fond**, et c'est indispensable : il en peint un opaque par defaut,
/// derriere toute l'application. La vue compacte avait beau peindre le sien a
/// vingt pour cent, ce bleu-la restait dessous et ne bougeait qu'avec
/// l'opacite de la fenetre — le curseur « Fond » ne semblait alors agir que
/// sur les bordures. La vue standard n'y perd rien : sa coquille peint deja
/// son propre fond.
///
/// Nomme et partage plutot que recopie : les tests montaient leur propre
/// habillage, opaque, et ne pouvaient donc pas voir le defaut.
Widget habille(BuildContext context, Widget? enfant) =>
    ShadAppBuilder(backgroundColor: Colors.transparent, child: enfant!);

/// Le theme complet, police du jeu comprise.
ShadThemeData themeSombre() => ShadThemeData(
  brightness: Brightness.dark,
  colorScheme: schemaSombre,
  textTheme: ShadTextTheme(family: Palette.police),
);

/// Le theme Material qui vit sous le theme shadcn.
///
/// Il ne sert qu'aux widgets du framework qu'on garde — infobulles, champs de
/// saisie, ascenseurs. Ses couleurs sont tirees du schema shadcn pour que les
/// deux ne divergent pas.
ThemeData themeMaterial() {
  const c = schemaSombre;
  return ThemeData(
    brightness: Brightness.dark,
    fontFamily: Palette.police,
    scaffoldBackgroundColor: Colors.transparent,
    colorScheme: ColorScheme.dark(
      surface: c.background,
      onSurface: c.foreground,
      primary: c.primary,
      onPrimary: c.primaryForeground,
      error: c.destructive,
    ),
    tooltipTheme: TooltipThemeData(
      decoration: BoxDecoration(
        color: c.popover,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: c.border),
      ),
      textStyle: TextStyle(
        color: c.popoverForeground,
        fontSize: 11,
        fontFamily: Palette.police,
      ),
      waitDuration: const Duration(milliseconds: 350),
    ),
    scrollbarTheme: ScrollbarThemeData(
      thumbColor: WidgetStatePropertyAll(c.border),
      thickness: const WidgetStatePropertyAll(6),
      radius: const Radius.circular(3),
    ),
  );
}
