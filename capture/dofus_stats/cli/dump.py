"""Sortie CLI de debug : horodatage, sens, personnage, code, taille, contenu."""
from __future__ import annotations

import argparse
import os
import sys
from datetime import datetime

# Permet de lancer ce fichier directement : la racine du projet est trois
# niveaux au-dessus (dofus_stats/cli/dump.py).
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.dirname(
    os.path.abspath(__file__)))))

from dofus_stats.capture.live_source import LiveSource, list_interfaces
from dofus_stats.capture.pcap_source import PcapSource
from dofus_stats.net.identify import load, snapshot
from dofus_stats.protocol import wire
from dofus_stats.protocol.registry import Registry
from dofus_stats.session import Session


def hexdump(data: bytes, width: int = 16, limit: int = 512) -> str:
    out = []
    view = data[:limit]
    for off in range(0, len(view), width):
        chunk = view[off:off + width]
        hexa = " ".join(f"{b:02x}" for b in chunk).ljust(width * 3 - 1)
        text = "".join(chr(b) if 32 <= b < 127 else "." for b in chunk)
        out.append(f"    {off:04x}  {hexa}  |{text}|")
    if len(data) > limit:
        out.append(f"    ... {len(data) - limit} octets de plus")
    return "\n".join(out)


def main(argv=None) -> int:
    ap = argparse.ArgumentParser(description="Lecture passive des messages Dofus 3.")
    src = ap.add_mutually_exclusive_group(required=True)
    src.add_argument("-r", "--read", metavar="FICHIER", help="rejouer une capture .pcapng")
    src.add_argument("-i", "--interface", help="capturer en direct sur cette interface")
    src.add_argument("-L", "--list-interfaces", action="store_true")
    ap.add_argument("--hosts", help="instantane des connexions (JSON) pour nommer les flux")
    ap.add_argument("--port", type=int, default=5555)
    ap.add_argument("--code", action="append", help="ne montrer que ces codes")
    ap.add_argument("--exclude", action="append", default=[], help="masquer ces codes")
    ap.add_argument("--perso", action="append", help="ne montrer que ces personnages")
    ap.add_argument("--dir", choices=["cs", "sc"], help="sens unique")
    ap.add_argument("--nested", action="store_true", help="lister aussi les Any imbriques")
    ap.add_argument("--hex", action="store_true", help="hexdump du corps")
    ap.add_argument("--tree", action="store_true", help="arbre protobuf decode")
    ap.add_argument("--summary", action="store_true", help="seulement le bilan final")
    ap.add_argument("--count", type=int, help="s'arreter apres N messages")
    args = ap.parse_args(argv)

    if args.list_interfaces:
        for num, name in list_interfaces():
            print(f"{num:>3}  {name}")
        return 0

    clients = load(args.hosts) if args.hosts else snapshot()
    if clients:
        print(f"# clients: {', '.join(f'{c.character}:{c.local_port}' for c in clients)}",
              file=sys.stderr)

    registry = Registry()
    session = Session(port=args.port, clients=clients)
    source = PcapSource(args.read) if args.read else LiveSource(args.interface, port=args.port)

    def split(values):
        """Accepte aussi bien --code a --code b que --code a,b."""
        return {v.strip() for item in (values or []) for v in item.split(",") if v.strip()}

    only = split(args.code)
    hide = split(args.exclude)
    personas = split(args.perso)
    shown = 0

    try:
        for obs in session.run(source.frames()):
            env = obs.env
            if args.dir == "cs" and env.from_server:
                continue
            if args.dir == "sc" and not env.from_server:
                continue
            if personas and obs.who not in personas:
                continue
            codes = env.codes if args.nested else env.codes[:1]
            if only and not (only & set(codes)):
                continue
            if hide and set(codes) <= hide:
                continue

            shown += 1
            if not args.summary:
                stamp = datetime.fromtimestamp(env.ts).strftime("%H:%M:%S.%f")[:-3]
                head = (f"{stamp}  {env.direction}  {obs.who:<14} "
                        f"{registry.label(env.code):<28} {env.size:>5}o")
                if len(env.anys) > 1:
                    head += "  [" + " > ".join(a.code for a in env.anys[1:6]) + "]"
                print(head)
                if env.error:
                    print(f"    !! {env.error}")
                if args.tree and env.top:
                    print(wire.render(env.top.fields, indent=2) or "    (vide)")
                if args.hex and env.top:
                    print(hexdump(env.top.raw or b""))
            if args.count and shown >= args.count:
                break
    except KeyboardInterrupt:
        print("\n# interrompu", file=sys.stderr)

    print("\n# " + session.report().replace("\n", "\n# "), file=sys.stderr)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
