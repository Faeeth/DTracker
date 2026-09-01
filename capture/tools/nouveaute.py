"""Compare une capture a un corpus de reference et isole ce qui n'y figure pas.

Un message declenche par une action precise du joueur ressort par contraste :
il est absent partout ailleurs. C'est ce qui a permis d'identifier le
recapitulatif de combat et la table des prix.
"""
from __future__ import annotations

import argparse
import collections
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from dofus_stats import Reader


def codes_of(pcap: str, hosts: str | None) -> collections.Counter:
    compte = collections.Counter()
    for obs in Reader.from_pcap(pcap, hosts=hosts).messages():
        compte[obs.env.code] += 1
    return compte


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("pcap", help="capture a analyser")
    ap.add_argument("--hosts")
    ap.add_argument("--reference", nargs="+", required=True,
                    help="captures de reference, ou l'action n'a pas eu lieu")
    args = ap.parse_args()

    connus: set[str] = set()
    for ref in args.reference:
        connus |= set(codes_of(ref, None))

    vus = codes_of(args.pcap, args.hosts)
    inedits = {c: n for c, n in vus.items() if c not in connus}

    print(f"{len(vus)} codes dans la capture, {len(connus)} dans la reference")
    print(f"\n=== {len(inedits)} code(s) inedit(s) ===")
    for code, n in sorted(inedits.items(), key=lambda kv: -kv[1]):
        print(f"  {code}  x{n}")
    if not inedits:
        print("  aucun — l'action n'a produit aucun message d'un type nouveau")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
