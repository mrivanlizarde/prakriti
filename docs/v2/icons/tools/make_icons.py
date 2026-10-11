#!/usr/bin/env python3
"""Prakriti icon generator: "Recomposed", the brand's ultramarine dot cut once and re-set.

Writes, under <out>/ (normally docs/v2/icons):
  source/Prakriti.icon/             Icon Composer document (icon.json + Assets/*.svg). Opens in Icon Composer.
  source/layers/*.svg               The same artwork as plain 1024 x 1024 layers: background, mid, foreground.
  source/prakriti-icon-flat.svg     One flat 1024 x 1024 SVG, full bleed and unmasked (the system masks it).
  source/prakriti-icon-rounded.svg  The flat icon inside the classic macOS rounded square, for web and docs only.
  source/menubar/*.svg              Menu bar template glyphs, 18 x 18 pt, black on clear.

Usage:  cd ~/Code/prakriti/docs/v2/icons && python3 tools/make_icons.py .
WARNING: this rewrites source/Prakriti.icon. Once anyone adjusts the icon in Icon Composer and saves, that saved
file is the source of truth: stop running this script, or the adjustments are lost.
Standard library only. Every number is in the 1024 canvas unless it says pt.
Each value was chosen by rendering with Apple's own renderer (ictool) and looking at 1024 down to 16 px.
"""
import json, math, os, sys

OUT = sys.argv[1] if len(sys.argv) > 1 else "."
OPTS = dict(a.split("=", 1) for a in sys.argv[2:])   # shift=0.15 gap=26, for trying variations only

# Brand colors, from web/public/assets/site.css.
STONE = "#F3F3F0"        # --ground (light): cool stone, deliberately not cream
STONE_DARK = "#18191C"   # --surface (dark): the dark-appearance ground
ULTRA = "#2337C6"        # --accent-mark (light): the underdot's ultramarine
ULTRA_DARK = "#4459E8"   # --accent-mark (dark): stays a saturated ultramarine, never lavender (site B18)

# The mark.
CX = CY = 512.0
R = float(OPTS.get("r", 305))   # disc diameter 610 = 60% of the canvas (v1's dot was 53%). 290, 305 and 320
#                                 were compared beside Photos, Compressor and Motion at Dock size: 290 looked timid,
#                                 320 crowded the corners.
GAP = float(OPTS.get("gap", 26))           # the cut. At 16 px the system's glass rim still draws it as a line
SHIFT = float(OPTS.get("shift", 0.15)) * 2 * R
# SHIFT is how far the upper half sits to the right of the lower one (92 px). Tried 0.11, 0.15 and 0.19 of
# the diameter: 0.11 lost the step at 16 and 32 px; 0.19 read as two loose pieces at full size.
FILLET = 16.0                              # rounds the corners where the cut meets the circle (HIG: no sharp corners)


def f(v):
    s = f"{v:.3f}".rstrip("0").rstrip(".")
    return "0" if s in ("-0", "") else s


def half_path(cx, cy, r, gap, fillet, upper, dx, scale=1.0, ox=0.0, oy=0.0):
    """One half of the disc (cx, cy, r) with `gap` removed around its horizontal diameter, moved by dx.
    The two corners where the cut meets the circle are rounded with exact tangent arcs of radius `fillet`.
    scale, ox and oy map the result into another canvas (the menu bar glyph)."""
    def P(x, y):
        return f"{f((x + dx) * scale + ox)} {f(y * scale + oy)}"
    Rs, rf = r * scale, fillet * scale
    k = r / (r - fillet)
    ycut = cy - gap / 2 if upper else cy + gap / 2
    yc = ycut - fillet if upper else ycut + fillet      # height of the fillet centres
    xc = math.sqrt((r - fillet) ** 2 - (yc - cy) ** 2)
    line_l, line_r = (cx - xc, ycut), (cx + xc, ycut)    # where the fillets meet the cut
    circ_l = (cx - xc * k, cy + (yc - cy) * k)           # where the fillets meet the circle
    circ_r = (cx + xc * k, cy + (yc - cy) * k)
    big = f"A{f(Rs)} {f(Rs)} 0 0 1 "
    small = f"A{f(rf)} {f(rf)} 0 0 1 "
    if upper:   # clockwise: up the left side, over the top, down to the cut, back along it
        return (f"M{P(*circ_l)}{big}{P(cx, cy - r)}{big}{P(*circ_r)}{small}{P(*line_r)}"
                f"L{P(*line_l)}{small}{P(*circ_l)}Z")
    return (f"M{P(*line_l)}L{P(*line_r)}{small}{P(*circ_r)}{big}{P(cx, cy + r)}{big}{P(*circ_l)}"
            f"{small}{P(*line_l)}Z")


