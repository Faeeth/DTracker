"""Extract the client's artwork into plain PNG files.

Companion to extract_data.py: that one recovers the labels, this one the
pictures they go with. Run it again after a game update — unchanged bundles
are skipped, so a second run costs almost nothing.

    python extract_images.py
    python extract_images.py --only item,spell --scale 2x
    python extract_images.py --folder Characters
    python extract_images.py --folder aa/StandaloneWindows64     habillage et polices
    python extract_images.py --list

Everything lands in data/images/<category>/<variant>/, under the name the
client gives each sprite. That name is the *icon* identifier, not the entity
one: item 303 is "Bois de Frene" but its picture is item/2x/38017.png, 38017
being the `iconId` of its record in data/records/items.json. Several items
share one icon, which is why there are fewer pictures than items.

Names are not always bare numbers either — spells come out as `sort_11830`,
classes as `Head_1`. Each folder therefore gets an `index.json` mapping the
number to the file, so a caller can look an `iconId` up without knowing the
naming habit of that particular category.

Sprites here are one texture apiece rather than cut out of an atlas, so each
one comes out as its own image with nothing to reassemble.

Three peculiarities of this client:

  - the bundle headers carry "5.x.x" instead of a real engine version, so the
    reader has to be told which one to assume — it is read from
    `globalgamemanagers` rather than written here, so an update moves it along;
  - a category exists in up to three flavours: `_1x` and `_2x` for the two
    resolutions, and `_all` or a bare `_` for artwork that has only one;
  - sprite names are not unique inside a bundle. The world map holds a hundred
    and sixty pictures called `1` — its tiles. Writing them under their bare
    name would keep one of each, so repeats take the internal object number as
    a suffix, which is stable from one run to the next.

Fonts travel with the artwork and land in data/fonts/ as ordinary `.ttf`
files. They are not in `Content` but among the Addressables bundles, hence
`--folder aa/StandaloneWindows64`, which is looked up relative to
`StreamingAssets` when it does not exist under `Content`.

This tool needs UnityPy, unlike the dofus_stats library itself, which keeps to
the standard library. Decoding the compressed GPU texture formats by hand would
be a project of its own for no gain, and nothing here runs while capturing.
"""
from __future__ import annotations

import argparse
import io
import json
import os
import re
import sys
import time
import warnings

if hasattr(sys.stdout, "buffer"):
    sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding="utf-8",
                                  errors="replace", line_buffering=True)

ROOT = os.path.dirname(os.path.abspath(__file__))
OUTPUT = os.path.join(ROOT, "data", "images")


def set_output(folder: str) -> None:
    """Write somewhere else than next to this script. See extract_data."""
    global OUTPUT
    OUTPUT = folder
FONTS = os.path.join(ROOT, "data", "fonts")

CLIENT_PATHS = [
    os.path.expandvars(r"%LOCALAPPDATA%\Ankama\Dofus-dofus3\Dofus_Data"),
    r"C:\Program Files\Ankama\Dofus\Dofus_Data",
    r"C:\Program Files (x86)\Ankama\Dofus\Dofus_Data",
]

DEFAULT_FOLDER = "Picto"
BUNDLE = re.compile(r"^(?P<category>.+?)_assets_(?P<variant>.*)\.bundle$", re.I)

# Fallback if the engine version cannot be read from the client.
ASSUMED_UNITY = "6000.3.16f1"


def find_client(given: str | None) -> str | None:
    if given:
        return given if os.path.isdir(given) else None
    for path in CLIENT_PATHS:
        if os.path.isdir(path):
            return path
    return None


def unity_version(client: str) -> str:
    """Engine version, taken from the client itself.

    The asset bundles claim "5.x.x", which no reader can act on. The real
    number sits in plain text at the head of `globalgamemanagers`.
    """
    marker = os.path.join(client, "globalgamemanagers")
    if os.path.exists(marker):
        with open(marker, "rb") as fh:
            found = re.search(rb"\d+\.\d+\.\d+[abfp]\d+", fh.read(4096))
        if found:
            return found.group().decode("ascii")
    return ASSUMED_UNITY


