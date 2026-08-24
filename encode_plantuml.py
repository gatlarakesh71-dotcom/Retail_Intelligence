#!/usr/bin/env python3
import sys, zlib

# PlantUML encoding: deflate (zlib) then a custom 6-bit encode
ALPHABET = "0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz-_"

def encode6bit(b):
    return ALPHABET[b & 0x3F]

def append3bytes(b1, b2, b3):
    c1 = (b1 >> 2) & 0x3F
    c2 = ((b1 & 0x3) << 4) | ((b2 >> 4) & 0xF)
    c3 = ((b2 & 0xF) << 2) | ((b3 >> 6) & 0x3)
    c4 = b3 & 0x3F
    return encode6bit(c1) + encode6bit(c2) + encode6bit(c3) + encode6bit(c4)

def plantuml_encode(text: bytes) -> str:
    z = zlib.compress(text)
    # remove zlib header and checksum as PlantUML expects raw DEFLATE stream
    z = z[2:-4]
    res = []
    i = 0
    L = len(z)
    while i < L:
        b1 = z[i]
        b2 = z[i+1] if i+1 < L else 0
        b3 = z[i+2] if i+2 < L else 0
        res.append(append3bytes(b1, b2, b3))
        i += 3
    return ''.join(res)

if __name__ == '__main__':
    if len(sys.argv) < 2:
        print('Usage: encode_plantuml.py <puml_file>', file=sys.stderr)
        sys.exit(2)
    path = sys.argv[1]
    with open(path, 'rb') as f:
        data = f.read()
    print(plantuml_encode(data))
