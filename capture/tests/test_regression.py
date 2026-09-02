"""Verrou de non-regression sur les correspondances validees.

Chaque assertion reprend une valeur confrontee a ce que le jeu affichait au
moment de la capture. C'est le seul garde-fou serieux dont dispose ce projet :
les codes de messages sont obfusques et changeront au prochain correctif du
jeu, mais les captures, elles, restent une reference stable.

Plusieurs de ces cas ont ete decouverts a la suite d'une erreur : le butin dont
seule la moitie etait lue, retrait et esquive attribues a l'envers, l'echec de
challenge qui se lit a l'absence d'un champ. Ils sont ici pour que ces erreurs
ne reviennent pas sans etre vues.

    python tests/test_regression.py
"""
from __future__ import annotations

import json
import os
import sys

RACINE = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, RACINE)

from dofus_stats import (
    AchievementUnlocked,
    ItemConsumed,
    CharacterInfo,
    ChallengeResult,
    Characteristics,
    CharacterState,
    FightEnd,
    FightStart,
    FighterDamage,
    ItemGained,
    PodsUpdate,
    Reader,
    SpellCast,
    TurnEnd,
)

CAPTURES = os.path.join(RACINE, "captures")
resultats: list[tuple[bool, str]] = []


def verifie(condition: bool, libelle: str) -> None:
    resultats.append((bool(condition), libelle))


def capture(nom: str) -> str | None:
    """Le fichier d'une capture, quelle que soit son extension.

    dumpcap ecrivait du pcapng, `tools/enregistre.py` ecrit du pcap. Ne
    chercher que la premiere faisait sauter un cas sans rien dire — c'est
    arrive, et le compte de verifications ne bougeait pas d'un pouce.
    """
    for extension in (".pcapng", ".pcap"):
        chemin = os.path.join(CAPTURES, nom + extension)
        if os.path.exists(chemin):
            return chemin
    return None


def lire(nom: str, hosts: str, **kwargs):
    chemin = capture(nom)
    if chemin is None:
        return None
    return list(Reader.from_pcap(chemin, hosts=os.path.join(
        CAPTURES, hosts + ".json"), **kwargs).events())


def test_combat_deux_personnages() -> None:
    """Combat du 30/08 a 13h15, gains confirmes par le joueur."""
    evts = lire("combat01", "hosts_combat01")
    if evts is None:
        return
    fins = [e for e in evts if isinstance(e, FightEnd)]
    verifie(len(fins) == 1, "combat01 : une seule fin de combat")
    par_nom = {p.name: p for p in fins[0].participants}
    verifie(par_nom["Kaska-nini"].xp == 5717, "combat01 : 5717 xp pour Kaska-nini")
    verifie(par_nom["Kaska-nini"].kamas == 30, "combat01 : 30 kamas pour Kaska-nini")
    verifie(par_nom["Kaska-panda"].xp == 5806, "combat01 : 5806 xp pour Kaska-panda")
    verifie(par_nom["Kaska-panda"].kamas == 1, "combat01 : 1 kama pour Kaska-panda")
    verifie([s.item_id for s in par_nom["Kaska-nini"].loot] == [2663],
            "combat01 : Kaska-nini remporte le seul objet 2663")
    verifie(sorted(s.item_id for s in par_nom["Kaska-panda"].loot) == [288, 306, 309],
            "combat01 : Kaska-panda remporte trois objets distincts")


def test_butin_complet() -> None:
    """Le recapitulatif groupe le butin par source, et repete le champ objet.

    Ne lire que le premier objet de chaque groupe faisait perdre la moitie du
    butin sans que rien ne le signale.
    """
    evts = lire("combat4p", "hosts_combat4p")
    if evts is None:
        return
    fins = [e for e in evts if isinstance(e, FightEnd)]
    par_nom = {p.name: p for p in fins[0].participants}
    attendu = {"Kaska-nini": (4, 7), "Kaska-panda": (6, 8),
               "Kaska-sadi": (4, 6), "Kaska-yopette": (5, 7)}
    for nom, (types, unites) in attendu.items():
        lots = par_nom[nom].loot
        verifie(len(lots) == types, f"combat4p : {nom} recoit {types} types d'objets")
        verifie(sum(s.quantity for s in lots) == unites,
                f"combat4p : {nom} recoit {unites} unites")


def test_succes() -> None:
    """Quatre succes valides d'un coup, gains confirmes par le joueur."""
    evts = lire("succes01", "hosts_succes01")
    if evts is None:
        return
    succes = [e for e in evts if isinstance(e, AchievementUnlocked)]
    verifie(len(succes) == 4, "succes01 : quatre succes")
    verifie(sum(s.xp for s in succes) == 201257, "succes01 : 201 257 xp au total")
    verifie(sum(s.kamas for s in succes) == 24330, "succes01 : 24 330 kamas au total")
    verifie(sorted(s.achievement_id for s in succes) == [488, 772, 1052, 6149],
            "succes01 : identifiants des quatre succes")


