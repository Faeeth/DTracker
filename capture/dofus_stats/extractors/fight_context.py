"""Entree et sortie de combat.

Le serveur signale un changement de contexte de jeu en deux temps : `kml`
detruit le contexte courant, puis `kmp` cree le suivant. Le champ 1 de `kmp`
porte le type de contexte — 1 pour le combat, absent (donc zero) pour le jeu
normal.

Sequence observee a l'engagement :

    hqa  C->S  1: <identifiant du groupe de monstres>     requete d'attaque
    kml  S->C  (vide)                                     fin du contexte courant
    kmp  S->C  1: 1                                       contexte de combat

Et a la sortie :

    jyg  S->C  recapitulatif de fin de combat
    kml  S->C  (vide)
    kmp  S->C  (vide)                                     retour au jeu normal

Pendant la phase de placement, deux autres messages circulent :

    kmw  C->S  1: <identifiant du combattant a exclure>    exclusion
    jxa  S->C  (vide)                                      recu par l'exclu
    jzy  C->S  1: <identifiant> 2: <case>                  placement

`kmp` arrive a chaque client engage : un combat a quatre personnages produit
donc quatre entrees en combat, une par personnage, ce qui est l'information
utile. La requete `hqa`, elle, n'est emise que par le client qui declenche.
"""
from __future__ import annotations

from typing import Iterable

from ..events import Event, FighterKicked, FighterPlaced, FightLeave, FightStart
from ..session import Observed
from .base import Context, Extractor

FIGHT_CONTEXT = 1
ATTACK_WINDOW = 5.0      # delai max entre la requete d'attaque et le changement de contexte


class FightContextExtractor(Extractor):
    codes = frozenset({"kmp", "hqa", "kmw", "jzy"})
    priority = 15

    def __init__(self) -> None:
        self._attacks: dict[str, tuple[float, int]] = {}

    def handle(self, obs: Observed, ctx: Context) -> Iterable[Event]:
        top = obs.env.top
        if top is None:
            return ()
        if obs.env.code == "hqa":
            return self._attack(obs, top.fields)
        if obs.env.code == "kmw":
            return self._kick(obs, ctx, top.fields)
        if obs.env.code == "jzy":
            return self._place(obs, ctx, top.fields)
        return self._context(obs, top.fields)

    def _attack(self, obs: Observed, fields) -> Iterable[Event]:
        """Requete d'attaque : on retient la cible, le contexte suivra."""
        for f in fields:
            if f.number == 1 and f.wire == 0:
                self._attacks[obs.who] = (obs.env.ts, _signed(f.value))
        return ()

    def _kick(self, obs: Observed, ctx: Context, fields) -> Iterable[Event]:
        for f in fields:
            if f.number == 1 and f.wire == 0:
                return (FighterKicked(obs.env.ts, obs.who, obs.who,
                                      f.value, ctx.name_of(f.value)),)
        return ()

    def _place(self, obs: Observed, ctx: Context, fields) -> Iterable[Event]:
        values = {f.number: f.value for f in fields if f.wire == 0}
        fighter, cell = values.get(1), values.get(2)
        if fighter is None or cell is None:
            return ()
        return (FighterPlaced(obs.env.ts, obs.who, obs.who, fighter,
                              ctx.name_of(fighter), cell),)

    def _context(self, obs: Observed, fields) -> Iterable[Event]:
        kind = 0
        for f in fields:
            if f.number == 1 and f.wire == 0:
                kind = f.value
        if kind != FIGHT_CONTEXT:
            return (FightLeave(obs.env.ts, obs.who, obs.who),)

        group = None
        initiated = False
        pending = self._attacks.pop(obs.who, None)
        if pending and obs.env.ts - pending[0] <= ATTACK_WINDOW:
            group, initiated = pending[1], True
        return (FightStart(obs.env.ts, obs.who, obs.who, group, initiated),)


def _signed(value: int) -> int:
    """Les entites non joueuses portent un identifiant negatif."""
    return value - (1 << 64) if value >= (1 << 63) else value
