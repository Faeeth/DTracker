"""Point d'entree de la bibliotheque.

    from dofus_stats import Reader, FightEnd

    for event in Reader.from_pcap("session.pcapng", hosts="hosts.json").events():
        if isinstance(event, FightEnd):
            print(event.total_xp, event.total_kamas)

La lecture d'un fichier et l'ecoute en direct passent par le meme chemin : seule
la source des trames change.
"""
from __future__ import annotations

from typing import Iterator

from .capture.live_source import LiveSource
from .capture.pcap_source import PcapSource
from .events import Event
from .extractors.base import Context, Extractor, Pipeline, default_extractors
from .net.identify import Client, load, snapshot
from .session import GAME_PORT, Session


class Reader:
    """Transforme un flux de trames en evenements de jeu."""

    def __init__(self, source, clients: list[Client] | None = None,
                 extractors: list[Extractor] | None = None, port: int = GAME_PORT,
                 prices: dict[int, int] | None = None,
                 item_types: dict[str, dict[int, int]] | None = None,
                 character_names: dict[int, str] | None = None,
                 character_breeds: dict[int, int] | None = None):
        """`prices` et `item_types` amorcent la lecture avec ce qui est deja connu.

        La bibliotheque ne conserve rien d'une lecture a l'autre : le prix d'un
        objet et le type associe a un identifiant unique n'arrivent qu'a certains
        moments — connexion, ouverture d'une interface marchande ou de
        l'inventaire. Une capture qui ne les contient pas laissera ces champs a
        None. A l'appelant de tenir son cache et de le fournir ici.

        `character_names` merite une attention particuliere pour une ecoute en
        direct. Le nom d'un personnage n'arrive qu'avec `ilw` ou `kae`, emis a
        un changement de carte ou a l'engagement d'un combat. Une ecoute
        demarree en cours de partie peut donc rester des minutes sans connaitre
        le moindre nom, et les participants d'un combat n'y sont alors designes
        que par un identifiant. Fournir la table apprise lors d'une session
        precedente evite cette periode aveugle. `character_breeds` obeit a la
        meme logique, en plus strict encore : la classe ne circule que dans
        `ilw`, donc uniquement lors d'un passage sur la carte.
        """
        self.source = source
        self.session = Session(port=port, clients=clients)
        self.pipeline = Pipeline(extractors if extractors is not None
                                 else default_extractors())
        if prices:
            self.pipeline.context.prices.update(prices)
        if character_names:
            self.pipeline.context.character_names.update(character_names)
        if character_breeds:
            self.pipeline.context.character_breeds.update(character_breeds)
        for who, table in (item_types or {}).items():
            cible = self.pipeline.context.items.setdefault(who, {})
            for uid, item_id in table.items():
                cible.setdefault(uid, (item_id, None))

    # ------------------------------------------------------------ constructeurs

    @classmethod
    def from_pcap(cls, path: str, hosts: str | None = None, **kwargs) -> "Reader":
        """Rejoue une capture. `hosts` est l'instantane des connexions pris
        pendant la capture, qui permet de nommer les flux."""
        return cls(PcapSource(path), clients=load(hosts) if hosts else [], **kwargs)

    def known_prices(self) -> dict[int, int]:
        """Prix rencontres pendant la lecture, a conserver par l'appelant."""
        return dict(self.pipeline.context.prices)

    def known_item_types(self) -> dict[str, dict[int, int]]:
        """Types d'objets rencontres, a conserver par l'appelant."""
        return {who: {uid: kind for uid, (kind, _) in table.items() if kind is not None}
                for who, table in self.pipeline.context.items.items()}

    def known_character_names(self) -> dict[int, str]:
        """Correspondance identifiant -> nom de personnage, a conserver."""
        return dict(self.pipeline.context.character_names)

    def known_character_breeds(self) -> dict[int, int]:
        """Correspondance identifiant -> classe, a conserver.

        Les numeros sont ceux de la table `breeds` du client : 1 Feca,
        2 Osamodas, 3 Enutrof, 4 Sram, 5 Xelor, 6 Ecaflip, 7 Eniripsa, 8 Iop,
        9 Cra, 10 Sadida, 11 Sacrieur, 12 Pandawa, 13 Roublard, 14 Zobal,
        15 Steamer, 16 Eliotrope, 17 Huppermage, 18 Ouginak, 20 Forgelance.
        """
        return dict(self.pipeline.context.character_breeds)

    @classmethod
    def from_live(cls, interface: str = "", hosts: str | None = None,
                  **kwargs) -> "Reader":
        """Ecoute en direct. Sans interface, toutes.

        Choisir la bonne carte est une question a laquelle l'appelant n'a pas
        de raison de savoir repondre : le jeu peut passer par l'Ethernet, le
        Wi-Fi ou un VPN, et cela change quand on debranche un cable. Une carte
        mal choisie ne se signale pas — l'ecoute reste simplement muette.

        Sans `hosts`, l'etat des connexions est releve au demarrage.
        """
        clients = load(hosts) if hosts else snapshot()
        port = kwargs.get("port", GAME_PORT)
        return cls(LiveSource(interface, port=port), clients=clients, **kwargs)

    # ---------------------------------------------------------------- lecture

    def events(self) -> Iterator[Event]:
        for obs in self.session.run(self.source.frames()):
            yield from self.pipeline.feed(obs)
        yield from self.pipeline.flush()

    def messages(self):
        """Flux de messages bruts, pour explorer un code non encore couvert."""
        return self.session.run(self.source.frames())

    # ---------------------------------------------------------------- etat

    @property
    def context(self) -> Context:
        return self.pipeline.context

    def report(self) -> str:
        """Bilan de sante du decodage : volumes, erreurs, trous."""
        return self.session.report()
