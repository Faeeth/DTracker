# DTracker

Suivi de session pour Dofus 3 : experience, kamas, butin et combats, lus
**sur le reseau** et affiches a cote du jeu — ou par-dessus, dans une
surcouche translucide.

    capture/   la bibliotheque qui ecoute et decode le protocole (Python)
    app/       l'application (Flutter, Windows)

## Ce que l'outil fait, et ce qu'il ne fait pas

Il **ecoute**, et rien d'autre. Aucun paquet envoye au jeu, aucun fichier du
client modifie, aucune automatisation. C'est un outil de lecture, au meme
titre qu'un compteur pose a cote de l'ecran.

Le protocole de Dofus 3 circule en clair : `[longueur][protobuf]` sur le port
5555. Les codes de messages sont obfusques et changent a chaque correctif du
jeu — c'est pourquoi la bibliotheque est tenue par cent-quarante-huit
verifications sur des captures reelles, seul garde-fou serieux quand les noms
ne veulent rien dire.

## Installer

Voir [INSTALLATION.md](INSTALLATION.md). En deux lignes : Wireshark (pour son
pilote de capture), puis l'installateur de la derniere
[release](../../releases).

## Developper

    cd capture && python tests/test_regression.py     # 148 verifications
    cd app     && flutter test                        # 170 cas
    cd app     && flutter run -d windows

Depuis les sources, l'application lance `python -m dofus_stats.cli.stream`.
Une fois installee, elle lance l'executable gele que produit
`capture/tools/gele.py` — l'utilisateur n'a alors pas a avoir Python.

## Publier une version

    git tag v1.0.0 && git push --tags

Le workflow construit tout, compose l'archive et ouvre une release en
brouillon.
