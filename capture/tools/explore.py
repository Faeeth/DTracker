"""Exploration d'une capture : quels codes existent, a quelle frequence, quelle taille.

Un message de fin de combat est rare (une fois par combat), volumineux (il porte
les participants, l'experience et les gains) et arrive au meme instant sur tous
les clients engages dans le meme combat. Ces trois criteres suffisent a le
faire ressortir sans rien connaitre du protocole.
"""
from __future__ import annotations

import argparse
import collections
import statistics
import os
import sys
from datetime import datetime

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from dofus_stats.capture.pcap_source import PcapSource
from dofus_stats.net.identify import load
from dofus_stats.session import Session


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("pcap")
    ap.add_argument("--hosts")
    ap.add_argument("--top", type=int, default=60)
    ap.add_argument("--rare", type=int, default=40, help="seuil d'occurrences pour 'rare'")
    args = ap.parse_args()

    clients = load(args.hosts) if args.hosts else []
    session = Session(clients=clients)

    sizes: dict[str, list[int]] = collections.defaultdict(list)
    depth0 = collections.Counter()
    nested = collections.Counter()
    per_who: dict[str, collections.Counter] = collections.defaultdict(collections.Counter)
    times: dict[str, list[float]] = collections.defaultdict(list)
    first_ts = None

    for obs in session.run(PcapSource(args.pcap).frames()):
        env = obs.env
        if first_ts is None:
            first_ts = env.ts
        for a in env.anys:
            (depth0 if a.depth == 0 else nested)[a.code] += 1
            sizes[a.code].append(len(a.raw) if a.raw else _tree_size(a))
            times[a.code].append(env.ts)
            per_who[a.code][obs.who] += 1

    print(session.report())
    all_codes = depth0 + nested
    print(f"\ncodes distincts: {len(all_codes)}   messages: {sum(all_codes.values())}")

    print(f"\n{'code':<6} {'total':>6} {'racine':>7} {'imbr.':>6} {'taille moy':>11} "
          f"{'max':>7} {'clients':>8}")
    print("-" * 60)
    for code, total in all_codes.most_common(args.top):
        s = sizes[code]
        print(f"{code:<6} {total:>6} {depth0[code]:>7} {nested[code]:>6} "
              f"{statistics.mean(s):>11.1f} {max(s):>7} {len(per_who[code]):>8}")

    print("\n=== candidats fin de combat : rares, volumineux, vus par plusieurs clients ===")
    cands = []
    for code, total in all_codes.items():
        s = sizes[code]
        if total <= args.rare and max(s) > 60:
            cands.append((max(s), code, total, len(per_who[code])))
    for mx, code, total, nwho in sorted(cands, reverse=True)[:25]:
        stamps = sorted(times[code])
        rel = [f"{t - first_ts:.1f}" for t in stamps[:10]]
        print(f"  {code:<5} n={total:<4} max={mx:<6} clients={nwho}  t=[{', '.join(rel)}]")
    return 0


def _tree_size(a) -> int:
    return sum(len(f.raw) for f in a.fields) if a.fields else 0


if __name__ == "__main__":
    raise SystemExit(main())
