"""Ne garde d'une capture que le trafic du jeu.

    python tools/reduis.py captures/*.pcapng
    python tools/reduis.py captures/brisage01.pcapng --sortie captures/propre

Les captures d'avant `tools/enregistre.py` ont ete prises avec dumpcap sans
filtre : elles portent tout ce que la machine faisait pendant l'enregistrement.
Sur `brisage01`, cent-soixante-seize trames sur trente-et-un mille concernent
le jeu — le reste pese cinquante megaoctets et ne dit rien du protocole.

Deux raisons de l'oter, et la seconde est la vraie. Le poids, d'abord : une
capture de reference doit pouvoir vivre dans le depot. La vie privee ensuite :
ces trames portent tout le reste — les sites visites, les autres applications,
les noms d'hotes en clair dans les poignees de main TLS. Rien de cela n'a a
etre publie parce qu'un combat a ete enregistre au meme moment.

Le filtre ne coupe jamais au milieu d'un flux : il garde ou jette une trame
entiere selon son port, et le reassemblage TCP du jeu reste intact.

L'original n'est pas touche. Le fichier reduit prend l'extension `.pcap`, le
format que ce projet ecrit et relit.
"""
from __future__ import annotations

import argparse
import os
import struct
import sys

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from dofus_stats.capture.pcap_source import PcapSource
from dofus_stats.net.dissect import dissect

PCAP_MAGIC_US = 0xA1B2C3D4


def reduis(source: str, cible: str, port: int) -> tuple[int, int, int, int]:
    """Rend (trames lues, trames gardees, octets lus, octets gardes)."""
    lues = gardees = octets = retenus = 0
    fh = None
    try:
        for f in PcapSource(source).frames():
            lues += 1
            octets += len(f.data)
            if dissect(f.ts, f.data, f.linktype, port) is None:
                continue
            if fh is None:
                fh = open(cible, "wb", buffering=1 << 20)
                fh.write(struct.pack("<IHHiIII", PCAP_MAGIC_US, 2, 4, 0, 0,
                                     65536, f.linktype))
            secondes = int(f.ts)
            fh.write(struct.pack("<IIII", secondes,
                                 int((f.ts - secondes) * 1_000_000),
                                 len(f.data), len(f.data)))
            fh.write(f.data)
            gardees += 1
            retenus += len(f.data)
    finally:
        if fh is not None:
            fh.close()
    return lues, gardees, octets, retenus


def main(argv=None) -> int:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("captures", nargs="+")
    ap.add_argument("--port", type=int, default=5555)
    ap.add_argument("--sortie", help="dossier de destination ; a cote sinon")
    args = ap.parse_args(argv)

    if args.sortie:
        os.makedirs(args.sortie, exist_ok=True)
    for source in args.captures:
        nom = os.path.splitext(os.path.basename(source))[0]
        dossier = args.sortie or os.path.dirname(os.path.abspath(source))
        cible = os.path.join(dossier, nom + ".pcap")
        if os.path.abspath(cible) == os.path.abspath(source):
            cible = os.path.join(dossier, nom + ".reduit.pcap")
        lues, gardees, octets, retenus = reduis(source, cible, args.port)
        print("{:<24} {:>6}/{:<6} trames  {:>8.0f} -> {:<6.0f} Kio"
              .format(nom, gardees, lues, octets / 1024, retenus / 1024))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
