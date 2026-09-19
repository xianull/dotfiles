#!/usr/bin/env python3
"""Render a small circular progress ring PNG for SketchyBar.

Usage:
  focus_ring.py <percent 0-100> [hex_color RRGGBB] [out_path]

Default out: /tmp/sbar_focus_ring.png
"""
from __future__ import annotations

import math
import struct
import sys
import zlib
from pathlib import Path


def write_png(path: Path, rgba: bytes, w: int, h: int) -> None:
    def chunk(tag: bytes, data: bytes) -> bytes:
        return struct.pack(">I", len(data)) + tag + data + struct.pack(
            ">I", zlib.crc32(tag + data) & 0xFFFFFFFF
        )

    raw = b""
    stride = w * 4
    for y in range(h):
        raw += b"\x00" + rgba[y * stride : (y + 1) * stride]
    ihdr = struct.pack(">IIBBBBB", w, h, 8, 6, 0, 0, 0)
    data = b"\x89PNG\r\n\x1a\n"
    data += chunk(b"IHDR", ihdr)
    data += chunk(b"IDAT", zlib.compress(raw, 9))
    data += chunk(b"IEND", b"")
    path.write_bytes(data)


def parse_hex(s: str):
    s = s.strip().lstrip("#")
    if len(s) == 8:
        s = s[2:]  # drop alpha prefix if AARRGGBB from sketchybar
    if len(s) != 6:
        return 255, 159, 10  # orange-ish
    return int(s[0:2], 16), int(s[2:4], 16), int(s[4:6], 16)


def draw_ring(percent: float, color_hex: str = "FF9F0A", size: int = 28) -> bytes:
    """Crisper ring with soft AA; progress starts at 12 o'clock, clockwise."""
    percent = max(0.0, min(100.0, float(percent)))
    r, g, b = parse_hex(color_hex)
    cx = cy = (size - 1) / 2.0
    outer = size * 0.44
    inner = size * 0.30
    track_rgb = (120, 122, 130)
    track_a = 70
    px = bytearray(size * size * 4)

    def set_px(x, y, rr, gg, bb, aa):
        if aa <= 0:
            return
        i = (y * size + x) * 4
        # alpha composite over existing
        oa = px[i + 3] / 255.0
        na = aa / 255.0
        out_a = na + oa * (1 - na)
        if out_a <= 0:
            return
        px[i] = int((rr * na + px[i] * oa * (1 - na)) / out_a)
        px[i + 1] = int((gg * na + px[i + 1] * oa * (1 - na)) / out_a)
        px[i + 2] = int((bb * na + px[i + 2] * oa * (1 - na)) / out_a)
        px[i + 3] = int(out_a * 255)

    end_ang = 2 * math.pi * (percent / 100.0)
    for y in range(size):
        for x in range(size):
            dx = x - cx
            dy = y - cy
            dist = math.hypot(dx, dy)
            # ring band with soft edges
            if dist > outer + 1.2 or dist < inner - 1.2:
                continue
            outer_e = max(0.0, min(1.0, (outer + 0.9 - dist) * 1.8))
            inner_e = max(0.0, min(1.0, (dist - (inner - 0.9)) * 1.8))
            band = outer_e * inner_e
            if band <= 0:
                continue

            ang = math.atan2(dx, -dy)
            if ang < 0:
                ang += 2 * math.pi

            on_progress = percent >= 99.9 or (percent > 0.4 and ang <= end_ang + 0.03)
            if on_progress:
                set_px(x, y, r, g, b, int(255 * band))
            else:
                set_px(x, y, track_rgb[0], track_rgb[1], track_rgb[2], int(track_a * band))

    return bytes(px)


def main(argv=None) -> int:
    argv = list(argv or sys.argv[1:])
    percent = float(argv[0]) if argv else 0
    color = argv[1] if len(argv) > 1 else "FF9F0A"
    out = Path(argv[2] if len(argv) > 2 else "/tmp/sbar_focus_ring.png")
    size = 28
    rgba = draw_ring(percent, color, size)
    write_png(out, rgba, size, size)
    print(str(out))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
