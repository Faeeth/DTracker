/// La vue compacte : le tableau, pose au-dessus du jeu.
///
/// Elle ne montre que ce qui se lit d'un coup d'oeil pendant qu'on joue, et
/// **rien n'y repond au clic**. Un clic destine au jeu ne doit pas ouvrir une
/// fenetre.
///
/// Au repos, elle se reduit a l'essentiel : le tableau, et les totaux dessous.
/// Le reste — la barre de titre et ses commandes, l'etat de la capture, les
/// cadences — ne parait qu'au **survol**. Ce sont des choses qu'on va chercher
/// quand on s'arrete ; les laisser a l'ecran en permanence encombre la seule
/// vue dont la raison d'etre est de ne pas encombrer.
///
/// La fenetre garde la meme hauteur dans les deux etats. La barre de titre
/// occupe sa bande, peinte ou non : la faire apparaitre en poussant le tableau
/// vers le bas ferait sauter tout ce qu'on est en train de lire, et
/// redimensionner la fenetre a chaque passage de souris serait pire.
///
/// C'est la seule vue translucide : laisser voir le terrain a travers est sa
/// raison d'etre.
library;

import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';

import '../modele/session.dart';
import '../source/flux.dart';
import '../source/ressources.dart';
import '../theme.dart';
import 'barre.dart';
import 'ligne.dart';
import 'theme_shad.dart';
import '../i18n/textes.dart';

class VueCompacte extends StatefulWidget {
  const VueCompacte({
    super.key,
    required this.session,
    required this.res,
    required this.opacites,
    required this.secondes,
    required this.etat,
    required this.diagnostic,
    required this.eclatDe,
    required this.personnagesConfigures,
    required this.verrouille,
    required this.onPause,
    required this.onReset,
    required this.onRenomme,
    required this.onVue,
    required this.onVerrou,
    required this.onQuitte,
  });

  final Session session;
  final Ressources res;
  final Opacites opacites;
  final int secondes;
  final EtatFlux etat;
  final String diagnostic;
  final double Function(Suivi) eclatDe;
  final int personnagesConfigures;
  final bool verrouille;

  final VoidCallback onPause;
  final VoidCallback onReset;
  final void Function(String) onRenomme;
  final VoidCallback onVue;
  final VoidCallback onVerrou;
  final VoidCallback onQuitte;

  static const colonnes = Colonnes.compacte;

  /// Hauteur voulue pour un nombre de lignes donne.
  ///
  /// La fenetre se cale dessus : un personnage qui apparait ajoute exactement
  /// sa ligne, et rien d'autre ne bouge. La bande de la barre de titre y est
  /// toujours comptee, meme au repos ou elle ne peint rien.
  /// La bande des cadences, reservee meme avant la cinquieme minute : la voir
  /// apparaitre pousserait tout le tableau d'un cran.
  static const hauteurCadences = 18.0;

  static double hauteurPour(int lignes) =>
      BarreDeTitre.hauteur +
      hauteurCadences +
      22 +
      (lignes == 0 ? 1 : lignes) * (colonnes.hauteur + 4) +
      24 +
      10;

  @override
  State<VueCompacte> createState() => _VueCompacteState();
}

class _VueCompacteState extends State<VueCompacte> {
  bool _survole = false;

  Session get session => widget.session;
  Opacites get o => widget.opacites;

