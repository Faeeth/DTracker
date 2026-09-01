/// Apparence de la surcouche, reprise de celle du jeu.
///
/// La palette est relevee au pixel sur le recapitulatif de fin de combat de
/// Dofus 3, qui montre exactement les memes informations que cet outil. Elle
/// n'est donc pas approchee a l'oeil.
///
/// Le fond et le texte ont chacun leur opacite, reglables independamment. C'est
/// la raison d'etre de cette surcouche : on doit pouvoir poser un fond a trente
/// pour cent sous un texte a quatre-vingt-quinze.
library;

import 'package:flutter/material.dart';

class Palette {
  /// Fond de la fenetre, entre les lignes.
  static const fond = Color(0xFF1B1D32);

  /// La carte d'un personnage.
  static const carte = Color(0xFF292C4D);

  /// Bandeau : barre de titre, en-tetes.
  static const bandeau = Color(0xFF3A3D58);

  /// Le creux d'une barre ou d'une pastille.
  static const creux = Color(0xFF141626);

  /// Emplacement d'inventaire : une carte eclaircie.
  static const emplacement = Color(0xFF343860);

  /// Le combat assombrit et sature. La surcouche etant deja indigo, un simple
  /// bleu ne se distinguerait plus : c'est le lisere qui porte le signal.
  static const fondCombat = Color(0xFF162042);
  static const bandeauCombat = Color(0xFF2C3A68);
  static const bleu = Color(0xFF6C9EFF);

  static const texte = Color(0xFFFFFFFF);

  /// La lavande des en-tetes de colonne.
  static const texteFaible = Color(0xFF9895C2);

  /// Les kamas, couleur de la piece.
  static const or = Color(0xFFFFC700);

  /// Le nom d'un personnage.
  static const orClair = Color(0xFFFFD194);

  /// Le niveau, sur sa pastille.
  static const jaune = Color(0xFFFFD336);

  /// La barre d'experience, de sa base a son extremite.
  static const barre = Color(0xFF787F27);
  static const barreClaire = Color(0xFFA8B23E);

  static const vert = Color(0xFF96D682);
  static const rouge = Color(0xFFE06060);

  /// Le fond, en plus profond : le puits sous les surfaces posees.
  static const puits = Color(0xFF15172A);

  /// La carte, survolee.
  static const carteSurvol = Color(0xFF32365C);

  static const police = 'Lexend';
}

/// La profondeur.
///
/// Sur un fond sombre, une ombre seule ne suffit pas a faire monter une carte :
/// il n'y a pas assez d'ecart entre le noir de l'ombre et le fond. Ce qui fait
/// le relief, c'est la paire — une ombre diffuse **dessous**, et un lisere
/// clair sur l'arete **du haut**, comme si la lumiere venait de la. C'est ce
/// que fait le jeu lui-meme sur ses panneaux, et ce que font les interfaces
/// sombres soignees.
///
/// Trois niveaux, pas plus. Au-dela, on ne distingue plus ce qui est au-dessus
/// de quoi, et tout parait flotter.
class Relief {
  /// Une carte posee : elle se detache sans appeler.
  static const List<BoxShadow> pose = [
    BoxShadow(color: Color(0x40000000), blurRadius: 10, offset: Offset(0, 3)),
    BoxShadow(color: Color(0x1A000000), blurRadius: 2, offset: Offset(0, 1)),
  ];

  /// La meme, sous le curseur : elle monte d'un cheveu.
  static const List<BoxShadow> souleve = [
    BoxShadow(color: Color(0x59000000), blurRadius: 18, offset: Offset(0, 6)),
    BoxShadow(color: Color(0x26000000), blurRadius: 3, offset: Offset(0, 1)),
  ];

  /// Un panneau qui surplombe tout le reste.
  static const List<BoxShadow> flottant = [
    BoxShadow(color: Color(0x80000000), blurRadius: 34, offset: Offset(0, 14)),
  ];

  /// L'arete eclairee, en haut d'une surface.
  static const areteHaute = Color(0x14FFFFFF);
  static const areteBasse = Color(0x0D000000);

  /// Le degrade d'une carte : un peu plus clair en haut.
  ///
  /// Deux pour cent d'ecart, pas davantage. Un degrade qu'on remarque est un
  /// degrade rate ; celui-ci ne se voit pas, il se sent.
  static LinearGradient carte(Color base, {double force = 1}) => LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color.lerp(base, Colors.white, 0.045 * force)!, base],
  );

  /// Le halo d'un element actif : la couleur d'accent, largement diffusee.
  static List<BoxShadow> halo(Color couleur) => [
    BoxShadow(
      color: couleur.withValues(alpha: 0.28),
      blurRadius: 16,
      spreadRadius: -2,
    ),
  ];

  /// Rayons, du plus serre au plus genereux.
  static const rayonPuce = 6.0;
  static const rayonCarte = 10.0;
  static const rayonPanneau = 14.0;
}

/// Les deux opacites, portees ensemble parce qu'elles vont toujours ensemble.
///
/// Tout ce qui se peint les consulte : le fond suit la premiere, le texte la
/// seconde. Un reglage global ne permettrait pas de les separer, et c'est
/// justement ce qu'on veut ici.
class Opacites {
  const Opacites({this.fond = 0.55, this.texte = 0.95});

  final double fond;
  final double texte;

  Color surFond(Color couleur, [double force = 1]) =>
      couleur.withValues(alpha: (fond * force).clamp(0, 1));

  Color surTexte(Color couleur, [double force = 1]) =>
      couleur.withValues(alpha: (texte * force).clamp(0, 1));
}

/// Nombre separe par milliers, a la francaise.
///
/// L'espace fine insecable — U+202F, la convention — manque a Lexend, qui la
/// rend alors quasi nulle : « 1 050 067 » s'affichait « 1050067 ». L'insecable
/// ordinaire passe partout et reste insecable, ce qui est l'essentiel.
String formateNombre(int valeur) {
  final chiffres = valeur.abs().toString();
  final morceaux = <String>[];
  for (var i = chiffres.length; i > 0; i -= 3) {
    morceaux.insert(0, chiffres.substring(i - 3 < 0 ? 0 : i - 3, i));
  }
  return (valeur < 0 ? '-' : '') + morceaux.join(' ');
}

/// Nombre abrege, pour les cadences ou la place manque.
///
/// Une cadence n'a pas besoin d'etre exacte a l'unite : ce qu'on lit dans
/// « 1,2 M/h », c'est l'ordre de grandeur, et l'ecrire en entier ferait sauter
/// la ligne d'une largeur a l'autre a chaque combat.
String formateCourt(num valeur) {
  const seuils = [(1000000000, 'G'), (1000000, 'M'), (1000, 'k')];
  for (final (seuil, suffixe) in seuils) {
    if (valeur.abs() >= seuil) {
      final reduit = valeur / seuil;
      final texte = reduit.abs() < 10
          ? reduit.toStringAsFixed(1)
          : reduit.toStringAsFixed(0);
      return '${texte.replaceAll('.', ',')} $suffixe';
    }
  }
  return formateNombre(valeur.round());
}

/// Duree en `hh:mm:ss`.
String formateDuree(int secondes) {
  final h = secondes ~/ 3600;
  final m = (secondes % 3600) ~/ 60;
  final s = secondes % 60;
  String d(int n) => n.toString().padLeft(2, '0');
  return '${d(h)}:${d(m)}:${d(s)}';
}
