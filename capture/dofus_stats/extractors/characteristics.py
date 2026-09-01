"""Feuille de caracteristiques.

Portee par `kub`, champ 2.11 repete. Chaque entree donne un identifiant
(champ 1) et une valeur dont la forme depend de la caracteristique :

    4: { 2: <base>, 7: <bonus> }     forme courante
    5: { 1: <base>, 5: <bonus> }     points d'action et de mouvement
    2: { 2: <valeur> }               energie et energie maximale

L'entree sans identifiant porte les points de vie de base (50 + 5 x niveau).
La vitalite affichee en jeu est cette base augmentee du bonus d'equipement.

Confronte a la page statistiques d'un personnage : 21 caracteristiques sur 22
identiques, le seul ecart venant d'un passage de niveau entre la capture et le
releve.
"""
from __future__ import annotations

from typing import Iterable

from ..events import Characteristic, Characteristics
from ..protocol.characteristics import name_of
from ..session import Observed
from .base import Context, Extractor

LEVEL = (2, 9, 5)


class CharacteristicsExtractor(Extractor):
    codes = frozenset({"kub"})
    priority = 25

    def __init__(self, only_on_change: bool = True):
        self.only_on_change = only_on_change
        self._last: dict[str, tuple] = {}

    def handle(self, obs: Observed, ctx: Context) -> Iterable[Characteristics]:
        top = obs.env.top
        if top is None:
            return ()
        for f in top.fields:
            if f.number != 2 or not f.is_message:
                continue
            return self._sheet(obs, f.value)
        return ()

    def _sheet(self, obs: Observed, fields) -> Iterable[Characteristics]:
        level = base_life = None
        values: dict[str, Characteristic] = {}
        for c in fields:
            if c.number == 9 and c.is_message:
                for g in c.value:
                    if g.number == 5 and g.wire == 0:
                        level = g.value
            elif c.number == 11 and c.is_message:
                char_id, base, bonus = _entry(c.value)
                if char_id is None:
                    base_life = base + bonus
                else:
                    values[name_of(char_id)] = Characteristic(char_id, name_of(char_id),
                                                              base, bonus)
        if not values:
            return ()
        signature = (level, base_life, tuple(sorted((k, v.total) for k, v in values.items())))
        if self.only_on_change and self._last.get(obs.who) == signature:
            return ()
        self._last[obs.who] = signature
        return (Characteristics(obs.env.ts, obs.who, obs.who, level,
                                base_life or 0, values),)


def _entry(fields) -> tuple[int | None, int, int]:
    """Rend (identifiant, base, bonus) quelle que soit la forme de la valeur."""
    char_id = None
    base = bonus = 0
    for g in fields:
        if g.number == 1 and g.wire == 0:
            char_id = g.value
        elif not g.is_message:
            continue
        elif g.number == 4:                       # forme courante
            for h in g.value:
                if h.wire != 0:
                    continue
                if h.number == 2:
                    base = _signed(h.value)
                elif h.number == 7:
                    bonus = h.value
        elif g.number == 5:                       # points d'action / mouvement
            for h in g.value:
                if h.wire != 0:
                    continue
                if h.number == 1:
                    base = h.value
                elif h.number == 5:
                    bonus = h.value
        elif g.number == 2:                       # valeur unique (energie)
            for h in g.value:
                if h.number == 2 and h.wire == 0:
                    base = h.value
    return char_id, base, bonus


def _signed(value: int) -> int:
    """Une caracteristique peut etre negative ; le varint l'encode sur 64 bits."""
    return value - (1 << 64) if value >= (1 << 63) else value
