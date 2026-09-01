"""Point d'entree de l'executable gele.

PyInstaller gele un script, pas un module : ce fichier n'existe que pour
appeler `dofus_stats.cli.stream` avec les arguments recus. Il porte le meme
comportement que `python -m dofus_stats.cli.stream`, aux memes options.
"""
from __future__ import annotations

import os
import sys

# Gele, le script tourne depuis un dossier ou le paquet est embarque ; lance
# depuis les sources, il faut ajouter la racine du depot.
if not getattr(sys, "frozen", False):
    sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from dofus_stats.cli.stream import main

if __name__ == "__main__":
    # Deux metiers dans un seul executable : ecouter le reseau, et tirer du
    # client du jeu les noms et les images. Le second ne sert qu'une fois,
    # mais il doit voyager avec le premier — il n'y a pas de Python sur la
    # machine ou l'outil est installe.
    if len(sys.argv) > 2 and sys.argv[1] == "--extraire":
        from dofus_stats.cli.extraction import extrait
        raise SystemExit(extrait(sys.argv[2],
                                 sys.argv[3] if len(sys.argv) > 3 else None))
    raise SystemExit(main())
