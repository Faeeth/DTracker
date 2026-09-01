"""Decodeur protobuf generique, sans schema.

Le wire format porte le numero de champ et son type physique. Cela suffit a
restituer entierement la STRUCTURE d'un message inconnu ; seul le NOM des champs
manque. C'est ce qui rend la cartographie des messages Dofus possible sans
disposer des .proto d'Ankama.
"""
from __future__ import annotations

import struct
from dataclasses import dataclass
from typing import Any

WIRE_VARINT, WIRE_64, WIRE_LEN, WIRE_SGROUP, WIRE_EGROUP, WIRE_32 = 0, 1, 2, 3, 4, 5


@dataclass
class Field:
    number: int
    wire: int
    value: Any                      # int | bytes | list[Field] | str
    raw: bytes = b""

    @property
    def is_message(self) -> bool:
        return isinstance(self.value, list)


def _varint(buf: bytes, pos: int) -> tuple[int, int]:
    value = shift = 0
    while pos < len(buf):
        byte = buf[pos]
        value |= (byte & 0x7F) << shift
        pos += 1
        if not byte & 0x80:
            return value, pos
        shift += 7
        if shift > 63:
            raise ValueError("varint trop long")
    raise ValueError("varint tronque")


def decode(data: bytes, depth: int = 0) -> list[Field]:
    """Decode un message. Leve ValueError si les octets ne sont pas du protobuf valide."""
    fields: list[Field] = []
    pos = 0
    while pos < len(data):
        start = pos
        tag, pos = _varint(data, pos)
        number, wire = tag >> 3, tag & 7
        if number == 0:
            raise ValueError("numero de champ nul")

        if wire == WIRE_VARINT:
            value, pos = _varint(data, pos)
        elif wire == WIRE_64:
            if pos + 8 > len(data):
                raise ValueError("champ 64 bits tronque")
            value, pos = struct.unpack("<Q", data[pos:pos + 8])[0], pos + 8
        elif wire == WIRE_32:
            if pos + 4 > len(data):
                raise ValueError("champ 32 bits tronque")
            value, pos = struct.unpack("<I", data[pos:pos + 4])[0], pos + 4
        elif wire == WIRE_LEN:
            length, pos = _varint(data, pos)
            if pos + length > len(data):
                raise ValueError("champ length-delimited tronque")
            chunk = data[pos:pos + length]
            pos += length
            value = _interpret(chunk, depth)
        else:
            raise ValueError(f"wire type non supporte: {wire}")

        fields.append(Field(number, wire, value, data[start:pos]))
    return fields


def _interpret(chunk: bytes, depth: int) -> Any:
    """Un champ length-delimited peut etre un sous-message, une chaine ou des octets."""
    if not chunk:
        return b""
    if depth < 12:
        try:
            sub = decode(chunk, depth + 1)
            if sub:
                return sub
        except ValueError:
            pass
    try:
        text = chunk.decode("utf-8")
        if text.isprintable():
            return text
    except UnicodeDecodeError:
        pass
    return chunk


def zigzag(value: int) -> int:
    """Interpretation sint32/sint64 d'un varint."""
    return (value >> 1) ^ -(value & 1)


def as_signed(value: int) -> int:
    """Interpretation int32/int64 d'un varint (negatifs encodes sur 10 octets)."""
    return value - (1 << 64) if value >= (1 << 63) else value


def render(fields: list[Field], indent: int = 0, max_bytes: int = 48) -> str:
    """Rendu texte arborescent, pour lecture humaine en debug."""
    pad = "  " * indent
    lines = []
    for f in fields:
        if f.is_message:
            lines.append(f"{pad}{f.number}: {{")
            lines.append(render(f.value, indent + 1, max_bytes))
            lines.append(f"{pad}}}")
        elif isinstance(f.value, str):
            lines.append(f'{pad}{f.number}: "{f.value}"')
        elif isinstance(f.value, bytes):
            shown = f.value[:max_bytes].hex()
            more = f"... (+{len(f.value) - max_bytes}o)" if len(f.value) > max_bytes else ""
            lines.append(f"{pad}{f.number}: 0x{shown}{more}")
        elif f.wire == WIRE_VARINT:
            signed = as_signed(f.value)
            shown = str(f.value) if signed == f.value else str(signed)
            lines.append(f"{pad}{f.number}: {shown}")
        elif f.wire == WIRE_32:
            as_float = struct.unpack("<f", struct.pack("<I", f.value))[0]
            lines.append(f"{pad}{f.number}: {f.value} (f32={as_float:.4g})")
        else:
            as_double = struct.unpack("<d", struct.pack("<Q", f.value))[0]
            lines.append(f"{pad}{f.number}: {f.value} (f64={as_double:.6g})")
    return "\n".join(l for l in lines if l)


def walk(fields: list[Field], path: tuple = ()):
    """Parcours recursif : rend (chemin, champ) pour chaque champ de l'arbre."""
    for f in fields:
        here = path + (f.number,)
        yield here, f
        if f.is_message:
            yield from walk(f.value, here)
