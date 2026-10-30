#!/usr/bin/env python3
"""Rasterize actual ANSI frames from render_terminal_screens.cr.
Requires Pillow, pyte and DejaVu Sans Mono. No UI content is synthesized here.
"""
from pathlib import Path
from html import escape
import zipfile
import os
import pyte
from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[1]
OUT = Path(os.environ.get('AZU_PREVIEW_DIR', '/tmp/azu-cli-previews/new-screens'))
IMAGES = ROOT / 'docs/assets/terminal-ui/new-screens'
COLS, ROWS = 136, 40
CW, CH, PAD, TOP = 11, 22, 24, 58
BG, FG = '#0b0e14', '#c9d1d9'
FONTS = Path('/usr/share/fonts/truetype/dejavu')
regular = ImageFont.truetype(str(FONTS / 'DejaVuSansMono.ttf'), 18)
bold = ImageFont.truetype(str(FONTS / 'DejaVuSansMono-Bold.ttf'), 18)
symbols = ImageFont.truetype(str(FONTS / 'DejaVuSans.ttf'), 18)
label = ImageFont.truetype(str(FONTS / 'DejaVuSansMono.ttf'), 15)
SCREENS = [
    ('joobq-queues', 'azu joobq / Queues & Workers'),
    ('joobq-workflows', 'azu joobq / Workflows'),
    ('joobq-dlq', 'azu joobq / DLQ & Retries'),
    ('dev-errors', 'azu dev / Errors'),
    ('dev-errors-stack', 'azu dev / Errors / Scrolled stack trace'),
    ('dev-sql', 'azu dev / SQL'),
    ('dev-sql-n-plus-one', 'azu dev / SQL / N+1 warning'),
]
NAMED = {'black':'#000000','red':'#f87171','green':'#34d399','yellow':'#fbbf24','blue':'#60a5fa','magenta':'#a78bfa','cyan':'#22d3ee','white':FG}
def color(value, default):
    if len(value) == 6 and all(c in '0123456789abcdefABCDEF' for c in value):
        return '#' + value
    return NAMED.get(value, default)

for name, title in SCREENS:
    screen = pyte.Screen(COLS, ROWS)
    pyte.Stream(screen).feed((OUT / f'{name}.ansi').read_text())
    img = Image.new('RGB', (COLS * CW + PAD * 2, ROWS * CH + TOP + PAD), BG)
    draw = ImageDraw.Draw(img)
    draw.text((PAD, 14), title, font=label, fill='#c9d1d9')
    note = 'ACTUAL UI RENDER / ILLUSTRATIVE DATA'
    draw.text((img.width-PAD-draw.textlength(note,font=label),14),note,font=label,fill='#8b949e')
    draw.line((PAD, 42, img.width-PAD, 42), fill='#2a313c')
    for y in range(ROWS):
        for x in range(COLS):
            cell = screen.buffer[y][x]
            fg, bg = color(cell.fg, FG), color(cell.bg, BG)
            if cell.reverse:
                fg, bg = bg, fg
            left, top = PAD + x * CW, TOP + y * CH
            draw.rectangle((left, top, left+CW-1, top+CH-1), fill=bg)
            font = symbols if any(0x2800 <= ord(c) <= 0x28ff for c in cell.data) else (bold if cell.bold else regular)
            draw.text((left, top+17), cell.data, font=font, fill=fg, anchor='ls')
            if cell.underscore:
                draw.line((left,top+20,left+CW-1,top+20),fill=fg)
    img.save(IMAGES / f'{name}.png')

# A local, responsive gallery plus original-resolution PNGs in one download.
html = '''<!doctype html><html lang="en"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>Azu terminal screens</title><style>body{background:#0b0e14;color:#c9d1d9;font:16px system-ui;margin:32px auto;max-width:1600px;padding:0 20px}h1{font-size:28px}p{color:#8b949e}nav{display:flex;gap:16px;flex-wrap:wrap}a{color:#22d3ee}figure{margin:40px 0}img{width:100%;height:auto;border:1px solid #2a313c;border-radius:8px}figcaption{margin-bottom:12px;font-size:18px}</style>
<h1>Azu terminal screens</h1><p>Actual Crystal UI components rendered at 136 × 40 cells with illustrative fixtures. No live application data or stores were accessed.</p><nav>'''
html += ''.join(f'<a href="#{name}">{escape(title)}</a>' for name,title in SCREENS)
html += '</nav>' + ''.join(f'<figure id="{name}"><figcaption>{escape(title)}</figcaption><a href="{name}.png"><img src="{name}.png" alt="{escape(title)}" loading="lazy"></a></figure>' for name,title in SCREENS)
html += '<p><a href="terminal-screens.zip">Download all PNGs</a></p></html>'
(OUT / 'index.html').write_text(html)
with zipfile.ZipFile(OUT / 'terminal-screens.zip', 'w', compression=zipfile.ZIP_DEFLATED) as archive:
    for name,_ in SCREENS:
        archive.write(IMAGES / f'{name}.png', f'{name}.png')
    archive.write(OUT / 'index.html','index.html')
for path in OUT.iterdir():
    if path.is_file():
        path.chmod(0o644)
print(f'Rendered {len(SCREENS)} PNGs, gallery and ZIP in {OUT}')
