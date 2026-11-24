#!/usr/bin/env python3
"""GUI kit for WATCH · YONGCHANG — lacquer-and-gold pixel controls.

Every control is a 9-slice texture consumed by
``game/scripts/ui/ui_control_theme.gd``. All ornament is kept inside the
corner patches (24px / 16px) and the 1px edge bands so stretching the centre
never smears fine detail.

Run from the project root:
    python3 pixel-art/ui_kit/build.py
"""

from __future__ import annotations

from pathlib import Path

from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "game" / "assets" / "ui" / "controls"
PREVIEW = Path(__file__).resolve().parent / "preview.png"

INK = "#0a0c0e"
INK_SOFT = "#1a1109"
GOLD_L = "#e9c274"
GOLD = "#b9853f"
GOLD_D = "#6d491f"
GOLD_DD = "#3d2a12"
LACQ = "#241a14"
LACQ_D = "#140d0a"
LACQ_L = "#33241a"
RED = "#8d3028"
RED_D = "#5a1c19"
RED_L = "#b8463a"
IVORY = "#e7e2d4"
IVORY_L = "#f8f2e3"
IVORY_D = "#b3a68c"


def chamfer(w: int, h: int, cut: int, inset: int = 0) -> list[tuple[int, int]]:
    x0, y0, x1, y1 = inset, inset, w - 1 - inset, h - 1 - inset
    c = max(1, cut - inset)
    return [
        (x0 + c, y0), (x1 - c, y0), (x1, y0 + c), (x1, y1 - c),
        (x1 - c, y1), (x0 + c, y1), (x0, y1 - c), (x0, y0 + c),
    ]


def layer(draw: ImageDraw.ImageDraw, w: int, h: int, cut: int, inset: int, color: str) -> None:
    draw.polygon(chamfer(w, h, cut, inset), fill=color)


def corner_stud(draw: ImageDraw.ImageDraw, x: int, y: int, color: str = GOLD_L) -> None:
    """Tiny three-pixel diamond stud used on every frame corner."""
    draw.point([(x, y - 1), (x - 1, y), (x + 1, y), (x, y + 1)], fill=color)
    draw.point((x, y), fill=IVORY)


def corner_bracket(draw: ImageDraw.ImageDraw, x: int, y: int, sx: int, sy: int, color: str) -> None:
    """L-shaped flourish that hugs one corner; sx/sy point inward."""
    draw.line([(x, y + sy * 5), (x, y), (x + sx * 5, y)], fill=color)
    draw.line([(x + sx * 2, y + sy * 2), (x + sx * 2, y + sy * 7)], fill=color)
    draw.line([(x + sx * 2, y + sy * 2), (x + sx * 7, y + sy * 2)], fill=color)


def frame(
    draw: ImageDraw.ImageDraw,
    w: int,
    h: int,
    cut: int,
    field: str,
    gold_mid: str = GOLD,
    gold_lit: str = GOLD_L,
    gold_dark: str = GOLD_D,
    brackets: bool = True,
) -> None:
    layer(draw, w, h, cut, 0, INK)
    layer(draw, w, h, cut, 1, gold_mid)
    layer(draw, w, h, cut, 2, gold_mid)
    layer(draw, w, h, cut, 3, gold_dark)
    layer(draw, w, h, cut, 4, INK_SOFT)
    layer(draw, w, h, cut, 5, field)
    # Carved bevel: lit on the top/left, deep on the bottom/right.
    draw.line([(cut + 1, 1), (w - 1 - cut, 1)], fill=gold_lit)
    draw.line([(1, cut + 1), (1, h - 1 - cut)], fill=gold_lit)
    draw.line([(cut + 1, 2), (w - 1 - cut, 2)], fill=gold_lit)
    draw.line([(2, cut + 1), (2, h - 1 - cut)], fill=gold_lit)
    draw.line([(cut + 1, h - 2), (w - 1 - cut, h - 2)], fill=INK)
    draw.line([(w - 2, cut + 1), (w - 2, h - 1 - cut)], fill=INK)
    draw.line([(cut + 1, h - 3), (w - 1 - cut, h - 3)], fill=gold_dark)
    draw.line([(w - 3, cut + 1), (w - 3, h - 1 - cut)], fill=gold_dark)
    if brackets:
        for x, y, sx, sy in (
            (6, 6, 1, 1), (w - 7, 6, -1, 1),
            (6, h - 7, 1, -1), (w - 7, h - 7, -1, -1),
        ):
            corner_bracket(draw, x, y, sx, sy, GOLD)
            corner_stud(draw, x + sx * 9, y + sy * 9)


