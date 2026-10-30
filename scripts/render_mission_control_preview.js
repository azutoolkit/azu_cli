// Rasterize actual Crystal frames. Requires Node and Playwright with Chromium.
const fs = require('fs');
const path = require('path');
const { chromium } = require('playwright');
const dir = process.env.AZU_PREVIEW_DIR || '/tmp/azu-cli-previews/mission-control';
const images = path.resolve(__dirname, '../docs/assets/terminal-ui/mission-control');
fs.mkdirSync(images, {recursive:true});
const escape = s => s.replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;').replace(/"/g, '&quot;');
function ansiHtml(input) {
  let out = '', offset = 0, style = {};
  const append = text => { if (text) out += `<span style="${Object.entries(style).map(([k,v])=>`${k}:${v}`).join(';')}">${Array.from(text).map(c => c === "\n" ? "\n" : c === "\r" ? "" : `<span class="cell">${escape(c)}</span>`).join("")}</span>`; };
  for (const match of input.matchAll(/\x1b\[([0-9;]*)m/g)) {
    append(input.slice(offset, match.index));
    const codes = match[1].split(';').map(Number);
    for (let i = 0; i < codes.length; i++) {
      const code = codes[i];
      if (code === 0) style = {};
      else if (code === 1) style['font-weight'] = 'bold';
      else if (code === 2) style.opacity = '0.7';
      else if (code === 3) style['font-style'] = 'italic';
      else if (code === 4) style['text-decoration'] = 'underline';
      else if ((code === 38 || code === 48) && codes[i+1] === 2) {
        style[code === 38 ? 'color' : 'background-color'] = `rgb(${codes.slice(i+2,i+5).join(',')})`;
        i += 4;
      }
    }
    offset = match.index + match[0].length;
  }
  append(input.slice(offset));
  return out;
}
(async () => {
  const browser = await chromium.launch({headless:true,executablePath:process.env.CHROMIUM_PATH || undefined,args:['--no-sandbox']});
  const page = await browser.newPage({viewport:{width:1440,height:1000},deviceScaleFactor:1});
  for (const name of ['overview', 'sql', 'auth', 'menu', 'production', 'compact', 'hints', 'tracing', 'cache', 'mailers', 'generators', 'serve', 'doctor']) {
    const html = `<!doctype html><html lang="en"><meta charset="utf-8"><title>Azu ${name} — actual terminal frame, sample data</title><style>body{margin:0;background:#0b0e14;color:#e6edf3;padding:12px;width:max-content}pre{font:16px/20px 'DejaVu Sans Mono',monospace;margin:0;white-space:pre}.cell{display:inline-block;width:1ch;height:20px;line-height:20px;text-align:center;vertical-align:top;background-color:inherit}</style><pre>${ansiHtml(fs.readFileSync(path.join(dir,name+'.ansi'),'utf8'))}</pre></html>`;
    const output = path.join(dir, name+'-theme-preview.html');
    fs.writeFileSync(output,html);
    await page.setContent(html);
    await page.locator('body').screenshot({path:path.join(images,name+'-theme-preview.png')});
  }
  await browser.close();
  console.log('Rendered SQL and navigation previews from actual ANSI frames.');
})();
