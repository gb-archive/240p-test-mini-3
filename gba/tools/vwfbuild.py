#!/usr/bin/env python3
from __future__ import with_statement
from PIL import Image
import array

def ca65_bytearray(s):
    s = ['  .byte ' + ','.join("%3d" % ch for ch in s[i:i + 16])
         for i in range(0, len(s), 16)]
    return '\n'.join(s)

def vwfcvt(filename, tileHt=8):
    im = Image.open(filename)
    pixels = im.load()
    (w, h) = im.size
    (xparentColor, sepColor) = im.getextrema()
    widths = bytearray()
    tiledata = bytearray()
    for yt in range(0, h, tileHt):
        for xt in range(0, w, 8):
            # step 1: find the glyph width
            tilew = 8
            for x in range(8):
                if pixels[x + xt, yt] == sepColor:
                    tilew = x
                    break
            # step 2: encode the pixels
            widths.append(tilew)
            for y in range(tileHt):
                rowdata = 0
                for x in range(8):
                    pxhere = pixels[x + xt, y + yt]
                    pxhere = 0 if pxhere in (xparentColor, sepColor) else 1
                    rowdata |= pxhere << x
                tiledata.append(rowdata)
    return (widths, tiledata)

def main(argv=None):
    import sys
    if argv is None:
        argv = sys.argv
    if len(argv) > 1 and argv[1] == '--help':
        print("usage: %s font.png font.s [font.h]" % argv[0])
        return
    if len(argv) < 3 or len(argv) > 4:
        print("wrong number of options; try %s --help" % argv[0], file=sys.stderr)
        sys.exit(1)
        
    (widths, tiledata) = vwfcvt(argv[1])
    out = ["@ Generated by vwfbuild",
           ".global vwfChrWidths, vwfChrData",
           ".hidden vwfChrWidths, vwfChrData",
           '.section .rodata',
           '.align 2',
           'vwfChrData:',
           ca65_bytearray(tiledata),
           "vwfChrWidths:",
           ca65_bytearray(widths),
           '']
    with open(argv[2], 'w') as outfp:
        outfp.write('\n'.join(out))
    if len(argv) > 3:
        out = ["// Generated by vwfbuild",
               "#ifndef VWFCHR_H__",
               "#define VWFCHR_H__",
               "extern const unsigned char vwfChrData[" + str(int(len(tiledata) / 8)) + "][8];\n"
               "extern const unsigned char vwfChrWidths[" + str(len(widths)) + "];\n"
               "#endif",
               '']
        with open(argv[3], 'w') as outfp:
            outfp.write('\n'.join(out))

if __name__ == '__main__':
##    main(['vwfbuild', '../tilesets/vwf7.png', '../obj/vwf7.s'])
    main()
