---

description: "Task list for feature 001-virtual-tour-guide"
---

# Tasks: Hướng dẫn viên tour ảo & gợi ý địa điểm

**Input**: Design documents from `/specs/001-virtual-tour-guide/`

**Prerequisites**: plan.md, spec.md, research.md, data-model.md, contracts/api.yaml, quickstart.md

**Tests**: CÓ. Constitution (Nguyên tắc II, III) và người dùng yêu cầu unit test cho dựng lộ trình,
xử lý prompt và grounding, mock mọi API ngoài. Test đặt trong `backend/tests/DiDau.Core.Tests/`,
viết trước và phải FAIL trước khi cài đặt.

**Organization**: Nhóm theo user story để mỗi story làm và kiểm tra độc lập.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Chạy song song được (khác file, không phụ thuộc task chưa xong)
- **[Story]**: US1 = Gợi ý nhanh, US2 = Tour tham quan, US3 = Đã lưu

## Path Conventions

- Backend: `backend/src/DiDau.Api/`, `backend/src/DiDau.Core/`, `backend/src/DiDau.Infrastructure/`, `backend/tests/DiDau.Core.Tests/`
- App: `app/lib/`, `app/web/`, `app/test/`

---

## Phase 1: Setup (Shared Infrastructure)

- [X] T001 Tạo solution `backend/DiDau.sln` với các project net8.0: `backend/src/DiDau.Api` (web), `backend/src/DiDau.Core` (classlib, không tham chiếu ASP.NET/EF), `backend/src/DiDau.Infrastructure` (classlib, tham chiếu Core), `backend/tests/DiDau.Core.Tests` (xUnit + NSubstitute, tham chiếu Core); bật `<Nullable>enable</Nullable>` và `<TreatWarningsAsErrors>true</TreatWarningsAsErrors>` trong `backend/Directory.Build.props`
- [X] T002 [P] Tạo app Flutter `app/` (`flutter create --platforms=web app`), thêm dependency `http`, `geolocator`, `shared_preferences`, `url_launcher` vào `app/pubspec.yaml`; đặt `name`/`short_name` "Đi Đâu", `lang: vi` trong `app/web/manifest.json`
- [X] T003 [P] Thêm `.gitignore` gốc (bin/obj, `app/build`, `.dart_tool`, `appsettings.Development.json`, `*.user`) tại `.gitignore`
- [X] T004 [P] Tạo `backend/src/DiDau.Api/appsettings.Example.json` với các khóa rỗng `GooglePlaces:ApiKey`, `OpenAi:ApiKey`, `OpenAi:Model`, `ConnectionStrings:Default`, `Cors:AllowedOrigins`, `Narration:PromptVersion` (không chứa giá trị thật — Nguyên tắc IV)
- [X] T005 [P] Thêm `docker-compose.yml` ở gốc với service `postgres:16` (port 5432, DB `didau`) cho dev

---

## Phase 2: Foundational (Blocking Prerequisites)

**⚠️ CRITICAL**: Xong phase này mới làm được user story.

### Domain chung & abstractions

