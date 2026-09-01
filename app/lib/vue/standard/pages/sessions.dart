/// Les sessions enregistrees : la liste, et le detail de l'une d'elles.
///
/// L'ordre est celui du temps, de la plus recente a la plus ancienne, et celle
/// que l'outil alimente vient donc en tete, marquee comme telle. C'est ainsi
/// qu'on les cherche : « ma soiree d'hier », pas « la session numero sept ».
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart' hide Cache;

import '../../../modele/session.dart';
import '../../../source/archives.dart';
import '../../../source/ressources.dart';
import '../../../theme.dart';
import '../briques.dart';
import 'combats.dart';
import 'inventaire.dart';
import '../../../i18n/textes.dart';

class PageSessions extends StatefulWidget {
  const PageSessions({
    super.key,
    required this.archives,
    required this.session,
    required this.res,
    required this.onOuvre,
    this.onBascule,
  });

  final Archives archives;
  final Session session;
  final Ressources res;
  final void Function(Archive) onOuvre;

  /// Rendre cette archive courante. Nul en consultation seule (les tests).
  final Future<void> Function(Archive)? onBascule;

  @override
  State<PageSessions> createState() => _PageSessionsState();
}

class _PageSessionsState extends State<PageSessions> {
  List<Archive>? _liste;
  String? _renomme;
  final _champ = TextEditingController();

  @override
  void initState() {
    super.initState();
    _charge();
  }

  @override
  void dispose() {
    _champ.dispose();
    super.dispose();
  }

  Future<void> _charge() async {
    // La session en cours est ecrite avant d'etre listee : ce qu'on vient de
    // gagner doit y figurer, pas l'etat d'il y a vingt secondes. Si elle est
    // encore vide, rien n'est ecrit — elle n'existe qu'en memoire.
    await widget.archives.enregistre(widget.session);
    final liste = await widget.archives.liste();
    if (mounted) setState(() => _liste = liste);
  }

  /// Est-ce la session que l'outil alimente en ce moment ?
  bool _courante(Archive a) =>
      a.fichier != null && a.fichier == widget.archives.courant;

  static String _nomParDefaut(Archive a) =>
      a.numero > 0 ? T.sessionNumero(a.numero) : T.sessions;

  /// Le nom affiche : celui de la session vivante pour la courante, sans quoi
  /// un renommage depuis le rail ne se verrait pas ici.
  String _nomDe(Archive a) {
    for (final candidat in [
      if (_courante(a)) widget.session.nom,
      a.nom,
      _nomParDefaut(a),
    ]) {
      if (candidat.isNotEmpty) return candidat;
    }
    return 'Session';
  }

  String _quandDe(Archive a) {
    final d = a.quand;
    String n(int v) => v.toString().padLeft(2, '0');
    return '${n(d.day)}/${n(d.month)} à ${n(d.hour)}:${n(d.minute)}';
  }

  /// Renomme une session, la courante comprise.
  ///
  /// La courante passe par la session vivante : c'est elle qui fait foi tant
  /// que l'outil tourne, et ecrire seulement le fichier serait efface a la
  /// sauvegarde suivante.
  Future<void> _valide(Archive a) async {
    final saisi = _champ.text.trim();
    final nom = saisi.isEmpty ? _nomParDefaut(a) : saisi;
    setState(() => _renomme = null);
    if (_courante(a)) {
      widget.session.nom = nom;
      await widget.archives.enregistre(widget.session);
    } else {
      await widget.archives.renomme(a, nom);
    }
    await _charge();
  }

  Future<void> _bascule(Archive a) async {
    await widget.onBascule?.call(a);
    if (mounted) await _charge();
  }

