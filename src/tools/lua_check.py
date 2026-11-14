"""Rough Lua sanity check (there is no Lua interpreter on this machine): block keywords vs end, bracket
balance, and calls to names that are neither defined in the file nor known globals.

Mod rule (AGENTS.md): in the mod, only util.lua may call the UE4SS entry-point APIs (RAW_ENTRY); every other
file goes through U.after / U.every / U.on_new / U.hook / U.key, which run on the game thread and turn errors
into a clean stop. LoopAsync and ExecuteWithDelay are banned everywhere (FORBIDDEN): their callbacks run on
another thread in the mod's Lua state, which corrupted it (AGENTS.md). A file breaking either rule fails the check.

Usage: python src/tools/lua_check.py [file.lua ...]   (default: every script of the mod)
Exit code 1 when a file is unbalanced.
"""
import re
import sys
from pathlib import Path

SRC = Path(__file__).resolve().parents[1]


def strip(src):
    out, i, n = [], 0, len(src)
    while i < n:
        c = src[i]
        if src.startswith('--', i):
            m = re.match(r'--\[(=*)\[', src[i:])
            if m:
                j = src.find(']' + m.group(1) + ']', i)
                i = j + len(m.group(1)) + 2
            else:
                j = src.find('\n', i)
                i = n if j < 0 else j
            continue
        m = re.match(r'\[(=*)\[', src[i:])
        if m:
            j = src.find(']' + m.group(1) + ']', i)
            out.append(' "" ')
            i = j + len(m.group(1)) + 2
            continue
        if c in '"\'':
            j = i + 1
            while src[j] != c:
                if src[j] == '\\':
                    j += 1
                if src[j] == '\n':
                    raise SystemExit('unterminated string near line %d' % (src.count('\n', 0, i) + 1))
                j += 1
            out.append(' "" ')
            i = j + 1
            continue
        out.append(c)
        i += 1
    return ''.join(out)


# FindAllOf too: U.find_all checks its argument is a string, which UE4SS's own check can crash on (AGENTS.md).
RAW_ENTRY = ('ExecuteInGameThread', 'ExecuteInGameThreadWithDelay', 'LoopInGameThreadWithDelay', 'CancelDelayedAction',
             'RegisterHook', 'NotifyOnNewObject', 'RegisterKeyBind', 'FindAllOf')
FORBIDDEN = ('LoopAsync', 'ExecuteWithDelay')
ENTRY_OWNER = 'util.lua'

files = sys.argv[1:] or [str(p) for p in sorted(SRC.glob('mod/*/Scripts/*.lua'))]
bad = False
for path in files:
    s = strip(open(path, encoding='utf-8').read())
    depth = 0
    for m in re.finditer(r'\b(function|if|do|repeat|end|until)\b', s):
        depth += 1 if m.group(1) in ('function', 'if', 'do', 'repeat') else -1
        if depth < 0:
            print('BAD %s: extra end near line %d' % (path, s.count('\n', 0, m.start()) + 1))
            bad = True
            break
    br = {c: s.count(c) for c in '()[]{}'}
    ok = depth == 0 and br['('] == br[')'] and br['['] == br[']'] and br['{'] == br['}']
    # identifiers called as functions but never defined/assigned anywhere in the file (locals only)
    defined = set(re.findall(r'\blocal\s+function\s+(\w+)', s))
    for m in re.finditer(r'\blocal\s+([\w\s,]+?)\s*=', s):
        defined.update(x.strip() for x in m.group(1).split(','))
    for m in re.finditer(r'\blocal\s+([\w\s,]+?)\s*\n', s):
        defined.update(x.strip() for x in m.group(1).split(','))
    defined.update(re.findall(r'^(\w+)\s*=\s*function', s, re.M))
    params = set()
    for m in re.finditer(r'function\s*[\w.:]*\s*\(([^)]*)\)', s):
        params.update(x.strip() for x in m.group(1).split(','))
    for m in re.finditer(r'\bfor\s+([\w\s,]+?)\s+(?:in|=)', s):
        params.update(x.strip() for x in m.group(1).split(','))
    known_globals = {'print', 'pcall', 'xpcall','ipairs', 'pairs', 'require', 'tostring', 'tonumber', 'type', 'error',
                     'select', 'setmetatable', 'getmetatable', 'rawget', 'rawset', 'next', 'unpack', 'assert',
                     'RegisterHook', 'NotifyOnNewObject', 'ExecuteInGameThread', 'ExecuteInGameThreadWithDelay',
                     'LoopInGameThreadWithDelay', 'CancelDelayedAction',
                     'FindFirstOf', 'FindAllOf', 'StaticFindObject', 'FName', 'FText', 'LoadAsset', 'RegisterKeyBind',
                     'RegisterConsoleCommandHandler', 'GenerateSDK', 'DumpAllObjects', 'StaticConstructObject',
                     'function', 'if', 'while', 'return', 'and', 'or', 'not', 'elseif', 'until', 'load_class'}
    undefined = set()
    for m in re.finditer(r'(?<![.:\w])(\w+)\s*\(', s):
        name = m.group(1)
        if name not in defined and name not in params and name not in known_globals:
            undefined.add(name)
    p = Path(path).resolve()
    if p.parent.name == 'Scripts' and p.parent.parent.parent.name == 'mod' and p.name != ENTRY_OWNER:
        raw = sorted({n for n in RAW_ENTRY if re.search(r'(?<![.:\w])' + n + r'\b', s)})
        if raw:
            print('BAD %s: calls %s directly; use the entry points in %s' % (path, ', '.join(raw), ENTRY_OWNER))
            ok = False
    banned = sorted({n for n in FORBIDDEN if re.search(r'(?<![.:\w])' + n + r'\b', s)})
    if banned:
        print('BAD %s: calls %s; use U.after / U.every (game-thread delayed actions)' % (path, ', '.join(banned)))
        ok = False
    msg = 'OK ' if ok else 'BAD'
    print('%s %s depth=%d () %d/%d [] %d/%d {} %d/%d%s' % (msg, path, depth, br['('], br[')'], br['['], br[']'],
          br['{'], br['}'], ('  undefined calls: ' + ', '.join(sorted(undefined))) if undefined else ''))
    bad = bad or not ok
sys.exit(1 if bad else 0)