def svg(w, h, body, title):
    return (f'<svg xmlns="http://www.w3.org/2000/svg" width="{w}" height="{h}" viewBox="0 0 {w} {h}">'
            f"<title>{title}</title>{body}</svg>\n")


def write(rel, text):
    p = os.path.join(OUT, rel)
    os.makedirs(os.path.dirname(p), exist_ok=True)
    with open(p, "w") as fh:
        fh.write(text)


def srgb(hexc, a=1.0):
    h = hexc.lstrip("#")
    r, g, b = (int(h[i:i + 2], 16) / 255 for i in (0, 2, 4))
    return f"srgb:{r:.5f},{g:.5f},{b:.5f},{a:.5f}"


# The upper half moves right and the lower half left by the same amount, so the mark's box and its
# centre of mass both stay on the canvas centre.
UPPER = half_path(CX, CY, R, GAP, FILLET, True, +SHIFT / 2)
LOWER = half_path(CX, CY, R, GAP, FILLET, False, -SHIFT / 2)

# ---- Plain layers: 1024, square, unmasked, no effects. Icon Composer adds glass, light and shadow;
# Apple: "Remove blurs and shadows... Remove background colors and gradients", "Don't export the canvas mask".
write("source/layers/0-background.svg",
      svg(1024, 1024, f'<rect width="1024" height="1024" fill="{STONE}"/>', "Prakriti icon, background: stone"))
write("source/layers/1-mid-lower-half.svg",
      svg(1024, 1024, f'<path fill="{ULTRA}" d="{LOWER}"/>', "Prakriti icon, mid: the lower half"))
write("source/layers/2-foreground-upper-half.svg",
      svg(1024, 1024, f'<path fill="{ULTRA}" d="{UPPER}"/>', "Prakriti icon, foreground: the upper half, re-set"))

# ---- The Icon Composer document. In icon.json the first group is the frontmost (checked by rendering two
# overlapping circles with ictool, 10 Oct 2026). The background is the document fill, not an image: Apple's
# Icon Composer guide says a solid or gradient fill makes an imported background unnecessary.
def group(name, image):
    layer = {
        "image-name": image,
        "name": name,
        "glass": True,
        "fill-specializations": [
            {"value": "automatic"},                                            # the SVG's own ultramarine
            {"appearance": "dark", "value": {"solid": srgb(ULTRA_DARK)}},
            # Clear and tinted: white, so the system tint reads. Ultramarine went dark on dark in Tinted Dark.
            {"appearance": "tinted", "value": {"solid": "extended-gray:1.00000,1.00000"}},
        ],
    }
    return {"name": name, "layers": [layer], "lighting": "individual", "specular": True,
            "shadow": {"kind": "layer-color", "opacity": 0.5},
            "translucency": {"enabled": True, "value": 0.35}}


doc = {
    "fill-specializations": [
        {"value": {"solid": srgb(STONE)}},
        {"appearance": "dark", "value": {"solid": srgb(STONE_DARK)}},
    ],
    "groups": [group("foreground-upper-half", "2-foreground-upper-half.svg"),
               group("mid-lower-half", "1-mid-lower-half.svg")],
    "supported-platforms": {"squares": ["macOS"]},
}
write("source/Prakriti.icon/icon.json", json.dumps(doc, indent=2) + "\n")
write("source/Prakriti.icon/Assets/2-foreground-upper-half.svg",
      svg(1024, 1024, f'<path fill="{ULTRA}" d="{UPPER}"/>', "upper half"))
write("source/Prakriti.icon/Assets/1-mid-lower-half.svg",
      svg(1024, 1024, f'<path fill="{ULTRA}" d="{LOWER}"/>', "lower half"))

# ---- Flat fallbacks.
write("source/prakriti-icon-flat.svg", svg(
    1024, 1024,
    f'<rect width="1024" height="1024" fill="{STONE}"/>'
    f'<path fill="{ULTRA}" d="{LOWER}"/><path fill="{ULTRA}" d="{UPPER}"/>', "Prakriti"))
