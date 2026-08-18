#!/usr/bin/env python3
"""Generate the synthetic Pocus README demo without recording a real desktop."""

from __future__ import annotations

import math
import shutil
import subprocess
import tempfile
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter, ImageFont, ImageOps


WIDTH = 960
HEIGHT = 540
FPS = 15
DURATION = 8
FRAME_COUNT = FPS * DURATION

ROOT = Path(__file__).resolve().parent.parent
OUTPUT_DIRECTORY = ROOT / "docs"
MP4_PATH = OUTPUT_DIRECTORY / "pocus-demo.mp4"
GIF_PATH = OUTPUT_DIRECTORY / "pocus-demo.gif"

WINDOWS = {
    "plan": (38, 112, 286, 410),
    "write": (310, 72, 674, 432),
    "research": (698, 126, 926, 410),
}


def font(size: int, bold: bool = False) -> ImageFont.FreeTypeFont | ImageFont.ImageFont:
    candidates = [
        "/System/Library/Fonts/Supplemental/Arial Bold.ttf"
        if bold
        else "/System/Library/Fonts/Supplemental/Arial.ttf",
        "/System/Library/Fonts/SFNS.ttf",
        "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf"
        if bold
        else "/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf",
    ]
    for candidate in candidates:
        try:
            return ImageFont.truetype(candidate, size)
        except OSError:
            continue
    return ImageFont.load_default()


FONT_11 = font(11)
FONT_12 = font(12)
FONT_13 = font(13)
FONT_14_BOLD = font(14, bold=True)
FONT_16_BOLD = font(16, bold=True)
FONT_18_BOLD = font(18, bold=True)
FONT_24_BOLD = font(24, bold=True)


def mix(start: float, end: float, amount: float) -> float:
    return start + (end - start) * amount


def smoothstep(amount: float) -> float:
    amount = max(0.0, min(1.0, amount))
    return amount * amount * (3 - 2 * amount)


def interpolate_rect(
    start: tuple[int, int, int, int],
    end: tuple[int, int, int, int],
    amount: float,
) -> tuple[int, int, int, int]:
    eased = smoothstep(amount)
    return tuple(round(mix(a, b, eased)) for a, b in zip(start, end))  # type: ignore[return-value]


def rounded_mask(rect: tuple[int, int, int, int], radius: int = 16) -> Image.Image:
    mask = Image.new("L", (WIDTH, HEIGHT), 0)
    ImageDraw.Draw(mask).rounded_rectangle(rect, radius=radius, fill=255)
    return mask


def draw_window_shell(
    draw: ImageDraw.ImageDraw,
    rect: tuple[int, int, int, int],
    title: str,
    accent: tuple[int, int, int],
) -> None:
    left, top, right, bottom = rect
    draw.rounded_rectangle(
        rect, radius=15, fill=(250, 251, 255), outline=(255, 255, 255), width=1
    )
    draw.rounded_rectangle(
        (left, top, right, top + 38), radius=15, fill=(237, 240, 247)
    )
    draw.rectangle((left, top + 22, right, top + 38), fill=(237, 240, 247))
    for index, color in enumerate(((255, 95, 87), (254, 188, 46), (40, 200, 64))):
        x = left + 16 + index * 18
        draw.ellipse((x, top + 14, x + 9, top + 23), fill=color)
    draw.text((left + 78, top + 12), title, font=FONT_12, fill=(74, 79, 92))
    draw.rounded_rectangle(
        (left + 13, top + 53, left + 18, bottom - 16), radius=3, fill=accent
    )


def draw_plan_window(draw: ImageDraw.ImageDraw, time: float) -> None:
    rect = WINDOWS["plan"]
    draw_window_shell(draw, rect, "Plan", (109, 89, 250))
    left, top, _, _ = rect
    draw.text((left + 34, top + 58), "Today", font=FONT_18_BOLD, fill=(40, 43, 54))
    tasks = ("Outline the idea", "Build the focus", "Share the result")
    checked = 1 + int(time >= 3.55) + int(time >= 4.05)
    for index, task in enumerate(tasks):
        y = top + 105 + index * 55
        is_checked = index < checked
        fill = (109, 89, 250) if is_checked else (255, 255, 255)
        outline = (109, 89, 250) if is_checked else (177, 181, 193)
        draw.rounded_rectangle(
            (left + 35, y, left + 53, y + 18), radius=5, fill=fill, outline=outline
        )
        if is_checked:
            draw.line((left + 39, y + 9, left + 44, y + 14), fill="white", width=2)
            draw.line((left + 44, y + 14, left + 51, y + 5), fill="white", width=2)
        draw.text((left + 65, y + 1), task, font=FONT_13, fill=(52, 56, 69))
        draw.line(
            (left + 65, y + 27, left + 218, y + 27), fill=(229, 231, 237), width=2
        )


