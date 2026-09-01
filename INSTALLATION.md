# Installer DTracker

## Ce qu'il faut avant

**Wireshark** — [wireshark.org/download.html](https://www.wireshark.org/download.html)

DTracker n'écoute pas le réseau lui-même. Il lui faut deux choses :

- **npcap**, le pilote qui donne accès au trafic. Lire les paquets se fait
  dans le noyau de Windows : aucun programme ne peut s'en passer.
- **dumpcap**, le moteur de capture livré avec Wireshark.

Ni l'un ni l'autre n'est fourni avec DTracker. Ce n'est pas un oubli : la
licence de npcap interdit de le redistribuer. L'installateur les cherche, dit
lesquels manquent, et **propose de télécharger npcap depuis son site
officiel** — vous verrez alors sa propre licence.

Le plus simple reste d'installer Wireshark : il propose npcap au passage, et
vous aurez les deux d'un coup. Laissez la case npcap cochée ; le reste peut
être décoché.

Python n'est pas nécessaire : la partie qui décode le protocole du jeu est
livrée compilée.

## Installer

1. Ouvrez le `.zip` téléchargé.
2. Lancez `DTracker-<version>-installateur.exe`.
3. Suivez les trois écrans.

L'installation se fait **pour votre compte utilisateur seulement** : Windows
ne demande pas de mot de passe administrateur, et rien n'est écrit en dehors
de vos dossiers personnels.

## Mettre à jour

Lancez le nouvel installateur par-dessus l'ancien. **Vos réglages, votre
cache de prix et l'historique de vos sessions ne sont pas touchés** : ils
vivent dans `%APPDATA%\DTracker`, où l'installateur n'écrit jamais.

## Désinstaller

Paramètres Windows → Applications → DTracker → Désinstaller. Ou l'entrée
« Désinstaller DTracker » du menu Démarrer.

La désinstallation laisse `%APPDATA%\DTracker` en place, pour qu'une
réinstallation retrouve vos sessions. Pour tout effacer, supprimez ce dossier
à la main — collez `%APPDATA%\DTracker` dans la barre d'adresse de
l'Explorateur.

## Au premier lancement

L'outil a besoin des noms d'objets, des images et des tables du jeu. **Ils ne
sont pas livrés avec** : ce sont les fichiers d'Ankama, et ils ne peuvent pas
être redistribués. DTracker les extrait de votre propre client Dofus, une
fois, au premier lancement.

Sans cette extraction, l'outil fonctionne quand même : les gains, les combats
et les cadences sont justes. Ce sont les noms et les images qui manquent —
un objet s'affiche alors « Objet 1731 ».

## Ce que fait l'outil, et ce qu'il ne fait pas

Il **écoute**. Il ne parle jamais au jeu : aucun paquet envoyé, aucun fichier
du client modifié, aucune automatisation. C'est un outil de lecture, au même
titre qu'un compteur regardé à côté de l'écran.

## Si rien ne remonte

Dans **Réglages → Capture**, laissez « Toutes les interfaces ». Si vous avez
choisi une carte à la main, c'est la première chose à défaire : le jeu peut
passer par l'Ethernet, le Wi-Fi ou un VPN, et cela change quand on débranche
un câble.

Le voyant en bas du panneau de gauche dit ce qu'il en est ; survolez-le, il
détaille.
