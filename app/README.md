# dofus-tracker — suivi de session (Flutter)

Surcouche translucide posee au-dessus du jeu. Reprise en Flutter de l'outil
ecrit en Python/Qt, dont les limites d'affichage se faisaient sentir : un
tableau soigne au pixel, des animations et une fenetre translucide demandent un
moteur de rendu, pas une feuille de style.

Comme la bibliotheque qui l'alimente, elle est **strictement passive** : elle
lit un flux d'evenements et n'interagit jamais avec le jeu.

## Ce qui est reste en Python

La capture du reseau, le reassemblage TCP et le decodage du protocole restent
dans [`dofus_stats`](../dofus_stats), validee par soixante-et-onze
verifications sur des captures reelles. Rien ne gagnerait a la reecrire : c'est
le travail le plus long du projet, et il est juste.

Cette application en est le consommateur. Le pont existait avant elle : la
bibliotheque diffuse deja ses evenements en JSON sur un WebSocket local,
precisement pour qu'un programme ecrit dans un autre langage puisse s'y
brancher.

```
dumpcap → dofus_stats (Python) → ws://127.0.0.1:8765 → cette application
```

Le processus Python est lance par l'application, pour n'avoir qu'une seule
chose a demarrer. S'il tourne deja — lance a la main pour rejouer une capture —
on se contente de s'y connecter.

## Lancement

```bash
flutter run -d windows          # developpement
flutter build windows --release --no-tree-shake-icons
```

Le binaire se trouve ensuite dans `build/windows/x64/runner/Release/`.

`--no-tree-shake-icons` n'est pas une precaution de principe. Par defaut, le
build ne garde de `MaterialIcons` que les glyphes qu'il croit utilises, et ce
sous-ensemble est **mis en cache** : ajouter une icone au code sans toucher
aux assets laisse en place la police de la fois d'avant. Le bouton repond au
clic, mais ne dessine rien — et aucun test ne le voit, puisque l'icone est
bien dans l'arbre des widgets. La police entiere pese un mega-octet et demi,
ce qui ne se remarque pas sur une application de bureau.

Prerequis : le SDK Flutter, et Visual Studio avec la charge de travail C++
(deja presente si `flutter doctor` valide « Visual Studio »).

### Mettre au point sans lancer le jeu

La bibliotheque sait rejouer une capture en respectant son tempo, et attendre
qu'un consommateur se presente :

```bash
cd ../dofus_stats
python -m dofus_stats.cli.stream -r captures/donjon01.pcapng \
    --hosts captures/hosts_donjon01.json \
    --mode websocket --attendre --tempo 60
```

`--attendre` retient la diffusion tant que personne n'ecoute — sans quoi un
rejeu se termine en une seconde, avant que l'application ait eu le temps de se
connecter. `--tempo` espace les evenements comme ils l'etaient, ce qui rend le
rejeu utilisable pour juger un affichage.

## Apparence

La palette est relevee au pixel sur le recapitulatif de fin de combat du jeu,
qui montre exactement les memes informations que cet outil :

| | |
|---|---|
| fond de fenetre | `#1b1d32` |
| carte d'une ligne | `#292c4d` |
| bandeau | `#3a3d58` |
| nom du personnage | `#ffd194` |
| nombres | `#ffffff` |
| kamas | `#ffc700` |
| en-tete de colonne | `#9895c2` |
| niveau | `#ffd336` sur un badge `#141626` |
| barre d'experience | `#787f27` a `#a8b23e` sur un creux `#141626` |

La police est **Lexend**, celle du jeu, extraite de son propre habillage par
`dofus_stats/extract_images.py` et embarquee dans `assets/fonts/`.

La ligne suit la composition du recapitulatif : portrait de classe, nom en or,
pastille des points a distribuer, niveau sur sa pastille puis sa barre,
experience suivie d'un `XP` discret, et le butin. Chaque ligne est une **carte**
posee sur le fond plutot qu'une rangee separee par un filet.

