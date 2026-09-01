"""Reader for the client's Unity asset bundles, with no dependency.

Game data — items, spells, achievements — lives in `.bundle` files using the
UnityFS container. This module opens them to recover the labels the protocol
never sends: only identifiers travel over the wire.

A bundle holds two layers:

  - the UnityFS header, big-endian, describing the compressed blocks and the
    files they contain;
  - the blocks themselves, in LZ4 *block* format — not the *frame* format,
    which would carry a header of its own.

The LZ4 decompressor is written here rather than imported: the algorithm fits
in a few dozen lines, and the library is meant to have no dependency.

Two details cost some digging and are easy to get wrong:

  - flag 0x200 requires realigning **after** the descriptor block. Without it
    the data is read fourteen bytes early and its compression header looks
    invalid;
  - Unity writes the five LZMA property bytes but omits the uncompressed size
    that normally follows. Declaring that size makes decoding fail; it has to
    be marked unknown so the stream ends on its own.
"""
from __future__ import annotations

import struct
from dataclasses import dataclass

SIGNATURE = b"UnityFS\x00"

# Compression mode, held in the low six bits of the flags.
COMPRESSION_NONE = 0
COMPRESSION_LZMA = 1
COMPRESSION_LZ4 = 2
COMPRESSION_LZ4HC = 3


class BundleError(Exception):
    pass


def decompress_lz4(source: bytes, expected_size: int) -> bytes:
    """LZ4 block format: a run of literal-plus-copy sequences.

    Each sequence opens with a token byte: the high nibble gives the literal
    length, the low nibble the copy length. A value of 15 means "the rest is
    spread over the following bytes".
    """
    out = bytearray()
    i = 0
    n = len(source)

    while i < n:
        token = source[i]
        i += 1

        length = token >> 4
        if length == 15:
            while i < n:
                byte = source[i]
                i += 1
                length += byte
                if byte != 255:
                    break
        out += source[i:i + length]
        i += length

        # The last sequence may stop right after its literal.
        if i >= n - 1:
            break

        distance = source[i] | (source[i + 1] << 8)
        i += 2
        if distance == 0:
            raise BundleError("zero copy distance")

        copy = token & 0x0F
        if copy == 15:
            while i < n:
                byte = source[i]
                i += 1
                copy += byte
                if byte != 255:
                    break
        copy += 4

        # Ranges may overlap, so the copy goes one byte at a time.
        start = len(out) - distance
        if start < 0:
            raise BundleError("copy reaches before the produced data")
        for k in range(copy):
            out.append(out[start + k])

    if expected_size and len(out) != expected_size:
        raise BundleError(f"got {len(out)} bytes, expected {expected_size}")
    return bytes(out)


def _decompress(data: bytes, size: int, flags: int) -> bytes:
    mode = flags & 0x3F
    if mode == COMPRESSION_NONE:
        return data
    if mode in (COMPRESSION_LZ4, COMPRESSION_LZ4HC):
        return decompress_lz4(data, size)
    if mode == COMPRESSION_LZMA:
        import lzma
        # Size marked unknown on purpose: see the module docstring.
        stream = data[:5] + b"\xff" * 8 + data[5:]
        plain = lzma.LZMADecompressor(format=lzma.FORMAT_ALONE).decompress(stream)
        if size and len(plain) != size:
            raise BundleError(f"LZMA: got {len(plain)} bytes, expected {size}")
        return plain
    raise BundleError(f"unknown compression mode: {mode}")


@dataclass
class BundleFile:
    """One file held inside a bundle."""
    path: str
    data: bytes


class Bundle:
    """Opens an asset bundle and exposes the files it contains."""

    def __init__(self, path: str):
        self.path = path
        with open(path, "rb") as fh:
            self.raw = fh.read()
        if not self.raw.startswith(SIGNATURE):
            raise BundleError(f"{path} is not a UnityFS bundle")
        self.files: list[BundleFile] = []
        self._read()

    def _string(self, pos: int) -> tuple[str, int]:
        end = self.raw.index(b"\x00", pos)
        return self.raw[pos:end].decode("utf-8", "replace"), end + 1

    def _read(self) -> None:
        raw = self.raw
        pos = len(SIGNATURE)
        version = struct.unpack_from(">I", raw, pos)[0]
        pos += 4
        _unity, pos = self._string(pos)
        _revision, pos = self._string(pos)
        _total = struct.unpack_from(">q", raw, pos)[0]
        pos += 8
        packed_size, plain_size, flags = struct.unpack_from(">III", raw, pos)
        pos += 12

        if version >= 7:
            pos = (pos + 15) & ~15

        # The descriptor block may sit at the end of the file instead.
        if flags & 0x80:
            start = len(raw) - packed_size
            info = _decompress(raw[start:start + packed_size], plain_size, flags)
        else:
            info = _decompress(raw[pos:pos + packed_size], plain_size, flags)
            pos += packed_size
        if flags & 0x200:
            pos = (pos + 15) & ~15

        # Block table, then file table.
        cursor = 16                          # checksum, of no use here
        block_count = struct.unpack_from(">i", info, cursor)[0]
        cursor += 4
        blocks = []
        for _ in range(block_count):
            plain, packed, block_flags = struct.unpack_from(">IIH", info, cursor)
            cursor += 10
            blocks.append((plain, packed, block_flags))

        node_count = struct.unpack_from(">i", info, cursor)[0]
        cursor += 4
        nodes = []
        for _ in range(node_count):
            offset, size, _node_flags = struct.unpack_from(">qqI", info, cursor)
            cursor += 20
            end = info.index(b"\x00", cursor)
            name = info[cursor:end].decode("utf-8", "replace")
            cursor = end + 1
            nodes.append((offset, size, name))

        # Blocks are decompressed back to back, then sliced per file.
        content = bytearray()
        for plain, packed, block_flags in blocks:
            content += _decompress(raw[pos:pos + packed], plain, block_flags)
            pos += packed

        for offset, size, name in nodes:
            self.files.append(BundleFile(name, bytes(content[offset:offset + size])))

    def __repr__(self) -> str:
        total = sum(len(f.data) for f in self.files)
        return f"<Bundle {len(self.files)} file(s), {total:,} bytes uncompressed>"
