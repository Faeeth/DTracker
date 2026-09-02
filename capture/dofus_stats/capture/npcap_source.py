"""Capture par npcap, sans passer par dumpcap.

npcap installe `wpcap.dll` : c'est l'API libpcap, pilote compris. `dumpcap`,
lui, n'est qu'un programme qui s'en sert — le detour par Wireshark n'etait
qu'une commodite d'auteur, et il coute quatre-vingts mega-octets a qui
installe l'outil. On appelle donc la bibliotheque directement.

**Ce qui ne change pas.** Le filtre reste pose dans le noyau (`pcap_setfilter`)
et non en Python : seul le trafic du jeu remonte, exactement comme avec le
`-f` de dumpcap. C'est ce qui permet de tenir le debit d'un combat sans rien
perdre — un flux TCP ampute ne se reassemble plus, et la fin de combat devient
illisible.

**Ce qui change.** Le tampon est le notre. `pcap_open_live` en prend un d'un
mega-octet, la ou dumpcap gerait le sien ; c'est le seul reglage qui separe
une capture propre d'une capture trouee.

Le module se tait quand npcap manque : `disponible()` rend faux, et l'appelant
se rabat sur dumpcap. Une machine sans pilote de capture est un cas ordinaire,
pas une anomalie.
"""
from __future__ import annotations

import ctypes
import os
import socket
import time
from typing import Iterator

from .source import Frame

#: Ce que `pcap_open_live` garde en memoire avant de rendre la main. Un
#: mega-octet : de quoi encaisser une rafale de fin de combat pendant que le
#: decodage travaille.
TAMPON = 1 << 20

#: Millisecondes que `pcap_next_ex` attend avant de rendre la main les mains
#: vides. Assez court pour que l'arret soit franc, assez long pour ne pas
#: tourner a vide.
ATTENTE_MS = 100

_SYSTEM32 = os.path.join(os.environ.get("SystemRoot", r"C:\Windows"),
                         "System32")

#: npcap pose ses DLL dans son propre dossier ; elles ne vont dans `System32`
#: que si l'on a coche « WinPcap API-compatible Mode » a l'installation. On
#: regarde donc aux deux endroits.
CHEMINS = [
    os.path.join(_SYSTEM32, "Npcap", "wpcap.dll"),
    os.path.join(_SYSTEM32, "wpcap.dll"),
    "wpcap.dll",
]


class _Entete(ctypes.Structure):
    _fields_ = [
        ("tv_sec", ctypes.c_long),
        ("tv_usec", ctypes.c_long),
        ("caplen", ctypes.c_uint32),
        ("len", ctypes.c_uint32),
    ]


class _SockAddr(ctypes.Structure):
    """L'en-tete commune : la famille, puis ce qui la suit selon la famille."""
    _fields_ = [("sa_family", ctypes.c_uint16), ("sa_data", ctypes.c_uint8 * 26)]


class _Adresse(ctypes.Structure):
    pass


_Adresse._fields_ = [
    ("next", ctypes.POINTER(_Adresse)),
    ("addr", ctypes.POINTER(_SockAddr)),
    ("netmask", ctypes.POINTER(_SockAddr)),
    ("broadaddr", ctypes.POINTER(_SockAddr)),
    ("dstaddr", ctypes.POINTER(_SockAddr)),
]


class _Interface(ctypes.Structure):
    pass


_Interface._fields_ = [
    ("next", ctypes.POINTER(_Interface)),
    ("name", ctypes.c_char_p),
    ("description", ctypes.c_char_p),
    ("addresses", ctypes.POINTER(_Adresse)),
    ("flags", ctypes.c_uint32),
]

#: Familles d'adresses, valeurs Windows.
AF_INET = 2
AF_INET6 = 23


def _lit_adresse(pointeur) -> str:
    """Une `sockaddr` en texte. Vide si ce n'est ni de l'IPv4 ni de l'IPv6.

    Les octets sont pris a leur position dans la structure : pour IPv4, les
    quatre de l'adresse suivent deux octets de famille et deux de port ; pour
    IPv6, les seize suivent famille, port et champ de flux.
    """
    if not pointeur:
        return ""
    sa = pointeur.contents
    if sa.sa_family == AF_INET:
        octets = bytes(sa.sa_data[2:6])
        return socket.inet_ntop(socket.AF_INET, octets)
    if sa.sa_family == AF_INET6:
        octets = bytes(sa.sa_data[6:22])
        return socket.inet_ntop(socket.AF_INET6, octets)
    return ""


def _adresses(carte: _Interface) -> list[str]:
    vues: list[str] = []
    courant = carte.addresses
    while courant:
        texte = _lit_adresse(courant.contents.addr)
        if texte and texte not in vues:
            vues.append(texte)
        courant = courant.contents.next
    return vues

#: Drapeaux de `pcap_findalldevs`, tels que libpcap les definit.
IF_LOOPBACK = 0x00000001
IF_WIRELESS = 0x00000008

_dll = None
_cherche = False


def bibliotheque():
    """Rend `wpcap.dll`, ou None. Cherchee une seule fois."""
    global _dll, _cherche
    if _cherche:
        return _dll
    _cherche = True
    npcap = os.path.join(_SYSTEM32, "Npcap")
    if os.path.isdir(npcap) and hasattr(os, "add_dll_directory"):
        try:
            # Les DLL de npcap dependent les unes des autres : sans ce
            # chemin, le chargement echoue sur une dependance manquante.
            os.add_dll_directory(npcap)
        except OSError:
            pass
    for chemin in CHEMINS:
        try:
            dll = ctypes.CDLL(chemin)
        except OSError:
            continue
        dll.pcap_lib_version.restype = ctypes.c_char_p
        dll.pcap_open_live.restype = ctypes.c_void_p
        dll.pcap_geterr.restype = ctypes.c_char_p
        _dll = dll
        return _dll
    return None


