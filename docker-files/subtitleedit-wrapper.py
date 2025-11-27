#!/usr/bin/env python3
import sys
from pathlib import Path
import shutil
try:
    import pysubs2
    from pycaption import SRTReader, DFXPWriter
except Exception:
    pysubs2 = None

def parse_args(argv):
    if '/Convert' in argv:
        i = argv.index('/Convert')
        inp = argv[i+1] if len(argv) > i+1 else None
        fmt = argv[i+2] if len(argv) > i+2 else None
        out = None
        for a in argv:
            if a.lower().startswith('/outputfilename:'):
                out = a.split(':',1)[1]
        return inp, fmt, out
    return None, None, None

def convert_with_pysubs2(inp, fmt, outpath):
    subs = pysubs2.load(inp, encoding='utf-8')
    fmt_map = {
        'AdvancedSubStationAlpha': 'ass',
        'SubStationAlphav4': 'ass',
        'SubRip': 'srt',
        'TimedText1.0': 'dfxp',
        'WebVTT': 'vtt'
    }
    target_ext = fmt_map.get(fmt, None)
    if target_ext in ('srt','ass','vtt'):
        subs.save(outpath, format_=target_ext, encoding='utf-8')
        return True
    if fmt in ('TimedText1.0',):
        tmp = Path('/tmp/_se_tmp.srt')
        subs.save(tmp, format_='srt', encoding='utf-8')
        text = tmp.read_text(encoding='utf-8')
        caption_set = SRTReader().read(text)
        dfxp = DFXPWriter().write(caption_set)
        Path(outpath).write_text(dfxp, encoding='utf-8')
        return True
    return False

def main():
    inp, fmt, out = parse_args(sys.argv)
    if not inp or not fmt or not out:
        print('subtitleedit wrapper: unsupported args or missing parameters', file=sys.stderr)
        sys.exit(2)
    inp = str(Path(inp))
    outpath = str(Path(inp).with_name(out))
    if pysubs2:
        ok = convert_with_pysubs2(inp, fmt, outpath)
        if ok:
            sys.exit(0)
    shutil.copy(inp, outpath)
    sys.exit(0)

if __name__ == '__main__':
    main()
