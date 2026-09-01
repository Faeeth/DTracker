"""Veille passive : recense les codes de message au fil de l'eau.

Conçu pour tourner plusieurs heures sans surveillance. Chaque code jamais
rencontre est note dans un journal avec l'heure, sa forme et un exemple de
contenu — de quoi savoir plus tard quoi en faire sans avoir a rejouer la
session.

L'inventaire (`data/codes.json`) est enrichi et sauvegarde regulierement plutot
qu'a la fin : une veille de trois heures interrompue par une mise en veille de
la machine ne doit pas tout perdre.

La capture est relancee si elle s'arrete — le jeu peut fermer sa connexion, la
carte reseau se reinitialiser — de sorte que la veille survit a ces accidents.

    python tools/veille.py -i 8
    python tools/veille.py -i 8 --heures 3
"""
from __future__ import annotations

import argparse
import io
import json
import os
import sys
import time
from datetime import datetime

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

if hasattr(sys.stdout, "buffer"):
    sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding="utf-8",
                                  errors="replace", line_buffering=True)

from dofus_stats import Reader
from dofus_stats.protocol import wire

RACINE = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
INVENTAIRE = os.path.join(RACINE, "data", "codes.json")
MESSAGES = os.path.join(RACINE, "data", "messages.json")
JOURNAL = os.path.join(RACINE, "data", "nouveaux_codes.log")

INTERVALLE_SAUVEGARDE = 60.0      # secondes


def forme(fields) -> str:
    """Signature de structure : numeros de champ et types, sans les valeurs."""
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


def charger(chemin: str) -> dict:
    if not os.path.exists(chemin):
        return {}
    try:
        with open(chemin, encoding="utf-8") as fh:
            return json.load(fh)
    except (OSError, json.JSONDecodeError):
        return {}


def enregistrer(inventaire: dict) -> None:
    """Ecriture par fichier temporaire : une coupure au mauvais moment ne doit
    pas laisser un inventaire tronque a la place de l'ancien."""
    os.makedirs(os.path.dirname(INVENTAIRE), exist_ok=True)
    provisoire = INVENTAIRE + ".tmp"
    try:
        with open(provisoire, "w", encoding="utf-8") as fh:
            json.dump(inventaire, fh, indent=1, ensure_ascii=False, sort_keys=True)
        os.replace(provisoire, INVENTAIRE)
    except OSError:
        pass


def journaliser(ligne: str) -> None:
    try:
        with open(JOURNAL, "a", encoding="utf-8") as fh:
            fh.write(ligne + "\n")
    except OSError:
        pass


def main() -> int:
    ap = argparse.ArgumentParser(description="Veille passive sur les codes de message.")
    ap.add_argument("-i", "--interface", default="8")
    ap.add_argument("--heures", type=float, default=3.0,
                    help="duree de la veille ; 0 pour ne pas s'arreter")
    args = ap.parse_args()

    inventaire = charger(INVENTAIRE)
    noms = charger(MESSAGES).get("names", {})
    connus_au_depart = set(inventaire)

    debut = time.time()
    fin = debut + args.heures * 3600 if args.heures else None
    derniere_sauvegarde = debut
    total = 0
    nouveaux: list[str] = []

    entete = (f"# veille demarree le "
              f"{datetime.now().strftime('%d/%m/%Y a %H:%M:%S')} — "
              f"{len(connus_au_depart)} codes deja connus")
    print(entete)
    journaliser("")
    journaliser(entete)
    if fin:
        print(f"# duree prevue : {args.heures:g} h")
    print("# chaque code inedit est signale ici et ajoute a data/codes.json\n")

    while fin is None or time.time() < fin:
        try:
            lecteur = Reader.from_live(args.interface)
            for obs in lecteur.messages():
                total += 1
                code = obs.env.code
                fiche = inventaire.get(code)

                if fiche is None:
                    heure = datetime.now().strftime("%H:%M:%S")
                    structure = (forme(obs.env.top.fields)
                                 if obs.env.top is not None else "")
                    exemple = ""
                    if obs.env.top is not None and obs.env.top.fields:
                        exemple = wire.render(obs.env.top.fields).replace("\n", " ")[:150]
                    fiche = inventaire[code] = {
                        "nom": noms.get(code, ""),
                        "vus": 0,
                        "sens": [],
                        "taille_min": obs.env.size,
                        "taille_max": obs.env.size,
                        "formes": [structure] if structure else [],
                        "captures": ["veille"],
                        "exemple": exemple,
                        "decouvert": heure,
                    }
                    nouveaux.append(code)
                    ligne = (f"[{heure}] {code}  {obs.env.direction}  "
                             f"{obs.env.size}o  forme: {structure or '(vide)'}")
                    print(ligne)
                    if exemple:
                        print(f"           {exemple}")
                    journaliser(ligne)
                    if exemple:
                        journaliser(f"           {exemple}")

                fiche["vus"] += 1
                fiche["taille_min"] = min(fiche["taille_min"], obs.env.size)
                fiche["taille_max"] = max(fiche["taille_max"], obs.env.size)
                if obs.env.direction not in fiche["sens"]:
                    fiche["sens"].append(obs.env.direction)
                if "veille" not in fiche["captures"]:
                    fiche["captures"].append("veille")
                if obs.env.top is not None:
                    structure = forme(obs.env.top.fields)
                    if structure and structure not in fiche["formes"]:
                        if len(fiche["formes"]) < 8:
                            fiche["formes"].append(structure)

                maintenant = time.time()
                if maintenant - derniere_sauvegarde >= INTERVALLE_SAUVEGARDE:
                    enregistrer(inventaire)
                    derniere_sauvegarde = maintenant
                if fin and maintenant >= fin:
                    break

        except KeyboardInterrupt:
            break
        except Exception as exc:                       # noqa: BLE001
            # Le flux peut s'interrompre : reconnexion du jeu, carte reseau
            # reinitialisee. On repart plutot que d'abandonner la veille.
            print(f"# capture interrompue ({exc}) — reprise dans 5 s")
            enregistrer(inventaire)
            time.sleep(5)

    enregistrer(inventaire)
    duree = (time.time() - debut) / 3600
    bilan = (f"# veille terminee apres {duree:.1f} h — {total:,} messages lus, "
             f"{len(nouveaux)} code(s) inedit(s) : "
             f"{', '.join(nouveaux) if nouveaux else 'aucun'}")
    print("\n" + bilan)
    journaliser(bilan)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
