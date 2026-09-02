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
