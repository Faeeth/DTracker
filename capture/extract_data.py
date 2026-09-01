"""Extract game data from the Dofus client into compact JSON dictionaries.

Run this again after every game update: identifiers change, and so do labels.
One command rebuilds everything.

    python extract_data.py
    python extract_data.py --labels-only
    python extract_data.py --client "D:\\Games\\Dofus\\Dofus_Data"

Two client files are cross-referenced:

  - `Content/Data/*.bundle` — Unity asset bundles, one per category, each
    holding the whole table for that category;
  - `Content/I18n/fr.bin` — the text catalogue the labels come from.

The bundles carry their own type description, so the records are read with
their real field names rather than guessed at. A challenge comes out as
`{id, nameId, descriptionId, incompatibleChallenges, categoryId, iconId,
completionCriterion, activationCriterion, targetMonsterId}` — the wire protocol
sends only that first number.

Three files are written per category:

  - `data/labels/<category>.json`, just identifier to label, which is what a
    display needs and small enough to load without thinking about it;
  - `data/icons/<category>.json`, identifier to `iconId`, the other half of
    what a display needs — it ties a record to the artwork extract_images.py
    pulls out, without loading the records themselves;
  - `data/records/<category>.json`, every field of every record, with the label
    and description resolved. Skip these with --labels-only.

Reading the type description needs UnityPy. Without it the tool falls back on
scanning the raw bytes for (identifier, label, description) triples, which
recovers most categories but not all: it cannot tell a real record from three
neighbouring integers that happen to look like one. The verdict of each
category is recorded in the manifest either way.

Labels come from the French catalogue, matching the client. A few are in
English there; they are kept as they are rather than dropped.
"""
from __future__ import annotations

import argparse
import io
import json
import os
import re
import struct
import sys
import time
import warnings

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

if hasattr(sys.stdout, "buffer"):
    sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding="utf-8",
                                  errors="replace", line_buffering=True)

from dofus_stats.protocol.i18n import Texts
from dofus_stats.protocol.unitybundle import Bundle, BundleError

ROOT = os.path.dirname(os.path.abspath(__file__))
LABELS = os.path.join(ROOT, "data", "labels")
RECORDS = os.path.join(ROOT, "data", "records")
DATA = os.path.join(ROOT, "data")


def set_output(folder: str) -> None:
    """Write somewhere else than next to this script.

    The installed application keeps the game data in the user's own folder:
    it is extracted from *their* client, and must survive an update that
    replaces the program.
    """
    global LABELS, RECORDS, DATA, ICONS
    DATA = folder
    LABELS = os.path.join(folder, "labels")
    RECORDS = os.path.join(folder, "records")
    ICONS = os.path.join(folder, "icons")
ICONS = os.path.join(ROOT, "data", "icons")

# Usual client locations, tried in order.
CLIENT_PATHS = [
    os.path.expandvars(r"%LOCALAPPDATA%\Ankama\Dofus-dofus3\Dofus_Data"),
    r"C:\Program Files\Ankama\Dofus\Dofus_Data",
    r"C:\Program Files (x86)\Ankama\Dofus\Dofus_Data",
]

PREFIX = "data_assets_"
SUFFIX = "dataroot.asset.bundle"

# Fallback if the engine version cannot be read from the client.
ASSUMED_UNITY = "6000.3.16f1"

# Known identifiers per category, to confirm a category reads correctly.
# Categories absent from this table are still written, simply without a verdict.
WITNESSES = {
    "items": {
        303: "Bois de Frêne",
        2663: "Engrais",
        8127: "Faux usée du Paysan",
    },
    "achievements": {
        488: "Tournesol Affamé (Duo)",
        6149: "Tournesol Affamé (Spécial)",
    },
    "spells": {
        13106: "Pression",
        25860: "Mot Turbulent",
    },
    "challenges": {
        20: "Élémentaire",
    },
}

# Bounds for the fallback scan only.
MAX_ID = 200_000
MIN_TEXT_ID, MAX_TEXT_ID = 1000, 1_400_000
MAX_LABEL_LENGTH = 60


def find_client(given: str | None) -> str | None:
    if given:
        return given if os.path.isdir(given) else None
    for path in CLIENT_PATHS:
        if os.path.isdir(path):
            return path
    return None


