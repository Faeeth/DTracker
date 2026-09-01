"""Tire du client du jeu ce que l'affichage a besoin de savoir.

    dtracker-capture --extraire "%APPDATA%\\DTracker\\data"

Les noms d'objets, les images et les tables ne sont pas livres avec l'outil et
ne peuvent pas l'etre : ce sont les fichiers d'Ankama. La seule voie qui tienne
est de les tirer du client installe sur la machine — ce que fait ce module, en
s'appuyant sur `extract_data.py` et `extract_images.py`.

**On n'extrait pas tout.** Le client rend seize cents mega-octets d'images ;
l'application en lit deux cent quatorze. Les documents, les decors, les
assets du monde et les ecrans-titre ne sont jamais affiches. Se limiter a ce
qui sert fait la difference entre une extraction de quelques minutes et une
d'une demi-heure.

La progression part sur la sortie d'erreur, une ligne par etape, prefixee de
`#` comme le reste des diagnostics : l'application la relaie a l'ecran.
"""
from __future__ import annotations

import contextlib
import os
import sys

#: Les dossiers d'images que l'application lit vraiment. Voir
#: `app/lib/source/ressources.dart` : chaque categorie y nomme son dossier et
#: la variante qu'elle prefere.
DOSSIERS_UTILES = ["item", "class", "challenge", "monster", "achievement"]

#: Les icones de l'habillage — le symbole des kamas, celui des pods. Elles ne
#: sont pas dans le meme dossier du client que les objets.
DOSSIER_HABILLAGE = "icons"
DOSSIER_HABILLAGE_SOURCE = "aa/StandaloneWindows64"


def _dit(message: str) -> None:
    print(f"# {message}", file=sys.stderr, flush=True)


def extrait(cible: str, client: str | None = None) -> int:
    """Ecrit dans `cible` de quoi nommer et illustrer ce que le flux annonce.

    Rend 0 si tout s'est bien passe, 2 si le client est introuvable.
    """
    racine = os.path.dirname(os.path.dirname(os.path.dirname(
        os.path.abspath(__file__))))
    if racine not in sys.path:
        sys.path.insert(0, racine)
    # Geles, les deux scripts sont embarques dans l'executable ; depuis les
    # sources, ils vivent a la racine du depot de capture.
    try:
        import extract_data
        import extract_images
    except ImportError as exc:                          # pragma: no cover
        _dit(f"extraction-impossible : {exc}")
        return 2

    trouve = extract_data.find_client(client)
    if not trouve:
        _dit("client-introuvable : le dossier Dofus_Data n'a pas ete trouve")
        return 2
    _dit(f"client : {trouve}")

    os.makedirs(cible, exist_ok=True)

    # Les deux extracteurs racontent leur travail sur la sortie standard.
    # Celle-ci est reservee au flux d'evenements : on renvoie leur bavardage
    # vers la sortie d'erreur, avec le reste des diagnostics.
    with contextlib.redirect_stdout(sys.stderr):
        return _travaille(extract_data, extract_images, trouve, cible)


def _travaille(extract_data, extract_images, trouve: str, cible: str) -> int:
    # --------------------------------------------------------------- les noms
    #
    # Sans `--labels-only` : les deux tables que l'affichage lit — le detail
    # des objets et le graphisme des monstres — se calculent depuis les
    # enregistrements complets. Ceux-ci pesent quarante-quatre mega-octets et
    # ne servent qu'a cela ; on les efface une fois les tables ecrites.
    _dit("etape 1/3 : les noms et les tables")
    code = extract_data.main(["--client", trouve, "--out", cible])
    if code != 0:
        _dit(f"noms-en-echec : code {code}")
        return code

    # ------------------------------------------------------- les images du jeu
    _dit("etape 2/3 : les images des objets et des monstres")
    code = extract_images.main([
        "--client", trouve,
        "--out", os.path.join(cible, "images"),
        "--only", ",".join(DOSSIERS_UTILES),
        # La variante double resolution suffit : c'est celle que l'affichage
        # prefere, et prendre les trois triplait le temps et la place.
        "--scale", "2x",
    ])
    if code != 0:
        _dit(f"images-en-echec : code {code}")
        return code

    # ---------------------------------------------------- les icones d'habillage
    #
    # Le symbole des kamas et celui des pods ne sont pas dans le meme dossier
    # du client que les objets : ils appartiennent a l'habillage de
    # l'interface, et se prennent en une seconde passe.
    _dit("etape 3/3 : les icones de l'interface")
    code = extract_images.main([
        "--client", trouve,
        "--out", os.path.join(cible, "images"),
        "--folder", DOSSIER_HABILLAGE_SOURCE,
        "--only", DOSSIER_HABILLAGE,
        "--scale", "2x",
    ])
    if code != 0:
        _dit(f"icones-en-echec : code {code}")
        return code

    _menage(cible)
    _dit("extraction-terminee")
    return 0


def _menage(cible: str) -> None:
    """Efface les enregistrements complets, qui ont fait leur office.

    Ils ne servent qu'a calculer `objets.json` et `monstres.json`. Les garder
    laisserait quarante-quatre mega-octets que rien ne relit jamais.
    """
    import shutil

    records = os.path.join(cible, "records")
    if os.path.isdir(records):
        taille = sum(
            os.path.getsize(os.path.join(records, f))
            for f in os.listdir(records)
            if os.path.isfile(os.path.join(records, f))
        )
        shutil.rmtree(records, ignore_errors=True)
        _dit(f"menage : {taille // (1024 * 1024)} Mo d'enregistrements effaces")
