#!/usr/bin/env python3
"""
Generates AAA-quality PBR textures (albedo, normal, roughness), ornate Persian
board artwork (2048px), royal Persian table mat, and procedural SFX for
Mench (Ludo) & Takhte Nard (Backgammon) — tuned for Mobile Portrait 3D!
"""

import math
import os
import random
import struct
import wave
from PIL import Image, ImageDraw, ImageFilter

BASE_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
TEX_DIR = os.path.join(BASE_DIR, "assets", "textures")
AUD_DIR = os.path.join(BASE_DIR, "assets", "audio")
os.makedirs(TEX_DIR, exist_ok=True)
os.makedirs(AUD_DIR, exist_ok=True)


def clamp(v, lo=0, hi=255):
    return max(lo, min(hi, int(v)))


def height_to_normal(height_img, strength=2.2):
    """Converts a grayscale PIL heightmap into a tangent-space RGB normal map."""
    w, h = height_img.size
    src = height_img.convert("L").load()
    out = Image.new("RGB", (w, h), (128, 128, 255))
    dst = out.load()
    for y in range(h):
        ym = max(0, y - 1)
        yp = min(h - 1, y + 1)
        for x in range(w):
            xm = max(0, x - 1)
            xp = min(w - 1, x + 1)
            dx = (src[xp, y] - src[xm, y]) / 255.0 * strength
            dy = (src[x, yp] - src[x, ym]) / 255.0 * strength
            dz = 1.0
            inv_len = 1.0 / math.sqrt(dx * dx + dy * dy + dz * dz)
            nx = (-dx * inv_len * 0.5 + 0.5) * 255.0
            ny = (-dy * inv_len * 0.5 + 0.5) * 255.0
            nz = (dz * inv_len * 0.5 + 0.5) * 255.0
            dst[x, y] = (clamp(nx), clamp(ny), clamp(nz))
    return out