  /// La corbeille ne supprime pas : elle demande.
  ///
  /// Les lignes sont serrees et le crayon est juste a cote — un clic de trop
  /// effacerait une soiree entiere, sans rien pour revenir en arriere. La
  /// demande dit **ce qu'on perd** : « etes-vous sur ? » ne renseigne
  /// personne.
  Future<void> _demandeSuppression(Archive a) async {
    final confirme = await showShadDialog<bool>(
      context: context,
      builder: (contexte) => ShadDialog.alert(
        title: Text(T.supprimerCetteSession),
        description: Padding(
          padding: const EdgeInsets.symmetric(vertical: Pas.s),
          child: Text(
            '${_nomDe(a)}  ·  ${_quandDe(a)}\n'
            '${T.resumeSession('${a.nombreCombats}', formateNombre(a.xp), formateNombre(a.kamas))}\n\n'
            'Le fichier est effacé du disque. Rien ne permet de revenir en '
            'arrière.',
          ),
        ),
        actions: [
          // « Annuler » en premier, et c'est voulu : la main part de la
          // gauche, et le geste le plus proche doit etre celui qui ne detruit
          // rien.
          ShadButton.outline(
            onPressed: () => Navigator.of(contexte).pop(false),
            child: const Text('Annuler'),
          ),
          ShadButton.destructive(
            onPressed: () => Navigator.of(contexte).pop(true),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
    if (confirme != true || !mounted) return;
    if (await widget.archives.supprime(a) && mounted) await _charge();
  }

  // Un getter : les libelles changent avec la langue.
  static List<Colonne> get _colonnes => [
    Colonne(T.colSession, 0),
    Colonne(T.colDuree, 110),
    Colonne(T.colCombats, 96, Alignment.centerRight),
    Colonne(T.colExperience, 128, Alignment.centerRight),
    Colonne(T.colButin, 128, Alignment.centerRight),
    const Colonne('', 108, Alignment.centerRight),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);
    final liste = _liste;
    if (liste == null) {
      return const Center(
        child: SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }
    if (liste.isEmpty) {
      return Vide(
        T.aucuneSession,
        icone: LucideIcons.history,
        detail: T.aucuneSessionNaitDetail,
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Section(
          T.enregistrees,
          aDroite: ShadBadge.secondary(child: Text('${liste.length} sessions')),
        ),
        Expanded(
          child: Tableau(
            colonnes: _colonnes,
            hauteurLigne: 56,
            lignes: [for (final a in liste) _rang(theme, a)],
          ),
        ),
      ],
    );
  }

  List<Widget> _rang(ShadThemeData theme, Archive a) {
    final courante = _courante(a);
    final pieces = a.personnages.fold(0, (n, p) => n + p.kamasPiece);
    final ressources = a.personnages.fold(0, (n, p) => n + p.kamasButin);
    return [
      _nom(theme, a, courante),
      Infobulle(
        // La duree est la somme des periodes d'ecoute, pas l'ecart entre la
        // premiere et la derniere : une session etalee sur quatre jours ne
        // dure pas quatre jours.
        builder: (_) => Text(
          a.reprises > 1
              ? T.dureeEcouteReprises(formateDuree(a.duree), a.reprises)
              : T.dureeEcoute(formateDuree(a.duree)),
        ),
        child: Text(
          formateDuree(a.duree),
          style: theme.textTheme.muted.copyWith(fontSize: 11),
        ),
      ),
      Text(
        '${a.nombreCombats}',
        style: theme.textTheme.small.copyWith(fontSize: 12),
      ),
      Text(
        formateNombre(a.xp),
        style: theme.textTheme.small.copyWith(fontSize: 12),
      ),
      Infobulle(
        builder: (_) => Text(
          '${T.kamasEnPiece} : ${formateNombre(pieces)}\n'
          '${T.valeurEstimee} : ${formateNombre(ressources)}',
        ),
        child: Kamas(a.kamas, image: widget.res.imageKamas, taille: 12),
      ),
      Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          ShadIconButton.ghost(
            icon: const Icon(LucideIcons.pencil, size: 13),
            height: 26,
            width: 26,
            onPressed: () => setState(() {
              _renomme = a.fichier;
              _champ.text = _nomDe(a);
              _champ.selection = TextSelection(
                baseOffset: 0,
                extentOffset: _champ.text.length,
              );
            }),
          ),
          // Pas de corbeille sur la session en cours : son fichier serait
          // recree a la sauvegarde suivante, et une suppression qui se defait
          // toute seule vaut moins qu'un refus franc.
          if (!courante)
            ShadIconButton.ghost(
              icon: Icon(
                LucideIcons.trash2,
                size: 13,
                color: theme.colorScheme.destructive,
              ),
              height: 26,
              width: 26,
              onPressed: () => _demandeSuppression(a),
            ),
          ShadIconButton.ghost(
            icon: const Icon(LucideIcons.chevronRight, size: 15),
            height: 26,
            width: 26,
            onPressed: () => widget.onOuvre(a),
          ),
        ],
      ),
    ];
  }

  Widget _nom(ShadThemeData theme, Archive a, bool courante) {
    if (_renomme == a.fichier && a.fichier != null) {
      return ShadInput(
        controller: _champ,
        autofocus: true,
        onSubmitted: (_) => _valide(a),
        onPressedOutside: (_) => _valide(a),
      );
    }
    return Row(
      children: [
        Flexible(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _nomDe(a),
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.small.copyWith(fontSize: 13),
              ),
              Text(
                _quandDe(a),
                style: theme.textTheme.muted.copyWith(fontSize: 10),
              ),
            ],
          ),
        ),
        const SizedBox(width: Pas.s),
        if (courante)
          ShadBadge(
            child: Text(widget.session.enPause ? 'en pause' : 'en cours'),
          )
        else
          Infobulle(
            builder: (_) => const Text(
              'Reprendre cette session : elle redevient la session '
              'courante\net repart aussitôt. Le temps déjà passé dessus '
              'est conservé.',
            ),
            child: ShadButton.ghost(
              size: ShadButtonSize.sm,
              onPressed: () => _bascule(a),
              child: const Text('Basculer'),
            ),
          ),
      ],
    );
  }
}

