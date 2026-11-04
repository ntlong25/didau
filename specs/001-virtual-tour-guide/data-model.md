# Data Model: Hướng dẫn viên tour ảo & gợi ý địa điểm

## Domain (DiDau.Core)

### City
| Field | Type | Notes |
|-------|------|-------|
| id | string | `hanoi`, `hcmc`, `dalat`, `nhatrang`, `danang` |
| name | string | Tên tiếng Việt |
| center | GeoPoint | |
| boundary | GeoPoint[] | Đa giác rút gọn; dùng cho `CityLocator` |

### Place
| Field | Type | Notes |
|-------|------|-------|
| id | string | Google place ID; bắt buộc |
| name | string | Tên gốc từ nguồn |
| address | string? | Từ Places; null → "chưa có thông tin" |
| location | GeoPoint | |
| types | string[] | |
| openingHours | WeeklyHours? | Từ `regularOpeningHours` |
| priceLevel | enum? | `Inexpensive`, `Moderate`, `Expensive`, `VeryExpensive` |
| rating | decimal?, userRatingCount int? | |
| businessStatus | enum | `Operational`, `ClosedTemporarily`; `ClosedPermanently` bị loại |
| editorialSummary | string? | |
| mapsUri | string | Tham chiếu nguồn (FR-004) |
| wikidataId | string? | QID nếu ghép được |
| fetchedAt | DateTimeOffset | Không quá 7 ngày khi hiển thị (FR-014a) |

### Fact
Một dữ kiện có nguồn, dùng làm ngữ cảnh cho LLM.

| Field | Type | Notes |
|-------|------|-------|
| id | string | Ổn định trong một lần sinh, vd `f3` |
| placeId | string | |
| text | string | Đoạn trích từ nguồn |
| sourceUrl | string | URL Wikipedia/Wikidata/Google Maps |
| kind | enum | `History`, `Description`, `PlaceData` |

### SuggestionRequest (không lưu)
`location: GeoPoint`, `need: Coffee | Food | Breakfast | Dinner`, `radiusMeters: 2000..5000`, `at: DateTimeOffset`.

Validation: vị trí phải thuộc một City (FR-010a); bán kính 2000 hoặc 5000.

### Suggestion
`place: Place`, `reason: string`, `distanceMeters: int`, `openNow: bool?`, `nextOpenAt: DateTimeOffset?`.

### TourRequest
| Field | Type | Notes |
|-------|------|-------|
| cityId | string | Bắt buộc, thuộc 5 thành phố |
| areaPlaceId | string? | Điểm/khu vực nổi tiếng trong thành phố |
| duration | enum | `OneHour` (60'), `HalfDay` (240'), `FullDay` (480') |
| interests | set of `History`, `Food`, `Photo` | Ít nhất 1 |
| variant | int | 0 mặc định; tăng khi "phương án khác" (FR-026) |
| userLocation | GeoPoint? | Chỉ dùng tính đoạn đầu, không lưu (FR-006) |

### Tour
| Field | Type | Notes |
|-------|------|-------|
| id | string | = khóa cache (hash) |
| cityId, areaPlaceId, duration, interests, variant | | Từ request |
| start | `UserLocation` \| `FirstStop` | FR-023a |
| stops | TourStop[] | Có thứ tự, ≥ 1 |
| legs | Leg[] | `legs.Count == stops.Count - 1`, cộng thêm 1 nếu start = UserLocation |
| totalMinutes | int | Tổng ở lại + di chuyển; **≤ duration** (SC-004) |
| generatedAt | DateTimeOffset | |

### TourStop
`order: int`, `place: Place`, `stayMinutes: int`, `narration: NarrationSection[]`.

### NarrationSection
`kind: History | Trivia | Tips`, `text: string` (tiếng Việt), `sources: SourceRef[]` (≥ 1).

### SourceRef
`title: string`, `url: string`.

### Leg
`fromOrder: int?` (null = vị trí người dùng), `toOrder: int`, `mode: Walk | Ride`, `distanceMeters: int`, `minutes: int`, `directionsUrl: string`.

## Quy tắc kiểm tra chính (có unit test)

- `RouteBuilder`: `totalMinutes ≤ duration`; không trùng địa điểm; không có địa điểm
  `ClosedPermanently`; không đủ ứng viên → lỗi `InsufficientData` (FR-027).
- `GroundingValidator`:
  - Loại stop có `placeId` không nằm trong ngữ cảnh.
  - Loại section không có `sourceIds` hoặc có ID lạ.
  - Loại section chứa số/năm/số điện thoại không có trong các fact được trích.
- `CacheKey`: interests được sắp xếp, nên thứ tự chọn sở thích không đổi khóa; có `promptVersion`.
- `LocationRounding`: làm tròn 0,002°.
- `OpeningHours`: tính `openNow` và `nextOpenAt` theo múi giờ Asia/Ho_Chi_Minh.

## Persistence (PostgreSQL)

| Table | Key | Columns | TTL |
|-------|-----|---------|-----|
| `osm_cache` | `search:<hash>` hoặc `place:osm:{type}/{id}` | `payload jsonb` = `Place[]` từ OpenStreetMap (ODbL cho phép lưu) | tìm kiếm 24 giờ, chi tiết 7 ngày |
| `tour_cache` | `key` (text, SHA-256) | `payload jsonb` = `{ stops: [{placeId, location, order, stayMinutes, narration[]}], facts[] }` — không chứa nội dung Places khác; `created_at`, `expires_at` | 7 ngày |
| `nearby_cache` | `key` (lat/lng làm tròn + need + radius) | `place_ids text[]`, `expires_at` | 24 giờ |
| `wiki_cache` | `key` (QID hoặc lang:title) | `payload jsonb`, `expires_at` | 30 ngày |

Chi tiết Goong không lưu giữa request. Chi tiết OSM lưu trong `osm_cache`; dữ liệu lấy từ
search có thể được dùng lại cho chi tiết (TTL 24 giờ), còn truy vấn riêng có TTL 7 ngày.

Không bảng nào chứa vị trí chính xác hay định danh người dùng/thiết bị. Bản ghi hết hạn bị bỏ qua
khi đọc và được dọn bằng job định kỳ đơn giản (hosted service, mỗi ngày).

## Client (localStorage)

Key `saved_items_v1` → JSON array của `SavedItem`:

| Field | Type | Notes |
|-------|------|-------|
| id | string | `tour:<tourId>` hoặc `place:<placeId>`; duy nhất |
| kind | `tour` \| `place` | |
| title | string | |
| savedAt | ISO datetime | Danh sách sắp giảm dần (FR-032) |
| snapshot | JSON tối giản | Chỉ ID, tọa độ ≤ 30 ngày, cấu trúc tour và lời dẫn Wiki; chi tiết provider tải lại khi mở |

Tour lưu có `start=FirstStop`, bỏ leg từ vị trí cá nhân và trừ thời gian leg đó khỏi tổng.
Tên mục lưu là nhãn chung hoặc tên thành phố; không chứa tên provider. Tọa độ hết hạn thì bỏ
URL chỉ đường; hydrate online tạo lại URL từ tọa độ vừa tải. Snapshot cũ được compact khi mở Đã lưu.

Trạng thái: chưa lưu → đã lưu (thêm) → chưa lưu (xóa). Lưu lại cùng `id` thì ghi đè bản chụp.