def test_caracteristiques() -> None:
    """Feuille de Kaska-yopette, confrontee a sa page statistiques.

    Retrait et esquive de PA/PM ont d'abord ete attribues a l'envers : les
    quatre valent la meme chose sur ces personnages, seul un sort accordant
    +20 en esquive de PM a permis de trancher.
    """
    evts = lire("xp5min", "hosts_xp5min")
    if evts is None:
        return
    fiches = {e.character: e for e in evts if isinstance(e, Characteristics)}
    c = fiches.get("Kaska-yopette")
    if c is None:
        return
    attendu = {"force": 405, "intelligence": 0, "chance": 30, "agilite": 0,
               "sagesse": 28, "points_action": 7, "points_mouvement": 4,
               "portee": 1, "critique": 8, "invocations": 2, "prospection": 103,
               "initiative": 462, "energie": 9280, "energie_max": 10000,
               "resistance_terre_pct": 40, "erosion_pct": 10}
    for cle, valeur in attendu.items():
        verifie(c.get(cle) == valeur, f"caracteristiques : {cle} = {valeur}")
    verifie(c.vitality == 511, "caracteristiques : vitalite affichee de 511")
    verifie(c.pods == 3883, "caracteristiques : pods avec les 1000 de base")


def test_pods_et_kamas() -> None:
    """Pods et solde de kamas, confirmes en jeu."""
    evts = lire("pods01", "hosts_pods01")
    if evts is None:
        return
    pods = [e for e in evts if isinstance(e, PodsUpdate) and e.character == "Kaska-yopette"]
    verifie(pods and pods[-1].maximum == 3923, "pods01 : maximum de 3923 pour Kaska-yopette")
    etats = [e for e in evts if isinstance(e, CharacterState) and e.character == "Kaska-yopette"]
    verifie(etats and etats[-1].kamas == 152988, "pods01 : 152 988 kamas pour Kaska-yopette")


def test_degats_et_elements() -> None:
    """Degats, elements et erosion, confrontes au journal de combat.

    L'erosion vaut exactement `degats x taux`, sauf sur un coup mortel ou la
    valeur echappe a la regle et n'est donc pas verifiee ici.
    """
    evts = lire("erosion01", "hosts_erosion01")
    if evts is None:
        return
    coups = [e for e in evts if isinstance(e, FighterDamage)
             and e.character == "Kaska-nini"]
    verifie([c.amount for c in coups] == [67, 72, 83, 77, 77, 88, 46],
            "erosion01 : les sept montants de degats")
    verifie(all(c.element == "terre" for c in coups),
            "erosion01 : tous les coups sont de terre")
    verifie([c.erosion for c in coups[:6]] == [6, 7, 16, 15, 15, 26],
            "erosion01 : erosion des six coups non mortels")
    sorts = [e.spell_id for e in evts if isinstance(e, SpellCast)]
    verifie(13106 in sorts and 13123 in sorts,
            "erosion01 : Pression et Concentration identifies")


def test_fin_de_tour() -> None:
    """Le clic du joueur se distingue d'une fin de tour par temps ecoule."""
    evts = lire("phases01", "hosts_phases01")
    if evts is None:
        return
    fins = [e for e in evts if isinstance(e, TurnEnd) and e.character == "Kaska-nini"]
    par_nom = {}
    for f in fins:
        par_nom.setdefault(f.fighter_name, []).append(f.requested)
    verifie(any(par_nom.get("Kaska-panda", [])), "phases01 : Kaska-panda a clique")
    verifie(any(par_nom.get("Kaska-sadi", [])), "phases01 : Kaska-sadi a clique")
    verifie(any(par_nom.get("Kaska-yopette", [])), "phases01 : Kaska-yopette a clique")
    verifie(not any(par_nom.get("Kaska-nini", [])),
            "phases01 : Kaska-nini n'a jamais clique, ses tours expiraient")


def test_challenges() -> None:
    """L'echec se lit a l'absence du champ de statut, pas a une valeur nulle."""
    evts = lire("challenge01", "hosts_challenge01")
    if evts is not None:
        res = [e for e in evts if isinstance(e, ChallengeResult)]
        verifie(res and res[0].challenge_id == 20 and res[0].succeeded,
                "challenge01 : challenge 20 reussi")
    evts = lire("phases02", "hosts_phases02")
    if evts is None:
        return
    res = [e for e in evts if isinstance(e, ChallengeResult)
           and e.character == "Kaska-nini"]
    echecs = [r for r in res if not r.succeeded]
    verifie(any(r.challenge_id == 964 for r in echecs),
            "phases02 : challenge 964 echoue")


def test_succes_sans_kamas() -> None:
    """Succes du 30/08 a 21h32 sur Kaska-nini : 18 649 xp et aucun kamas.

    Un succes peut ne rien rapporter en kamas. Il faut alors lire zero, et non
    conclure que la lecture a echoue — la sequence ne porte tout simplement pas
    de message `lqn`.
    """
    evts = lire("succes_nini", "hosts_succes_nini")
    if evts is None:
        return
    succes = [e for e in evts if isinstance(e, AchievementUnlocked)]
    verifie(len(succes) == 1, "succes_nini : un seul succes")
    if not succes:
        return
    e = succes[0]
    verifie(e.achievement_id == 1046, "succes_nini : succes 1046")
    verifie(e.character == "Kaska-nini", "succes_nini : sur Kaska-nini")
    verifie(e.xp == 18649, "succes_nini : 18 649 xp")
    verifie(e.kamas == 0, "succes_nini : aucun kamas")


