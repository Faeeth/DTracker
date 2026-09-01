/// Alimentation du suivi par la bibliotheque Python.
///
/// La capture du reseau, la reassemblage TCP et le decodage du protocole
/// restent en Python : c'est la que vit `dofus_stats`, valide par soixante-et-
/// onze verifications sur des captures reelles, et rien ne gagnerait a le
/// reecrire. Cette application en est le consommateur.
///
/// Le pont est un serveur WebSocket local que la bibliotheque ouvre elle-meme,
/// et qui diffuse un objet JSON par evenement. Ce transport existait avant
/// cette interface : il avait ete prevu pour qu'un programme ecrit dans un
/// autre langage puisse s'y brancher.
///
/// Le processus Python est lance par l'application, pour n'avoir qu'une seule
/// chose a demarrer. S'il tourne deja — lance a la main, par exemple pour
/// rejouer une capture — on se contente de s'y connecter.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:web_socket_channel/web_socket_channel.dart';
import 'emplacements.dart';

/// Ce que l'interface a besoin de savoir de l'etat de la liaison.
///
/// `liee` et `connecte` se distinguent, et ce n'est pas un detail : la
/// liaison peut etre etablie sans qu'aucun evenement n'arrive — jeu a
/// l'arret, ou capture qui ecoute la mauvaise carte. Confondre les deux
/// laissait chercher une panne de reseau la ou il n'y en avait pas.
enum EtatFlux {
  /// Rien ne tourne.
  arrete,

  /// On cherche a joindre la diffusion.
  attente,

  /// Liaison etablie, mais aucun evenement encore recu.
  liee,

  /// Des evenements arrivent.
  connecte,

  /// Aucun pilote de capture n'est installe.
  ///
  /// Le seul etat que l'utilisateur puisse corriger lui-meme, et le seul qui
  /// merite un lien : sans npcap, aucun programme ne peut lire le trafic.
  sansPilote,

  /// Le pilote est la, mais aucune carte n'est ecoutable.
  sansCarte,

  /// La capture n'a pas pu demarrer.
  erreur,
}

class Flux {
  Flux({
    this.hote = '127.0.0.1',
    this.port = 8765,
    required this.ou,
    this.interface = '',
  });

  /// Dossier de la bibliotheque Python, ou vit `dofus_stats`.
  /// Ou trouver la diffusion de capture, et sous quelle forme.
  final Emplacements ou;
  final String hote;
  final int port;

  /// L'interface a ecouter. Vide : toutes.
  ///
  /// Choisir la bonne carte est une question a laquelle on n'a pas de raison
  /// de savoir repondre — le jeu passe par l'Ethernet, le Wi-Fi ou un VPN, et
  /// cela change quand on debranche un cable. Une carte mal choisie ne se
  /// signale pas : l'outil reste muet, ce qui ressemble a une panne.
  ///
  /// Windows n'a pas de pseudo-interface `any`, propre a Linux ; la
  /// bibliotheque developpe donc `any` en autant de `-i` que de cartes, dans
  /// un seul flux pcapng.
  String interface;

  final _evenements = StreamController<Map<String, dynamic>>.broadcast();
  final _etats = StreamController<EtatFlux>.broadcast();

  Stream<Map<String, dynamic>> get evenements => _evenements.stream;
  Stream<EtatFlux> get etats => _etats.stream;

  Process? _processus;
  WebSocketChannel? _canal;
  Timer? _reprise;
  bool _arrete = false;
  EtatFlux _etat = EtatFlux.arrete;

  EtatFlux get etat => _etat;

  /// Reconnait ce que la diffusion dit d'elle-meme.
  ///
  /// Elle prefixe ses diagnostics d'un mot convenu — `npcap-absent`,
  /// `aucune-carte` — precisement pour que ce ne soit pas une phrase a
  /// analyser. L'etat qui en decoule survit a la fin du processus : c'est
  /// justement parce qu'il s'est arrete qu'on a quelque chose a dire.
  void _lit(String ligne) {
    if (ligne.contains('npcap-absent')) {
      _fige = EtatFlux.sansPilote;
      _pose(EtatFlux.sansPilote);
    } else if (ligne.contains('aucune-carte')) {
      _fige = EtatFlux.sansCarte;
      _pose(EtatFlux.sansCarte);
    }
  }

  /// Un etat que rien ne doit ecraser : la diffusion s'est arretee en disant
  /// pourquoi, et la reconnexion qui suit n'a rien de plus a apprendre.
  EtatFlux? _fige;

  void _pose(EtatFlux etat) {
    if (_fige != null && etat != _fige) return;
    if (_etat == etat) return;
    _etat = etat;
    _etats.add(etat);
  }

  /// Demarre la capture et s'y abonne.
  Future<void> demarre() async {
    _arrete = false;
    await _lancePython();
    _connecte();
  }

