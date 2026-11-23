#!/usr/bin/env python3
"""Derive a nine-slice UI control kit from game/assets/ui/panel_dark.png."""

from pathlib import Path

from PIL import Image, ImageChops, ImageDraw, ImageFilter, ImageOps


ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "game/assets/ui/panel_dark.png"
OUT = ROOT / "game/assets/ui/controls"
PREVIEW = ROOT / "docs/screenshots/ui_2026-11-23/ui_controls_contact_sheet.png"

GOLD = (196, 145, 70, 255)
GOLD_BRIGHT = (232, 183, 94, 255)
GOLD_DIM = (126, 92, 44, 210)
INK = (22, 14, 11, 255)
PAPER = (232, 216, 182, 255)


def multiply(image: Image.Image, color: tuple[int, int, int]) -> Image.Image:
    layer = Image.new("RGBA", image.size, (*color, 255))
    return ImageChops.multiply(image, layer)


def alpha_color(image: Image.Image, color: tuple[int, int, int], alpha: int) -> Image.Image:
    tinted = multiply(image.convert("RGBA"), color)
    tinted.putalpha(alpha)
    return tinted


def wood_fill(size: tuple[int, int], brightness: int) -> Image.Image:
    fill = PANEL.crop((96, 96, 416, 416)).resize(size, Image.Resampling.LANCZOS)
    fill = multiply(fill, (brightness, brightness, brightness))
    gradient = Image.new("RGBA", size, (0, 0, 0, 0))
    draw = ImageDraw.Draw(gradient)
    for y in range(size[1]):
        t = y / max(1, size[1] - 1)
        alpha = int(24 * (1.0 - t) + 12)
        draw.line((0, y, size[0], y), fill=(255, 225, 178, alpha))
    return Image.alpha_composite(fill, gradient)


def ornament_mask(crop: Image.Image) -> Image.Image:
    mask = Image.new("L", crop.size, 0)
    src = crop.load()
    out = mask.load()
    for y in range(crop.height):
        for x in range(crop.width):
            r, g, b, a = src[x, y]
            warm = r + g + b
            if a > 0 and r > 58 and g > 34 and warm > 142 and r > g * 1.22:
                out[x, y] = min(255, int((warm - 120) * 1.65))
    return mask.filter(ImageFilter.GaussianBlur(0.35))


def corner_layers(size: int) -> tuple[Image.Image, Image.Image, Image.Image, Image.Image]:
    boxes = [
        (0, 0, 48, 48),
        (464, 0, 512, 48),
        (0, 464, 48, 512),
        (464, 464, 512, 512),
    ]
    result = []
    for box in boxes:
        crop = PANEL.crop(box)
        ornament = ImageOps.fit(crop, (size, size), Image.Resampling.LANCZOS)
        mask = ornament_mask(ornament)
        gold = multiply(ornament, (255, 218, 148))
        result.append((gold, mask))
    return result


def draw_corners(image: Image.Image, size: int) -> None:
    corners = corner_layers(size)
    positions = [
        (0, 0),
        (image.width - size, 0),
        (0, image.height - size),
        (image.width - size, image.height - size),
    ]
    for (gold, mask), pos in zip(corners, positions, strict=True):
        image.paste(gold, pos, mask)


def draw_border(draw: ImageDraw.ImageDraw, size: tuple[int, int], bright: bool = False) -> None:
    w, h = size
    outer = GOLD_BRIGHT if bright else GOLD
    inner = (222, 170, 82, 150 if bright else 112)
    draw.rectangle((0, 0, w - 1, h - 1), outline=(18, 10, 8, 230), width=1)
    draw.rectangle((1, 1, w - 2, h - 2), outline=outer, width=2)
    draw.rectangle((6, 6, w - 7, h - 7), outline=inner, width=1)
    draw.line((10, 3, w - 11, 3), fill=(255, 220, 150, 74 if bright else 40), width=1)


