"""Search the game's assets offline (IoStore over ProjectPBZ-Windows.utoc, via the pbzero package).

  python src/tools/asset_scan.py list  <path part> [<name regex>]   asset paths containing <path part>
  python src/tools/asset_scan.py grep  <path part> <text> [<text> ...] assets whose bytes contain any text
  python src/tools/asset_scan.py names <path part> <regex>          readable names inside each asset
  python src/tools/asset_scan.py deps  <path part>                  what a boss's assets look up or spawn

`deps` is the level-dependency check behind 补点 (DESIGN 5.2): a class named next to GetActorOfClass /
GetAllActorsOfClass is looked up in the level; GetTargets / FindNearestActor look up actors that registered with
the targeting subsystem (RegisterTarget, e.g. BP_YuBi_SnapPoint: the first scan missed these); a class named
next to BeginDeferredActorSpawnFromClass / SpawnActor is created by the skill itself (not a level dependency:
魔渊's pillars, 舞狮尊主's poles). AISpawner / GetSpawnTransform read the boss's original spawner. Names come from
the assets' name maps, so this tells which classes and calls an asset uses, not how they are wired: confirm in game.
Paths look like "/Mobs/YuBi/" or "UI/GameSystem/Settings/". Some packages fail to decode (Oodle panics are
printed by the decoder and skipped).
"""
import re
import sys
from pathlib import Path

sys.path.insert(0, r"F:\C\pbzero\src")
from pbzero import portraits  # noqa: E402
from pbzero.container import Oodle  # noqa: E402

GAME = Path(r"G:\G\Steam\steamapps\common\PBZ")
portraits.MAX_TEXTURE = 1 << 30           # the reader caps sizes for textures; assets here can be larger

LOOKUP = ["GetActorOfClass", "GetAllActorsOfClass", "GetAllActorsWithTag", "FindNearestActor", "GetTargets",
          "RegisterTarget", "AISpawner", "GetSpawnTransform"]
SPAWN = ["BeginDeferredActorSpawnFromClass", "SpawnActor"]
CLASS = re.compile(r"/(BP_[A-Za-z0-9_]+?)(?=[A-Z][a-z]+Property|CallFunc|K2Node|Default__|$|/|\s)")


def assets(store, part):
    part = part.lower()
    return sorted(n for n in store.files if part in n.lower() and n.endswith(".uasset"))


def read(store, n):
    try:
        return store.read(n)
    except Exception:
        return None


def text_of(data):
    return " ".join(s.decode() for s in re.findall(rb"[ -~]{4,}", data))


def short(n):
    return n.split("/Content/")[-1]


def main():
    if len(sys.argv) < 3:
        sys.exit(__doc__)
    cmd, part, rest = sys.argv[1], sys.argv[2], sys.argv[3:]
    store = portraits.IoStore(GAME / portraits.UTOC, Oodle(Path(r"F:\C\pbzero\src\native")))
    if cmd == "list":
        pat = re.compile(rest[0]) if rest else None
        for n in assets(store, part):
            if not pat or pat.search(n.rsplit("/", 1)[-1]):
                print(short(n))
    elif cmd == "grep":
        needles = [t.encode() for t in rest]
        for n in assets(store, part):
            d = read(store, n)
            hit = [t.decode() for t in needles if d and t in d]
            if hit:
                print(short(n), "|", ", ".join(hit))
    elif cmd == "names":
        pat = re.compile(rest[0])
        for n in assets(store, part):
            d = read(store, n)
            if not d:
                continue
            toks = set()
            for s in re.findall(rb"[ -~]{4,}", d):
                toks.update(re.split(r"(?=/[A-Z])", s.decode()))   # name maps run names together
            hits = sorted(t for t in toks if pat.search(t))
            if hits:
                print("==", short(n))
                for h in hits:
                    print("   ", h[:200])
    elif cmd == "deps":
        for n in assets(store, part):
            d = read(store, n)
            if not d:
                continue
            text = text_of(d)
            look = [v for v in LOOKUP if v in text]
            spawn = [v for v in SPAWN if v in text]
            if not (look or spawn):
                continue
            own = n.rsplit("/", 1)[-1][:-7]
            classes = sorted(set(c for c in CLASS.findall(text) if c != own))
            print(short(n))
            print("    looks up:", ", ".join(look) or "-", "| spawns:", ", ".join(spawn) or "-")
            print("    classes:", ", ".join(classes)[:400] or "-")
    else:
        sys.exit(__doc__)


main()
