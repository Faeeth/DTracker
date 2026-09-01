"""Lecture passive du trafic reseau de Dofus 3 (Unity).

Ecoute seule : la bibliotheque n'emet jamais rien et ne touche pas au client.

    from dofus_stats import Reader, FightEnd

    for event in Reader.from_pcap("session.pcapng").events():
        if isinstance(event, FightEnd):
            for p in event.participants:
                print(p.name, p.xp, p.kamas, p.loot)
"""
from .events import (
    AchievementUnlocked,
    Characteristic,
    Characteristics,
    CharacterState,
    EffectApplied,
    Event,
    CharacterInfo,
    ExperienceGain,
    FightEnd,
    ChallengeActive,
    ChallengeOffer,
    ChallengeResult,
    ChallengeSelected,
    CharacteristicChange,
    FighterDamage,
    FighterDeath,
    FighterHealth,
    FighterKicked,
    FighterPlaced,
    FightLeave,
    FightStart,
    FightParticipant,
    ItemConsumed,
    ItemGained,
    ItemStack,
    KamasUpdate,
    TurnEnd,
    SpellCast,
    TurnStart,
    PodsUpdate,
    PriceTable,
)
from .extractors.base import Context, Extractor, Pipeline
from .reader import Reader
from .serialize import to_dict, to_json
from .stream import (
    CallbackSink,
    FanOut,
    NdjsonSink,
    Sink,
    WebSocketSink,
    make_sink,
    stream,
)

__all__ = [
    "Reader",
    "Event",
    "FightEnd",
    "ChallengeOffer",
    "ChallengeActive",
    "ChallengeSelected",
    "ChallengeResult",
    "FightStart",
    "FightLeave",
    "FighterKicked",
    "FighterDamage",
    "SpellCast",
    "EffectApplied",
    "CharacteristicChange",
    "FighterDeath",
    "FighterHealth",
    "FighterPlaced",
    "FightParticipant",
    "ItemStack",
    "ItemConsumed",
    "ItemGained",
    "AchievementUnlocked",
    "CharacterState",
    "Characteristics",
    "Characteristic",
    "CharacterInfo",
    "ExperienceGain",
    "KamasUpdate",
    "PodsUpdate",
    "TurnStart",
    "TurnEnd",
    "PriceTable",
    "Extractor",
    "Pipeline",
    "Context",
    # diffusion vers un consommateur exterieur
    "to_dict",
    "to_json",
    "Sink",
    "NdjsonSink",
    "WebSocketSink",
    "CallbackSink",
    "FanOut",
    "make_sink",
    "stream",
]

__version__ = "1.0.0"
