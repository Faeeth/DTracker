"""Point d'entree pour consommer les evenements depuis un autre programme.

    python -m dofus_stats.cli.stream --live 8
    python -m dofus_stats.cli.stream --read session.pcapng --hosts hosts.json
    python -m dofus_stats.cli.stream --live 8 --mode websocket --port 8765

En mode `ndjson`, chaque evenement sort sur une ligne de la sortie standard :
l'appelant lance ce module en sous-processus et lit sa sortie, sans port a
gerer. En mode `websocket`, un serveur local diffuse aux consommateurs
connectes.

Les diagnostics vont sur la sortie d'erreur, jamais sur la sortie standard, qui
ne doit contenir que des evenements.
"""
from __future__ import annotations

import argparse
import json
import os
import sys
import time

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.dirname(
    os.path.abspath(__file__)))))

from dofus_stats import Reader
from dofus_stats.session import GAME_PORT
from dofus_stats.stream import make_sink, stream


def main(argv=None) -> int:
    ap = argparse.ArgumentParser(
        description="Diffuse les evenements de jeu vers un consommateur exterieur.")
    src = ap.add_mutually_exclusive_group(required=True)
    src.add_argument("-r", "--read", metavar="FICHIER", help="rejouer une capture")
    src.add_argument("-i", "--live", metavar="INTERFACE", nargs="?", const="",
                     help="ecouter en direct ; sans valeur, ou avec « any », "
                          "sur toutes les interfaces")
    src.add_argument("--interfaces", action="store_true",
                     help="lister les interfaces de capture, en JSON, et sortir")
    ap.add_argument("--hosts", help="instantane des connexions, pour nommer les flux")
    ap.add_argument("--mode", choices=["ndjson", "websocket", "both"], default="ndjson",
                    help="transport ; ndjson par defaut, suffisant au debit du jeu")
    ap.add_argument("--host", default="127.0.0.1", help="adresse d'ecoute du serveur")
    ap.add_argument("--port", type=int, default=8765, help="port du serveur")
    ap.add_argument("--game-port", type=int, default=GAME_PORT)
    ap.add_argument("--prices", metavar="FICHIER",
                    help="table de prix conservee par l'appelant, a reinjecter")
    ap.add_argument("--item-types", metavar="FICHIER",
                    help="types d'objets conserves par l'appelant, a reinjecter")
    ap.add_argument("--full", action="store_true",
                    help="emettre aussi les champs vides, pour un schema stable")
    ap.add_argument("--only", action="append",
                    help="ne diffuser que ces types d'evenements")
    ap.add_argument("--attendre", action="store_true",
                    help="ne rien diffuser tant qu'aucun client n'est connecte")
    ap.add_argument("--tempo", type=float, default=0.0, metavar="FACTEUR",
                    help="rejouer au rythme de la capture ; 1 = temps reel, "
                         "2 = deux fois plus vite")
    args = ap.parse_args(argv)

    if args.interfaces:
        # Une interface graphique doit pouvoir proposer la liste sans avoir a
        # savoir ou vit Wireshark ni comment lire sa sortie.
        from dofus_stats.capture.live_source import (detailed_interfaces,
                                                      est_physique,
                                                      list_interfaces)
        try:
            # Le nom de peripherique est rendu en plus du numero : lui seul est
            # stable d'un demarrage a l'autre, et c'est donc lui qu'une
            # interface graphique doit conserver dans ses reglages.
            #
            # `physique` est rendu ici et non laisse a l'appelant : le verdict
            # demande de connaitre les conventions de nommage de Windows, ce
            # qui n'est pas le travail d'une interface graphique.
            liste = [{"numero": i["numero"], "libelle": i["libelle"],
                      "device": i["device"], "adresses": i["adresses"],
                      "mac": i.get("mac", ""),
                      "loopback": i["loopback"],
                      "physique": est_physique(i)}
                     for i in detailed_interfaces()]
            if not liste:
                liste = [{"numero": n, "libelle": libelle}
                         for n, libelle in list_interfaces()]
        except Exception as exc:                       # noqa: BLE001
            print(f"# interfaces indisponibles : {exc}", file=sys.stderr)
            liste = []
        # `ensure_ascii` par defaut, et c'est voulu : la sortie standard de
        # Windows n'est pas en UTF-8 — « Connexion reseau Bluetooth » sortait
        # avec un `0xe9` cp1252 au milieu, que l'appelant ne pouvait pas
        # decoder. Toute la liste devenait alors vide, et l'interface
        # choisie dans les reglages s'affichait « introuvable ». Echapper les
        # accents rend la sortie lisible par n'importe quel decodeur.
        print(json.dumps(liste))
        return 0

    if args.live is not None:
        # Dire sur quoi on ecoute : une interface muette ne se distingue
        # autrement pas d'un jeu a l'arret, et c'est precisement ce qui rendait
        # un mauvais choix d'interface indechiffrable.
        from dofus_stats.capture.live_source import LiveSource
        cartes = LiveSource(args.live, port=args.game_port).interfaces()
        print(f"# ecoute sur {len(cartes)} interface(s)", file=sys.stderr)

    prices = _load_prices(args.prices)
    item_types = _load_item_types(args.item_types)

    reader = (Reader.from_pcap(args.read, hosts=args.hosts, port=args.game_port,
                               prices=prices, item_types=item_types)
              if args.read else
              Reader.from_live(args.live, hosts=args.hosts, port=args.game_port,
                               prices=prices, item_types=item_types))

    options = {"drop_none": not args.full}
    if args.mode in ("websocket", "both"):
        options.update(host=args.host, port=args.port)
    sink = make_sink(args.mode, **options)

    if args.mode in ("websocket", "both"):
        print(f"# diffusion sur ws://{args.host}:{args.port}", file=sys.stderr)

    if args.attendre and args.mode in ("websocket", "both"):
        # Un rejeu se termine en une seconde : sans cette attente, tout est
        # diffuse avant qu'un client ait eu le temps de se connecter. C'est ce
        # qui permet de developper une interface sans lancer le jeu.
        print("# en attente d'un consommateur...", file=sys.stderr)
        while not sink.clients:
            time.sleep(0.1)

    garde = set(args.only or ())
    evenements = reader.events()
    if garde:
        evenements = (e for e in evenements if type(e).__name__ in garde)
    if args.tempo > 0:
        evenements = _au_tempo(evenements, args.tempo)

    try:
        n = stream(evenements, sink)
    except KeyboardInterrupt:
        print("\n# interrompu", file=sys.stderr)
        return 0
    print(f"# {n} evenements diffuses", file=sys.stderr)
    print("# " + reader.report().replace("\n", "\n# "), file=sys.stderr)
    return 0