La colonne **BUTIN** porte les kamas en piece **et** la valeur estimee des
ressources ramassees. Une rangee d'icones la suivait : cinq objets au plus,
sans regroupement, elle ne montrait rien d'utilisable. C'est le chiffre qui
ouvre la fenetre de butin, laquelle le fait bien mieux.

La bande d'etat sous la barre de titre est **toujours presente** : « Hors
combat » quand il n'y a rien a dire, le chronometre, le tour et les challenges
quand il y a lieu. Elle n'apparaissait qu'a l'entree en combat, et poussait
alors tout le tableau d'un cran vers le bas — au moment precis ou l'on regarde
ailleurs, et ou une ligne qui bouge fait cliquer a cote.

Les images — icones d'objets, portraits, challenges — ne sont pas embarquees :
elles pesent un gigaoctet et demi et changent a chaque mise a jour du jeu. Elles
sont lues sur le disque, dans `dofus_stats/data/images/`, a la demande.

## Les points a distribuer

Une pastille doree parait a droite du nom des qu'un personnage a des points de
caracteristiques en attente, et disparait des qu'ils sont depenses. Elle porte
**le nombre** : savoir qu'il en reste ne dit pas s'il en reste un ou trente, et
c'est cela qui decide si l'on s'arrete pour les depenser. Elle vient
de la caracteristique 3, `points_stats_restants`, que le serveur envoie avec la
feuille du personnage.

Elle **bat comme un coeur** : deux pulsations rapprochees puis un repos qui
occupe la moitie du cycle. Un clignotement regulier se remarque autant et
fatigue davantage — ici l'oeil est appele, puis laisse tranquille. Elle ne
s'eteint jamais tout a fait : au repos elle reste lisible, elle cesse seulement
d'appeler.

Le battement a sa propre horloge. Le tableau, lui, ne se repeint qu'a l'arrivee
d'un evenement : accroche a lui, l'animation s'arreterait entre deux combats —
precisement quand on a le temps de la voir.

Sa place est reservee meme quand elle est absente, sinon les noms se
decaleraient a son apparition : un mouvement qui attire l'oeil pour la mauvaise
raison.

Un **reset** ne l'efface pas. Les points tiennent au personnage, pas a la
session : remettre les compteurs a zero ne les a pas depenses.

## Deux vues

L'application se coupe en deux, et le bouton aux quatre fleches de la barre de
titre passe de l'une a l'autre.

### La vue standard

Une application, pas une surcouche : un **rail de navigation** a gauche, un
en-tete de page, et des **pages**. Elle est opaque, redimensionnable, ses
colonnes sont larges et ses boutons s'atteignent sans viser.

```
┌──────────────┬──────────────────────────────────────────┐
│ DOFUS    [⤡] │  ‹  Butin de Kaska-nini              [✕] │
│ Session 12 ✎ │  Suivi › Butin de Kaska-nini             │
│ ⏱ 01:23:45   ├──────────────────────────────────────────┤
│              │                                          │
│ ▸ Suivi      │              (la page)                   │
│   Sessions   │                                          │
│   Réglages   │                                          │
│              │                                          │
│ [Pause] [↺]  │                                          │
│ ● Connecté   │                                          │
└──────────────┴──────────────────────────────────────────┘
```

**Plus une seule fenetre surgissante.** Une popup convient a une question
fermee — « supprimer ? », et c'est le seul endroit ou il en reste une. Elle
convient mal a tout le reste : elle n'a pas d'adresse, on ne peut pas revenir
en arriere dedans, elle empeche de regarder autre chose en attendant, et elle
obligeait a redimensionner la fenetre sous elle — d'ou le clignotement du
tableau a chaque fermeture.

