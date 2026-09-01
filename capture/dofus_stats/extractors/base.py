"""Socle des extracteurs.

Un extracteur observe les messages dont le code l'interesse et produit des
evenements. Ajouter une donnee au perimetre de la bibliotheque (les
caracteristiques a l'ouverture de la page statistiques, le solde a l'ouverture
de l'inventaire, ...) revient a ecrire une classe et a l'enregistrer : ni le
pipeline reseau ni le code appelant ne changent.

Certains extracteurs ne produisent rien et se contentent d'entretenir un etat
partage — la correspondance identifiant -> nom de personnage, par exemple. Ils
sont declares prioritaires pour que l'etat soit a jour quand les autres
travaillent.
"""
from __future__ import annotations

from typing import Iterable, Iterator

from ..events import Event
from ..session import Observed


class Context:
    """Etat partage entre extracteurs, alimente au fil du flux."""

    def __init__(self) -> None:
        self.character_names: dict[int, str] = {}
        # identifiant -> classe (1 a 20). Ne vient que de `ilw`, donc d'un
        # passage sur la carte : un flux entierement en combat l'ignore.
        self.character_breeds: dict[int, int] = {}
        self.prices: dict[int, int] = {}
        # personnage -> identifiant unique -> (type d'objet, derniere quantite connue)
        self.items: dict[str, dict[int, tuple[int, int]]] = {}
        self.kamas: dict[str, int] = {}
        # personnage -> (instant, provenance) de sa derniere commande. Ce qui
        # entre dans l'inventaire juste apres n'est pas un gain : c'est un
        # deplacement, ou la recompense d'un succes reclame.
        self.commands: dict[str, tuple[float, str]] = {}
        # personnage -> (instant, identifiant unique) du dernier objet utilise.
        # Ce que le serveur dit ensuite de cet identifiant-la est la
        # decroissance de l'objet consomme, pas un gain.
        self.consumed: dict[str, tuple[float, int]] = {}
        # personnage -> (instant, identifiant unique) du dernier objet utilise.
        # Ce que le serveur dit ensuite de cet identifiant-la est la
        # decroissance de l'objet consomme, pas un gain.
        self.consumed: dict[str, tuple[float, int]] = {}
        # personnage -> identifiant de combattant (negatif) -> (monstre, grade)
        #
        # Par personnage, et non en commun : chaque client numerote les
        # combattants de son propre combat. Quatre personnages qui farment
        # chacun leur groupe produisent quatre `-1` differents dans le meme
        # flux. La table est videe a l'entree en combat, les identifiants
        # etant rejoues d'un combat au suivant.
        self.fighters: dict[str, dict[int, tuple[int, int]]] = {}

    def name_of(self, character_id: int | None) -> str | None:
        return self.character_names.get(character_id) if character_id else None

    def breed_of(self, character_id: int | None) -> int | None:
        return self.character_breeds.get(character_id) if character_id else None

    def price_of(self, item_id: int) -> int | None:
        return self.prices.get(item_id)

    def origin_of(self, who: str, ts: float, window: float) -> str:
        """D'ou vient un objet entrant a cet instant, pour ce personnage.

        `"pickup"` sauf si une commande du client — deplacement, brisage,
        succes reclame — vient de partir. Voir `extractors/origin.py`.
        """
        connu = self.commands.get(who)
        if connu is None:
            return "pickup"
        depuis, provenance = connu
        return provenance if 0 <= ts - depuis <= window else "pickup"

    def consumed_uid(self, who: str, ts: float, window: float) -> int | None:
        """L'objet que ce personnage vient d'utiliser, s'il y a moins de
        `window` secondes."""
        connu = self.consumed.get(who)
        if connu is None:
            return None
        depuis, uid = connu
        return uid if 0 <= ts - depuis <= window else None

    def consumed_uid(self, who: str, ts: float, window: float) -> int | None:
        """L'objet que ce personnage vient d'utiliser, s'il y a moins de
        `window` secondes."""
        connu = self.consumed.get(who)
        if connu is None:
            return None
        depuis, uid = connu
        return uid if 0 <= ts - depuis <= window else None

    def monster_of(self, who: str,
                   fighter_id: int | None) -> tuple[int, int] | None:
        """Le monstre et son grade derriere un identifiant de combattant."""
        if fighter_id is None:
            return None
        return self.fighters.get(who, {}).get(fighter_id)

    def learn_fighter(self, who: str, fighter_id: int,
                      monster_id: int, grade: int) -> None:
        self.fighters.setdefault(who, {})[fighter_id] = (monster_id, grade)

    def forget_fighters(self, who: str) -> None:
        self.fighters.pop(who, None)

    def value(self, stacks) -> None:
        """Renseigne le prix unitaire des lots dont le type a un prix connu."""
        for stack in stacks:
            if stack.unit_price is None:
                stack.unit_price = self.prices.get(stack.item_id)

    def item_type(self, who: str, uid: int) -> int | None:
        known = self.items.get(who, {}).get(uid)
        return known[0] if known else None

    def item_quantity(self, who: str, uid: int) -> int | None:
        known = self.items.get(who, {}).get(uid)
        return known[1] if known else None

    def learn_item(self, who: str, uid: int, item_id: int | None,
                   quantity: int | None = None) -> None:
        """Enregistre le type d'un objet, et sa quantite si elle est connue.

        Un objet deja connu garde son type si la source n'en fournit pas ; une
        quantite absente n'ecrase pas celle deja relevee.
        """
        table = self.items.setdefault(who, {})
        previous = table.get(uid)
        kind = item_id if item_id is not None else (previous[0] if previous else None)
        qty = quantity if quantity is not None else (previous[1] if previous else None)
        if kind is not None or qty is not None:
            table[uid] = (kind, qty)


