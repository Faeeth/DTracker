/// La fenetre : ce qui vit, et ce qui se dessine.
///
/// Elle ne dessine plus rien elle-meme. Elle tient ce qui dure — la liaison
/// avec la capture, la session, les horloges, la geometrie de la fenetre — et
/// confie l'affichage a l'une des deux vues : la **coquille** en vue standard,
/// avec son rail et ses pages ; la **vue compacte** en surcouche du jeu.
///
/// L'affichage n'est pas reconstruit a chaque evenement recu : en plein combat
/// il en arrive plusieurs par seconde. Un rafraichissement est demande, et
/// applique au plus trente fois par seconde. Les animations, elles, ont leur
/// propre horloge — elles ne dependent pas de l'arrivee des evenements, sans
/// quoi elles s'arreteraient net entre deux.
library;

import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';

import '../config.dart';
import '../modele/session.dart';
import '../source/archives.dart';
import '../source/cache.dart';
import '../source/flux.dart';
import '../source/ressources.dart';
import '../theme.dart';
import 'compacte.dart';
import 'standard/coquille.dart';
import '../i18n/textes.dart';

class Surcouche extends StatefulWidget {
  const Surcouche({
    super.key,
    required this.config,
    required this.res,
    required this.racine,
    required this.flux,
    required this.session,
    required this.cache,
    required this.archives,
  });

  final Config config;
  final Ressources res;
  final String racine;
  final Flux flux;
  final Session session;
  final Cache cache;
  final Archives archives;

  @override
  State<Surcouche> createState() => _SurcoucheState();
}

class _SurcoucheState extends State<Surcouche> with WindowListener {
  late final Timer _horloge;
  late final Timer _peinture;
  late final Timer _sauvegarde;
  StreamSubscription? _abonnement;
  StreamSubscription? _abonnementEtat;

  int _secondes = 0;
  bool _aRafraichir = false;
  EtatFlux _etat = EtatFlux.arrete;

  /// Instant du dernier gain, par personnage : c'est ce qui allume la carte.
  final Map<String, DateTime> _gains = {};

  Config get config => widget.config;
  Session get session => widget.session;

