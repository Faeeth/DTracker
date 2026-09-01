"""Chronologie d'un combat, message par message.

Sert a rapprocher le trafic d'actions decrites par le joueur. Les codes deja
identifies sont annotes ; les autres sont montres bruts, groupes par instant,
puisque ce sont eux qu'il s'agit de reconnaitre.
"""
from __future__ import annotations

import argparse
import json
import os
import sys
from datetime import datetime

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from dofus_stats import Reader
from dofus_stats.protocol import wire

# Trafic de fond, sans rapport avec le deroulement d'un combat.
BRUIT = set("jto jwi jwe jxm jsj jxw jtn ino jzc jti jwz kqo kqy lva jqi jsq "
            "jya jru jrh kmv lqu jxh jsd kmu kau imh iln jyt jxc jss jsn".split())


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("pcap")
    ap.add_argument("--hosts")
    ap.add_argument("--perso", help="ne suivre qu'un personnage")
    ap.add_argument("--from", dest="debut", type=float, default=0.0)
    ap.add_argument("--to", dest="fin", type=float, default=1e9)
    ap.add_argument("--all", action="store_true", help="inclure le trafic de fond")
    ap.add_argument("--largeur", type=int, default=110)
    args = ap.parse_args()

    noms = {}
    chemin = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))),
                          "data", "messages.json")
    if os.path.exists(chemin):
        with open(chemin, encoding="utf-8") as fh:
            noms = json.load(fh).get("names", {})

    reader = Reader.from_pcap(args.pcap, hosts=args.hosts)
    debut = None
    precedent = None
    for obs in reader.messages():
        if debut is None:
            debut = obs.env.ts
        t = obs.env.ts - debut
        if not (args.debut <= t <= args.fin):
            continue
        if args.perso and obs.who != args.perso:
            continue
        code = obs.env.code
        if not args.all and code in BRUIT:
            continue

        # Une ligne vide separe les rafales : un instant = une action du joueur.
        if precedent is not None and t - precedent > 0.6:
            print()
        precedent = t

        corps = ""
        if obs.env.top is not None:
            corps = wire.render(obs.env.top.fields).replace("\n", " ")
        etiquette = noms.get(code, "")
        marque = f"{code} ({etiquette})" if etiquette else code
        print(f"  t={t:7.2f} {obs.who:<14} {obs.env.direction} {marque:<28} "
              f"{obs.env.size:>4}o  {corps[:args.largeur]}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