class Extractor:
    """Base a heriter. `codes` limite les messages transmis a `handle`."""

    codes: frozenset[str] = frozenset()
    priority: int = 100          # plus bas = execute plus tot

    def start(self, ctx: Context) -> None:
        """Appele une fois avant le premier message. Sert aux extracteurs qui
        doivent amorcer le contexte depuis une source exterieure."""

    def handle(self, obs: Observed, ctx: Context) -> Iterable[Event]:
        return ()

    def tick(self, ts: float, ctx: Context) -> Iterable[Event]:
        """Appele pour chaque message, quel que soit son code.

        Sert aux extracteurs qui retiennent un evenement le temps que le
        contexte se complete : certaines informations n'arrivent qu'apres le
        message qui les motive.
        """
        return ()

    def flush(self, ctx: Context) -> Iterable[Event]:
        """Evenements restant en attente en fin de flux."""
        return ()


class Pipeline:
    """Diffuse les messages aux extracteurs et rend leurs evenements."""

    def __init__(self, extractors: list[Extractor] | None = None):
        self.extractors = sorted(extractors or [], key=lambda e: e.priority)
        self.context = Context()
        self._by_code: dict[str, list[Extractor]] = {}
        self._catch_all: list[Extractor] = []
        for ex in self.extractors:
            if ex.codes:
                for code in ex.codes:
                    self._by_code.setdefault(code, []).append(ex)
            else:
                self._catch_all.append(ex)
        # `tick` et `flush` sont appeles pour chaque message, mais deux
        # extracteurs seulement les redefinissent. On retient lesquels une
        # fois pour toutes plutot que de traverser la liste entiere a chaque
        # message pour n'y rien faire.
        self._ticking = [ex for ex in self.extractors
                         if type(ex).tick is not Extractor.tick]
        self._flushing = [ex for ex in self.extractors
                          if type(ex).flush is not Extractor.flush]
        for ex in self.extractors:
            ex.start(self.context)

    def feed(self, obs: Observed) -> Iterator[Event]:
        for ex in self._by_code.get(obs.env.code, ()):
            yield from ex.handle(obs, self.context)
        for ex in self._catch_all:
            yield from ex.handle(obs, self.context)
        for ex in self._ticking:
            yield from ex.tick(obs.env.ts, self.context)

    def flush(self) -> Iterator[Event]:
        for ex in self._flushing:
            yield from ex.flush(self.context)


def default_extractors() -> list[Extractor]:
    """Jeu d'extracteurs livre avec la bibliotheque."""
    from .achievement import AchievementExtractor
    from .challenge import ChallengeExtractor
    from .character import CharacterIndexExtractor, InventoryIndexExtractor
    from .character_state import CharacterStateExtractor
    from .characteristics import CharacteristicsExtractor
    from .fight import FightEndExtractor
    from .fight_context import FightContextExtractor
    from .inventory import InventoryExtractor
    from .effects import EffectExtractor
    from .origin import OriginExtractor
    from .fight_flow import FightFlowExtractor
    from .pods import PodsExtractor
    from .price import PriceTableExtractor
    from .roster import RosterExtractor
    from .spells import SpellExtractor

    return [
        PriceTableExtractor(),
        OriginExtractor(),
        RosterExtractor(),
        InventoryExtractor(),
        CharacterIndexExtractor(),
        InventoryIndexExtractor(),
        CharacterStateExtractor(),
        CharacteristicsExtractor(),
        PodsExtractor(),
        FightContextExtractor(),
        FightEndExtractor(),
        ChallengeExtractor(),
        FightFlowExtractor(),
        SpellExtractor(),
        EffectExtractor(),
        AchievementExtractor(),
    ]