- [X] T006 [P] Tạo `GeoPoint` (record lat/lng) và `Geo.HaversineMeters(a, b)` trong `backend/src/DiDau.Core/Geo/GeoPoint.cs`
- [X] T007 [P] Tạo `Place` record theo data-model.md trong `backend/src/DiDau.Core/Places/Place.cs`: `id` bắt buộc; `address` nullable ("null → 'chưa có thông tin'"); `priceLevel` enum `Inexpensive|Moderate|Expensive|VeryExpensive` nullable; `businessStatus` enum `Operational|ClosedTemporarily|ClosedPermanently`; `openingHours` (WeeklyHours?); `mapsUri`; `wikidataId?`; `fetchedAt`
- [X] T008 [P] Tạo `WeeklyHours` và `OpeningHours.Evaluate(hours, at)` trả `openNow`/`nextOpenAt` theo múi giờ `Asia/Ho_Chi_Minh` trong `backend/src/DiDau.Core/Places/OpeningHours.cs`
- [X] T009 [P] Tạo `City` + cấu hình tĩnh 5 thành phố (`hanoi`, `hcmc`, `dalat`, `nhatrang`, `danang`: tên tiếng Việt, tâm, đa giác ranh giới rút gọn) và `CityLocator.Find(GeoPoint) → City?` (point-in-polygon) trong `backend/src/DiDau.Core/Cities/`
- [X] T010 [P] Tạo interfaces trong `backend/src/DiDau.Core/Abstractions/`: `IPlacesClient` (NearbySearch, TextSearch, GetDetails), `IWikiClient` (FindByNameNear, GetSummary), `INarrationClient` (GenerateAsync(prompt, schema)), `ICacheStore` (Get<T>/Set<T>(table, key, value, ttl)), `IClock`
- [X] T011 [P] Tạo `LocationRounding.Round(GeoPoint)` làm tròn 0,002° và `CacheKey` (SHA-256; interests được sắp xếp trước khi băm; có `promptVersion`) cùng `CacheTtl` (tour 7 ngày, place 7 ngày, nearby 24 giờ, wiki 30 ngày) trong `backend/src/DiDau.Core/Caching/`
- [X] T012 [P] Unit test `CityLocator` (Hồ Hoàn Kiếm → hanoi; Bến Thành → hcmc; Cần Thơ → null) trong `backend/tests/DiDau.Core.Tests/Cities/CityLocatorTests.cs`
- [X] T013 [P] Unit test `OpeningHours` (đang mở, đã đóng, qua nửa đêm, `nextOpenAt` hôm sau, thiếu dữ liệu → null) trong `backend/tests/DiDau.Core.Tests/Places/OpeningHoursTests.cs`
- [X] T014 [P] Unit test `LocationRounding` và `CacheKey` (thứ tự interests không đổi khóa; đổi `promptVersion`/`variant` đổi khóa; hai điểm cách < 100 m cùng ô làm tròn) trong `backend/tests/DiDau.Core.Tests/Caching/CacheKeyTests.cs`

### Persistence & API khung

- [X] T015 Tạo `DiDauDbContext` với 4 bảng theo data-model.md (`tour_cache`, `place_cache`, `nearby_cache`, `wiki_cache`; payload `jsonb`, cột `expires_at`; KHÔNG có cột tọa độ chưa làm tròn hay định danh người dùng — FR-006) trong `backend/src/DiDau.Infrastructure/Persistence/DiDauDbContext.cs`, và migration đầu tiên trong `backend/src/DiDau.Infrastructure/Persistence/Migrations/`
- [X] T016 Cài `PostgresCacheStore : ICacheStore` (bỏ qua bản ghi hết hạn khi đọc, upsert khi ghi) trong `backend/src/DiDau.Infrastructure/Persistence/PostgresCacheStore.cs` và `CacheCleanupService` (hosted service, xóa bản ghi hết hạn mỗi 24 giờ) trong `backend/src/DiDau.Infrastructure/Persistence/CacheCleanupService.cs`
- [X] T017 Cài `GooglePlacesClient : IPlacesClient` dùng Places API (New) với header `X-Goog-Api-Key` và field mask `id,displayName,formattedAddress,location,types,regularOpeningHours,priceLevel,rating,userRatingCount,businessStatus,editorialSummary,googleMapsUri`, `languageCode=vi`; map sang `Place`; bọc cache `place_cache` theo place ID trong `backend/src/DiDau.Infrastructure/GooglePlaces/GooglePlacesClient.cs`
- [X] T018 Cấu hình `backend/src/DiDau.Api/Program.cs`: DI cho Core/Infrastructure, đọc key từ cấu hình/biến môi trường (không log key), CORS theo `Cors:AllowedOrigins`, `AddRateLimiter` với policy `suggestions` (30 req/phút/IP) và `tours` (5 req/phút/IP), ProblemDetails trả `Error { code, message }` theo contracts/api.yaml (`CITY_NOT_SUPPORTED`, `INSUFFICIENT_DATA`, `VALIDATION_ERROR`, `RATE_LIMITED`, `UPSTREAM_ERROR`), `IClock` hệ thống
- [X] T019 Cài `GET /api/cities` trả 5 thành phố trong `backend/src/DiDau.Api/Endpoints/CitiesEndpoints.cs`

### App khung

- [X] T020 [P] Tạo `ApiClient` (base URL từ `--dart-define=API_BASE_URL`, parse `Error.message` để hiển thị) và model Dart theo contracts/api.yaml trong `app/lib/api/api_client.dart`, `app/lib/api/models.dart`
- [X] T021 [P] Tạo khung app: `MaterialApp` locale `vi`, bottom navigation 3 tab "Gợi ý nhanh" / "Tour" / "Đã lưu", widget dùng chung `InfoValue` hiển thị "chưa có thông tin" khi null, `ErrorRetry` (thông báo + nút thử lại) trong `app/lib/main.dart`, `app/lib/widgets/`