def disponible() -> bool:
    return bibliotheque() is not None


def version() -> str:
    dll = bibliotheque()
    return dll.pcap_lib_version().decode("latin-1", "replace") if dll else ""


def interfaces() -> list[dict]:
    """Les cartes que npcap propose.

    Meme forme que celles de dumpcap, a une nuance pres : la description est
    celle du materiel — « MediaTek Wi-Fi 7 MT7925 » — la ou dumpcap donne le
    nom convivial de Windows — « Wi-Fi 4 ». Le nom convivial et l'adresse
    materielle sont rajoutes par `live_source`, qui les tient de Windows.
    """
    dll = bibliotheque()
    if dll is None:
        return []
    erreur = ctypes.create_string_buffer(256)
    tete = ctypes.POINTER(_Interface)()
    if dll.pcap_findalldevs(ctypes.byref(tete), erreur) != 0:
        return []
    sorties = []
    try:
        courant = tete
        numero = 0
        while courant:
            c = courant.contents
            numero += 1
            nom = c.name.decode("latin-1", "replace")
            description = (c.description or b"").decode("latin-1", "replace")
            sorties.append({
                "numero": str(numero),
                "device": nom,
                "libelle": description or nom,
                "description": description,
                # Le type que `est_physique` attend : filaire par defaut,
                # sans-fil quand le drapeau le dit.
                "type": 5 if c.flags & IF_WIRELESS else 0,
                "adresses": _adresses(c),
                "loopback": bool(c.flags & IF_LOOPBACK),
            })
            courant = c.next
    finally:
        dll.pcap_freealldevs(tete)
    return sorties


class NpcapSource:
    """Une source de trames branchee sur npcap.

    Plusieurs cartes a la fois : Windows n'a pas de pseudo-interface `any`, et
    le jeu peut passer par l'Ethernet comme par le Wi-Fi. Chaque carte a sa
    poignee, et on les interroge a tour de role.
    """

    def __init__(self, interfaces: list[str], bpf: str = "tcp port 5555"):
        self.interfaces = interfaces
        self.bpf = bpf
        self._poignees: list[tuple[int, int]] = []   # (poignee, linktype)
        self._arrete = False

    def _ouvre(self, dll, nom: str):
        erreur = ctypes.create_string_buffer(256)
        poignee = dll.pcap_open_live(nom.encode("latin-1"), 65536, 1,
                                     ATTENTE_MS, erreur)
        if not poignee:
            return None
        poignee = ctypes.c_void_p(poignee)
        # Un tampon genereux : c'est lui qui absorbe la rafale de fin de
        # combat pendant que le decodage travaille.
        if hasattr(dll, "pcap_setbuff"):
            dll.pcap_setbuff(poignee, TAMPON)
        if self.bpf:
            programme = ctypes.create_string_buffer(64)
            if dll.pcap_compile(poignee, ctypes.byref(programme),
                                self.bpf.encode("latin-1"), 1,
                                ctypes.c_uint32(0xFFFFFFFF)) == 0:
                dll.pcap_setfilter(poignee, ctypes.byref(programme))
                dll.pcap_freecode(ctypes.byref(programme))
        return poignee

    def frames(self) -> Iterator[Frame]:
        dll = bibliotheque()
        if dll is None:
            return
        for nom in self.interfaces:
            poignee = self._ouvre(dll, nom)
            if poignee is None:
                continue
            self._poignees.append((poignee, dll.pcap_datalink(poignee)))
        if not self._poignees:
            return

        entete = ctypes.POINTER(_Entete)()
        donnees = ctypes.POINTER(ctypes.c_ubyte)()
        try:
            while not self._arrete:
                recu = False
                for poignee, linktype in self._poignees:
                    # Une carte peut avoir plusieurs paquets en attente ; on
                    # la vide avant de passer a la suivante, sans quoi une
                    # carte chargee prendrait du retard sur les autres.
                    for _ in range(64):
                        r = dll.pcap_next_ex(poignee, ctypes.byref(entete),
                                             ctypes.byref(donnees))
                        if r != 1:
                            break
                        recu = True
                        e = entete.contents
                        yield Frame(
                            e.tv_sec + e.tv_usec / 1_000_000,
                            ctypes.string_at(donnees, e.caplen),
                            linktype,
                        )
                if not recu:
                    # Rien nulle part : on rend la main plutot que de tourner
                    # a vide sur un processeur.
                    time.sleep(0.005)
        finally:
            self.close()

    def arrete(self) -> None:
        """Demande l'arret sans fermer les poignees.

        Ce que `close` ne peut pas faire depuis un autre fil : il libere des
        poignees que la boucle de lecture est peut-etre en train d'utiliser.
        Ici on pose un drapeau, la boucle sort d'elle-meme — au plus tard
        apres l'attente de `pcap_next_ex` — et ferme ce qu'elle a ouvert.
        """
        self._arrete = True

    def close(self) -> None:
        self._arrete = True
        dll = bibliotheque()
        if dll is None:
            return
        for poignee, _ in self._poignees:
            dll.pcap_close(poignee)
        self._poignees = []
