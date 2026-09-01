"""Capture en direct via dumpcap.

dumpcap est le moteur de capture de Wireshark : ecrit en C, il tient la charge
sans perte la ou du Python pur decrocherait. On le branche en sous-processus,
sortie pcapng sur un tube, et on relit ce tube avec le meme lecteur que pour un
fichier. Direct et differe empruntent ainsi exactement le meme chemin de code.
"""
from __future__ import annotations

import io
import json
import locale
import os
import re
import sys
import subprocess
from typing import Iterator

from .pcap_source import _read_pcapng
from .source import Frame

DUMPCAP_CANDIDATES = [
    r"C:\Program Files\Wireshark\dumpcap.exe",
    r"C:\Program Files (x86)\Wireshark\dumpcap.exe",
    "/usr/bin/dumpcap",
    "dumpcap",
]


def find_dumpcap() -> str:
    for path in DUMPCAP_CANDIDATES:
        if os.path.exists(path):
            return path
    return "dumpcap"


def dumpcap_present() -> bool:
    """dumpcap est-il installe ?

    Wireshark n'est pas fourni avec l'outil et ne peut pas l'etre : c'est le
    pilote npcap qui compte, et sa licence interdit la redistribution. Une
    machine sans lui est donc un cas ordinaire, pas une anomalie — tout ce qui
    appelle dumpcap doit le supporter.
    """
    return any(os.path.exists(p) for p in DUMPCAP_CANDIDATES)


def _dumpcap(*arguments: str) -> bytes:
    """Lance dumpcap et rend sa sortie. Vide s'il n'est pas la.

    Sans ce garde-fou, l'absence de Wireshark remontait en `FileNotFoundError`
    depuis les profondeurs de `subprocess` — une trace de dix lignes la ou il
    fallait lire « aucune carte ».
    """
    try:
        res = subprocess.run([find_dumpcap(), *arguments], capture_output=True)
        return res.stdout or b""
    except OSError:
        return b""


def _texte(donnees: bytes) -> str:
    """Decode la sortie de dumpcap, quel que soit son encodage.

    Sous Windows, les noms conviviaux des cartes sortent dans la page de codes
    locale, pas en UTF-8 : « Connexion reseau Bluetooth » y porte un `0xe9`
    cp1252. Le lire en UTF-8 remplacait l'accent par un caractere de
    remplacement, et le nom devenait illisible a l'ecran.

    Les codecs sont essayes du plus strict au plus permissif. `latin-1`
    n'echoue jamais : il ferme la liste plutot que de laisser passer une
    exception.
    """
    for codec in ("utf-8", locale.getpreferredencoding(False), "cp1252",
                  "latin-1"):
        try:
            return donnees.decode(codec)
        except (UnicodeDecodeError, LookupError):
            continue
    return donnees.decode("utf-8", "replace")


def list_interfaces() -> list[tuple[str, str]]:
    out = []
    for line in _texte(_dumpcap("-D")).splitlines():
        num, _, rest = line.partition(". ")
        if num.strip().isdigit():
            out.append((num.strip(), rest.strip()))
    return out


#: Types d'interface, tels que Wireshark les numerote.
IF_FILAIRE = 0
IF_BLUETOOTH = 4
IF_SANS_FIL = 5

#: Ce qui, dans le nom ou la description d'une carte, la designe comme
#: virtuelle. Le type ne suffit pas : Windows presente les adaptateurs VPN
#: comme filaires, exactement comme une vraie carte Ethernet, et rien d'autre
#: ne les en distingue.
VIRTUELLES = re.compile(
    r"virtual|vmware|virtualbox|hyper-?v|vethernet|vbox"
    r"|tap-?win|openvpn|wireguard|wintun|tailscale|zerotier|hamachi"
    r"|nordlynx|proton|surfshark|expressvpn|teredo|isatap|pseudo"
    r"|loopback|wan miniport|bluetooth|docker|wsl|npcap|vpn",
    re.IGNORECASE,
)


