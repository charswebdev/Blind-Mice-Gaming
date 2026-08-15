# Convert approved journal PNGs to WoW BGRA TGA (power-of-two).
from __future__ import print_function
import os
import struct
from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
REVIEW = os.path.join(ROOT, "Media", "Review")
ICONS_SRC = os.path.join(REVIEW, "Icons")
COVERS_SRC = os.path.join(REVIEW, "Covers")
ICONS_DST = os.path.join(ROOT, "Media", "Icons")
COVERS_DST = os.path.join(ROOT, "Media", "Covers")


def write_tga_bgra(im, dest):
    im = im.convert("RGBA")
    w, h = im.size
    pixels = im.tobytes()
    raw = bytearray(w * h * 4)
    for i in range(0, len(pixels), 4):
        r, g, b, a = pixels[i], pixels[i + 1], pixels[i + 2], pixels[i + 3]
        j = i
        raw[j] = b
        raw[j + 1] = g
        raw[j + 2] = r
        raw[j + 3] = a
    header = struct.pack(
        "<BBBHHBHHHHBB",
        0, 0, 2, 0, 0, 0, 0, 0, w, h, 32, 32,
    )
    with open(dest, "wb") as f:
        f.write(header)
        f.write(raw)
    print("wrote", dest, w, "x", h, os.path.getsize(dest))


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
    os.makedirs(ICONS_DST, exist_ok=True)
    os.makedirs(COVERS_DST, exist_ok=True)

    icons = [
        ("journal-icon-home.png", "Home.tga"),
        ("journal-icon-back.png", "Back.tga"),
        ("journal-icon-close.png", "Close.tga"),
        ("journal-icon-search.png", "Search.tga"),
        ("journal-icon-grid.png", "Grid.tga"),
        ("journal-icon-list.png", "List.tga"),
        ("journal-icon-here.png", "Here.tga"),
    ]
    for src_name, dst_name in icons:
        src = os.path.join(ICONS_SRC, src_name)
        im = Image.open(src).convert("RGBA")
        im = im.resize((256, 256), Image.Resampling.LANCZOS)
        write_tga_bgra(im, os.path.join(ICONS_DST, dst_name))

    covers = [
        ("cover-classic.png", "Classic.tga"),
        ("cover-tbc.png", "TBC.tga"),
        ("cover-wrath.png", "Wrath.tga"),
        ("cover-cata.png", "Cata.tga"),
        ("cover-mop.png", "MoP.tga"),
        ("cover-wod.png", "WoD.tga"),
        ("cover-legion.png", "Legion.tga"),
        ("cover-bfa.png", "BFA.tga"),
        ("cover-shadowlands.png", "Shadowlands.tga"),
        ("cover-dragonflight.png", "Dragonflight.tga"),
        ("cover-tww.png", "TWW.tga"),
        ("cover-midnight.png", "Midnight.tga"),
    ]
    for src_name, dst_name in covers:
        src = os.path.join(COVERS_SRC, src_name)
        im = Image.open(src)
        im = resize_cover(im, 1024, 512)
        write_tga_bgra(im, os.path.join(COVERS_DST, dst_name))


if __name__ == "__main__":
    main()