def make_button(name: str, primary: bool, state: str, size=(176, 72), corner=24) -> Image.Image:
    base = {
        "normal": (196, 190, 182),
        "hover": (224, 214, 200),
        "pressed": (151, 143, 136),
    }[state]
    image = wood_fill(size, 112)
    image = multiply(image, base)
    if primary:
        wash = Image.new("RGBA", size, (116, 40, 28, 0))
        alpha = 92 if state != "pressed" else 112
        wash.putalpha(alpha)
        image = Image.alpha_composite(image, wash)
    if state == "hover":
        glow = Image.new("RGBA", size, (0, 0, 0, 0))
        ImageDraw.Draw(glow).rectangle(
            (0, 0, size[0] - 1, size[1] - 1), outline=(245, 190, 92, 50), width=4
        )
        image = Image.alpha_composite(image, glow.filter(ImageFilter.GaussianBlur(3)))
    if state == "pressed":
        shade = Image.new("RGBA", size, (0, 0, 0, 0))
        draw = ImageDraw.Draw(shade)
        draw.rectangle((0, 0, size[0], 13), fill=(0, 0, 0, 74))
        image = Image.alpha_composite(image, shade)
    draw = ImageDraw.Draw(image)
    draw_border(draw, size, bright=state == "hover")
    draw_corners(image, corner)
    if primary:
        draw.line((12, size[1] - 7, size[0] - 13, size[1] - 7), fill=(224, 150, 90, 74), width=1)
    image.save(OUT / name)
    return image


def make_slider_track() -> None:
    size = (64, 16)
    image = Image.new("RGBA", size, (0, 0, 0, 0))
    draw = ImageDraw.Draw(image)
    draw.rounded_rectangle((1, 2, 62, 13), radius=4, fill=(14, 8, 6, 246), outline=(119, 85, 38, 240))
    draw.line((4, 3, 60, 3), fill=(232, 176, 88, 104))
    draw.line((4, 12, 60, 12), fill=(0, 0, 0, 150))
    image.save(OUT / "slider_track.png")


def make_slider_fill() -> None:
    size = (64, 16)
    image = Image.new("RGBA", size, (0, 0, 0, 0))
    draw = ImageDraw.Draw(image)
    draw.rounded_rectangle((1, 2, 62, 13), radius=4, fill=(151, 104, 39, 250), outline=(238, 187, 94, 250))
    draw.line((4, 3, 60, 3), fill=(255, 226, 154, 205))
    draw.line((4, 12, 60, 12), fill=(91, 55, 21, 190))
    image.save(OUT / "slider_fill.png")


def make_grabber(name: str, hover: bool) -> None:
    size = (24, 24)
    image = Image.new("RGBA", size, (0, 0, 0, 0))
    draw = ImageDraw.Draw(image)
    if hover:
        draw.ellipse((1, 1, 22, 22), fill=(238, 178, 74, 42))
    points = [(12, 1), (23, 12), (12, 23), (1, 12)]
    draw.polygon(points, fill=(42, 23, 18, 255), outline=(245, 206, 123, 255))
    points_inner = [(12, 5), (19, 12), (12, 19), (5, 12)]
    draw.polygon(points_inner, fill=(176, 120, 45, 255), outline=(85, 49, 19, 255))
    draw.ellipse((10, 10, 14, 14), fill=(255, 231, 170, 255))
    image.save(OUT / name)


def make_check(name: str, checked: bool) -> None:
    size = (52, 28)
    image = Image.new("RGBA", size, (0, 0, 0, 0))
    draw = ImageDraw.Draw(image)
    fill = (92, 35, 26, 255) if checked else (25, 16, 13, 245)
    outline = GOLD_BRIGHT if checked else (118, 89, 43, 235)
    draw.rounded_rectangle((1, 3, 50, 24), radius=11, fill=fill, outline=outline, width=2)
    draw.rounded_rectangle((5, 6, 46, 21), radius=8, outline=(245, 203, 124, 42), width=1)
    cx = 38 if checked else 14
    draw.ellipse((cx - 8, 6, cx + 8, 22), fill=(226, 205, 164, 255), outline=(92, 61, 26, 255))
    draw.ellipse((cx - 5, 8, cx + 3, 16), fill=(255, 241, 207, 220))
    if checked:
        draw.line((7, 14, 16, 14), fill=(240, 179, 83, 200), width=2)
    image.save(OUT / name)


def make_arrow() -> None:
    size = (18, 12)
    image = Image.new("RGBA", size, (0, 0, 0, 0))
    draw = ImageDraw.Draw(image)
    draw.polygon([(2, 2), (16, 2), (9, 10)], fill=(224, 178, 94, 255), outline=(62, 36, 17, 255))
    draw.line((5, 3, 13, 3), fill=(255, 230, 170, 170))
    image.save(OUT / "option_arrow.png")


