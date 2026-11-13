"""Read a UE4SS crash dump (ue4ss\\crash_*.dmp) without a debugger.

Prints the exception, the faulting module (+ the UE4SS.dll exported symbol whose function holds the address:
UE4SS exports its C++ API, so most frames get a name), the crashing thread's name and registers, a scan of
return addresses on its stack, and the readable strings its stack points at (UE4SS error messages often sit there,
e.g. "No overload found for function 'FindAllOf'").

Usage: python src/tools/crash_dump.py [crash.dmp] [frames]   (default: the newest dump in the game's ue4ss folder,
40 frames; the outermost frames show who called into Lua, e.g. an object-creation notification or a timer)
"""
import bisect
import re
import struct
import sys
from pathlib import Path

UE4SS = Path(r"G:\G\Steam\steamapps\common\PBZ\platform\steam\ue4ss")


# ---------------------------------------------------------------- UE4SS.dll exports
def load_exports(dll):
    pe = dll.read_bytes()
    e = struct.unpack_from('<I', pe, 0x3C)[0]
    nsec = struct.unpack_from('<H', pe, e + 6)[0]
    optsz = struct.unpack_from('<H', pe, e + 20)[0]
    opt = e + 24
    exp_rva = struct.unpack_from('<I', pe, opt + 112)[0]
    pdata_rva, pdata_size = struct.unpack_from('<II', pe, opt + 112 + 3 * 8)
    secs = []
    for i in range(nsec):
        o = opt + optsz + i * 40
        vsize, va, rsize, raw = struct.unpack_from('<IIII', pe, o + 8)
        secs.append((va, max(vsize, rsize), raw))

    def off(rva):
        for va, size, raw in secs:
            if va <= rva < va + size:
                return raw + rva - va
        raise ValueError(hex(rva))

    o = off(exp_rva)
    nfun, nnames, afun, aname, aord = struct.unpack_from('<IIIII', pe, o + 20)
    funcs = [struct.unpack_from('<I', pe, off(afun) + 4 * i)[0] for i in range(nfun)]
    names = {}
    for i in range(nnames):
        nrva = struct.unpack_from('<I', pe, off(aname) + 4 * i)[0]
        ordn = struct.unpack_from('<H', pe, off(aord) + 2 * i)[0]
        names[funcs[ordn]] = pe[off(nrva):pe.index(b'\0', off(nrva))].decode()
    po = off(pdata_rva)
    fns = sorted(struct.unpack_from('<II', pe, po + 12 * i) for i in range(pdata_size // 12))
    return names, fns


def symbol(rva, names, fns):
    k = bisect.bisect_right([f[0] for f in fns], rva) - 1
    if k < 0:
        return ''
    start, end = fns[k]
    return names.get(start, '(func %X, not exported)' % start) if rva < end else ''


# ---------------------------------------------------------------- minidump
def main():
    path = Path(sys.argv[1]) if len(sys.argv) > 1 and sys.argv[1] != '-' else \
        max(UE4SS.glob('crash_*.dmp'), key=lambda p: p.stat().st_mtime)
    frames = int(sys.argv[2]) if len(sys.argv) > 2 else 40
    d = path.read_bytes()
    _, _, nstreams, rva_dir = struct.unpack_from('<IIII', d, 0)
    streams = {}
    for i in range(nstreams):
        t, size, rva = struct.unpack_from('<III', d, rva_dir + i * 12)
        streams.setdefault(t, (size, rva))

    def mdstring(rva):
        n = struct.unpack_from('<I', d, rva)[0]
        return d[rva + 4: rva + 4 + n].decode('utf-16-le')

    mods = []
    _, rva = streams[4]
    for i in range(struct.unpack_from('<I', d, rva)[0]):
        o = rva + 4 + i * 108
        base, msize = struct.unpack_from('<QI', d, o)
        mods.append((base, msize, mdstring(struct.unpack_from('<I', d, o + 20)[0]).split('\\')[-1]))
    mem = []
    if 9 in streams:
        _, rva = streams[9]
        n, cur = struct.unpack_from('<QQ', d, rva)
        for i in range(n):
            start, size = struct.unpack_from('<QQ', d, rva + 16 + i * 16)
            mem.append((start, size, cur))
            cur += size
    if 5 in streams:
        _, rva = streams[5]
        for i in range(struct.unpack_from('<I', d, rva)[0]):
            start, size, drva = struct.unpack_from('<QII', d, rva + 4 + i * 16)
            mem.append((start, size, drva))

    def read(addr, n):
        for start, size, drva in mem:
            if start <= addr and addr + n <= start + size:
                return d[drva + addr - start: drva + addr - start + n]
        return None

    ue = next((m for m in mods if m[2].lower() == 'ue4ss.dll'), None)
    names, fns = load_exports(UE4SS / 'UE4SS.dll') if ue else ({}, [])

    def where(a):
        for base, size, name in mods:
            if base <= a < base + size:
                s = '%s+0x%X' % (name, a - base)
                if ue and base == ue[0]:
                    s += '  ' + symbol(a - base, names, fns)[:110]
                return s
        return None

    thread_names = {}
    if 24 in streams:
        _, rva = streams[24]
        for i in range(struct.unpack_from('<I', d, rva)[0]):
            tid, nrva = struct.unpack_from('<IQ', d, rva + 4 + i * 12)
            thread_names[tid] = mdstring(nrva)

    _, rva = streams[6]
    tid = struct.unpack_from('<I', d, rva)[0]
    code, _, _, addr, nparams = struct.unpack_from('<IIQQI', d, rva + 8)
    params = struct.unpack_from('<15Q', d, rva + 8 + 32)[:nparams]
    ctx = struct.unpack_from('<II', d, rva + 8 + 152)[1]
    print(path.name)
    print('exception 0x%08X at %s, thread %d %s, params %s' % (code, where(addr), tid, thread_names.get(tid, ''),
                                                              [hex(p) for p in params]))
    regs = ['Rax', 'Rcx', 'Rdx', 'Rbx', 'Rsp', 'Rbp', 'Rsi', 'Rdi', 'R8', 'R9', 'R10', 'R11', 'R12', 'R13', 'R14', 'R15']
    vals = struct.unpack_from('<16Q', d, ctx + 0x78)
    print('registers: ' + '  '.join('%s=%X' % (r, v) for r, v in zip(regs, vals)))
    rsp = vals[4]
    print('return addresses on the stack (heuristic, innermost first):')
    shown = 0
    for k in range(0, 0x8000, 8):
        b = read(rsp + k, 8)
        if b is None or shown >= frames:
            break
        w = where(struct.unpack('<Q', b)[0])
        if w and not w.startswith('ucrtbase'):
            print('  [rsp+%04X] %s' % (k, w))
            shown += 1
    print('strings the stack points at:')
    seen = set()
    for k in range(0, 0x3000, 8):
        b = read(rsp + k, 8)
        if b is None:
            break
        v = struct.unpack('<Q', b)[0]
        for o in (0, 0x18):                     # Lua 5.4 keeps a short string's bytes at +0x18
            s = read(v + o, 160) or b''
            m = re.match(rb'\s*[ -~]{6,160}', s)
            if m and m.group() not in seen:
                seen.add(m.group())
                print('  [rsp+%04X] %s' % (k, m.group().decode().strip()))


main()