**Checkpoint**: `dotnet test` chạy được (test foundational xanh), `GET /api/cities` trả 5 thành phố, app mở được 3 tab trống.

---

## Phase 3: User Story 1 - Gợi ý nhanh địa điểm gần đây (Priority: P1) 🎯 MVP

**Goal**: Từ vị trí + nhu cầu, trả 3–5 địa điểm gần có lý do, giờ, giá, khoảng cách.

**Independent Test**: Tọa độ Hồ Hoàn Kiếm + `Coffee` → 3–5 quán thật đủ trường trong ≤ 5 s; tọa độ Cần Thơ → `CITY_NOT_SUPPORTED`.

### Tests for User Story 1

- [X] T022 [P] [US1] Unit test `SuggestionService` với `IPlacesClient`, `ICacheStore`, `IClock` mock trong `backend/tests/DiDau.Core.Tests/Suggestions/SuggestionServiceTests.cs`: ngoài 5 thành phố → lỗi `CitiesNotSupported`; loại `ClosedPermanently`; `Breakfast` lúc 21:00 chỉ trả nơi phục vụ bữa sáng và có `nextOpenAt`; ưu tiên đang mở; tối đa 5 kết quả sắp theo điểm phù hợp rồi khoảng cách; < 3 kết quả ở 2000 m → `canExpandRadius = true`, ở 5000 m → `false`; khóa `nearby_cache` dùng tọa độ đã làm tròn
- [X] T023 [P] [US1] Unit test `ReasonBuilder` trong `backend/tests/DiDau.Core.Tests/Suggestions/ReasonBuilderTests.cs`: lý do chỉ ghép từ `editorialSummary`/rating/số đánh giá/đang mở có trong dữ liệu; không có dữ liệu → câu trung tính không chứa con số

### Implementation for User Story 1

- [X] T024 [P] [US1] Tạo `SuggestionRequest` (`need` enum `Coffee|Food|Breakfast|Dinner`; `radiusMeters` chỉ nhận `2000` hoặc `5000`, mặc định 2000) và `Suggestion`, `SuggestionResult` (`cityId`, `items` maxItems 5, `canExpandRadius`) trong `backend/src/DiDau.Core/Suggestions/Models.cs`
- [X] T025 [P] [US1] Cài `NeedMapping` (need → loại Places: Coffee→`cafe`,`coffee_shop`; Food→`restaurant`; Breakfast→`breakfast_restaurant`,`brunch_restaurant`,`cafe`; Dinner→`restaurant` mở sau 17:00) trong `backend/src/DiDau.Core/Suggestions/NeedMapping.cs`
- [X] T026 [P] [US1] Cài `ReasonBuilder` (1–2 câu tiếng Việt, chỉ từ dữ liệu Place) trong `backend/src/DiDau.Core/Suggestions/ReasonBuilder.cs`
- [X] T027 [US1] Cài `SuggestionService` (CityLocator → cache nearby theo vị trí làm tròn → IPlacesClient.NearbySearch → lọc/xếp hạng → khoảng cách tính từ vị trí thật trong request, không lưu) trong `backend/src/DiDau.Core/Suggestions/SuggestionService.cs` cho tới khi T022, T023 xanh
- [X] T028 [US1] Cài `POST /api/suggestions` (policy rate limit `suggestions`; 422 `CITY_NOT_SUPPORTED`; 502 `UPSTREAM_ERROR` khi Places lỗi; trả `openNow`, `nextOpenAt`, `openingHoursText`, `priceLevel` theo schema `Place`) trong `backend/src/DiDau.Api/Endpoints/SuggestionsEndpoints.cs`
- [X] T029 [P] [US1] Màn hình chọn vị trí: nút "Dùng vị trí hiện tại" (geolocator), ô nhập địa chỉ/khu vực khi từ chối quyền (geocode qua `GET /api/cities/{id}/areas` hoặc chọn thành phố + nhập tên khu vực) trong `app/lib/features/suggestions/location_picker.dart`
- [X] T030 [US1] Màn hình gợi ý nhanh: 4 chip nhu cầu, danh sách thẻ (tên, địa chỉ, lý do, trạng thái mở/đóng + giờ mở lần tới, mức giá rẻ/vừa/cao, khoảng cách), dùng `InfoValue` cho trường null, nút "Mở rộng bán kính" khi `canExpandRadius`, thông báo khi `CITY_NOT_SUPPORTED` liệt kê 5 thành phố, `ErrorRetry` khi mất mạng trong `app/lib/features/suggestions/suggestions_screen.dart`
- [X] T031 [US1] Màn hình chi tiết địa điểm có link "Xem nguồn" mở `mapsUri` (FR-004) và nút "Chỉ đường" trong `app/lib/features/suggestions/place_detail_screen.dart`

