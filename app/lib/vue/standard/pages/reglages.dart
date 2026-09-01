/// Les reglages.
///
/// **Chaque geste s'applique aussitot.** Il n'y a ni « Valider » ni
/// « Annuler » : on regle en voyant le resultat, et quitter la page ne fait
/// que la quitter. Deux boutons pour confirmer ce qu'on vient de voir se
/// produire n'ajoutaient qu'une hesitation. Le revers : un geste
/// malencontreux est ecrit aussi vite qu'un geste voulu.
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart' hide Cache;

import '../../../config.dart';
import '../../../modele/session.dart';
import '../../../source/flux.dart';
import '../../../source/ressources.dart';
import '../../../theme.dart';
import '../../compacte.dart';
import '../briques.dart';
import '../../../i18n/textes.dart';
import '../../../source/emplacements.dart';

/// Une interface de capture, telle que la bibliotheque la rapporte.
class Interface {
  const Interface({
    required this.numero,
    required this.libelle,
    this.device = '',
    this.description = '',
    this.mac = '',
    this.physique = true,
  });

  final String numero;
  final String libelle;

  /// L'adresse materielle, si le systeme la donne.
  ///
  /// Elle departage ce que le nom ne suffit pas a reconnaitre : un pilote
  /// Wi-Fi moderne expose « Wi-Fi », « Wi-Fi 3 » et « Wi-Fi 4 », et rien dans
  /// ces libelles ne dit laquelle porte le trafic. L'adresse, elle, se
  /// retrouve dans l'interface du routeur.
  final String mac;

  /// Le libelle tel qu'il s'affiche : le nom, puis l'adresse s'il y en a une.
  String get intitule => mac.isEmpty ? libelle : '$libelle  ·  $mac';

  /// Le nom de peripherique. Illisible, mais **stable** : le numero, lui, se
  /// decale des qu'une carte apparait. C'est donc lui qu'on conserve.
  final String device;

  /// La description du constructeur, qui departage deux cartes de meme nom.
  final String description;

  /// Une vraie carte Ethernet ou Wi-Fi, par opposition a un adaptateur
  /// virtuel, au Bluetooth ou a la boucle locale.
  final bool physique;

  String get valeur => device.isEmpty ? numero : device;

  /// Interroge la bibliotheque, qui sait ou vit `dumpcap`.
  ///
  /// Elle rend **toutes** les cartes, chacune sachant si elle est physique :
  /// le tri appartient a l'affichage, pas a la source.
  static Future<List<Interface>> liste(Emplacements ou) async {
    try {
      // Meme bascule que pour la diffusion : l'executable gele quand il
      // est la, le module Python depuis les sources.
      final gelee = File(ou.diffusion).existsSync();
      final sortie = await Process.run(
        gelee ? ou.diffusion : 'python',
        [
          if (!gelee) ...['-m', 'dofus_stats.cli.stream'],
          '--interfaces',
        ],
        workingDirectory: ou.programme,
        stdoutEncoding: utf8,
      );
      final objet = jsonDecode(sortie.stdout as String);
      if (objet is List) {
        return [
          for (final e in objet)
            if (e is Map)
              Interface(
                numero: '${e['numero']}',
                libelle: '${e['libelle']}',
                device: '${e['device'] ?? ''}',
                description: '${e['description'] ?? ''}',
                mac: '${e['mac'] ?? ''}',
                // Une bibliotheque plus ancienne ne rend pas le verdict :
                // tout garder vaut mieux que tout cacher.
                physique: e['physique'] as bool? ?? true,
              ),
        ];
      }
    } on Exception {
      // Sans liste, le choix se limite a toutes les interfaces.
    }
    return const [];
  }
}

class PageReglages extends StatefulWidget {
  const PageReglages({
    super.key,
    required this.config,
    required this.ou,
    required this.onChange,
    this.res,
    this.classes = const {},
    this.interfaces,
  });

  final Config config;
  final Emplacements ou;
  final VoidCallback onChange;

  final Ressources? res;
  final Map<String, int> classes;

  /// Fournie par les tests : sans elle, la page lance un sous-processus.
  final List<Interface>? interfaces;

