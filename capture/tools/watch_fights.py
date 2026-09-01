"""Affiche les fins de combat au fil de l'eau, avec la latence de la chaine.

Sert a departager deux causes possibles quand un affichage semble en retard :
la bibliotheque met du temps a livrer l'evenement, ou bien c'est le jeu qui ne
l'a pas encore envoye.

Deux horodatages sont donc donnes :

  - celui du paquet, tel que la capture l'a date au moment ou il est passe sur
    le reseau ;
  - celui de la livraison, mesure a l'instant ou la bibliotheque rend
    l'evenement.

L'ecart entre les deux est le temps que la chaine a mis a decoder. S'il est de
l'ordre de la seconde ou moins, un retard percu vient d'ailleurs.

    python tools/watch_fights.py -i 8
    python tools/watch_fights.py -i 8 --all
"""
from __future__ import annotations

import argparse
import os
import sys
import time
from datetime import datetime

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from dofus_stats import (
    AchievementUnlocked,
    FightEnd,
    FightStart,
    Reader,
)
from dofus_stats.capture.live_source import list_interfaces


def horodate(ts: float) -> str:
    return datetime.fromtimestamp(ts).strftime("%H:%M:%S.%f")[:-3]


def main(argv=None) -> int:
    ap = argparse.ArgumentParser(description="Suit les fins de combat en direct.")
    ap.add_argument("-i", "--interface", help="interface de capture")
    ap.add_argument("-r", "--read", help="rejouer une capture au lieu d'ecouter")
    ap.add_argument("--hosts", help="instantane des connexions")
    ap.add_argument("--all", action="store_true",
                    help="afficher aussi les debuts de combat et les succes")
    ap.add_argument("-L", "--list", action="store_true", help="lister les interfaces")
    args = ap.parse_args(argv)

    if args.list:
        for numero, libelle in list_interfaces():
            print(f"{numero:>3}  {libelle}")
        return 0

    if args.read:
        reader = Reader.from_pcap(args.read, hosts=args.hosts)
        print(f"# rejeu de {args.read}")
    else:
        interface = args.interface or "8"
        reader = Reader.from_live(interface, hosts=args.hosts)
        print(f"# ecoute de l'interface {interface} — Ctrl+C pour arreter")

    print(f"# {'reseau':<13} {'livraison':<13} {'latence':>8}   evenement")
    print("# " + "-" * 74)

    combats = 0
    try:
        for event in reader.events():
            recu = time.time()
            latence = recu - event.ts

            if isinstance(event, FightEnd):
                combats += 1
                print(f"  {horodate(event.ts):<13} {horodate(recu):<13} "
                      f"{latence:>7.2f}s   FIN DE COMBAT #{combats}")
                for p in sorted(event.participants, key=lambda x: -x.xp):
                    butin = ", ".join(f"{s.item_id}x{s.quantity}" for s in p.loot)
                    print(f"  {'':<13} {'':<13} {'':>8}     "
                          f"{p.name or p.character_id:<16} "
                          f"+{p.xp:>7,} xp  +{p.kamas:>4} kamas"
                          + (f"  [{butin}]" if butin else ""))
                valeur = event.total_value
                print(f"  {'':<13} {'':<13} {'':>8}     "
                      f"{'TOTAL':<16} +{event.total_xp:>7,} xp  "
                      f"+{event.total_kamas:>4} kamas"
                      + (f"  butin {valeur:,} kamas" if valeur else ""))
                print()
                sys.stdout.flush()

            elif args.all and isinstance(event, FightStart) and event.initiated:
                print(f"  {horodate(event.ts):<13} {horodate(recu):<13} "
                      f"{latence:>7.2f}s   combat engage par {event.character}")
                sys.stdout.flush()

            elif args.all and isinstance(event, AchievementUnlocked):
                print(f"  {horodate(event.ts):<13} {horodate(recu):<13} "
                      f"{latence:>7.2f}s   succes {event.achievement_id} "
                      f"sur {event.character} : +{event.xp:,} xp, "
                      f"+{event.kamas:,} kamas")
                sys.stdout.flush()

    except KeyboardInterrupt:
        print(f"\n# interrompu — {combats} combat(s) observe(s)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