La navigation est une **pile**, dans `navigation.dart`, volontairement separee
de l'affichage : c'est la partie ou l'on se trompe, et elle se verifie sans
monter le moindre widget. Le rail pose la racine, le contenu empile ce qu'on
ouvre depuis lui, et le fil d'Ariane dit ou l'on est.

| Racine | Ce qui s'empile dessus |
|---|---|
| Suivi | le butin d'un personnage, ses combats, un recapitulatif |
| Sessions | une session, puis un de ses combats |
| Reglages | — |

Une sous-page garde **l'onglet de sa racine** allume : le meme recapitulatif se
lit depuis deux endroits, et le rail ne doit pas sauter sous les yeux.
Recliquer sur l'onglet courant ramene a sa racine — c'est le geste qu'on fait
sans y penser quand on s'est enfonce dans un detail.

Le rail porte aussi ce qui ne depend d'aucune page : le nom de la session, le
chronometre, Pause, Reset, et **l'etat de la capture**. Il etait auparavant
dans un pied qu'une page pouvait remplacer.

`briques.dart` tient les mesures et les elements repetes — `Ecart`,
`TitreSection`, `Carte`, `Bouton`, `Etiquette`, `Chiffre`, `RienAMontrer`,
`ListeDefilante`, `Plaque`. Trois marges differentes pour trois panneaux,
c'est ainsi que naissent les interfaces qui « ne font pas serieux » sans qu'on
sache dire pourquoi.

### Le relief

Une interface entierement plate se lit comme un tableur : rien n'y dit ce qui
est pose sur quoi, ni ce qui repond au clic. `Relief`, dans `theme.dart`, tient
trois niveaux — pose, souleve, flottant — et pas un de plus : au-dela, on ne
distingue plus ce qui surplombe quoi, et tout parait flotter.

Sur un fond sombre, **une ombre seule ne suffit pas** : il n'y a pas assez
d'ecart entre le noir de l'ombre et le fond. Ce qui fait le relief, c'est la
paire — une ombre diffuse dessous, et une arete claire sur le bord du haut,
comme si la lumiere venait de la. S'y ajoute un degrade vertical de quatre
pour cent sur chaque carte : un degrade qu'on remarque est un degrade rate,
celui-ci ne se voit pas, il se sent.

Le mouvement complete le dessin. Une carte cliquable **se souleve d'un pixel**
au survol et son ombre s'ouvre ; le geste dit qu'elle repond avant meme le
clic, ce qu'aucune couleur ne dit aussi vite. Les listes sont posees dans une
`Plaque` en creux, plus sombre que le fond : sans creux, tout est au meme plan
et rien ne se detache.

Deux regles de Flutter valent d'etre notees, car elles ne se signalent qu'a la
peinture — donc loin de la ligne fautive :

- un rayon interdit une bordure aux **cotes de couleurs differentes** ;
- un rayon interdit une bordure **en cheveu** (`width: 0`).

L'arete claire est donc une bordure uniforme, et les liseres d'accent — l'or
d'une session courante, le bleu d'un personnage en combat — sont des barres
**posees par-dessus**, dans un `ClipRRect`, avec leur propre halo.

### La vue compacte

Elle se pose au-dessus du jeu et n'affiche que le tableau. C'est la seule qui
soit **translucide**, et c'est sa raison d'etre : laisser voir le terrain a
travers.

Rien n'y est cliquable et rien n'y survole. Une infobulle qui surgit par-dessus
un combat gene plus qu'elle ne renseigne, et un clic destine au jeu ne doit pas
ouvrir une fenetre. Restent les boutons de la barre — Pause, Reset — la bande
d'etat du combat et le pied avec ses cadences.

Elle perd les sessions et les reglages : on ne vient pas y regler quoi que ce
soit, et deux boutons de moins font deux occasions de moins de cliquer a cote
pendant un combat. A leur place, un **cadenas** :

| Cadenas | Effet |
|---|---|
| ouvert | la fenetre se saisit **n'importe ou** — sauf sur les boutons |
| ferme | la position est clouee, les boutons restent accessibles |