def test_classes() -> None:
    """La classe se lit dans `ilw`, au champ 1.4.7 de la description d'entite.

    Les huit personnages du donjon portent leur classe dans leur pseudo, ce qui
    donne une verification sans equivoque.
    """
    chemin = capture("donjon01")
    if not os.path.exists(chemin):
        return
    lecteur = Reader.from_pcap(chemin,
                               hosts=os.path.join(CAPTURES, "hosts_donjon01.json"))
    for _ in lecteur.events():
        pass
    noms = lecteur.known_character_names()
    classes = lecteur.known_character_breeds()
    par_nom = {noms[i]: c for i, c in classes.items() if i in noms}
    attendu = {"Kaska-Feca": 1, "Kaska-Osa": 2, "Kaska-Enu": 3,
               "Kaska-nini": 7, "Kaska-yopette": 8, "Kaska-sadi": 10,
               "Kaska-panda": 12, "Kaska-Ougi": 18}
    for nom, classe in attendu.items():
        verifie(par_nom.get(nom) == classe,
                f"donjon01 : {nom} de classe {classe}")

    # La meme chose doit sortir en evenements, pour un consommateur exterieur
    # qui n'a pas acces au contexte du lecteur.
    fiches = [e for e in lecteur_evenements("donjon01", "hosts_donjon01")
              if isinstance(e, CharacterInfo)]
    par_evenement = {f.name: f.breed for f in fiches}
    verifie(len(fiches) == 8, "donjon01 : une fiche par personnage, sans repetition")
    for nom, classe in attendu.items():
        verifie(par_evenement.get(nom) == classe,
                f"donjon01 : fiche de {nom} annoncee")


def lecteur_evenements(nom: str, hosts: str):
    """Rejoue une capture et rend ses evenements, ou rien si elle manque."""
    chemin = capture(nom)
    if not os.path.exists(chemin):
        return []
    return list(Reader.from_pcap(
        chemin, hosts=os.path.join(CAPTURES, hosts + ".json")).events())


def test_recolte() -> None:
    """Type d'objet et prix, resolus via le cache fourni par l'appelant."""
    source = lire("farm02", "hosts_now")
    if source is None:
        return
    lecteur = Reader.from_pcap(capture("farm02"),
                               hosts=os.path.join(CAPTURES, "hosts_now.json"))
    for _ in lecteur.events():
        pass
    evts = lire("recolte01", "hosts_recolte01",
                prices=lecteur.known_prices(), item_types=lecteur.known_item_types())
    if evts is None:
        return
    gains = [e for e in evts if isinstance(e, ItemGained) and e.item_id == 303]
    verifie(gains and gains[0].unit_price == 72,
            "recolte01 : objet 303 valorise a 72 kamas")


def test_echange_et_achat() -> None:
    """Ce qui change de mains n'est pas un gain.

    Capture du 02/09, faite pour l'occasion : un echange de Kaska-nini vers
    Kaska-yopette — treize objets et des kamas — puis, en hotel de vente, deux
    lots repris a la vente et trois achats de Casque de Wobot.

    Trois provenances distinctes, et rien de ramasse : la capture ne doit
    produire aucun `pickup`. C'est le verrou le plus severe possible ici, et
    il tient parce que la scene a ete jouee pour cela.

    Chacune s'etablit differemment. L'achat se lit a la commande qui le
    precede, `kbm`, comme le brisage ou le retrait de coffre. La reprise a la
    vente passe par `kcr`, deja connu. L'echange, lui, echappait a ce
    mecanisme : celui qui **recoit** n'envoie aucune commande, c'est l'autre
    qui a donne. Ce sont les `kfb` — le depot dans la fenetre, annonce aux
    deux parties — qui l'annoncent, douze secondes avant que l'objet n'entre.
    """
    evenements = lire("echange_hdv01", "hosts_echange_hdv01")
    if evenements is None:
        return
    gains = [e for e in evenements if isinstance(e, ItemGained)]
    verifie(len(gains) == 18, "echange_hdv01 : dix-huit mouvements")
    par_origine: dict[str, int] = {}
    for g in gains:
        par_origine[g.origin] = par_origine.get(g.origin, 0) + 1
    verifie(par_origine.get("pickup", 0) == 0,
            "echange_hdv01 : rien n'a ete ramasse")
    verifie(par_origine.get("trade") == 13,
            "echange_hdv01 : les treize objets de l'echange")
    verifie(par_origine.get("purchase") == 3,
            "echange_hdv01 : les trois achats")
    verifie(par_origine.get("transfer") == 2,
            "echange_hdv01 : les deux lots repris a la vente")

    # Les achats sont bien ceux du joueur : un lot de dix, puis deux unites.
    achats = [g for g in gains if g.origin == "purchase"]
    verifie(all(g.item_id == 14471 for g in achats),
            "echange_hdv01 : trois Casque de Wobot")
    verifie([g.quantity for g in achats] == [10, 1, 1],
            "echange_hdv01 : dix, puis un, puis un")


