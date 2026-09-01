"""Succes valides, et gains bruts d'experience et de kamas.

La validation d'un succes se lit sur une sequence de messages qui se termine par
`mfs`. Ce qui precede porte les recompenses :

    ivf  <nouveau solde de kamas>
    lqn  libelle 45, parametre = montant de kamas gagne
    kuf  <experience gagnee>
    iua  <objet recu>
    mfs  <identifiant du succes>          <- cloture

On accumule donc les recompenses au fil de l'eau et on les rattache au `mfs`
qui suit — mais seulement celles vues dans les secondes qui precedent. Sans
cette limite, un gain d'experience de combat, qui emprunte le meme message
`kuf`, reste en attente indefiniment et se retrouve attribue au premier succes
valide, fut-il plusieurs minutes plus tard. L'experience du combat est alors
comptee deux fois : une fois dans son recapitulatif, une fois dans le succes. Verifie sur trois series de quatre succes, sur trois personnages differents.
L'apercu d'un succes non encore valide annonce une unite d'experience de plus
que ce qui est reellement credite (34 398 pour 34 397) : c'est la recompense
nominale lue dans les donnees du client. Le chat du jeu, lui, affiche bien
34 397, et la hausse du total du personnage la reproduit exactement. On rend
donc la valeur du flux sans correction — l'ajuster fausserait tout cumul.

`ExperienceGain` et `KamasUpdate` sont emis independamment : ce sont des faits
bruts, valables quelle qu'en soit la cause. Un consommateur qui additionne a la
fois ces evenements et les `AchievementUnlocked` comptera deux fois les memes
gains ; c'est a lui de choisir son grain.
"""
from __future__ import annotations

from typing import Iterable

from ..events import AchievementUnlocked, Event, ExperienceGain, ItemStack, KamasUpdate
from ..protocol import wire
from ..session import Observed
from .base import Context, Extractor

KAMAS_LABEL = 45         # libelle de l'annonce "gain de kamas" dans `lqn`
UID_MIN, UID_MAX = 1_000_000, 1 << 40

# Delai au-dela duquel une recompense en attente n'appartient plus au succes qui
# suit. La validation d'un succes enchaine ses messages en quelques dizaines de
# millisecondes ; trois secondes laissent large sans ramasser un combat passe.
FENETRE = 3.0


class _Pending:
    """Recompenses vues depuis le dernier succes valide.

    Chaque entree porte son horodatage : au moment d'attribuer, on ecarte celles
    qui sont trop anciennes pour appartenir au succes.
    """

    def __init__(self) -> None:
        self.xp: list[tuple[float, int]] = []
        self.kamas: list[tuple[float, int]] = []
        self.items: list[tuple[float, ItemStack]] = []

    def clear(self) -> None:
        self.xp.clear()
        self.kamas.clear()
        self.items.clear()

    def recent(self, ts: float) -> tuple[list[int], list[int], list[ItemStack]]:
        """Recompenses assez proches de `ts` pour lui appartenir."""
        return ([v for t, v in self.xp if ts - t <= FENETRE],
                [v for t, v in self.kamas if ts - t <= FENETRE],
                [v for t, v in self.items if ts - t <= FENETRE])


class AchievementExtractor(Extractor):
    codes = frozenset({"mfs", "kuf", "ivf", "lqn", "iua", "ivj"})

    def __init__(self) -> None:
        self._pending: dict[str, _Pending] = {}

    def _bucket(self, who: str) -> _Pending:
        return self._pending.setdefault(who, _Pending())

    def handle(self, obs: Observed, ctx: Context) -> Iterable[Event]:
        env = obs.env
        top = env.top
        if top is None:
            return ()
        handler = getattr(self, "_on_" + env.code, None)
        return handler(obs, ctx, top.fields) if handler else ()

    # ------------------------------------------------------------------ sources

    def _on_kuf(self, obs, ctx, fields) -> Iterable[Event]:
        for f in fields:
            if f.number == 1 and f.wire == 0:
                self._bucket(obs.who).xp.append((obs.env.ts, f.value))
                return (ExperienceGain(obs.env.ts, obs.who, obs.who, f.value),)
        return ()

    def _on_ivf(self, obs, ctx, fields) -> Iterable[Event]:
        for f in fields:
            if f.number == 1 and f.wire == 0:
                previous = ctx.kamas.get(obs.who)
                ctx.kamas[obs.who] = f.value
                gain = f.value - previous if previous is not None else None
                return (KamasUpdate(obs.env.ts, obs.who, obs.who, f.value, gain),)
        return ()

    def _on_lqn(self, obs, ctx, fields) -> Iterable[Event]:
        """Annonce textuelle. Le libelle 45 porte un gain de kamas, dont le
        montant arrive comme parametre textuel. On lui fait confiance plutot
        qu'a la variation du solde : celle-ci rate le premier gain quand le
        solde de depart n'a jamais transite."""
        label = None
        params: list[str] = []
        for f in fields:
            if f.number == 2 and f.wire == 0:
                label = f.value
            elif f.number == 4 and isinstance(f.value, str):
                params.append(f.value)
        if label == KAMAS_LABEL and params:
            try:
                self._bucket(obs.who).kamas.append((obs.env.ts, int(params[0])))
            except ValueError:
                pass
        return ()

    def _on_iua(self, obs, ctx, fields) -> Iterable[Event]:
        for _, f in wire.walk(fields):
            if not f.is_message:
                continue
            sub = {c.number: c.value for c in f.value if c.wire == 0}
            uid, item_id = sub.get(4), sub.get(1)
            if uid is not None and item_id is not None and UID_MIN <= uid < UID_MAX:
                self._bucket(obs.who).items.append(
                    (obs.env.ts, ItemStack(item_id, sub.get(3, 1))))
        return ()

    def _on_ivj(self, obs, ctx, fields) -> Iterable[Event]:
        """`ivj` annonce la quantite totale apres coup, pas le gain : on le
        deduit de la derniere quantite connue pour cet objet."""
        sub: dict[int, int] = {}
        for _, f in wire.walk(fields):
            if f.is_message:
                for c in f.value:
                    if c.wire == 0:
                        sub[c.number] = c.value
        uid, total = sub.get(2), sub.get(3)
        if uid is None or total is None or not (UID_MIN <= uid < UID_MAX):
            return ()
        item_id = ctx.item_type(obs.who, uid)
        previous = ctx.item_quantity(obs.who, uid)
        ctx.learn_item(obs.who, uid, item_id, total)
        if item_id is None:
            return ()
        gain = total - previous if previous is not None else total
        if gain > 0:
            self._bucket(obs.who).items.append((obs.env.ts, ItemStack(item_id, gain)))
        return ()

    def _on_mfs(self, obs, ctx, fields) -> Iterable[Event]:
        """Cloture : le succes est valide, on lui attribue ce qui precede."""
        achievement_id = None
        for f in fields:
            if f.number == 4 and f.wire == 0:
                achievement_id = f.value
        if achievement_id is None:
            return ()
        bucket = self._bucket(obs.who)
        xp, kamas, items = bucket.recent(obs.env.ts)
        ctx.value(items)
        event = AchievementUnlocked(
            obs.env.ts, obs.who, achievement_id, obs.who,
            xp=xp[0] if xp else 0,
            kamas=kamas[0] if kamas else 0,
            rewards=items,
        )
        bucket.clear()
        return (event,)