  @override
  void initState() {
    super.initState();
    windowManager.addListener(this);

    _abonnement = widget.flux.evenements.listen((e) {
      if (session.recoit(e)) {
        _marqueGain(e);
        _aRafraichir = true;
      }
      _nourritCache(e);
    });
    _abonnementEtat = widget.flux.etats.listen((etat) {
      if (mounted) setState(() => _etat = etat);
    });
    widget.flux.demarre();

    _horloge = Timer.periodic(const Duration(seconds: 1), (_) {
      // Le compteur se lit sur la session plutot que de s'incrementer : elle
      // seule sait ce qui compte. Une session reprise affiche d'emblee le
      // total de ses lancements precedents, et une pause ne la fait pas
      // avancer.
      _secondes = session.duree.round();
      if (mounted) setState(() {});
      _ajusteHauteur();
    });
    // Le cache s'ecrit au fil de l'eau plutot qu'a la fermeture : une session
    // interrompue par une mise en veille ne doit pas tout perdre.
    _sauvegarde = Timer.periodic(const Duration(seconds: 20), (_) async {
      await widget.cache.enregistre();
      await widget.archives.enregistre(session);
    });
    // Trente images par seconde le temps qu'un eclat s'eteigne ; sinon on se
    // contente du rythme des evenements.
    //
    // Le combat n'y donne plus droit. Il l'obtenait pour le chronometre de la
    // bande, qui se lit en secondes : l'horloge ci-dessus suffit. On repeignait
    // donc toute la fenetre trente fois par seconde d'un bout a l'autre de
    // chaque combat — le moment ou le jeu a le plus besoin de la machine, et
    // ou cette surcouche doit se faire la plus discrete.
    _peinture = Timer.periodic(const Duration(milliseconds: 33), (_) {
      final anime = _gains.values.any(
        (t) => DateTime.now().difference(t) < const Duration(milliseconds: 900),
      );
      if ((_aRafraichir || anime) && mounted) {
        _aRafraichir = false;
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _horloge.cancel();
    _peinture.cancel();
    _sauvegarde.cancel();
    _abonnement?.cancel();
    _abonnementEtat?.cancel();
    widget.flux.ferme();
    windowManager.removeListener(this);
    super.dispose();
  }

  @override
  void onWindowMoved() async {
    final position = await windowManager.getPosition();
    config.x = position.dx;
    config.y = position.dy;
  }

  @override
  void onWindowResized() async {
    // La vue standard est une fenetre ordinaire : sa taille est celle qu'on
    // lui a donnee a la souris, et on la retrouve au lancement suivant.
    if (config.compact) return;
    final taille = await windowManager.getSize();
    config.largeurStandard = taille.width;
    config.hauteurStandard = taille.height;
  }

  // -------------------------------------------------------------- geometrie

  double _derniereHauteur = 0;

  /// La vue compacte se cale sur son contenu ; la vue standard, non.
  Future<void> _ajusteHauteur() async {
    if (!config.compact) return;
    final voulue = VueCompacte.hauteurPour(session.lignes.length);
    if ((voulue - _derniereHauteur).abs() < 1) return;
    _derniereHauteur = voulue;
    // Le minimum descend avant la taille : sans cela, le systeme refuse de
    // rapetissir la fenetre autant qu'on le demande, et le contenu flotte au
    // milieu d'une bande trop haute.
    await windowManager.setMinimumSize(Size(tailleMiniCompacte.width, voulue));
    await windowManager.setSize(Size(config.largeur, voulue));
  }

  /// Passe d'une vue a l'autre.
  ///
  /// Chaque vue garde sa geometrie : on ne veut pas retrouver la vue standard
  /// a la taille d'une etiquette parce qu'on est passe par la vue compacte.
  Future<void> _changeDeVue() async {
    if (!config.compact) {
      final taille = await windowManager.getSize();
      config.largeurStandard = taille.width;
      config.hauteurStandard = taille.height;
    }
    setState(() => config.compact = !config.compact);
    _derniereHauteur = 0;
    if (config.compact) {
      // Le minimum descend avant la taille, sinon le systeme refuse de
      // rapetissir la fenetre autant qu'on le demande.
      final voulue = VueCompacte.hauteurPour(session.lignes.length);
      await windowManager.setMinimumSize(
        Size(tailleMiniCompacte.width, voulue),
      );
      await windowManager.setSize(Size(config.largeur, voulue));
      _derniereHauteur = voulue;
      await windowManager.setResizable(false);
    } else {
      await windowManager.setResizable(true);
      await windowManager.setMinimumSize(tailleMiniStandard);
      await windowManager.setSize(
        Size(config.largeurStandard, config.hauteurStandard),
      );
    }
    await _appliqueTransparence();
    await config.enregistre(widget.racine);
  }

  Future<void> _basculeVerrou() async {
    setState(() => config.verrouille = !config.verrouille);
    await config.enregistre(widget.racine);
  }

  // ---------------------------------------------------------------- session

  /// Retient ce qui ne repassera pas : classes et prix.
  void _nourritCache(Map<String, dynamic> e) {
    switch (e['type']) {
      case 'CharacterInfo':
        widget.cache.apprendClasse(
          '${e['name']}',
          (e['breed'] as num?)?.toInt(),
        );
      case 'PriceTable':
        widget.cache.apprendPrix(session.prix);
    }
  }

  void _marqueGain(Map<String, dynamic> e) {
    final type = e['type'];
    if (type == 'FightEnd') {
      for (final p in e['participants'] as List? ?? []) {
        if (p is Map && p['name'] is String) {
          _gains[cleDe(p['name'] as String)] = DateTime.now();
        }
      }
    } else if (type == 'AchievementUnlocked' || type == 'ItemGained') {
      final qui = e['character'];
      if (qui is String) _gains[cleDe(qui)] = DateTime.now();
    }
  }

  double _eclatDe(Suivi suivi) {
    final quand = _gains[suivi.cle];
    if (quand == null) return 0;
    final ecoule = DateTime.now().difference(quand).inMilliseconds;
    return ecoule >= 900 ? 0 : 1 - ecoule / 900;
  }

  /// Reset clot la session en cours plutot que de l'effacer : elle reste
  /// consultable, et la suivante prend son propre fichier. Sans cette
  /// cloture, la session neuve se reecrivait par-dessus l'ancienne, qui
  /// disparaissait.
  Future<void> _reset() async {
    await widget.archives.clot(session);
    final suivant = await widget.archives.prochainNumero();
    if (!mounted) return;
    setState(() {
      session.remetAZero();
      session.numero = suivant;
      session.nom = 'Session $suivant';
      _secondes = 0;
      _gains.clear();
    });
  }

  /// Un nom vide n'en est pas un : on retombe alors sur celui par defaut.
  Future<void> _renommeSession(String saisi) async {
    setState(
      () => session.nom = saisi.isEmpty ? 'Session ${session.numero}' : saisi,
    );
    await widget.archives.enregistre(session);
  }

  /// Bascule sur une session archivee.
  ///
  /// Celle qu'on quitte est ecrite et close — elle cesse d'etre celle que
  /// l'outil alimente. Celle qu'on ouvre prend sa place et **repart
  /// aussitot** : on y bascule pour continuer. Une nouvelle periode s'ouvre,
  /// de sorte que le temps deja passe dessus s'ajoute au lieu de repartir de
  /// zero.
  Future<void> _bascule(Archive archive) async {
    if (archive.fichier == null) return;
    await widget.archives.clot(session);
    if (!mounted) return;
    setState(() {
      archive.rechargeDans(session);
      _secondes = session.duree.round();
      _gains.clear();
    });
    widget.archives.reprend(archive.fichier!);
    await widget.archives.enregistre(session);
    _derniereHauteur = 0;
  }

  /// Repercute un reglage des qu'il est fait.
  ///
  /// Rien n'attend une validation : la liste des personnages, les opacites, le
  /// premier plan et l'interface de capture prennent effet au geste, et le
  /// fichier de reglages suit.
  Future<void> _appliqueReglages() async {
    session.definitPersonnages(config.personnages);
    session.definitClasses(widget.cache.classes);
    session.compteLesSucces = config.succesComptes;
    if (mounted) setState(() {});
    await windowManager.setAlwaysOnTop(_devant);
    await _appliqueTransparence();
    await config.enregistre(widget.racine);
    if (config.interface != widget.flux.interface) {
      // Changer d'interface veut dire recommencer la capture ; le reste de la
      // session, lui, n'a aucune raison d'etre perdu.
      widget.flux.interface = config.interface;
      await widget.flux.arrete();
      await widget.flux.demarre();
    }
  }

  /// Ferme l'outil.
  ///
  /// L'ordre compte. Les horloges d'abord : la sauvegarde periodique reecrit
  /// la session en la marquant « en cours », et si elle se declenchait apres
  /// la cloture, la session repartirait ouverte. Les ecritures ensuite, une
  /// par une. La capture enfin, avant de detruire la fenetre — elle tient un
  /// port et un dumpcap, et une fenetre qui disparait en les laissant
  /// derriere elle empeche le lancement suivant d'ecouter.
  Future<void> _quitte() async {
    _horloge.cancel();
    _peinture.cancel();
    _sauvegarde.cancel();
    await config.enregistre(widget.racine);
    await widget.cache.enregistre();
    // La session se clot en quittant : sa periode se ferme, et elle cesse
    // d'etre celle que l'outil alimente.
    await widget.archives.clot(session);
    await widget.flux.arrete();
    await windowManager.destroy();
    // Tout est ecrit et la capture est arretee : plus rien n'a de raison de
    // retenir le processus.
    //
    // Cette ligne n'est pas une precaution : c'est elle qui a supprime les
    // cinq secondes de fenetre figee apres le clic sur la croix. Chronometre,
    // chaque geste ci-dessus tient sous les trois cents millisecondes,
    // `destroy` comprise — l'attente etait entierement dans l'extinction du
    // moteur qui la suivait.
    exit(0);
  }

  /// Les opacites ne valent que pour la vue compacte.
  ///
  /// Elle se pose au-dessus du jeu, et c'est sa raison d'etre : laisser voir
  /// le terrain a travers. La vue standard occupe sa propre fenetre et n'a
  /// rien a laisser passer.
  ///
  /// La transparence ne peut pas venir de ce que l'application peint : Flutter
  /// ne compose pas sa surface avec un canal alpha sur Windows — la demande
  /// est ouverte depuis decembre 2020 — et un fond peint a zero pour cent
  /// donnait un rectangle **noir**, pas une vue du jeu.
  ///
  /// Elle vient donc de la fenetre elle-meme, rendue translucide par Windows.
  /// Mais une fenetre translucide l'est **en entier**, texte compris, la ou
  /// les deux curseurs promettent de les regler separement. On retrouve la
  /// promesse en composant les deux : la fenetre porte l'opacite du texte, et
  /// le fond est peint dessous dans le rapport qui manque.
  ///
  ///     fond a l'ecran = opacite de la fenetre x fond peint
  ///                    = texte x (fond / texte) = fond
  ///
  /// Le texte, lui, est peint plein : la fenetre porte deja son opacite.
  Opacites get _opacites => Opacites(
    fond: config.opaciteTexte == 0
        ? 0
        : (config.opaciteFond / config.opaciteTexte).clamp(0.0, 1.0),
    texte: 1,
  );

  /// La fenetre doit-elle rester au-dessus des autres ?
  ///
  /// La vue compacte, toujours : elle se pose sur le jeu, et une surcouche qui
  /// passe derriere lui ne sert plus a rien. Le reglage ne vaut donc que pour
  /// la vue standard, qui est une fenetre ordinaire.
  bool get _devant => config.compact || config.toujoursDevant;

  /// Rend la fenetre aussi translucide que le texte doit l'etre.
  ///
  /// La vue standard occupe sa propre fenetre : elle reste pleine.
  Future<void> _appliqueTransparence() =>
      windowManager.setOpacity(config.compact ? config.opaciteTexte / 100 : 1);

  /// Ce que l'etat de la liaison veut dire, et quoi en faire.
  ///
  /// Un libelle de trois mots ne suffit pas a distinguer un jeu a l'arret
  /// d'une capture aveugle : ce sont deux situations qui n'appellent pas le
  /// meme geste, et c'est exactement la ou l'on se perd.
  String _diagnostic() {
    final carte = config.interface.isEmpty
        ? T.carteToutesPhysiques
        : T.carteNommee(config.interface);
    return switch (_etat) {
      EtatFlux.connecte => T.diagEcouteSur(carte),
      EtatFlux.liee => T.diagRienEntendu(carte),
      EtatFlux.attente => T.diagNeRepondPas,
      EtatFlux.erreur => T.diagNaPasDemarre,
      EtatFlux.arrete => T.diagAucuneCapture,
    };
  }

  @override
  Widget build(BuildContext context) {
    if (config.compact) {
      return VueCompacte(
        session: session,
        res: widget.res,
        opacites: _opacites,
        secondes: _secondes,
        etat: _etat,
        diagnostic: _diagnostic(),
        eclatDe: _eclatDe,
        personnagesConfigures: config.personnages.length,
        verrouille: config.verrouille,
        onPause: () => setState(() => session.enPause = !session.enPause),
        onReset: _reset,
        onRenomme: _renommeSession,
        onVue: _changeDeVue,
        onVerrou: _basculeVerrou,
        onQuitte: _quitte,
      );
    }
    return Coquille(
      config: config,
      session: session,
      archives: widget.archives,
      res: widget.res,
      ou: widget.flux.ou,
      classes: widget.cache.classes,
      secondes: _secondes,
      etat: _etat,
      diagnostic: _diagnostic(),
      eclatDe: _eclatDe,
      onPause: () => setState(() => session.enPause = !session.enPause),
      onReset: _reset,
      onRenomme: _renommeSession,
      onCompact: _changeDeVue,
      onQuitte: _quitte,
      onReglageChange: _appliqueReglages,
      onBascule: _bascule,
    );
  }
}
