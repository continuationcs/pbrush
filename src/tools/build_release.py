"""Build the Nexus release zip of the Trial of Echoes (BOSS RUSH) mod.

Copies src/mod/BossRush into out/, switches the copy to a release configuration (debug log off), adds the
README and enabled.txt, and zips it so the archive extracts straight into the game's UE4SS Mods folder:

    <game>/platform/steam/ue4ss/Mods/BossRush/...

The repo's own src/mod/BossRush is never modified. Usage: python src/tools/build_release.py <version>
"""
import re
import shutil
import sys
import zipfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]     # repo root (this file is src/tools/build_release.py)
SRC = ROOT / 'src' / 'mod' / 'BossRush'
OUT = ROOT / 'out'
RELEASE_DOCS = ROOT / 'doc' / 'release'


def main():
    version = sys.argv[1] if len(sys.argv) > 1 else '0.1.0'
    stage = OUT / f'BossRush-{version}'
    if stage.exists():
        shutil.rmtree(stage)
    mod = stage / 'BossRush'
    shutil.copytree(SRC, mod, ignore=shutil.ignore_patterns('records.tsv', 'enabled.txt', '*.bak', 'devtools.lua', 'dev.tsv', 'marks.tsv'))

    # Release configuration: no debug log.
    cfg = mod / 'Scripts' / 'config.lua'
    text = cfg.read_text(encoding='utf-8')
    text, n = re.subn(r'(\n\s*debug\s*=\s*)true,', r'\1false,', text)
    if n != 1:
        sys.exit('config.lua: could not switch debug off')
    cfg.write_text(text, encoding='utf-8', newline='\n')

    # The version the mod shows (result screen): version.lua returns "dev" in the repo.
    ver = mod / 'Scripts' / 'version.lua'
    text, n = re.subn(r'return "dev"', f'return "{version}"', ver.read_text(encoding='utf-8'))
    if n != 1:
        sys.exit('version.lua: could not set the version')
    ver.write_text(text, encoding='utf-8', newline='\n')

    (mod / 'enabled.txt').write_text('', encoding='ascii')
    for name in ('README.txt', 'README_zh.txt'):
        src = RELEASE_DOCS / name
        if src.exists():
            shutil.copy(src, mod / name)

    # Sanity: no leftovers of the retired probe or debug key bindings in the shipped scripts. Key bindings go through U.key
    # (util.lua defines it on top of RegisterKeyBind; only development code calls it).
    for f in (mod / 'Scripts').glob('*.lua'):
        body = f.read_text(encoding='utf-8')
        bad_words = ['BRProbe', 'GenerateSDK'] + ([] if f.name == 'util.lua' else ['U.key(', 'RegisterKeyBind'])
        for bad in bad_words:
            if bad in body:
                sys.exit(f'{f.name}: contains {bad}')

    zpath = OUT / f'BossRush-{version}.zip'
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
