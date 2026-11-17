#!/usr/bin/env python3
"""
Generates high-craft 9-slice mobile game UI textures (glossy 3D beveled buttons,
luxury Persian dark-walnut gradient cards, gold-trimmed active panels, dice chips).
"""

import os
from PIL import Image, ImageDraw, ImageFilter

BASE_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
UI_DIR = os.path.join(BASE_DIR, "assets", "ui")
os.makedirs(UI_DIR, exist_ok=True)


def lerp_col(c1, c2, t):
    return tuple(int(c1[i] + (c2[i] - c1[i]) * t) for i in range(len(c1)))


def make_glossy_button(filename, top_col, bot_col, lip_col, border_col, highlight_alpha=72, pressed=False):
    """Creates a crisp 160x72 9-slice tactile 3D glossy mobile button."""
    w, h = 160, 72
    r = 18
    lip = 2 if pressed else 6
    y_shift = 4 if pressed else 0

    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))

    # 1. Soft drop shadow underneath
    shadow = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    sdraw = ImageDraw.Draw(shadow)
    sdraw.rounded_rectangle([4, 6 + y_shift, w - 4, h - 1], radius=r, fill=(0, 0, 0, 125))
    shadow = shadow.filter(ImageFilter.GaussianBlur(radius=3))
    img = Image.alpha_composite(img, shadow)

    # 2. 3D Bottom Lip / Extrusion
    draw = ImageDraw.Draw(img)
    draw.rounded_rectangle([3, 3 + y_shift, w - 3, h - 3], radius=r, fill=lip_col + (255,), outline=border_col + (255,), width=2)

    # 3. Main Vertical Gradient Face
    face_h = h - 6 - lip
    grad = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    gpx = grad.load()
    for y in range(3 + y_shift, 3 + y_shift + face_h):
        t = (y - (3 + y_shift)) / max(1, face_h - 1)
        col = lerp_col(top_col, bot_col, t) + (255,)
        for x in range(3, w - 3):
            gpx[x, y] = col

    # Mask gradient to rounded face
    mask = Image.new("L", (w, h), 0)
    mdraw = ImageDraw.Draw(mask)
    mdraw.rounded_rectangle([4, 4 + y_shift, w - 4, 3 + y_shift + face_h], radius=r - 1, fill=255)
    img.paste(grad, (0, 0), mask)

    # 4. Top Gloss Specular Reflection Band
    gloss = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    gdraw = ImageDraw.Draw(gloss)
    gloss_h = int(face_h * 0.46)
    gdraw.rounded_rectangle(
        [7, 6 + y_shift, w - 7, 6 + y_shift + gloss_h],
        radius=r - 4,
        fill=(255, 252, 240, highlight_alpha),
    )
    img = Image.alpha_composite(img, gloss)

    # 5. Crisp Inner Highlight Rim & Outer Gold/Accent Border
    draw = ImageDraw.Draw(img)
    draw.rounded_rectangle([5, 5 + y_shift, w - 5, 3 + y_shift + face_h], radius=r - 2, outline=(255, 245, 210, 88), width=1)
    draw.rounded_rectangle([3, 3 + y_shift, w - 3, h - 3], radius=r, outline=border_col + (255,), width=2)

    out = os.path.join(UI_DIR, filename)
    img.save(out)


def make_luxury_panel(filename, top_col, bot_col, border_col, inner_line_col, radius=20):
    """Creates a rich 160x160 9-slice dark Persian glass/leather gradient panel."""
    w, h = 160, 160
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))

    # Gradient body
    grad = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    gpx = grad.load()
    for y in range(h):
        t = y / (h - 1)
        col = lerp_col(top_col, bot_col, t)
        for x in range(w):
            gpx[x, y] = col

    mask = Image.new("L", (w, h), 0)
    mdraw = ImageDraw.Draw(mask)
    mdraw.rounded_rectangle([2, 2, w - 3, h - 3], radius=radius, fill=255)
    img.paste(grad, (0, 0), mask)

    # Subtle top warm sheen
    sheen = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    sdraw = ImageDraw.Draw(sheen)
    sdraw.rounded_rectangle([6, 5, w - 7, 36], radius=radius - 4, fill=(255, 232, 175, 18))
    img = Image.alpha_composite(img, sheen)

    # Outer border + delicate inner filigree hairline
    draw = ImageDraw.Draw(img)
    draw.rounded_rectangle([2, 2, w - 3, h - 3], radius=radius, outline=border_col, width=2)
    draw.rounded_rectangle([6, 6, w - 7, h - 7], radius=radius - 3, outline=inner_line_col, width=1)

    out = os.path.join(UI_DIR, filename)
    img.save(out)


def main():
    # Gold Primary Button (Roll Dice, Active Tabs)
    make_glossy_button("btn_gold.png", (236, 188, 72), (176, 124, 28), (112, 74, 14), (252, 224, 134), 82, False)
    make_glossy_button("btn_gold_hover.png", (250, 206, 92), (196, 142, 38), (124, 82, 18), (255, 240, 170), 96, False)
    make_glossy_button("btn_gold_pressed.png", (196, 148, 46), (146, 98, 20), (96, 60, 12), (250, 218, 120), 42, True)

    # Royal Emerald Button (Start Backgammon, Send Chat, Save)
    make_glossy_button("btn_emerald.png", (38, 168, 124), (16, 110, 82), (8, 66, 48), (142, 234, 194), 70, False)
    make_glossy_button("btn_emerald_hover.png", (52, 190, 142), (24, 128, 96), (10, 76, 56), (186, 250, 220), 86, False)
    make_glossy_button("btn_emerald_pressed.png", (24, 128, 94), (12, 86, 64), (8, 54, 40), (132, 218, 182), 36, True)

    # Royal Ruby Crimson Button (Start Mench)
    make_glossy_button("btn_crimson.png", (214, 58, 72), (146, 24, 38), (88, 12, 22), (250, 184, 124), 72, False)
    make_glossy_button("btn_crimson_hover.png", (234, 76, 88), (168, 34, 48), (100, 16, 26), (255, 214, 158), 88, False)
    make_glossy_button("btn_crimson_pressed.png", (174, 38, 52), (118, 18, 30), (74, 10, 18), (235, 165, 110), 38, True)

    # Dark Walnut Luxury Secondary Button (Top bar icons, Back, Undo, Nav inactive)
    make_glossy_button("btn_dark.png", (64, 44, 32), (38, 25, 18), (20, 12, 8), (168, 132, 68), 38, False)
    make_glossy_button("btn_dark_hover.png", (86, 60, 42), (52, 34, 24), (26, 16, 11), (228, 188, 98), 52, False)
    make_glossy_button("btn_dark_pressed.png", (46, 30, 22), (28, 18, 12), (16, 10, 7), (210, 172, 88), 22, True)

    # Luxury Panels & Cards
    make_luxury_panel("panel_glass.png", (38, 25, 18, 232), (20, 13, 9, 242), (176, 138, 68, 235), (242, 206, 120, 52), 20)
    make_luxury_panel("panel_card.png", (48, 32, 22, 242), (26, 17, 12, 248), (208, 168, 84, 245), (255, 224, 140, 68), 22)
    make_luxury_panel("panel_active.png", (68, 46, 24, 248), (38, 24, 14, 250), (252, 216, 116, 255), (255, 238, 170, 110), 18)

    print("All luxury 9-slice UI textures generated in", UI_DIR)


if __name__ == "__main__":
    main()
