/// Ce qu'une version a change, tel qu'on l'annonce au lancement.
///
/// Tenu a la main, version par version : c'est le seul texte du projet
/// qu'aucun outil ne peut ecrire a notre place, et le seul dont la redaction
/// soit un choix editorial. Le parti pris est de rester court et de parler du
/// resultat, pas du moyen — celui qui lance l'outil veut jouer, pas lire un
/// journal de bord.
///
/// Trois rubriques, et la frontiere se tient :
///
/// - **Nouveautes** : ce qui n'existait pas.
/// - **Correctifs** : ce qui marchait mal.
/// - **Ajustements** : ce qui marchait, et se lit mieux.
///
/// Seule la version installee est annoncee. Trois versions de retard ne
/// donnent pas trois fenetres : on montre celle qu'on vient de recevoir, qui
/// est aussi la seule dont le lecteur puisse verifier les effets sous ses
/// yeux.
///
/// Une version absente de la table n'ouvre aucune fenetre — c'est le cas des
/// versions de developpement, et le comportement voulu pour une publication
/// dont on n'aurait rien a dire.
library;

import 'textes.dart';

/// Les trois listes d'une version, dans une langue.
class NotesVersion {
  const NotesVersion({
    this.nouveautes = const [],
    this.correctifs = const [],
    this.ajustements = const [],
  });

  final List<String> nouveautes;
  final List<String> correctifs;
  final List<String> ajustements;

  bool get vide =>
      nouveautes.isEmpty && correctifs.isEmpty && ajustements.isEmpty;
}

/// Les notes d'une version, dans la langue courante ou celle demandee.
NotesVersion? notesDe(String version, [Langue? langue]) =>
    _notes[version]?[langue ?? langueCourante];

/// Les versions dont la table porte des notes.
///
/// Expose pour le verrou qui s'assure qu'aucune langue n'a ete oubliee : ici,
/// contrairement au reste des textes, une traduction manquante compile.
Iterable<String> get versionsAnnoncees => _notes.keys;

/// Y a-t-il quelque chose a annoncer, et quoi ?
///
/// `vue` est le numero deja annonce, conserve dans les reglages. L'egalite
/// suffit a se taire : on ne compare pas l'anciennete, car un retour en
/// arriere volontaire n'a pas a rouvrir la fenetre de la version qu'on quitte.
///
/// `premiereInstallation` fait taire l'annonce. Ce qui a change n'interesse
/// que celui qui connaissait l'etat d'avant, et le premier lancement a bien
/// assez a faire : c'est celui ou l'outil va chercher les noms et les images
/// du jeu, et une fenetre par-dessus cet ecran-la ferait deux choses a lire
/// en meme temps.
NotesVersion? aAnnoncer({
  required String version,
  required String vue,
  bool premiereInstallation = false,
  Langue? langue,
}) {
  if (version == vue || premiereInstallation) return null;
  final notes = notesDe(version, langue);
  return notes == null || notes.vide ? null : notes;
}

