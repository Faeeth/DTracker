"""Enveloppe applicative Ankama.

Chaque message transporte un ou plusieurs google.protobuf.Any, reperables a leur
champ 1 de la forme "type.ankama.com/<code>". Le code, trois lettres obfusquees,
tient lieu d'identifiant de message. Les Any s'imbriquent : un message de lot
contient les evenements qu'il regroupe.

Plutot que de coder en dur la forme de l'enveloppe (qui peut changer), on cherche
les Any partout dans l'arbre. Robuste aux evolutions de structure.
"""
from __future__ import annotations

from dataclasses import dataclass, field as dc_field

from . import wire
from .wire import Field

TYPE_PREFIX = "type.ankama.com/"


@dataclass
class AnyMessage:
    code: str                       # ex. "jwe"
    depth: int                      # 0 = message principal, >0 = imbrique
    fields: list[Field]             # contenu decode du champ 2 de l'Any
    raw: bytes = b""

    def render(self) -> str:
        return wire.render(self.fields)


@dataclass
class Envelope:
    ts: float
    from_server: bool
    size: int
    tree: list[Field]
    anys: list[AnyMessage] = dc_field(default_factory=list)
    error: str | None = None

    @property
    def top(self) -> AnyMessage | None:
        return self.anys[0] if self.anys else None

    @property
    def code(self) -> str:
        return self.anys[0].code if self.anys else "?"

    @property
    def codes(self) -> list[str]:
        return [a.code for a in self.anys]

    @property
    def direction(self) -> str:
        return "S->C" if self.from_server else "C->S"


def parse(body: bytes, ts: float, from_server: bool) -> Envelope:
    try:
        tree = wire.decode(body)
    except ValueError as exc:
        return Envelope(ts, from_server, len(body), [], error=str(exc))
    env = Envelope(ts, from_server, len(body), tree)
    _collect(tree, env, 0)
    return env


def _collect(fields: list[Field], env: Envelope, depth: int) -> None:
    """Descend l'arbre en notant chaque Any rencontre, avec sa profondeur."""
    for f in fields:
        if not f.is_message:
            continue
        code = _any_code(f.value)
        if code is not None:
            payload = next((c.value for c in f.value if c.number == 2), [])
            body = payload if isinstance(payload, list) else []
            raw = payload if isinstance(payload, bytes) else b""
            env.anys.append(AnyMessage(code, depth, body, raw))
            _collect(body, env, depth + 1)
        else:
            _collect(f.value, env, depth)


def _any_code(fields: list[Field]) -> str | None:
    for f in fields:
        if f.number == 1 and isinstance(f.value, str) and f.value.startswith(TYPE_PREFIX):
            return f.value[len(TYPE_PREFIX):]
    return None
