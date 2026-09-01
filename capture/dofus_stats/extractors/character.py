"""Extracteurs d'etat : ils ne produisent rien mais renseignent le contexte."""
from __future__ import annotations

from typing import Iterable

from ..events import CharacterInfo, Event
from ..protocol import wire
from ..session import Observed
from .base import Context, Extractor

UID_MIN, UID_MAX = 1_000_000, 1 << 40


class CharacterIndexExtractor(Extractor):
    """Apprend ce qu'on peut savoir d'un personnage : son nom, sa classe.

    `ilw` decrit une entite sur la carte, `kae` un combattant. Les deux portent
    le meme motif : un sous-message `{1: {2: <nom>}, 2: <identifiant>}`. C'est ce
    qui permet de nommer les participants d'un combat, que les messages ne
    designent que par un identifiant numerique.

    Les deux sources sont necessaires : `ilw` n'arrive qu'au retour sur la
    carte, donc une capture entierement passee en combat ne le verrait jamais.

    La classe, elle, n'est que dans `ilw`, ou le bloc d'apparence la porte :

        1: { 2: <nom>  3: <niveau>  4: { ... 7: <classe> } }
        2: <identifiant>

    Etablie en confrontant huit personnages a leur classe connue — 1 Feca,
    2 Osamodas, 3 Enutrof, 7 Eniripsa, 8 Iop, 10 Sadida, 12 Pandawa,
    18 Ouginak — soit la numerotation de `breeds` dans les fichiers du client.
    Rien dans `kae` ne la reprend : un combattant croise sans etre passe par la
    carte reste donc sans classe.
    """

    codes = frozenset({"ilw", "kae"})
    priority = 10

    def handle(self, obs: Observed, ctx: Context) -> Iterable[Event]:
        top = obs.env.top
        if top is None:
            return ()
        appris = []
        for _, f in wire.walk(top.fields):
            if not f.is_message:
                continue
            name = ident = breed = None
            for c in f.value:
                if c.number == 1 and c.is_message:
                    for g in c.value:
                        if g.number == 2 and isinstance(g.value, str):
                            name = g.value
                        elif g.number == 4 and g.is_message:
                            for h in g.value:
                                if h.number == 7 and h.wire == 0:
                                    breed = h.value
                elif c.number == 2 and c.wire == 0:
                    ident = c.value
            if not (name and ident):
                continue
            # On n'annonce que ce qui change : `ilw` repasse a chaque retour
            # sur la carte, et repeter la meme fiche noierait le flux.
            connu = (ctx.character_names.get(ident),
                     ctx.character_breeds.get(ident))
            ctx.character_names[ident] = name
            if breed:
                ctx.character_breeds[ident] = breed
            if connu != (name, ctx.character_breeds.get(ident)):
                appris.append(CharacterInfo(
                    obs.env.ts, obs.who, character_id=ident, name=name,
                    breed=ctx.character_breeds.get(ident)))
        return appris


class InventoryIndexExtractor(Extractor):
    """Apprend la correspondance identifiant unique -> type d'objet.

    `iua` et `ivx` la fournissent ; `ivj`, qui annonce une nouvelle quantite, ne
    cite que l'identifiant unique. Sans cette table, un gain reste anonyme.

    L'inventaire complet n'arrive qu'a l'ouverture de la fenetre en jeu : une
    capture qui ne la contient pas ne peut nommer que les objets vus entrer.
    Rien n'est conserve d'une lecture a l'autre — a l'appelant de tenir son
    cache et de le reinjecter via le parametre `item_types` du lecteur.
    """

    codes = frozenset({"iua", "ivx", "ivj"})
    priority = 10

    def handle(self, obs: Observed, ctx: Context) -> Iterable[Event]:
        top = obs.env.top
        if top is None:
            return ()
        if obs.env.code == "ivj":
            self._quantity(obs, ctx, top.fields)
            return ()
        for _, f in wire.walk(top.fields):
            if not f.is_message:
                continue
            sub = {c.number: c.value for c in f.value if c.wire == 0}
            uid, item_id = sub.get(4), sub.get(1)
            if uid is not None and item_id is not None and UID_MIN <= uid < UID_MAX:
                ctx.learn_item(obs.who, uid, item_id, sub.get(3, 1))
        return ()

    def _quantity(self, obs: Observed, ctx: Context, fields) -> None:
        """Tient la quantite a jour, pour que le gain suivant soit calculable."""
        sub: dict[int, int] = {}
        for _, f in wire.walk(fields):
            if f.is_message:
                for c in f.value:
                    if c.wire == 0:
                        sub[c.number] = c.value
        uid, total = sub.get(2), sub.get(3)
        if uid is None or total is None or not (UID_MIN <= uid < UID_MAX):
            return
        ctx.learn_item(obs.who, uid, ctx.item_type(obs.who, uid), total)
