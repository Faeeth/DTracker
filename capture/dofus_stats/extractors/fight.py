"""Fin de combat.

Le message `jyg` porte, pour chaque participant, l'experience gagnee, les kamas
et le butin. Structure etablie par recoupement avec des combats dont les gains
etaient connus :

    2: {                            une entree par participant
      2: {                          recompenses
        1: <kamas>
        2: {                        groupe de butin, repete
          1: { 2: <quantite>, 4: <type d'objet> }    repete dans le groupe
          5: <identifiant de la source, commun a tous les participants>
        }
      }
      3: {
        1: <identifiant du personnage>
        2: {
          1: { 2: { 1: <experience gagnee>
                    2: <seuil du niveau suivant>
                    5: <experience totale apres>
                    6: <seuil du niveau courant> } }
          2: <niveau>
        }
      }
      4: <issue>  2 chez les gagnants, absent chez les perdants
    }
    4: <duree du combat, en millisecondes>
    6: <identifiant du donjon, absent hors donjon>
    8: -1 en int64, constant

Le champ 4 de premier niveau est la duree, celle que le jeu affiche a la fin du
combat. Etabli en le confrontant, sur douze captures, au temps ecoule entre
l'engagement observe et l'annonce de la fin : il lui est toujours inferieur de
quelques secondes a une demi-minute, l'ecart etant la phase de placement, que
le jeu ne compte pas. Un boss annonce 492 716 ms pour 520 s observees, un
combat court 9 458 ms pour 15 s.

Cette valeur vaut mieux qu'un chronometre tenu par l'appelant, pour deux
raisons. Elle dit ce que le jeu dit — placement exclu. Et l'evenement de fin
est emis avec une seconde de retard, le temps que les noms arrivent : a cet
instant, un chronometre local a souvent deja ete arrete par la sortie de
combat, et rendait zero.

Le meme combat est annonce a chacun des clients presents. On ne retient que la
premiere annonce vue pour un combat donne, sans quoi un combat a quatre
personnages serait compte quatre fois.

Les combattants d'en face figurent dans la meme liste, mais sans recompense ni
identite : seul leur identifiant de combattant est la, et il est negatif. Ce
qu'ils sont se lit ailleurs — voir `roster.py`. Sur un combat perdu, ce sont eux
qui portent l'issue gagnante.

Le nom des participants n'est pas dans ce message : il arrive quelques
millisecondes plus tard, avec `ilw`. L'evenement est donc retenu brievement, le
temps que le contexte se complete, puis emis avec les noms resolus.
"""
from __future__ import annotations

from typing import Iterable

from ..events import (WINNER, FightEnd, FightOpponent, FightParticipant,
                      ItemStack)
from ..protocol.wire import Field
from ..session import Observed
from .base import Context, Extractor

DEDUP_WINDOW = 3.0       # secondes
HOLD_DELAY = 1.0         # retenue avant emission, le temps que les noms arrivent


class FightEndExtractor(Extractor):
    codes = frozenset({"jyg"})

    def __init__(self) -> None:
        self._seen: list[tuple[float, frozenset]] = []
        self._held: list[FightEnd] = []

    def handle(self, obs: Observed, ctx: Context) -> Iterable[FightEnd]:
        top = obs.env.top
        if top is None:
            return ()
        participants = [p for p in (_participant(f.value) for f in top.fields
                                    if f.number == 2 and f.is_message) if p]
        if not participants:
            return ()
        scalaires = {f.number: f.value for f in top.fields if not f.is_message}
        millisecondes = scalaires.get(4)
        duree = millisecondes / 1000 if isinstance(millisecondes, int) else None
        for p in participants:
            ctx.value(p.loot)
        signature = frozenset(p.character_id for p in participants if p.character_id)
        ts = obs.env.ts
        self._seen = [(t, s) for t, s in self._seen if ts - t <= DEDUP_WINDOW]
        if any(s == signature for _, s in self._seen):
            return ()
        self._seen.append((ts, signature))
        self._held.append(
            FightEnd(ts, obs.who, participants, duration=duree,
                     opponents=_opponents(top.fields, ctx, obs.who,
                                          participants)))
        return ()

    def tick(self, ts: float, ctx: Context) -> Iterable[FightEnd]:
        ready = [e for e in self._held if ts - e.ts >= HOLD_DELAY]
        if not ready:
            return ()
        self._held = [e for e in self._held if ts - e.ts < HOLD_DELAY]
        return [self._resolve(e, ctx) for e in ready]

    def flush(self, ctx: Context) -> Iterable[FightEnd]:
        ready, self._held = self._held, []
        return [self._resolve(e, ctx) for e in ready]

    @staticmethod
    def _resolve(event: FightEnd, ctx: Context) -> FightEnd:
        for p in event.participants:
            p.name = ctx.name_of(p.character_id) or p.name
        return event