def test_coffre_havre_sac() -> None:
    """Le coffre d'un havre-sac ne passe pas par l'inventaire.

    Capture du 02/09. Il a sa propre famille de messages — `itf`, `itv`,
    `iuy`, `iwa` — et n'emet ni `iua` ni `ivj` : rien n'en sort, donc rien
    n'est a ecarter. Verifie ici pour que cela reste vrai, et parce que
    l'hypothese inverse etait la premiere venue a l'esprit.
    """
    evenements = lire("coffre_havre01", "hosts_coffre_havre01")
    if evenements is None:
        return
    verifie(not [e for e in evenements if isinstance(e, ItemGained)],
            "coffre_havre01 : aucun mouvement d'inventaire")


def test_banque_et_connexion() -> None:
    """Deux scenes qui auraient pu gonfler les totaux, et ne le font pas.

    **La banque.** Capture du 02/09 : deux Fragments d'anomalie repris, et
    quelques piles deposees. Le retrait suit le chemin deja documente —
    `kcr`, puis `itc`, puis `iua` sous un identifiant neuf — et ressort donc
    en `transfer`. Le depot passe soit par `kcr` a l'endroit, soit par `kdd`,
    et repond alors par `itv` et `iuy` : une famille de messages que
    l'inventaire ne lit pas, et qui ne peut donc rien compter.

    Le coffre d'un havre-sac emprunte cette seconde famille de bout en bout,
    la banque la premiere : deux mecanismes distincts pour un meme geste, ce
    qui justifiait de les verifier separement plutot que de supposer.

    **La connexion.** L'inventaire d'un personnage qui se connecte arrive en
    un seul `ivx`, que l'extracteur d'inventaire ne lit pas non plus. Rien
    n'en sort — ce qui importe, car lancer l'outil puis connecter ses
    personnages est l'ordre habituel.
    """
    evenements = lire("banque01", "hosts_banque01")
    if evenements is not None:
        gains = [e for e in evenements if isinstance(e, ItemGained)]
        verifie(len(gains) == 1, "banque01 : un seul mouvement")
        verifie(all(g.origin == "transfer" for g in gains),
                "banque01 : un retrait de banque n'est pas un gain")
        verifie(gains and gains[0].quantity == 2,
                "banque01 : les deux unites reprises")

    evenements = lire("connexion01", "hosts_connexion01")
    if evenements is not None:
        verifie(not [e for e in evenements if isinstance(e, ItemGained)],
                "connexion01 : se connecter ne rapporte rien")


def test_integrite_du_decodage() -> None:
    """Aucune capture ne doit produire d'erreur de parsing ni de trou."""
    for nom, hosts in [("farm02", "hosts_now"), ("combat4p", "hosts_combat4p"),
                       ("phases02", "hosts_phases02"), ("erosion01", "hosts_erosion01")]:
        chemin = capture(nom)
        if not os.path.exists(chemin):
            continue
        r = Reader.from_pcap(chemin, hosts=os.path.join(CAPTURES, hosts + ".json"))
        for _ in r.events():
            pass
        s = r.session.stats
        verifie(s.parse_errors == 0, f"{nom} : aucune erreur de parsing")
        verifie(s.gaps == 0, f"{nom} : aucun trou dans le flux")


def test_interfaces() -> None:
    """Le choix de l'interface d'ecoute.

    Une carte mal choisie ne se signale pas : l'outil reste muet, ce qui
    ressemble a une panne du jeu ou de la capture. Le defaut est donc de les
    ecouter toutes — dumpcap accepte plusieurs `-i` dans un seul flux pcapng,
    et le lecteur sait deja demeler les cartes par l'indice que porte chaque
    paquet.

    « Toutes » ne veut pas dire n'importe laquelle : seules les vraies cartes
    Ethernet et Wi-Fi. Le jeu ne passe ni par un adaptateur VPN, ni par le
    Bluetooth, ni par la boucle locale.
    """
    from dofus_stats.capture.live_source import (LiveSource, all_interfaces,
                                                 detailed_interfaces,
                                                 est_physique)

    # Un choix explicite est respecte tel quel, numero ou nom de peripherique.
    verifie(LiveSource("5").interfaces() == ["5"], "interface : choix respecte")
    verifie(LiveSource("5,2").interfaces() == ["5", "2"],
            "interface : liste separee par des virgules")

    # Toutes les facons de dire « toutes » mènent au meme endroit.
    defaut = LiveSource().interfaces()
    for mot in ("", "any", "all", "toutes", "auto"):
        verifie(LiveSource(mot).interfaces() == defaut,
                f"interface : « {mot or 'vide'} » vaut toutes les interfaces")

    # Le tri ne retient que les vraies cartes. Le type ne suffit pas : Windows
    # presente un adaptateur VPN comme filaire, exactement comme une Ethernet.
    cas = [
        ({"libelle": "Ethernet", "description": "Realtek PCIe 2.5GbE Family "
          "Controller", "type": 0, "loopback": False}, True),
        ({"libelle": "Wi-Fi", "description": "MediaTek Wi-Fi 7 MT7925 "
          "Wireless LAN Card", "type": 5, "loopback": False}, True),
        ({"libelle": "Connexion au reseau local", "description":
          "TAP-Windows Adapter V9 for OpenVPN Connect", "type": 0,
          "loopback": False}, False),
        ({"libelle": "OpenVPN Connect DCO Adapter", "description":
          "OpenVPN Data Channel Offload", "type": 0, "loopback": False},
         False),
        ({"libelle": "Connexion reseau Bluetooth", "description":
          "Bluetooth Device (Personal Area Network)", "type": 4,
          "loopback": False}, False),
        ({"libelle": "Adapter for loopback traffic capture",
          "description": "", "type": 0, "loopback": True}, False),
        ({"libelle": "vEthernet (Default Switch)", "description":
          "Hyper-V Virtual Ethernet Adapter", "type": 0, "loopback": False},
         False),
        ({"libelle": "Ethernet 2", "description": "VMware Virtual Ethernet "
          "Adapter for VMnet1", "type": 0, "loopback": False}, False),
    ]
    for interface, attendu in cas:
        obtenu = est_physique(interface)
        verifie(obtenu == attendu,
                f"interface : « {interface['libelle']} » "
                f"{'gardee' if attendu else 'ecartee'}")

    detaillees = detailed_interfaces()
    if not detaillees:
        # Sans dumpcap, on ne peut rien affirmer de plus, mais le defaut doit
        # rester utilisable plutot que vide.
        verifie(bool(defaut), "interface : un defaut meme sans dumpcap")
        return

    verifie(all(i.get("device") for i in detaillees),
            "interface : chacune a son nom de peripherique")
    verifie(any(i["adresses"] for i in detaillees),
            "interface : les adresses sont rendues")
    verifie(all("physique" in i for i in detaillees),
            "interface : le verdict accompagne chaque carte")
    # La liste rendue est complete : c'est a l'affichage de trier, pas a la
    # source de decider ce qu'on a le droit de voir.
    verifie(len(detaillees) >= len(defaut),
            "interface : la liste rendue reste complete")
    verifie(len(defaut) == len(all_interfaces()),
            "interface : le defaut suit le tri")
    verifie(len(all_interfaces(toutes=True)) >= len(defaut),
            "interface : le tri peut etre leve")