def draw_write_window(draw: ImageDraw.ImageDraw, time: float) -> None:
    rect = WINDOWS["write"]
    draw_window_shell(draw, rect, "Write", (38, 142, 255))
    left, top, right, _ = rect
    draw.text(
        (left + 36, top + 59),
        "One window. One idea.",
        font=FONT_24_BOLD,
        fill=(32, 38, 52),
    )
    lines = (
        "Pocus keeps the selected window clear while",
        "the rest of your desktop gently fades away.",
        "Switch tasks naturally—the focus follows you.",
    )
    visible_characters = min(
        sum(len(line) for line in lines),
        max(0, round((time - 0.35) * 45)),
    )
    used = 0
    for index, line in enumerate(lines):
        visible = line[: max(0, visible_characters - used)]
        y = top + 123 + index * 34
        draw.text(
            (left + 36, y),
            visible,
            font=FONT_14_BOLD,
            fill=(68, 74, 88),
        )
        used += len(line)
    caret_line = min(2, visible_characters // max(1, len(lines[0])))
    if int(time * 3) % 2 == 0 and time < 2.25:
        current_line = lines[caret_line][
            : max(0, visible_characters - sum(len(item) for item in lines[:caret_line]))
        ]
        caret_x = left + 36 + draw.textlength(current_line, font=FONT_14_BOLD)
        caret_y = top + 123 + caret_line * 34
        draw.line(
            (caret_x + 2, caret_y, caret_x + 2, caret_y + 17),
            fill=(38, 142, 255),
            width=2,
        )
    draw.rounded_rectangle(
        (left + 35, top + 254, right - 34, top + 310), radius=12, fill=(232, 243, 255)
    )
    draw.text(
        (left + 52, top + 273),
        "Stay with what matters.",
        font=FONT_16_BOLD,
        fill=(29, 105, 189),
    )


def draw_research_window(draw: ImageDraw.ImageDraw, time: float) -> None:
    rect = WINDOWS["research"]
    draw_window_shell(draw, rect, "Research", (244, 130, 54))
    left, top, right, _ = rect
    draw.text(
        (left + 34, top + 58), "Reading list", font=FONT_18_BOLD, fill=(40, 43, 54)
    )
    cards = (
        ((255, 232, 214), "Deep work"),
        ((225, 241, 255), "Attention"),
        ((233, 229, 255), "Flow state"),
    )
    pulse = (math.sin(time * math.pi * 2) + 1) / 2 if 5.4 <= time <= 7.1 else 0
    for index, (color, title) in enumerate(cards):
        y = top + 101 + index * 67
        active = index == 1 and pulse > 0.35
        outline = (38, 142, 255) if active else (225, 227, 234)
        draw.rounded_rectangle(
            (left + 33, y, right - 24, y + 49),
            radius=10,
            fill=(255, 255, 255),
            outline=outline,
            width=2 if active else 1,
        )
        draw.rounded_rectangle(
            (left + 44, y + 10, left + 73, y + 39), radius=7, fill=color
        )
        draw.text((left + 84, y + 15), title, font=FONT_13, fill=(55, 59, 72))


def draw_desktop(time: float) -> Image.Image:
    gradient = Image.linear_gradient("L").resize((WIDTH, HEIGHT))
    image = ImageOps.colorize(
        gradient,
        black=(84, 92, 236),
        white=(138, 152, 188),
    )

    draw = ImageDraw.Draw(image, "RGBA")
    draw.ellipse((-120, 140, 380, 640), fill=(69, 218, 197, 70))
    draw.ellipse((600, -220, 1100, 280), fill=(255, 125, 163, 85))
    draw.rounded_rectangle((0, 0, WIDTH, 32), radius=0, fill=(249, 249, 252, 220))
    draw.text((16, 8), "●", font=FONT_11, fill=(38, 41, 50))
    draw.text((35, 8), "Pocus Demo", font=FONT_12, fill=(38, 41, 50))
    draw.text((790, 8), "Focus", font=FONT_12, fill=(56, 60, 72))
    draw_viewfinder(draw, 915, 8, (38, 142, 255, 255))

    draw_plan_window(draw, time)
    draw_write_window(draw, time)
    draw_research_window(draw, time)

    draw.rounded_rectangle(
        (342, 486, 618, 527),
        radius=16,
        fill=(240, 241, 247, 205),
        outline=(255, 255, 255, 150),
    )
    dock_colors = (
        (65, 150, 255),
        (105, 91, 255),
        (255, 126, 79),
        (71, 201, 133),
        (244, 87, 114),
        (128, 134, 148),
    )
    for index, color in enumerate(dock_colors):
        x = 361 + index * 42
        draw.rounded_rectangle((x, 493, x + 29, 522), radius=8, fill=color)
    return image


def draw_viewfinder(
    draw: ImageDraw.ImageDraw,
    x: int,
    y: int,
    color: tuple[int, int, int, int],
) -> None:
    length = 6
    size = 15
    width = 2
    draw.line((x, y + length, x, y, x + length, y), fill=color, width=width)
    draw.line(
        (x + size - length, y, x + size, y, x + size, y + length),
        fill=color,
        width=width,
    )
    draw.line(
        (x, y + size - length, x, y + size, x + length, y + size),
        fill=color,
        width=width,
    )
    draw.line(
        (x + size - length, y + size, x + size, y + size, x + size, y + size - length),
        fill=color,
        width=width,
    )


def focus_rect(time: float) -> tuple[int, int, int, int]:
    write = WINDOWS["write"]
    plan = WINDOWS["plan"]
    research = WINDOWS["research"]
    if time < 2.2:
        return write
    if time < 3.0:
        return interpolate_rect(write, plan, (time - 2.2) / 0.8)
    if time < 4.6:
        return plan
    if time < 5.4:
        return interpolate_rect(plan, research, (time - 4.6) / 0.8)
    if time < 7.0:
        return research
    return interpolate_rect(research, write, (time - 7.0) / 1.0)


def cursor_position(time: float, rect: tuple[int, int, int, int]) -> tuple[int, int]:
    left, top, right, bottom = rect
    phase = (math.sin(time * 1.7) + 1) / 2
    return (
        round(mix(left + 70, right - 55, phase)),
        round(mix(top + 100, bottom - 70, 1 - phase)),
    )


def render_frame(time: float) -> Image.Image:
    base = draw_desktop(time)
    blurred = base.filter(ImageFilter.GaussianBlur(radius=9))
    shade = Image.new("RGBA", (WIDTH, HEIGHT), (9, 13, 24, 112))
    muted = Image.alpha_composite(blurred.convert("RGBA"), shade).convert("RGB")

    rect = focus_rect(time)
    padded = (rect[0] - 8, rect[1] - 8, rect[2] + 8, rect[3] + 8)
    frame = Image.composite(base, muted, rounded_mask(padded, radius=20)).convert(
        "RGBA"
    )
    draw = ImageDraw.Draw(frame, "RGBA")
    draw.rounded_rectangle(padded, radius=20, outline=(255, 255, 255, 155), width=2)

    cursor_x, cursor_y = cursor_position(time, rect)
    cursor = (
        (cursor_x, cursor_y),
        (cursor_x + 3, cursor_y + 19),
        (cursor_x + 8, cursor_y + 14),
        (cursor_x + 13, cursor_y + 23),
        (cursor_x + 17, cursor_y + 21),
        (cursor_x + 12, cursor_y + 12),
        (cursor_x + 20, cursor_y + 11),
    )
    draw.polygon(cursor, fill=(255, 255, 255, 255), outline=(30, 34, 45, 255))

    caption = "Focus follows your selected window"
    caption_width = draw.textlength(caption, font=FONT_14_BOLD)
    caption_rect = (
        WIDTH / 2 - caption_width / 2 - 18,
        449,
        WIDTH / 2 + caption_width / 2 + 18,
        478,
    )
    draw.rounded_rectangle(caption_rect, radius=14, fill=(17, 22, 35, 205))
    draw.text(
        (WIDTH / 2 - caption_width / 2, 456),
        caption,
        font=FONT_14_BOLD,
        fill=(255, 255, 255, 245),
    )
    return frame.convert("RGB")


def encode_video(frames_directory: Path) -> None:
    ffmpeg = shutil.which("ffmpeg")
    if ffmpeg is None:
        raise SystemExit("ffmpeg is required to generate the demo assets")

    OUTPUT_DIRECTORY.mkdir(parents=True, exist_ok=True)
    input_pattern = str(frames_directory / "frame-%03d.png")
    subprocess.run(
        [
            ffmpeg,
            "-y",
            "-loglevel",
            "error",
            "-framerate",
            str(FPS),
            "-i",
            input_pattern,
            "-c:v",
            "libx264",
            "-preset",
            "slow",
            "-crf",
            "24",
            "-pix_fmt",
            "yuv420p",
            "-movflags",
            "+faststart",
            str(MP4_PATH),
        ],
        check=True,
    )
    subprocess.run(
        [
            ffmpeg,
            "-y",
            "-loglevel",
            "error",
            "-i",
            str(MP4_PATH),
            "-filter_complex",
            "[0:v]fps=12,scale=720:-1:flags=lanczos,split[v0][v1];"
            "[v0]palettegen=max_colors=96:stats_mode=diff[p];"
            "[v1][p]paletteuse=dither=bayer:bayer_scale=4:diff_mode=rectangle",
            "-loop",
            "0",
            str(GIF_PATH),
        ],
        check=True,
    )


def main() -> None:
    with tempfile.TemporaryDirectory(prefix="pocus-demo-") as temporary_directory:
        frames_directory = Path(temporary_directory)
        for index in range(FRAME_COUNT):
            time = index / FPS
            render_frame(time).save(
                frames_directory / f"frame-{index:03d}.png", optimize=True
            )
        encode_video(frames_directory)

    print(f"Generated {MP4_PATH.relative_to(ROOT)}")
    print(f"Generated {GIF_PATH.relative_to(ROOT)}")


if __name__ == "__main__":
    main()
