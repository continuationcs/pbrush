"""Nexus main image (1920x1080) for Boss Challenge.

Background: an in-game screenshot (blurred and darkened so no UI text shows through), title in Kaiti.
Usage: python tools/make_cover.py <screenshot> <out.png>
"""
import os
import sys
from PIL import Image, ImageDraw, ImageFilter, ImageFont

W, H = 1920, 1080
FONTS = r"C:\Windows\Fonts"


def font(names, size):
    for n in names:
        p = os.path.join(FONTS, n)
        if os.path.exists(p):
            return ImageFont.truetype(p, size)
    return ImageFont.load_default()


def centered(draw, y, text, f, fill, spacing=0, shadow=None):
    if spacing:
        widths = [draw.textlength(ch, font=f) for ch in text]
        total = sum(widths) + spacing * (len(text) - 1)
        x = (W - total) / 2
        for ch, w in zip(text, widths):
            if shadow:
                draw.text((x + 3, y + 4), ch, font=f, fill=shadow)
            draw.text((x, y), ch, font=f, fill=fill)
            x += w + spacing
        return
    w = draw.textlength(text, font=f)
    if shadow:
        draw.text(((W - w) / 2 + 3, y + 4), text, font=f, fill=shadow)
    draw.text(((W - w) / 2, y), text, font=f, fill=fill)


def main(src, out):
    bg = Image.open(src).convert("RGB")
    # Fill 16:9 from the top of the shot, then blur hard so the probe's labels vanish.
    scale = max(W / bg.width, H / bg.height)
    bg = bg.resize((int(bg.width * scale), int(bg.height * scale)), Image.LANCZOS)
    bg = bg.crop((0, 0, W, H))
    # The screenshot carries UI text ("敬请期待！" and the probe's labels with white icon squares): smear
    # those areas much harder than the rest, through a soft mask.
    heavy = bg.filter(ImageFilter.GaussianBlur(60))
    mask = Image.new("L", (W, H), 0)
    md = ImageDraw.Draw(mask)
    md.rectangle([500, 360, 1440, 600], fill=255)
    md.rectangle([200, 650, 1720, 1100], fill=255)
    mask = mask.filter(ImageFilter.GaussianBlur(40))
    bg = Image.composite(heavy, bg, mask).filter(ImageFilter.GaussianBlur(9))
    # Darken, with a cool ink tint.
    dark = Image.new("RGB", (W, H), (8, 10, 16))
    bg = Image.blend(bg, dark, 0.30)
    # Vignette + central ink band behind the title.
    shade = Image.new("L", (W, H), 0)
    sd = ImageDraw.Draw(shade)
    for i in range(60):
        a = int(255 * (i / 60) ** 2 * 0.85)
        sd.rectangle([i * 8, i * 5, W - i * 8, H - i * 5], outline=None)
    band = Image.new("L", (W, H), 0)
    bd = ImageDraw.Draw(band)
    bd.ellipse([0, 330, W, 800], fill=170)
    band = band.filter(ImageFilter.GaussianBlur(90))
    bg = Image.composite(Image.new("RGB", (W, H), (4, 5, 8)), bg, band)
    edge = Image.new("L", (W, H), 0)
    ed = ImageDraw.Draw(edge)
    ed.rectangle([0, 0, W, H], outline=255, width=140)
    edge = edge.filter(ImageFilter.GaussianBlur(120))
    bg = Image.composite(Image.new("RGB", (W, H), (0, 0, 0)), bg, edge)

    d = ImageDraw.Draw(bg)
    red = (176, 28, 32)
    # Brush stroke: a soft red bar behind the title.
    stroke = Image.new("L", (W, H), 0)
    st = ImageDraw.Draw(stroke)
    st.rounded_rectangle([W / 2 - 520, 520, W / 2 + 520, 534], radius=7, fill=230)
    stroke = stroke.filter(ImageFilter.GaussianBlur(3))
    bg.paste(Image.new("RGB", (W, H), red), (0, 0), stroke)
    d = ImageDraw.Draw(bg)

    kai = ["simkai.ttf", "STKAITI.TTF"]
    serif = ["georgiab.ttf", "georgia.ttf", "timesbd.ttf", "times.ttf"]
    centered(d, 290, "BOSS RUSH", font(serif, 170), (240, 236, 228), spacing=14, shadow=(0, 0, 0))
    centered(d, 600, "单挑 · 连战", font(kai, 64), (210, 200, 188))
    centered(d, 690, "DUEL  ·  GAUNTLET", font(serif, 34), (180, 170, 160), spacing=6)
    centered(d, 930, "影之刃零  ·  PHANTOM BLADE ZERO", font(["msyh.ttc", "simhei.ttf"], 30), (150, 140, 132), spacing=4)
    # Seal-style mark, lower right.
    seal = font(kai, 54)
    x0, y0 = W - 230, H - 230
    d.rounded_rectangle([x0, y0, x0 + 130, y0 + 130], radius=10, fill=red)
    d.text((x0 + 14, y0 + 8), "再", font=seal, fill=(245, 232, 220))
    d.text((x0 + 66, y0 + 66), "战", font=seal, fill=(245, 232, 220))
    bg.save(out, "PNG")
    print(out)


if __name__ == "__main__":
    main(sys.argv[1], sys.argv[2])
