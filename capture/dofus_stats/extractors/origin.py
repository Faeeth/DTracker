"""D'ou vient un objet qui entre dans l'inventaire.

Le serveur annonce de la meme facon un objet ramasse, un objet **repris dans un
coffre**, les runes d'un **brisage**, les recompenses d'un **succes** et le
contenu d'un **consommable ouvert** : `iua` ou `ivj`, l'objet entre dans
l'inventaire. Rien dans ces messages ne dit d'ou il vient, et les quatre
derniers cas n'ont rien d'un gain.

Ce qui les separe est la commande que le client a envoyee juste avant. La
reponse suit dans les vingt-cinq millisecondes :

    kcr  C->S  1: <quantite signee>  2: <identifiant unique>
               deplace un objet entre l'inventaire et l'echange ouvert.
               Positif : on depose. Negatif : on reprend.

    kbj  C->S  2: 1  3: <nombre>          lance le brisage

    mga  C->S                             reclame un succes

    iuu  C->S                             utilise un objet — ouvrir une
                                          pochette, boire une potion

Un retrait de coffre, dans l'ordre :

    kcr  C->S  1: -4  2: 190135620       reprendre quatre unites
    itc  S->C  1: 190135620              retirees **du coffre**
    iua  S->C  {1: 8139, 3: 4, ...}      ajoutees a l'inventaire
    kcu  S->C  1: 779  3: 2650           pods du coffre
    iun  S->C                            pods du personnage

Un brisage :

    kbj  C->S  2: 1  3: 2
    ium  S->C  x2                        les objets brises disparaissent
    iua  S->C  {1: 1523, 3: 2, ...}      les runes apparaissent
    kfp  S->C                            le detail du brisage

Un succes reclame :

    mga  C->S                            le joueur reclame
    ivf  S->C                            nouveau solde de kamas
    kuf  S->C                            experience gagnee
    ivj  S->C  x5                        les recompenses entrent
    iua  S->C  x1                        idem, objet neuf
    mfs  S->C                            **et seulement la**, le succes

Une pochette ouverte :

    iuu  C->S                            le joueur ouvre
    ivj  S->C                            le contenu entre
    lqn  S->C                            l'objet ouvert est decompte
    ium  S->C                            il disparait, s'il n'en restait qu'un
    iun  S->C                            pods du personnage

Noter l'ordre du dernier cas : les recompenses arrivent **avant** l'annonce du
succes. Un consommateur qui voudrait les rattacher apres coup ne le peut pas ;
c'est la commande qui precede qui renseigne, pas l'annonce qui suit.

Aucun de ces codes n'apparait dans les captures de jeu ordinaire : ni en
combat, ni en recolte. `iuu` a ete cherche dans les vingt-cinq captures du
depot — cent mille messages, dont un donjon complet et deux sessions de farm —
et ne s'y trouve que dans celle des consommables.

Cette absence ne prouve pas a elle seule ce que `iuu` designe : aucune de ces
captures ne contient d'ouverture, faute d'occasion. Elle prouve ce qui compte
ici, et c'est different : le code ne tombe pas pendant qu'on joue, donc le
lever ne peut pas faire disparaitre un vrai ramassage.

`iuu` est vraisemblablement « utiliser un objet » au sens large, et non la
seule ouverture d'une pochette — une potion bue, un parchemin lu porteraient
le meme code. Cela ne change rien a la regle : ce qui entre dans la foulee de
l'usage d'un objet n'est pas un butin de farm.
"""
from __future__ import annotations

from typing import Iterable

from ..events import Event, ItemConsumed
from ..protocol import wire
from ..session import Observed
from .base import Context, Extractor

#: Delai au-dela duquel une commande ne repond plus de rien. La reponse
#: observee vient en vingt-cinq millisecondes ; deux secondes laissent de la
#: marge a un serveur charge sans couvrir l'action suivante du joueur.
COMMAND_WINDOW = 2.0

#: Commande du client -> provenance de ce qui entre dans la foulee.
COMMANDS = {
    "kcr": "transfer",      # deplacement dans un coffre, un broyeur, un echange
    "kbj": "transfer",      # brisage : les runes remplacent les objets brises
    "mga": "achievement",   # recompenses d'un succes reclame
    "iuu": "use",           # objet utilise : pochette ouverte, potion bue
}


class OriginExtractor(Extractor):
    """Note ce que le client vient de demander.

    N'emet qu'une chose, et seulement pour `iuu` : l'objet consomme, que
    l'appelant peut avoir besoin de defalquer.
    """

    codes = frozenset(COMMANDS)
    priority = 5

    def handle(self, obs: Observed, ctx: Context) -> Iterable[Event]:
        # Seulement dans le sens client -> serveur : c'est une commande, et la
        # trace serveur du meme geste porte d'autres codes.
        if obs.env.from_server:
            return ()
        ctx.commands[obs.who] = (obs.env.ts, COMMANDS[obs.env.code])
        if obs.env.code != "iuu":
            return ()
        return self._consomme(obs, ctx)

    @staticmethod
    def _consomme(obs: Observed, ctx: Context) -> Iterable[Event]:
        """`iuu  3: <identifiant unique>` — l'objet que le joueur utilise."""
        top = obs.env.top
        if top is None:
            return ()
        uid = None
        for _, f in wire.walk(top.fields):
            if f.number == 3 and f.wire == 0:
                uid = f.value
                break
        if uid is None:
            return ()
        ctx.consumed[obs.who] = (obs.env.ts, uid)
        return (ItemConsumed(obs.env.ts, obs.who, obs.who,
                             ctx.item_type(obs.who, uid), uid),)