def test_doublons_de_capture() -> None:
    """Un paquet vu deux fois ne compte qu'une.

    C'est ce qui rend l'ecoute simultanee de toutes les interfaces sans
    danger : deux cartes peuvent voir le meme paquet — pont, machine
    virtuelle, carte en double — et le compter deux fois doublerait tout ce
    qui en decoule, experience et butin compris.

    Le reassembleur travaille sur les numeros de sequence : un segment deja
    consomme est un chevauchement complet, et il est ecarte. Ce test le fige,
    car cette propriete est desormais portante.
    """
    from dofus_stats.net.dissect import FlowKey, Segment
    from dofus_stats.net.reassembler import TCPReassembler

    flux = FlowKey("54.75.207.24", 5555, "192.168.1.111", 51472)
    r = TCPReassembler()

    premier = Segment(1.0, flux, 1000, b"abcdef", 0)
    verifie(b"".join(d.data for d in r.feed(premier)) == b"abcdef",
            "doublons : le premier passage rend les octets")
    # Le meme paquet, capte par une seconde carte, un cheveu plus tard.
    verifie(r.feed(Segment(1.001, flux, 1000, b"abcdef", 0)) == [],
            "doublons : le second passage ne rend rien")

    suite = Segment(1.1, flux, 1006, b"ghij", 0)
    verifie(b"".join(d.data for d in r.feed(suite)) == b"ghij",
            "doublons : la suite passe normalement")
    verifie(r.feed(Segment(1.101, flux, 1006, b"ghij", 0)) == [],
            "doublons : et son doublon est ecarte")

    # Chevauchement partiel : seule la portion neuve sort.
    chevauche = Segment(1.2, flux, 1008, b"ijklmn", 0)
    verifie(b"".join(d.data for d in r.feed(chevauche)) == b"klmn",
            "doublons : un chevauchement partiel ne rend que le neuf")

    etat = next(iter(r.states.values()))
    verifie(etat.gaps == 0, "doublons : aucun trou signale a tort")



def test_duree_de_combat() -> None:
    """La duree du combat, annoncee par le serveur.

    Le champ 4 de `jyg` la porte, en millisecondes. Etabli en le confrontant,
    sur douze captures, au temps ecoule entre l'engagement observe et
    l'annonce de la fin : il lui est toujours inferieur de quelques secondes a
    une demi-minute, l'ecart etant la phase de placement, que le jeu ne compte
    pas.

    Elle vaut mieux qu'un chronometre tenu par l'appelant. L'evenement de fin
    est emis avec une seconde de retard, le temps que les noms arrivent : a cet
    instant, un chronometre local a souvent deja ete arrete par la sortie de
    combat, et rendait zero. C'est precisement le defaut qui a fait afficher
    « 00:00:00 » a tous les combats du suivi.
    """
    for nom, hosts, attendues in (
        ("donjon01", "hosts_donjon01", [134.362, 107.849, 280.486]),
        ("boss01", "hosts_boss01", [492.716]),
        ("challenge01", "hosts_challenge01", [9.458]),
    ):
        evenements = lire(nom, hosts)
        if evenements is None:
            continue
        fins = [e for e in evenements if isinstance(e, FightEnd)]
        verifie([e.duration for e in fins] == attendues,
                f"{nom} : durees {attendues}")
        # Le placement n'est pas compte : la duree annoncee reste en deca du
        # temps ecoule entre l'engagement et la fin.
        debuts = [e.ts for e in evenements if isinstance(e, FightStart)]
        for fin in fins:
            avant = [d for d in debuts if d < fin.ts]
            if not avant or fin.duration is None:
                continue
            verifie(fin.duration <= fin.ts - max(avant) + 0.5,
                    f"{nom} : la duree exclut le placement")



