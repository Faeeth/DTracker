"""Gele la diffusion de capture en un executable autonome.

    python tools/gele.py

Ecrit `dist/dtracker-capture.exe`. L'application Flutter le lance a la place
de `python -m dofus_stats.cli.stream` des qu'elle le trouve a cote d'elle :
personne n'a alors a installer Python pour se servir de l'outil.

**Ce que l'executable ne remplace pas.** La capture elle-meme reste l'affaire
de `dumpcap`, livre avec Wireshark, et du pilote npcap. Ni l'un ni l'autre ne
peut etre embarque ici : npcap installe un pilote reseau, ce qui demande son
propre installateur et son propre consentement. L'outil les detecte et le dit
quand ils manquent.

Un dossier plutot qu'un fichier unique (`--onefile`) : un exe unique se
decompresse dans un dossier temporaire a chaque lancement, ce qui ajoute une
seconde au demarrage et attire l'attention des antivirus. L'installateur, lui,
n'a aucune peine a poser un dossier.
"""
from __future__ import annotations

import os
import shutil
import subprocess
import sys

RACINE = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
NOM = "dtracker-capture"

#: Les gros paquets qu'un environnement Python de travail traine souvent, et
#: dont ni la capture ni l'extraction n'ont besoin.
EXCLUS = [
    "torch", "transformers", "scipy", "onnxruntime", "llvmlite", "numba",
    "matplotlib", "pandas", "IPython", "notebook", "imageio_ffmpeg", "av",
    "sympy", "tensorflow", "sklearn", "cv2", "babel",
]


def gele() -> int:
    dist = os.path.join(RACINE, "dist")
    travail = os.path.join(RACINE, "build", "pyinstaller")
    commande = [
        sys.executable, "-m", "PyInstaller",
        "--noconfirm",
        "--clean",
        "--name", NOM,
        # Console et non fenetre : la diffusion ecrit ses diagnostics sur la
        # sortie d'erreur, et l'application les relaie. Sans console, ces
        # messages disparaissent — et c'est par eux qu'on comprend pourquoi une
        # capture reste muette.
        "--console",
        # Les deux extracteurs vivent a la racine du depot et non dans le
        # paquet : PyInstaller ne les suivrait pas tout seul.
        "--paths", RACINE,
        "--hidden-import", "extract_data",
        "--hidden-import", "extract_images",
        # UnityPy n'est importe qu'au moment d'ouvrir un bundle : l'analyse
        # statique de PyInstaller ne le voit pas, et l'extraction des images
        # echouait dans l'executable gele en le reclamant.
        #
        # `--collect-submodules` et non `--collect-all` : ce dernier suit les
        # dependances declarees et ramassait quatre giga-octets — torch,
        # transformers, scipy — qui n'ont rien a faire ici.
        "--collect-submodules", "UnityPy",
        "--collect-data", "UnityPy",
        # UnityPy charge tous ses convertisseurs au demarrage, dont celui du
        # son, qui importe `fmod_toolkit` en dur. Sans sa DLL, l'import
        # echoue et emporte le decodage des **images** avec lui : toutes les
        # textures ressortaient « undecodable ». Un mega-octet et demi.
        "--collect-all", "fmod_toolkit",
        # `archspec` lit une table de microarchitectures rangee a cote de son
        # code : sans elle, la detection du processeur echoue et le decodage
        # des textures tombe avec. Ces deux-la sont des dependances de
        # `UnityPy` qui ne se voient qu'a l'usage.
        "--collect-all", "archspec",
        "--distpath", dist,
        "--workpath", travail,
        "--specpath", travail,
        # Le module est lance par son chemin, pas par `-m` : on gele donc un
        # petit lanceur qui appelle son `main`.
        # Ce que l'environnement de developpement traine et qui n'a rien a
        # faire dans une capture reseau. Nomme explicitement : PyInstaller
        # suit les imports transitifs, et un paquet scientifique installe a
        # cote suffit a doubler la taille.
        *[a for m in EXCLUS for a in ("--exclude-module", m)],
        os.path.join(RACINE, "tools", "_lanceur_capture.py"),
    ]
    print(" ".join(commande))
    code = subprocess.call(commande, cwd=RACINE)
    if code != 0:
        return code

    # PyInstaller pose l'exe dans un sous-dossier a son nom ; on remonte le
    # tout d'un cran pour que l'installateur n'ait qu'un dossier a copier.
    interne = os.path.join(dist, NOM)
    if os.path.isdir(interne):
        cible = os.path.join(dist, "capture")
        if os.path.isdir(cible):
            shutil.rmtree(cible)
        shutil.move(interne, cible)
        print(f"\n{os.path.join(cible, NOM + '.exe')}")
    return 0


if __name__ == "__main__":
    raise SystemExit(gele())