**Checkpoint**: Kịch bản 1, 2 trong quickstart.md chạy đúng. MVP có thể demo.

---

## Phase 4: User Story 2 - Tạo tour tham quan có hướng dẫn (Priority: P2)

**Goal**: Tour có thứ tự, lời dẫn có nguồn, đường đi ước tính, không vượt thời lượng.

**Independent Test**: `hanoi`, `HalfDay`, `[History]` → `totalMinutes ≤ 240`, mọi section có ≥ 1 nguồn; gọi lại ≤ 3 s; `variant=1` cho tour khác.

### Tests for User Story 2

- [X] T032 [P] [US2] Unit test `LegEstimator` trong `backend/tests/DiDau.Core.Tests/Tours/LegEstimatorTests.cs`: quãng đường = haversine × 1,3; ≤ 1,5 km → `Walk` 4,5 km/h, xa hơn → `Ride` 20 km/h; phút làm tròn lên; `directionsUrl` dạng `https://www.google.com/maps/dir/?api=1&origin=..&destination=..&travelmode=walking|driving`
- [X] T033 [P] [US2] Unit test `RouteBuilder` trong `backend/tests/DiDau.Core.Tests/Tours/RouteBuilderTests.cs`: `totalMinutes ≤ duration` cho cả `OneHour`(60)/`HalfDay`(240)/`FullDay`(480); `OneHour` cho 2–4 điểm khi ứng viên gần nhau; không trùng địa điểm; loại `ClosedPermanently`; nhiều sở thích → có điểm của mỗi sở thích khi đủ ứng viên; `variant` khác → tập điểm khác (tất định theo variant); bắt đầu từ `userLocation` → có leg `fromOrder = null` tính vào tổng và bớt điểm cuối nếu vượt; < 1 ứng viên hợp lệ → `InsufficientData`
- [X] T034 [P] [US2] Unit test `PromptBuilder` trong `backend/tests/DiDau.Core.Tests/Narration/PromptBuilderTests.cs`: prompt chỉ chứa các stop và fact được truyền vào (ID, text, URL); có chỉ dẫn viết tiếng Việt, không nêu địa chỉ/giờ/giá, mỗi section phải có `sourceIds`; schema đầu ra có `placeId`, `sections[{kind: History|Trivia|Tips, text, sourceIds[]}]`; không có fact History cho một stop → prompt không yêu cầu section History cho stop đó
- [X] T035 [P] [US2] Unit test `GroundingValidator` trong `backend/tests/DiDau.Core.Tests/Narration/GroundingValidatorTests.cs`: loại stop có `placeId` lạ; loại section `sourceIds` rỗng hoặc chứa ID lạ; loại section có năm/số/số điện thoại không xuất hiện trong text của các fact được trích; giữ section hợp lệ; ánh xạ `sourceIds` → `SourceRef{title,url}`
- [X] T036 [P] [US2] Unit test `TourService` với mock `IPlacesClient`, `IWikiClient`, `INarrationClient`, `ICacheStore` trong `backend/tests/DiDau.Core.Tests/Tours/TourServiceTests.cs`: cache hit → không gọi `INarrationClient`; cache miss → gọi một lần và ghi `tour_cache` với khóa không chứa `userLocation`; `userLocation` trong thành phố → sắp lại từ vị trí trên stops đã cache mà không gọi LLM; `cityId` ngoài 5 thành phố → `CitiesNotSupported`; LLM trả nội dung bịa → bị loại trước khi trả

### Implementation for User Story 2

