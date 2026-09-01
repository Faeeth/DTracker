"""Composition du combat : qui est en face.

Le recapitulatif de fin de combat (`jyg`) nomme les perdants par un identifiant
de combattant negatif — `-1`, `-2`, ... — et rien d'autre. Ni nom, ni niveau,
ni espece. Ce qui manque est annonce plus tot, pendant le placement, par
`kae` :

    1: {
      3: <identifiant du groupe>
      5: {
        1: { 2: <identifiant du combattant>
             1: { 1: <niveau>, 2: <nom> }        pour un personnage
             5: { 1: <monstre>, 2: <grade> } }   pour un monstre
        ...                                      le champ 1 est repete
      }
    }

Le message est emis a chaque ajout de combattant, et reprend tous ceux deja
annonces : le dernier recu suffirait, mais les accumuler coute moins cher que
de deviner lequel est le dernier.

Les identifiants sont **propres a chaque client** et **rejoues d'un combat a
l'autre**. Quatre personnages qui farment chacun leur groupe emettent quatre
`-1` differents dans le meme flux ; les melanger donnait un combat sur trois
peuple de monstres pris chez le voisin. La table est donc tenue par
personnage, et videe a sa sortie de combat — pas a son entree : le serveur
annonce les combattants avant de dire au client qu'il entre en combat.

Une table vide vaut mieux qu'une table fausse : quand le combat a commence
avant l'ecoute, on ne sait pas qui etait en face, et on le dit.
"""
from __future__ import annotations

from typing import Iterable

from ..events import Event
from ..session import Observed
from .base import Context, Extractor

FIGHT_CONTEXT = 1


class RosterExtractor(Extractor):
    """N'emet rien : tient la table identifiant de combattant -> monstre."""

    codes = frozenset({"kae", "kmp"})
    priority = 10

    def handle(self, obs: Observed, ctx: Context) -> Iterable[Event]:
        top = obs.env.top
        if top is None:
            return ()
        if obs.env.code == "kmp":
            # A la sortie du combat, pas a l'entree : le serveur annonce les
            # combattants **avant** de dire au client qu'il entre en combat.
            # Vider a l'entree effacait tout ce qui venait d'arriver.
            if _contexte(top.fields) != FIGHT_CONTEXT:
                ctx.forget_fighters(obs.who)
            return ()
        for ident, monster_id, grade in _fighters(top.fields):
            ctx.learn_fighter(obs.who, ident, monster_id, grade)
        return ()


def _contexte(fields) -> int:
    for f in fields:
        if f.number == 1 and not f.is_message:
            return f.value
    return 0


def _fighters(fields):
    """(identifiant, monstre, grade) pour les combattants monstres d'un `kae`.

    Les personnages sont ignores : leur nom et leur niveau arrivent deja par
    `ilw`, et le recapitulatif les nomme lui-meme.
    """
    for corps in _messages(fields, 1):
        for conteneur in _messages(corps, 5):
            for entree in _messages(conteneur, 1):
                ident = monster_id = grade = None
                for f in entree:
                    if f.number == 2 and not f.is_message:
                        ident = _signed(f.value)
                    elif f.number == 5 and f.is_message:
                        for g in f.value:
                            if g.number == 1 and not g.is_message:
                                monster_id = g.value
                            elif g.number == 2 and not g.is_message:
                                grade = g.value
                if ident is not None and monster_id is not None:
                    yield ident, monster_id, grade or 1


def _messages(fields, number: int):
    for f in fields:
        if f.number == number and f.is_message:
            yield f.value


def _signed(value: int) -> int:
    """Les varints arrivent non signes : le combattant -1 vaut 2^64 - 1."""
    return value - (1 << 64) if value >= (1 << 63) else value