La zone de deplacement est posee **sous** le contenu ; les boutons, opaques au
clic, l'interceptent avant elle.

### Deux planchers, pas un

Les deux tailles minimales ne se confondent pas — `tailleMiniCompacte` et
`tailleMiniStandard` dans `config.dart`. La vue compacte tient dans une bande
etroite, c'est tout son interet ; la vue standard donne 208 pixels a son rail
environ 700 a son tableau et une trentaine a la plaque en creux, et sous
**980** pixels sa rangee deborde. Ce n'est pas un defaut
d'apparence mais une erreur de rendu, et deux cas la tiennent : chaque jeu de
mesures est monte a son propre plancher.

Le minimum de la fenetre suit la vue. En passant au compact, il descend
**avant** la taille : dans l'autre ordre, le systeme refuse de rapetissir la
fenetre autant qu'on le demande.

## Les deux opacites

Fond et texte se reglent separement : on doit pouvoir poser un fond a trente
pour cent sous un texte a quatre-vingt-quinze. Ils ne valent que pour la **vue
compacte** — la vue standard occupe sa propre fenetre et n'a rien a laisser
voir ; la rendre translucide ne ferait que la rendre moins lisible.

## Ce qui est compte

Une seule source par grandeur, pour ne rien compter deux fois. La logique est
portee telle quelle de la version Python, avec les pieges qu'elle avait appris
a eviter :

- **l'experience et les kamas** viennent des recapitulatifs de fin de combat et
  des succes, jamais des gains bruts qui les accompagnent ;
- **le butin arrive deux fois** — l'inventaire d'abord, le recapitulatif
  ensuite. Le suivi retient les entrees des huit dernieres secondes et chaque
  recapitulatif consomme celles qui lui correspondent, a l'unite ;
- **les challenges** suivent la liste des actifs, jamais les selections : on
  peut changer d'avis, et un donjon impose les siens ;
- **la casse d'un pseudo** est ignoree, et l'orthographe du serveur l'emporte.

```bash
flutter test
```

Cent-trente-neuf verifications : la comptabilite reprise une a une de la
version Python, les reglages, l'affichage, le cache, le cycle de vie des
sessions, la page des combats, la pastille des points, la forme du fichier
d'archive, le tri des interfaces, la suppression et sa
confirmation, la mise en page de la barre de titre, les deux jeux de
mesures a leur plancher, la pile de navigation et la coquille — et deux rendus
de reference.

La coquille se verifie a la **taille minimale** : un debordement de rangee y est
une erreur de rendu, pas un defaut d'apparence, et c'est ce cas qui a revele que
le plancher ne tenait compte ni du rail ni, plus tard, de la plaque.

Le battement est verifie comme un battement, pas comme une animation : on
compare l'opacite au repos, au sommet de la premiere pulsation, puis pendant le
silence. Un test qui se contenterait de constater que « ca bouge » passerait
tout aussi bien sur un clignotement.

Ce rendu n'est pas decoratif : il a revele un debordement de mise en page que
l'ecran ne montrait pas, la fenetre etant alors plus large que le cas teste.

```bash
flutter test --update-goldens   # apres un changement d'apparence assume
```

## Etat de la reprise

Ce qui fonctionne : la fenetre translucide sans bordure et toujours au premier
plan, le tableau complet avec portraits, niveaux, barres, experience, kamas et
butin, la bande de combat avec ses challenges et leur origine, le pied avec
l'etat de la liaison et les cadences, la reconnexion automatique.

Le **panneau de reglages** s'ouvre par le bouton ⚙ : personnages suivis,
opacites du fond et du texte, premier plan, interface de capture. La liste des
interfaces vient de la bibliotheque, qui sait ou vit `dumpcap`.

### L'interface de capture

