"""Build the Nexus release zip of the Boss Challenge mod.

Copies mod/BossRush into dist/, switches the copy to a release configuration (debug log off), adds the
README and enabled.txt, and zips it so the archive extracts straight into the game's UE4SS Mods folder:

    <game>/platform/steam/ue4ss/Mods/BossRush/...

The repo's own mod/BossRush is never modified. Usage: python tools/build_release.py <version>
"""
import re
import shutil
import sys
import zipfile
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SRC = ROOT / 'mod' / 'BossRush'
DIST = ROOT / 'dist'


def main():
    version = sys.argv[1] if len(sys.argv) > 1 else '0.1.0'
    stage = DIST / f'BossRush-{version}'
    if stage.exists():
        shutil.rmtree(stage)
    mod = stage / 'BossRush'
    shutil.copytree(SRC, mod, ignore=shutil.ignore_patterns('records.tsv', 'enabled.txt', '*.bak'))

    # Release configuration: no debug log.
    cfg = mod / 'Scripts' / 'config.lua'
    text = cfg.read_text(encoding='utf-8')
    text, n = re.subn(r'(\n\s*debug\s*=\s*)true,', r'\1false,', text)
    if n != 1:
        sys.exit('config.lua: could not switch debug off')
    cfg.write_text(text, encoding='utf-8', newline='\n')

    # Version stamp in main.lua's first line.
    main_lua = mod / 'Scripts' / 'main.lua'
    m = main_lua.read_text(encoding='utf-8')
    main_lua.write_text(f'-- Boss Challenge {version}\n' + m, encoding='utf-8', newline='\n')

    (mod / 'enabled.txt').write_text('', encoding='ascii')
    for name in ('README.txt', 'README_zh.txt'):
        src = ROOT / 'release' / name
        if src.exists():
            shutil.copy(src, mod / name)

    # Sanity: no probe leftovers or debug key bindings in the shipped scripts.
    for f in (mod / 'Scripts').glob('*.lua'):
        body = f.read_text(encoding='utf-8')
        for bad in ('RegisterKeyBind', 'BRProbe', 'GenerateSDK'):
            if bad in body:
                sys.exit(f'{f.name}: contains {bad}')

    zpath = DIST / f'BossRush-{version}.zip'
    if zpath.exists():
        zpath.unlink()
    with zipfile.ZipFile(zpath, 'w', zipfile.ZIP_DEFLATED) as z:
        for p in sorted(mod.rglob('*')):
            if p.is_file():
                z.write(p, p.relative_to(stage).as_posix())
    print(zpath)
    with zipfile.ZipFile(zpath) as z:
        for i in z.infolist():
            print(f'  {i.file_size:>7}  {i.filename}')


if __name__ == '__main__':
    main()