def est_physique(interface: dict) -> bool:
    """La carte est-elle une vraie Ethernet ou un vrai Wi-Fi ?

    Ecouter les adaptateurs virtuels ne rapporte rien et encombre le menu : le
    jeu ne passe pas par un TAP OpenVPN ni par le Bluetooth. On garde donc les
    types filaire et sans-fil, boucle locale exclue, puis on ecarte ce que le
    nom ou la description designe comme virtuel.

    Le tri se fait sur ce que le systeme declare, jamais sur la presence d'une
    adresse : un Wi-Fi debranche au demarrage doit rester ecoutable, sans quoi
    brancher le cable en cours de partie rendrait l'outil muet.
    """
    if interface.get("loopback"):
        return False
    if interface.get("type") not in (IF_FILAIRE, IF_SANS_FIL):
        return False
    texte = f"{interface.get('libelle', '')} {interface.get('description', '')}"
    return not VIRTUELLES.search(texte)


#: Le GUID dans un nom de peripherique npcap : `\Device\NPF_{GUID}`.
GUID = re.compile(r"\{[0-9A-Fa-f-]{36}\}")


def adresses_mac() -> dict[str, str]:
    """L'adresse materielle de chaque carte, par GUID d'interface.

    dumpcap ne la donne pas : il rend les adresses IP, qui changent de bail en
    bail et manquent tant que la carte n'est pas configuree. L'adresse
    materielle, elle, identifie la carte pour de bon — c'est ce qu'on lit sur
    l'etiquette et dans l'interface du routeur.

    La source est `Get-NetAdapter -IncludeHidden`, seule a rendre a la fois le
    GUID et l'adresse. `-IncludeHidden` n'est pas un detail : les cartes
    virtuelles d'un pilote Wi-Fi moderne — « Wi-Fi 3 », « Wi-Fi 4 » — n'y
    figurent pas autrement, et ce sont justement celles qu'on ne sait pas
    reconnaitre de vue.

    Rend une table vide sur tout autre systeme, ou si PowerShell manque :
    l'adresse est un agrement d'affichage, pas une condition.
    """
    if not sys.platform.startswith("win"):
        return {}
    try:
        res = subprocess.run(
            ["powershell", "-NoProfile", "-NonInteractive", "-Command",
             "Get-NetAdapter -IncludeHidden | "
             "Select-Object InterfaceGuid, MacAddress | ConvertTo-Json"],
            capture_output=True, timeout=15,
        )
        brut = json.loads(_texte(res.stdout))
    except (OSError, subprocess.SubprocessError, json.JSONDecodeError,
            TypeError, ValueError):
        return {}
    # Une carte unique sort en objet, pas en liste.
    if isinstance(brut, dict):
        brut = [brut]
    table = {}
    for entree in brut if isinstance(brut, list) else []:
        if not isinstance(entree, dict):
            continue
        guid = str(entree.get("InterfaceGuid") or "").upper()
        mac = str(entree.get("MacAddress") or "").strip().upper()
        if guid and mac:
            table[guid] = mac
    return table


def detailed_interfaces() -> list[dict]:
    """Les interfaces avec leurs adresses, telles que dumpcap les decrit.

    `dumpcap -M -D` rend du JSON : nom de peripherique, nom convivial,
    adresses, et si c'est une boucle locale. Le nom de peripherique est stable
    d'un demarrage a l'autre ; le numero de la liste, lui, ne l'est pas — une
    carte qui apparait decale tous les suivants.
    """
    try:
        brut = json.loads(_texte(_dumpcap("-M", "-D")))
    except (json.JSONDecodeError, TypeError):
        return []
    macs = adresses_mac()
    interfaces = []
    for numero, entree in enumerate(brut, start=1):
        if not isinstance(entree, dict):
            continue
        for peripherique, details in entree.items():
            details = details if isinstance(details, dict) else {}
            interface = {
                "numero": str(numero),
                "device": peripherique,
                "libelle": details.get("friendly_name") or peripherique,
                "description": details.get("vendor_description") or "",
                "type": details.get("type"),
                "adresses": [str(a) for a in details.get("addrs") or []],
                "loopback": bool(details.get("loopback")),
                "mac": _mac_de(peripherique, macs),
            }
            # Le verdict accompagne la carte plutot que de filtrer la liste :
            # une interface graphique doit pouvoir montrer le tout si on le lui
            # demande, et c'est a elle de decider ce qu'elle affiche.
            interface["physique"] = est_physique(interface)
            interfaces.append(interface)
    return interfaces


def _mac_de(peripherique: str, macs: dict[str, str]) -> str:
    """L'adresse materielle derriere un nom de peripherique npcap."""
    trouve = GUID.search(peripherique or "")
    return macs.get(trouve.group(0).upper(), "") if trouve else ""


