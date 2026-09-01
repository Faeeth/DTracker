/// La coquille de la vue standard : le rail, l'en-tete de page, le contenu.
///
/// Elle ne sait rien de ce qu'elle montre. Elle tient la pile de navigation,
/// dessine l'ossature — rail a gauche, titre et fil d'Ariane en haut — et
/// delegue le corps a l'ecran courant. Ajouter une page consiste a l'ajouter a
/// `navigation.dart` puis a la citer dans le `switch` ci-dessous ; rien
/// d'autre ne bouge.
library;

import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart' hide Cache;
import 'package:window_manager/window_manager.dart';

import '../../config.dart';
import '../../modele/session.dart';
import '../../source/archives.dart';
import '../../source/flux.dart';
import '../../source/ressources.dart';
import '../../theme.dart';
import 'briques.dart';
import 'navigation.dart';
import 'pages/butin.dart';
import 'pages/inventaire.dart';
import 'pages/combats.dart';
import 'pages/reglages.dart';
import 'pages/sessions.dart';
import 'pages/suivi.dart';
import 'rail.dart';
import '../../source/emplacements.dart';

class Coquille extends StatefulWidget {
  const Coquille({
    super.key,
    required this.config,
    required this.session,
    required this.archives,
    required this.res,
    required this.ou,
    required this.classes,
    required this.secondes,
    required this.etat,
    required this.diagnostic,
    required this.eclatDe,
    required this.onPause,
    required this.onReset,
    required this.onRenomme,
    required this.onCompact,
    required this.onQuitte,
    required this.onReglageChange,
    required this.onBascule,
    this.interfaces,
  });

  final Config config;
  final Session session;
  final Archives archives;
  final Ressources res;
  /// Ou trouver la diffusion, pour lui demander les cartes reseau.
  final Emplacements ou;
  final Map<String, int> classes;
  final int secondes;
  final EtatFlux etat;
  final String diagnostic;
  final double Function(Suivi) eclatDe;
  final VoidCallback onPause;
  final VoidCallback onReset;
  final void Function(String) onRenomme;
  final VoidCallback onCompact;
  final VoidCallback onQuitte;
  final VoidCallback onReglageChange;
  final Future<void> Function(Archive) onBascule;

  /// Fournie par les tests, pour ne pas lancer un sous-processus Python.
  final List<Interface>? interfaces;

  @override
  State<Coquille> createState() => _CoquilleState();
}

class _CoquilleState extends State<Coquille> {
  final _navigation = Navigation();

  Config get config => widget.config;
  Session get session => widget.session;

