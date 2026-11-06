#!/usr/bin/env python3
"""Draws Blob's app icons (macOS and iOS) with Pillow. Monochrome, continuous corners.

    python3 scripts/make_icons.py preview <out_dir>   # side-by-side variants
    python3 scripts/make_icons.py build [default] [alternate]   # writes the asset catalogs (blob, light)
"""
import json
import os
import sys

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

SS = 4  # supersampling for smooth edges


def squircle_mask(w, h, n=5.0, radius_frac=1.0):
    """Superellipse mask: continuous corners like Apple's icon shape."""
    y, x = np.mgrid[0:h, 0:w].astype(np.float64)
    nx = (x + 0.5 - w / 2) / (w / 2)
    ny = (y + 0.5 - h / 2) / (h / 2)
    inside = (np.abs(nx) ** n + np.abs(ny) ** n) <= radius_frac
    return Image.fromarray((inside * 255).astype(np.uint8), "L")


def rounded_rect_mask(w, h, r):
    """Continuous-ish rounded rect: superellipse corners blended into straight edges."""
    m = Image.new("L", (w, h), 0)
    d = ImageDraw.Draw(m)
    d.rounded_rectangle([0, 0, w - 1, h - 1], radius=r, fill=255)
    return m


def vertical_gradient(w, h, top, bottom):
    t = np.linspace(0, 1, h)[:, None, None]
    top = np.array(top, dtype=np.float64)[None, None, :]
    bottom = np.array(bottom, dtype=np.float64)[None, None, :]
    rows = top * (1 - t) + bottom * t
    arr = np.repeat(rows, w, axis=1)
    return Image.fromarray(arr.clip(0, 255).astype(np.uint8), "RGB")


def draw_blob(canvas, cx, cy, size, body=(148, 148, 152), eye=(0, 0, 0), look=(0.0, 0.0), squint=1.0):
    """The character: a grey continuous rounded rectangle with two capsule eyes.
    (cx, cy) is the centre of the body; size is its height."""
    w, h = int(size * 1.12), int(size)
    body_img = Image.new("RGBA", (w, h), body + (255,))
    mask = squircle_mask(w, h, n=3.6)
    # Soft shadow under the body.
    shadow = Image.new("RGBA", canvas.size, (0, 0, 0, 0))
    sm = Image.new("L", canvas.size, 0)
    sm.paste(mask, (int(cx - w / 2), int(cy - h / 2 + size * 0.06)))
    sm = sm.filter(ImageFilter.GaussianBlur(size * 0.08))
    shadow.putalpha(sm.point(lambda v: int(v * 0.55)))
    canvas.alpha_composite(shadow)
    # Body with a faint top-to-bottom shade.
    shade = vertical_gradient(w, h, tuple(min(255, c + 18) for c in body), tuple(max(0, c - 14) for c in body)).convert("RGBA")
    shade.putalpha(mask)
    canvas.alpha_composite(shade, (int(cx - w / 2), int(cy - h / 2)))
    # Eyes.
    d = ImageDraw.Draw(canvas)
    ew, eh = size * 0.13, size * 0.21 * squint
    gap = size * 0.24
    ex = cx + look[0] * size * 0.08
    ey = cy - size * 0.05 + look[1] * size * 0.06
    for sx in (-1, 1):
        x0 = ex + sx * (gap / 2 + ew / 2) - ew / 2
        d.rounded_rectangle([x0, ey - eh / 2, x0 + ew, ey + eh / 2], radius=ew / 2, fill=eye + (255,))


def variant_blob(px):
    """Black tile, the character centred."""
    img = vertical_gradient(px, px, (30, 30, 32), (6, 6, 7)).convert("RGBA")
    draw_blob(img, px / 2, px * 0.53, px * 0.42)
    return img


def variant_notch(px):
    """A notch at the top with Blob peeking out underneath, eyes up."""
    img = vertical_gradient(px, px, (44, 44, 47), (20, 20, 22)).convert("RGBA")
    d = ImageDraw.Draw(img)
    nw, nh = px * 0.62, px * 0.2
    x0 = (px - nw) / 2
    d.rounded_rectangle([x0, -nh, x0 + nw, nh], radius=px * 0.09, fill=(0, 0, 0, 255))
    draw_blob(img, px / 2, px * 0.6, px * 0.36, look=(0.0, -1.0))
    return img


def variant_light(px):
    """Light tile, grey character: reads well in a light Dock."""
    img = vertical_gradient(px, px, (246, 246, 247), (222, 222, 225)).convert("RGBA")
    draw_blob(img, px / 2, px * 0.53, px * 0.42, body=(120, 120, 126))
    return img


VARIANTS = {"blob": variant_blob, "notch": variant_notch, "light": variant_light}


def render_ios(variant, size=1024):
    """Full-bleed square; iOS applies its own mask."""
    big = VARIANTS[variant](size * SS)
    return big.resize((size, size), Image.LANCZOS).convert("RGB")


