"""Cut out overhead roof sprites from the generated source atlas.

Source: OpenAI ImageGen output. The source image remains intact in source/.
Outputs are derived transparent PNG sprites for Godot runtime placement.
"""
from pathlib import Path
from collections import deque
import hashlib
import json
from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
SOURCE = Path(__file__).parent / "source" / "roof_atlas.png"
OUTPUT = ROOT / "game/assets/tiles/buildings"
CELLS = {
    "house": (55, 185, 355, 445),
    "hall": (445, 95, 970, 500),
    "shop": (1040, 155, 1480, 495),
    "watchtower": (45, 600, 335, 915),
    "gatehouse": (385, 575, 985, 965),
    "warehouse": (960, 620, 1520, 910),
}
TOWER_NAMES = ["watchtower", "arrow_tower", "dragon_tower"]


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for block in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest()


def remove_connected_background(image: Image.Image) -> Image.Image:
    image = image.convert("RGBA")
    px = image.load()
    w, h = image.size
    seen = bytearray(w * h)
    queue = deque()

    def is_bg(x: int, y: int) -> bool:
        r, g, b, _ = px[x, y]
        # Remove the generated pale checkerboard while keeping outlined stonework.
        return min(r, g, b) > 218 and max(r, g, b) - min(r, g, b) < 22

    for x in range(w):
        for y in (0, h - 1):
            if is_bg(x, y):
                queue.append((x, y))
    for y in range(h):
        for x in (0, w - 1):
            if is_bg(x, y):
                queue.append((x, y))
    while queue:
        x, y = queue.popleft()
        idx = y * w + x
        if seen[idx] or not is_bg(x, y):
            continue
        seen[idx] = 1
        px[x, y] = (0, 0, 0, 0)
        if x: queue.append((x - 1, y))
        if x + 1 < w: queue.append((x + 1, y))
        if y: queue.append((x, y - 1))
        if y + 1 < h: queue.append((x, y + 1))
    return image


def main() -> None:
    OUTPUT.mkdir(parents=True, exist_ok=True)
    atlas = remove_connected_background(Image.open(SOURCE))
    for name, bounds in CELLS.items():
        # Image generators may let an oversized sprite cross nominal atlas cells.
        # Explicit bounds keep each full roof and exclude its neighbor.
        cell = atlas.crop(bounds)
        bounds = cell.getchannel("A").getbbox()
        if not bounds:
            raise RuntimeError(f"empty generated cell: {name}")
        sprite = cell.crop(bounds)
        sprite.save(OUTPUT / f"{name}.png", optimize=True)
        print(name, sprite.size)

    tower_source = remove_connected_background(Image.open(Path(__file__).parent / "source" / "towers_atlas.png"))
    tower_out = ROOT / "game/assets/units/towers"
    tower_out.mkdir(parents=True, exist_ok=True)
    for index, name in enumerate(TOWER_NAMES):
        x0 = round(index * tower_source.width / 3) + 12
        x1 = round((index + 1) * tower_source.width / 3) - 12
        cell = tower_source.crop((x0, 12, x1, tower_source.height - 12))
        bounds = cell.getchannel("A").getbbox()
        if not bounds:
            raise RuntimeError(f"empty generated tower cell: {name}")
        content = cell.crop(bounds)
        factor = min(158 / content.width, 158 / content.height)
        fitted = content.resize(
            (max(1, round(content.width * factor)), max(1, round(content.height * factor))),
            Image.Resampling.NEAREST,
        )
        sprite = Image.new("RGBA", (168, 168), (0, 0, 0, 0))
        sprite.alpha_composite(fitted, ((168 - fitted.width) // 2, 163 - fitted.height))
        sprite.save(tower_out / f"{name}.png", optimize=True)
        sprite.save(tower_out / f"{name}.webp", "WEBP", lossless=True, method=6)
        print(name, sprite.size)

    inputs = [SOURCE, Path(__file__).parent / "source" / "towers_atlas.png", Path(__file__).parent / "source" / "coast_atlas.png"]
    outputs = sorted(OUTPUT.glob("*.png")) + [tower_out / f"{name}.{ext}" for name in TOWER_NAMES for ext in ("png", "webp")]
    manifest = {
        "license": "CC BY 4.0",
        "generator": "OpenAI ImageGen; pixel-art/overhead_buildings/build.py",
        "inputs": [{"path": str(path.relative_to(ROOT)), "sha256": sha256(path)} for path in inputs],
        "outputs": [{"path": str(path.relative_to(ROOT)), "sha256": sha256(path), "bytes": path.stat().st_size} for path in outputs],
    }
    (Path(__file__).parent / "manifest.json").write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


if __name__ == "__main__":
    main()