def _opponents(fields: list[Field], ctx: Context, who: str,
               participants: list[FightParticipant]) -> list[FightOpponent]:
    """Les combattants d'en face, quelle que soit l'issue.

    Ils se reconnaissent a leur identifiant : negatif chez ceux d'en face,
    positif chez les personnages. C'est le seul critere, et il tient dans les
    deux sens — un combat perdu est un combat ou **ils** portent l'issue
    gagnante, et les ecarter pour cela laissait la defaite sans adversaires.

    Un personnage qui abandonne n'est donc pas des leurs : il perd le combat
    sans devenir pour autant un adversaire, et son identifiant n'a rien a
    faire dans la table des monstres.

    On les resout tout de suite, pendant que la table du combat est encore
    celle-ci — le combat suivant la videra.
    """
    # Les tables a consulter : celle du client qui rapporte, et celles de ses
    # compagnons de combat.
    #
    # L'attaquant n'est **jamais** informe de la composition du groupe : son
    # client la connait deja par la carte, et le serveur ne la lui repete pas.
    # Seuls les allies qui rejoignent recoivent la liste des combattants —
    # verifie sur cinq captures, ou l'attaquant recoit toujours moins de `kae`
    # que les autres, et un combat mene en solo n'en produit qu'un seul, vide.
    #
    # Se limiter au client qui rapporte laissait donc le combat anonyme une
    # fois sur deux, au gre de celui dont l'annonce arrivait la premiere. On
    # elargit aux participants du **meme** combat : ils ont recu les memes
    # identifiants pour les memes monstres. Pas au-dela — quatre personnages
    # qui farment chacun leur groupe ont chacun un `-1` different.
    temoins = [who]
    for p in participants:
        nom = ctx.name_of(p.character_id) or p.name
        if nom and nom not in temoins:
            temoins.append(nom)

    en_face = []
    for f in fields:
        if f.number != 2 or not f.is_message:
            continue
        issue = ident = None
        for g in f.value:
            if g.number == 4 and not g.is_message:
                issue = g.value
            elif g.number == 3 and g.is_message:
                for h in g.value:
                    if h.number == 1 and not h.is_message:
                        ident = _signed(h.value)
        # Un identifiant positif est un personnage : les combattants d'en
        # face sont numerotes en negatif, et le sont dans toutes les captures.
        if ident is None or ident >= 0:
            continue
        connu = _resolve(ctx, temoins, ident)
        en_face.append(FightOpponent(
            ident,
            monster_id=connu[0] if connu else None,
            grade=connu[1] if connu else None,
            outcome=issue))
    return en_face


def _resolve(ctx: Context, temoins: list[str],
             ident: int) -> tuple[int, int] | None:
    """Le monstre derriere un identifiant, vu par l'un des combattants."""
    for nom in temoins:
        connu = ctx.monster_of(nom, ident)
        if connu is not None:
            return connu
    return None


def _signed(value: int) -> int:
    """Les varints arrivent non signes : le combattant -1 vaut 2^64 - 1."""
    return value - (1 << 64) if value >= (1 << 63) else value


def _participant(fields: list[Field]) -> FightParticipant | None:
    part = FightParticipant()
    seen = False
    for f in fields:
        if f.number == 4 and f.wire == 0:
            part.outcome = f.value
        elif f.number == 2 and f.is_message:
            _rewards(f.value, part)
            seen = True
        elif f.number == 3 and f.is_message:
            seen = _identity(f.value, part) or seen
    return part if seen else None


def _rewards(fields: list[Field], part: FightParticipant) -> None:
    for f in fields:
        if f.number == 1 and f.wire == 0:
            part.kamas = f.value
        elif f.number == 2 and f.is_message:
            _drop_group(f.value, part)


def _drop_group(fields: list[Field], part: FightParticipant) -> None:
    """Un groupe porte une source et, sous le meme numero de champ repete,
    autant d'objets que la source en a laches."""
    source = None
    stacks: list[ItemStack] = []
    for c in fields:
        if c.number == 5 and c.wire == 0:
            source = c.value
        elif c.number == 1 and c.is_message:
            item_id = quantity = None
            for g in c.value:
                if g.number == 4 and g.wire == 0:
                    item_id = g.value
                elif g.number == 2 and g.wire == 0:
                    quantity = g.value
            if item_id is not None:
                stacks.append(ItemStack(item_id, quantity or 1))
    for stack in stacks:
        stack.source_id = source
    part.loot.extend(stacks)


def _identity(fields: list[Field], part: FightParticipant) -> bool:
    """L'entree decrit-elle un personnage ?

    A l'identifiant, et a lui seul. L'experience gagnee semblait le marqueur
    naturel — un personnage en gagne, un monstre non — mais le wire format
    protobuf n'emet pas les valeurs nulles : un combat perdu ne rapporte rien,
    donc ne porte pas ce champ, donc n'etait pas reconnu. Le recapitulatif
    tout entier tombait alors, et le combat disparaissait de la liste.

    L'identifiant, lui, est toujours la. Il est positif chez les personnages
    et negatif chez les combattants d'en face : c'est ce qui garde les
    monstres hors des participants, ou ils fausseraient tous les totaux.
    """
    found = False
    for f in fields:
        if f.number == 1 and f.wire == 0:
            part.character_id = f.value
            found = _signed(f.value) > 0
        elif f.number == 2 and f.is_message:
            for c in f.value:
                if c.number == 2 and c.wire == 0:
                    part.level = c.value
                elif c.number == 1 and c.is_message:
                    for g in c.value:
                        if g.number != 2 or not g.is_message:
                            continue
                        for h in g.value:
                            if h.wire != 0:
                                continue
                            if h.number == 1:
                                part.xp = h.value
                            elif h.number == 2:
                                part.xp_next = h.value
                            elif h.number == 5:
                                part.xp_total = h.value
                            elif h.number == 6:
                                part.xp_floor = h.value
    return found
