// Run after build-web.ps1 and npm install --prefix artifacts/browser-check playwright.
const { chromium } = require('../artifacts/browser-check/node_modules/playwright');
const http = require('node:http');
const fs = require('node:fs/promises');
const path = require('node:path');
const assert = require('node:assert/strict');
const root = path.resolve(__dirname, '../app/build/web');
const types = { '.html':'text/html', '.js':'text/javascript', '.json':'application/json', '.wasm':'application/wasm', '.png':'image/png', '.otf':'font/otf', '.ttf':'font/ttf' };
const server = http.createServer(async (req, res) => {
  try {
    const pathname = decodeURIComponent(new URL(req.url, 'http://localhost').pathname);
    const file = path.resolve(root, '.' + (pathname === '/' ? '/index.html' : pathname));
    if (!file.startsWith(root + path.sep)) { res.writeHead(403).end(); return; }
    res.setHeader('Content-Type', types[path.extname(file)] || 'application/octet-stream');
    res.setHeader('Cache-Control', 'no-cache');
    res.end(await fs.readFile(file));
  } catch { res.writeHead(404).end(); }
});

(async () => {
  await new Promise(resolve => server.listen(8088, '127.0.0.1', resolve));
  const browser = await chromium.launch({channel:'chrome', headless:true});
  const context = await browser.newContext({ viewport:{width:390,height:844}, deviceScaleFactor:1, isMobile:true, hasTouch:true });
  const page = await context.newPage();
  page.setDefaultTimeout(15000);
  const errors = [];
  page.on('pageerror', e => errors.push(e.message));
  const place = {id:'fixture-place',name:'Địa điểm kiểm thử',address:'Địa chỉ kiểm thử',location:{lat:21.0288,lng:105.852},mapsUri:'https://www.google.com/maps',openingHoursText:null,openNow:null,nextOpenAt:null,priceLevel:null,rating:null,userRatingCount:null,fetchedAt:'2026-11-03T00:00:00Z'};
  const tour = {id:'fixture-tour',cityId:'hanoi',duration:'OneHour',interests:['History'],variant:0,start:'FirstStop',stops:[{order:1,place,stayMinutes:20,narration:[{kind:'History',text:'Lời dẫn kiểm thử offline.',sources:[]}]}],legs:[],totalMinutes:20,generatedAt:'2026-11-03T00:00:00Z'};
  await context.route('**/api/**', async route => {
    const url = route.request().url();
    const body = url.includes('/places/') ? place : url.endsWith('/cities') ? [{id:'hanoi',name:'Hà Nội',center:place.location}] : url.includes('/geocode') ? [{label:place.name,location:place.location,cityId:'hanoi'}] : url.includes('/areas') ? [place] : url.endsWith('/suggestions') ? {cityId:'hanoi',items:[{place,reason:'Dữ liệu kiểm thử.',distanceMeters:100}],canExpandRadius:true} : tour;
    await route.fulfill({status:200,contentType:'application/json',body:JSON.stringify(body)});
  });
  try {
    await page.goto('http://127.0.0.1:8088/');
    // Flutter exposes an explicit accessibility opt-in element in web builds.
    await page.locator('flt-semantics-placeholder').evaluate(el => el.click());
    await page.getByRole('textbox', {name:'Địa chỉ / khu vực'}).fill('Hồ Hoàn Kiếm');
    await page.getByRole('button', {name:'Tìm khu vực',exact:true}).click();
    await page.getByRole('button', {name:/^Địa điểm kiểm thử/}).click();
    await page.getByRole('button', {name:'Gợi ý cho tôi',exact:true}).click();
    await page.getByRole('button', {name:/^Địa điểm kiểm thử/}).click();
    await page.getByRole('button', {name:'Lưu',exact:true}).click();
    await page.getByRole('button', {name:'Đã lưu',exact:true}).waitFor();
    await page.screenshot({path:path.resolve(__dirname,'../artifacts/place-mobile.png')});
    await page.goBack();
    await page.getByRole('tab', {name:'Tour',exact:true}).click();
    await page.getByRole('button', {name:'Tạo tour',exact:true}).click();
    await page.getByRole('button', {name:'Lưu',exact:true}).click();
    await page.getByRole('button', {name:'Đã lưu',exact:true}).waitFor();
    await page.evaluate(async () => { await navigator.serviceWorker.ready; });
    const stored = await page.evaluate(() => localStorage.getItem('flutter.saved_items_v1'));
    assert.ok(stored && !stored.includes('Địa điểm kiểm thử') && !stored.includes('Địa chỉ kiểm thử'));
    await page.waitForFunction(() => navigator.serviceWorker.controller !== null);
    await context.unroute('**/api/**');
    await context.setOffline(true);
    await page.reload();
    await page.locator('flt-semantics-placeholder').evaluate(el => el.click());
    await page.getByRole('tab', {name:'Đã lưu',exact:true}).click();
    await page.getByRole('button', {name:/^Tour Hà Nội/}).waitFor();
    await page.screenshot({path:path.resolve(__dirname,'../artifacts/saved-offline-mobile.png')});
    await page.getByRole('button', {name:/^Tour Hà Nội/}).click();
    await page.getByText('1 điểm dừng • 20 phút', {exact:true}).waitFor();
    await page.getByRole('button', {name:/Cần kết nối mạng để xem tên/}).click();
    await page.getByText('Lời dẫn kiểm thử offline.', {exact:true}).waitFor();
    await page.goBack();
    await page.goBack();
    await page.getByRole('button', {name:/^Địa điểm đã lưu/}).click();
    await page.getByRole('button', {name:'Đã lưu',exact:true}).click();
    await page.getByRole('button', {name:'Lưu',exact:true}).waitFor();
    assert.deepEqual(errors, []);
    console.log('PASS: mobile suggestions, save place/tour, service worker, offline reload/details, unsave. API responses were fixtures, not live providers.');
  } catch (error) {
    console.error(await page.locator('body').ariaSnapshot());
    await page.screenshot({path:path.resolve(__dirname,'../artifacts/browser-failure.png')});
    throw error;
  } finally { await browser.close(); server.close(); }
})().catch(e => { console.error(e); server.close(); process.exitCode=1; });
