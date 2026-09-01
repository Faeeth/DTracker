"""Lancers de sorts et variations de caracteristiques en combat.

    jwh  C->S  1: <case ciblee>  4: <identifiant du sort>
    jxw  S->C  1: <combattant>  3: {5: {1: <caracteristique>, ...}}

Le sort n'est designe que par un identifiant : le libelle vit dans les fichiers
du client et n'est pas resolu ici. L'appariement a ete verifie de facon croisee,
un meme sort lance dans deux combats distincts portant le meme identifiant
(25860 pour l'un, 25742 pour un autre).

`jxw` porte la valeur d'une caracteristique apres coup. Deux formes cohabitent :

    5: {1: <carac>, 2: {2: <valeur>}}                       valeur simple
    5: {1: <carac>, 5: {1: <base>, 4: <delta>, 5: ..., 6: ...}}   avec variation

Le champ 4 de la seconde forme donne la variation elle-meme — negative quand un
lanceur consomme ses points d'action, positive quand un sort de soutien en
accorde. Quand seule la valeur finale est transmise, `value` la reporte telle
quelle : c'est au consommateur de la comparer a l'etat precedent s'il veut un
delta.
"""
from __future__ import annotations

from typing import Iterable

from ..events import CharacteristicChange, Event, SpellCast
from ..protocol.characteristics import name_of
from ..session import Observed
from .base import Context, Extractor


class SpellExtractor(Extractor):
    codes = frozenset({"jwh", "jxw"})
    priority = 35

    def handle(self, obs: Observed, ctx: Context) -> Iterable[Event]:
        top = obs.env.top
        if top is None:
            return ()
        if obs.env.code == "jwh":
            return self._cast(obs, top.fields)
        return self._characteristic(obs, ctx, top.fields)

    def _cast(self, obs: Observed, fields) -> Iterable[Event]:
        values = {f.number: f.value for f in fields if f.wire == 0}
        spell = values.get(4)
        if spell is None:
            return ()
        return (SpellCast(obs.env.ts, obs.who, obs.who, spell, values.get(1)),)

    def _characteristic(self, obs: Observed, ctx: Context, fields) -> Iterable[Event]:
        fighter = None
        entry = None
        for f in fields:
            if f.number == 1 and f.wire == 0:
                fighter = _signed(f.value)
            elif f.number == 3 and f.is_message:
                entry = _entry(f.value)
        if fighter is None or entry is None:
            return ()
        char_id, value = entry
        return (CharacteristicChange(obs.env.ts, obs.who, obs.who, fighter,
                                     ctx.name_of(fighter), char_id,
                                     name_of(char_id), value),)


def _entry(fields):
    """Extrait (identifiant de caracteristique, valeur) du sous-message."""
    for f in fields:
        if f.number != 5 or not f.is_message:
            continue
        char_id = None
        value = None
        for c in f.value:
            if c.number == 1 and c.wire == 0:
                char_id = c.value
            elif c.number == 2 and c.is_message:
                for g in c.value:
                    if g.number == 2 and g.wire == 0:
                        value = _signed(g.value)
            elif c.number == 5 and c.is_message:
                # forme detaillee : le champ 4 porte la variation
                for g in c.value:
                    if g.number == 4 and g.wire == 0:
                        value = _signed(g.value)
        if char_id is not None:
            return char_id, value
    return None


def _signed(value: int) -> int:
    """Les identifiants d'entites et les variations peuvent etre negatifs."""
    return value - (1 << 64) if value >= (1 << 63) else value
