"""Inventaire de tous les codes de message rencontres, identifies ou non.

Le protocole compte des centaines de messages dont une trentaine seulement a ete
elucidee. Les autres ne sont pas moins reels : ils passent, ils ont une forme,
une frequence, un sens de circulation. Les recenser au fil des captures evite
d'avoir a tout redecouvrir quand on s'attaque a l'un d'eux, et permet de voir
d'un coup d'oeil ce qui reste a faire.

L'inventaire s'accumule dans `data/codes.json`, enrichi a chaque passage. Pour
chaque code on garde ce qui aide a le reconnaitre plus tard : combien de fois
vu, dans quel sens, quelles tailles, la forme de son contenu, et les captures ou
il apparait.

    python tools/cartographie.py captures/*.pcapng
    python tools/cartographie.py --inconnus
    python tools/cartographie.py --detail jxm
"""
from __future__ import annotations

import argparse
import glob
import io
import json
import os
import sys
from collections import Counter

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

# L'inventaire contient des libelles accentues : une console Windows en page de
# code 1252 ne saurait pas les ecrire.
if hasattr(sys.stdout, "buffer"):
    sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding="utf-8",
                                  errors="replace", line_buffering=True)

from dofus_stats import Reader
from dofus_stats.protocol import wire

RACINE = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
INVENTAIRE = os.path.join(RACINE, "data", "codes.json")
MESSAGES = os.path.join(RACINE, "data", "messages.json")


def connus() -> dict[str, str]:
    if not os.path.exists(MESSAGES):
        return {}
    with open(MESSAGES, encoding="utf-8") as fh:
        return json.load(fh).get("names", {})


def charger() -> dict:
    if not os.path.exists(INVENTAIRE):
        return {}
    try:
        with open(INVENTAIRE, encoding="utf-8") as fh:
            return json.load(fh)
    except (OSError, json.JSONDecodeError):
        return {}


def enregistrer(inventaire: dict) -> None:
    os.makedirs(os.path.dirname(INVENTAIRE), exist_ok=True)
    with open(INVENTAIRE, "w", encoding="utf-8") as fh:
        json.dump(inventaire, fh, indent=1, ensure_ascii=False, sort_keys=True)


def forme(fields) -> str:
    """Signature de la structure : les numeros de champ et leur type.

    Deux messages de meme code partagent la meme forme ; c'est ce qui permet de
    reconnaitre un message deja croise sans avoir a relire son contenu.
    """
    morceaux = []
    for f in fields[:8]:
        if f.is_message:
            morceaux.append(f"{f.number}{{}}")
        elif isinstance(f.value, str):
            morceaux.append(f"{f.number}:str")
        elif isinstance(f.value, bytes):
            morceaux.append(f"{f.number}:oct")
        else:
            morceaux.append(f"{f.number}:num")
    return " ".join(morceaux)


def parcourir(chemins: list[str], inventaire: dict) -> int:
    noms = connus()
    total = 0
    for chemin in chemins:
        nom_capture = os.path.basename(chemin)
        hosts = os.path.join(os.path.dirname(chemin),
                             "hosts_" + nom_capture.replace(".pcapng", "") + ".json")
        try:
            lecteur = Reader.from_pcap(chemin,
                                       hosts=hosts if os.path.exists(hosts) else None)
            messages = list(lecteur.messages())
        except Exception as exc:                       # noqa: BLE001
            print(f"  {nom_capture} : illisible ({exc})", file=sys.stderr)
            continue

        for obs in messages:
            code = obs.env.code
            fiche = inventaire.setdefault(code, {
                "nom": noms.get(code, ""),
                "vus": 0,
                "sens": [],
                "taille_min": obs.env.size,
                "taille_max": obs.env.size,
                "formes": [],
                "captures": [],
                "exemple": "",
            })
            fiche["nom"] = noms.get(code, fiche.get("nom", ""))
            fiche["vus"] += 1
            fiche["taille_min"] = min(fiche["taille_min"], obs.env.size)
            fiche["taille_max"] = max(fiche["taille_max"], obs.env.size)
            if obs.env.direction not in fiche["sens"]:
                fiche["sens"].append(obs.env.direction)
            if nom_capture not in fiche["captures"]:
                fiche["captures"].append(nom_capture)
            if obs.env.top is not None:
                f = forme(obs.env.top.fields)
                if f and f not in fiche["formes"] and len(fiche["formes"]) < 6:
                    fiche["formes"].append(f)
                if not fiche["exemple"] and obs.env.top.fields:
                    rendu = wire.render(obs.env.top.fields).replace("\n", " ")
                    fiche["exemple"] = rendu[:160]
            total += 1
        print(f"  {nom_capture} : {len(messages)} messages", file=sys.stderr)
    return total


def resume(inventaire: dict, seulement_inconnus: bool = False) -> None:
    lignes = []
    for code, fiche in inventaire.items():
        if seulement_inconnus and fiche.get("nom"):
            continue
        lignes.append((fiche["vus"], code, fiche))
    lignes.sort(reverse=True)

    identifies = sum(1 for f in inventaire.values() if f.get("nom"))
    print(f"{len(inventaire)} codes recenses, {identifies} identifies, "
          f"{len(inventaire) - identifies} a elucider\n")
    print(f"  {'code':<6}{'vus':>8}  {'sens':<10}{'tailles':<14}{'nom':<26}captures")
    print("  " + "-" * 88)
    for vus, code, fiche in lignes[:60]:
        sens = "/".join(fiche["sens"])
        tailles = f"{fiche['taille_min']}-{fiche['taille_max']}o"
        print(f"  {code:<6}{vus:>8}  {sens:<10}{tailles:<14}"
              f"{fiche.get('nom', '') or '—':<26}{len(fiche['captures'])}")


def detail(inventaire: dict, code: str) -> None:
    fiche = inventaire.get(code)
    if fiche is None:
        print(f"code {code} jamais rencontre")
        return
    print(f"=== {code} ===")
    print(f"  nom       : {fiche.get('nom') or '(non identifie)'}")
    print(f"  vus       : {fiche['vus']} fois, sens {'/'.join(fiche['sens'])}")
    print(f"  tailles   : de {fiche['taille_min']} a {fiche['taille_max']} octets")
    print(f"  captures  : {', '.join(fiche['captures'][:6])}")
    print(f"  formes    :")
    for f in fiche["formes"]:
        print(f"      {f}")
    if fiche.get("exemple"):
        print(f"  exemple   : {fiche['exemple']}")


def main() -> int:
    ap = argparse.ArgumentParser(description="Cartographie des codes de message.")
    ap.add_argument("captures", nargs="*", help="fichiers a depouiller")
    ap.add_argument("--inconnus", action="store_true",
                    help="ne lister que les codes non identifies")
    ap.add_argument("--detail", metavar="CODE", help="tout ce qu'on sait d'un code")
    args = ap.parse_args()

    inventaire = charger()

    if args.detail:
        detail(inventaire, args.detail)
        return 0

    if args.captures:
        chemins = []
        for motif in args.captures:
            chemins.extend(sorted(glob.glob(motif)))
        if not chemins:
            print("aucune capture trouvee", file=sys.stderr)
            return 1
        avant = len(inventaire)
        parcourir(chemins, inventaire)
        enregistrer(inventaire)
        print(f"\n  {len(inventaire) - avant} nouveau(x) code(s) recense(s)",
              file=sys.stderr)

    resume(inventaire, args.inconnus)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
