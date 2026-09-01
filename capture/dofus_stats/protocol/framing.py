"""Decoupage du flux d'octets en messages.

Format observe sur Dofus 3.6.10.11 (port 5555, en clair) :

    [varint longueur][corps protobuf][varint longueur][corps protobuf]...

C'est le "length-delimited stream" standard de protobuf. Valide sur capture reelle :
342 messages deframes sur 8 demi-flux, zero octet residuel.
"""
from __future__ import annotations

from dataclasses import dataclass

MAX_MESSAGE = 8 << 20          # garde-fou : au-dela, on considere le flux desynchronise
ANY_MARKER = b"type.ankama.com/"


def read_varint(buf: bytes, pos: int = 0) -> tuple[int | None, int]:
    """Retourne (valeur, position suivante). Valeur None si incomplet ou invalide."""
    value = shift = 0
    while pos < len(buf):
        byte = buf[pos]
        value |= (byte & 0x7F) << shift
        pos += 1
        if not byte & 0x80:
            return value, pos
        shift += 7
        if shift > 63:
            return None, pos
    return None, pos


@dataclass(frozen=True)
class RawMessage:
    ts: float
    body: bytes


class Deframer:
    """Accumule des octets et rend les messages complets, un flux a la fois."""

    def __init__(self) -> None:
        self.buf = bytearray()
        self.ts = 0.0
        self.messages = 0
        self.resyncs = 0
        self.dropped_bytes = 0
        self.desynced = False

    def feed(self, data: bytes, ts: float, gap_before: int = 0) -> list[RawMessage]:
        if gap_before:
            # Des octets manquent : la position courante ne veut plus rien dire.
            self.dropped_bytes += len(self.buf)
            self.buf.clear()
            self.desynced = True
        self.buf.extend(data)
        self.ts = ts

        if self.desynced and not self._resync():
            return []

        out: list[RawMessage] = []
        while True:
            length, pos = read_varint(self.buf)
            if length is None:
                if len(self.buf) > 10:      # un varint de longueur tient sur 10 octets max
                    self._mark_desync()
                return out
            if length == 0 or length > MAX_MESSAGE:
                self._mark_desync()
                if not self._resync():
                    return out
                continue
            if pos + length > len(self.buf):
                return out                   # message a cheval sur le segment suivant
            out.append(RawMessage(ts, bytes(self.buf[pos:pos + length])))
            del self.buf[:pos + length]
            self.messages += 1

    def _mark_desync(self) -> None:
        self.desynced = True
        self.resyncs += 1

    def _resync(self) -> bool:
        """Cherche un offset ou le chainage des longueurs redevient coherent.

        Un offset n'est retenu que si plusieurs messages s'enchainent sans reste et
        qu'au moins un porte la signature Any d'Ankama : une longueur plausible
        isolee arrive par hasard, une chaine valide beaucoup moins.
        """
        for offset in range(len(self.buf)):
            if self._chain_ok(offset):
                if offset:
                    self.dropped_bytes += offset
                    del self.buf[:offset]
                self.desynced = False
                return True
        # Rien de sur : on conserve une fenetre glissante en attendant la suite.
        if len(self.buf) > MAX_MESSAGE:
            self.dropped_bytes += len(self.buf) - 4096
            del self.buf[:-4096]
        return False

    def _chain_ok(self, offset: int, need: int = 3) -> bool:
        pos, seen, marker = offset, 0, False
        while seen < need:
            length, after = read_varint(self.buf, pos)
            if length is None:
                return False
            if length == 0 or length > MAX_MESSAGE:
                return False
            end = after + length
            if end > len(self.buf):
                # Fin de buffer atteinte : acceptable si on a deja vu assez de preuves.
                return seen >= 1 and marker
            if ANY_MARKER in self.buf[after:end]:
                marker = True
            pos = end
            seen += 1
        return marker