def test_adversaires() -> None:
    """Qui etait en face : le recapitulatif ne le dit pas, le placement si.

    `jyg` designe les perdants par un identifiant de combattant negatif, sans
    nom ni espece. `kae`, emis pendant le placement, donne la correspondance
    identifiant -> (monstre, grade).

    Deux pieges, tous deux verifies ici. Les identifiants sont propres a
    **chaque client** : quatre personnages qui farment chacun leur groupe
    emettent quatre `-1` differents dans le meme flux. Et le serveur annonce
    les combattants **avant** de dire au client qu'il entre en combat : vider
    la table a l'entree effacait tout ce qui venait d'arriver.
    """
    attendus = {
        # capture, hosts : le premier combat, (monstre, grade) trie
        ("combat4p", "hosts_combat4p"):
            # un Tournesol Sauvage, trois Roses Demoniaques, un Epouvanteur
            [(48, 2), (78, 1), (78, 2), (78, 2), (4820, 3)],
        # un Pichon Orange et un Pichon Bleu
        ("xp5min", "hosts_xp5min"): [(920, 4), (921, 4)],
        # un Pissenlit Diabolique
        ("esquive01", "hosts_esquive01"): [(79, 3)],
    }
    for (nom, hosts), premier in attendus.items():
        evenements = lire(nom, hosts)
        if evenements is None:
            continue
        fins = [e for e in evenements if isinstance(e, FightEnd)]
        verifie(bool(fins), f"{nom} : au moins un combat")
        if not fins:
            continue
        vus = [(o.monster_id, o.grade) for o in fins[0].opponents]
        verifie(sorted(vus) == sorted(premier),
                f"{nom} : adversaires du premier combat")
        # Les combattants d'en face restent hors des participants : ils n'ont
        # ni experience ni butin, et les compter fausserait tous les totaux.
        verifie(all(p.character_id and p.character_id > 0
                    for p in fins[0].participants),
                f"{nom} : ceux d'en face ne sont pas des participants")
        # Et ils n'ont pas gagne, sur ces trois captures qui sont autant de
        # victoires. C'est le verrou du sens : on ne les retient plus a
        # l'absence d'issue mais au signe de leur identifiant, et il fallait
        # s'assurer qu'aucun ne se mette a paraitre vainqueur au passage.
        verifie(not any(o.won for o in fins[0].opponents),
                f"{nom} : un combat gagne n'a pas d'adversaire vainqueur")

    # Un combat engage avant l'ecoute n'a pas ete place devant nous : on
    # compte alors les adversaires sans savoir les nommer, et on le dit
    # plutot que d'inventer.
    evenements = lire("donjon01", "hosts_donjon01")
    if evenements is not None:
        fins = [e for e in evenements if isinstance(e, FightEnd)]
        inconnus = [o for e in fins for o in e.opponents if o.monster_id is None]
        verifie(len(inconnus) == 24,
                "donjon01 : adversaires comptes mais non nommes")


def test_consommables() -> None:
    """Ouvrir un consommable remplit l'inventaire sans rien gagner.

    Capture du 01/09, faite pour l'occasion : quatre pochettes ouvertes sur
    Kaska-nini, dont trois dans la fenetre de capture. Le contenu entre par le meme `ivj` qu'un ramassage ; ce qui
    l'en separe est la commande `iuu` que le client vient d'emettre.

    Sans cela, tout ce qui sort d'une pochette comptait comme butin de la
    session — et une pochette rend d'un coup ce que le farm met des minutes a
    donner.
    """
    evenements = lire("consommable01", "hosts_consommable01")
    if evenements is None:
        return
    gains = [e for e in evenements if isinstance(e, ItemGained)]
    verifie(len(gains) == 4, "consommable01 : quatre mouvements d'objet")
    verifie(not any(e.gained for e in gains),
            "consommable01 : aucun n'est un gain")
    # Le contenu obtenu et la pochette qui decroit portent le meme message :
    # ce qui les separe est l'identifiant que le client vient de nommer.
    verifie(sorted(e.origin for e in gains)
            == ["consumed", "use", "use", "use"],
            "consommable01 : le contenu, et la pochette qui decroit")

    # L'objet utilise est annonce a part, pour que l'appelant qui compte le
    # contenu puisse defalquer la pochette elle-meme.
    ouverts = [e for e in evenements if isinstance(e, ItemConsumed)]
    verifie(len(ouverts) == 3, "consommable01 : trois ouvertures")
    verifie([e.item_uid for e in ouverts]
            == [255772234, 255904550, 255904550],
            "consommable01 : chacune nomme l'objet ouvert")
    # Jamais vues entrer — elles sont d'avant l'ecoute : rien a defalquer, et
    # c'est juste, ce qui n'a pas ete compte n'a pas a etre repris.
    verifie(all(e.item_id is None for e in ouverts),
            "consommable01 : pochettes inconnues, rien a defalquer")


