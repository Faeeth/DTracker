"""Dissection Ethernet / IPv4 / IPv6 / TCP, reduite au strict necessaire.

On ne cherche pas a etre un analyseur generaliste : juste a extraire
(qui parle a qui, numero de sequence, octets utiles) de facon fiable.
"""
from __future__ import annotations

import socket
import struct
from dataclasses import dataclass

ETH_IPV4 = 0x0800
ETH_IPV6 = 0x86DD
ETH_VLAN = 0x8100
ETH_QINQ = 0x88A8
IPPROTO_TCP = 6

TCP_FIN = 0x01
TCP_SYN = 0x02
TCP_RST = 0x04


@dataclass(frozen=True)
class FlowKey:
    """Direction d'une connexion : A vers B. La direction inverse est une autre cle."""
    src: str
    sport: int
    dst: str
    dport: int

    def reversed(self) -> "FlowKey":
        return FlowKey(self.dst, self.dport, self.src, self.sport)

    def connection_id(self) -> tuple:
        """Identifiant stable partage par les deux directions."""
        a, b = (self.src, self.sport), (self.dst, self.dport)
        return (a, b) if a <= b else (b, a)

    def __str__(self) -> str:
        return f"{self.src}:{self.sport} -> {self.dst}:{self.dport}"


@dataclass(frozen=True)
class Segment:
    ts: float
    flow: FlowKey
    seq: int
    payload: bytes
    flags: int


def dissect(ts: float, data: bytes, linktype: int = 1,
            port: int | None = None) -> Segment | None:
    """Retourne le segment TCP porte par la trame, ou None si non pertinent.

    `port` ecarte tout de suite ce qui ne va ni ne vient de ce port. Il ne
    change pas le resultat — l'appelant filtrait deja — mais il le decide
    avant de mettre les adresses en forme et de construire le segment. Sur une
    carte reseau ordinaire, la quasi-totalite des trames sont etrangeres au
    jeu : on payait pour chacune deux conversions d'adresse en texte.
    """
    if linktype == 1:
        if len(data) < 14:
            return None
        ethertype = struct.unpack("!H", data[12:14])[0]
        offset = 14
        # Un ou plusieurs tags VLAN peuvent s'intercaler.
        while ethertype in (ETH_VLAN, ETH_QINQ):
            if len(data) < offset + 4:
                return None
            ethertype = struct.unpack("!H", data[offset + 2:offset + 4])[0]
            offset += 4
    elif linktype == 101:      # DLT_RAW : le paquet commence directement en IP
        if not data:
            return None
        version = data[0] >> 4
        ethertype = ETH_IPV4 if version == 4 else ETH_IPV6 if version == 6 else 0
        offset = 0
    elif linktype == 228:      # DLT_IPV4
        ethertype, offset = ETH_IPV4, 0
    else:
        return None

    if ethertype == ETH_IPV4:
        return _ipv4(ts, data, offset, port)
    if ethertype == ETH_IPV6:
        return _ipv6(ts, data, offset, port)
    return None


def _ipv4(ts: float, data: bytes, off: int,
          port: int | None = None) -> Segment | None:
    if len(data) < off + 20:
        return None
    ihl = (data[off] & 0x0F) * 4
    if ihl < 20 or data[off + 9] != IPPROTO_TCP:
        return None
    total_len = struct.unpack("!H", data[off + 2:off + 4])[0]
    # Fragmentation IP : on ne traite que le premier fragment (offset nul).
    if struct.unpack("!H", data[off + 6:off + 8])[0] & 0x1FFF:
        return None
    # total_len fait autorite sur la taille reelle : Ethernet peut avoir ajoute du padding.
    end = off + total_len if 0 < total_len <= len(data) - off else len(data)
    return _tcp(ts, data, off + ihl, end,
                socket.AF_INET, data[off + 12:off + 16], data[off + 16:off + 20],
                port)


def _ipv6(ts: float, data: bytes, off: int,
          port: int | None = None) -> Segment | None:
    if len(data) < off + 40:
        return None
    nxt = data[off + 6]
    payload_len = struct.unpack("!H", data[off + 34:off + 36])[0]
    pos = off + 40
    end = pos + payload_len if 0 < payload_len <= len(data) - pos else len(data)
    # Traversee des en-tetes d'extension usuels.
    for _ in range(8):
        if nxt == IPPROTO_TCP:
            return _tcp(ts, data, pos, end,
                        socket.AF_INET6, data[off + 8:off + 24],
                        data[off + 24:off + 40], port)
        if nxt in (0, 43, 60) and len(data) >= pos + 8:
            nxt = data[pos]
            pos += (data[pos + 1] + 1) * 8
        else:
            return None
    return None


def _tcp(ts: float, data: bytes, off: int, end: int,
         famille: int, src: bytes, dst: bytes,
         port: int | None = None) -> Segment | None:
    """Les adresses arrivent en octets et ne sont mises en texte qu'a la fin.

    C'est le dernier endroit ou l'on peut encore renoncer sans rien avoir
    construit : le port se lit dans les quatre premiers octets de l'en-tete,
    la conversion des adresses coute bien davantage.
    """
    if len(data) < off + 20:
        return None
    sport, dport, seq = struct.unpack("!HHI", data[off:off + 8])
    if port is not None and port != sport and port != dport:
        return None
    doff = (data[off + 12] >> 4) * 4
    if doff < 20:
        return None
    flags = data[off + 13]
    payload = bytes(data[off + doff:end]) if end > off + doff else b""
    return Segment(
        ts,
        FlowKey(socket.inet_ntop(famille, src), sport,
                socket.inet_ntop(famille, dst), dport),
        seq, payload, flags,
    )
