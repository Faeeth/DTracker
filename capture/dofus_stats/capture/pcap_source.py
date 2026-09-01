"""Lecture de fichiers .pcap et .pcapng, sans dependance externe.

Assez de pcapng pour ce qu'on capture avec dumpcap : SHB, IDB, EPB.
Les blocs inconnus sont sautes proprement grace au champ longueur.
"""
from __future__ import annotations

import struct
from typing import BinaryIO, Iterator

from .source import Frame

PCAP_MAGIC_US = 0xA1B2C3D4      # timestamps en microsecondes
PCAP_MAGIC_NS = 0xA1B23C4D      # timestamps en nanosecondes
PCAPNG_SHB = 0x0A0D0D0A
PCAPNG_IDB = 0x00000001
PCAPNG_EPB = 0x00000006
PCAPNG_SPB = 0x00000003
PCAPNG_BOM = 0x1A2B3C4D


class PcapError(Exception):
    pass


def read_file(path: str) -> Iterator[Frame]:
    # Un tampon d'un mega-octet : une capture d'une soiree tient des dizaines
    # de milliers de blocs, et chacun demandait deux ou trois appels systeme.
    with open(path, "rb", buffering=1 << 20) as fh:
        magic = fh.read(4)
        if len(magic) < 4:
            raise PcapError(f"{path}: fichier vide ou tronque")
        fh.seek(0)
        if struct.unpack("<I", magic)[0] == PCAPNG_SHB:
            yield from _read_pcapng(fh)
        else:
            yield from _read_pcap(fh)


# --------------------------------------------------------------------------- pcap

def _read_pcap(fh: BinaryIO) -> Iterator[Frame]:
    hdr = fh.read(24)
    if len(hdr) < 24:
        raise PcapError("en-tete pcap tronque")
    magic = struct.unpack("<I", hdr[:4])[0]
    if magic in (PCAP_MAGIC_US, PCAP_MAGIC_NS):
        endian = "<"
    elif struct.unpack(">I", hdr[:4])[0] in (PCAP_MAGIC_US, PCAP_MAGIC_NS):
        endian = ">"
        magic = struct.unpack(">I", hdr[:4])[0]
    else:
        raise PcapError(f"magic pcap inconnu: {magic:#x}")

    divisor = 1_000_000_000 if magic == PCAP_MAGIC_NS else 1_000_000
    linktype = struct.unpack(endian + "I", hdr[20:24])[0]

    while True:
        rec = fh.read(16)
        if len(rec) < 16:
            return
        ts_sec, ts_frac, caplen, _origlen = struct.unpack(endian + "IIII", rec)
        data = fh.read(caplen)
        if len(data) < caplen:
            return
        yield Frame(ts_sec + ts_frac / divisor, data, linktype)


# ------------------------------------------------------------------------- pcapng

def _read_pcapng(fh: BinaryIO) -> Iterator[Frame]:
    endian = "<"
    interfaces: list[tuple[int, int]] = []   # (linktype, divisor)

    while True:
        head = fh.read(8)
        if len(head) < 8:
            return
        btype, blen = struct.unpack(endian + "II", head)

        if btype == PCAPNG_SHB:
            # Le BOM permet de decouvrir l'endianness reelle du fichier.
            bom_raw = fh.read(4)
            if struct.unpack("<I", bom_raw)[0] != PCAPNG_BOM:
                endian = ">"
                blen = struct.unpack(">I", head[4:8])[0]
            body = fh.read(blen - 16)
            fh.read(4)
            interfaces.clear()
            continue

        if blen < 12:
            raise PcapError(f"bloc pcapng de longueur invalide: {blen}")
        # Corps et longueur repetee d'un seul coup : celle-ci ne sert a rien
        # ici, on la lisait pour la jeter.
        body = fh.read(blen - 8)

        if btype == PCAPNG_IDB:
            linktype = struct.unpack(endian + "H", body[:2])[0]
            divisor = _ts_divisor(body[8:], endian)
            interfaces.append((linktype, divisor))

        elif btype == PCAPNG_EPB:
            if_id, ts_hi, ts_lo, caplen, _orig = struct.unpack(endian + "IIIII", body[:20])
            linktype, divisor = interfaces[if_id] if if_id < len(interfaces) else (1, 1_000_000)
            ts = ((ts_hi << 32) | ts_lo) / divisor
            yield Frame(ts, bytes(body[20:20 + caplen]), linktype)

        elif btype == PCAPNG_SPB:
            linktype, _ = interfaces[0] if interfaces else (1, 1_000_000)
            yield Frame(0.0, bytes(body[4:]), linktype)


def _ts_divisor(options: bytes, endian: str) -> int:
    """Lit l'option if_tsresol (code 9). Absente => microsecondes."""
    i = 0
    while i + 4 <= len(options):
        code, length = struct.unpack(endian + "HH", options[i:i + 4])
        if code == 0:
            break
        value = options[i + 4:i + 4 + length]
        if code == 9 and value:
            raw = value[0]
            return (1 << (raw & 0x7F)) if raw & 0x80 else 10 ** raw
        i += 4 + ((length + 3) & ~3)
    return 1_000_000


class PcapSource:
    """Source rejouant un fichier de capture."""

    def __init__(self, path: str):
        self.path = path

    def frames(self) -> Iterator[Frame]:
        return read_file(self.path)