def test_combat_perdu() -> None:
    """Un combat qui ne rapporte rien reste un combat.

    Capture `erosion01` : un duel entre deux personnages, donc sans
    experience, sans kamas et sans butin. Le recapitulatif est bien la, et
    porte l'issue chez le vainqueur seul.

    Il ne ressortait pas. On reconnaissait un participant a son experience
    gagnee, et le wire format protobuf n'emet pas les valeurs nulles : aucune
    entree ne portait ce champ, aucun participant n'etait retenu, et le
    recapitulatif tout entier tombait. Tout combat perdu disparaissait ainsi
    de la liste — celui-ci le montre parce qu'un duel ne rapporte rien a
    personne, mais un simple echec en face de monstres donnait la meme chose.

    On reconnait desormais un personnage a son identifiant, qui est toujours
    la et que son signe distingue de celui d'un monstre.
    """
    evenements = lire("erosion01", "hosts_erosion01")
    if evenements is None:
        return
    fins = [e for e in evenements if isinstance(e, FightEnd)]
    verifie(len(fins) == 1, "erosion01 : le duel ressort")
    if not fins:
        return
    par_nom = {p.name: p for p in fins[0].participants}
    verifie(set(par_nom) == {"Kaska-nini", "Kaska-yopette"},
            "erosion01 : les deux duellistes sont la")
    # L'issue est ce qui les separe : deux chez le vainqueur, rien chez
    # l'autre. C'est de quoi les ranger sous « gagnants » et « perdants ».
    verifie([p.outcome for p in fins[0].participants].count(2) == 1,
            "erosion01 : un seul vainqueur")
    verifie(sum(1 for p in fins[0].participants if p.outcome is None) == 1,
            "erosion01 : un seul perdant")
    verifie(fins[0].total_xp == 0 and fins[0].total_kamas == 0,
            "erosion01 : un duel ne rapporte rien")
    # Et le perdant garde son niveau : c'est ce qui remplit sa ligne, faute
    # d'experience a y mettre.
    verifie(all(p.level for p in fins[0].participants),
            "erosion01 : les niveaux sont connus")


def test_transferts() -> None:
    """Coffre, brisage, succes : l'objet entre sans etre gagne.

    Capture du 01/09, faite pour l'occasion : deux objets brises, puis quatre
    clefs sorties d'un coffre, remises, ressorties. Le serveur annonce les six
    entrees par le meme `iua` qu'un ramassage — rien dans le message ne dit
    d'ou l'objet vient. Ce qui les separe est la commande qui precede, emise
    par le client : `kcr` pour un deplacement, `kbj` pour un brisage.

    Sans cela, trois runes et huit clefs comptaient comme butin de la session.
    """
    evenements = lire("brisage01", "hosts_brisage01")
    if evenements is None:
        return
    gains = [e for e in evenements if isinstance(e, ItemGained)]
    verifie(len(gains) == 4, "brisage01 : quatre mouvements d'objet")
    verifie(all(e.origin == "transfer" for e in gains),
            "brisage01 : aucun n'est un gain")
    verifie(not any(e.gained for e in gains),
            "brisage01 : `gained` le dit aussi")
    # Rune Vi et Rune Fui pour le brisage, Clef du Donjon des Scarafeuilles
    # pour le coffre — reprise deux fois.
    verifie([(e.item_id, e.quantity) for e in gains]
            == [(1523, 2), (11637, 1), (8139, 4), (8139, 4)],
            "brisage01 : les runes puis les clefs")

    # Les recompenses d'un succes arrivent **avant** l'annonce du succes :
    # `mga`, la demande du joueur, puis les objets, et seulement ensuite
    # `mfs`. Rien ne permet de les rattacher apres coup — c'est la commande
    # qui precede qui renseigne.
    #
    # Capture du 01/09 : deux succes reclames, comptage desactive dans
    # l'outil, et le butin montait quand meme.
    evenements = lire("succes_toggle", "succes_toggle")
    if evenements is not None:
        gains = [e for e in evenements if isinstance(e, ItemGained)]
        verifie(gains and all(e.origin == "achievement" for e in gains),
                "succes_toggle : les recompenses ne sont pas des ramassages")
        verifie(len([e for e in evenements
                     if isinstance(e, AchievementUnlocked)]) == 2,
                "succes_toggle : les deux succes sont vus")

    # Et le jeu ordinaire n'est pas touche : aucune de ces commandes n'y
    # apparait, ni en combat, ni en recolte.
    for nom, hosts in (("recolte01", "hosts_recolte01"),
                       ("combat4p", "hosts_combat4p")):
        evenements = lire(nom, hosts)
        if evenements is None:
            continue
        gains = [e for e in evenements if isinstance(e, ItemGained)]
        verifie(gains and all(e.gained for e in gains),
                f"{nom} : tout ce qui entre est un gain")