  /// Lance la diffusion si personne ne l'assure deja.
  ///
  /// Le port occupe signifie qu'une diffusion tourne : c'est le cas quand on
  /// rejoue une capture a la main pour mettre au point l'affichage. On ne la
  /// double pas.
  Future<void> _lancePython() async {
    if (await _portOuvert()) return;
    try {
      // Installee, la diffusion est un executable gele a cote du
      // programme : l'utilisateur n'a pas a avoir Python. Depuis les sources,
      // on lance le module, ce qui laisse le code modifiable sans le regeler.
      final gelee = File(ou.diffusion).existsSync();
      _processus = await Process.start(gelee ? ou.diffusion : 'python', [
        if (!gelee) ...['-m', 'dofus_stats.cli.stream'],
        '-i',
        interface.isEmpty ? 'any' : interface,
        '--mode',
        'websocket',
        '--host',
        hote,
        '--port',
        '$port',
      ], workingDirectory: ou.programme);
      // La sortie d'erreur porte les diagnostics de la bibliotheque ; on la
      // relaie telle quelle, sans quoi une capture qui echoue reste muette.
      _processus!.stderr
          .transform(utf8.decoder)
          .listen((ligne) {
            stderr.write('[capture] $ligne');
            _lit(ligne);
          });
      // La sortie standard ne sert a rien en mode websocket, mais un tube que
      // personne ne vide finit par se remplir : le processus fils se bloque
      // alors en ecriture, et le notre attend a la fermeture un flux qui ne
      // se refermera jamais.
      _processus!.stdout.drain<void>().ignore();
    } on ProcessException catch (e) {
      stderr.writeln('[capture] diffusion introuvable : ${e.message}');
      _pose(EtatFlux.erreur);
    }
  }

  Future<bool> _portOuvert() async {
    try {
      final prise = await Socket.connect(
        hote,
        port,
        timeout: const Duration(milliseconds: 300),
      );
      prise.destroy();
      return true;
    } on SocketException {
      return false;
    }
  }

  void _connecte() {
    if (_arrete) return;
    _pose(EtatFlux.attente);
    try {
      final canal = WebSocketChannel.connect(Uri.parse('ws://$hote:$port'));
      _canal = canal;
      // La liaison s'annonce des qu'elle est ouverte, sans attendre un
      // evenement : sans cela, une capture qui tourne mais n'entend rien
      // etait indiscernable d'une capture injoignable.
      canal.ready
          .then((_) {
            if (!_arrete && _etat == EtatFlux.attente) _pose(EtatFlux.liee);
          })
          .catchError((_) {});
      canal.stream.listen(
        (message) {
          _pose(EtatFlux.connecte);
          try {
            final objet = jsonDecode(message as String);
            if (objet is Map<String, dynamic>) _evenements.add(objet);
          } on FormatException {
            // Une ligne illisible ne doit pas interrompre le flux.
          }
        },
        onDone: _replanifie,
        onError: (_) => _replanifie(),
        cancelOnError: true,
      );
    } on Exception {
      _replanifie();
    }
  }

  /// Reconnexion patiente.
  ///
  /// Le jeu peut fermer sa connexion, la capture redemarrer : la liaison doit
  /// se retablir seule, sans que l'on ait a relancer l'application.
  void _replanifie() {
    _canal = null;
    if (_arrete) return;
    _pose(EtatFlux.attente);
    _reprise?.cancel();
    _reprise = Timer(const Duration(seconds: 2), _connecte);
  }

  Future<void> arrete() async {
    _arrete = true;
    _reprise?.cancel();
    // Fermer proprement une liaison WebSocket suppose un echange avec le
    // serveur, qui peut ne jamais venir — capture deja morte, tube sature.
    // On accorde une demi-seconde, puis on passe : la prise sera de toute
    // facon liberee par la sortie du processus. Sans cette borne, la
    // fermeture de la fenetre attendait cet echange, et l'utilisateur voyait
    // l'outil se figer apres avoir clique sur la croix.
    final canal = _canal;
    _canal = null;
    if (canal != null) {
      await canal.sink
          .close()
          .timeout(const Duration(milliseconds: 500), onTimeout: () {})
          .catchError((_) {});
    }
    await _tue();
    _pose(EtatFlux.arrete);
  }

  /// Tue la capture, dumpcap compris.
  ///
  /// `kill` n'emporte que le processus Python. `dumpcap`, qu'il a lance,
  /// survivrait et continuerait a capturer — un processus invisible qui garde
  /// une carte ouverte, et un port qui reste pris pour le prochain lancement.
  /// Sur Windows, `taskkill /T` emporte l'arbre entier.
  Future<void> _tue() async {
    final processus = _processus;
    _processus = null;
    if (processus == null) return;
    if (Platform.isWindows) {
      try {
        await Process.run('taskkill', [
          '/T',
          '/F',
          '/PID',
          '${processus.pid}',
        ]).timeout(const Duration(seconds: 2));
      } on Exception {
        // Deja mort, ou taskkill absent : le kill direct reste un filet.
      }
    }
    processus.kill();
  }

  Future<void> ferme() async {
    await arrete();
    await _evenements.close();
    await _etats.close();
  }
}
