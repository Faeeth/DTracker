"""Table des prix moyens.

Le serveur diffuse, dans un unique message `ivi`, le prix moyen de chaque type
d'objet : environ 9 700 entrees, une centaine de kilo-octets. Structure :

    2: { 1: <type d'objet>, 2: <prix moyen> }      repete

Ce message n'arrive qu'a certains moments — a la connexion, ou a l'ouverture
d'une interface marchande. Une capture qui commence apres ne le contient pas, et
les prix y seront donc inconnus.

La bibliotheque ne conserve rien entre deux lectures : elle rend la table telle
qu'elle passe, dans un evenement `PriceTable`. A l'appelant de la garder s'il en
a besoin, et de la reinjecter via le parametre `prices` du lecteur.
"""
from __future__ import annotations

from typing import Iterable

from ..events import PriceTable
from ..session import Observed
from .base import Context, Extractor


class PriceTableExtractor(Extractor):
    codes = frozenset({"ivi"})
    priority = 5          # avant les extracteurs qui valorisent du butin

    def handle(self, obs: Observed, ctx: Context) -> Iterable[PriceTable]:
        top = obs.env.top
        if top is None:
            return ()
        prices: dict[int, int] = {}
        for f in top.fields:
            if f.number != 2 or not f.is_message:
                continue
            entry = {c.number: c.value for c in f.value if c.wire == 0}
            item_id, price = entry.get(1), entry.get(2)
            if item_id is not None and price is not None:
                prices[item_id] = price
        if not prices:
            return ()
        ctx.prices.update(prices)
        return (PriceTable(obs.env.ts, obs.who, prices),)
