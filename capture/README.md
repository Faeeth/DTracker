# dofus-stats — lecture passive du trafic Dofus 3 (Unity)

Version **1.0.0**

Bibliotheque de deserialisation du protocole reseau de Dofus 3.6.10.11. Elle
observe le trafic et rend des evenements de jeu typés : fins de combat, succes,
caracteristiques, recoltes, challenges, deroulement des tours.

**Strictement passive.** Elle ecoute l'interface reseau et ne fait rien d'autre :
aucun paquet emis, aucune modification du client, aucun proxy, aucune
automatisation.

## Ce que le protocole s'est revele etre

Le format historique de Dofus 2 (identifiant sur les bits de poids fort) n'existe
plus. Dofus 3 utilise :

```
[varint longueur][message protobuf][varint longueur][message protobuf]...
```

Chaque message porte un `google.protobuf.Any` dont le `type_url` vaut
`type.ankama.com/<code>`, ou `<code>` est un identifiant obfusque de trois
lettres. Le flux est **en clair** : pas de TLS.

Le wire format protobuf etant auto-descriptif, la structure de n'importe quel
message se decode sans posseder les `.proto` d'Ankama. Seuls les noms de champs
manquent, ce qui a impose de les etablir par confrontation avec le jeu.

## Installation

La bibliotheque n'a **aucune dependance Python**. Elle necessite Wireshark, pour
`dumpcap`. Sur le poste de developpement, la capture fonctionne **sans droits
administrateur**.

Les deux outils d'extraction hors ligne (`extract_data.py`, `extract_images.py`)
demandent en revanche `pip install UnityPy`. Rien de tout cela ne tourne pendant
une capture ; le paquet n'est jamais importe par `dofus_stats`.

## Utilisation depuis Python

```python
from dofus_stats import Reader, FightEnd, AchievementUnlocked

for event in Reader.from_pcap("session.pcapng", hosts="hosts.json").events():
    if isinstance(event, FightEnd):
        for p in event.participants:
            print(p.name, p.xp, p.kamas, [(s.item_id, s.quantity) for s in p.loot])
    elif isinstance(event, AchievementUnlocked):
        print(event.achievement_id, event.xp, event.kamas)
```

`Reader.from_live()` remplace `from_pcap` pour l'ecoute en direct ; tout le
reste est identique.

### Sur quelle interface ecouter

**Toutes, par defaut.** Choisir la bonne carte est une question a laquelle
l'appelant n'a pas de raison de savoir repondre : le jeu passe par l'Ethernet,
le Wi-Fi ou un VPN, et cela change quand on debranche un cable. Une carte mal
choisie ne se signale pas — l'ecoute reste simplement muette, ce qui ressemble
a une panne du jeu.

Windows n'a pas de pseudo-interface `any`, celle-la est propre a Linux. Mais
`dumpcap` accepte plusieurs `-i` dans un seul flux pcapng, chaque paquet
portant l'indice de sa carte, et le lecteur les demele deja. Sur Linux, la
vraie pseudo-interface est utilisee telle quelle.

```python
Reader.from_live()             # toutes les cartes physiques
Reader.from_live("5")          # une seule, par son numero
Reader.from_live("5,2")        # deux, pour restreindre
Reader.from_live(r"\Device\NPF_{7AE2...}")   # par son nom, stable
```

« Toutes » ne veut pas dire n'importe laquelle : seules les vraies cartes
**Ethernet et Wi-Fi**. Le jeu ne passe ni par un adaptateur VPN, ni par le
Bluetooth, ni par la boucle locale, et chacune couterait un dumpcap pour rien.

Le type que Windows declare ne suffit pas a faire le tri : un adaptateur TAP
d'OpenVPN se presente comme **filaire**, exactement comme une vraie carte
Ethernet. Sur la machine de developpement, sept cartes se ressemblent ainsi :

| Type | Nom | Description | |
|---|---|---|---|
| 0 | Ethernet | Realtek PCIe 2.5GbE Family Controller | gardee |
| 5 | Wi-Fi | MediaTek Wi-Fi 7 MT7925 Wireless LAN Card | gardee |
| 0 | Connexion au reseau local | TAP-Windows Adapter V9 for OpenVPN Connect | ecartee |
| 0 | OpenVPN Connect DCO Adapter | OpenVPN Data Channel Offload | ecartee |
| 4 | Connexion reseau Bluetooth | Bluetooth Device (Personal Area Network) | ecartee |