const _notes = <String, Map<Langue, NotesVersion>>{
  '1.0.8': {
    Langue.fr: NotesVersion(
      nouveautes: [
        'Macros : une touche déclenche une suite d\'actions — écrire, '
            'appuyer, cliquer, changer de fenêtre, attendre, répéter.',
        'Des variables et une boucle : la liste de vos personnages, un tour '
            'par nom, et {mes_persos} qui vaut celui du tour.',
        'Une touche d\'arrêt reprend la main sur une macro partie de travers, '
            'même pendant qu\'elle joue.',
      ],
      ajustements: [
        'Rien ne part vers autre chose que le jeu : une frappe ou un clic est '
            'refusé si une autre fenêtre est devant, et la macro s\'arrête en '
            'le disant.',
      ],
    ),
    Langue.en: NotesVersion(
      nouveautes: [
        'Macros: one key fires a sequence of actions — type, press, click, '
            'switch window, wait, repeat.',
        'Variables and a loop: your list of characters, one round per name, '
            'and {my_chars} standing for the one of the round.',
        'A stop key takes back control of a macro gone wrong, even while it '
            'is playing.',
      ],
      ajustements: [
        'Nothing leaves for anything but the game: a keystroke or a click is '
            'refused when another window is in front, and the macro stops '
            'saying so.',
      ],
    ),
    Langue.es: NotesVersion(
      nouveautes: [
        'Macros: una tecla lanza una secuencia de acciones — escribir, '
            'pulsar, hacer clic, cambiar de ventana, esperar, repetir.',
        'Variables y un bucle: tu lista de personajes, una vuelta por nombre, '
            'y {mis_personajes} que vale el del turno.',
        'Una tecla de parada recupera el control de una macro descarriada, '
            'incluso mientras se ejecuta.',
      ],
      ajustements: [
        'Nada sale hacia otra cosa que el juego: una pulsación o un clic se '
            'rechaza si otra ventana está delante, y la macro se detiene '
            'diciéndolo.',
      ],
    ),
    Langue.pt: NotesVersion(
      nouveautes: [
        'Macros: uma tecla lança uma sequência de ações — escrever, carregar, '
            'clicar, mudar de janela, esperar, repetir.',
        'Variáveis e um ciclo: a lista das suas personagens, uma volta por '
            'nome, e {as_minhas} que vale a da volta.',
        'Uma tecla de paragem retoma o controlo de uma macro que correu mal, '
            'mesmo enquanto ela decorre.',
      ],
      ajustements: [
        'Nada sai para outra coisa que não o jogo: uma tecla ou um clique é '
            'recusado se outra janela estiver à frente, e a macro para a '
            'dizê-lo.',
      ],
    ),
  },
  '1.0.7': {
    Langue.fr: NotesVersion(
      nouveautes: [
        'Organizer : une touche par personnage, et sa fenêtre passe devant. '
            'Un onglet de plus, indépendant du suivi.',
        'Les personnages se rangent en équipes qui se replient, chacun avec '
            'son portrait de classe : la composition se lit d\'un coup d\'œil.',
      ],
    ),
    Langue.en: NotesVersion(
      nouveautes: [
        'Organizer: one key per character, and its window comes to the '
            'front. One more tab, independent from the tracker.',
        'Characters are grouped into teams that fold away, each with its '
            'class portrait: the line-up reads at a glance.',
      ],
    ),
    Langue.es: NotesVersion(
      nouveautes: [
        'Organizer: una tecla por personaje y su ventana pasa al frente. '
            'Una pestaña más, independiente del seguimiento.',
        'Los personajes se agrupan en equipos que se pliegan, cada uno con '
            'su retrato de clase: la composición se lee de un vistazo.',
      ],
    ),
    Langue.pt: NotesVersion(
      nouveautes: [
        'Organizer: uma tecla por personagem e a sua janela vem para a '
            'frente. Mais um separador, independente do acompanhamento.',
        'As personagens agrupam-se em equipas que se recolhem, cada uma com '
            'o seu retrato de classe: a composição lê-se num relance.',
      ],
    ),
  },
  '1.0.6': {
    Langue.fr: NotesVersion(
      correctifs: [
        'Les objets reçus dans un échange étaient comptés comme du butin de '
            'la session. Ils ne le sont plus.',
        'Les achats en hôtel de vente non plus : ils coûtent des kamas, ils '
            'n\'en rapportent pas.',
      ],
    ),
    Langue.en: NotesVersion(
      correctifs: [
        'Items received in a trade were counted as session loot. They no '
            'longer are.',
        'Neither are auction house purchases: they cost kamas, they do not '
            'earn any.',
      ],
    ),
    Langue.es: NotesVersion(
      correctifs: [
        'Los objetos recibidos en un intercambio contaban como botín de la '
            'sesión. Ya no cuentan.',
        'Tampoco las compras en la casa de ventas: cuestan kamas, no los '
            'generan.',
      ],
    ),
    Langue.pt: NotesVersion(
      correctifs: [
        'Os objetos recebidos numa troca contavam como espólio da sessão. '
            'Deixam de contar.',
        'As compras na casa de vendas também não: custam kamas, não os '
            'rendem.',
      ],
    ),
  },
  '1.0.5': {
    Langue.fr: NotesVersion(
      nouveautes: [
        'Cette fenêtre : à chaque mise à jour, ce qui a changé en quelques '
            'lignes.',
      ],
      correctifs: [
        'Les combats perdus n\'apparaissaient nulle part. Ils figurent '
            'désormais dans la liste, avec les adversaires qui les ont gagnés.',
      ],
      ajustements: [
        'Une icône en tête de chaque ligne de la liste des combats : '
            'victoire ou défaite d\'un coup d\'œil.',
        'Le portrait de classe de chaque personnage dans le détail d\'un '
            'combat.',
        'Dans le détail d\'un combat, les vainqueurs sont toujours en haut — '
            'les monstres compris, quand ce sont eux qui l\'emportent.',
        'Le survol d\'un personnage non suivi précise que c\'est pour ce '
            'combat-là.',
      ],
    ),
    Langue.en: NotesVersion(
      nouveautes: [
        'This window: after every update, what changed in a few lines.',
      ],
      correctifs: [
        'Lost fights showed up nowhere at all. They are now in the list, '
            'along with the opponents that won them.',
      ],
      ajustements: [
        'An icon at the head of every row in the fight list: victory or '
            'defeat at a glance.',
        'Each character\'s class portrait in the fight details.',
        'In the fight details, the winners are always on top — monsters '
            'included, when they are the ones who won.',
        'Hovering an untracked character now says it was for that fight.',
      ],
    ),
    Langue.es: NotesVersion(
      nouveautes: [
        'Esta ventana: tras cada actualización, lo que ha cambiado en unas '
            'líneas.',
      ],
      correctifs: [
        'Los combates perdidos no aparecían en ninguna parte. Ahora están en '
            'la lista, junto con los adversarios que los ganaron.',
      ],
      ajustements: [
        'Un icono al principio de cada línea de la lista de combates: '
            'victoria o derrota de un vistazo.',
        'El retrato de clase de cada personaje en el detalle de un combate.',
        'En el detalle de un combate, los vencedores siempre arriba — '
            'monstruos incluidos, cuando son ellos los que ganan.',
        'Al pasar por encima de un personaje no seguido se precisa que es '
            'para ese combate.',
      ],
    ),
    Langue.pt: NotesVersion(
      nouveautes: [
        'Esta janela: a cada atualização, o que mudou em algumas linhas.',
      ],
      correctifs: [
        'Os combates perdidos não apareciam em parte alguma. Passam a constar '
            'na lista, com os adversários que os venceram.',
      ],
      ajustements: [
        'Um ícone à cabeça de cada linha da lista de combates: vitória ou '
            'derrota num relance.',
        'O retrato de classe de cada personagem no detalhe de um combate.',
        'No detalhe de um combate, os vencedores estão sempre em cima — '
            'monstros incluídos, quando são eles a vencer.',
        'Ao passar sobre um personagem não seguido, indica-se que é para '
            'aquele combate.',
      ],
    ),
  },
};