def render_mac(variant, size=1024):
    """macOS icon grid: 824 pt tile centred in 1024 with continuous corners and a soft shadow."""
    S = size * SS
    tile = int(S * 824 / 1024)
    art = VARIANTS[variant](tile)
    mask = squircle_mask(tile, tile, n=5.0)
    canvas = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    off = (S - tile) // 2
    sm = Image.new("L", (S, S), 0)
    sm.paste(mask, (off, off + int(S * 0.012)))
    sm = sm.filter(ImageFilter.GaussianBlur(S * 0.014))
    shadow = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    shadow.putalpha(sm.point(lambda v: int(v * 0.45)))
    canvas.alpha_composite(shadow)
    art.putalpha(mask)
    canvas.alpha_composite(art, (off, off))
    # Hairline edge so a black icon still reads on a dark Dock.
    edge = Image.new("RGBA", (S, S), (255, 255, 255, 0))
    k = int(SS * 2.5)
    inner = Image.new("L", (tile, tile), 0)
    inner.paste(squircle_mask(tile - 2 * k, tile - 2 * k, n=5.0), (k, k))
    ring_arr = np.array(mask, dtype=np.int16) - np.array(inner, dtype=np.int16)
    edge_alpha = Image.fromarray((ring_arr.clip(0, 255) * 0.10).astype(np.uint8), "L")
    full = Image.new("L", (S, S), 0)
    full.paste(edge_alpha, (off, off))
    edge.putalpha(full)
    canvas.alpha_composite(edge)
    return canvas.resize((size, size), Image.LANCZOS)


def preview(out_dir):
    os.makedirs(out_dir, exist_ok=True)
    names = list(VARIANTS)
    W = 560
    sheet = Image.new("RGB", (W * len(names), W * 2 + 40), (238, 238, 240))
    dark = Image.new("RGB", (W * len(names), W), (30, 30, 32))
    sheet.paste(dark, (0, W + 40))
    for i, name in enumerate(names):
        icon = render_mac(name, 1024).resize((440, 440), Image.LANCZOS)
        sheet.paste(icon, (i * W + 60, 40), icon)
        sheet.paste(icon, (i * W + 60, W + 100), icon)
        render_ios(name).save(os.path.join(out_dir, f"{name}-ios.png"))
        render_mac(name).save(os.path.join(out_dir, f"{name}-mac.png"))
        d = ImageDraw.Draw(sheet)
        d.text((i * W + 250, 10), name.upper(), fill=(90, 90, 95))
    sheet.save(os.path.join(out_dir, "icons-preview.png"))
    print(os.path.join(out_dir, "icons-preview.png"))


def build(default="blob", alternate="light"):
    """Writes the default icon (AppIcon) and the alternate one for both apps."""
    root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    info = {"info": {"version": 1, "author": "xcode"}}
    # macOS: the default app icon, plus the alternate as an image Blob applies at runtime.
    mac_assets = os.path.join(root, "Blob/Assets.xcassets")
    mac_dir = os.path.join(mac_assets, "AppIcon.appiconset")
    os.makedirs(mac_dir, exist_ok=True)
    master = render_mac(default, 1024)
    images = []
    for pt in (16, 32, 128, 256, 512):
        for scale in (1, 2):
            px = pt * scale
            name = f"icon_{pt}x{pt}{'@2x' if scale == 2 else ''}.png"
            master.resize((px, px), Image.LANCZOS).save(os.path.join(mac_dir, name))
            images.append({"idiom": "mac", "size": f"{pt}x{pt}", "scale": f"{scale}x", "filename": name})
    write_json(os.path.join(mac_dir, "Contents.json"), {"images": images, **info})
    alt_dir = os.path.join(mac_assets, "IconLight.imageset")
    os.makedirs(alt_dir, exist_ok=True)
    render_mac(alternate, 1024).save(os.path.join(alt_dir, "icon-light.png"))
    write_json(os.path.join(alt_dir, "Contents.json"),
               {"images": [{"idiom": "universal", "filename": "icon-light.png"}], **info})
    write_json(os.path.join(mac_assets, "Contents.json"), info)
    # iOS: AppIcon plus the alternate AppIconLight.
    ios_assets = os.path.join(root, "iOS/BlobPhone/Assets.xcassets")
    for set_name, variant in (("AppIcon", default), ("AppIconLight", alternate)):
        d = os.path.join(ios_assets, f"{set_name}.appiconset")
        os.makedirs(d, exist_ok=True)
        render_ios(variant).save(os.path.join(d, "icon-1024.png"))
        write_json(os.path.join(d, "Contents.json"), {
            "images": [{"idiom": "universal", "platform": "ios", "size": "1024x1024", "filename": "icon-1024.png"}],
            **info,
        })
    # Small previews for the in-app pickers.
    for set_name, variant in (("IconPreviewBlob", default), ("IconPreviewLight", alternate)):
        for assets, render in ((ios_assets, render_ios), (mac_assets, render_mac)):
            d = os.path.join(assets, f"{set_name}.imageset")
            os.makedirs(d, exist_ok=True)
            render(variant, 1024).resize((180, 180), Image.LANCZOS).save(os.path.join(d, "preview.png"))
            write_json(os.path.join(d, "Contents.json"),
                       {"images": [{"idiom": "universal", "filename": "preview.png"}], **info})
    write_json(os.path.join(ios_assets, "Contents.json"), info)
    print(f"Wrote icons: default {default}, alternate {alternate}")


def write_json(path, obj):
    with open(path, "w") as f:
        json.dump(obj, f, indent=2)
        f.write("\n")


if __name__ == "__main__":
    if len(sys.argv) >= 3 and sys.argv[1] == "preview":
        preview(sys.argv[2])
    elif len(sys.argv) >= 2 and sys.argv[1] == "build":
        build(*sys.argv[2:4])
    else:
        print(__doc__)
