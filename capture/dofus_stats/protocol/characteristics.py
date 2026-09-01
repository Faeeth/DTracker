"""Identifiants des caracteristiques du personnage.

Etablis par confrontation avec la page statistiques de deux personnages de
classes differentes. Le message `kub` les transporte en permanence : ouvrir la
page en jeu ne declenche aucun echange reseau, tout est deja la.

Trois formes cohabitent dans le message :

  - la forme courante : `4: { 2: <base>, 7: <bonus> }`, le total etant la somme ;
  - les points d'action et de mouvement : `5: { 1: <base>, 5: <bonus> }` ;
  - l'energie : `2: { 2: <valeur> }`.

L'entree sans identifiant porte les points de vie de base (50 + 5 x niveau) ;
la vitalite affichee en jeu est cette base augmentee du bonus d'equipement.

Retrait et esquive de PA/PM ont d'abord ete attribues a l'envers : les quatre
valent la meme chose sur les personnages observes, si bien que la feuille de
statistiques ne permettait pas de les departager. Un sort accordant +20 en
esquive de PM a tranche — il porte sur la caracteristique 28 — et les malus de
retrait infliges par un autre sort ont confirme 82 et 83.
"""
from __future__ import annotations

# identifiant -> (cle, libelle)
CHARACTERISTICS: dict[int, tuple[str, str]] = {
    3: ("points_stats_restants", "Points de caracteristiques a distribuer"),
    10: ("force", "Force"),
    11: ("vitalite", "Vitalite (bonus d'equipement)"),
    12: ("sagesse", "Sagesse"),
    13: ("chance", "Chance"),
    14: ("agilite", "Agilite"),
    15: ("intelligence", "Intelligence"),
    16: ("portee", "Portee"),
    18: ("critique", "Coups critiques"),
    25: ("puissance", "Puissance"),
    19: ("dommages", "Dommages"),
    26: ("invocations", "Invocations"),
    27: ("esquive_pa", "Esquive de PA"),
    28: ("esquive_pm", "Esquive de PM"),
    29: ("energie", "Energie"),
    32: ("resistance_neutre_pct", "Resistance neutre en pourcentage"),
    33: ("resistance_terre_pct", "Resistance terre en pourcentage"),
    34: ("resistance_feu_pct", "Resistance feu en pourcentage"),
    35: ("resistance_eau_pct", "Resistance eau en pourcentage"),
    36: ("resistance_air_pct", "Resistance air en pourcentage"),
    40: ("pods", "Pods"),
    44: ("initiative", "Initiative"),
    47: ("energie_max", "Energie maximale"),
    48: ("prospection", "Prospection"),
    75: ("erosion_pct", "Erosion en pourcentage"),
    78: ("fuite", "Fuite"),
    79: ("tacle", "Tacle"),
    82: ("retrait_pa", "Retrait de PA"),
    83: ("retrait_pm", "Retrait de PM"),
}

# Les pods sont transmis en supplement des 1000 accordes a tout personnage :
# la valeur affichee en jeu est celle du message augmentee de cette base.
BASE_PODS = 1000
PODS = 40

# Caracteristiques valant systematiquement 100 chez tous les personnages
# observes. Deux d'entre elles correspondent vraisemblablement au bonus
# d'experience et au plafond de gain affiches en jeu, les autres restent a
# identifier ; toutes sont exposees telles quelles sous `carac_N`.
NEUTRAL_HUNDRED = frozenset({107, 120, 121, 122, 123, 124, 125, 141, 142, 143, 150})

# caracteristiques dont la valeur suit la forme `5: {1: base, 5: bonus}`
ACTION_POINTS = 1        # points d'action
MOVEMENT_POINTS = 23     # points de mouvement

# caracteristiques dont la valeur suit la forme `2: {2: valeur}`
SINGLE_VALUE = frozenset({29, 47})

BASE_LIFE = None         # l'entree sans identifiant


def name_of(char_id: int | None) -> str:
    if char_id is None:
        return "points_de_vie_base"
    if char_id == ACTION_POINTS:
        return "points_action"
    if char_id == MOVEMENT_POINTS:
        return "points_mouvement"
    known = CHARACTERISTICS.get(char_id)
    return known[0] if known else f"carac_{char_id}"