Le menu ne propose que les vraies cartes **Ethernet et Wi-Fi**. Les adaptateurs
VPN, le Bluetooth et la boucle locale en sont retires : le jeu n'y passe pas, et
les proposer n'offrait que des facons de se tromper — c'est precisement ainsi
que l'outil s'etait retrouve a ecouter un TAP OpenVPN.

Ce qui est conserve dans les reglages est le **nom de peripherique**, pas le
numero : celui-ci se decale des qu'une carte apparait, et le choix d'hier peut
designer une autre carte aujourd'hui. Un reglage ancien, donne par numero, est
ramene silencieusement au nom correspondant — le choix est conserve, sa notation
change. Un reglage qu'on ne reconnait pas reste affiche tel quel plutot que de
disparaitre.

### Toutes les interfaces

Par defaut l'outil ecoute **toutes** les cartes physiques a la fois. Choisir la
bonne est une question a laquelle on n'a pas de raison de savoir repondre — le
jeu passe par l'Ethernet ou le Wi-Fi, et cela change quand on debranche un
cable.

Le menu proposait « Detection automatique » alors que le code passait `-i 8` en
dur : sur une machine ou la carte 8 etait un adaptateur VPN sans trafic,
l'outil restait muet indefiniment. Rien ne le disait, et le pied affichait
« En attente du jeu », le meme message que pour un jeu a l'arret.

Les deux situations se distinguent maintenant :

| Pastille | Etat | Ce qui se passe |
|---|---|---|
| verte | Connecte | les evenements arrivent |
| jaune | En attente du jeu | la capture tourne et repond, mais n'entend rien |
| rouge | Capture injoignable | la diffusion ne repond pas |
| rouge | Capture indisponible | Python ou Wireshark manquent |

L'infobulle du pied dit sur quoi on ecoute et quoi faire dans chaque cas.

**Chaque geste s'applique aussitot** — il n'y a ni « Valider » ni « Annuler ».
On regle en voyant le resultat, et fermer le panneau ne fait que le fermer.
Deux boutons pour confirmer ce qu'on vient de voir se produire n'ajoutaient
qu'une hesitation. Le revers : un geste malencontreux est ecrit aussi vite
qu'un geste voulu, et il n'y a rien pour revenir en arriere.

Chaque personnage suivi porte son **portrait de classe**, ou un « ? » quand
elle n'est pas connue — elle n'arrive qu'au passage sur une carte. L'infobulle
separe les deux raisons d'un « ? » : classe encore inconnue, ou portrait
introuvable faute d'extraction. Ce n'est pas le meme remede.

Le panneau s'affiche dans la meme fenetre, qui s'agrandit le temps du reglage.
Une fenetre a part demanderait a `window_manager` d'en ouvrir une seconde, avec
sa propre transparence et sa propre position a retenir — et l'on ne verrait
plus les opacites changer sous ses yeux.

La **page d'inventaire** s'ouvre par un clic sur les kamas d'une ligne : une
grille de cases a la maniere du jeu, les kamas en piece en premier, le total
sous la grille.

Le **resume d'une session** montre ses chiffres, ses personnages, puis le
tableau de ses combats — chacun avec ses challenges en pastilles, vertes ou
rouges selon l'issue, le logo du challenge servant de reperage. Un clic ouvre
le recapitulatif du combat.

Seuls les **combats** defilent. Faire defiler la page entiere emportait les
chiffres de la session et la liste des personnages hors de l'ecran des le
troisieme combat — or c'est justement a eux qu'on compare ce qu'on lit.

Il montrait auparavant trois listes qui redisaient la meme chose : les
personnages, les challenges detaches de leur combat, et un journal. Les deux
dernieres ont disparu ; seul le compte « CHALLENGES 3/4 » reste en haut, ou il
resume sans rien detacher.