Le tri combine donc le type — filaire ou sans-fil, boucle locale exclue — et la
reconnaissance de ce que le nom ou la description designe comme virtuel. Il ne
regarde **pas** les adresses : un Wi-Fi debranche au demarrage doit rester
ecoutable, sans quoi brancher le cable en cours de partie rendrait l'outil
muet.

`detailed_interfaces()` rend la liste **entiere**, chaque carte sachant si elle
est physique. Le tri appartient a l'affichage, pas a la source, et
`all_interfaces(toutes=True)` le leve pour une machine dont on ne sait rien.

Le numero d'une interface **change** d'un demarrage a l'autre — une carte qui
apparait decale toutes les suivantes. Une interface graphique qui conserve un
choix doit donc retenir le nom de peripherique, que `--interfaces` rend a cote
du numero.

Ecouter plusieurs cartes est sans danger pour la comptabilite : un paquet vu
deux fois — pont, machine virtuelle — est un chevauchement complet pour le
reassembleur, qui l'ecarte. Le test `test_doublons_de_capture` fige cette
propriete, desormais portante.

Le filtre BPF fait le reste : une carte sans trafic de jeu ne coute rien.

## Utilisation depuis un autre langage

La bibliotheque diffuse ses evenements en JSON. Deux transports, choisis a
l'appel :

```bash
# NDJSON sur la sortie standard — le defaut, aucun port ouvert
python -m dofus_stats.cli.stream --live 8

# serveur WebSocket local — plusieurs consommateurs simultanes
python -m dofus_stats.cli.stream --live 8 --mode websocket --port 8765

# les deux a la fois
python -m dofus_stats.cli.stream --live 8 --mode both
```

Chaque ligne est un objet portant un champ `type` egal au nom de l'evenement :

```json
{"ts":1788099122.06,"source":"Kaska-sadi","offers":[[20,60],[8,85]],"type":"ChallengeOffer"}
{"ts":1788099133.09,"source":"Kaska-nini","challenge_id":20,"succeeded":true,"type":"ChallengeResult"}
```

Les champs vides sont omis : un prix inconnu ne doit pas se confondre avec un
prix nul. `--full` les conserve, pour un schema stable.

Un exemple de consommation depuis Go se trouve dans `examples/consumer.go`.

### Pourquoi NDJSON par defaut

Le jeu produit environ **3 a 4 evenements par seconde** avec quatre clients
actifs. La chaine complete, serialisation comprise, en traite **plus de 5 000
par seconde**. Le transport le plus simple suffit donc trois ordres de grandeur
au-dessus du besoin ; le WebSocket n'est utile que pour servir plusieurs
consommateurs ou une interface web.

## Evenements

| Evenement | Contenu |
|---|---|
| `FightStart` / `FightLeave` | entree et sortie de combat, groupe attaque |
| `FighterPlaced` / `FighterKicked` | placement et exclusion pendant la preparation |
| `TurnStart` / `TurnEnd` | numero de tour ; `requested` distingue le clic du temps ecoule |
| `SpellCast` | identifiant du sort et case ciblee |
| `FighterDamage` | montant, cible, element, erosion |
| `FighterDeath` / `FighterHealth` | morts et points de vie |
| `EffectApplied` | effet pose : cible, lanceur, identifiant, sort d'origine |
| `CharacteristicChange` | variation d'une caracteristique en combat |
| `FightEnd` | recapitulatif : experience, kamas et butin par participant |
| `ChallengeOffer` / `ChallengeSelected` / `ChallengeResult` | challenges et leur issue |
| `AchievementUnlocked` | succes valide, experience et kamas |
| `Characteristics` | feuille complete du personnage |
| `CharacterState` | experience totale, niveau, seuils, solde de kamas |
| `ItemGained` | mouvement d'inventaire, avec prix si connu |
| `PodsUpdate` | poids porte et capacite |
| `ExperienceGain` / `KamasUpdate` / `PriceTable` | faits bruts |

## Etat conserve

**La bibliotheque ne conserve rien entre deux lectures.** Certaines informations
n'arrivent qu'a des moments precis : la table des prix a la connexion ou a
l'ouverture d'une interface marchande, l'inventaire complet a l'ouverture de la
fenetre. Une capture qui ne les contient pas laissera les champs correspondants
a `None`.

Il en va de meme du nom et de la **classe** d'un personnage. Le nom vient de
`ilw` ou `kae`, la classe de `ilw` seul — donc d'un passage sur la carte. Une
session entierement passee en donjon ne verrait jamais la seconde.

A l'appelant de tenir son cache :

