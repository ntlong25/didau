// Optional local API fixture for manually exploring the Android emulator.
// No external API calls. Stop this server before starting the real backend.
const http = require('node:http');
const place = {
  id: 'osm:node/42', name: 'Địa điểm demo (dữ liệu kiểm thử)',
  address: 'Địa chỉ giả lập để kiểm thử giao diện',
  location: {lat: 21.0288, lng: 105.852},
  mapsUri: 'https://www.openstreetmap.org/',
};
const server = http.createServer(async (req, res) => {
  for await (const chunk of req) { /* drain request */ }
  const path = new URL(req.url, 'http://localhost').pathname;
  let body;
  if (path === '/api/cities') body = [{id: 'hanoi', name: 'Hà Nội', center: place.location}];
  else if (path === '/api/geocode') body = [{label: place.name, location: place.location}];
  else if (path.endsWith('/areas')) body = [place];
  else if (path.startsWith('/api/places/')) body = place;
  else if (path === '/api/suggestions') body = {
    cityId: 'hanoi', canExpandRadius: true,
    items: [{place, reason: 'Kết quả giả lập để kiểm thử ứng dụng Android.', distanceMeters: 100}],
  };
  else if (path === '/api/tours') body = {
    id: 'demo-tour', cityId: 'hanoi', variant: 0, start: 'FirstStop', totalMinutes: 20, legs: [],
    stops: [{order: 1, place, stayMinutes: 20, narration: [
      {kind: 'History', text: 'Đây là lời dẫn giả lập để kiểm thử lưu và đọc offline, không phải thông tin về địa điểm thật.', sources: []},
    ]}],
  };
  else { res.writeHead(404).end(); return; }
  res.writeHead(200, {'Content-Type': 'application/json; charset=utf-8'});
  res.end(JSON.stringify(body));
});
server.listen(5000, '127.0.0.1', () => console.log('Android FIXTURE API on :5000 — all data is synthetic. Ctrl+C to stop.'));