def list_bundles(base: str) -> list[tuple[str, str, str]]:
    """Every bundle under a content folder, as (category, variant, path)."""
    found = []
    for directory, _subdirs, names in os.walk(base):
        for name in names:
            match = BUNDLE.match(name)
            if not match:
                continue
            variant = match.group("variant").lower() or "base"
            found.append((match.group("category").lower(), variant,
                          os.path.join(directory, name)))
    found.sort(key=lambda b: (b[0], b[1]))
    return found


def stamp(path: str) -> str:
    """Cheap fingerprint of a bundle: enough to notice an update.

    Hashing hundreds of megabytes on every run would cost more than the
    extraction itself, and the client rewrites these files wholesale.
    """
    info = os.stat(path)
    return f"{info.st_size}-{int(info.st_mtime)}"


def safe_name(raw) -> str:
    """A sprite name turned into a file name.

    Names are usually bare identifiers, but a few carry characters Windows
    will not accept in a path.
    """
    cleaned = re.sub(r'[<>:"/\\|?*\x00-\x1f]', "_", str(raw)).strip(" .")
    return cleaned or "unnamed"


NUMBER = re.compile(r"^\D*?(\d+)$")


def index_key(stem: str) -> str | None:
    """The number a caller would look this picture up by, if there is one.

    `38017` and `sort_11830` both hold one; `wings-demonAngel2_frame3` holds
    two and is left out rather than indexed under the wrong one.
    """
    match = NUMBER.match(stem)
    return match.group(1) if match else None


def extract_fonts(env) -> int:
    """Write the bundle's fonts as ordinary `.ttf` files.

    Unity stores them whole, header included: what comes out is the very file
    the designers handed over, usable by any program.
    """
    written = 0
    for obj in env.objects:
        if obj.type.name != "Font":
            continue
        data = obj.read()
        blob = getattr(data, "m_FontData", b"") or b""
        if not blob:
            continue
        os.makedirs(FONTS, exist_ok=True)
        with open(os.path.join(FONTS, safe_name(data.m_Name) + ".ttf"), "wb") as fh:
            fh.write(bytes(blob))
        written += 1
    return written


def extract_bundle(path: str, destination: str) -> tuple[int, int]:
    """Write every sprite and font of one bundle. Returns (written, failed)."""
    import UnityPy

    written = failed = 0
    taken: set[str] = set()
    index: dict[str, str] = {}
    env = UnityPy.load(path)
    polices = extract_fonts(env)
    for obj in env.objects:
        if obj.type.name != "Sprite":
            continue
        try:
            data = obj.read()
            image = data.image
        except Exception as exc:                       # noqa: BLE001
            # Une texture illisible se compte ; savoir *pourquoi* demande de
            # le demander. Utile surtout dans l'executable gele, ou une
            # dependance manquante fait echouer toutes les images d'un coup
            # sans que rien ne le dise.
            if os.environ.get("DTRACKER_DEBUG"):
                print(f"    {type(exc).__name__}: {exc}", flush=True)
            # A few textures use formats the decoder does not know. One
            # unreadable sprite must not cost the other thousands.
            failed += 1
            continue
        stem = safe_name(data.m_Name)
        if stem in taken:
            # The object number is stable from one run to the next, so a
            # picture keeps the same file name across updates.
            stem = f"{stem}#{obj.path_id}"
        taken.add(stem)
        os.makedirs(destination, exist_ok=True)
        image.save(os.path.join(destination, stem + ".png"))
        key = index_key(stem)
        if key:
            index.setdefault(key, stem + ".png")
        written += 1

    if written:
        with open(os.path.join(destination, "index.json"), "w",
                  encoding="utf-8") as fh:
            json.dump(index, fh, ensure_ascii=False, separators=(",", ":"),
                      sort_keys=True)
    return written + polices, failed


