"""Generate original geometric image fixtures. Not bundled with the application."""
from pathlib import Path
from PIL import Image, ImageDraw, PngImagePlugin

root = Path(__file__).resolve().parents[1] / 'test' / 'fixtures'
root.mkdir(parents=True, exist_ok=True)
image = Image.new('RGB', (120, 2400), '#eee5d5')
draw = ImageDraw.Draw(image)
for y in range(0, 2400, 120):
    draw.rectangle((10, y + 10, 110, y + 100), fill='#243c31')
metadata = PngImagePlugin.PngInfo()
metadata.add_text('Software', 'CodeRabbit generated reader regression fixture; original geometric artwork')
image.save(root / 'long_strip.png', pnginfo=metadata)
image.save(root / 'long_strip.jpg', quality=85)
image.save(root / 'long_strip.webp', quality=85)
image.save(root / 'long_strip_lossless.webp', lossless=True)
image.save(root / 'long_strip.gif')

image.transpose(Image.Transpose.ROTATE_90).save(root / 'wide_page.png', pnginfo=metadata)
