#!/usr/bin/env python3
"""Verify/rebuild owner-approved registered Mill/Greystone assets without generative editing.

Requires Pillow and NumPy. Default is read-only; --write updates the four existing
asset slots. No changes to app layout, catalog references or unlock state.
"""
import argparse
import hashlib
import json
from pathlib import Path

import numpy as np
from PIL import Image
from PIL.PngImagePlugin import PngInfo

ROOT = Path(__file__).resolve().parents[1]
CATALOG = ROOT / 'CranfordHistoricalAR/Assets.xcassets'


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--write', action='store_true', help='Rebuild the existing app asset files')
    parser.add_argument('--landmark', choices=['mill', 'greystone'], default='mill', help='Approved artwork collection (default: mill)')
    args = parser.parse_args()
    SOURCE = ROOT / 'artwork' / args.landmark
    manifest = json.loads((SOURCE / 'manifest.json').read_text())
    size = tuple(manifest['canvas'])
    for filename, expected in manifest['source_files'].items():
        actual = hashlib.sha256((SOURCE / filename).read_bytes()).hexdigest()
        if actual != expected:
            raise ValueError(f'Approved source changed: {filename}. Obtain approval before updating the manifest.')
    layers = {name: Image.open(SOURCE / f'{name}.png').convert('RGBA')
              for name in ['INK_MASTER', 'SUBJECT_BASE', 'WHITE_RESERVES', 'WATERCOLOR_UNDERLAY']}
    mask = Image.open(SOURCE / 'ARTWORK_MASK.png').convert('L')
    if any(layer.size != size for layer in list(layers.values()) + [mask]):
        raise ValueError('Every layer must retain the full approved canvas')
    if hashlib.sha256(layers['INK_MASTER'].tobytes()).hexdigest() != manifest['ink_master_raw_rgba_sha256']:
        raise ValueError('Canonical ink pixels changed')
    if hashlib.sha256(mask.tobytes()).hexdigest() != manifest['alpha_raw_sha256']:
        raise ValueError('Canonical alpha mask changed')

    def composite(painted):
        # Opaque internal subject base; the single canonical final mask is applied last.
        image = layers['SUBJECT_BASE'].convert('RGB').convert('RGBA')
        if painted:
            image.alpha_composite(layers['WATERCOLOR_UNDERLAY'])
        image.alpha_composite(layers['WHITE_RESERVES'])
        image.alpha_composite(layers['INK_MASTER'])
        image.putalpha(mask)
        pixels = np.asarray(image).copy()
        if manifest.get('clear_transparent_rgb', True):
            pixels[np.asarray(mask) == 0, :3] = 0
        return Image.fromarray(pixels)

    ink, watercolor = composite(False), composite(True)
    if ink.getchannel('A').tobytes() != watercolor.getchannel('A').tobytes():
        raise ValueError('Ink and watercolor alpha must match byte-for-byte')
    home = Image.new('RGBA', tuple(manifest['home_canvas']), (0, 0, 0, 0))
    offset = tuple(manifest['home_ink_offset'])
    home.paste(ink, offset)  # Copy bytes; no scaling, cropping or alpha recompositing.
    crop = home.crop((offset[0], offset[1], offset[0] + size[0], offset[1] + size[1]))
    if crop.tobytes() != ink.tobytes():
        raise ValueError('Home padding must not change the authoritative ink drawing')
    expected_assets = {f'home-sketch-{args.landmark}': home, f'stop-ink-{args.landmark}': ink,
                       f'sketchbook-{args.landmark}': watercolor, f'{args.landmark}-map-landmark': watercolor}
    for name, expected in expected_assets.items():
        folder = CATALOG / f'{name}.imageset'
        catalog = json.loads((folder / 'Contents.json').read_text())
        filenames = {entry['filename'] for entry in catalog['images'] if 'filename' in entry}
        if filenames != {f'{name}.png'}:
            raise ValueError(f'Unexpected asset registration: {name}')
        target = folder / f'{name}.png'
        if args.write:
            metadata = PngInfo()
            metadata.add(b'sRGB', bytes([0]))
            expected.save(target, pnginfo=metadata)
        installed = Image.open(target)
        if installed.mode != 'RGBA' or installed.size != expected.size or installed.tobytes() != expected.tobytes():
            raise ValueError(f'App asset differs from approved master: {name}')
        if installed.info.get('srgb') != 0:
            raise ValueError(f'Missing consistent sRGB interpretation: {name}')
        print(f'{name}: {expected.width}x{expected.height}, RGBA, exact approved pixels')
    print('PASS: unchanged canonical ink; zero differing alpha pixels; Home padding only; all four asset slots verified.')


if __name__ == '__main__':
    main()
