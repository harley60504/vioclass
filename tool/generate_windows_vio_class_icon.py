#!/usr/bin/env python3
"""Generate the Windows launcher icon from the shared VioClass SVG asset.

Usage from repo root:

    python tool/generate_windows_vio_class_icon.py

Optional dependency install:

    python -m pip install cairosvg pillow

The script keeps Windows using the same source artwork as Android:
- source: assets/app/vio_class_icon.svg
- output: windows/runner/resources/app_icon.ico
"""

from __future__ import annotations

import sys
import tempfile
from pathlib import Path


def main() -> int:
    repo_root = Path(__file__).resolve().parents[1]
    source_svg = repo_root / "assets" / "app" / "vio_class_icon.svg"
    output_ico = repo_root / "windows" / "runner" / "resources" / "app_icon.ico"

    if not source_svg.exists():
        print(f"ERROR: source SVG not found: {source_svg}", file=sys.stderr)
        return 1

    try:
        import cairosvg  # type: ignore
        from PIL import Image  # type: ignore
    except ImportError:
        print(
            "ERROR: missing dependencies. Install them with:\n"
            "  python -m pip install cairosvg pillow",
            file=sys.stderr,
        )
        return 1

    output_ico.parent.mkdir(parents=True, exist_ok=True)

    svg_text = source_svg.read_text(encoding="utf-8")

    with tempfile.TemporaryDirectory() as temp_dir:
        png_path = Path(temp_dir) / "vio_class_icon_1024.png"
        cairosvg.svg2png(
            bytestring=svg_text.encode("utf-8"),
            write_to=str(png_path),
            output_width=1024,
            output_height=1024,
        )

        image = Image.open(png_path).convert("RGBA")
        image.save(
            output_ico,
            format="ICO",
            sizes=[
                (256, 256),
                (128, 128),
                (64, 64),
                (48, 48),
                (32, 32),
                (16, 16),
            ],
        )

    print(f"Generated Windows icon: {output_ico}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
