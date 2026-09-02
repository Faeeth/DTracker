"""Deroule une capture pour identifier un message.

    python tools/chronologie.py captures/echange_hdv01          recensement
    python tools/chronologie.py captures/echange_hdv01 --de 44 --a 62
    python tools/chronologie.py captures/echange_hdv01 --codes iua,ivj,kcr
    python tools/chronologie.py captures/echange_hdv01 --objet 14471

C'est l'outil qui a servi a trouver `kfb` et `kbm` — le depot dans une fenetre
d'echange, et l'achat en hotel de vente. La methode tient en trois passes, et
elle se repete a chaque nouveau message a identifier.

**Recenser.** Sans option, on obtient les codes du flux avec leur sens et leur
nombre. Un code qui n'apparait que dans la capture d'une action precise est
deja un candidat ; c'est ainsi qu'on a isole le recapitulatif de combat et la
table des prix — voir `tools/nouveaute.py`, qui automatise ce contraste.

**Situer.** `--de` et `--a` bornent une fenetre de temps. On joue la scene en
sachant l'heure, on borne, et on lit la sequence complete : la commande du
client, la reponse du serveur, les consequences. C'est la que se voit l'ordre,
qui est souvent toute l'information — les recompenses d'un succes arrivent
**avant** l'annonce du succes, et c'est pour cela qu'on ne peut pas les
rattacher apres coup.

**Confirmer.** `--objet` ne garde que les messages ou figure un identifiant
donne. Acheter un objet dont on connait le numero, puis demander a le voir
passer, transforme une intuition en fait.

Les messages de decor — presence des autres joueurs, chat, carte — sont ecartes
par defaut : ils representent l'essentiel du volume et ne concernent jamais
l'inventaire. `--sauf ''` les ramene.
"""
from __future__ import annotations

import argparse
import collections
import io
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from dofus_stats.capture.pcap_source import PcapSource
from dofus_stats.net.identify import load
from dofus_stats.session import Session

#: Ce qui remplit un flux sans rien dire du sujet : joueurs autour, chat,
#: deplacements, carte. A ecarter d'abord, quitte a le ramener ensuite.
DECOR = "jsj,jsn,kmu,iwn,izz,kti,jsq,hlm,jhd,jsd,lva,jru,jrw,jqi,jss,jrh"


def chemins(capture: str) -> tuple[str, str]:
    """La capture et sa photo de connexions, quelle que soit l'extension."""
    base, extension = os.path.splitext(capture)
    if not extension:
        for essai in (".pcap", ".pcapng"):
            if os.path.exists(base + essai):
                capture = base + essai
                break
    dossier, nom = os.path.split(os.path.splitext(capture)[0])
    return capture, os.path.join(dossier, f"hosts_{nom}.json")


def main(argv=None) -> int:
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("capture", help="chemin, avec ou sans extension")
    ap.add_argument("--codes", help="liste separee par des virgules")
    ap.add_argument("--objet", type=int, action="append",
                    help="ne garder que les messages citant cet identifiant")
    ap.add_argument("--de", type=float, default=0.0, metavar="SECONDES")
    ap.add_argument("--a", type=float, default=1e9, metavar="SECONDES")
    ap.add_argument("--sauf", default=DECOR)
    ap.add_argument("--large", type=int, default=320,
                    help="longueur maximale du rendu d'un message")
    ap.add_argument("--sortie", help="fichier ; la sortie standard sinon")
    args = ap.parse_args(argv)

    capture, hosts = chemins(args.capture)
    if not os.path.exists(capture):
        print(f"{capture} : introuvable", file=sys.stderr)
        return 2
    codes = set(args.codes.split(",")) if args.codes else None
    cibles = {str(o) for o in (args.objet or [])}
    sauf = set(args.sauf.split(",")) if args.sauf else set()
    # Un code demande explicitement passe, meme s'il est du decor : demander
    # `--codes jsn` et ne rien obtenir serait deroutant.
    if codes:
        sauf -= codes
    borne = args.de > 0 or args.a < 1e9
    detaille = bool(codes or cibles or borne)

    sortie = io.open(args.sortie, "w", encoding="utf-8") if args.sortie \
        else sys.stdout
    compte: collections.Counter = collections.Counter()
    par_client: collections.Counter = collections.Counter()
    t0 = None
    lignes = 0
    for obs in Session(clients=load(hosts)).run(PcapSource(capture).frames()):
        env = obs.env
        if t0 is None:
            t0 = env.ts
        t = env.ts - t0
        sens = "S->C" if env.from_server else "C->S"
        compte[(env.code, sens)] += 1
        par_client[obs.who] += 1
        if not detaille or env.code in sauf or not (args.de <= t <= args.a):
            continue
        if codes is not None and env.code not in codes:
            continue
        rendu = (env.top.render() if env.top else "").replace("\n", " ")
        while "  " in rendu:
            rendu = rendu.replace("  ", " ")
        if cibles and not any(c in rendu for c in cibles):
            continue
        sortie.write("{:8.2f} {} {:<14} {:<5} {}\n".format(
            t, sens, obs.who[:13], env.code, rendu[:args.large]))
        lignes += 1

    if detaille:
        sortie.write(f"{lignes} messages\n")
    else:
        sortie.write(f"clients : {dict(par_client)}\n")
        sortie.write(f"{len({c for c, _ in compte})} codes distincts\n")
        for (code, sens), n in compte.most_common():
            sortie.write(f"  {code:<6} {sens}  x{n}\n")
    if sortie is not sys.stdout:
        sortie.close()
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
