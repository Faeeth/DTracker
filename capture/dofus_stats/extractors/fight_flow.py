"""Deroulement d'un combat : tours, degats, morts, points de vie.

Correspondances etablies en confrontant une capture au recit detaille du
joueur, action par action, et au journal de combat du jeu.

    jxz  2: <numero>                     numero du tour
    jxh  2: <combattant>                 fin du tour de ce combattant
    jxy  (C->S, vide)                    le joueur a clique sur fin de tour
    kuq  1: <actuels> 4: <maximum>       points de vie
    jwe  14: <code> 40: {2: cible, 3: degats, 5: erosion}   degats subis
    jwe  14: 103 4: {1: <combattant>}    mort

Le code porte par `jwe` designe l'element des degats. Correspondance etablie sur
sept lancers de sorts dont l'element etait connu, sans exception :

    96  eau      Larme de Sadida, Ethylo
    97  terre    Pression
    98  air      Protection des Champs, Schnaps
    99  feu      Mot Turbulent

Le neutre n'a pas encore ete observe. La detection des degats ne repose donc pas
sur cette liste mais sur la forme du message — un champ 40 portant une cible et
un montant — pour rester valable sur un element inconnu.

Le champ 40.5 porte l'erosion : les points de vie maximum perdus
definitivement. Il vaut exactement `degats x taux d'erosion`, verifie au point
pres sur six coups a trois taux differents lors d'un duel ou le taux etait connu
a chaque instant. Sur un coup mortel la valeur echappe a cette regle et est
rapportee telle quelle.

Verification : sur un combat, les degats lus (86, 74, 90) reproduisent
exactement le journal du jeu, et leur somme egale les points de vie du monstre.
"""
from __future__ import annotations

from typing import Iterable

from ..events import Event, FighterDamage, FighterDeath, FighterHealth, TurnEnd, TurnStart
from ..session import Observed
from .base import Context, Extractor

DEATH_CODE = 103

# Element des degats, deduit du code d'action.
ELEMENTS = {96: "eau", 97: "terre", 98: "air", 99: "feu"}
CLICK_WINDOW = 1.0       # delai max entre le clic du joueur et la fin annoncee


class FightFlowExtractor(Extractor):
    codes = frozenset({"jxz", "jxh", "jxy", "kuq", "jwe"})
    priority = 40

    def __init__(self) -> None:
        self._clicks: dict[str, float] = {}

    def handle(self, obs: Observed, ctx: Context) -> Iterable[Event]:
        top = obs.env.top
        if top is None:
            return ()
        handler = getattr(self, "_on_" + obs.env.code, None)
        return handler(obs, ctx, top.fields) if handler else ()

    def _on_jxz(self, obs, ctx, fields) -> Iterable[Event]:
        for f in fields:
            if f.number == 2 and f.wire == 0:
                return (TurnStart(obs.env.ts, obs.who, obs.who, f.value),)
        return ()

    def _on_jxy(self, obs, ctx, fields) -> Iterable[Event]:
        """Requete cliente : le joueur met fin a son tour.

        Elle est retenue au nom du personnage qui clique, pas du client qui la
        voit passer : la fin de tour est ensuite annoncee a TOUS les clients, et
        c'est le combattant designe dans l'annonce qu'il faut rapprocher du clic.
        """
        self._clicks[obs.who] = obs.env.ts
        return ()

    def _on_jxh(self, obs, ctx, fields) -> Iterable[Event]:
        for f in fields:
            if f.number != 2 or f.wire != 0:
                continue
            fighter = _signed(f.value)
            name = ctx.name_of(fighter)
            clicked = self._clicks.get(name) if name else None
            requested = clicked is not None and obs.env.ts - clicked <= CLICK_WINDOW
            return (TurnEnd(obs.env.ts, obs.who, obs.who, fighter, name, requested),)
        return ()

    def _on_kuq(self, obs, ctx, fields) -> Iterable[Event]:
        values = {f.number: f.value for f in fields if f.wire == 0}
        current, maximum = values.get(1), values.get(4)
        if current is None or maximum is None:
            return ()
        return (FighterHealth(obs.env.ts, obs.who, obs.who, current, maximum),)

    def _on_jwe(self, obs, ctx, fields) -> Iterable[Event]:
        code = None
        damage = death = None
        for f in fields:
            if f.number == 14 and f.wire == 0:
                code = f.value
            elif f.number == 40 and f.is_message:
                sub = {c.number: c.value for c in f.value if c.wire == 0}
                if 2 in sub and 3 in sub:
                    damage = (_signed(sub[2]), sub[3], sub.get(5))
            elif f.number == 4 and f.is_message:
                for c in f.value:
                    if c.number == 1 and c.wire == 0:
                        death = _signed(c.value)
        if code == DEATH_CODE and death is not None:
            return (FighterDeath(obs.env.ts, obs.who, obs.who, death,
                                 ctx.name_of(death)),)
        if damage is not None:
            target, amount, erosion = damage
            return (FighterDamage(obs.env.ts, obs.who, obs.who, target,
                                  ctx.name_of(target), amount, code,
                                  ELEMENTS.get(code), erosion),)
        return ()


def _signed(value: int) -> int:
    """Les entites non joueuses portent un identifiant negatif."""
    return value - (1 << 64) if value >= (1 << 63) else value