  void _va(Ecran ecran) => setState(() => _navigation.ouvre(ecran));

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);
    return Scaffold(
      backgroundColor: theme.colorScheme.background,
      body: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Rail(
            actif: _navigation.onglet,
            onChoisit: (o) => setState(() => _navigation.choisit(o)),
            etat: widget.etat,
            diagnostic: widget.diagnostic,
            nomSession: session.nom,
            duree: formateDuree(widget.secondes),
            enPause: session.enPause,
            onRenomme: widget.onRenomme,
            onPause: widget.onPause,
            onReset: widget.onReset,
            onCompact: widget.onCompact,
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _entete(theme),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(Pas.l, 0, Pas.l, Pas.l),
                    child: _contenu(),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// L'en-tete de page : retour, titre, et la poignee pour deplacer la
  /// fenetre.
  ///
  /// La fenetre est sans bordure : c'est cette bande qui la remplace. Elle est
  /// donc une zone de deplacement, sauf la ou se trouvent le retour et la
  /// croix — qui sont opaques au clic et l'interceptent.
  Widget _entete(ShadThemeData theme) {
    final ecran = _navigation.courant;
    return Container(
      height: 62,
      padding: const EdgeInsets.only(left: Pas.l, right: Pas.m),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: theme.colorScheme.border)),
      ),
      child: Stack(
        children: [
          const Positioned.fill(
            child: DragToMoveArea(child: SizedBox.expand()),
          ),
          Row(
            children: [
              if (_navigation.peutRevenir) ...[
                ShadIconButton.outline(
                  icon: const Icon(LucideIcons.arrowLeft, size: 15),
                  height: 32,
                  width: 32,
                  onPressed: () => setState(_navigation.revient),
                ),
                const SizedBox(width: Pas.m),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      ecran.titre,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.h4.copyWith(
                        fontSize: 17,
                        letterSpacing: -0.2,
                        height: 1.2,
                      ),
                    ),
                    if (ecran.sousTitre != null || _navigation.peutRevenir)
                      Text(
                        ecran.sousTitre ?? _navigation.chemin.join('  ›  '),
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.muted.copyWith(fontSize: 11),
                      ),
                  ],
                ),
              ),
              ShadIconButton.ghost(
                icon: Icon(
                  LucideIcons.x,
                  size: 16,
                  color: theme.colorScheme.destructive,
                ),
                height: 32,
                width: 32,
                onPressed: widget.onQuitte,
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Cette archive est-elle celle que l'outil alimente en ce moment ?
  ///
  /// Le fichier fait foi. Le numero seul ne suffirait pas : une archive
  /// ouverte puis reprise porte le meme numero que la session vivante.
  bool _vivante(Archive a) =>
      a.fichier != null && a.fichier == widget.archives.courant;

  Widget _contenu() => switch (_navigation.courant) {
    EcranSuivi() => PageSuivi(
      session: session,
      res: widget.res,
      secondes: widget.secondes,
      eclatDe: widget.eclatDe,
      personnagesConfigures: config.personnages.length,
      onPersonnage: (s) => _va(EcranPersonnage(s.nom)),
      onReglages: () => setState(() => _navigation.choisit(Onglet.reglages)),
    ),
    // Le butin seul : cliquer un personnage, c'est vouloir voir ce qu'il
    // a ramasse. Ses combats etaient dans un onglet a cote, qu'il fallait
    // deviner ; ils se regardent pour la session entiere, et ont leur
    // propre entree dans le rail.
    EcranPersonnage(:final personnage) => PageButin(
      suivi: _suiviDe(personnage),
      res: widget.res,
    ),
    EcranMesCombats() => PageCombats(
      combats: session.combats,
      personnage: null,
      res: widget.res,
      onCombat: (c) => _va(EcranCombat(c, onglet: Onglet.mesCombats)),
    ),
    EcranMonInventaire() => PageInventaire(
      suivis: session.lignes,
      res: widget.res,
    ),
    EcranSessions() => PageSessions(
      archives: widget.archives,
      session: session,
      res: widget.res,
      onOuvre: (a) => _va(EcranSession(a)),
      onBascule: (a) async {
        await widget.onBascule(a);
        if (!mounted) return;
        // Basculer, c'est reprendre cette session : on veut la voir
        // tourner, pas rester devant la liste d'ou l'on vient.
        setState(() => _navigation.choisit(Onglet.suivi));
      },
    ),
    EcranSession(:final archive) => () {
      // La session en cours est relue a chaque image plutot que prise
      // telle qu'elle etait a l'ouverture : sans cela, une pause ou un
      // combat de plus ne se voyait qu'en ressortant de la page. Les
      // autres archives, elles, ne bougent plus.
      final vue = _vivante(archive)
          ? Archive.depuisSession(widget.session)
          : archive;
      return PageDetailSession(
        archive: vue,
        res: widget.res,
        onCombat: (i) => _va(EcranCombat(vue.combats[i])),
        onPersonnage: (nom) => _va(EcranButinArchive(vue, nom)),
      );
    }(),
    EcranButinArchive(:final archive, :final personnage) => PageButinArchive(
      bilan: archive.personnages.firstWhere(
        (p) => cleDe(p.nom) == cleDe(personnage),
        orElse: () => BilanPersonnage(
          nom: personnage,
          classe: null,
          niveau: null,
          xp: 0,
          kamasPiece: 0,
          butin: const {},
        ),
      ),
      res: widget.res,
    ),
    EcranCombat(:final combat, :final surligne) => PageRecapitulatif(
      combat: combat,
      res: widget.res,
      surligne: surligne,
    ),
    EcranReglages() => PageReglages(
      config: config,
      ou: widget.ou,
      res: widget.res,
      classes: widget.classes,
      interfaces: widget.interfaces,
      onChange: widget.onReglageChange,
    ),
  };

  /// Le suivi d'un personnage, ou une coquille vide s'il a disparu de la liste
  /// pendant qu'on regardait son butin.
  Suivi _suiviDe(String nom) => session.suivis[cleDe(nom)] ?? Suivi(nom);
}