La **page des combats** s'ouvre par un clic sur le nom d'un personnage : tous
les combats de la session, avec l'heure de **fin** pour reference — c'est ce
moment-la qu'on a en tete, pas celui de l'engagement. Les colonnes se trient
d'un clic, et recliquer inverse l'ordre : « ou ai-je fait le plus de kamas »,
« le combat le plus long ». Ouvrir un combat rend le recapitulatif tel qu'il
etait en jeu — tous les participants, suivis ou non, avec le niveau et la barre
de progression **de cet instant**, non recalcules avec l'etat courant.

Le tri des kamas compte la valeur du butin, pas seulement les pieces : le
combat le plus riche n'est pas toujours celui qui a rendu le plus de monnaie.

La **duree** d'un combat vient du serveur, pas d'un chronometre local. Celui-ci
affichait « 00:00:00 » pour tous les combats : la bibliotheque retient la fin de
combat une seconde, le temps que les noms des participants arrivent, et d'ici
la la sortie de combat avait deja arrete le compteur. La valeur annoncee est
en prime celle que le jeu affiche — phase de placement exclue.

## Qui apparait dans le tableau

Seuls les personnages **rencontres pendant la session**. Suivre huit
personnages et n'en jouer que quatre laissait quatre lignes a zero, qui ne
disaient rien et prenaient la place.

Une ligne apparait des que son personnage se manifeste — un combat, un succes,
une recolte, ou simplement le fait d'etre vu sur une carte. Les autres restent
suivis : leur ligne viendra d'elle-meme. **Reset** vide le tableau, la session
suivante repartant de zero.

Le tableau vide dit pourquoi il l'est : aucun personnage configure, ou aucun
d'eux n'a encore joue. Ce sont deux raisons differentes, et les confondre
laisserait chercher un reglage qui n'y est pour rien.

## Ce qui est conserve

Le suivi ecrit trois choses a cote de lui :

| Fichier | Contenu |
|---|---|
| `settings.json` | les reglages, editables a la main |
| `cache.json` | classes et prix, appris au fil des sessions |
| `sessions/session-<horodatage>.json` | une session complete |

### Un combat est un objet entier

C'est l'unite de la structure. Un combat porte tout ce qu'il faut pour etre
relu seul, sans sa session :

```json
{
  "fin": 1756661234.9, "duree": 92.4,
  "participants": [
    { "nom": "Kaska-yopette", "niveau": 60,
      "xp": 53652, "xp_total": 812340,
      "xp_seuil_bas": 800000, "xp_seuil_haut": 900000,
      "kamas": 255,
      "butin": { "2663": { "quantite": 2, "prix": 1567 } } }
  ],
  "challenges": [
    { "ts": 1756661230.1, "challenge_id": 20, "bonus": 60,
      "origine": "choisi", "reussi": true,
      "combattants": ["Kaska-yopette", "Kaska-nini"] }
  ]
}
```

Les participants **non suivis** y figurent aussi, et l'etat d'experience est
celui de cet instant : c'est ce qui permet de rendre le recapitulatif tel
qu'on l'a vu en jeu, barre de progression comprise, plutot que de le
recalculer avec l'etat courant.

Les challenges sont **rattaches a leur combat**, non ranges dans une liste a
part. Detaches, ils obligeaient a rapprocher deux horodatages de tete :
« l'Elitiste rate, c'etait lequel de ces combats ? ».

Une session, elle, n'est qu'un nom, des periodes d'ecoute, un bilan par
personnage et cette suite de combats. `test/forme_test.dart` fige ce format :
il echoue des qu'une clef disparait, c'est-a-dire des qu'une archive deja
ecrite deviendrait illisible.

### Qui a fait echouer un challenge

**Le flux ne le dit pas.** Verifie sur les huit captures : le message d'issue
(`kwl`) ne contient que l'identifiant du challenge et un drapeau de reussite,
et les quatre clients d'un groupe recoivent le meme message octet pour octet.

