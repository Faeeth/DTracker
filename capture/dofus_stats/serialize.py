"""Conversion des evenements en structures JSON.

Le format est stable : c'est le contrat entre la bibliotheque et ses
consommateurs, quel que soit leur langage. Chaque evenement rend un objet plat
portant un champ `type` egal au nom de sa classe, ce qui permet de le router
sans connaitre le detail des autres.

Les valeurs absentes sont omises plutot que rendues nulles : un prix inconnu ne
doit pas se confondre avec un prix de zero, et un consommateur qui teste la
presence de la cle a une reponse claire.
"""
from __future__ import annotations

import dataclasses
import json
from typing import Any

from .events import Event


def to_dict(event: Event, *, drop_none: bool = True) -> dict[str, Any]:
    """Rend un evenement sous forme d'objet JSON-able.

    `drop_none` retire les champs vides. Le mettre a False donne un schema
    stable, toutes cles presentes, ce que preferent certains consommateurs
    types.
    """
    data = dataclasses.asdict(event)
    data["type"] = type(event).__name__
    return _clean(data) if drop_none else data


def _clean(value: Any) -> Any:
    if isinstance(value, dict):
        return {k: _clean(v) for k, v in value.items() if v is not None}
    if isinstance(value, (list, tuple)):
        return [_clean(v) for v in value]
    return value


def to_json(event: Event, *, drop_none: bool = True) -> str:
    """Rend une ligne JSON, sans saut de ligne, prete pour un flux NDJSON."""
    return json.dumps(to_dict(event, drop_none=drop_none),
                      ensure_ascii=False, separators=(",", ":"))


class EventEncoder(json.JSONEncoder):
    """Encodeur acceptant directement les evenements et les dataclasses."""

    def default(self, o: Any) -> Any:
        if isinstance(o, Event):
            return to_dict(o)
        if dataclasses.is_dataclass(o):
            return dataclasses.asdict(o)
        return super().default(o)