- [X] T037 [P] [US2] Tạo model `TourRequest` (`duration` enum `OneHour|HalfDay|FullDay`; `interests` set ≥ 1 của `History|Food|Photo`; `variant ≥ 0` mặc định 0; `userLocation?`), `Tour` (`start` enum `UserLocation|FirstStop`; `stops` ≥ 1; `totalMinutes ≤ duration`), `TourStop`, `Leg` (`fromOrder` nullable = vị trí người dùng; `mode` `Walk|Ride`), `NarrationSection` (`sources` ≥ 1), `SourceRef`, `Fact` (`kind` `History|Description|PlaceData`) trong `backend/src/DiDau.Core/Tours/Models.cs`
- [X] T038 [P] [US2] Cài `LegEstimator` trong `backend/src/DiDau.Core/Tours/LegEstimator.cs` cho tới khi T032 xanh
- [X] T039 [US2] Cài `RouteBuilder` (chấm điểm theo sở thích + rating/lượt đánh giá + có Wikipedia; láng giềng gần nhất; thời gian ở lại theo loại 20–90 phút; dừng thêm khi vượt thời lượng; variant xoay ứng viên tất định) trong `backend/src/DiDau.Core/Tours/RouteBuilder.cs` cho tới khi T033 xanh
- [X] T040 [P] [US2] Cài `PromptBuilder` trong `backend/src/DiDau.Core/Narration/PromptBuilder.cs` cho tới khi T034 xanh
- [X] T041 [P] [US2] Cài `GroundingValidator` trong `backend/src/DiDau.Core/Narration/GroundingValidator.cs` cho tới khi T035 xanh
- [X] T042 [P] [US2] Cài `WikiClient : IWikiClient` (Wikidata `wbsearchentities`/SPARQL theo tên + tọa độ gần ≤ 500 m; Wikipedia REST `page/summary` ưu tiên `vi`, fallback `en`; User-Agent có thông tin liên hệ; cache `wiki_cache` 30 ngày) trong `backend/src/DiDau.Infrastructure/Wiki/WikiClient.cs`
- [X] T043 [P] [US2] Cài `OpenAiNarrationClient : INarrationClient` (model từ `OpenAi:Model`, Structured Outputs theo schema của PromptBuilder, timeout 15 s, không log key/prompt đầy đủ) trong `backend/src/DiDau.Infrastructure/OpenAi/OpenAiNarrationClient.cs`
- [X] T044 [US2] Cài `TourService` (kiểm tra city → cache → lấy ứng viên qua Places TextSearch theo sở thích → ghép Wiki → tạo facts → RouteBuilder → PromptBuilder → INarrationClient → GroundingValidator → ghi cache → áp dụng `userLocation` nếu thuộc thành phố) trong `backend/src/DiDau.Core/Tours/TourService.cs` cho tới khi T036 xanh
- [X] T045 [US2] Cài `GET /api/cities/{cityId}/areas` (điểm nổi tiếng qua Places TextSearch, cache) và `POST /api/tours` (policy `tours`; 422 `CITY_NOT_SUPPORTED`/`INSUFFICIENT_DATA` kèm thông báo gợi ý chọn thành phố được hỗ trợ; 502 `UPSTREAM_ERROR`) trong `backend/src/DiDau.Api/Endpoints/ToursEndpoints.cs`
- [X] T046 [US2] Màn hình tạo tour: chọn thành phố (5) → khu vực/điểm nổi tiếng (tùy chọn) → thời lượng (1 giờ / nửa ngày / cả ngày) → sở thích (chọn nhiều) → nút "Tạo tour" với trạng thái đang tải (≤ 20 s) trong `app/lib/features/tours/tour_form_screen.dart`
- [X] T047 [US2] Màn hình tour: danh sách điểm dừng theo thứ tự, thời gian ở lại, đoạn đường giữa các điểm (phương thức, quãng đường, phút, nút "Chỉ đường" mở `directionsUrl`), tổng thời gian, nút "Phương án khác" (gửi `variant + 1`) trong `app/lib/features/tours/tour_screen.dart`
- [X] T048 [US2] Màn hình điểm dừng: các section Lịch sử / Điều thú vị / Mẹo tham quan (ẩn section không có), danh sách nguồn mở được, thông tin địa chỉ/giờ/giá từ Place với `InfoValue` trong `app/lib/features/tours/stop_screen.dart`

**Checkpoint**: Kịch bản 3, 4 trong quickstart.md chạy đúng; US1 vẫn hoạt động.

---

## Phase 5: User Story 3 - Lưu và xem lại tour/địa điểm yêu thích (Priority: P3)