def unity_version(client: str) -> str:
    """Engine version, taken from the client itself.

    The bundle headers claim "5.x.x", which no reader can act on. The real
    number sits in plain text at the head of `globalgamemanagers`.
    """
    marker = os.path.join(client, "globalgamemanagers")
    if os.path.exists(marker):
        with open(marker, "rb") as fh:
            found = re.search(rb"\d+\.\d+\.\d+[abfp]\d+", fh.read(4096))
        if found:
            return found.group().decode("ascii")
    return ASSUMED_UNITY


def list_bundles(data_dir: str) -> list[tuple[str, str]]:
    """Every data bundle present, as (category, path).

    Read from the folder rather than a fixed list: a game update may add
    bundles, and they should be picked up without touching this file.
    """
    found = []
    for name in sorted(os.listdir(data_dir)):
        if not (name.startswith(PREFIX) and name.endswith(SUFFIX)):
            continue
        found.append((name[len(PREFIX):-len(SUFFIX)], os.path.join(data_dir, name)))
    return found


def read_records(path: str) -> list[dict]:
    """Every record of a bundle, read through its own type description.

    Records live in the `references` block as typed entries; `objectsById`
    only indexes them. The class name is kept: a category may hold several,
    items being both `ItemData` and `WeaponData`.
    """
    import UnityPy

    records = []
    env = UnityPy.load(path)
    for obj in env.objects:
        if obj.type.name != "MonoBehaviour":
            continue
        tree = obj.read_typetree()
        for ref in tree.get("references", {}).get("RefIds", []):
            data = ref.get("data")
            if isinstance(data, dict):
                records.append({"class": ref.get("type", {}).get("class", ""), **data})
    return records


def scan_bytes(blob: bytes, texts: Texts, description_at: int) -> dict[int, str]:
    """Fallback: recover (identifier, label) pairs by reading raw integers.

    A record starts with its identifier followed by the identifier of its
    label; the description sits either eight or twelve bytes further along
    depending on the category, so both are tried and the richer reading wins.
    Requiring the description to exist as well is what separates a record from
    a coincidence between neighbouring integers — imperfectly.
    """
    found: dict[int, str] = {}
    for pos in range(0, len(blob) - description_at - 4, 4):
        entity, label_id = struct.unpack_from("<2I", blob, pos)
        if not (1 <= entity < MAX_ID):
            continue
        if not (MIN_TEXT_ID < label_id < MAX_TEXT_ID):
            continue
        description_id = struct.unpack_from("<I", blob, pos + description_at)[0]
        if not (MIN_TEXT_ID < description_id < MAX_TEXT_ID):
            continue
        label = texts.get(label_id)
        if not label or not (2 <= len(label) <= MAX_LABEL_LENGTH) or label.isdigit():
            continue
        if texts.get(description_id) is None:
            continue
        found.setdefault(entity, label)
    return found


def read_by_scan(path: str, texts: Texts) -> list[dict]:
    """Fallback reading, dressed up as records so the rest is unaware."""
    blob = b"".join(f.data for f in Bundle(path).files)
    best: dict[int, str] = {}
    for offset in (12, 8):
        found = scan_bytes(blob, texts, offset)
        if len(found) > len(best):
            best = found
    return [{"class": "", "id": k, "name": v} for k, v in sorted(best.items())]


# Champs portant le libelle, par ordre de preference. Toutes les tables
# n'emploient pas le meme nom : les classes n'ont qu'un `shortNameId`, ce qui
# les faisait passer inapercues.
NAME_FIELDS = ("nameId", "shortNameId", "longNameId", "labelId")


def as_int(value) -> int | None:
    """A whole number, whatever shape it arrived in.

    The type reader renders 64-bit fields as strings — a sound choice for JSON,
    but it means a perfectly ordinary identifier can turn up as `"685"`.
    Comparing it to an integer then silently fails, and a whole category comes
    out empty without any error to explain it.
    """
    if isinstance(value, bool):
        return None
    if isinstance(value, int):
        return value
    if isinstance(value, str) and value.lstrip("-").isdigit():
        return int(value)
    return None


