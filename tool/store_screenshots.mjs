// Generates App Store / Play Store screenshots from the demo web build.
// Usage: node tool/store_screenshots.mjs <baseUrl> <outDir>
// Sizes: iPhone 6.9" (1290x2796) and Android phone (1080x2340, 9:19.5).
import { chromium } from 'playwright';
import fs from 'node:fs';

const [base, out] = process.argv.slice(2);
fs.mkdirSync(out, { recursive: true });

const shots = [
  ['01-kesfet', '#/'],
  ['02-saha-detay', '#/venue/demo-venue-1'],
  ['03-maclarim', '#/matches'],
  ['04-favoriler', '#/favorites'],
  ['05-destek', '#/support'],
  ['06-profil', '#/profile'],
];
const devices = [
  { name: 'ios-6.9', width: 430, height: 932, scale: 3 },     // 1290 x 2796
  { name: 'android', width: 360, height: 780, scale: 3 },     // 1080 x 2340
];

const browser = await chromium.launch();
for (const d of devices) {
  for (const scheme of ['light', 'dark']) {
    const ctx = await browser.newContext({
      viewport: { width: d.width, height: d.height }, deviceScaleFactor: d.scale,
      isMobile: true, hasTouch: true, colorScheme: scheme, locale: 'tr-TR',
    });
    const page = await ctx.newPage();
    for (const [name, hash] of shots) {
      await page.goto(base + '?shots=1' + hash, { waitUntil: 'networkidle' });
      await page.waitForTimeout(6000);
      await page.screenshot({ path: `${out}/${d.name}-${scheme}-${name}.png` });
    }
    await ctx.close();
  }
}
await browser.close();
const files = fs.readdirSync(out).filter(f => f.endsWith('.png'));
fs.writeFileSync(`${out}/index.html`, `<!doctype html><meta charset="utf-8"><title>Rövanş mağaza görselleri</title>
<style>body{font-family:system-ui;margin:24px}img{height:420px;margin:6px;border:1px solid #ddd;border-radius:8px}</style>
<h1>Rövanş · mağaza ekran görüntüleri</h1><p>Sağ tık → farklı kaydet. Boyutlar: iOS 6.9" 1290×2796, Android 1080×2340.</p>
${files.map(f => `<a href="${f}"><img src="${f}" alt="${f}"></a>`).join('\n')}`);
console.log(`screenshots: ${files.length}`);