  @override
  State<PageReglages> createState() => _PageReglagesState();
}

class _PageReglagesState extends State<PageReglages> {
  final _saisie = TextEditingController();
  List<Interface> _interfaces = const [];

  Config get config => widget.config;

  @override
  void initState() {
    super.initState();
    final fournies = widget.interfaces;
    if (fournies != null) {
      _interfaces = fournies;
      _migreLeReglage();
    } else {
      Interface.liste(widget.ou).then((liste) {
        if (!mounted) return;
        setState(() => _interfaces = liste);
        // La liste arrive apres coup : c'est seulement maintenant qu'on peut
        // reconnaitre la carte que designait un numero.
        _migreLeReglage();
      });
    }
  }

  @override
  void dispose() {
    _saisie.dispose();
    _poigneeFond.dispose();
    _poigneeTexte.dispose();
    super.dispose();
  }

  /// Les poignees des deux curseurs d'opacite.
  ///
  /// Tenues ici, et non recreees a chaque valeur : `ShadSlider` ne lit
  /// `initialValue` qu'une fois, et la clef qui servait a le reconstruire
  /// coupait le geste — on ne pouvait plus que cliquer sur une position, plus
  /// glisser. Un controleur laisse le curseur vivre et permet quand meme de
  /// lui pousser une valeur venue d'ailleurs : le fond, rabattu quand le
  /// texte descend sous lui.
  late final _poigneeFond = ShadSliderController(
    initialValue: config.opaciteFond.toDouble(),
  );
  late final _poigneeTexte = ShadSliderController(
    initialValue: config.opaciteTexte.toDouble(),
  );

  void _change(void Function() geste) {
    setState(geste);
    config.borne();
    widget.onChange();
  }

  /// Ramene un reglage donne par numero au nom de peripherique correspondant.
  ///
  /// Les versions precedentes conservaient le numero. Il marche encore pour
  /// dumpcap, mais il se decale des qu'une carte apparait — le choix d'hier
  /// peut designer une autre carte aujourd'hui.
  void _migreLeReglage() {
    final choix = config.interface;
    if (choix.isEmpty || _interfaces.isEmpty) return;
    if (_interfaces.any((i) => i.valeur == choix)) return;
    for (final i in _interfaces) {
      if (i.numero == choix && i.device.isNotEmpty) {
        _change(() => config.interface = i.device);
        return;
      }
    }
  }

  /// Le reglage courant, s'il ne correspond a aucune carte proposee.
  String? get _inconnue {
    final choix = config.interface;
    if (choix.isEmpty) return null;
    final proposees = _interfaces
        .where((i) => i.physique)
        .map((i) => i.valeur)
        .toSet();
    return proposees.contains(choix) ? null : choix;
  }

  void _ajoute() {
    final nom = _saisie.text.trim();
    if (nom.isEmpty) return;
    // La casse ne compte pas : c'est aussi ainsi que les gains sont attribues.
    if (config.personnages.any((n) => n.toLowerCase() == nom.toLowerCase())) {
      setState(_saisie.clear);
      return;
    }
    _change(() {
      config.personnages = [...config.personnages, nom];
      _saisie.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Onglets(
      entrees: [
        (
          'personnages',
          T.ongletPersonnagesAvecNombre(config.personnages.length),
          LucideIcons.users,
          _personnages(context),
        ),
        // `trendingUp` et non `sigma` ni `calculator` : ces deux-la ne
        // dessinent rien a l'ecran, alors que la police les contient et que le
        // widget est bien dans l'arbre — verifie jusqu'aux contours du glyphe.
        // Faute d'explication, on prend un glyphe dont on constate qu'il
        // s'affiche : celui-ci sert deja a l'experience dans le suivi. Il dit
        // d'ailleurs bien de quoi l'onglet decide — ce qui entre dans les
        // totaux.
        (
          'comptage',
          T.ongletComptage,
          LucideIcons.trendingUp,
          _comptage(context),
        ),
        ('capture', T.ongletCapture, LucideIcons.antenna, _capture(context)),
        ('fenetre', T.ongletFenetre, LucideIcons.appWindow, _fenetre(context)),
        ('langue', T.ongletLangue, LucideIcons.languages, _langue(context)),
      ],
    );
  }

  // -------------------------------------------------------------- personnages

  Widget _personnages(BuildContext context) {
    final theme = ShadTheme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ShadCard(
          padding: const EdgeInsets.all(Pas.m),
          child: Row(
            children: [
              Expanded(
                child: ShadInput(
                  controller: _saisie,
                  placeholder: Text(T.nomDuPersonnage),
                  onSubmitted: (_) => _ajoute(),
                ),
              ),
              const SizedBox(width: Pas.s),
              ShadButton(
                leading: const Icon(LucideIcons.plus, size: 15),
                onPressed: _ajoute,
                child: Text(T.ajouter),
              ),
            ],
          ),
        ),
        const SizedBox(height: Pas.m),
        Expanded(
          child: config.personnages.isEmpty
              ? Vide(
                  T.aucunPersonnageSuivi,
                  icone: LucideIcons.userX,
                  detail: T.gainsComptesDetail,
                )
              : ListView.builder(
                  itemCount: config.personnages.length,
                  itemBuilder: (_, i) =>
                      _personnage(theme, config.personnages[i]),
                ),
        ),
      ],
    );
  }

