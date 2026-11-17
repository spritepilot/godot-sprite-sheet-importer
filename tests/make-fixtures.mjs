// Makes the test fixtures: real exports from spritepilot.com (a 6 frame GIF,
// trimmed, three tags), saved in all five formats. Needs Node with
// @playwright/test and gifenc installed. Usage: node tests/make-fixtures.mjs <out-dir>
import { chromium } from '@playwright/test'
import * as gifenc from 'gifenc'
import { writeFileSync, mkdirSync } from 'node:fs'
const { GIFEncoder } = gifenc.default ?? gifenc
const OUT = process.argv[2]
mkdirSync(OUT, { recursive: true })

function gif() {
  const g = GIFEncoder()
  const palette = [[0, 0, 0], [230, 60, 60], [60, 200, 90], [60, 110, 230], [240, 200, 40], [200, 80, 220], [40, 200, 210]]
  const delays = [100, 100, 300, 100, 100, 200]
  delays.forEach((delay, i) => {
    const px = new Uint8Array(24 * 24)
    const x0 = 2 + i * 2, y0 = 3 + (i % 3) * 3, w = 8 + (i % 2) * 4, h = 10
    for (let y = y0; y < y0 + h; y++) for (let x = x0; x < x0 + w; x++) px[y * 24 + x] = i + 1
    g.writeFrame(px, 24, 24, { palette, delay, transparent: true, transparentIndex: 0, dispose: 2 })
  })
  g.finish()
  return Buffer.from(g.bytes())
}

const browser = await chromium.launch({ args: ['--host-resolver-rules=MAP www.googletagmanager.com 127.0.0.1, MAP www.google-analytics.com 127.0.0.1, MAP region1.google-analytics.com 127.0.0.1, MAP pagead2.googlesyndication.com 127.0.0.1'] })
const page = await browser.newPage({ acceptDownloads: true })
await page.goto('https://spritepilot.com/gif-to-sprite-sheet')
await page.locator('input[type=file]').setInputFiles({ name: 'hero.gif', mimeType: 'image/gif', buffer: gif() })
await page.getByText(/6 frames/).first().waitFor()
await page.getByRole('button', { name: 'Send to Export & Download', exact: true }).click()
await page.getByLabel('Trim transparency').check()
// three tags
const tagsToggle = page.getByRole('button', { name: /Animation Tags/ })
await tagsToggle.click()
const tags = [['walk', 0, 3, 'forward'], ['hit', 3, 5, 'pingpong'], ['back', 0, 2, 'reverse']]
for (let t = 0; t < tags.length; t++) {
  await page.getByRole('button', { name: 'Add Tag' }).click()
  const row = page.locator('input[placeholder="tag name"]').nth(t)
  await row.fill(tags[t][0])
  const nums = page.locator('input[type=number]')
  await nums.nth(t * 2).fill(String(tags[t][1]))
  await nums.nth(t * 2 + 1).fill(String(tags[t][2]))
  await page.locator('select').filter({ has: page.locator('option[value=pingpong]') }).nth(t).selectOption(tags[t][3])
}
const formats = [['TexturePacker', 'tp'], ['Phaser', 'phaser'], ['Godot JSON', 'godot'], ['SpriteFrames', 'spriteframes'], ['Aseprite JSON', 'aseprite']]
for (const [label] of formats) {
  await page.getByRole('button', { name: new RegExp(`^${label}`) }).click()
  const got = []
  page.on('download', d => got.push(d))
  await page.getByRole('button', { name: /Download Sprite Sheet/ }).click()
  await page.waitForTimeout(2500)
  page.removeAllListeners('download')
  for (const d of got) { await d.saveAs(`${OUT}/${d.suggestedFilename()}`); console.log(label, '->', d.suggestedFilename()) }
}
await browser.close()