**Goal**: Lưu/bỏ lưu tour và địa điểm, xem lại offline.

**Independent Test**: Lưu 1 quán + 1 tour → offline → tải lại → "Đã lưu" mở được cả hai; bỏ lưu → biến mất.

### Tests for User Story 3

- [X] T049 [P] [US3] Test `SavedStore` với `SharedPreferences.setMockInitialValues` trong `app/test/saved_store_test.dart`: lưu tour/place; `id` là `tour:<tourId>`/`place:<placeId>` duy nhất (lưu lại ghi đè snapshot); danh sách sắp `savedAt` giảm dần; bỏ lưu xóa mục; dữ liệu hỏng trong key → trả danh sách rỗng không crash

### Implementation for User Story 3

- [X] T050 [US3] Cài `SavedItem` (`id`, `kind` `tour|place`, `title`, `savedAt` ISO, `snapshot`) và `SavedStore` lưu JSON array dưới key `saved_items_v1` qua `shared_preferences` (web → `localStorage`) trong `app/lib/features/saved/saved_store.dart` cho tới khi T049 xanh
- [X] T051 [US3] Thêm nút Lưu/Đã lưu (toggle) vào `app/lib/features/suggestions/place_detail_screen.dart` và `app/lib/features/tours/tour_screen.dart`, lưu snapshot đầy đủ
- [X] T052 [US3] Màn hình "Đã lưu": danh sách mới nhất ở trên, mở chi tiết từ snapshot (dùng lại `tour_screen`, `stop_screen`, `place_detail_screen` ở chế độ chỉ đọc, không gọi mạng), vuốt/nút để bỏ lưu trong `app/lib/features/saved/saved_screen.dart`
- [X] T053 [US3] Bảo đảm PWA mở offline: kiểm tra service worker của Flutter web cache app shell, thêm icon 192/512 trong `app/web/icons/` và cấu hình `app/web/manifest.json`

**Checkpoint**: Kịch bản 6 trong quickstart.md chạy đúng; cả ba story hoạt động độc lập.

---

## Phase 6: Polish & Cross-Cutting Concerns

- [X] T054 [P] Thêm `README.md` gốc: kiến trúc ngắn, cách chạy theo quickstart.md, nơi đặt secret
- [X] T055 [P] Thêm `backend/Dockerfile` (multi-stage, chạy `DiDau.Api`) và service `api` trong `docker-compose.yml`
- [X] T056 Kiểm tra bí mật: script `scripts/check-secrets.ps1` tìm chuỗi dạng key Google (`AIza`) / OpenAI (`sk-`) trong repo và `app/build/web`; chạy và sửa nếu có
- [X] T057 Rà soát log: bảo đảm không log key, prompt đầy đủ hay tọa độ chưa làm tròn trong `backend/src/DiDau.Api/Program.cs` và các client ở `backend/src/DiDau.Infrastructure/`
- [ ] T058 Chạy toàn bộ kịch bản trong `specs/001-virtual-tour-guide/quickstart.md` (gồm 429 khi vượt rate limit, kiểm tra bảng cache không có tọa độ chưa làm tròn) và ghi kết quả vào cuối file đó

---

## Phase 7: Remediation (từ /speckit-analyze 2026-11-03)

**Mục đích**: Sửa các vấn đề phát hiện sau khi T001–T045 đã xong. Không sửa task cũ; các task dưới
đây thay đổi code đã viết khi cần.

### C1 — Không lưu bền nội dung Google Places (research.md §7)

- [X] T059 Bỏ cache chi tiết địa điểm của `GooglePlacesClient` (không PostgreSQL, không cache giữa các request; chỉ gộp các lần gọi trùng trong cùng request); thêm migration xóa bảng `place_cache` trong `backend/src/DiDau.Infrastructure/GooglePlaces/GooglePlacesClient.cs` và `backend/src/DiDau.Infrastructure/Persistence/Migrations/`
- [X] T060 Đổi payload `tour_cache` chỉ còn `{ stops: [{placeId, location, order, stayMinutes, narration[]}], facts[] }` (không chứa tên/địa chỉ/giờ/giá/rating); `TourService` gọi `IPlacesClient.GetDetails` song song cho từng stop khi trả về; cập nhật test: lấy từ cache → gọi `GetDetails`, không gọi `INarrationClient`, payload ghi cache không chứa trường Place nào ngoài `placeId`/`location` trong `backend/src/DiDau.Core/Tours/TourService.cs` và `backend/tests/DiDau.Core.Tests/Tours/TourServiceTests.cs`