def resolve(records: list[dict], texts: Texts) -> tuple[dict[int, str], list[dict]]:
    """Turn text identifiers into text. Returns (labels, records)."""
    labels: dict[int, str] = {}
    for record in records:
        entity = as_int(record.get("id"))
        name = record.get("name")
        if name is None:
            for field in NAME_FIELDS:
                name_id = as_int(record.get(field))
                name = texts.get(name_id) if name_id is not None else None
                if name:
                    record["name"] = name
                    break
        description_id = as_int(record.get("descriptionId"))
        if description_id is not None:
            description = texts.get(description_id)
            if description:
                record["description"] = description
        if entity is not None and name:
            labels.setdefault(entity, name)
    return labels, records


def icons_of(records: list[dict]) -> dict[int, int]:
    """Entity to icon, pulled out of the records.

    A separate small file rather than a lookup in `data/records/`: a display
    wanting the picture of an object should not have to load forty megabytes
    of item statistics to find its `iconId`.
    """
    found: dict[int, int] = {}
    for record in records:
        entity, icon = as_int(record.get("id")), as_int(record.get("iconId"))
        if entity is not None and icon is not None:
            found.setdefault(entity, icon)
    return found


def validate(labels: dict[int, str], known: dict[int, str]) -> tuple[bool, str]:
    """Check a category against labels we already know."""
    if not known:
        return True, "no witness available"
    hits = sum(1 for entity, label in known.items()
               if labels.get(entity, "").lower() == label.lower())
    return hits == len(known), f"{hits}/{len(known)} witnesses matched"


def write_json(path: str, payload) -> int:
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "w", encoding="utf-8") as fh:
        # Compact on purpose: these files are read by the program, and
        # indentation would double their size for nothing.
        json.dump(payload, fh, ensure_ascii=False, separators=(",", ":"),
                  default=str)
    return os.path.getsize(path)


def write_item_digest(records_dir: str, labels_dir: str, out: str) -> int:
    """Write a small per-item digest: level, weight and type name.

    `records/items.json` weighs forty-four megabytes. Loading it to show three
    fields in a tooltip would be absurd, so the useful part is distilled here
    — the same way icon ids already are. The result is under a megabyte and is
    read on demand by the interface.
    """
    try:
        with open(os.path.join(records_dir, "items.json"),
                  encoding="utf-8") as fh:
            items = json.load(fh)
        with open(os.path.join(labels_dir, "itemtypes.json"),
                  encoding="utf-8") as fh:
            types = json.load(fh)
    except (OSError, json.JSONDecodeError):
        return 0

    digest = {}
    for item in items:
        if not isinstance(item, dict) or "id" not in item:
            continue
        level = item.get("level") or 0
        weight = item.get("realWeight") or 0
        kind = types.get(str(item.get("typeId")), "")
        # Only what adds something: an item with no level, no weight and no
        # type has nothing to say beyond its name.
        if not level and not weight and not kind:
            continue
        digest[str(item["id"])] = {"n": level, "p": weight, "t": kind}
    return write_json(out, digest)


