"""Evenements produits par la bibliotheque.

Ce sont les objets que consomme l'appelant. Ils sont volontairement independants
du protocole : un changement de code obfusque ou de structure de message se
rattrape dans un extracteur, sans toucher a ces definitions ni au code appelant.
"""
from __future__ import annotations

from dataclasses import dataclass, field

#: Valeur de l'issue chez un gagnant, dans le recapitulatif de fin de combat.
#:
#: Les autres n'en portent aucune : le wire format protobuf n'emet pas les
#: valeurs nulles, et c'est cette absence meme qui dit la defaite.
WINNER = 2


@dataclass
class Event:
    """Socle commun. `source` nomme le client sur lequel l'evenement a ete lu."""
    ts: float
    source: str


@dataclass
class ItemStack:
    """Un lot d'objets d'un meme type, en identifiants bruts.

    `source_id` designe l'origine du lot dans un recapitulatif de combat : il
    est commun a tous les participants, ce qui en fait vraisemblablement le
    monstre ou le groupe qui l'a lache.

    `unit_price` est le prix moyen que le serveur diffuse pour ce type d'objet
    (message `ivi`). Il vaut None tant qu'aucune table de prix n'a ete vue.

    Aucune traduction ici : la bibliotheque desérialise, elle ne nomme pas. Les
    libelles vivent dans les fichiers du client et seront traites separement.
    """
    item_id: int
    quantity: int = 1
    source_id: int | None = None
    unit_price: int | None = None

    @property
    def total_price(self) -> int | None:
        return None if self.unit_price is None else self.unit_price * self.quantity


@dataclass
class FightParticipant:
    character_id: int | None = None
    name: str | None = None
    level: int | None = None
    xp: int = 0
    xp_total: int = 0
    xp_floor: int = 0
    xp_next: int = 0
    kamas: int = 0
    loot: list[ItemStack] = field(default_factory=list)
    outcome: int | None = None

    @property
    def loot_value(self) -> int | None:
        values = [s.total_price for s in self.loot if s.total_price is not None]
        return sum(values) if values else None

    @property
    def level_progress(self) -> float:
        """Avancement dans le niveau courant, entre 0 et 1."""
        span = self.xp_next - self.xp_floor
        return (self.xp_total - self.xp_floor) / span if span > 0 else 0.0


@dataclass
class FightOpponent:
    """Un combattant d'en face, tel que le recapitulatif le designe.

    `monster_id` et `grade` viennent du placement, pas du recapitulatif : ce
    dernier ne porte que `fighter_id`. Ils restent nuls quand le combat a
    commence avant l'ecoute — on connait alors le nombre d'adversaires, pas
    leur espece.

    `outcome` vaut 2 quand ce combattant a gagne, et rien sinon. Il est donc
    nul dans le cas ordinaire, ou c'est nous qui l'emportons — et renseigne
    exactement quand le combat a ete perdu.
    """
    fighter_id: int
    monster_id: int | None = None
    grade: int | None = None
    outcome: int | None = None

    @property
    def won(self) -> bool:
        return self.outcome == WINNER


@dataclass
class FightStart(Event):
    """Entree en combat du personnage.

    Deduite du changement de contexte de jeu (`kmp`), que le serveur envoie a
    chaque client engage. `monster_group_id` n'est renseigne que si c'est ce
    client qui a lance l'attaque : il provient alors de sa requete `hqa`.
    """
    character: str | None = None
    monster_group_id: int | None = None
    initiated: bool = False       # ce client est-il l'attaquant ?


@dataclass
class FightLeave(Event):
    """Retour au contexte de jeu normal, apres un combat ou un changement de zone.

    Ne signifie pas a lui seul qu'un combat vient de finir : le meme changement
    de contexte accompagne d'autres transitions. Le recapitulatif `FightEnd`
    reste la source sure pour une fin de combat.
    """
    character: str | None = None


@dataclass
class FighterKicked(Event):
    """Exclusion d'un combattant pendant la phase de placement.

    La requete vient du meneur ; le personnage vise recoit de son cote une
    notification et retrouve le contexte de jeu normal.
    """
    character: str | None = None        # qui a demande l'exclusion
    target_id: int | None = None
    target_name: str | None = None


@dataclass
class FighterPlaced(Event):
    """Deplacement d'un combattant sur une case de depart, avant le lancement."""
    character: str | None = None
    fighter_id: int | None = None
    fighter_name: str | None = None
    cell: int | None = None