### U1 — Nhập địa chỉ (FR-010)

- [X] T061 [US1] Cài `GET /api/geocode?q=&cityId=` theo contracts/api.yaml (Places Text Search giới hạn theo vùng thành phố, lọc bằng `CityLocator`, tối đa 5 `GeocodeResult`, rate limit `suggestions`, không log `q`) trong `backend/src/DiDau.Api/Endpoints/GeocodeEndpoints.cs`
- [X] T062 [US1] Sửa ô nhập địa chỉ gọi `/api/geocode` và cho chọn 1 trong ≤ 5 kết quả thay cho `/cities/{id}/areas` trong `app/lib/features/suggestions/location_picker.dart`

### D1 — Chạy trên điện thoại qua HTTPS

- [X] T063 Thêm `scripts/run-mobile.ps1`: build web với `API_BASE_URL` của tunnel, chạy API, mở 2 tunnel HTTPS (API và `app/build/web`), in URL cho điện thoại và nhắc thêm origin vào `Cors:AllowedOrigins`
- [ ] T064 Kiểm tra trên thiết bị thật (Safari iOS 16.4+ và Chrome Android) qua T063: cấp quyền vị trí, gợi ý nhanh, tạo tour, cài PWA ra màn hình chính, mở offline; ghi kết quả vào cuối `specs/001-virtual-tour-guide/quickstart.md`

### MEDIUM / LOW

- [ ] T065 Đo hiệu năng (SC-001, SC-002): 20 lần gọi mỗi loại (gợi ý nhanh, tour mới, tour từ cache), ghi p90 và đối chiếu 5 s / 20 s / 3 s vào cuối `specs/001-virtual-tour-guide/quickstart.md`
- [ ] T066 Kiểm tra grounding thủ công (SC-003): 50 tour/gợi ý ngẫu nhiên trong 5 thành phố, đối chiếu từng địa chỉ/sự kiện với nguồn, ghi kết quả vào `specs/001-virtual-tour-guide/grounding-audit.md`
- [X] T067 [P] Khởi tạo git repo và thêm CI tối thiểu chạy `dotnet test backend/DiDau.sln` và `flutter test` trong `.github/workflows/ci.yml` (Constitution II)
- [X] T068 [P] [US1] Bỏ `cafe` khỏi nhóm `Breakfast` trong `backend/src/DiDau.Core/Suggestions/NeedMapping.cs` và cập nhật test liên quan trong `backend/tests/DiDau.Core.Tests/Suggestions/`
- [X] T070 [P] Hiển thị ghi công Google ("Google Maps" theo hướng dẫn attribution của Places API) ở mọi màn hình có dữ liệu Places không kèm bản đồ Google (Service Specific Terms 5.2) trong `app/lib/widgets/google_attribution.dart`, dùng ở `suggestions_screen.dart`, `place_detail_screen.dart`, `tour_screen.dart`, `stop_screen.dart`, `saved_screen.dart`
- [X] T069 [P] Đổi tên lỗi domain `CitiesNotSupported` → `CityNotSupported` (vẫn ánh xạ ra mã API `CITY_NOT_SUPPORTED`) trong `backend/src/DiDau.Core/` và `backend/tests/DiDau.Core.Tests/`
- [X] T071 [US3] Mục đã lưu chỉ giữ `place_id`, tọa độ (xóa sau 30 ngày) và dữ liệu tour của app; tên/địa chỉ/giờ/giá tải lại qua `GET /api/places/{placeId}` khi mở; snapshot đầy đủ cũ được làm gọn khi đọc (Places terms 5.4) trong `app/lib/features/saved/` và `backend/src/DiDau.Api/Endpoints/PlacesEndpoints.cs`
- [X] T072 Thay Google Places bằng OSM Overpass (tour, khu vực nổi tiếng; `osm_cache` + migration `AddOsmCache`; nối Wikipedia qua tag `wikidata`) và Goong.io (gợi ý nhanh, geocode, chi tiết); định tuyến chi tiết theo tiền tố ID trong `backend/src/DiDau.Infrastructure/RoutingPlacesClient.cs`; ghi công "Goong · © OpenStreetMap contributors" trong `app/lib/widgets/source_attribution.dart`; nút Chỉ đường vẫn mở Google Maps bằng URL

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: không phụ thuộc
- **Foundational (Phase 2)**: sau Setup — chặn mọi user story
- **US1 (Phase 3)**: sau Foundational
- **US2 (Phase 4)**: sau Foundational; độc lập với US1 về backend. Dùng lại `InfoValue`/`ApiClient` từ Phase 2
- **US3 (Phase 5)**: `SavedStore` (T049, T050) làm được ngay sau Foundational; T051–T052 cần màn hình của US1 (T031) và US2 (T047, T048)
- **Polish (Phase 6)**: sau các story muốn phát hành

