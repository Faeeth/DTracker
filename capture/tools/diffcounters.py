"""Cherche tout compteur qui bouge, sur tous les messages et tous les champs.

Utile pour identifier une valeur dont on connait la variation attendue : si un
combat rapporte N kamas, le champ qui bouge de N les porte.
"""
from __future__ import annotations

import argparse
import collections
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from dofus_stats.capture.pcap_source import PcapSource
from dofus_stats.net.identify import load
from dofus_stats.protocol import wire
from dofus_stats.session import Session


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("pcap")
    ap.add_argument("--hosts")
    ap.add_argument("--min", type=int, default=100, help="valeur minimale a considerer")
    ap.add_argument("--delta", type=int, help="ne montrer que les variations de cette taille")
    ap.add_argument("--tolerance", type=int, default=0)
    args = ap.parse_args()

    session = Session(clients=load(args.hosts) if args.hosts else [])
    first = None
    last: dict[tuple, int] = {}
    moves = collections.defaultdict(list)

    for obs in session.run(PcapSource(args.pcap).frames()):
        env = obs.env
        if first is None:
            first = env.ts
        top = env.top
        if top is None:
            continue
        for path, f in wire.walk(top.fields):
            if f.wire != 0 or f.value < args.min:
                continue
            key = (obs.who, env.code, path)
            prev = last.get(key)
            if prev is not None and prev != f.value:
                moves[key].append((env.ts - first, prev, f.value))
            last[key] = f.value

    print(f"{len(moves)} compteurs ont bouge\n")
    rows = []
    for key, evts in moves.items():
        for t, a, b in evts:
            if args.delta is not None and abs((b - a) - args.delta) > args.tolerance:
                continue
            rows.append((t, key, a, b))
    rows.sort()
    for t, (who, code, path), a, b in rows[:60]:
        p = ".".join(map(str, path))
        print(f"  t={t:7.2f}  {who:<14} {code} champ {p:<16} {a:>13,} -> {b:>13,}  ({b - a:+,})")
    if not rows:
        print("  (aucune variation ne correspond au filtre)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