```python
source = Reader.from_pcap("session_avec_inventaire.pcapng")
for _ in source.events():
    pass
prix, types = source.known_prices(), source.known_item_types()
noms, classes = source.known_character_names(), source.known_character_breeds()

reader = Reader.from_pcap("recolte.pcapng", prices=prix, item_types=types,
                          character_names=noms, character_breeds=classes)
```

En ligne de commande : `--prices fichier.json` et `--item-types fichier.json`.

## Etendre le perimetre

Chaque information vit dans un extracteur isole :

```python
from dofus_stats import Extractor

class MonExtracteur(Extractor):
    codes = frozenset({"abc"})        # codes qui declenchent handle()

    def handle(self, obs, ctx):
        yield MonEvenement(obs.env.ts, obs.who, ...)
```

Puis `Reader.from_pcap(..., extractors=[...])`. Ni le pipeline reseau ni le code
appelant ne changent. Pour explorer un code non couvert, `Reader.messages()`
rend le flux brut, sur lequel `dofus_stats.protocol.wire.render` donne un arbre
lisible.

## Architecture

```
capture/     source de trames : fichier .pcapng ou dumpcap en direct
net/         dissection eth/ip/tcp, reassemblage par flux, identification des clients
protocol/    deframing varint, decodeur protobuf generique, enveloppe Ankama
extractors/  un extracteur par type d'information ; c'est ici qu'on etend
events.py    evenements publics, independants du protocole
serialize.py conversion JSON, contrat avec les consommateurs exterieurs
stream.py    transports NDJSON et WebSocket
reader.py    API : Reader.from_pcap / from_live -> events()
```

Le direct et le differe empruntent le meme chemin : `dumpcap` ecrit du pcapng
sur un tube, relu par le meme lecteur que pour un fichier. Le parsing s'itere
donc hors ligne, sans relancer le jeu.

## Libelles et images

Le protocole ne transporte que des identifiants. Les libelles et les icones
correspondants sont dans les fichiers du client et s'en extraient hors ligne,
en une commande, a relancer apres chaque mise a jour du jeu :

```bash
python extract_data.py          # -> data/labels/, data/icons/ et data/records/
python extract_images.py        # -> data/images/ : objets, sorts, monstres...
python extract_images.py --folder aa/StandaloneWindows64   # habillage et polices
```

La derniere ligne va chercher l'interface elle-meme : ses elements graphiques et
ses **polices**, ecrites telles quelles dans `data/fonts/`. Le jeu compose en
**Lexend** ; sa charte se releve sur les memes fichiers — panneau `#282820`,
contour `#080808`, emplacement d'inventaire `#484038`, accent `#d0f000`.

Les bundles Unity portent leur propre description de types : les
enregistrements se lisent donc avec leurs vrais noms de champs, sans rien
deviner. Un challenge sort tel quel :

```json
{"id": 20, "name": "Élémentaire", "iconId": 20, "categoryId": 3,
 "completionCriterion": "...", "incompatibleChallenges": [...]}
```

| Fichier | Contenu |
|---|---|
| `data/labels/<categorie>.json` | identifiant vers libelle, compact — ce dont un affichage a besoin |
| `data/records/<categorie>.json` | tous les champs de tous les enregistrements, libelle et description resolus |
| `data/images/<categorie>/<variante>/` | les images, plus un `index.json` qui relie `iconId` au fichier |
| `data/fonts/` | les polices du jeu, en `.ttf` utilisables tels quels |
| `data/labels/manifest.json` | ce qui a ete ecrit, et le verdict de chaque categorie |

Ordre de grandeur pour la version 3.6.10.11 : 204 bundles, 88 922 libelles
(2,4 Mo), 111 Mo d'enregistrements, 45 859 images (1,4 Go), une dizaine de
secondes pour les libelles et trois minutes pour les images.

Le nom d'un fichier image est l'identifiant **d'icone**, pas celui de l'objet :
l'objet 303 est « Bois de Frêne » mais son image est `item/2x/38017.png`,
`38017` etant son `iconId`. Plusieurs objets partagent une meme icone.

Quatre categories sont confrontees a des libelles connus a chaque extraction
(objets, sorts, succes, challenges) ; le manifeste porte le verdict. Les autres
sont ecrites telles quelles.

`extract_data.py` lit les descriptions de types avec **UnityPy**, seule
dependance du projet et cantonnee a ces deux outils : rien de tout cela ne
tourne pendant une capture. Sans UnityPy, `extract_data.py` retombe sur une
lecture des octets bruts, qui retrouve la plupart des categories mais confond
parfois un enregistrement avec trois entiers voisins ; `extract_images.py`, lui,
refuse de tourner.