def button(w: int, h: int, cut: int, field: str, hover: bool, pressed: bool,
           primary: bool = False) -> Image.Image:
    im = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    # Compact rows (OptionButton, small back keys) stay clean: no corner
    # flourishes or centre ridge, which would crowd the label at 48px.
    ornate = h >= 64
    if pressed:
        body = RED_D if primary else LACQ_D
        frame(d, w, h, cut, body, GOLD_D, GOLD, GOLD_DD, brackets=ornate)
    elif hover:
        body = RED_L if primary else LACQ_L
        frame(d, w, h, cut, body, GOLD_L, IVORY_L, GOLD, brackets=ornate)
        # inner warm hairline sells the lift
        d.polygon(chamfer(w, h, cut, 8), outline=GOLD)
    else:
        body = RED if primary else LACQ
        frame(d, w, h, cut, body, brackets=ornate)
    # Fields need a little grain; keep it in flat rows so it stretches safely.
    if primary:
        d.line([(cut + 4, 4), (w - 5 - cut, 4)], fill=RED_L if not pressed else RED)
        d.line([(cut + 4, h - 5), (w - 5 - cut, h - 5)], fill=RED_D if not pressed else GOLD_DD)
    else:
        d.line([(cut + 4, 5), (w - 5 - cut, 5)], fill=LACQ_L if not pressed else LACQ_D)
        d.line([(cut + 4, h - 6), (w - 5 - cut, h - 6)], fill=INK_SOFT)
    # Centre ridge stud, a small nod to the door-knocker hardware on the gate.
    cx = w // 2
    if w >= 140 and h >= 64:
        d.line([(cx - 14, h - 12), (cx + 14, h - 12)], fill=GOLD_DD if not hover else GOLD_D)
        d.line([(cx - 7, h - 12), (cx - 7, h - 10)], fill=GOLD_DD)
        d.line([(cx + 7, h - 12), (cx + 7, h - 10)], fill=GOLD_DD)
    return im


def save(name: str, im: Image.Image) -> None:
    im.save(OUT / name, optimize=True)
    print(f"saved {name} {im.width}x{im.height}")


def build_buttons() -> list[Image.Image]:
    made = []
    for w, h, cut, prefix in ((176, 72, 6, "button"), (144, 48, 5, "button_compact")):
        for state, hover, pressed in (
            ("normal", False, False), ("hover", True, False), ("pressed", False, True),
        ):
            im = button(w, h, cut, LACQ, hover, pressed, primary=False)
            save(f"{prefix}_{state}.png", im)
            made.append(im)
    for state, hover, pressed in (
        ("normal", False, False), ("hover", True, False), ("pressed", False, True),
    ):
        im = button(176, 72, 6, RED, hover, pressed, primary=True)
        save(f"button_primary_{state}.png", im)
        made.append(im)
    return made