def write_monster_digest(records_dir: str, out: str) -> int:
    """Write each monster's sprite id and its level, one per grade.

    A fight's summary names its losers by monster id and grade. Two things are
    missing to show them: the level the game prints beside the name, and the
    picture.

    The picture needs a detour. `images/monster/` is indexed by **gfxId**, the
    sprite, not by monster id — and the two ranges overlap, so using one for
    the other silently yields a wrong picture rather than none: a Moskito came
    out as "La Folle", a Champ Champ as "Boo". Both ids exist, neither warns.
    The mapping is written here, once.

    Entries are `{"g": <gfxId>, "n": {<grade>: <level>}}`.
    """
    try:
        with open(os.path.join(records_dir, "monsters.json"),
                  encoding="utf-8") as fh:
            monsters = json.load(fh)
    except (OSError, json.JSONDecodeError):
        return 0

    digest = {}
    for monster in monsters:
        if not isinstance(monster, dict) or "id" not in monster:
            continue
        levels = {}
        for grade in monster.get("grades", []):
            if not isinstance(grade, dict):
                continue
            rank, level = grade.get("grade"), grade.get("level")
            if rank and level:
                levels[str(rank)] = level
        gfx = monster.get("gfxId")
        if not levels and not gfx:
            continue
        entree = {}
        if gfx:
            entree["g"] = gfx
        if levels:
            entree["n"] = levels
        digest[str(monster["id"])] = entree
    return write_json(out, digest)


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(
        description="Extract game data from the Dofus client.")
    parser.add_argument("--client", help="the game's Dofus_Data folder")
    parser.add_argument("--labels-only", action="store_true",
                        help="skip data/records/, keep only identifier to label")
    parser.add_argument("--out", help="write there instead of ./data")
    args = parser.parse_args(argv)
    if args.out:
        set_output(args.out)

    client = find_client(args.client)
    if not client:
        print("Client not found. Point at it with --client.", file=sys.stderr)
        return 1
    data_dir = os.path.join(client, "StreamingAssets", "Content", "Data")
    catalogue = os.path.join(client, "StreamingAssets", "Content", "I18n", "fr.bin")
    if not os.path.isdir(data_dir) or not os.path.exists(catalogue):
        print(f"Incomplete data folder: {client}", file=sys.stderr)
        return 1

    try:
        import UnityPy
    except ImportError:
        UnityPy = None

    version = unity_version(client)
    if UnityPy is not None:
        UnityPy.config.FALLBACK_UNITY_VERSION = version
        # The reader warns on every file that the bundle header carries no
        # usable version. That is expected here and would drown the report.
        warnings.filterwarnings(
            "ignore", category=UnityPy.exceptions.UnityVersionFallbackWarning)

    print(f"  client   : {client}")
    print(f"  engine   : {version}")
    texts = Texts(catalogue)
    print(f"  catalogue: {len(texts.offsets):,} texts")
    if UnityPy is None:
        print("  reading  : raw bytes — install UnityPy for exact records")
    else:
        print("  reading  : type descriptions")

    bundles = list_bundles(data_dir)
    print(f"  bundles  : {len(bundles)}\n")

    started = time.time()
    manifest: dict = {"engine": version, "categories": {}}
    total = 0

    for category, path in bundles:
        try:
            if UnityPy is None:
                records = read_by_scan(path, texts)
            else:
                records = read_records(path)
        except (BundleError, ValueError, KeyError, struct.error) as exc:
            print(f"  {category:<22} unreadable: {exc}")
            continue

        labels, records = resolve(records, texts)
        if not labels:
            continue

        ok, detail = validate(labels, WITNESSES.get(category, {}))
        size = write_json(os.path.join(LABELS, category + ".json"),
                          {str(k): v for k, v in sorted(labels.items())})
        icons = icons_of(records)
        if icons:
            write_json(os.path.join(ICONS, category + ".json"),
                       {str(k): v for k, v in sorted(icons.items())})
        heavy = 0
        if not args.labels_only:
            heavy = write_json(os.path.join(RECORDS, category + ".json"), records)

        mark = "SUSPECT" if not ok else ("ok" if category in WITNESSES else "?")
        print(f"  {category:<22} {len(labels):>6,} labels  {size / 1024:>7.0f} KB  "
              f"{len(records):>7,} records  {heavy / 1048576:>6.1f} MB  {mark:<8}{detail}")
        manifest["categories"][category] = {
            "labels": len(labels), "records": len(records), "icons": len(icons),
            "validation": detail, "trusted": bool(ok and category in WITNESSES)}
        total += len(labels)

    if not args.labels_only:
        taille = write_item_digest(RECORDS, LABELS,
                                   os.path.join(DATA, "objets.json"))
        if taille:
            print(f"\n  item digest in data/objets.json — "
                  f"{taille / 1024:.0f} KB")
        taille = write_monster_digest(RECORDS,
                                      os.path.join(DATA, "monstres.json"))
        if taille:
            print(f"  monster digest in data/monstres.json — "
                  f"{taille / 1024:.0f} KB")

    with open(os.path.join(LABELS, "manifest.json"), "w", encoding="utf-8") as fh:
        json.dump(manifest, fh, ensure_ascii=False, indent=1, sort_keys=True)

    print(f"\n  {total:,} labels in data/labels/", end="")
    if not args.labels_only:
        print(f", full records in data/records/", end="")
    print(f" — {time.time() - started:.0f}s")
    trusted = [c for c, m in manifest["categories"].items() if m["trusted"]]
    print(f"  {len(trusted)} categor{'y' if len(trusted) == 1 else 'ies'} "
          f"checked against known labels: {', '.join(trusted)}")
    suspect = [c for c, m in manifest["categories"].items()
               if c in WITNESSES and not m["trusted"]]
    if suspect:
        print(f"  read wrong: {', '.join(suspect)}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