def make_popup(name: str, hover: bool = False, size=(112, 112)) -> None:
    if hover:
        image = Image.new("RGBA", size, (0, 0, 0, 0))
        draw = ImageDraw.Draw(image)
        draw.rectangle((1, 1, size[0] - 2, size[1] - 2), fill=(139, 88, 35, 92))
        draw.line((3, size[1] // 2, 3, size[1] // 2), fill=GOLD_BRIGHT, width=2)
        image.save(OUT / name)
        return
    image = wood_fill(size, 90)
    image = multiply(image, (174, 168, 160))
    draw_border(ImageDraw.Draw(image), size, bright=False)
    draw_corners(image, 26)
    image.save(OUT / name)


def make_tooltip() -> None:
    size = (96, 64)
    image = wood_fill(size, 82)
    image.putalpha(242)
    draw = ImageDraw.Draw(image)
    draw.rectangle((0, 0, size[0] - 1, size[1] - 1), outline=(23, 12, 9, 255), width=1)
    draw.rectangle((1, 1, size[0] - 2, size[1] - 2), outline=(143, 107, 51, 220), width=1)
    draw.rectangle((5, 5, size[0] - 6, size[1] - 6), outline=(218, 165, 82, 54), width=1)
    image.save(OUT / "tooltip.png")


def make_scroll() -> None:
    track = Image.new("RGBA", (12, 64), (0, 0, 0, 0))
    draw = ImageDraw.Draw(track)
    draw.rounded_rectangle((1, 1, 10, 62), radius=3, fill=(20, 12, 10, 220), outline=(89, 64, 30, 210))
    track.save(OUT / "scroll_track.png")
    grabber = Image.new("RGBA", (12, 48), (0, 0, 0, 0))
    draw = ImageDraw.Draw(grabber)
    draw.rounded_rectangle((1, 1, 10, 46), radius=4, fill=(132, 90, 38, 255), outline=(224, 174, 88, 235))
    draw.line((4, 5, 4, 42), fill=(255, 220, 144, 120))
    grabber.save(OUT / "scroll_grabber.png")


def make_contact_sheet(images: list[tuple[str, Image.Image]]) -> None:
    scale = 2
    cell_w, cell_h = 400, 130
    cols = 3
    rows = (len(images) + cols - 1) // cols
    sheet = Image.new("RGBA", (cols * cell_w, rows * cell_h + 60), (23, 17, 13, 255))
    draw = ImageDraw.Draw(sheet)
    draw.text((24, 18), "UI controls derived from panel_dark.png", fill=PAPER)
    for index, (label, image) in enumerate(images):
        col = index % cols
        row = index // cols
        x = col * cell_w + 22
        y = row * cell_h + 58
        preview = image.resize((image.width * scale, image.height * scale), Image.Resampling.NEAREST)
        if preview.width > 350:
            preview.thumbnail((350, 86), Image.Resampling.NEAREST)
        sheet.alpha_composite(preview, (x, y))
        draw.text((x, y + 88), label, fill=(176, 151, 108, 255))
    sheet.convert("RGB").save(PREVIEW)


def main() -> None:
    global PANEL
    PANEL = Image.open(SOURCE).convert("RGBA")
    OUT.mkdir(parents=True, exist_ok=True)
    previews = []
    for state in ("normal", "hover", "pressed"):
        image = make_button(f"button_{state}.png", False, state)
        previews.append((f"button_{state}", image))
    for state in ("normal", "hover", "pressed"):
        image = make_button(f"button_primary_{state}.png", True, state)
        previews.append((f"button_primary_{state}", image))
    for state in ("normal", "hover", "pressed"):
        image = make_button(
            f"button_compact_{state}.png", False, state, size=(144, 48), corner=16
        )
        previews.append((f"button_compact_{state}", image))
    make_slider_track()
    make_slider_fill()
    make_grabber("slider_grabber.png", False)
    make_grabber("slider_grabber_hover.png", True)
    make_check("check_off.png", False)
    make_check("check_on.png", True)
    make_arrow()
    make_popup("popup_panel.png")
    make_popup("popup_hover.png", hover=True, size=(96, 28))
    make_tooltip()
    make_scroll()
    for name in (
        "slider_track",
        "slider_fill",
        "slider_grabber",
        "slider_grabber_hover",
        "check_off",
        "check_on",
        "option_arrow",
        "popup_panel",
        "popup_hover",
        "tooltip",
        "scroll_track",
        "scroll_grabber",
    ):
        previews.append((name, Image.open(OUT / f"{name}.png").convert("RGBA")))
    make_contact_sheet(previews)


if __name__ == "__main__":
    main()