@dataclass
class TurnStart(Event):
    """Debut d'un tour de jeu. Le numero repart de 1 a chaque combat."""
    character: str | None = None
    turn: int = 0


@dataclass
class TurnEnd(Event):
    """Fin du tour d'un combattant, annoncee par le serveur.

    `requested` distingue une fin demandee par le joueur d'une fin subie, faute
    de temps : le clic passe par une requete cliente, pas l'expiration.
    """
    character: str | None = None
    fighter_id: int | None = None
    fighter_name: str | None = None
    requested: bool = False


@dataclass
class SpellCast(Event):
    """Lancer de sort, tel que le client le demande au serveur.

    Seul l'identifiant du sort circule ; le libelle vit dans les fichiers du
    client et n'est pas resolu ici. Verifie de facon croisee : un meme sort
    lance dans deux combats distincts porte le meme identifiant.
    """
    character: str | None = None
    spell_id: int | None = None
    cell: int | None = None


@dataclass
class CharacteristicChange(Event):
    """Variation d'une caracteristique pendant un combat.

    Couvre aussi bien la consommation de points d'action d'un lanceur que le
    gain accorde par un sort de soutien ou un malus inflige a l'adversaire.
    """
    character: str | None = None
    fighter_id: int | None = None
    fighter_name: str | None = None
    characteristic_id: int | None = None
    characteristic: str | None = None
    value: int | None = None


@dataclass
class FighterDamage(Event):
    """Degats subis par un combattant.

    Le montant est celui affiche dans le journal de combat. Le code d'action
    varie selon l'element du sort, aussi la detection repose sur la forme du
    message plutot que sur un code fige.
    """
    character: str | None = None
    target_id: int | None = None
    target_name: str | None = None
    amount: int = 0
    action_code: int | None = None
    element: str | None = None      # eau, terre, air, feu ; None si code inconnu
    erosion: int | None = None
    """Points de vie maximum perdus definitivement.

    Vaut exactement `degats x taux d'erosion`, verifie au point pres sur six
    coups couvrant trois taux differents (10, 20 et 30 pour cent) lors d'un duel
    ou le taux etait connu a chaque instant.

    Sur un coup qui tue, la valeur cesse de suivre cette regle : elle atteint
    parfois le plafond de cinquante pour cent, parfois des rapports
    inexplicables. Elle est alors rapportee telle quelle, sans correction.
    """


@dataclass
class EffectApplied(Event):
    """Effet ou etat pose sur un combattant.

    ATTENTION : `value` n'est pas fiable en l'etat. Sur deux effets confrontes
    au journal du jeu, il porte bien la valeur annoncee — dix pour une erosion
    de dix pour cent, deux pour un gain de deux points d'action. Mais sur
    d'autres effets du meme combat il vaut 18647, 25807 ou 4247, et vaut meme
    parfois exactement l'identifiant du sort. Le champ porte donc tantot une
    valeur, tantot un identifiant, selon un critere non identifie. Ne pas s'en
    servir sans verifier le cas d'usage.

    La duree n'est pas rapportee non plus : le message contient un sous-message
    qui lui est vraisemblablement destine, mais aucun de ses champs ne
    correspond a la duree affichee en jeu.

    Sont en revanche fiables : la cible, le lanceur, l'identifiant de l'effet et
    celui du sort d'origine.
    """
    character: str | None = None
    target_id: int | None = None
    target_name: str | None = None
    caster_id: int | None = None
    caster_name: str | None = None
    value: int | None = None
    effect_id: int | None = None
    spell_id: int | None = None
    trigger: str | None = None      # "I", "TB", "TE" — sens non verifie


@dataclass
class FighterDeath(Event):
    """Mort d'un combattant."""
    character: str | None = None
    fighter_id: int | None = None
    fighter_name: str | None = None


@dataclass
class FighterHealth(Event):
    """Points de vie d'un combattant, au debut du combat ou apres variation."""
    character: str | None = None
    current: int = 0
    maximum: int = 0


@dataclass
class ChallengeOffer(Event):
    """Challenges proposes au groupe, chacun avec son bonus en pourcentage."""
    character: str | None = None
    offers: list[tuple[int, int]] = field(default_factory=list)   # (identifiant, bonus)


@dataclass
class ChallengeSelected(Event):
    """Challenge retenu par le groupe."""
    character: str | None = None
    challenge_id: int | None = None


