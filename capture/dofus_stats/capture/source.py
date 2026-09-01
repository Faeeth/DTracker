"""Sources de paquets.

Toute source produit la meme chose : une suite de (timestamp, trame brute, linktype).
Le reste du pipeline ignore si les octets viennent d'un fichier ou de la carte reseau.
"""
from __future__ import annotations

from dataclasses import dataclass
from typing import Iterator, Protocol


@dataclass(frozen=True)
class Frame:
    ts: float          # epoch en secondes, resolution native de la capture
    data: bytes        # trame complete, couche liaison incluse
    linktype: int      # DLT_* (1 = Ethernet)


class Source(Protocol):
    def frames(self) -> Iterator[Frame]:
        ...