def all_interfaces(toutes: bool = False) -> list[str]:
    """Les cartes a ecouter quand aucune n'est choisie.

    Par defaut, les seules cartes physiques — Ethernet et Wi-Fi. Les
    adaptateurs virtuels, la boucle locale et le Bluetooth sont ecartes : le
    jeu n'y passe pas, et chacun coute une poignee de dumpcap pour rien.

    `toutes` leve le tri, pour le cas ou la reconnaissance se tromperait sur
    une machine dont on ne sait rien.
    """
    interfaces = detailed_interfaces()
    retenues = [i for i in interfaces if toutes and not i["loopback"]
                or not toutes and i["physique"]]
    # Un tri trop severe vaut mieux corrige que subi : sans rien de physique,
    # on se rabat sur tout ce qui n'est pas la boucle locale.
    if not retenues:
        retenues = [i for i in interfaces if not i["loopback"]]
    return [i["device"] for i in retenues]


class LiveSource:
    """Ecoute en direct, sur une interface ou sur toutes.

    Par defaut, **toutes**. Choisir la bonne carte est une question a laquelle
    l'utilisateur n'a aucune raison de savoir repondre : le jeu peut passer par
    l'Ethernet, le Wi-Fi ou un VPN, et cela change en cours de partie quand on
    debranche un cable. Une carte mal choisie ne se signale pas — l'outil reste
    simplement muet, ce qui ressemble a une panne.

    Windows n'a pas de pseudo-interface `any`, celle-la est propre a Linux.
    Mais dumpcap accepte plusieurs `-i` dans un seul flux pcapng, chaque paquet
    portant l'indice de sa carte, et le lecteur s'en accommode deja. Le filtre
    BPF fait le reste : une interface sans trafic de jeu ne coute rien.
    """

    #: Ce qui, dans un reglage, veut dire « toutes les interfaces ».
    TOUTES = ("", "any", "all", "toutes", "auto")

    def __init__(self, interface: str = "", port: int = 5555,
                 bpf: str | None = None):
        self.interface = interface
        self.bpf = bpf if bpf is not None else (f"tcp port {port}" if port else "tcp")
        self.proc: subprocess.Popen | None = None

    def interfaces(self) -> list[str]:
        """Les interfaces a ecouter, dans l'ordre des `-i`."""
        choix = (self.interface or "").strip()
        if choix.lower() not in self.TOUTES:
            # Une liste separee par des virgules reste possible : on peut
            # vouloir restreindre a deux cartes precises.
            return [m.strip() for m in choix.split(",") if m.strip()]
        if sys.platform.startswith("linux"):
            # Linux a la vraie pseudo-interface, autant s'en servir.
            return ["any"]
        return all_interfaces() or ["1"]

    def frames(self) -> Iterator[Frame]:
        # Ne pas brider le tampon de dumpcap. L'option -N, essayee pour reduire
        # la latence, s'est revelee desastreuse : limite a un paquet en memoire,
        # dumpcap en a perdu deux sur trois des que le decodage prenait la main,
        # et un flux TCP ampute ne se reassemble plus. Mieux vaut quelques
        # dizaines de millisecondes de retard qu'un flux troue.
        cmd = [find_dumpcap(), "-w", "-", "-q"]
        for interface in self.interfaces():
            cmd += ["-i", interface]
        if self.bpf:
            cmd += ["-f", self.bpf]
        self.proc = subprocess.Popen(cmd, stdout=subprocess.PIPE, stderr=subprocess.DEVNULL,
                                     bufsize=0)
        try:
            # Le tube est relu au travers d'un tampon, et non brut.
            #
            # Deux raisons, dont une de justesse : sur un flux brut, `read(n)`
            # rend ce que le tube a sous la main, qui peut etre moins que n.
            # Le lecteur pcapng, lui, prend ce qu'il recoit pour un bloc
            # entier — un bloc arrive en deux morceaux se serait lu de
            # travers, sans rien signaler. Un `BufferedReader` reclame jusqu'a
            # obtenir son compte. Il epargne au passage un appel systeme par
            # bloc, sans rien retarder : il ne rend la main qu'a la demande.
            yield from _read_pcapng(io.BufferedReader(self.proc.stdout,
                                                      buffer_size=1 << 16))
        finally:
            self.close()

    def close(self) -> None:
        if self.proc and self.proc.poll() is None:
            self.proc.terminate()
            try:
                self.proc.wait(timeout=3)
            except subprocess.TimeoutExpired:
                self.proc.kill()
