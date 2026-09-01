"""Pods : poids porte et capacite.

Le message `iun` porte les deux : champ 1 = pods actuels, champ 3 = maximum.
Il arrive a chaque variation de l'inventaire, donc a chaque objet ramasse.

Le maximum recoupe la caracteristique 40 augmentee des 1000 pods accordes a
tout personnage, verifie sur quatre personnages : 294/318/444/2883 dans `kub`
pour 1294/1318/1444/3883 annonces ici.
"""
from __future__ import annotations

from typing import Iterable

from ..events import PodsUpdate
from ..session import Observed
from .base import Context, Extractor


class PodsExtractor(Extractor):
    codes = frozenset({"iun"})
    priority = 30

    def __init__(self, only_on_change: bool = True):
        self.only_on_change = only_on_change
        self._last: dict[str, tuple[int, int]] = {}

    def handle(self, obs: Observed, ctx: Context) -> Iterable[PodsUpdate]:
        top = obs.env.top
        if top is None:
            return ()
        values = {f.number: f.value for f in top.fields if f.wire == 0}
        current, maximum = values.get(1), values.get(3)
        if current is None or maximum is None:
            return ()
        if self.only_on_change and self._last.get(obs.who) == (current, maximum):
            return ()
        self._last[obs.who] = (current, maximum)
        return (PodsUpdate(obs.env.ts, obs.who, obs.who, current, maximum),)