def generate_wood_pbr(width=1024, height=1024, base_rgb=(98, 56, 28), grain_rgb=(44, 21, 10), seed=42):
    """Generates rich walnut wood albedo + heightmap for normal & roughness."""
    rng = random.Random(seed)
    albedo = Image.new("RGB", (width, height), base_rgb)
    hmap = Image.new("L", (width, height), 128)
    apx = albedo.load()
    hpx = hmap.load()

    phases = [rng.uniform(0, 6.28) for _ in range(8)]
    for y in range(height):
        row_shift = (
            math.sin(y * 0.009 + phases[0]) * 18.0
            + math.sin(y * 0.025 + phases[1]) * 7.0
            + math.sin(y * 0.06 + phases[5]) * 2.5
        )
        for x in range(width):
            v = (
                math.sin((x + row_shift) * 0.017 + phases[2]) * 0.45
                + math.sin((x * 1.9 - row_shift * 0.55) * 0.048 + phases[3]) * 0.30
                + math.sin((x * 0.11 + y * 0.005) + phases[4]) * 0.15
                + math.sin((x * 0.28 + y * 0.01) + phases[6]) * 0.10
            )
            t = (v + 1.0) * 0.5
            pore = ((hash((x // 2, y // 10)) & 255) / 255.0 - 0.5) * 0.18
            t = max(0.0, min(1.0, t + pore))
            r = clamp(base_rgb[0] * (1 - t * 0.56) + grain_rgb[0] * (t * 0.56))
            g = clamp(base_rgb[1] * (1 - t * 0.56) + grain_rgb[1] * (t * 0.56))
            b = clamp(base_rgb[2] * (1 - t * 0.56) + grain_rgb[2] * (t * 0.56))
            apx[x, y] = (r, g, b)
            hpx[x, y] = clamp(200 - t * 140)
    return albedo.filter(ImageFilter.GaussianBlur(radius=0.5)), hmap.filter(ImageFilter.GaussianBlur(radius=0.6))


def draw_khatam_border(draw, x0, y0, x1, y1, thickness=34):
    """Draws an intricate multi-band Persian Khatamkari geometric border."""
    gold = (224, 184, 96)
    gold_hi = (248, 218, 134)
    dark = (36, 20, 12)
    ivory = (244, 232, 204)
    crimson = (158, 30, 38)
    turquoise = (24, 124, 118)
    navy = (28, 52, 98)

    draw.rectangle([x0, y0, x1, y1], outline=gold, width=5)
    step = thickness
    palette = [crimson, turquoise, navy]

    # Top & Bottom strips
    for i, x in enumerate(range(x0, x1 - step + 1, step)):
        for by in (y0, y1 - thickness):
            cx = x + step // 2
            cy = by + thickness // 2
            draw.rectangle([x, by, x + step, by + thickness], fill=dark, outline=gold, width=1)
            r = thickness // 2 - 3
            draw.polygon([(cx, cy - r), (cx + r, cy), (cx, cy + r), (cx - r, cy)], fill=ivory, outline=gold_hi)
            r2 = max(3, int(r * 0.56))
            draw.polygon([(cx, cy - r2), (cx + r2, cy), (cx, cy + r2), (cx - r2, cy)], fill=palette[i % 3], outline=gold)
            draw.ellipse([cx - 2, cy - 2, cx + 2, cy + 2], fill=gold_hi)

    # Left & Right strips
    for i, y in enumerate(range(y0 + thickness, y1 - thickness - step + 1, step)):
        for bx in (x0, x1 - thickness):
            cx = bx + thickness // 2
            cy = y + step // 2
            draw.rectangle([bx, y, bx + thickness, y + step], fill=dark, outline=gold, width=1)
            r = thickness // 2 - 3
            draw.polygon([(cx, cy - r), (cx + r, cy), (cx, cy + r), (cx - r, cy)], fill=ivory, outline=gold_hi)
            r2 = max(3, int(r * 0.56))
            draw.polygon([(cx, cy - r2), (cx + r2, cy), (cx, cy + r2), (cx - r2, cy)], fill=palette[(i + 1) % 3], outline=gold)
            draw.ellipse([cx - 2, cy - 2, cx + 2, cy + 2], fill=gold_hi)


def draw_persian_star(draw, cx, cy, r_outer, r_inner, points=8, fill=(224, 184, 96), outline=(120, 84, 28)):
    pts = []
    step_deg = 360.0 / (points * 2)
    for i in range(points * 2):
        ang = math.radians(i * step_deg - 90)
        r = r_outer if i % 2 == 0 else r_inner
        pts.append((cx + math.cos(ang) * r, cy + math.sin(ang) * r))
    draw.polygon(pts, fill=fill, outline=outline)


def draw_beveled_tile(draw, hdraw, x0, y0, x1, y1, fill, border=(130, 102, 68)):
    draw.rectangle([x0, y0, x1, y1], fill=fill, outline=border, width=2)
    # Subtle top-left inner sheen & bottom-right shadow
    hi = tuple(min(255, c + 16) for c in fill[:3])
    lo = tuple(max(0, c - 20) for c in fill[:3])
    draw.line([(x0 + 3, y0 + 3), (x1 - 3, y0 + 3)], fill=hi, width=2)
    draw.line([(x0 + 3, y0 + 3), (x0 + 3, y1 - 3)], fill=hi, width=2)
    draw.line([(x0 + 3, y1 - 3), (x1 - 3, y1 - 3)], fill=lo, width=2)
    draw.line([(x1 - 3, y0 + 3), (x1 - 3, y1 - 3)], fill=lo, width=2)
    # Heightmap grout groove
    hdraw.rectangle([x0, y0, x1, y1], fill=185, outline=70, width=4)


def generate_ludo_board_pbr():
    """Generates an ornate 1800x1800 Persian Royal Mench board + normal map."""
    size = 1800
    cell = size // 15  # 120 px per cell
    img = Image.new("RGB", (size, size), (242, 232, 208))
    himg = Image.new("L", (size, size), 180)
    draw = ImageDraw.Draw(img)
    hdraw = ImageDraw.Draw(himg)

    # Rich marble/parchment base speckle
    rng = random.Random(21)
    for _ in range(9000):
        rx = rng.randint(0, size - 1)
        ry = rng.randint(0, size - 1)
        draw.point((rx, ry), fill=(228, 214, 186))

    RED = (188, 36, 48)
    RED_DARK = (122, 18, 28)
    GREEN = (24, 134, 82)
    GREEN_DARK = (12, 84, 50)
    YELLOW = (224, 166, 32)
    YELLOW_DARK = (158, 108, 14)
    BLUE = (30, 96, 184)
    BLUE_DARK = (16, 58, 122)
    GOLD = (214, 172, 78)
    GOLD_BRIGHT = (244, 212, 120)
    CREAM = (234, 222, 196)
    CREAM_ALT = (224, 210, 182)

    def tile(gx, gy, col):
        draw_beveled_tile(draw, hdraw, gx * cell, gy * cell, (gx + 1) * cell, (gy + 1) * cell, col)

    # 15x15 base track tiles with subtle checkerboard ivory tint
    for gx in range(15):
        for gy in range(15):
            tile(gx, gy, CREAM if (gx + gy) % 2 == 0 else CREAM_ALT)

    # Home columns & start tiles
    for gx in range(1, 6):
        tile(gx, 7, RED)
    tile(1, 6, RED)

    for gy in range(1, 6):
        tile(7, gy, GREEN)
    tile(8, 1, GREEN)

    for gx in range(9, 14):
        tile(gx, 7, YELLOW)
    tile(13, 8, YELLOW)

    for gy in range(9, 14):
        tile(7, gy, BLUE)
    tile(6, 13, BLUE)

    # Decorative directional arrows pointing into home stretches
    arrows = [
        (0, 7, (1, 0), RED),
        (7, 0, (0, 1), GREEN),
        (14, 7, (-1, 0), YELLOW),
        (7, 14, (0, -1), BLUE),
    ]
    for gx, gy, (dx, dy), col in arrows:
        cx = gx * cell + cell // 2
        cy = gy * cell + cell // 2
        tip = (cx + dx * 32, cy + dy * 32)
        left = (cx - dx * 22 - dy * 24, cy - dy * 22 + dx * 24)
        right = (cx - dx * 22 + dy * 24, cy - dy * 22 - dx * 24)
        draw.polygon([tip, left, right], fill=col, outline=GOLD)

    # Ornate 8-point Persian stars on safe tiles
    for gx, gy in [(2, 8), (6, 2), (12, 6), (8, 12)]:
        cx, cy = gx * cell + cell // 2, gy * cell + cell // 2
        tile(gx, gy, (234, 218, 184))
        draw_persian_star(draw, cx, cy, 42, 20, points=8, fill=GOLD, outline=(122, 84, 28))
        draw_persian_star(draw, cx, cy, 20, 9, points=8, fill=CREAM, outline=GOLD)
        hdraw.ellipse([cx - 38, cy - 38, cx + 38, cy + 38], fill=215)

    for gx, gy in [(1, 6), (8, 1), (13, 8), (6, 13)]:
        cx, cy = gx * cell + cell // 2, gy * cell + cell // 2
        draw_persian_star(draw, cx, cy, 38, 18, points=8, fill=CREAM, outline=GOLD_BRIGHT)
        draw.ellipse([cx - 10, cy - 10, cx + 10, cy + 10], fill=GOLD)

    # 4 Ornate Royal Corner Yards (6x6)
    yards = [
        (0, 0, RED, RED_DARK),
        (9, 0, GREEN, GREEN_DARK),
        (9, 9, YELLOW, YELLOW_DARK),
        (0, 9, BLUE, BLUE_DARK),
    ]
    for yx, yy, col, col_dark in yards:
        x0, y0 = yx * cell, yy * cell
        x1, y1 = (yx + 6) * cell, (yy + 6) * cell
        draw.rectangle([x0, y0, x1, y1], fill=col, outline=GOLD, width=6)
        draw.rectangle([x0 + 18, y0 + 18, x1 - 18, y1 - 18], fill=col_dark, outline=GOLD_BRIGHT, width=3)
        hdraw.rectangle([x0, y0, x1, y1], fill=195, outline=80, width=8)

        # Subtle ornamental corner filigree diamonds
        for fx in (x0 + 44, x1 - 44):
            for fy in (y0 + 44, y1 - 44):
                draw_persian_star(draw, fx, fy, 18, 8, points=8, fill=GOLD, outline=col_dark)

        # Inner sanctuary panel
        pad = 78
        draw.rounded_rectangle([x0 + pad, y0 + pad, x1 - pad, y1 - pad], radius=48, fill=CREAM, outline=GOLD_BRIGHT, width=6)
        draw.rounded_rectangle([x0 + pad + 12, y0 + pad + 12, x1 - pad - 12, y1 - pad - 12], radius=38, outline=GOLD, width=2)
        hdraw.rounded_rectangle([x0 + pad, y0 + pad, x1 - pad, y1 - pad], radius=48, fill=165, outline=220, width=6)

        # Center micro rosette inside each yard
        ycx, ycy = (x0 + x1) // 2, (y0 + y1) // 2
        draw_persian_star(draw, ycx, ycy, 36, 16, points=8, fill=(235, 222, 194), outline=GOLD)

        # 4 Pawn pads (matching fractional coordinates +1.85, +4.15)
        for dx in (1.85, 4.15):
            for dy in (1.85, 4.15):
                px = int((yx + dx) * cell)
                py = int((yy + dy) * cell)
                draw.ellipse([px - 70, py - 70, px + 70, py + 70], fill=col_dark, outline=GOLD_BRIGHT, width=5)
                draw.ellipse([px - 58, py - 58, px + 58, py + 58], fill=col, outline=GOLD, width=3)
                draw.ellipse([px - 42, py - 42, px + 42, py + 42], fill=CREAM, outline=GOLD_BRIGHT, width=3)
                hdraw.ellipse([px - 66, py - 66, px + 66, py + 66], fill=210, outline=95, width=6)
                hdraw.ellipse([px - 40, py - 40, px + 40, py + 40], fill=145)

    # Center 3x3 Royal Shamsa Sanctuary (6..9, 6..9)
    cx0, cy0 = 6 * cell, 6 * cell
    cx1, cy1 = 9 * cell, 9 * cell
    cm_x, cm_y = (cx0 + cx1) // 2, (cy0 + cy1) // 2
    draw.polygon([(cx0, cy0), (cx0, cy1), (cm_x, cm_y)], fill=RED, outline=GOLD_BRIGHT)
    draw.polygon([(cx0, cy0), (cx1, cy0), (cm_x, cm_y)], fill=GREEN, outline=GOLD_BRIGHT)
    draw.polygon([(cx1, cy0), (cx1, cy1), (cm_x, cm_y)], fill=YELLOW, outline=GOLD_BRIGHT)
    draw.polygon([(cx0, cy1), (cx1, cy1), (cm_x, cm_y)], fill=BLUE, outline=GOLD_BRIGHT)
    draw.rectangle([cx0, cy0, cx1, cy1], outline=GOLD_BRIGHT, width=6)

    # Persian Shamsa (12-point golden medallion) in center
    draw.ellipse([cm_x - 84, cm_y - 84, cm_x + 84, cm_y + 84], fill=(44, 24, 14), outline=GOLD_BRIGHT, width=6)
    draw_persian_star(draw, cm_x, cm_y, 72, 36, points=12, fill=GOLD, outline=GOLD_BRIGHT)
    draw_persian_star(draw, cm_x, cm_y, 40, 18, points=12, fill=(148, 28, 34), outline=GOLD_BRIGHT)
    draw.ellipse([cm_x - 14, cm_y - 14, cm_x + 14, cm_y + 14], fill=GOLD_BRIGHT)
    hdraw.ellipse([cm_x - 82, cm_y - 82, cm_x + 82, cm_y + 82], fill=230, outline=90, width=6)

    # Outer gold trim
    draw.rectangle([3, 3, size - 4, size - 4], outline=GOLD_BRIGHT, width=8)

    out_path = os.path.join(TEX_DIR, "ludo_board.png")
    img.save(out_path, quality=95)
    norm = height_to_normal(himg.filter(ImageFilter.GaussianBlur(radius=0.8)), strength=2.6)
    norm_path = os.path.join(TEX_DIR, "ludo_board_normal.png")
    norm.save(norm_path)
    print(f"Saved {out_path} & {norm_path}")


def generate_backgammon_board_pbr():
    """
    Generates an ornate 1800x1980 portrait-proportioned inlaid Persian Backgammon
    surface (world 12.4 x 13.6) + matching normal map!
    """
    w, h = 1800, 1980
    img, hmap = generate_wood_pbr(w, h, base_rgb=(156, 110, 66), grain_rgb=(112, 72, 36), seed=99)
    draw = ImageDraw.Draw(img)
    hdraw = ImageDraw.Draw(hmap)

    gold = (222, 182, 94)
    gold_hi = (248, 220, 138)
    walnut_dark = (50, 24, 12)
    crimson = (138, 22, 30)
    crimson_in = (166, 36, 44)
    ivory = (210, 184, 138)
    ivory_in = (196, 168, 120)
    ebony = (34, 20, 14)
    ebony_in = (52, 34, 24)

    border = 38
    draw_khatam_border(draw, 0, 0, w - 1, h - 1, thickness=border)
    hdraw.rectangle([0, 0, w - 1, h - 1], outline=230, width=border)

    # Central walnut bar (116px wide -> ~0.80 world units)
    bar_w = 116
    bar_x0 = (w - bar_w) // 2
    bar_x1 = bar_x0 + bar_w
    draw.rectangle([bar_x0, border, bar_x1, h - border], fill=walnut_dark, outline=gold, width=4)
    hdraw.rectangle([bar_x0, border, bar_x1, h - border], fill=215, outline=85, width=4)

    # Gold Persian diamonds down the central bar
    for py in range(border + 130, h - border - 80, 240):
        cx = w // 2
        draw_persian_star(draw, cx, py, 28, 12, points=4, fill=gold_hi, outline=walnut_dark)

    left_w = bar_x0 - border
    right_w = (w - border) - bar_x1
    pt_h = int((h - 2 * border) * 0.415)

    for (hx0, hw) in [(border, left_w), (bar_x1, right_w)]:
        pw = hw / 6.0
        for i in range(6):
            x0 = hx0 + i * pw
            x1 = hx0 + (i + 1) * pw
            xm = (x0 + x1) * 0.5
            is_even = (i % 2 == 0)

            # Top triangle pointing down
            t_col = crimson if is_even else ivory
            t_in = crimson_in if is_even else ivory_in
            draw.polygon([(x0 + 3, border + 2), (x1 - 3, border + 2), (xm, border + pt_h)], fill=t_col, outline=gold_hi)
            draw.polygon([(x0 + 18, border + 2), (x1 - 18, border + 2), (xm, border + pt_h - 54)], fill=t_in, outline=gold)
            hdraw.polygon([(x0 + 3, border + 2), (x1 - 3, border + 2), (xm, border + pt_h)], fill=170, outline=90)

            # Bottom triangle pointing up
            b_col = ivory if is_even else ebony
            b_in = ivory_in if is_even else ebony_in
            draw.polygon([(x0 + 3, h - border - 2), (x1 - 3, h - border - 2), (xm, h - border - pt_h)], fill=b_col, outline=gold_hi)
            draw.polygon([(x0 + 18, h - border - 2), (x1 - 18, h - border - 2), (xm, h - border - pt_h + 54)], fill=b_in, outline=gold)
            hdraw.polygon([(x0 + 3, h - border - 2), (x1 - 3, h - border - 2), (xm, h - border - pt_h)], fill=170, outline=90)

    # Ornate Persian Shamsa rosettes in left & right midfields
    for cx in (border + left_w // 2, bar_x1 + right_w // 2):
        cy = h // 2
        draw.ellipse([cx - 82, cy - 82, cx + 82, cy + 82], outline=gold_hi, width=3)
        draw.ellipse([cx - 68, cy - 68, cx + 68, cy + 68], outline=gold, width=2)
        draw_persian_star(draw, cx, cy, 56, 26, points=12, fill=(198, 158, 80), outline=walnut_dark)
        draw_persian_star(draw, cx, cy, 26, 12, points=12, fill=crimson, outline=gold_hi)

    out_path = os.path.join(TEX_DIR, "backgammon_board.png")
    img.save(out_path, quality=95)
    norm = height_to_normal(hmap.filter(ImageFilter.GaussianBlur(radius=0.8)), strength=2.4)
    norm_path = os.path.join(TEX_DIR, "backgammon_board_normal.png")
    norm.save(norm_path)
    print(f"Saved {out_path} & {norm_path}")


def generate_walnut_and_carpet():
    albedo, hmap = generate_wood_pbr(1024, 1024, base_rgb=(88, 48, 22), grain_rgb=(38, 18, 8), seed=17)
    albedo.save(os.path.join(TEX_DIR, "walnut_wood.png"), quality=95)
    height_to_normal(hmap, strength=2.8).save(os.path.join(TEX_DIR, "walnut_normal.png"))
    # Roughness: darker pores rougher, smooth grain glossier
    rough = hmap.point(lambda p: clamp(190 - p * 0.55))
    rough.save(os.path.join(TEX_DIR, "walnut_roughness.png"))

    # Royal Persian Lounge Table Carpet/Felt backdrop (1024x1024 tileable feel)
    s = 1024
    carp = Image.new("RGB", (s, s), (42, 16, 18))
    cdraw = ImageDraw.Draw(carp)
    rng = random.Random(55)
    for _ in range(18000):
        x, y = rng.randint(0, s - 1), rng.randint(0, s - 1)
        cdraw.point((x, y), fill=(54, 22, 24) if rng.random() > 0.5 else (32, 11, 13))
    # Subtle woven diamond damask pattern
    step = 64
    for gy in range(0, s, step):
        for gx in range(0, s, step):
            cx, cy = gx + step // 2, gy + step // 2
            cdraw.polygon([(cx, cy - 22), (cx + 22, cy), (cx, cy + 22), (cx - 22, cy)], outline=(78, 36, 30))
            cdraw.polygon([(cx, cy - 10), (cx + 10, cy), (cx, cy + 10), (cx - 10, cy)], outline=(108, 72, 34))
    carp.filter(ImageFilter.GaussianBlur(radius=0.4)).save(os.path.join(TEX_DIR, "table_carpet.png"), quality=92)
    print("Saved walnut PBR maps & royal table carpet!")


def generate_glow_ring():
    size = 256
    img = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    px = img.load()
    c = size / 2.0
    for y in range(size):
        for x in range(size):
            d = math.hypot(x - c, y - c) / c
            ring_outer = math.exp(-((d - 0.78) ** 2) / 0.008)
            ring_inner = math.exp(-((d - 0.58) ** 2) / 0.012) * 0.55
            soft = math.exp(-(d ** 2) / 0.30) * 0.22
            a = clamp((ring_outer + ring_inner + soft) * 255)
            px[x, y] = (255, 244, 192, a)
    img.save(os.path.join(TEX_DIR, "glow_ring.png"))
    print("Saved glow_ring.png")


def write_wav(filename, samples, sample_rate=22050):
    path = os.path.join(AUD_DIR, filename)
    with wave.open(path, "w") as wf:
        wf.setnchannels(1)
        wf.setsampwidth(2)
        wf.setframerate(sample_rate)
        data = b"".join(struct.pack("<h", max(-32767, min(32767, int(s * 32767)))) for s in samples)
        wf.writeframes(data)


def ensure_audio():
    if os.path.exists(os.path.join(AUD_DIR, "win.wav")):
        return
    sr = 22050
    rng = random.Random(123)
    # Fallback regeneration if needed
    dur = 0.14
    n = int(sr * dur)
    write_wav("piece_move.wav", [math.sin(2 * math.pi * 340 * (i / sr)) * math.exp(-(i / sr) * 48) * 0.7 for i in range(n)], sr)


if __name__ == "__main__":
    generate_walnut_and_carpet()
    generate_ludo_board_pbr()
    generate_backgammon_board_pbr()
    generate_glow_ring()
    ensure_audio()
    print("All upgraded AAA PBR textures generated!")