  @override
  Widget build(BuildContext context) {
    final combat = session.enCombat;
    final rayon = BorderRadius.circular(8);

    // Les lignes une fois pour toutes : `lignes` reconstruit sa liste a chaque
    // lecture, en repassant chaque nom en minuscules, et le corps la demandait
    // deux fois — puis le pied une troisieme.
    final lignes = session.lignes;

    final corps = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _cadences(),
        _entetes(),
        ...lignes.map(
          (suivi) => Padding(
            padding: const EdgeInsets.fromLTRB(7, 0, 7, 4),
            child: LigneSuivi(
              suivi: suivi,
              opacites: o,
              res: widget.res,
              secondes: widget.secondes,
              eclat: widget.eclatDe(suivi),
              colonnes: VueCompacte.colonnes,
            ),
          ),
        ),
        if (lignes.isEmpty) _aucunPersonnage(),
        const Spacer(),
        _pied(lignes.length),
      ],
    );

    // Un seul fond, pour toute la surface peinte — barre de titre comprise
    // quand elle parait. La barre n'a pas de fond a elle : peindre le corps
    // seul lui laissait des coins hauts carres, une pointe de chaque cote
    // sous une barre restee transparente.
    final peint = Container(
      decoration: BoxDecoration(
        color: o.surFond(combat ? TeinteCompacte.combat : TeinteCompacte.fond),
        borderRadius: rayon,
        // Sans bordure : a dix ou vingt pour cent de fond, un filet tranche
        // plus qu'il ne delimite. Le combat se dit par la teinte du fond, et
        // chaque ligne par l'ombre de ses textes.
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_survole) SizedBox(height: BarreDeTitre.hauteur, child: _barre()),
          Expanded(child: _saisissable(corps)),
        ],
      ),
    );

    final contenu = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // La bande est reservee dans les deux etats — la hauteur ne doit pas
        // sauter au passage de la souris. Au repos elle reste hors du fond :
        // le jeu s'y voit comme si la fenetre commencait plus bas.
        if (!_survole)
          SizedBox(
            height: BarreDeTitre.hauteur,
            child: _saisissable(const SizedBox.expand()),
          ),
        Expanded(child: peint),
      ],
    );

    return MouseRegion(
      onEnter: (_) => setState(() => _survole = true),
      onExit: (_) => setState(() => _survole = false),
      child: Scaffold(backgroundColor: Colors.transparent, body: contenu),
    );
  }

  /// Une surface par laquelle la fenetre se saisit — sauf cadenas ferme.
  ///
  /// Elle **enveloppe** ce qu'elle rend saisissable, au lieu d'etre posee
  /// dessous. Sous le contenu, elle ne recevait rien : le fond de la vue est
  /// opaque au pointeur et l'interceptait le premier, si bien que la fenetre
  /// ne se deplacait que par la barre de titre — la seule qui portait sa
  /// propre zone.
  ///
  /// Elle n'enveloppe en revanche jamais la barre de titre : `DragToMoveArea`
  /// intercepte le pointeur des sa descente, et un bouton place dessous ne
  /// recevrait jamais son clic. La barre gere ses propres zones, autour de ses
  /// boutons.
  Widget _saisissable(Widget enfant) =>
      widget.verrouille ? enfant : DragToMoveArea(child: enfant);

  Widget _barre() {
    // Les challenges tombes depuis le debut de la session, objectifs de boss
    // exclus : les compter donnait « 3/5 » sur une soiree qui n'en proposait
    // que deux. Comptes ici en une passe : en getter, l'historique etait
    // parcouru deux fois par image.
    var tenus = 0;
    var reussis = 0;
    for (final c in session.historiqueChallenges) {
      if (!c.estChallenge) continue;
      tenus++;
      if (c.reussi) reussis++;
    }
    return BarreDeTitre(
      nom: session.nom,
      secondes: widget.secondes,
      combats: session.combats.length,
      defisReussis: reussis,
      defisTenus: tenus,
      opacites: o,
      enCombat: session.enCombat,
      enPause: session.enPause,
      compacte: true,
      verrouille: widget.verrouille,
      onRenomme: widget.onRenomme,
      onPause: widget.onPause,
      onReset: widget.onReset,
      onSessions: () {},
      onReglages: () {},
      onQuitte: widget.onQuitte,
      onVue: widget.onVue,
      onVerrou: widget.onVerrou,
    );
  }

  Widget _entetes() {
    const c = VueCompacte.colonnes;
    // Les memes en-tetes que le tableau de la vue standard : dix pixels,
    // demi-gras, une pointe d'interlettrage.
    // En clair et non en sourd : le gris se noyait dans le decor du jeu des
    // qu'on baissait le fond. La taille et la graisse suffisent a distinguer
    // un en-tete d'une valeur.
    TextStyle style() => TextStyle(
      color: o.surTexte(TeinteCompacte.texte),
      fontSize: 10,
      fontWeight: grasCompacte,
      letterSpacing: 0.9,
      shadows: ombreSelon(o),
    );
    return Padding(
      padding: const EdgeInsets.fromLTRB(13, 5, 13, 5),
      child: Row(
        children: [
          SizedBox(width: c.portrait + c.espace),
          SizedBox(
            width: c.nom,
            child: Text(T.colPersonnage, style: style()),
          ),
          SizedBox(width: c.espace),
          Expanded(
            child: Text(
              T.colExperience,
              textAlign: TextAlign.right,
              style: style(),
            ),
          ),
          SizedBox(width: c.espace),
          SizedBox(
            width: c.kamas + c.texte + 3,
            child: Text(T.colButin, textAlign: TextAlign.right, style: style()),
          ),
        ],
      ),
    );
  }

  Widget _aucunPersonnage() => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    child: Text(
      widget.personnagesConfigures == 0
          ? T.aucunPersonnageCompacte
          : T.enAttenteCompacte(widget.personnagesConfigures),
      style: TextStyle(
        color: o.surTexte(TeinteCompacte.texte),
        fontSize: 11,
        shadows: ombreSelon(o),
      ),
    ),
  );

  /// Le pied : les totaux, toujours ; l'etat et les cadences au survol.
  ///
  /// Les totaux sont ce qu'on vient lire ; l'etat de la capture et les
  /// cadences sont ce qu'on va chercher quand on s'arrete. Les seconds ne
  /// s'affichent donc qu'au survol, a gauche, ou ils ne poussent rien.
  /// `personnages` est passe plutot que relu : la liste des lignes se
  /// reconstruit a chaque lecture.
  Widget _pied(int personnages) {
    final xp = session.xpTotale;
    final kamas = session.kamasTotaux;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 5),
      child: Row(
        children: [
          // Tout ce qui parait au survol tient dans un `Expanded` : les
          // totaux gardent alors exactement la meme place dans les deux
          // etats. Avec un `Flexible` suivi d'un `Spacer`, les deux se
          // partageaient l'espace libre et les totaux glissaient de quelques
          // pixels au passage de la souris — un mouvement sur le seul chiffre
          // qu'on est en train de lire.
          Expanded(child: _survole ? _liaison() : const SizedBox.shrink()),
          // A un seul personnage, le total **est** sa ligne : le repeter
          // dessous n'ajoute rien et prend la place qu'on economise ailleurs.
          if (personnages > 1 && (xp > 0 || kamas > 0)) _totaux(xp, kamas),
        ],
      ),
    );
  }

  Widget _liaison() {
    final (libelle, couleur) = switch (widget.etat) {
      EtatFlux.connecte => ('Connecté', Palette.vert),
      EtatFlux.liee => (T.fluxEnAttente, Palette.jaune),
      EtatFlux.attente => (T.fluxInjoignable, schemaSombre.destructive),
      EtatFlux.erreur => (T.fluxIndisponible, schemaSombre.destructive),
      EtatFlux.arrete => (T.fluxDeconnecte, schemaSombre.destructive),
    };
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 7,
          height: 7,
          decoration: BoxDecoration(shape: BoxShape.circle, color: couleur),
        ),
        const SizedBox(width: 6),
        Text(
          libelle,
          style: TextStyle(
            color: o.surTexte(TeinteCompacte.texte),
            fontSize: 10,
            fontWeight: grasCompacte,
            shadows: ombreSelon(o),
          ),
        ),
      ],
    );
  }

  /// Les cadences, sur leur propre bande, entre le titre et le tableau.
  ///
  /// **Toujours visibles** : c'est le chiffre qu'on surveille en farmant, et
  /// le releguer au survol obligeait a poser la souris sur la fenetre pour
  /// savoir si la soiree avance bien. Il est donc au-dessus du tableau, la ou
  /// le regard tombe en premier.
  ///
  /// Memes regles que le bandeau de la vue standard : au-dela de cinq
  /// minutes, et par paliers de dix secondes pour que le chiffre tienne en
  /// place au lieu de remuer a chaque battement d'horloge. Abregees, en
  /// revanche : la bande fait cinq cents pixels, et « 1,2 M xp/h » y dit
  /// l'essentiel — l'ordre de grandeur.
  Widget _cadences() {
    final assise = widget.secondes - widget.secondes % 10;
    final xp = session.xpTotale;
    final kamas = session.kamasTotaux;
    if (widget.secondes < 300 || assise <= 0 || (xp == 0 && kamas == 0)) {
      return const SizedBox(height: VueCompacte.hauteurCadences);
    }
    return SizedBox(
      height: VueCompacte.hauteurCadences,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(13, 0, 13, 0),
        child: Row(
          children: [
            _cadence(
              '${formateCourt(xp * 3600 / assise)} ${T.cadenceXp}',
              TeinteCompacte.texte,
            ),
            const SizedBox(width: 14),
            _cadence(
              '${formateCourt(kamas * 3600 / assise)} ${T.cadenceKamas}',
              Palette.or,
            ),
          ],
        ),
      ),
    );
  }

  Widget _cadence(String texte, Color couleur) => Text(
    texte,
    style: TextStyle(
      color: o.surTexte(couleur),
      fontSize: 11,
      fontWeight: grasCompacte,
      shadows: ombreSelon(o),
    ),
  );

  /// Les totaux, dans les couleurs des colonnes : l'experience en clair, le
  /// butin en or, comme dans le tableau juste au-dessus.
  Widget _totaux(int xp, int kamas) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Text(
        '${formateNombre(xp)} ${T.xp}',
        style: TextStyle(
          color: o.surTexte(TeinteCompacte.texte),
          fontSize: 10,
          fontWeight: grasCompacte,
          shadows: ombreSelon(o),
        ),
      ),
      Text(
        '   ·   ',
        style: TextStyle(
          color: o.surTexte(TeinteCompacte.texte),
          fontSize: 10,
          fontWeight: grasCompacte,
          shadows: ombreSelon(o),
        ),
      ),
      Text(
        formateNombre(kamas),
        style: TextStyle(
          color: o.surTexte(Palette.or),
          fontSize: 10,
          fontWeight: grasCompacte,
          shadows: ombreSelon(o),
        ),
      ),
      const SizedBox(width: 3),
      // Le symbole ferme la ligne, comme partout ailleurs : sans lui, le
      // total se lit comme un compte d'objets. Ombre comme les textes.
      if (widget.res.imageKamas == null)
        const SizedBox(width: 9, height: 9)
      else
        symboleOmbre(
          widget.res.imageKamas!,
          o.surTexte(Palette.or),
          9,
          ombreSelon(o),
        ),
    ],
  );
}