# Classic macOS grid (824 body, 100 margin, 185 corner), the same grid v1's make_icon.swift used.
# Web and documents only: an app ships the .icon, never this.
s = 824 / 1024
write("source/prakriti-icon-rounded.svg", svg(
    1024, 1024,
    f'<rect x="100" y="100" width="824" height="824" rx="185" fill="{STONE}"/>'
    f'<rect x="100.5" y="100.5" width="823" height="823" rx="184.5" fill="none" stroke="#B8BAB3"/>'
    f'<g transform="translate(100 100) scale({f(s)})">'
    f'<path fill="{ULTRA}" d="{LOWER}"/><path fill="{ULTRA}" d="{UPPER}"/></g>', "Prakriti"))

# ---- Menu bar template glyphs: 18 x 18 pt, black on clear, so macOS tints them for light, dark and
# selected menu bars. The same drawing at a smaller size, with two optical changes for the menu bar:
#   disc 14 pt, edges on whole points at 1x (top 2, cut 8 to 10, bottom 16), so 18 px is crisp;
#   a 2 pt cut and a 3 pt step (0.21 of the disc, against 0.15 in the app icon), because at 16 px
#   a proportional step is under 2 px and the mark reads as a plain dot.
MB, mr = 18.0, 7.0
ms = mr / R
ox, oy = MB / 2 - CX * ms, MB / 2 - CY * ms
m_gap, m_step, m_fillet = 2.0 / ms, 3.0 / ms, 0.9 / ms


def glyph(op_upper=1.0, op_lower=1.0):
    up = half_path(CX, CY, R, m_gap, m_fillet, True, +m_step / 2, ms, ox, oy)
    lo = half_path(CX, CY, R, m_gap, m_fillet, False, -m_step / 2, ms, ox, oy)
    a = "" if op_upper == 1 else f' fill-opacity="{op_upper}"'
    b = "" if op_lower == 1 else f' fill-opacity="{op_lower}"'
    return f'<path fill="#000000"{a} d="{up}"/><path fill="#000000"{b} d="{lo}"/>'


def upper_notched_pt(badge, clear):
    """The menu bar's upper half (in pt) with a round notch cut where the badge sits, so the badge stays
    separate at 16 px without relying on SVG masks (which asset catalogs may not keep [unverified])."""
    cx, cy, r, gap, rf = 9 + 1.5, 9.0, 7.0, 2.0, 0.9
    bx, by = badge
    ycut = cy - gap / 2
    yc = ycut - rf
    xc = math.sqrt((r - rf) ** 2 - (yc - cy) ** 2)
    k = r / (r - rf)
    line_l, line_r = (cx - xc, ycut), (cx + xc, ycut)
    circ_l, circ_r = (cx - xc * k, cy + (yc - cy) * k), (cx + xc * k, cy + (yc - cy) * k)
    d = math.hypot(bx - cx, by - cy)
    a = (r * r - clear * clear + d * d) / (2 * d)
    h = math.sqrt(r * r - a * a)
    xm, ym = cx + a * (bx - cx) / d, cy + a * (by - cy) / d
    pts = [(xm + h * (by - cy) / d, ym - h * (bx - cx) / d), (xm - h * (by - cy) / d, ym + h * (bx - cx) / d)]
    p1, p2 = sorted(pts, key=lambda p: math.atan2(p[1] - cy, p[0] - cx))   # clockwise from the top
    q = lambda p: f"{f(p[0])} {f(p[1])}"
    big, small, notch = f"A{f(r)} {f(r)} 0 0 1 ", f"A{f(rf)} {f(rf)} 0 0 1 ", f"A{f(clear)} {f(clear)} 0 0 0 "
    return (f"M{q(circ_l)}{big}{q((cx, cy - r))}{big}{q(p1)}{notch}{q(p2)}{big}{q(circ_r)}"
            f"{small}{q(line_r)}L{q(line_l)}{small}{q(circ_l)}Z")