def build_popup() -> list[Image.Image]:
    made = []
    w = h = 112
    im = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    frame(d, w, h, 8, LACQ_D, brackets=False)
    for x, y, sx, sy in ((14, 14, 1, 1), (w - 15, 14, -1, 1),
                         (14, h - 15, 1, -1), (w - 15, h - 15, -1, -1)):
        corner_bracket(d, x, y, sx, sy, GOLD)
        corner_stud(d, x + sx * 7, y + sy * 7)
    save("popup_panel.png", im)
    made.append(im)

    im = Image.new("RGBA", (96, 28), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    d.polygon(chamfer(96, 28, 4), fill=GOLD_D)
    d.polygon(chamfer(96, 28, 4, 1), fill=LACQ_L)
    d.line([(5, 1), (90, 1)], fill=GOLD)
    d.line([(1, 5), (1, 22)], fill=GOLD)
    d.line([(5, 26), (90, 26)], fill=INK)
    save("popup_hover.png", im)
    made.append(im)
    return made


def build_tooltip() -> list[Image.Image]:
    w, h = 96, 64
    im = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    d.polygon(chamfer(w, h, 6), fill=(10, 12, 14, 236))
    d.polygon(chamfer(w, h, 6, 1), fill=(26, 20, 15, 224))
    d.line([(6, 1), (w - 7, 1)], fill=GOLD_D)
    d.line([(1, 6), (1, h - 7)], fill=GOLD_D)
    d.line([(6, h - 2), (w - 7, h - 2)], fill=INK)
    for x, y in ((5, 5), (w - 6, 5), (5, h - 6), (w - 6, h - 6)):
        d.point((x, y), fill=GOLD)
    save("tooltip.png", im)
    return [im]


def build_toggle() -> list[Image.Image]:
    made = []
    for on in (True, False):
        w, h = 52, 28
        im = Image.new("RGBA", (w, h), (0, 0, 0, 0))
        d = ImageDraw.Draw(im)
        track = RED_D if on else LACQ_D
        d.rounded_rectangle([0, 3, w - 1, h - 4], radius=11, fill=INK)
        d.rounded_rectangle([1, 4, w - 2, h - 5], radius=10, fill=track)
        d.rounded_rectangle([2, 5, w - 3, h - 6], radius=9,
                            outline=GOLD if on else GOLD_D)
        # recessed groove
        d.line([(8, 8), (w - 9, 8)], fill=INK if on else INK_SOFT)
        knob_x = w - 15 if on else 6
        d.ellipse([knob_x, 5, knob_x + 17, 22], fill=INK)
        d.ellipse([knob_x + 1, 6, knob_x + 16, 21],
                  fill=IVORY if on else IVORY_D)
        d.arc([knob_x + 2, 7, knob_x + 15, 20], 180, 300, fill=IVORY_L)
        d.point((knob_x + 8, 13), fill=GOLD if on else IVORY_D)
        save("check_on.png" if on else "check_off.png", im)
        made.append(im)
    return made


def build_slider() -> list[Image.Image]:
    made = []
    w, h = 64, 16
    im = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    d.rounded_rectangle([0, 4, w - 1, h - 5], radius=3, fill=INK)
    d.rounded_rectangle([1, 5, w - 2, h - 6], radius=2, fill=LACQ_D)
    d.line([(1, h - 6), (w - 2, h - 6)], fill=GOLD_DD)
    d.line([(1, 5), (w - 2, 5)], fill=INK)
    save("slider_track.png", im)
    made.append(im)

    im = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    d.rounded_rectangle([0, 4, w - 1, h - 5], radius=3, fill=GOLD_D)
    d.rounded_rectangle([1, 5, w - 2, h - 6], radius=2, fill=GOLD)
    d.line([(1, 6), (w - 2, 6)], fill=GOLD_L)
    d.line([(1, h - 7), (w - 2, h - 7)], fill=GOLD_D)
    save("slider_fill.png", im)
    made.append(im)

    for name, lit in (("slider_grabber.png", False), ("slider_grabber_hover.png", True)):
        im = Image.new("RGBA", (24, 24), (0, 0, 0, 0))
        d = ImageDraw.Draw(im)
        d.ellipse([0, 0, 23, 23], fill=INK)
        d.ellipse([1, 1, 22, 22], fill=GOLD_D)
        d.ellipse([2, 2, 21, 21], fill=IVORY if lit else IVORY_D)
        d.arc([3, 3, 20, 20], 190, 330, fill=IVORY_L)
        d.ellipse([9, 9, 14, 14], fill=GOLD if lit else GOLD_D)
        d.point((11, 11), fill=INK)
        save(name, im)
        made.append(im)
    return made


def build_scroll() -> list[Image.Image]:
    made = []
    im = Image.new("RGBA", (12, 64), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    d.rectangle([2, 0, 9, 63], fill=INK)
    d.rectangle([3, 1, 8, 62], fill=LACQ_D)
    d.line([(3, 1), (3, 62)], fill=INK_SOFT)
    save("scroll_track.png", im)
    made.append(im)

    im = Image.new("RGBA", (12, 48), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    d.rounded_rectangle([1, 0, 10, 47], radius=4, fill=INK)
    d.rounded_rectangle([2, 1, 9, 46], radius=3, fill=GOLD)
    d.line([(3, 3), (3, 44)], fill=GOLD_L)
    d.line([(8, 3), (8, 44)], fill=GOLD_D)
    for y in range(10, 40, 8):
        d.line([(4, y), (7, y)], fill=GOLD_DD)
    save("scroll_grabber.png", im)
    made.append(im)
    return made


def build_arrow() -> list[Image.Image]:
    im = Image.new("RGBA", (18, 12), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    for i in range(5):
        d.line([(5 + i, 3 + i), (13 - i, 3 + i)], fill=INK)
        d.point((5 + i, 2 + i), fill=INK)
        d.point((13 - i, 2 + i), fill=INK)
    for i in range(4):
        d.line([(6 + i, 3 + i), (12 - i, 3 + i)], fill=GOLD_L)
    save("option_arrow.png", im)
    return [im]


def build_preview(parts: list[Image.Image]) -> None:
    big = parts[:9]
    small = parts[9:]
    sheet = Image.new("RGBA", (900, 40 + 3 * 82 + 140), (22, 24, 26, 255))
    for index, im in enumerate(big):
        col, row = index % 3, index // 3
        sheet.alpha_composite(im, (12 + col * 290, 12 + row * 82))
    y = 12 + 3 * 82 + 8
    x = 12
    for im in small:
        scaled = im.resize((im.width * 3, im.height * 3), Image.NEAREST)
        if x + scaled.width > 880:
            x, y = 12, y + scaled.height + 10
        sheet.alpha_composite(scaled, (x, y))
        x += scaled.width + 14
    sheet.save(PREVIEW)
    print(f"preview -> {PREVIEW.relative_to(ROOT)}")


def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    parts: list[Image.Image] = []
    parts += build_buttons()
    parts += build_popup()
    parts += build_tooltip()
    parts += build_toggle()
    parts += build_slider()
    parts += build_scroll()
    parts += build_arrow()
    build_preview(parts)


if __name__ == "__main__":
    main()
