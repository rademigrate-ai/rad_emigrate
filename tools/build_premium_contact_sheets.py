"""Labelled, resized review indexes; original screenshot PNGs remain intact."""
import os
from pathlib import Path
from PIL import Image, ImageDraw, ImageOps

OUT = Path(os.environ.get('RAD_QA_OUTPUT', 'docs/qa/pr54/redesign'))
for size in ['mobile', 'tablet', 'desktop']:
    for locale in ['en', 'fa']:
        for theme in ['light', 'dark']:
            prefix = f'{size}-{locale}-{theme}'
            paths = sorted(OUT.glob(prefix + '-*.png'))
            paths = [p for p in paths if not p.stem.endswith('-overview')]
            if not paths:
                continue
            width, height = {'mobile': (210, 455), 'tablet': (210, 280), 'desktop': (320, 200)}[size]
            columns = 5
            sheet = Image.new('RGB', (columns * width, 60 + ((len(paths) + 4) // 5) * (height + 30)), '#e7ebf0')
            draw = ImageDraw.Draw(sheet)
            draw.text((12, 16), f'{prefix} | Actual Flutter fixture screenshots (resized index)', fill='#17202b')
            for index, path in enumerate(paths):
                x, y = (index % columns) * width, 60 + (index // columns) * (height + 30)
                draw.text((x + 5, y + 5), path.stem[len(prefix) + 1:], fill='#17202b')
                with Image.open(path) as source:
                    thumbnail = ImageOps.contain(source.convert('RGB'), (width - 8, height - 8))
                    sheet.paste(thumbnail, (x + (width - thumbnail.width) // 2, y + 30))
            sheet.save(OUT / f'{prefix}-overview.jpg', quality=90)