def outline(dashed=False):
    """The mark as an outline, 1.25 pt, the same outer size as the filled mark."""
    sw = 1.25
    up = half_path(CX, CY, R - sw / 2 / ms, m_gap + sw / ms, m_fillet - sw / 2 / ms, True, +m_step / 2, ms, ox, oy)
    lo = half_path(CX, CY, R - sw / 2 / ms, m_gap + sw / ms, m_fillet - sw / 2 / ms, False, -m_step / 2, ms, ox, oy)
    st = f'fill="none" stroke="#000000" stroke-width="{sw}" stroke-linejoin="round"'
    if dashed:
        st += ' stroke-dasharray="1.6 1.4" stroke-linecap="butt"'
    return f'<path {st} d="{up}"/><path {st} d="{lo}"/>'


# v1 gives each of its six menu bar states its own shape (RulesTests: "each menu bar state has its own
# shape"; the site's rule: status is a word plus a shape, never color alone). v2 keeps all six.
#   idle            the mark
#   working         the mark, its halves lit in turn (two frames)
#   waiting for you the mark with a dot at the top right
#   problem         the mark with an exclamation mark at the top right
#   paused          the mark as an outline
#   not watching    the mark as a dashed outline
# Badges sit in a round notch 1 pt clear of the mark, cut into the path itself rather than with an SVG
# mask, which asset catalogs may not keep [unverified].
BADGE, BADGE_R = (15.4, 2.6), 2.6
NOTCHED = upper_notched_pt(BADGE, BADGE_R + 1.0)
LOWER_PT = half_path(CX, CY, R, m_gap, m_fillet, False, -m_step / 2, ms, ox, oy)
# The exclamation mark is 2 pt wide so it survives 1x; its notch is a little larger and lower than the dot's
# so every part of it stays 1 pt clear of the mark.
EXCLAIM = ('<rect fill="#000000" x="14.4" y="0.2" width="2" height="3.1" rx="1"/>'
           '<circle fill="#000000" cx="15.4" cy="4.75" r="1"/>')
NOTCHED_EXCLAIM = upper_notched_pt((15.4, 2.9), 3.9)
GLYPHS = {
    "prakriti-menubar": (glyph(), "Prakriti"),
    # Working: one half lit, the other at 35%, swapped every 0.7 s by the app (see README: a TimelineView
    # inside a MenuBarExtra label never ticks; a state change from outside it does).
    "prakriti-menubar-working-1": (glyph(1.0, 0.35), "Prakriti, working"),
    "prakriti-menubar-working-2": (glyph(0.35, 1.0), "Prakriti, working"),
    "prakriti-menubar-waiting": (f'<path fill="#000000" d="{NOTCHED}"/><path fill="#000000" d="{LOWER_PT}"/>'
                                 f'<circle fill="#000000" cx="{BADGE[0]}" cy="{BADGE[1]}" r="{BADGE_R}"/>',
                                 "Prakriti, waiting for you"),
    "prakriti-menubar-problem": (f'<path fill="#000000" d="{NOTCHED_EXCLAIM}"/><path fill="#000000" d="{LOWER_PT}"/>'
                                 + EXCLAIM, "Prakriti, problem"),
    # Paused and not watching are outlines, a change of shape rather than a dimmer copy: macOS already
    # dims every menu bar item on a display that is not active, and a dim glyph dimmed again disappears.
    "prakriti-menubar-paused": (outline(), "Prakriti, paused"),
    "prakriti-menubar-not-watching": (outline(dashed=True), "Prakriti, not watching"),
}
for name, (body, title) in GLYPHS.items():
    write(f"source/menubar/{name}.svg", svg(18, 18, body, title))
print("wrote the icon sources under", os.path.abspath(OUT))

# ---- Ready-to-copy asset catalog image sets for the menu bar glyphs: template rendering, vector kept.
# Copy each folder into mac/Prakriti/Resources/Assets.xcassets/. Checked 10 Oct 2026 in a scratch
# XcodeGen 2.46 + Xcode 27 project: builds with no warnings, compiled as template images at 1x and 2x.
for name in GLYPHS:
    with open(os.path.join(OUT, "source/menubar", name + ".svg")) as fh:
        body = fh.read()
    write(f"source/menubar/imagesets/{name}.imageset/{name}.svg", body)
    write(f"source/menubar/imagesets/{name}.imageset/Contents.json", json.dumps({
        "images": [{"filename": name + ".svg", "idiom": "universal"}],
        "info": {"author": "xcode", "version": 1},
        "properties": {"preserves-vector-representation": True, "template-rendering-intent": "template"},
    }, indent=2) + "\n")
print("wrote the menu bar image sets")
