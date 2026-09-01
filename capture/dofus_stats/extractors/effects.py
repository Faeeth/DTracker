"""Effets et etats appliques en combat.

Le message `jxm` decrit un effet pose sur un combattant :

    1: {
      1: {
        1:  <valeur de l'effet>
        2:  <combattant cible>
        3:  <numero d'ordre dans le combat>
        7:  <code de declenchement : "I", "TB", "TE">
        8:  <identifiant de l'effet>
        14: <sort a l'origine de l'effet>
      }
      2: <lanceur>
    }

Correspondances etablies contre le journal du jeu :

  - Pression appliquant « 10% Erosion » porte une valeur de 10 et le sort 13106 ;
  - Mot Stimulant accordant « 2 PA » porte une valeur de 2.

Mais le champ 1.1.1 ne porte pas toujours une valeur : sur d'autres effets du
meme combat il vaut 18647, 25807 ou 4247, et parfois exactement l'identifiant du
sort. Sa semantique depend du type d'effet, ce qui n'a pas ete elucide. Il est
rapporte tel quel, avec cette reserve, plutot que presente comme une valeur.

La duree n'est pas identifiee : le journal annonce deux tours la ou le message
porte un sous-message `6: {2: 4, 3: 1}` dont aucun champ ne vaut deux. Elle
n'est donc pas rapportee.

Le code de declenchement prend les valeurs "I", "TB" et "TE", vraisemblablement
immediat, debut et fin de tour, sans que cela ait ete verifie. Il est rapporte
tel quel.
"""
from __future__ import annotations

from typing import Iterable

from ..events import EffectApplied
from ..session import Observed
from .base import Context, Extractor


class EffectExtractor(Extractor):
    codes = frozenset({"jxm"})
    priority = 45

    def handle(self, obs: Observed, ctx: Context) -> Iterable[EffectApplied]:
        top = obs.env.top
        if top is None:
            return ()
        out = []
        for f in top.fields:
            if f.number != 1 or not f.is_message:
                continue
            caster = None
            detail = None
            for c in f.value:
                if c.number == 2 and c.wire == 0:
                    caster = _signed(c.value)
                elif c.number == 1 and c.is_message:
                    detail = _detail(c.value)
            if detail is None:
                continue
            target, value, effect_id, spell_id, trigger = detail
            out.append(EffectApplied(
                obs.env.ts, obs.who, obs.who, target, ctx.name_of(target),
                caster, ctx.name_of(caster), value, effect_id, spell_id, trigger))
        return out


def _detail(fields):
    """Extrait (cible, valeur, identifiant d'effet, sort, declenchement)."""
    target = value = effect_id = spell_id = None
    trigger = None
    for g in fields:
        if g.wire == 0:
            if g.number == 1:
                value = _signed(g.value)
            elif g.number == 2:
                target = _signed(g.value)
            elif g.number == 8:
                effect_id = g.value
            elif g.number == 14:
                spell_id = g.value
        elif g.number == 7 and isinstance(g.value, str):
            trigger = g.value
    if target is None and effect_id is None:
        return None
    return target, value, effect_id, spell_id, trigger


def _signed(value: int) -> int:
    """Les entites non joueuses portent un identifiant negatif."""
    if value is None:
        return None
    return value - (1 << 64) if value >= (1 << 63) else value