@dataclass
class ChallengeActive(Event):
    """Challenges reellement en cours dans le combat.

    A distinguer de la selection : un donjon impose ses propres challenges, qui
    n'ont jamais ete proposes ni choisis. Sur un combat observe, le joueur avait
    retenu le challenge 20 parmi deux propositions, et le serveur a declare
    actifs le 20 **et** un 973 venu du donjon. Ne lire que les selections en
    aurait perdu la moitie.
    """
    character: str | None = None
    challenges: list[tuple[int, int]] = field(default_factory=list)   # (id, bonus)


@dataclass
class ChallengeResult(Event):
    """Issue du challenge, annoncee en fin de combat.

    L'echec se lit a l'absence du champ de statut : le wire format protobuf
    n'emet pas les valeurs nulles.
    """
    character: str | None = None
    challenge_id: int | None = None
    succeeded: bool = False


@dataclass
class FightEnd(Event):
    """Fin de combat, avec le detail par participant."""
    participants: list[FightParticipant] = field(default_factory=list)

    #: Les combattants d'en face — les monstres, le plus souvent.
    #:
    #: Ils ne figurent pas dans `participants` : le recapitulatif ne leur
    #: donne ni experience ni butin, et les melanger aux notres fausserait
    #: tous les totaux.
    #:
    #: Ils sont la quelle que soit l'issue. Sur un combat perdu, c'est eux qui
    #: portent l'issue gagnante — voir `FightOpponent.won`.
    opponents: list[FightOpponent] = field(default_factory=list)

    #: Duree du combat en secondes, telle que le serveur l'annonce.
    #:
    #: C'est la duree que le jeu affiche : elle exclut la phase de placement.
    #: Elle est preferable a tout chronometre tenu par l'appelant — celui-ci
    #: ne connait ni l'instant exact ou le combat a commence, ni ce que le jeu
    #: choisit de compter.
    duration: float | None = None

    @property
    def total_xp(self) -> int:
        return sum(p.xp for p in self.participants)

    @property
    def total_kamas(self) -> int:
        return sum(p.kamas for p in self.participants)

    @property
    def total_value(self) -> int | None:
        """Valeur marchande du butin, si les prix sont connus. None si aucun
        prix ne l'est ; les objets sans prix connu sont simplement ignores."""
        values = [s.total_price for p in self.participants for s in p.loot
                  if s.total_price is not None]
        return sum(values) if values else None

    @property
    def total_loot(self) -> list[ItemStack]:
        merged: dict[int, ItemStack] = {}
        for p in self.participants:
            for stack in p.loot:
                cur = merged.get(stack.item_id)
                if cur is None:
                    merged[stack.item_id] = ItemStack(stack.item_id, stack.quantity,
                                                      unit_price=stack.unit_price)
                else:
                    cur.quantity += stack.quantity
        return sorted(merged.values(), key=lambda s: s.item_id)


@dataclass
class AchievementUnlocked(Event):
    """Succes valide, avec ce qu'il a rapporte."""
    achievement_id: int
    character: str | None = None
    xp: int = 0
    kamas: int = 0
    rewards: list[ItemStack] = field(default_factory=list)


@dataclass
class CharacterInfo(Event):
    """Ce que le jeu apprend d'un personnage croise : son nom, sa classe.

    Emis a la premiere rencontre et a chaque changement, jamais en boucle : la
    description d'une entite passe a chaque retour sur la carte, et la
    reemettre a l'identique noierait le flux.

    La classe n'arrive qu'avec `ilw`, donc au passage sur une carte. Un
    consommateur qui veut afficher un portrait a interet a conserver cette
    correspondance d'une session a l'autre : une soiree passee en donjon d'un
    bout a l'autre ne la verrait jamais.
    """
    character_id: int = 0
    name: str | None = None
    breed: int | None = None


@dataclass
class ExperienceGain(Event):
    """Gain d'experience brut, quelle qu'en soit la cause."""
    character: str | None = None
    amount: int = 0


@dataclass
class KamasUpdate(Event):
    """Nouveau solde de kamas. `gain` n'est renseigne que si un solde precedent
    etait connu ou si le serveur a annonce le montant."""
    character: str | None = None
    balance: int = 0
    gain: int | None = None


@dataclass
class CharacterState(Event):
    """Etat du personnage tel que le serveur le rappelle.

    Ce message accompagne chaque gain d'experience : le total est donc suivi en
    continu, sans avoir a ouvrir quoi que ce soit en jeu. Il sert de point de
    controle face au cumul des gains, qui reste la source a privilegier — un
    total peut manquer un gain si la capture demarre au mauvais moment.
    """
    character: str | None = None
    level: int | None = None
    xp_total: int = 0
    xp_floor: int = 0
    xp_next: int = 0
    kamas: int = 0

    @property
    def level_progress(self) -> float:
        span = self.xp_next - self.xp_floor
        return (self.xp_total - self.xp_floor) / span if span > 0 else 0.0


