"""Entrees et sorties de l'inventaire, hors combat.

Deux messages annoncent un mouvement d'objet :

    iua  3.5: {1: <type>, 3: <quantite>, 4: <identifiant unique>}   objet entrant
    ivj  3:   {2: <identifiant unique>, 3: <nouvelle quantite>}     quantite mise a jour

`ivj` ne donne que le total apres coup. Le gain se deduit de la quantite
precedente, tenue par le contexte — d'ou l'interet de conserver l'inventaire
entre deux captures : sans cet historique, une recolte est vue mais son montant
reste inconnu.

Verifie sur une recolte annoncee : deux ramassages portant la quantite a 22 puis
65, pour des gains de six et cinq unites, et des pods montant de cinq — un par
unite pour la seconde ressource.

Le meme `iua` sert a un objet repris dans un coffre, aux runes d'un brisage et
aux recompenses d'un succes : rien dans le message ne dit d'ou l'objet vient.
Ceux-la ne sont pas des gains, et leur `origin` le dit — voir `origin.py`.
"""
from __future__ import annotations

from typing import Iterable

from ..events import ItemGained
from .origin import COMMAND_WINDOW, TRADE_WINDOW
from ..protocol import wire
from ..session import Observed
from .base import Context, Extractor

UID_MIN, UID_MAX = 1_000_000, 1 << 40


class InventoryExtractor(Extractor):
    """Emet les gains et pertes d'objets. Doit passer avant l'index, qui met a
    jour les quantites et ferait disparaitre le point de comparaison."""

    codes = frozenset({"iua", "ivj"})
    priority = 8

    def handle(self, obs: Observed, ctx: Context) -> Iterable[ItemGained]:
        top = obs.env.top
        if top is None:
            return ()
        if obs.env.code == "iua":
            return self._added(obs, ctx, top.fields)
        return self._updated(obs, ctx, top.fields)

    def _added(self, obs: Observed, ctx: Context, fields) -> Iterable[ItemGained]:
        out = []
        for _, f in wire.walk(fields):
            if not f.is_message:
                continue
            sub = {c.number: c.value for c in f.value if c.wire == 0}
            uid, item_id = sub.get(4), sub.get(1)
            if uid is None or item_id is None or not (UID_MIN <= uid < UID_MAX):
                continue
            quantity = sub.get(3, 1)
            known = ctx.item_quantity(obs.who, uid)
            gain = quantity - known if known is not None else quantity
            out.append(self._event(obs, ctx, item_id, gain, quantity, uid))
        return out

    def _updated(self, obs: Observed, ctx: Context, fields) -> Iterable[ItemGained]:
        sub: dict[int, int] = {}
        for _, f in wire.walk(fields):
            if f.is_message:
                for c in f.value:
                    if c.wire == 0:
                        sub[c.number] = c.value
        uid, total = sub.get(2), sub.get(3)
        if uid is None or total is None or not (UID_MIN <= uid < UID_MAX):
            return ()
        known = ctx.item_quantity(obs.who, uid)
        if known is None:
            # Objet jamais vu : on ne peut pas dire de combien il a augmente.
            return (self._event(obs, ctx, ctx.item_type(obs.who, uid), None, total, uid),)
        if total == known:
            return ()
        return (self._event(obs, ctx, ctx.item_type(obs.who, uid),
                            total - known, total, uid),)

    @staticmethod
    def _event(obs, ctx, item_id, gain, total, uid) -> ItemGained:
        price = ctx.price_of(item_id) if item_id is not None else None
        origin = ctx.origin_of(obs.who, obs.env.ts, COMMAND_WINDOW)
        # Ce que le partenaire avait pose dans la fenetre d'echange. Le
        # rapprochement se fait ici et non par une commande du client : celui
        # qui recoit n'en envoie aucune, c'est l'autre qui a donne.
        if origin == "pickup" and ctx.take_trade_offer(
                obs.who, obs.env.ts, item_id, TRADE_WINDOW):
            origin = "trade"
        # L'objet utilise decroit d'une unite, et le serveur l'annonce par le
        # meme message que le contenu obtenu. Les deux se distinguent a leur
        # identifiant : celui-la est l'objet que le client vient de nommer.
        if uid == ctx.consumed_uid(obs.who, obs.env.ts, COMMAND_WINDOW):
            origin = "consumed"
        return ItemGained(obs.env.ts, obs.who, obs.who, item_id, uid,
                          gain, total, price, origin=origin)
