# Convert approved zone PNGs to WoW BGRA TGA and write Journal/ZoneArt.lua.
from __future__ import print_function
import glob
import os
import re
import struct
from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
REVIEW = os.path.join(ROOT, "Media", "Review", "Zones")
DST = os.path.join(ROOT, "Media", "Zones")
LUA = os.path.join(ROOT, "Journal", "ZoneArt.lua")


def write_tga_bgra(im, dest):
    im = im.convert("RGBA")
    w, h = im.size
    pixels = im.tobytes()
    raw = bytearray(w * h * 4)
    for i in range(0, len(pixels), 4):
        r, g, b, a = pixels[i], pixels[i + 1], pixels[i + 2], pixels[i + 3]
        raw[i] = b
        raw[i + 1] = g
        raw[i + 2] = r
        raw[i + 3] = a
    header = struct.pack(
        "<BBBHHBHHHHBB",
        0, 0, 2, 0, 0, 0, 0, 0, w, h, 32, 32,
    )
    with open(dest, "wb") as f:
        f.write(header)
        f.write(raw)


def resize_cover(im, tw, th):
    im = im.convert("RGBA")
    sw, sh = im.size
    scale = max(float(tw) / sw, float(th) / sh)
    nw = max(1, int(round(sw * scale)))
    nh = max(1, int(round(sh * scale)))
    im = im.resize((nw, nh), Image.Resampling.LANCZOS)
    left = max(0, (nw - tw) // 2)
    top = max(0, (nh - th) // 2)
    return im.crop((left, top, left + tw, top + th))


def main():
    os.makedirs(DST, exist_ok=True)
    converted = 0
    for path in glob.glob(os.path.join(REVIEW, "*", "zone-*.png")):
        name = os.path.basename(path)
        m = re.search(r"zone-[a-z]+-(\d+)-", name)
        if not m:
            print("skip", name)
            continue
        cid = m.group(1)
        im = resize_cover(Image.open(path), 1024, 512)
        dest = os.path.join(DST, cid + ".tga")
        write_tga_bgra(im, dest)
        converted += 1
        print("wrote", dest)
    print("converted", converted)

    ids = []
    for tga in glob.glob(os.path.join(DST, "*.tga")):
        base = os.path.splitext(os.path.basename(tga))[0]
        if base.isdigit():
            ids.append(int(base))
    ids.sort()

    lines = [
        "-- Generated zone cover index. Lua 5.1 only.",
        "AllQuest = AllQuest or {}",
        "local AQ = AllQuest",
        "AQ.Media = AQ.Media or {}",
        "AQ.Media.Zones = AQ.Media.Zones or {}",
        'local MEDIA = "Interface\\\\AddOns\\\\AllQuest\\\\Media\\\\Zones\\\\"',
        "local ids = {",
    ]
    chunk = []
    for i, cid in enumerate(ids, 1):
        chunk.append(str(cid))
        if i % 10 == 0:
            lines.append("    " + ", ".join(chunk) + ",")
            chunk = []
    if chunk:
        lines.append("    " + ", ".join(chunk) + ",")
    lines.extend([
        "}",
        "for i = 1, #ids do",
        "    AQ.Media.Zones[ids[i]] = MEDIA .. ids[i]",
        "end",
        "",
    ])
    with open(LUA, "w", newline="\n") as f:
        f.write("\n".join(lines))
    print("wrote", LUA, "ids", len(ids))


if __name__ == "__main__":
    main()