@dataclass
class Characteristic:
    """Une caracteristique, telle que le serveur la decompose."""
    char_id: int | None
    key: str
    base: int = 0
    bonus: int = 0

    @property
    def total(self) -> int:
        return self.base + self.bonus


@dataclass
class Characteristics(Event):
    """Feuille de caracteristiques du personnage.

    Le serveur l'envoie avec chaque rappel d'etat : ouvrir la page statistiques
    en jeu ne declenche aucun echange, l'information circule deja.
    """
    character: str | None = None
    level: int | None = None
    base_life: int = 0
    values: dict[str, Characteristic] = field(default_factory=dict)

    def get(self, key: str) -> int:
        c = self.values.get(key)
        return c.total if c else 0

    @property
    def vitality(self) -> int:
        """Vitalite affichee : points de vie de base plus bonus d'equipement."""
        return self.base_life + self.get("vitalite")

    @property
    def pods(self) -> int:
        """Pods affiches. Le serveur ne transmet que le supplement au-dela des
        1000 pods dont dispose tout personnage."""
        from .protocol.characteristics import BASE_PODS
        return BASE_PODS + self.get("pods")


@dataclass
class ItemConsumed(Event):
    """Un objet vient d'etre utilise : pochette ouverte, potion bue.

    Emis en plus des `ItemGained` que l'usage declenche. L'appelant qui compte
    le contenu d'une pochette doit pouvoir defalquer la pochette elle-meme :
    elle avait ete ramassee, donc comptee, et elle n'existe plus.

    `item_id` reste nul si l'objet n'a jamais ete vu entrer — une pochette
    d'avant le debut de l'ecoute. Rien n'est alors defalcable, et c'est juste :
    ce qui n'a pas ete compte n'a pas a etre repris.
    """
    character: str
    item_id: int | None
    item_uid: int
    quantity: int = 1


@dataclass
class ItemGained(Event):
    """Mouvement d'objet dans l'inventaire, hors combat.

    `quantity` est le gain, negatif en cas de perte. Il vaut None quand l'objet
    n'avait jamais ete vu : le serveur n'annonce qu'un total, et sans quantite
    precedente le gain est indeterminable.

    `item_id` vaut None tant que la correspondance identifiant unique -> type
    n'est pas connue. Elle vient de l'inventaire complet, que le serveur
    n'envoie qu'a l'ouverture de la fenetre en jeu.

    `origin` dit si l'objet a ete gagne ou seulement deplace : voir
    `extractors/exchange.py`.
    """
    character: str | None = None
    item_id: int | None = None
    item_uid: int | None = None
    quantity: int | None = None
    total: int = 0
    unit_price: int | None = None

    #: D'ou vient l'objet. `"pickup"` par defaut — un ramassage, une recolte,
    #: un gain. `"transfer"` quand il ne fait que changer de contenant : repris
    #: dans un coffre, ou rendu par un brisage. `"achievement"` pour les
    #: recompenses d'un succes, que `AchievementUnlocked` porte deja. Le
    #: serveur annonce tout cela de la meme facon ; seule la commande qui
    #: precede les separe.
    origin: str = "pickup"

    @property
    def gained(self) -> bool:
        """Vrai si l'objet entre reellement dans le patrimoine du joueur."""
        return self.origin == "pickup"

    @property
    def value(self) -> int | None:
        """Valeur marchande du gain, si le type et le prix sont connus."""
        if self.unit_price is None or self.quantity is None:
            return None
        return self.unit_price * self.quantity


@dataclass
class PodsUpdate(Event):
    """Poids porte par le personnage, rapporte a sa capacite.

    Emis a chaque variation de l'inventaire, donc a chaque ramassage. Le
    maximum recoupe la caracteristique de pods augmentee des 1000 de base.
    """
    character: str | None = None
    current: int = 0
    maximum: int = 0

    @property
    def ratio(self) -> float:
        return self.current / self.maximum if self.maximum else 0.0

    @property
    def full(self) -> bool:
        return self.maximum > 0 and self.current >= self.maximum


@dataclass
class PriceTable(Event):
    """Table des prix moyens diffusee par le serveur, un prix par type d'objet."""
    prices: dict[int, int] = field(default_factory=dict)