### Within Each User Story

- Test viết trước và phải FAIL → model → service → endpoint → UI
- T027 sau T022–T026; T039 sau T037–T038; T044 sau T039–T043; T045 sau T044

### Parallel Opportunities

- Setup: T002–T005 song song sau T001
- Foundational: T006–T014 song song; T020–T021 song song với phần backend
- US1: T022–T026 song song; T029 song song với backend
- US2: T032–T038, T040–T043 song song (khác file)
- US3: T049 có thể bắt đầu song song với US1/US2

---

## Parallel Example: User Story 2

```bash
# Viết test song song:
Task: "Unit test LegEstimator in backend/tests/DiDau.Core.Tests/Tours/LegEstimatorTests.cs"
Task: "Unit test RouteBuilder in backend/tests/DiDau.Core.Tests/Tours/RouteBuilderTests.cs"
Task: "Unit test PromptBuilder in backend/tests/DiDau.Core.Tests/Narration/PromptBuilderTests.cs"
Task: "Unit test GroundingValidator in backend/tests/DiDau.Core.Tests/Narration/GroundingValidatorTests.cs"

# Adapter ngoài song song:
Task: "WikiClient in backend/src/DiDau.Infrastructure/Wiki/WikiClient.cs"
Task: "OpenAiNarrationClient in backend/src/DiDau.Infrastructure/OpenAi/OpenAiNarrationClient.cs"
```

---

## Implementation Strategy

### MVP First (User Story 1 Only)

1. Phase 1 Setup → Phase 2 Foundational
2. Phase 3 US1 (gợi ý nhanh)
3. **STOP and VALIDATE**: kịch bản 1, 2 của quickstart.md trên điện thoại thật
4. Demo

### Incremental Delivery

1. Setup + Foundational
2. + US1 → demo (MVP)
3. + US2 → demo tour
4. + US3 → demo lưu/offline
5. Polish → phát hành thử

---

## Notes

### Android native — yêu cầu bổ sung 2026-11-04

- [X] T076 Thêm Android runner, quyền Internet/GPS foreground, biểu tượng/tên Đi Đâu và cấu hình API local qua 10.0.2.2; giữ nền tảng web.
- [X] T077 Build APK debug/release, cài trên máy ảo và kiểm thử GPS, gợi ý, tour, lưu/bỏ lưu, offline bằng integration test native; ghi rõ giới hạn API fixture và release signing.

### Kiểm tra sau bàn giao Claude — 2026-11-04

- [X] T073 Sửa hồi quy provider: cache gợi ý giữ keyword match khi Goong details không có type; giải mã ID chứa slash; đổi namespace cache sau chuyển provider; Overpass xuất tọa độ node, tái sử dụng search và không cache phản hồi lỗi từng phần. Kiểm chứng bằng backend regression tests.
- [X] T074 Sửa mục đã lưu: loại vị trí xuất phát, whitelist trường được lưu, bỏ tên provider trong title, vô hiệu hóa chỉ đường thiếu tọa độ và khôi phục khi hydrate; chống mở trùng khi đang tải. Kiểm chứng bằng Flutter tests và browser smoke offline.
- [X] T075 Đồng bộ README, plan, research, data-model và quickstart theo Goong/OSM và lưu tối giản; cập nhật kiểm thử browser và kết quả kiểm tra. T058/T064/T065/T066 vẫn cần môi trường hoặc thiết bị thật.

- [P] = khác file, không phụ thuộc
- Mọi API ngoài chỉ gọi qua interface trong `DiDau.Core/Abstractions` → test không gọi mạng
- Không commit secret; chạy `dotnet test` trước mỗi commit
- Dừng ở mỗi checkpoint để kiểm tra story độc lập