```
kwl  Kaska-yopette  [(1, 973)]            echec  — champ 2 absent
kwl  Kaska-nini     [(1, 973)]            le meme
kwl  Kaska-panda    [(1, 20), (2, 1)]     reussite
```

Le jeu designe le fautif en rejouant les actions du combat cote client : c'est
une deduction, pas une donnee. L'archive garde donc **qui combattait**, la
reponse la plus proche que le flux permette, et un champ `fautif` reste prevu
sans jamais etre ecrit.

### La duree est une somme, pas un ecart

Une session peut s'etaler sur quatre jours et une dizaine de lancements. Elle
retient donc ses **periodes d'ecoute**, et sa duree en est la somme :

```json
"periodes": [
  { "debut": 1756600000, "fin": 1756607200 },
  { "debut": 1756690000, "fin": 1756694400 }
]
```

Les nuits, les pauses et les fermetures de l'outil n'en font pas partie. L'ecart
entre la premiere et la derniere donnerait quatre jours, et toute cadence
calculee dessus serait fausse d'un ordre de grandeur.

Mettre en pause ferme la periode en cours ; reprendre en ouvre une neuve.
Quitter et basculer la ferment aussi.

### Cycle de vie

Chaque lancement ouvre sa session — jamais la derniere « en cours », qui
appartenait a l'execution precedente. Elle **n'existe qu'en memoire** jusqu'au
premier fait : lancer l'outil puis basculer ailleurs ne seme pas de fichier
vide.

Le marqueur `en_cours` dit laquelle l'outil alimente, et une seule a la fois.
Au demarrage, celles restees marquees par une fermeture brutale sont closes.

**Basculer** sur une session passee la rend courante et la **reprend
aussitot** : on y bascule pour continuer, et un second geste pour la remettre
en marche n'avait de raison pour personne. Une periode neuve s'ouvre, de sorte
que le temps deja passe dessus s'ajoute au lieu de repartir de zero. Les
personnages qui n'y sont plus suivis retrouvent leur ligne le temps du detour —
les cacher afficherait des totaux sans les lignes qui les composent.

« Pause » reste la pour qui veut consulter sans enregistrer.

**Reset** clot la session en cours — elle reste consultable — et en ouvre une
neuve, qui prend le numero suivant. Sans cette cloture, la session neuve se
reecrivait par-dessus l'ancienne, qui disparaissait.

### Nommer une session

« 31/08 a 21:04 » ne dit pas ce qu'on a fait ce soir-la, « Donjon Bouftou »
si. Le nom se change **dans la barre de titre** de l'outil, ou par le crayon
d'une ligne de la liste. Par defaut : « Session 7 », le numero etant un
increment — effacer une archive ne doit pas faire reapparaitre un numero deja
porte.

Dans la liste, le nom n'est pas lui-meme un bouton : la ligne entiere ouvre la
session, et deux gestes differents au meme endroit se marchent dessus.

### Supprimer une session

La corbeille ne supprime pas : elle **demande**. Les lignes sont serrees et le
crayon est juste a cote — un clic de trop effacerait une soiree entiere, sans
rien pour revenir en arriere.

La demande dit ce qu'on perd : le nom, la date, le nombre de combats,
l'experience et les kamas. « Etes-vous sur ? » ne renseigne personne ; ce qu'on
veut savoir a cet instant, c'est si c'est bien celle-la. « Annuler » est place
en premier, a gauche : le geste le plus proche de la main doit etre celui qui ne
detruit rien.

La session **en cours n'a pas de corbeille**. Son fichier serait recree a la
sauvegarde suivante, quelques secondes plus tard : une suppression qui se defait
toute seule vaut moins que de ne pas la proposer. **Reset** la clot d'abord, et
elle devient alors supprimable comme les autres.

L'archive est ecrite au fil de l'eau plutot qu'a la fermeture : une mise en
veille ou une coupure ne doit pas emporter la soiree.