## Verification

```bash
python tests/test_regression.py
```

Cent-soixante-dix-huit verifications sur une vingtaine de captures, chacune
reprenant une valeur confrontee a ce que le jeu affichait. Sur l'ensemble du
corpus : **aucune erreur de parsing, aucun trou dans le flux**. S'y ajoutent le
tri des interfaces — carte par carte, celles d'une vraie machine —, le rejet
des paquets vus deux fois et la duree annoncee par le serveur.

Les captures sont **versionnees avec le code**, dans `captures/`. Ce sont les
artefacts du projet : les codes de messages sont obfusques et changeront au
prochain correctif du jeu, et ces enregistrements sont la seule chose qui
permette de rejouer une scene et de refaire le raisonnement. Elles ne portent
que le port du jeu — voir `tools/reduis.py`.

Ce verrou n'est pas decoratif. Quatre correspondances se sont revelees fausses
en cours de route, chacune decouverte par un test que le joueur a provoque :

- le solde de kamas avait ete pris pour des points de succes ;
- seule la moitie du butin etait lue, le recapitulatif repetant le champ objet
  a l'interieur d'un groupe ;
- retrait et esquive de PA/PM etaient inverses, les quatre valant la meme chose
  sur les personnages observes ;
- l'echec d'un challenge se lit a l'absence d'un champ, le protobuf n'emettant
  pas les valeurs nulles.

La **duree du combat** a ete etablie de la meme facon. Le champ 4 de `jyg`
portait une valeur inexploitee ; confrontee sur douze captures au temps ecoule
entre l'engagement observe et l'annonce de la fin, elle lui est toujours
inferieure de quelques secondes a une demi-minute — l'ecart etant la phase de
placement, que le jeu ne compte pas.

| Capture | Champ 4 | Engagement → fin observe |
|---|---|---|
| boss01 | 492 716 ms | 520,5 s |
| donjon01 | 280 486 ms | 290,1 s |
| challenge01 | 9 458 ms | 15,0 s |

`FightEnd.duration` la rend en secondes. Elle vaut mieux qu'un chronometre tenu
par l'appelant : elle dit ce que le jeu dit, et l'evenement de fin etant emis
avec une seconde de retard — le temps que les noms arrivent — un chronometre
local a souvent deja ete arrete par la sortie de combat.

Ces cas figurent dans les tests pour qu'ils ne reviennent pas sans etre vus.

### D'ou vient un objet qui entre dans l'inventaire

Le serveur annonce de la meme facon un objet ramasse, un objet repris dans un
coffre, les runes d'un brisage, les recompenses d'un succes, le contenu d'une
pochette ouverte, un achat en hotel de vente et ce qu'un autre joueur vient de
donner : `iua` ou `ivj`, l'objet entre. **Rien dans ces messages ne dit d'ou il
vient**, et un seul de ces sept cas est un gain.

Ce qui les separe est ce qui precede. Sept provenances, etablies capture par
capture, chacune jouee en jeu pour l'occasion :

| Marqueur | Sens | Provenance | Delai observe |
|---|---|---|---|
| `kcr` | C→S | coffre, banque, depot dans un echange, reprise a la vente | 20 ms |
| `kbj` | C→S | brisage : les runes remplacent les objets brises | 25 ms |
| `mga` | C→S | recompenses d'un succes reclame | — |
| `iuu` | C→S | objet utilise : pochette ouverte, potion bue | 25 ms |
| `kbm` | C→S | achat en hotel de vente | 30 ms |
| `kfb` | S→C | depot du partenaire dans une fenetre d'echange | 12 s |
| — | | ramassage, recolte : tout le reste | |

Les six premieres sont des commandes du client, lues dans les deux secondes
qui precedent. La septieme fait exception et meritait son propre mecanisme :
dans un echange, **celui qui recoit n'envoie aucune commande** — c'est l'autre
qui a donne. Le serveur annonce chaque depot aux deux parties par `kfb`, et la
copie envoyee a celui qui ne depose pas porte un champ de plus. C'est elle qui
dit « voici ce que ton partenaire propose ». L'objet n'entrera que douze
secondes plus tard, a la validation : l'offre est donc retenue comme un etat,
consommee au rapprochement, et perimee au bout de cinq minutes.

Quatre autres pistes ont ete verifiees et se sont revelees inoffensives, ce qui
valait d'etre etabli plutot que suppose :

