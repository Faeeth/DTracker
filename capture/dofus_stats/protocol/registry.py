"""Correspondance code -> nom lisible.

Les codes a trois lettres sont obfusques et changent potentiellement a chaque
patch. Le dictionnaire vit donc dans un fichier JSON externe, regenerable, et
non en dur dans le code.
"""
from __future__ import annotations

import json
import os

_DEFAULT = os.path.join(os.path.dirname(__file__), "..", "..", "data", "messages.json")


class Registry:
    def __init__(self, path: str | None = None):
        self.path = os.path.abspath(path or _DEFAULT)
        self.names: dict[str, str] = {}
        self.notes: dict[str, str] = {}
        self.load()

    def load(self) -> None:
        if not os.path.exists(self.path):
            return
        with open(self.path, "r", encoding="utf-8") as fh:
            data = json.load(fh)
        self.names = data.get("names", {})
        self.notes = data.get("notes", {})

    def save(self) -> None:
        os.makedirs(os.path.dirname(self.path), exist_ok=True)
        with open(self.path, "w", encoding="utf-8") as fh:
            json.dump({"names": self.names, "notes": self.notes}, fh,
                      indent=2, ensure_ascii=False, sort_keys=True)

    def name(self, code: str) -> str:
        return self.names.get(code, code)

    def label(self, code: str) -> str:
        known = self.names.get(code)
        return f"{code} ({known})" if known else code