def _au_tempo(evenements, facteur: float):
    """Rend les evenements en respectant l'ecart de temps de la capture.

    Un rejeu instantane ne dit rien de l'allure d'une session : les gains
    arrivent tous ensemble et l'on ne voit ni les animations, ni le passage en
    combat. Espacer les evenements comme ils l'etaient rend le rejeu utilisable
    pour mettre au point un affichage.

    Les longues pauses sont ecourtees : personne n'attend cinq minutes entre
    deux combats pour verifier une couleur.
    """
    precedent = None
    for evenement in evenements:
        ts = getattr(evenement, "ts", None)
        if precedent is not None and ts is not None:
            attente = min((ts - precedent) / facteur, 3.0)
            if attente > 0:
                time.sleep(attente)
        if ts is not None:
            precedent = ts
        yield evenement


def _load_prices(path: str | None) -> dict[int, int] | None:
    if not path or not os.path.exists(path):
        return None
    with open(path, encoding="utf-8") as fh:
        data = json.load(fh)
    table = data.get("prices", data)
    return {int(k): v for k, v in table.items()}


def _load_item_types(path: str | None) -> dict[str, dict[int, int]] | None:
    if not path or not os.path.exists(path):
        return None
    with open(path, encoding="utf-8") as fh:
        data = json.load(fh)
    return {who: {int(uid): kind for uid, kind in table.items()}
            for who, table in data.items()}


if __name__ == "__main__":
    raise SystemExit(main())
