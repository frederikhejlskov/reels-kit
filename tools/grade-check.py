#!/usr/bin/env python3
"""Checks a grade against what the camera saw.

  grade-check.py <frame before the grade> <frame after the grade> [dusk]

Both are the same frame of one clip. Add the word dusk for a sunset,
dusk or night clip that the first line calls daylight. The picture is
read in three bands (top, middle, bottom), because a whole-frame number
hides a sky that changed colour while a bright road stayed the same.
Prints each band before and after, then OK, or one line per band that
moved too far, and ends with 1 when any did. Reads the images only.
"""
import colorsys, subprocess, sys

N = 48  # each image is read as N x N pixels
DARK = 0.25  # whole frame darker than this before the grade: dusk or night
# How far a band may move: brightness (times), saturation (added), hue (degrees).
LIMITS = {True: (1.15, 0.03, 8), False: (1.40, 0.20, 20)}
GREY = 0.15  # an average colour greyer than this has no hue worth comparing
BLACK = 0.04  # below this brightness a band has nothing worth comparing
WHITE = 0.98  # a band this bright after the grade has lost its picture


def bands(path):
    try:
        raw = subprocess.run(
            ["ffmpeg", "-nostdin", "-v", "error", "-i", path, "-frames:v", "1",
             "-vf", "scale=%d:%d" % (N, N), "-f", "rawvideo", "-pix_fmt", "rgb24", "-"],
            capture_output=True, check=True).stdout
    except OSError as e:
        sys.exit("Could not start ffmpeg: %s" % e)
    except subprocess.CalledProcessError as e:
        sys.exit("Could not read %s: %s" % (path, e.stderr.decode().strip() or e))
    if len(raw) != N * N * 3:
        sys.exit("Could not read %s as a picture" % path)
    out = []
    for lo, hi in ((0, N // 3), (N // 3, 2 * N // 3), (2 * N // 3, N), (0, N)):  # top, middle, bottom, all
        px = raw[lo * N * 3:hi * N * 3]
        n = len(px) // 3
        r, g, b = (sum(px[i::3]) / n / 255 for i in range(3))
        h, flat, v = colorsys.rgb_to_hsv(r, g, b)  # flat: of the average colour
        # Saturation pixel by pixel, so an orange cloud beside a blue sky
        # does not average to grey; weighted by brightness, so noise in
        # the dark does not count as colour.
        hi_ = [max(px[i:i + 3]) for i in range(0, len(px), 3)]
        lo_ = [min(px[i:i + 3]) for i in range(0, len(px), 3)]
        out.append((v, (sum(hi_) - sum(lo_)) / max(sum(hi_), 1), h * 360, flat))
    return out, 0.2126 * r + 0.7152 * g + 0.0722 * b  # the last band is the whole frame


def check(before, after, dusk=False):
    """Returns (lines to print, lines that failed)."""
    (b, luma), (a, _) = bands(before), bands(after)
    dark = dusk or luma < DARK
    up, sat, hue = LIMITS[dark]
    lines = ["%s clip (brightness %.2f before the grade)"
             % ("dusk or night" if dark else "daylight", luma)]
    bad = []
    for name, (bv, bs, bh, bf), (av, as_, ah, af) in zip(("top", "middle", "bottom"), b, a):
        lines.append("%-6s brightness %.2f to %.2f, saturation %.2f to %.2f, hue %3.0f to %3.0f"
                     % (name, bv, av, bs, as_, bh, ah))
        if max(bv, av) < BLACK:
            continue
        if av > bv * up + 0.01:
            bad.append("%s: %d%% brighter (limit %d%%)"
                       % (name, round((av / max(bv, 0.01) - 1) * 100), round((up - 1) * 100)))
        if av < bv / up - 0.01:
            bad.append("%s: %d%% darker (limit %d%%)"
                       % (name, round((1 - av / bv) * 100), round((1 - 1 / up) * 100)))
        if av >= WHITE > bv:
            bad.append("%s: blown out to white" % name)
        if as_ > bs + sat:
            bad.append("%s: saturation up %.2f (limit %.2f)" % (name, as_ - bs, sat))
        turn = abs((ah - bh + 180) % 360 - 180)
        if min(bf, af) >= GREY and turn > hue:  # the hue is the average colour's
            bad.append("%s: hue turned %d degrees (limit %d)" % (name, round(turn), hue))
    return lines, bad


if __name__ == "__main__":
    if len(sys.argv) not in (3, 4) or sys.argv[3:] not in ([], ["dusk"]):
        sys.exit(__doc__.strip())
    lines, bad = check(sys.argv[1], sys.argv[2], len(sys.argv) == 4)
    print("\n".join(lines))
    if bad:
        print("\n".join("TOO FAR " + x for x in bad))
        sys.exit(1)
    print("OK")