  Widget _personnage(ShadThemeData theme, String nom) {
    final classe =
        widget.classes[nom] ??
        widget.classes.entries
            .firstWhere(
              (e) => e.key.toLowerCase() == nom.toLowerCase(),
              orElse: () => const MapEntry('', -1),
            )
            .value;
    final connue = classe > 0;
    final chemin = connue ? widget.res?.imageClasse(classe) : null;
    return Padding(
      padding: const EdgeInsets.only(bottom: Pas.s),
      child: ShadCard(
        padding: const EdgeInsets.symmetric(horizontal: Pas.m, vertical: Pas.s),
        child: Row(
          children: [
            Infobulle(
              // L'infobulle separe les deux raisons d'un « ? » : classe encore
              // inconnue, ou portrait introuvable faute d'extraction. Ce n'est
              // pas le meme remede.
              builder: (_) => Text(
                !connue
                    ? T.classeInconnue
                    : chemin == null
                    ? T.portraitIntrouvable(
                        widget.res?.classe(classe) ?? T.classeNumero(classe),
                      )
                    : widget.res?.classe(classe) ?? T.classeNumero(classe),
              ),
              child: SizedBox(
                width: 24,
                height: 24,
                child: chemin == null
                    ? Center(
                        child: Text(
                          '?',
                          style: theme.textTheme.muted.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      )
                    : Image.file(
                        File(chemin),
                        filterQuality: FilterQuality.medium,
                        errorBuilder: (_, _, _) => const SizedBox.shrink(),
                      ),
              ),
            ),
            const SizedBox(width: Pas.m),
            Expanded(
              child: Text(
                nom,
                style: theme.textTheme.small.copyWith(fontSize: 13),
              ),
            ),
            Infobulle(
              builder: (_) => Text(T.retirer),
              child: ShadIconButton.ghost(
                icon: Icon(
                  LucideIcons.x,
                  size: 14,
                  color: theme.colorScheme.destructive,
                ),
                height: 26,
                width: 26,
                onPressed: () => _change(
                  () => config.personnages = config.personnages
                      .where((n) => n != nom)
                      .toList(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ----------------------------------------------------------------- comptage

  Widget _comptage(BuildContext context) {
    final theme = ShadTheme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _bascule(
          theme,
          T.compterLesSucces,
          T.compterLesSuccesDetail,
          config.succesComptes,
          (v) => _change(() => config.succesComptes = v),
        ),
      ],
    );
  }

  /// Un reglage a deux etats : son libelle, ce qu'il fait, son interrupteur.
  Widget _bascule(
    ShadThemeData theme,
    String libelle,
    String detail,
    bool valeur,
    void Function(bool) onChange,
  ) => ShadCard(
    padding: const EdgeInsets.all(Pas.m),
    child: Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                libelle,
                style: theme.textTheme.small.copyWith(fontSize: 13),
              ),
              const SizedBox(height: 2),
              Text(detail, style: theme.textTheme.muted.copyWith(height: 1.5)),
            ],
          ),
        ),
        const SizedBox(width: Pas.m),
        ShadSwitch(value: valeur, onChanged: onChange),
      ],
    ),
  );

  // ------------------------------------------------------------------- langue

  /// Le choix de la langue.
  ///
  /// Chaque langue s'annonce dans la sienne — « English », « Español » — et
  /// non traduite : on cherche la sienne dans une liste qu'on ne lit pas
  /// forcement.
  Widget _langue(BuildContext context) {
    final theme = ShadTheme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ShadCard(
          padding: const EdgeInsets.all(Pas.m),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Section(T.langue),
              Text(T.langueDetail, style: theme.textTheme.muted),
              const SizedBox(height: Pas.m),
              for (final langue in Langue.values) ...[
                _choixLangue(theme, langue),
                const SizedBox(height: Pas.xs),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _choixLangue(ShadThemeData theme, Langue langue) {
    final choisie = langue.code == config.langue;
    return ShadButton.ghost(
      mainAxisAlignment: MainAxisAlignment.start,
      backgroundColor: choisie ? theme.colorScheme.accent : null,
      leading: Icon(
        choisie ? LucideIcons.check : LucideIcons.circle,
        size: 14,
        color: choisie
            ? theme.colorScheme.primary
            : theme.colorScheme.mutedForeground,
      ),
      onPressed: () => _change(() {
        config.langue = langue.code;
        changeLangue(langue);
      }),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Un filet autour : le blanc du drapeau francais se perdrait sur
          // une carte claire, et le bord donne au dessin l'air d'un objet
          // plutot que d'une tache de couleur.
          Container(
            width: 21,
            height: 14,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(2),
              border: Border.all(
                color: theme.colorScheme.border,
                width: 0.5,
              ),
            ),
            clipBehavior: Clip.antiAlias,
            child: SvgPicture.asset(langue.drapeau, fit: BoxFit.cover),
          ),
          const SizedBox(width: Pas.s),
          Text(langue.nom),
        ],
      ),
    );
  }

  // ------------------------------------------------------------------ capture

  Widget _capture(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ShadCard(
          padding: const EdgeInsets.all(Pas.m),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Section(T.interfaceEcoute),
              const SizedBox(height: Pas.s),
              ShadSelect<String>(
                initialValue: config.interface,
                minWidth: 320,
                placeholder: Text(T.toutesLesInterfaces),
                options: [
                  ShadOption(
                    value: '',
                    child: Text(T.toutesLesInterfacesRecommande),
                  ),
                  // Seules les vraies cartes : le jeu ne passe ni par un
                  // adaptateur VPN ni par le Bluetooth, et les proposer ne
                  // fait qu'offrir des facons de se tromper.
                  for (final i in _interfaces.where((i) => i.physique))
                    ShadOption(value: i.valeur, child: Text(i.intitule)),
                  // Un reglage venu d'ailleurs doit rester selectionnable.
                  if (_inconnue != null)
                    ShadOption(
                      value: _inconnue!,
                      child: Text(T.introuvable('$_inconnue')),
                    ),
                ],
                selectedOptionBuilder: (context, valeur) => Text(
                  valeur.isEmpty
                      ? T.toutesLesInterfacesRecommande
                      : _interfaces
                                .where((i) => i.valeur == valeur)
                                .map((i) => i.intitule)
                                .firstOrNull ??
                            T.introuvable(valeur),
                ),
                onChanged: (v) => _change(() => config.interface = v ?? ''),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ------------------------------------------------------------------ fenetre

  Widget _fenetre(BuildContext context) {
    final theme = ShadTheme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ShadCard(
          padding: const EdgeInsets.all(Pas.m),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  T.toujoursDevant,
                  style: theme.textTheme.small.copyWith(fontSize: 13),
                ),
              ),
              ShadSwitch(
                value: config.toujoursDevant,
                onChanged: (v) => _change(() => config.toujoursDevant = v),
              ),
            ],
          ),
        ),
        const SizedBox(height: Pas.m),
        // La carte prend le reste de la page, et l'apercu le reste de la
        // carte : sa hauteur ne se decide pas ici mais a l'ecran. Fixe, elle
        // faisait passer le bas du decor sous le bord de la fenetre, ou rien
        // ne permettait d'aller le chercher — la page n'a pas d'ascenseur.
        Expanded(
          child: ShadCard(
            padding: const EdgeInsets.all(Pas.m),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Section(T.transparence),
                // Une ligne : la seule chose qu'on ne devine pas en jouant avec
                // les curseurs, c'est pourquoi le fond bute contre le texte.
                // Le reste, l'apercu juste dessous le montre mieux qu'un
                // paragraphe.
                Text(T.transparenceDetail, style: theme.textTheme.muted),
                const SizedBox(height: Pas.m),
                _curseur(
                  theme,
                  T.fond,
                  _poigneeFond,
                  config.opaciteFond,
                  0,
                  config.opaciteTexte,
                  (v) => _change(() => config.opaciteFond = v),
                ),
                const SizedBox(height: Pas.s),
                _curseur(
                  theme,
                  T.texte,
                  _poigneeTexte,
                  config.opaciteTexte,
                  opaciteTexteMin,
                  100,
                  (v) {
                    _change(() => config.opaciteTexte = v);
                    // Le fond a pu etre rabattu avec lui : sa poignee doit le
                    // suivre, sans quoi la barre annonce quatre-vingts pour une
                    // valeur de vingt.
                    _poigneeFond.value = config.opaciteFond.toDouble();
                  },
                ),

                const SizedBox(height: Pas.m),
                Expanded(child: _apercu(theme)),
              ],
            ),
          ),
        ),
      ],
    );
  }

  /// Quatre personnages inventes, aux chiffres ronds.
  ///
  /// Une maquette et non la session en cours : celle-ci peut n'avoir qu'un
  /// personnage, ou aucun, et l'apercu servirait alors a regler une
  /// transparence sur une ligne — ou sur du vide. Quatre lignes remplies
  /// donnent a voir ce qu'on aura vraiment sous les yeux en jouant.
  ///
  /// Les chiffres sont faux et ronds a dessein : on regarde ici la lisibilite,
  /// pas les gains.
  static final Session _maquette = () {
    const noms = ['Perso 1', 'Perso 2', 'Perso 3', 'Perso 4'];
    final session = Session(noms)..nom = 'Session 12';
    const xp = [214500, 186300, 245800, 132900];
    const kamas = [98400, 76200, 112500, 54800];
    const niveaux = [200, 199, 198, 195];
    // Une classe par ligne, pour que les portraits ne soient pas tous les
    // memes : c'est aussi ce qu'on regarde en jugeant une transparence.
    const classes = [12, 4, 7, 10];
    for (var i = 0; i < noms.length; i++) {
      final suivi = session.suivis[cleDe(noms[i])]!
        ..vu = true
        ..classe = classes[i]
        ..niveau = niveaux[i]
        ..xpGagnee = xp[i]
        ..kamasPiece = kamas[i]
        ..xpSeuilBas = 0
        ..xpSeuilHaut = 1000000
        ..xpTotal = 250000 + i * 150000;
      suivi.combats = 12 + i;
    }
    return session;
  }();

  /// La vue compacte, telle qu'elle sera, sur un damier.
  ///
  /// Les curseurs se reglaient a l'aveugle : il fallait basculer de vue,
  /// juger, revenir, corriger. L'apercu suit le curseur au pixel pres.
  ///
  /// Le damier, et non un fond uni : c'est la facon convenue de montrer ce
  /// qu'on voit **au travers**, et un fond uni aurait menti sur ce que donne
  /// une transparence posee sur un decor qui bouge.
  Widget _apercu(ShadThemeData theme) {
    final session = _maquette;
    final hauteur = VueCompacte.hauteurPour(session.lignes.length);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Un titre de rubrique, comme ailleurs : le damier se comprend a le
        // voir, et l'expliquer prenait une ligne pour rien.
        Section(T.apercu),
        Expanded(
          child: ClipRRect(
            borderRadius: theme.radius,
            child: DecoratedBox(
              // Un decor du jeu, et non un damier : une transparence se juge
              // sur ce qui passera vraiment dessous. Celui-ci a ce qu'il faut
              // pour cela — des feuillages clairs, des rochers sombres, des
              // troncs entre les deux — et l'on voit du meme coup ou le texte
              // tient et ou il commence a se perdre.
              decoration: const BoxDecoration(
                image: DecorationImage(
                  image: AssetImage('assets/apercu_jeu.jpg'),
                  fit: BoxFit.cover,
                ),
              ),
              child: SizedBox.expand(
                child: Center(
                  // La vue garde sa taille reelle meme si le decor est plus
                  // court que lui : c'est ce qu'on est venu juger. A la plus
                  // petite fenetre, elle depasse alors du decor et se trouve
                  // rognee — le ClipRRect s'en charge — plutot que comprimee.
                  child: OverflowBox(
                    maxHeight: double.infinity,
                    child: SizedBox(
                      width: config.largeur,
                      // Quelques pixels de marge : `hauteurPour` donne la hauteur
                      // exacte que la fenetre prendra, et une police un peu plus
                      // large suffit a la depasser d'un cheveu. Dans la vraie
                      // fenetre cela ne se voit pas — elle s'ajuste ; ici, un pied
                      // rogne ferait croire a un defaut d'affichage.
                      height: hauteur + 8,
                      // Verrouillee : sans cela, l'apercu poserait ses zones de
                      // deplacement et la fenetre des reglages suivrait la souris.
                      child: VueCompacte(
                        session: session,
                        res: widget.res ?? Ressources('.'),
                        opacites: Opacites(
                          fond: config.opaciteFond / 100,
                          texte: config.opaciteTexte / 100,
                        ),
                        secondes: 3600,
                        etat: EtatFlux.connecte,
                        diagnostic: '',
                        eclatDe: (_) => 0,
                        personnagesConfigures: session.lignes.length,
                        verrouille: true,
                        onPause: () {},
                        onReset: () {},
                        onRenomme: (_) {},
                        onVue: () {},
                        onVerrou: () {},
                        onQuitte: () {},
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// Un curseur d'opacite, de zero a cent.
  ///
  /// La course va toujours de zero a cent, meme quand le reglage a des
  /// bornes : la part interdite se voit alors, voilee, au lieu d'etre
  /// escamotee. Un curseur qui commence a vingt sans le dire laisse croire
  /// qu'on est au minimum quand on est au cinquieme, et un curseur dont la
  /// course se raccourcit quand on baisse le texte donne le meme mensonge a
  /// l'autre bout.
  Widget _curseur(
    ShadThemeData theme,
    String libelle,
    ShadSliderController poignee,
    int valeur,
    int minimum,
    int maximum,
    void Function(int) onChange,
  ) {
    return Row(
      children: [
        SizedBox(
          width: 60,
          child: Text(
            libelle,
            style: theme.textTheme.small.copyWith(fontSize: 12),
          ),
        ),
        Expanded(
          child: Stack(
            alignment: Alignment.centerLeft,
            children: [
              ShadSlider(
                controller: poignee,
                max: 100,
                onChanged: (v) => onChange(v.round().clamp(minimum, maximum)),
              ),
              // Les parts hors d'atteinte. En bas, le texte devient illisible
              // et la vue ne sert plus a rien ; en haut, le fond passerait
              // devant son propre texte.
              if (minimum > 0)
                _voile(theme, minimum / 100, Alignment.centerLeft),
              if (maximum < 100)
                _voile(theme, (100 - maximum) / 100, Alignment.centerRight),
            ],
          ),
        ),
        SizedBox(
          width: 52,
          child: Text(
            '$valeur %',
            textAlign: TextAlign.right,
            style: theme.textTheme.muted.copyWith(fontSize: 12),
          ),
        ),
      ],
    );
  }

  /// Une part de course voilee, a l'un ou l'autre bout.
  Widget _voile(ShadThemeData theme, double part, Alignment cote) =>
      IgnorePointer(
        child: Align(
          alignment: cote,
          child: FractionallySizedBox(
            widthFactor: part,
            child: Container(
              height: 16,
              decoration: BoxDecoration(
                color: theme.colorScheme.background.withValues(alpha: 0.75),
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        ),
      );
}
