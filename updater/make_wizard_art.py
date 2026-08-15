from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parent
LOGO = ROOT / "assets" / "logo.png"
SIDE = ROOT / "assets" / "wizard-side.png"
SMALL = ROOT / "assets" / "wizard-small.png"

BG = (0, 0, 0, 255)
YELLOW = (255, 230, 0, 255)


def font(size: int) -> ImageFont.FreeTypeFont | ImageFont.ImageFont:
    for name in ("segoeuib.ttf", "seguisb.ttf", "segoeui.ttf", "arialbd.ttf"):
        path = Path(r"C:\Windows\Fonts") / name
        if path.is_file():
            return ImageFont.truetype(str(path), size)
    return ImageFont.load_default()


def make_side() -> None:
    width, height = 280, 520
    image = Image.new("RGBA", (width, height), BG)
    logo = Image.open(LOGO).convert("RGBA")
    logo.thumbnail((240, 240), Image.Resampling.LANCZOS)
    image.alpha_composite(logo, ((width - logo.width) // 2, 48))

    draw = ImageDraw.Draw(image)
    title = font(28)
    subtitle = font(18)
    line1 = "BLIND MICE"
    line2 = "GAMING"
    line3 = "UPDATER SETUP"
    for text, face, y in ((line1, title, 320), (line2, title, 356), (line3, subtitle, 420)):
        box = draw.textbbox((0, 0), text, font=face)
        x = (width - (box[2] - box[0])) // 2
        draw.text((x, y), text, font=face, fill=YELLOW)

    SIDE.parent.mkdir(parents=True, exist_ok=True)
    image.save(SIDE)
    print(SIDE)


def make_small() -> None:
    size = 64
    image = Image.new("RGBA", (size, size), BG)
    logo = Image.open(LOGO).convert("RGBA")
    logo.thumbnail((size, size), Image.Resampling.LANCZOS)
    image.alpha_composite(logo, ((size - logo.width) // 2, (size - logo.height) // 2))
    image.save(SMALL)
    print(SMALL)


if __name__ == "__main__":
    make_side()
    make_small()