def test_liste_des_interfaces() -> None:
    """La liste que lit une interface graphique.

    Deux ecueils, tous deux rencontres. Sous Windows, `dumpcap` ecrit les noms
    conviviaux dans la page de codes locale : « Connexion reseau Bluetooth »
    porte un `0xe9` cp1252. Le lire en UTF-8 rendait un caractere de
    remplacement ; le reecrire tel quel donnait une sortie qu'aucun decodeur
    UTF-8 n'acceptait. L'appelant obtenait alors une liste **vide**, sans rien
    pour le lui dire, et l'interface choisie s'affichait « introuvable ».

    La sortie est donc echappee en ASCII pur, et le verdict `physique` y
    figure : savoir qu'un « OpenVPN Connect DCO Adapter » se presente comme
    une carte filaire n'est pas le travail d'une interface graphique.
    """
    import subprocess

    res = subprocess.run(
        [sys.executable, "-m", "dofus_stats.cli.stream", "--interfaces"],
        capture_output=True, cwd=RACINE)
    verifie(res.returncode == 0, "interfaces : la commande aboutit")

    brut = res.stdout
    verifie(brut.strip().startswith(b"["), "interfaces : du JSON en sortie")
    # Le point precis qui cassait tout : la sortie doit se decoder.
    lisible = True
    try:
        texte = brut.decode("utf-8")
    except UnicodeDecodeError:
        lisible = False
        texte = ""
    verifie(lisible, "interfaces : la sortie se decode en UTF-8")
    if not lisible:
        return
    # ASCII pur : le contrat tient quel que soit le decodeur de l'appelant.
    verifie(all(o < 128 for o in brut),
            "interfaces : sortie en ASCII, accents echappes")

    liste = json.loads(texte)
    verifie(isinstance(liste, list), "interfaces : une liste")
    if not liste:
        return
    for cle in ("numero", "libelle", "device", "physique"):
        verifie(all(cle in i for i in liste), f"interfaces : champ {cle}")
    # Un accent decode se lit comme un accent, pas comme un losange.
    verifie("\ufffd" not in texte,
            "interfaces : aucun caractere de remplacement")


def test_sans_wireshark() -> None:
    """Wireshark n'est plus necessaire, npcap suffit.

    npcap installe `wpcap.dll`, l'API libpcap : la bibliotheque l'appelle
    directement. dumpcap — donc Wireshark, et ses quatre-vingts mega-octets —
    n'est plus qu'un chemin de repli pour qui aurait l'un sans l'autre.

    Deux cas, donc. Sans dumpcap mais avec npcap, on voit les cartes comme
    avant. Sans ni l'un ni l'autre, on rend des listes vides : c'est le
    premier lancement de quelqu'un qui n'a pas encore installe le pilote, et
    il doit lire « aucune carte », pas une trace remontee des profondeurs de
    `subprocess`.
    """
    from dofus_stats.capture import live_source, npcap_source

    connus = live_source.DUMPCAP_CANDIDATES
    live_source.DUMPCAP_CANDIDATES = ["/nulle/part/dumpcap"]
    try:
        verifie(live_source.dumpcap_present() is False,
                "sans wireshark : l'absence de dumpcap est vue")
        if npcap_source.disponible():
            cartes = live_source.detailed_interfaces()
            verifie(len(cartes) > 0,
                    "sans wireshark : npcap voit les cartes")
            verifie(all(c.get("device") for c in cartes),
                    "sans wireshark : chacune porte son peripherique")
            # Le nom convivial vient de Windows, pas de npcap, qui ne connait
            # que le materiel : « Wi-Fi 4 » et non « MediaTek MT7925 ».
            verifie(any(c.get("mac") for c in cartes),
                    "sans wireshark : les adresses materielles sont la")
            verifie(any(c.get("physique") for c in cartes),
                    "sans wireshark : au moins une vraie carte")

        # Et maintenant sans npcap non plus.
        chemins = npcap_source.CHEMINS
        dll, cherche = npcap_source._dll, npcap_source._cherche
        npcap_source.CHEMINS = ["/nulle/part/wpcap.dll"]
        npcap_source._dll, npcap_source._cherche = None, False
        try:
            verifie(npcap_source.disponible() is False,
                    "sans rien : l'absence de npcap est vue")
            verifie(live_source.detailed_interfaces() == [],
                    "sans rien : liste detaillee vide")
            verifie(live_source.list_interfaces() == [],
                    "sans rien : liste simple vide")
            verifie(live_source.all_interfaces() == [],
                    "sans rien : aucune carte a ecouter")
        finally:
            npcap_source.CHEMINS = chemins
            npcap_source._dll, npcap_source._cherche = dll, cherche
    finally:
        live_source.DUMPCAP_CANDIDATES = connus

def main() -> int:
    for fn in [test_combat_deux_personnages, test_butin_complet, test_succes,
               test_caracteristiques, test_pods_et_kamas, test_degats_et_elements,
               test_fin_de_tour, test_challenges, test_classes,
               test_succes_sans_kamas,
               test_recolte, test_interfaces,
               test_liste_des_interfaces, test_sans_wireshark,
               test_doublons_de_capture,
               test_duree_de_combat, test_adversaires,
               test_combat_perdu,
               test_transferts, test_consommables,
               test_echange_et_achat, test_coffre_havre_sac,
               test_banque_et_connexion,
               test_integrite_du_decodage]:
        fn()
    echecs = [libelle for ok, libelle in resultats if not ok]
    for libelle in echecs:
        print(f"  ECHEC  {libelle}")
    print(f"\n{len(resultats) - len(echecs)}/{len(resultats)} verifications passees")
    return 1 if echecs else 0


if __name__ == "__main__":
    raise SystemExit(main())
