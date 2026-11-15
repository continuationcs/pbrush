"""Keep the game classes the mod relies on as text, per game build, to see what a game update changed (doc/UPDATE.md).

  python src/tools/header_baseline.py           write src/data/game_baseline/<buildid>.txt from UE4SS's header dump
  python src/tools/header_baseline.py diff      compare the two newest baselines (or: diff <old build> <new build>)

The classes are the ones the start-up check names (health.lua: NATIVE, BLUEPRINTS), so a class added to the check is
kept here too. Each is copied from CXXHeaderDump with its parent chain (members can move to a parent), offsets
left out (they shift with any change and say nothing about names).

The dump must be of the installed build: after a game update, regenerate it in game (Ctrl+H, UE4SS's
CXXHeaderGenerator) first; the tool refuses a dump older than the game's last update. Blueprint classes appear in
the dump only if they were loaded when it was made: open a bell menu and finish a fight (result screen,
wb_settlement) before Ctrl+H, or they are listed as not in the dump.
"""
import difflib
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
HEALTH = ROOT / 'src' / 'mod' / 'BossRush' / 'Scripts' / 'health.lua'
OUT = ROOT / 'src' / 'data' / 'game_baseline'
GAME = Path(r'G:\G\Steam\steamapps\common\PBZ')
DUMP = GAME / 'platform' / 'steam' / 'ue4ss' / 'CXXHeaderDump'
MANIFEST = GAME.parents[1] / 'appmanifest_4115450.acf'


def manifest():
    text = MANIFEST.read_text(encoding='utf-8')
    return (re.search(r'"buildid"\s+"(\d+)"', text).group(1),
            int(re.search(r'"LastUpdated"\s+"(\d+)"', text).group(1)))


def wanted_classes():
    """Short class names the start-up check looks up: "/Script/Module.Class" and "/Pkg/X.X_C"."""
    text = HEALTH.read_text(encoding='utf-8')
    names = re.findall(r'"/Script/\w+\.(?:Default__)?(\w+)"', text)      # a class default object: its class
    names += re.findall(r'"/Game/[^"]*\.(\w+_C)"', text[text.index('local BLUEPRINTS'):text.index('local CORE_ASSETS')])
    return list(dict.fromkeys(names))


def read_dump():
    """class name in the dump (with U/A/I/F prefix) -> (parent, lines without offsets)."""
    classes = {}
    for p in sorted(DUMP.glob('*.hpp')):
        cur = None
        for line in p.read_text(encoding='utf-8', errors='ignore').splitlines():
            m = re.match(r'(?:class|struct) (\w+)(?: : public (\w+))?', line)
            if m:
                cur = m.group(1)
                classes[cur] = (m.group(2), [f'{line.strip()}   // {p.name}'])
            elif cur and line.startswith('}'):
                cur = None
            elif cur and line.strip() and line.strip() != '{':
                classes[cur][1].append('    ' + re.sub(r'\s*//.*$', '', line.strip()))
    return classes


def find(classes, short):
    for prefix in ('U', 'A', 'I', 'F', ''):
        if prefix + short in classes:
            return prefix + short
    return None


def write():
    build, updated = manifest()
    stamp = (DUMP / 'ProjectPBZ.hpp').stat().st_mtime
    if stamp < updated:
        sys.exit(f'the header dump is older than the game\'s last update: regenerate it in game (Ctrl+H) first')
    classes = read_dump()
    out, missing, done = [f'// game build {build}: classes the start-up check uses (health.lua), from CXXHeaderDump'], [], set()
    for short in wanted_classes():
        name = find(classes, short)
        if not name:
            missing.append(short)
            continue
        while name and name in classes and name not in done:
            done.add(name)
            parent, lines = classes[name]
            out += [''] + lines
            name = parent
    if missing:
        out += ['', '// not in the dump (a Blueprint not loaded when it was made, or gone): ' + ', '.join(missing)]
    OUT.mkdir(parents=True, exist_ok=True)
    path = OUT / f'{build}.txt'
    path.write_text('\n'.join(out) + '\n', encoding='utf-8', newline='\n')
    print(f'{path}: {len(done)} classes' + (f', not in the dump: {", ".join(missing)}' if missing else ''))


def diff(old=None, new=None):
    files = sorted(OUT.glob('*.txt'), key=lambda p: int(p.stem))
    if old and new:
        a, b = OUT / f'{old}.txt', OUT / f'{new}.txt'
    elif len(files) >= 2:
        a, b = files[-2], files[-1]
    else:
        sys.exit('need two baselines in ' + str(OUT))
    lines = list(difflib.unified_diff(a.read_text(encoding='utf-8').splitlines(),
                                      b.read_text(encoding='utf-8').splitlines(), a.name, b.name, lineterm=''))
    print('\n'.join(lines) if lines else f'{a.name} and {b.name}: no change')


if __name__ == '__main__':
    if len(sys.argv) > 1 and sys.argv[1] == 'diff':
        diff(*sys.argv[2:4])
    else:
        write()
