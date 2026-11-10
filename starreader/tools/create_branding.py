"""Generate original StarReader geometric artwork; no external image assets."""
from pathlib import Path
from PIL import Image, ImageDraw
from PIL.PngImagePlugin import PngInfo
META = PngInfo()
META.add_text("Software", "CodeRabbit generated original StarReader geometry")
import math
ROOT = Path(__file__).resolve().parents[1]

def icon(size):
    im = Image.new('RGB', (size, size), '#101513')
    d = ImageDraw.Draw(im)
    d.rounded_rectangle((size*.12,size*.12,size*.88,size*.88), radius=size*.22, fill='#284335')
    def star(cx,cy,r):
        pts=[]
        for i in range(8):
            angle=i*math.pi/4-math.pi/2
            radius=r if i%2==0 else r*.32
            pts.append((cx+math.cos(angle)*radius,cy+math.sin(angle)*radius))
        d.polygon(pts,fill='#bdedd0')
    star(size*.46,size*.52,size*.25)
    star(size*.73,size*.28,size*.10)
    star(size*.72,size*.73,size*.075)
    return im

for density,size in [('mdpi',48),('hdpi',72),('xhdpi',96),('xxhdpi',144),('xxxhdpi',192)]:
    target=ROOT/'android/app/src/main/res'/f'mipmap-{density}'/'ic_launcher.png'
    target.parent.mkdir(parents=True,exist_ok=True)
    icon(size*4).resize((size,size),Image.Resampling.LANCZOS).save(target, pnginfo=META)
for size in [192,512]:
    for suffix in ['', '-maskable']:
        icon(size).save(ROOT/'web/icons'/f'Icon{suffix}-{size}.png', pnginfo=META)
icon(64).save(ROOT/'web/favicon.png', pnginfo=META)
icon(1024).save(ROOT/'assets/starreader-icon.png', pnginfo=META)
