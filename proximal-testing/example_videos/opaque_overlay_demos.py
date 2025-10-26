"""Generate videos that highlight MoviePy's current opaque compositing behaviour.

Each output intentionally relies on semi-transparent overlays so the lack of
alpha blending is obvious in the rendered result.
"""

import argparse
from pathlib import Path

import numpy as np

from moviepy import *


FPS = 24


def write_video(clip, filename: str) -> None:
    """Persist `clip` in the same directory as this script."""
    target = Path(__file__).resolve().parent / filename
    target.parent.mkdir(parents=True, exist_ok=True)
    clip.write_videofile(
        target.as_posix(),
        fps=FPS,
        codec="libx264",
        preset="ultrafast",
        bitrate="500k",
        audio=False,
        logger=None,
    )


def checkerboard_clip(
    size: tuple[int, int],
    duration: float,
    tile: int = 40,
    colors: tuple[tuple[int, int, int], tuple[int, int, int]] = (
        (20, 20, 20),
        (220, 220, 220),
    ),
) -> VideoClip:
    """Return a static checkerboard backing clip."""
    width, height = size
    tile = max(1, tile)

    cols = np.arange(width) // tile
    rows = np.arange(height) // tile
    grid = (rows[:, None] + cols[None, :]) % 2

    palette = np.array(colors, dtype=np.uint8)
    frame = palette[grid]

    return ImageClip(frame).with_duration(duration).with_fps(FPS)


def opaque_overlay_demo(suffix: str = "") -> None:
    """Full-frame overlay that used to appear translucent now covers the base clip."""
    duration = 2
    size = (320, 240)

    background = ColorClip(size, color=(0, 0, 255), duration=duration).with_fps(FPS)
    overlay = ColorClip(size, color=(0, 255, 0), duration=duration).with_opacity(0.5)

    demo = CompositeVideoClip([background, overlay])
    write_video(demo, f"./out/opaque_overlay_demo_hee{suffix}.mp4")


def mask_ignored_demo(suffix: str = "") -> None:
    """Layered square that used to respect its animated mask now stays solid."""
    duration = 2
    size = (320, 240)

    background = ColorClip(size, color=(255, 0, 0), duration=duration).with_fps(FPS)

    square = ColorClip((120, 120), color=(255, 255, 255), duration=duration)
    square = square.with_position(("center", "center")).with_opacity(0.2)

    demo = CompositeVideoClip([background, square])
    write_video(demo, f"./out/mask_ignored_demo_hee{suffix}.mp4")


def background_transparency_demo(suffix: str = "") -> None:
    """Semi-transparent background retains its alpha instead of turning opaque."""
    duration = 2
    size = (320, 240)

    checker = checkerboard_clip(size, duration)
    translucent_bg = ColorClip(size, color=(0, 0, 255), duration=duration).with_opacity(
        0.5
    ).with_fps(FPS)
    opaque_bar = (
        ColorClip((160, 240), color=(0, 255, 0), duration=duration)
        .with_position(("right", "center"))
        .with_fps(FPS)
    )

    layered = CompositeVideoClip([translucent_bg, opaque_bar], bg_color=None)
    demo = CompositeVideoClip([checker, layered], bg_color=None)
    write_video(demo, f"./out/background_transparency_demo_hee{suffix}.mp4")


def dual_mask_blend_demo(suffix: str = "") -> None:
    """Overlapping translucent layers blend their colors instead of replacing."""
    duration = 2
    size = (320, 240)

    base = ColorClip(size, color=(0, 0, 255), duration=duration).with_opacity(0.5).with_fps(
        FPS
    )
    overlay = (
        ColorClip((200, 160), color=(255, 255, 0), duration=duration)
        .with_position(("center", "center"))
        .with_opacity(0.5)
        .with_fps(FPS)
    )

    demo = CompositeVideoClip([base, overlay])
    write_video(demo, f"./out/dual_mask_blend_demo_hee{suffix}.mp4")


def clipped_mask_demo(suffix: str = "") -> None:
    """Off-screen translucent elements stay feathered instead of snapping opaque."""
    duration = 2
    size = (320, 240)

    background = ColorClip(size, color=(0, 0, 0), duration=duration).with_fps(FPS)
    offscreen = (
        ColorClip((200, 200), color=(255, 255, 255), duration=duration)
        .with_position((-80, "center"))
        .with_opacity(0.5)
        .with_fps(FPS)
    )

    demo = CompositeVideoClip([background, offscreen])
    write_video(demo, f"./out/clipped_mask_demo_hee{suffix}.mp4")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(
        description="Generate videos that highlight MoviePy's opaque compositing behaviour."
    )
    parser.add_argument(
        "--suffix",
        type=str,
        default="",
        help="Suffix to add to video filenames (e.g., '_v2' results in 'demo_hee_v2.mp4')",
    )
    args = parser.parse_args()
    
    opaque_overlay_demo(args.suffix)
    mask_ignored_demo(args.suffix)
    background_transparency_demo(args.suffix)
    dual_mask_blend_demo(args.suffix)
    clipped_mask_demo(args.suffix)
