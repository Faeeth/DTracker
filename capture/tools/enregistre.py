"""Enregistre le trafic du jeu dans un fichier rejouable.

    python tools/enregistre.py captures/echange01 --secondes 180

Ecrit deux fichiers cote a cote, ceux qu'attend le reste du projet :

    captures/echange01.pcap          les trames
    captures/hosts_echange01.json    quel flux appartient a quel personnage

Pourquoi enregistrer plutot que lire au vol : identifier un message demande de
relire la meme scene des dizaines de fois, en changeant d'hypothese a chaque
passage. Une ecoute en direct ne se rejoue pas, et refaire l'action en jeu
n'est ni fidele ni toujours possible.

Le fichier est en format pcap classique, que `PcapSource` lit comme le pcapng
de dumpcap. On l'ecrit nous-memes : il tient en trente lignes, la ou dependre
de Wireshark reviendrait a le reinstaller pour une seule occasion.

Rien n'est emis sur le reseau. La capture est passive, comme tout le reste du
projet : on ouvre la carte en lecture, on filtre sur le port du jeu, on ecrit
ce qui passe.
"""
from __future__ import annotations

import argparse
import os
import struct
import sys
import threading
import time

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from dofus_stats.capture import npcap_source
from dofus_stats.capture.live_source import all_interfaces
from dofus_stats.net import identify

PCAP_MAGIC_US = 0xA1B2C3D4


def entete(fh, linktype: int) -> None:
    """L'en-tete pcap : magie, version 2.4, pas de decalage horaire."""
    fh.write(struct.pack("<IHHiIII", PCAP_MAGIC_US, 2, 4, 0, 0, 65536,
                         linktype))


def trame(fh, ts: float, data: bytes) -> None:
    secondes = int(ts)
    fh.write(struct.pack("<IIII", secondes, int((ts - secondes) * 1_000_000),
                         len(data), len(data)))
    fh.write(data)


def main(argv=None) -> int:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("sortie", help="chemin sans extension, ex. captures/echange01")
    ap.add_argument("--secondes", type=float, default=180.0)
    ap.add_argument("-i", "--interface", action="append",
                    help="nom npcap d'une carte ; par defaut, celles qui portent le jeu")
    args = ap.parse_args(argv)

    if not npcap_source.disponible():
        print("npcap n'est pas installe : voir npcap.com", file=sys.stderr)
        return 3

    # La photo des connexions, prise deux fois : maintenant et a la fin.
    #
    # Une seule prise au demarrage suffisait tant qu'on enregistrait une scene
    # de jeu ordinaire. Elle exigeait alors precisement ce que certaines
    # scenes viennent creer : enregistrer une connexion de personnage, c'est
    # commencer sans client a photographier. L'outil refusait de demarrer.
    debut = identify.snapshot()
    for c in debut:
        print(f"  {c.label:<20} {c.local_addr}:{c.local_port}")
    if not debut:
        print("aucun client pour l'instant : la photo se prendra a la fin",
              file=sys.stderr)

    cartes = args.interface or all_interfaces()
    if not cartes:
        print("aucune carte a ecouter", file=sys.stderr)
        return 4

    base = os.path.abspath(args.sortie)
    os.makedirs(os.path.dirname(base), exist_ok=True)
    dossier, nom = os.path.split(base)

    source = npcap_source.NpcapSource(cartes)
    # Un minuteur plutot que la seule verification dans la boucle : celle-ci
    # ne passe qu'a l'arrivee d'une trame, et une scene silencieuse — une
    # fenetre d'echange ouverte sans rien faire — n'en produit plus.
    threading.Timer(args.secondes, source.arrete).start()
    fin = time.time() + args.secondes
    compte = 0
    octets = 0
    with open(base + ".pcap", "wb", buffering=1 << 20) as fh:
        ecrit = False
        print(f"enregistrement de {args.secondes:.0f} s sur {len(cartes)} carte(s)…",
              file=sys.stderr)
        try:
            for f in source.frames():
                if not ecrit:
                    entete(fh, f.linktype)
                    ecrit = True
                trame(fh, f.ts, f.data)
                compte += 1
                octets += len(f.data)
                if time.time() >= fin:
                    break
        except KeyboardInterrupt:
            pass
        finally:
            source.close()
        if not ecrit:
            entete(fh, 1)
    # La seconde photo, maintenant que la scene est jouee : elle porte les
    # connexions ouvertes pendant l'enregistrement, que la premiere ignorait.
    # Un flux se nomme par son port local, aussi les deux se completent sans
    # se contredire — un port n'est pas reattribue en une minute.
    connus = {(c.local_addr, c.local_port) for c in debut}
    clients = list(debut) + [c for c in identify.snapshot()
                             if (c.local_addr, c.local_port) not in connus]
    identify.save(clients, os.path.join(dossier, f"hosts_{nom}.json"))
    for c in clients[len(debut):]:
        print(f"  {c.label:<20} {c.local_addr}:{c.local_port}  (apparu)")
    if not clients:
        print("aucun client vu : les flux resteront anonymes", file=sys.stderr)

    print(f"{compte} trames, {octets / 1024:.0f} Kio -> {base}.pcap")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
