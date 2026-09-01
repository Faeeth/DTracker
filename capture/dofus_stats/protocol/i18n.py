"""Lecture du catalogue de textes du client (StreamingAssets/Content/I18n/fr.bin).

Format : en-tete `\x02` + code langue sur 2 octets + nombre d'entrees sur 4
octets, puis une table de (identifiant, offset) sur 8 octets chacun, puis les
chaines, chacune prefixee de sa longueur en varint. Tout est en clair.

Ce catalogue donne le libelle des messages que le serveur envoie sous forme
d'identifiant + parametres, ce qui rend lisibles les annonces de gain.
"""
from __future__ import annotations

import os
import struct

DEFAULT = (r"C:\Users\orfre\AppData\Local\Ankama\Dofus-dofus3\Dofus_Data"
           r"\StreamingAssets\Content\I18n\fr.bin")


class Texts:
    def __init__(self, path: str | None = None):
        self.path = path or DEFAULT
        self.offsets: dict[int, int] = {}
        self.data = b""
        if os.path.exists(self.path):
            self._load()

    def _load(self) -> None:
        self.data = open(self.path, "rb").read()
        count = struct.unpack("<I", self.data[3:7])[0]
        table = 7
        for i in range(count):
            pos = table + i * 8
            if pos + 8 > len(self.data):
                break
            key, off = struct.unpack("<II", self.data[pos:pos + 8])
            self.offsets[key] = off

    def get(self, key: int) -> str | None:
        off = self.offsets.get(key)
        if off is None or off >= len(self.data):
            return None
        length, pos = self._varint(off)
        if length is None or pos + length > len(self.data):
            return None
        try:
            return self.data[pos:pos + length].decode("utf-8")
        except UnicodeDecodeError:
            return None

    def _varint(self, pos: int):
        value = shift = 0
        while pos < len(self.data):
            b = self.data[pos]
            value |= (b & 0x7F) << shift
            pos += 1
            if not b & 0x80:
                return value, pos
            shift += 7
            if shift > 35:
                return None, pos
        return None, pos

    def __bool__(self) -> bool:
        return bool(self.offsets)
