from pathlib import Path
from PIL import Image

src = Path(__file__).resolve().parent / "assets" / "logo.png"
dest = Path(__file__).resolve().parent / "assets" / "logo.ico"
image = Image.open(src).convert("RGBA")
image.save(dest, sizes=[(16, 16), (32, 32), (48, 48), (64, 64), (128, 128), (256, 256)])
print(dest)
