"""Etat du personnage.

Le message `kub` rappelle l'etat courant : experience totale, niveau, seuils du
niveau et solde de kamas. Il accompagne chaque gain d'experience, ce qui permet
de suivre le total en continu.

    2.1   seuil d'experience du niveau suivant
    2.7   seuil d'experience du niveau courant
    2.8   experience totale
    2.9.5 niveau
    2.10  solde de kamas
"""
from __future__ import annotations

from typing import Iterable

from ..events import CharacterState
from ..protocol import wire
from ..session import Observed
from .base import Context, Extractor

XP_NEXT = (2, 1)
XP_FLOOR = (2, 7)
XP_TOTAL = (2, 8)
LEVEL = (2, 9, 5)
KAMAS = (2, 10)


class CharacterStateExtractor(Extractor):
    codes = frozenset({"kub"})
    priority = 20

    def __init__(self, only_on_change: bool = True):
        """`only_on_change` evite un evenement a chaque rappel d'etat : le
        serveur reemet `kub` souvent sans que rien n'ait bouge."""
        self.only_on_change = only_on_change
        self._last: dict[str, tuple] = {}

    def handle(self, obs: Observed, ctx: Context) -> Iterable[CharacterState]:
        top = obs.env.top
        if top is None:
            return ()
        values = {path: f.value for path, f in wire.walk(top.fields) if f.wire == 0}
        total = values.get(XP_TOTAL)
        if total is None:
            return ()
        kamas = values.get(KAMAS, 0)
        signature = (total, kamas, values.get(LEVEL))
        if self.only_on_change and self._last.get(obs.who) == signature:
            return ()
        self._last[obs.who] = signature
        ctx.kamas.setdefault(obs.who, kamas)
        return (CharacterState(
            obs.env.ts, obs.who, obs.who,
            level=values.get(LEVEL),
            xp_total=total,
            xp_floor=values.get(XP_FLOOR, 0),
            xp_next=values.get(XP_NEXT, 0),
            kamas=kamas,
        ),)
