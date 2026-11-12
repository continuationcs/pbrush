"""Extract the game's own localized text (Game.locres) from ProjectPBZ-Windows.pak.

Reads the local game install only. Used to study the game's wording so the mod's text reads like
first-party UI; nothing extracted is shipped with the mod.

usage: python tools/pak_locres.py <out_dir> [cultures...]
writes <out_dir>/<culture>.tsv with "namespace<TAB>key<TAB>text" lines.
"""
from __future__ import annotations

import struct
import sys
from pathlib import Path

sys.path.insert(0, r"F:\C\pbzero\src")
from cryptography.hazmat.primitives.ciphers import Cipher, algorithms, modes  # noqa: E402
from pbzero.container import Oodle  # noqa: E402

GAME = Path(r"G:\G\Steam\steamapps\common\PBZ")
PAK = GAME / "ProjectPBZ" / "Content" / "Paks" / "ProjectPBZ-Windows.pak"
KEY = bytes.fromhex("4BC8A51E5381325073F2BC7D4E3089CD557C4E9B7D453901C2C795518867E01D")
MAGIC = 0x5A6F12E1


def ecb(data: bytes) -> bytes:
    d = Cipher(algorithms.AES(KEY), modes.ECB()).decryptor()
    return d.update(data) + d.finalize()


class R:
    def __init__(self, b: bytes, p: int = 0):
        self.b, self.p = b, p

    def take(self, n):
        v = self.b[self.p:self.p + n]
        self.p += n
        return v

    def u8(self): return self.take(1)[0]
    def u32(self): return struct.unpack("<I", self.take(4))[0]
    def i32(self): return struct.unpack("<i", self.take(4))[0]
    def u64(self): return struct.unpack("<Q", self.take(8))[0]
    def i64(self): return struct.unpack("<q", self.take(8))[0]

    def fstr(self):
        n = self.i32()
        if n == 0:
            return ""
        if n < 0:
            return self.take(-n * 2).decode("utf-16-le").rstrip("\0")
        return self.take(n).decode("utf-8", "replace").rstrip("\0")


class Pak:
    def __init__(self, path: Path):
        self.f = path.open("rb")
        size = path.stat().st_size
        self.f.seek(size - 512)
        tail = self.f.read(512)
        at = tail.rfind(struct.pack("<I", MAGIC))
        if at < 17:
            raise ValueError("pak footer not found")
        r = R(tail, at - 17)
        r.take(16)
        encrypted_index = r.u8()
        r.u32()
        self.version = r.i32()
        index_offset, index_size = r.i64(), r.i64()
        r.take(20)
        rest = tail[r.p:]
        self.methods = [""] + [rest[i * 32:(i + 1) * 32].split(b"\0")[0].decode() for i in range(len(rest) // 32)]
        self.encrypted_index = encrypted_index
        idx = self.read_raw(index_offset, index_size)
        r = R(idx)
        r.fstr()
        r.i32()
        r.u64()
        if r.u32():
            r.i64(); r.i64(); r.take(20)
        if not r.u32():
            raise ValueError("no full directory index")
        fdi_off, fdi_size = r.i64(), r.i64()
        r.take(20)
        enc_size = r.i32()
        self.encoded = r.take(enc_size)
        fdi = R(self.read_raw(fdi_off, fdi_size))
        self.files: dict[str, int] = {}
        for _ in range(fdi.u32()):
            d = fdi.fstr()
            for _ in range(fdi.u32()):
                name = fdi.fstr()
                self.files[(d + name).lstrip("/")] = fdi.i32()

    def read_raw(self, off, size):
        self.f.seek(off)
        data = self.f.read((size + 15) // 16 * 16 if self.encrypted_index else size)
        return ecb(data)[:size] if self.encrypted_index else data

    def read(self, name: str, codec: Oodle) -> bytes:
        r = R(self.encoded, self.files[name])
        flags = r.u32()
        block_size = (flags & 0x3F) << 11
        if flags & 0x3F == 0x3F:
            block_size = r.u32()
        blocks = (flags >> 6) & 0xFFFF
        encrypted = bool(flags & (1 << 22))
        method = (flags >> 23) & 0x3F
        offset = r.u32() if flags & (1 << 31) else r.u64()
        usize = r.u32() if flags & (1 << 30) else r.u64()
        size = (r.u32() if flags & (1 << 29) else r.u64()) if method else usize
        sizes = []
        if blocks > 0 and (encrypted or blocks != 1):
            sizes = [r.u32() for _ in range(blocks)]
        elif blocks == 1:
            sizes = [size]
        header = 8 + 8 + 8 + 4 + 20 + 1 + 4 + ((4 + 16 * blocks) if method else 0)
        pos = offset + header
        if not method:
            self.f.seek(pos)
            data = self.f.read((size + 15) // 16 * 16 if encrypted else size)
            return (ecb(data) if encrypted else data)[:usize]
        out = bytearray()
        for i, bs in enumerate(sizes):
            self.f.seek(pos)
            raw = self.f.read((bs + 15) // 16 * 16 if encrypted else bs)
            pos += (bs + 15) // 16 * 16 if encrypted else bs
            if encrypted:
                raw = ecb(raw)[:bs]
            want = min(block_size, usize - i * block_size)
            name_m = self.methods[method].lower()
            if name_m.startswith("oodle"):
                out += codec.decompress(raw, want)
            elif name_m.startswith("zlib"):
                import zlib
                out += zlib.decompress(raw)
            else:
                raise ValueError("unsupported compression " + self.methods[method])
        return bytes(out[:usize])


def parse_locres(b: bytes):
    r = R(b)
    r.take(16)
    ver = r.u8()
    str_off = r.i64()
    if ver >= 2:
        r.u32()
    s = R(b, str_off)
    strings = []
    for _ in range(s.u32()):
        strings.append(s.fstr())
        if ver >= 2:
            s.i32()
    out = []
    for _ in range(r.u32()):
        if ver >= 2:
            r.u32()
        ns = r.fstr()
        for _ in range(r.u32()):
            if ver >= 2:
                r.u32()
            key = r.fstr()
            r.u32()
            idx = r.i32()
            out.append((ns, key, strings[idx] if 0 <= idx < len(strings) else ""))
    return out


def main():
    out = Path(sys.argv[1])
    out.mkdir(parents=True, exist_ok=True)
    pak = Pak(PAK)
    locs = sorted(n for n in pak.files if n.endswith("Game.locres"))
    print("version", pak.version, "methods", pak.methods)
    print("\n".join(locs))
    want = sys.argv[2:]
    codec = Oodle(Path(r"F:\C\pbzero\src\native"))
    for n in locs:
        culture = n.split("/")[-2]
        if want and culture not in want:
            continue
        rows = parse_locres(pak.read(n, codec))
        with (out / f"{culture}.tsv").open("w", encoding="utf-8") as f:
            for ns, key, text in rows:
                f.write(f"{ns}\t{key}\t{text.replace(chr(10), ' / ').replace(chr(13), '')}\n")
        print(culture, len(rows))


if __name__ == "__main__":
    main()