- le **coffre d'un havre-sac** a sa propre famille de messages — `itf`, `itv`,
  `iuy`, `iwa` — et n'emet ni `iua` ni `ivj` ;
- la **banque** emprunte la premiere famille pour retirer et la seconde pour
  deposer : deux mecanismes pour un meme geste ;
- l'inventaire d'un personnage **qui se connecte** arrive en un seul `ivx`, que
  l'extracteur d'inventaire ne lit pas ;
- un `iuy` de depot peut porter quatre cent cinquante-neuf unites sous la meme
  forme qu'un `iua`. Lire ce code par megarde ferait entrer une pile entiere
  d'un coup — le test le verrouille.

## Identifier un message

Trois outils, dans l'ordre ou ils servent. Aucun n'emet quoi que ce soit sur le
reseau.

```bash
python tools/enregistre.py captures/echange01 --secondes 120
python tools/chronologie.py captures/echange01 --de 15 --a 32
python tools/reduis.py captures/echange01.pcapng
```

`enregistre.py` ecrit une capture rejouable et la photo des connexions a cote.
Enregistrer plutot qu'ecouter au vol, parce qu'identifier un message demande de
relire la meme scene des dizaines de fois en changeant d'hypothese a chaque
passage — et qu'une action en jeu ne se rejoue jamais a l'identique. La photo
est prise au debut **et a la fin** : enregistrer une connexion de personnage,
c'est commencer sans client a photographier.

`chronologie.py` recense les codes, borne une fenetre de temps, ou ne garde que
les messages citant un identifiant donne. C'est lui qui a trouve `kfb` et
`kbm` : on joue la scene en sachant l'heure, on borne, et on lit la sequence
complete — commande, reponse, consequences. L'ordre est souvent toute
l'information.

`reduis.py` ne garde d'une capture que le port du jeu. Les enregistrements pris
a l'epoque de dumpcap portaient tout le trafic de la machine : sur `brisage01`,
cent-soixante-seize trames utiles sur trente-et-un mille, et cinquante
megaoctets de tout le reste — les sites visites ce soir-la compris.

## Nommer les flux

Le fichier `hosts.json` associe chaque connexion a un personnage. Il doit etre
produit **pendant** la capture : le port local ne survit pas a une reconnexion.

```powershell
$procs = @{}
Get-Process -Name Dofus | ForEach-Object { $procs[[string]$_.Id] = $_.MainWindowTitle }
Get-NetTCPConnection -State Established |
  Where-Object { $_.RemotePort -eq 5555 -and $procs.Keys -contains [string]$_.OwningProcess } |
  ForEach-Object { [PSCustomObject]@{ pid=$_.OwningProcess; title=$procs[[string]$_.OwningProcess]
                                      localAddr=$_.LocalAddress; localPort=$_.LocalPort
                                      remoteAddr=$_.RemoteAddress; remotePort=$_.RemotePort } } |
  ConvertTo-Json | Out-File captures/hosts.json -Encoding utf8
```

Sans ce fichier, les flux sont designes par leur port et les evenements restent
exploitables, mais anonymes.

## Limites connues

- **Les codes de messages changeront** au prochain correctif du jeu. Ils vivent
  dans `data/messages.json`, hors du code, et sont regenerables. Les structures,
  elles, devraient tenir.
- **Le flux ne transporte aucun libelle** : objets, sorts et succes n'y sont
  designes que par leur identifiant. Les libelles s'obtiennent hors ligne, une
  fois par mise a jour du jeu (voir « Libelles et images » plus haut) ; la
  bibliotheque elle-meme n'en depend pas.
- **L'erosion sur un coup mortel** echappe a la regle `degats x taux`, verifiee
  partout ailleurs. La valeur brute est rapportee sans correction.
- **Le champ `value` d'un effet** porte tantot une valeur, tantot un
  identifiant, selon un critere non elucide. Ne pas s'en servir sans verifier.
- **Le profil de recompense d'un challenge** (experience ou butin, reglable par
  personnage) ne circule pas : les clients d'un meme groupe recoivent des
  messages identiques.
- **Le sexe d'un personnage** n'est jamais apparu dans le flux : le protobuf
  n'emet pas les zeros, et tous les personnages observes semblent masculins.
  Les portraits de classe existent dans les deux versions ; a defaut, on prend
  la premiere.
- **Trois caracteristiques restent non identifiees** (`93`, la serie a 100, et le
  champ d'en-tete `2.4`), ainsi que l'element neutre, faute de sort a tester.
