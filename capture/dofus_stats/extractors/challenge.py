"""Challenges de combat.

Quatre messages jalonnent la vie d'un challenge :

    kwx  S->C  1: 15  2: {1: <bonus>, 2: <identifiant>, 4: <bonus>, 5: 2}  repete
    kwv  C->S  1: <identifiant>                       le groupe choisit
    kwh  S->C  1: {...}                               confirmation du choix
    kwu  S->C  2: {...} repete                        challenges reellement actifs
    kwl  S->C  1: <identifiant>  2: 1                 resultat, en fin de combat

`kwu` fait autorite sur ce qui est en jeu, et non `kwv` : on n'en choisit qu'un,
il peut y en avoir plusieurs. Quatre situations ont ete observees, toutes avec
`kwx` proposant une paire :

    combat ordinaire   propose 20 et 8, choisi 20        -> kwu : 20
    donjon             propose 20 et 42, choisi 20       -> kwu : 20 et 973
    donjon             deux paires proposees a la suite  -> kwu : les deux choisis
    boss               propose 971 et 45, choisi 971     -> kwu : 971, 45
                                                             et trois objectifs

Le second challenge d'un donjon n'a donc jamais ete propose — c'est le donjon
qui l'ajoute. Sur le boss en revanche, c'est la proposition ecartee qui reste
en jeu, et elle recoit un resultat comme les autres. Deduire ce qui est actif
des seuls choix serait faux dans les deux sens.

Rapprocher `kwx` et `kwv` de `kwu` permet de dire d'ou vient chaque challenge —
choisi, ecarte, impose — ce que le protocole n'ecrit nulle part mais qui se
lit sans ambiguite de la comparaison.

Le bonus est un pourcentage, porte a l'identique par les champs 1 et 4.

Le resultat se lit a la presence du champ 2 : il vaut 1 en cas de reussite et
n'est pas transmis en cas d'echec, le wire format protobuf omettant les valeurs
nulles. Verifie sur deux combats aux issues opposees : un challenge reussi
annonce `1: 20  2: 1`, un challenge echoue `1: 964` seul.

Le profil de recompense — experience ou butin, reglable par personnage — ne
circule pas ici : les quatre clients d'un meme groupe recoivent des messages
strictement identiques. Il reste donc soit dans le profil de compte, soit
entierement cote client.
"""
from __future__ import annotations

from typing import Iterable

from ..events import (
    ChallengeActive,
    ChallengeOffer,
    ChallengeResult,
    ChallengeSelected,
    Event,
)
from ..session import Observed
from .base import Context, Extractor


class ChallengeExtractor(Extractor):
    codes = frozenset({"kwx", "kwv", "kwu", "kwl"})
    priority = 50

    def handle(self, obs: Observed, ctx: Context) -> Iterable[Event]:
        top = obs.env.top
        if top is None:
            return ()
        if obs.env.code == "kwx":
            return self._offer(obs, top.fields)
        if obs.env.code == "kwv":
            return self._selected(obs, top.fields)
        if obs.env.code == "kwu":
            return self._active(obs, top.fields)
        return self._result(obs, top.fields)

    def _active(self, obs: Observed, fields) -> Iterable[Event]:
        actifs: list[tuple[int, int]] = []
        for f in fields:
            if f.number != 2 or not f.is_message:
                continue
            sub = {c.number: c.value for c in f.value if c.wire == 0}
            ident, bonus = sub.get(2), sub.get(1)
            if ident is not None:
                actifs.append((ident, bonus))
        if not actifs:
            return ()
        return (ChallengeActive(obs.env.ts, obs.who, obs.who, actifs),)

    def _offer(self, obs: Observed, fields) -> Iterable[Event]:
        proposes: list[tuple[int, int]] = []
        for f in fields:
            if f.number != 2 or not f.is_message:
                continue
            sub = {c.number: c.value for c in f.value if c.wire == 0}
            ident, bonus = sub.get(2), sub.get(1)
            if ident is not None:
                proposes.append((ident, bonus))
        if not proposes:
            return ()
        return (ChallengeOffer(obs.env.ts, obs.who, obs.who, proposes),)

    def _selected(self, obs: Observed, fields) -> Iterable[Event]:
        for f in fields:
            if f.number == 1 and f.wire == 0:
                return (ChallengeSelected(obs.env.ts, obs.who, obs.who, f.value),)
        return ()

    def _result(self, obs: Observed, fields) -> Iterable[Event]:
        values = {f.number: f.value for f in fields if f.wire == 0}
        ident = values.get(1)
        if ident is None:
            return ()
        # Champ 2 absent : le protobuf n'a pas transmis un zero, donc echec.
        return (ChallengeResult(obs.env.ts, obs.who, obs.who, ident,
                                values.get(2, 0) == 1),)
