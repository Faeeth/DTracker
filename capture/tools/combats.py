"""Rapport de fin de combat et de succes, construit sur la bibliotheque."""
from __future__ import annotations

import argparse
import os
import sys
from datetime import datetime

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from dofus_stats import AchievementUnlocked, FightEnd, Reader


def main() -> int:
    ap = argparse.ArgumentParser(description="Gains de fin de combat et de succes.")
    src = ap.add_mutually_exclusive_group(required=True)
    src.add_argument("-r", "--read", metavar="FICHIER", help="rejouer une capture")
    src.add_argument("-i", "--interface", help="ecouter en direct")
    ap.add_argument("--hosts", help="instantane des connexions, pour nommer les flux")
    args = ap.parse_args()

    reader = (Reader.from_pcap(args.read, hosts=args.hosts) if args.read
              else Reader.from_live(args.interface, hosts=args.hosts))

    fights = achievements = 0
    try:
        for event in reader.events():
            stamp = datetime.fromtimestamp(event.ts).strftime("%H:%M:%S")
            if isinstance(event, FightEnd):
                fights += 1
                print(f"=== combat termine a {stamp} "
                      f"— {len(event.participants)} participants ===")
                for p in event.participants:
                    label = p.name or f"personnage {p.character_id}"
                    units = sum(s.quantity for s in p.loot)
                    print(f"  {label:<15} niveau {p.level}")
                    print(f"      xp     +{p.xp:>8,}   (total {p.xp_total:,}, "
                          f"{p.level_progress * 100:.1f} % du niveau)")
                    print(f"      kamas  +{p.kamas:>8,}")
                    value = p.loot_value
                    valeur = f", {value:,} kamas" if value is not None else ""
                    print(f"      butin   {len(p.loot)} type(s), {units} unite(s){valeur}")
                    for s in sorted(p.loot, key=lambda x: -(x.total_price or 0)):
                        if s.unit_price is None:
                            montant = "prix inconnu"
                        else:
                            montant = (f"{s.total_price:>7,} kamas"
                                       + (f"  ({s.unit_price:,} l'unite)" if s.quantity > 1 else ""))
                        print(f"          x{s.quantity:<3} {montant:<32} objet {s.item_id}")
                butin = event.total_value
                print(f"  --- total : +{event.total_xp:,} xp, "
                      f"+{event.total_kamas:,} kamas cash"
                      + (f", butin estime a {butin:,} kamas" if butin is not None else ""))
                cumule = "  ".join(
                    f"x{s.quantity} objet {s.item_id}"
                    + (f" ({s.total_price:,}k)" if s.total_price is not None else "")
                    for s in sorted(event.total_loot, key=lambda x: -(x.total_price or 0)))
                print(f"      butin cumule : {cumule or 'aucun'}")
                if butin is not None:
                    print(f"      gain total   : {event.total_kamas + butin:,} kamas")
                print()
            elif isinstance(event, AchievementUnlocked):
                achievements += 1
                objets = ", ".join(
                    f"x{s.quantity} objet {s.item_id}"
                    + (f" ({s.total_price:,} kamas)" if s.total_price is not None else "")
                    for s in event.rewards)
                print(f"[{stamp}] succes {event.achievement_id} sur {event.character} : "
                      f"+{event.xp:,} xp, +{event.kamas:,} kamas"
                      + (f", objets {objets}" if objets else ""))
    except KeyboardInterrupt:
        print("\n# interrompu", file=sys.stderr)

    print(f"# {fights} combat(s), {achievements} succes", file=sys.stderr)
    print("# " + reader.report().replace("\n", "\n# "), file=sys.stderr)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