Le **cache** est desormais tenu par cette application : la bibliotheque annonce
les classes qu'elle apprend (`CharacterInfo`), et les prix arrivent avec la
table du serveur. Au premier lancement, ce que savait la version Python est
repris, pour ne pas repartir aveugle.

## La fermeture

Cliquer sur la croix figeait la fenetre cinq secondes. Chronometre, chaque
geste de la fermeture tient sous les trois cents millisecondes — reglages 2 ms,
cache 5 ms, session 0 ms, capture 270 ms, `destroy` 0 ms. L'attente etait
**entierement** dans l'extinction du moteur qui suivait. Tout etant ecrit a ce
stade, la fermeture se termine donc par un `exit(0)`.

La premiere explication qui venait — la liaison WebSocket qui attend son
echange de fermeture — etait fausse : mesuree contre la capture en marche,
`sink.close()` prend **3 ms**.

L'ordre des gestes compte :

1. les horloges, d'abord. La sauvegarde periodique reecrit la session en la
   marquant « en cours » ; declenchee apres la cloture, elle la rouvrirait ;
2. les ecritures, une par une ;
3. la capture, **avant** de detruire la fenetre.

Ce dernier point corrigeait une fuite : l'outil se fermait en laissant son
processus Python et son `dumpcap` en vie. Ils gardaient le port 8765, et le
lancement suivant s'y raccrochait — donc a l'ancienne capture, sur l'ancienne
carte. `Process.kill()` n'y suffisait pas : il n'emporte que Python, et
`dumpcap`, son enfant, survivait. Sur Windows, `taskkill /T` emporte l'arbre.

## Deux pieges

`DragToMoveArea` intercepte le pointeur des sa descente : un bouton place
dessous ne recoit jamais son clic. La barre de titre ne l'enveloppe donc que
sur sa partie gauche, les boutons restant en dehors. Le symptome etait muet —
les boutons paraissaient inertes — et c'est ce qui a fait preferer des tests de
widgets aux clics simules a l'ecran.

Les croix, les fleches et les crayons etaient des **glyphes nus** : leur zone
sensible se limitait a l'encre, et il fallait viser. Ce qui repond au clic est
desormais la boite entiere, avec une taille minimale, et le geste s'arrete la
— `HitTestBehavior.opaque`, sans quoi il traverserait jusqu'a la zone de
deplacement posee derriere.

Un `Flexible` **lache** reserve sa part de l'espace libre et n'en rend pas le
surplus. Le nom de session y etant loge, les boutons flottaient a un endroit
qui dependait de sa longueur, au lieu de rester colles au bord droit. Le nom est
donc pose **par-dessus** une zone de deplacement qui occupe tout le reste : il
n'en prend que sa largeur, la bande continue de saisir la fenetre partout
ailleurs, et les boutons ne bougent plus. `test/barre_test.dart` compare les
deux cas, nom court et nom long.

Le corps d'un `testWidgets` tourne dans une horloge simulee : une lecture de
fichier n'y aboutit jamais, et le test se fige sans rien dire — pas d'erreur,
pas de trace, juste un depassement de delai plusieurs minutes plus tard. Tout
ce qui touche au disque, montage du panneau compris, passe donc par
`tester.runAsync`.

Et un aller-retour entre les deux horloges n'avance la chaine que **d'un
cran**. Une suppression en a demande huit : effacer le fichier, relire le
dossier, repeindre. Le test paraissait prouver que la suppression ne marchait
pas, alors que le fichier avait bien disparu au premier tour — seul l'affichage
etait en retard. Les cas attendent donc sur une **condition** (`jusqua`), jamais
sur un nombre de tours : celui-ci serait faux le jour ou la machine est plus
lente.

Les separateurs de milliers sont des espaces **insecables**. Une comparaison
ecrite avec une espace ordinaire ne trouve rien, et l'echec ne dit pas pourquoi.
Les tests passent donc par `formateNombre`, jamais par un litteral.
