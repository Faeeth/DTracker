/// La ligne d'un personnage dans la vue compacte.
///
/// De gauche a droite : le portrait de classe, le nom, l'experience, le butin.
/// Trois colonnes seulement, la ou la vue standard en montre quatre : le
/// niveau et sa barre de progression ne se lisent pas d'un coup d'oeil au
/// milieu d'un combat, et prenaient un tiers de la largeur pour cela.
///
/// Rien ne saute : la barre glisse vers sa nouvelle valeur, et la carte
/// s'eclaire une seconde quand elle encaisse. Les chiffres, eux, sont ecrits
/// d'un coup a leur valeur juste — un compteur qui defile est joli et empeche
/// de lire.
///
/// La ligne est **inerte** : ni clic, ni survol. Posee au-dessus du jeu, elle
/// se lit et ne se manipule pas. Une infobulle qui surgit par-dessus le
/// terrain de combat gene plus qu'elle ne renseigne, et un clic destine au jeu
/// ne doit pas ouvrir une fenetre.
library;

import 'dart:io';

import 'package:flutter/material.dart';

import '../modele/session.dart';
import '../source/ressources.dart';
import '../theme.dart';
import 'theme_shad.dart';

/// Largeurs des colonnes, partagees avec l'en-tete pour qu'ils s'alignent.
class Colonnes {
  const Colonnes({
    required this.portrait,
    required this.nom,
    required this.kamas,
    required this.espace,
    required this.hauteur,
    required this.texte,
  });

  final double portrait;
  final double nom;
  final double kamas;
  final double espace;

  /// Hauteur d'une ligne, et taille du texte courant.
  final double hauteur;
  final double texte;

  static const compacte = Colonnes(
    portrait: 18,
    nom: 150,
    kamas: 74,
    espace: 10,
    hauteur: 28,
    texte: 12,
  );
}

class LigneSuivi extends StatelessWidget {
  const LigneSuivi({
    super.key,
    required this.suivi,
    required this.opacites,
    required this.res,
    required this.secondes,
    required this.eclat,
    this.colonnes = Colonnes.compacte,
  });

  final Suivi suivi;
  final Opacites opacites;
  final Ressources res;
  final int secondes;

  /// De 1 a 0 dans la seconde qui suit un gain.
  final double eclat;

  /// Les mesures de la vue courante.
  final Colonnes colonnes;

  @override
  Widget build(BuildContext context) {
    // Pas de surface propre a la ligne : la fenetre a un seul fond, et une
    // carte par personnage y dessinait autant de rectangles flottants. Seul
    // l'eclat subsiste — il ne dure qu'une seconde, et c'est une information :
    // celui-la vient d'encaisser. Il vire a l'or, la couleur du chiffre qui a
    // bouge.
    final carte = Container(
      height: colonnes.hauteur,
      padding: EdgeInsets.symmetric(horizontal: colonnes.espace * 0.6),
      decoration: BoxDecoration(
        color: Palette.or.withValues(alpha: 0.20 * eclat),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        children: [
          _portrait(),
          SizedBox(width: colonnes.espace),
          SizedBox(width: colonnes.nom, child: _nom()),
          SizedBox(width: colonnes.espace),
          Expanded(child: _experience()),
          SizedBox(width: colonnes.espace),
          _kamas(),
        ],
      ),
    );
    // Rien ne marque le personnage en combat : le fond de la fenetre le dit
    // deja pour tout le groupe, et un lisere de plus faisait une tache de
    // couleur de plus sur une surcouche qui doit se faire oublier.
    return carte;
  }

  /// La case du portrait est reservee meme vide : la classe n'arrive qu'au
  /// passage sur la carte, et les pseudos ne doivent pas se decaler quand elle
  /// finit par arriver.
  Widget _portrait() {
    final chemin = res.imageClasse(suivi.classe);
    return SizedBox(
      width: colonnes.portrait,
      height: colonnes.portrait + 2,
      // Le portrait suit l'opacite du texte : c'est une donnee qu'on lit, au
      // meme titre qu'un nom. Laisse plein, il restait net pendant que le
      // reste de la ligne s'effacait.
      child: chemin == null
          ? null
          : Opacity(
              opacity: opacites.texte,
              child: Image.file(
                File(chemin),
                filterQuality: FilterQuality.medium,
                errorBuilder: (_, _, _) => const SizedBox.shrink(),
              ),
            ),
    );
  }

  Widget _nom() => Text(
    suivi.nom,
    overflow: TextOverflow.ellipsis,
    style: TextStyle(
      color: opacites.surTexte(TeinteCompacte.texte),
      fontSize: colonnes.texte,
      fontWeight: grasCompacte,
      shadows: ombreSelon(opacites),
    ),
  );

  Widget _experience() => Row(
    mainAxisAlignment: MainAxisAlignment.end,
    children: [
      Text(
        formateNombre(suivi.xpGagnee),
        style: TextStyle(
          color: opacites.surTexte(TeinteCompacte.texte),
          fontSize: colonnes.texte,
          fontWeight: grasCompacte,
          shadows: ombreSelon(opacites),
        ),
      ),
      const SizedBox(width: 3),
      Text(
        'XP',
        style: TextStyle(
          color: opacites.surTexte(TeinteCompacte.texte),
          fontSize: colonnes.texte - 3,
          fontWeight: grasCompacte,
          shadows: ombreSelon(opacites),
        ),
      ),
    ],
  );

  /// Le butin en or, symbole compris — comme la colonne BUTIN du tableau.
  Widget _kamas() {
    final piece = res.imageKamas;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: colonnes.kamas,
          child: Text(
            formateNombre(suivi.kamasTotal),
            textAlign: TextAlign.right,
            style: TextStyle(
              color: opacites.surTexte(Palette.or),
              fontSize: colonnes.texte,
              fontWeight: grasCompacte,
              shadows: ombreSelon(opacites),
            ),
          ),
        ),
        const SizedBox(width: 4),
        // Le glyphe est blanc dans les fichiers du jeu : on le teinte, ce qui
        // evite d'embarquer une seconde image. Il porte la meme ombre que les
        // textes — sur un decor clair, un symbole nu se perd comme eux.
        if (piece == null)
          SizedBox(width: colonnes.texte - 2, height: colonnes.texte - 2)
        else
          symboleOmbre(
            piece,
            opacites.surTexte(Palette.or),
            colonnes.texte - 2,
            ombreSelon(opacites),
          ),
      ],
    );
  }
}