def folder_size(path: str) -> int:
    total = 0
    for directory, _subdirs, names in os.walk(path):
        for name in names:
            total += os.path.getsize(os.path.join(directory, name))
    return total


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(
        description="Extract the Dofus client's artwork as PNG files.")
    parser.add_argument("--client", help="the game's Dofus_Data folder")
    parser.add_argument("--out", help="write there instead of ./data/images")
    parser.add_argument("--folder", default=DEFAULT_FOLDER,
                        help="content folder to walk (default: Picto)")
    parser.add_argument("--only", help="comma-separated categories, e.g. item,spell")
    parser.add_argument("--scale", default="all", choices=["1x", "2x", "all"],
                        help="which resolution to keep (default: both)")
    parser.add_argument("--force", action="store_true",
                        help="redo bundles already extracted")
    parser.add_argument("--list", action="store_true",
                        help="show what would be extracted and stop")
    args = parser.parse_args(argv)
    if args.out:
        set_output(args.out)

    client = find_client(args.client)
    if not client:
        print("Client not found. Point at it with --client.", file=sys.stderr)
        return 1
    # Les bundles d'habillage vivent a cote de `Content`, pas dedans.
    base = os.path.join(client, "StreamingAssets", "Content", args.folder)
    if not os.path.isdir(base):
        base = os.path.join(client, "StreamingAssets", args.folder)
    if not os.path.isdir(base):
        print(f"No such content folder: {args.folder}", file=sys.stderr)
        return 1

    bundles = list_bundles(base)
    if args.only:
        wanted = {c.strip().lower() for c in args.only.split(",")}
        bundles = [b for b in bundles if b[0] in wanted]
    if args.scale != "all":
        # A category with a single flavour has no resolution to choose from,
        # so it is kept whichever scale was asked for.
        bundles = [b for b in bundles if b[1] in (args.scale, "all", "base")]

    if not bundles:
        print("Nothing matches.", file=sys.stderr)
        return 1

    if args.list:
        print(f"  {len(bundles)} bundles under {args.folder}\n")
        for category, variant, path in bundles:
            print(f"  {category:<24} {variant:<5} "
                  f"{os.path.getsize(path) / 1048576:>8.1f} MB")
        return 0

    try:
        import UnityPy
    except ImportError:
        print("UnityPy is missing — install it with:  pip install UnityPy\n"
              "It is needed only here; the dofus_stats library itself has no "
              "dependency.", file=sys.stderr)
        return 1

    version = unity_version(client)
    UnityPy.config.FALLBACK_UNITY_VERSION = version
    # The reader warns on every file that the bundle header carries no usable
    # version. That is expected here and would drown the report.
    warnings.filterwarnings(
        "ignore", category=UnityPy.exceptions.UnityVersionFallbackWarning)

    print(f"  client : {client}")
    print(f"  engine : {version}")
    print(f"  folder : {args.folder} — {len(bundles)} bundles\n")

    os.makedirs(OUTPUT, exist_ok=True)
    manifest_path = os.path.join(OUTPUT, "manifest.json")
    manifest: dict = {"bundles": {}}
    if os.path.exists(manifest_path) and not args.force:
        try:
            with open(manifest_path, encoding="utf-8") as fh:
                manifest = json.load(fh)
        except (OSError, json.JSONDecodeError):
            pass
    manifest.setdefault("bundles", {})

    started = time.time()
    total = skipped = 0

    for category, variant, path in bundles:
        key = f"{category}/{variant}"
        destination = os.path.join(OUTPUT, category, variant)
        current = stamp(path)
        previous = manifest["bundles"].get(key)
        if (previous and previous.get("stamp") == current
                and os.path.isdir(destination) and not args.force):
            skipped += 1
            total += previous.get("images", 0)
            continue

        size = os.path.getsize(path) / 1048576
        print(f"  {key:<28} {size:>7.1f} MB  ", end="", flush=True)
        clock = time.time()
        try:
            written, failed = extract_bundle(path, destination)
        except Exception as exc:                       # noqa: BLE001
            print(f"unreadable: {exc}")
            continue

        note = f"  ({failed} undecodable)" if failed else ""
        print(f"{written:>6,} images  {time.time() - clock:>5.0f}s{note}")
        manifest["bundles"][key] = {
            "stamp": current, "images": written, "undecodable": failed,
            "source": os.path.relpath(path, client).replace("\\", "/")}
        total += written

    manifest["engine"] = version
    with open(manifest_path, "w", encoding="utf-8") as fh:
        json.dump(manifest, fh, ensure_ascii=False, indent=1, sort_keys=True)

    print(f"\n  {total:,} images in data/images/ "
          f"({folder_size(OUTPUT) / 1048576:.0f} MB), "
          f"{time.time() - started:.0f}s")
    if skipped:
        print(f"  {skipped} bundle(s) unchanged since the last run, left alone")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