/// Le detail d'une session : ses chiffres, ses personnages, ses combats.
///
/// Les trois listes qui redisaient la meme chose ont laisse place a des
/// **onglets** : personnages et combats, chacun chez lui. Le compte des
/// challenges reste dans le bandeau, ou il resume sans rien detacher.
class PageDetailSession extends StatelessWidget {
  const PageDetailSession({
    super.key,
    required this.archive,
    required this.res,
    required this.onCombat,
    required this.onPersonnage,
  });

  final Archive archive;
  final Ressources res;
  final void Function(int) onCombat;

  /// Ouvre l'inventaire d'un personnage sur cette session.
  final void Function(String) onPersonnage;

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _resume(theme),
        const SizedBox(height: Pas.s),
        Expanded(
          child: Onglets(
            entrees: [
              (
                'combats',
                'Combats (${archive.combats.length})',
                LucideIcons.swords,
                _combats(theme),
              ),
              (
                'personnages',
                'Personnages (${archive.personnages.length})',
                LucideIcons.users,
                _personnages(theme),
              ),
              (
                'inventaire',
                'Inventaire',
                LucideIcons.package,
                PageInventaire(suivis: _suivis, res: res),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// Les personnages de la session, sous la forme que l'inventaire attend.
  ///
  /// Une archive garde des bilans, pas des compteurs vivants. On reconstitue
  /// le suivi que chaque bilan represente plutot que d'ecrire une seconde
  /// grille : c'est deja ce que fait l'inventaire d'un personnage archive.
  List<Suivi> get _suivis => [
    for (final p in archive.personnages)
      Suivi(p.nom)
        ..classe = p.classe
        ..niveau = p.niveau
        ..kamasPiece = p.kamasPiece
        ..vu = true
        ..ajouteTout(p.butin),
  ];

  /// Le resume, servi serre : trois bandes se succedent deja au-dessus de la
  /// liste — celle-ci, les onglets, puis le titre de la rubrique — et chaque
  /// pixel repris ici est une ligne de plus a l'ecran.
  Widget _resume(ShadThemeData theme) => ShadCard(
    padding: const EdgeInsets.symmetric(horizontal: Pas.l, vertical: Pas.s),
    child: Row(
      children: [
        Chiffre(
          T.colDuree,
          formateDuree(archive.duree),
          icone: LucideIcons.timer,
          detail: archive.reprises > 1 ? T.nbReprises(archive.reprises) : null,
        ),
        const SizedBox(width: Pas.xl),
        Chiffre(
          T.colCombats,
          '${archive.nombreCombats}',
          icone: LucideIcons.swords,
        ),
        const SizedBox(width: Pas.xl),
        Chiffre(
          T.colExperience,
          formateNombre(archive.xp),
          icone: LucideIcons.trendingUp,
        ),
        const SizedBox(width: Pas.xl),
        Chiffre(
          T.colButin,
          formateNombre(archive.kamas),
          couleur: theme.colorScheme.primary,
          icone: LucideIcons.coins,
        ),
        const SizedBox(width: Pas.xl),
        Chiffre(
          T.colChallenges,
          '${archive.challengesReussis}/${archive.challengesSeuls.length}',
          icone: LucideIcons.target,
        ),
      ],
    ),
  );

  // -------------------------------------------------------------- personnages

  // Un getter : les libelles changent avec la langue.
  static List<Colonne> get _colonnesPersos => [
    Colonne(T.colPersonnage, 0),
    Colonne(T.colObjets, 100, Alignment.centerRight),
    Colonne(T.colExperience, 132, Alignment.centerRight),
    Colonne(T.colButin, 138, Alignment.centerRight),
  ];

  Widget _personnages(ShadThemeData theme) {
    if (archive.personnages.isEmpty) {
      return Vide(T.aucunPersonnageSession, icone: LucideIcons.userX);
    }
    return Tableau(
      colonnes: _colonnesPersos,
      lignes: [
        for (final p in archive.personnages)
          [
            Row(
              children: [
                SizedBox(width: 22, height: 22, child: _portrait(p.classe)),
                const SizedBox(width: Pas.s),
                Flexible(
                  child: Text(
                    p.nom,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.small.copyWith(fontSize: 13),
                  ),
                ),
              ],
            ),
            Text(
              '${p.unites}',
              style: theme.textTheme.muted.copyWith(fontSize: 11),
            ),
            Text(
              formateNombre(p.xp),
              style: theme.textTheme.small.copyWith(fontSize: 12),
            ),
            // Sans infobulle : la composition se lit en entier d'un clic sur
            // la ligne, et la redire au survol couvrait le tableau des qu'on
            // le parcourait.
            Kamas(p.kamasTotal, image: res.imageKamas, taille: 12),
          ],
      ],
      // Ouvrir un personnage montre ce qu'il a ramasse pendant la session.
      onLigne: (rang) => onPersonnage(archive.personnages[rang].nom),
    );
  }

  Widget? _portrait(int? classe) {
    final chemin = res.imageClasse(classe);
    return chemin == null
        ? null
        : Image.file(
            File(chemin),
            filterQuality: FilterQuality.medium,
            errorBuilder: (_, _, _) => const SizedBox.shrink(),
          );
  }

  // ------------------------------------------------------------------ combats

  /// La meme liste que « Mes combats », a l'identique.
  ///
  /// Elle avait sa propre version, avec ses colonnes a elle : ni les icones du
  /// butin, ni le symbole des kamas, ni le « XP » a cote du chiffre, et pas de
  /// tri. Deux listes pour la meme chose, c'etait deux endroits ou corriger.
  Widget _combats(ShadThemeData theme) {
    if (archive.combats.isEmpty) {
      return Vide(T.aucunCombat, icone: LucideIcons.shield);
    }
    final combats = _combatsCompletes;
    return PageCombats(
      combats: combats,
      personnage: null,
      res: res,
      avecTitre: false,
      onCombat: (c) => onCombat(combats.indexOf(c)),
    );
  }

  /// Les combats, leurs challenges rattaches.
  ///
  /// Les archives d'avant le rattachement ne portent les challenges que dans
  /// une liste a part ; `challengesDe` les retrouve par leur horodatage. On
  /// repare ici plutot que dans la liste, qui n'a pas a connaitre les vieux
  /// formats.
  List<Combat> get _combatsCompletes => [
    for (var i = 0; i < archive.combats.length; i++)
      if (archive.combats[i].challenges.isNotEmpty)
        archive.combats[i]
      else
        Combat(
          fin: archive.combats[i].fin,
          duree: archive.combats[i].duree,
          participants: archive.combats[i].participants,
          adversaires: archive.combats[i].adversaires,
          challenges: archive.challengesDe(i),
        ),
  ];
}
