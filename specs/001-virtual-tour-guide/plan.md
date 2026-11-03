# Implementation Plan: Hướng dẫn viên tour ảo & gợi ý địa điểm

**Branch**: `001-virtual-tour-guide` | **Date**: 2026-11-03 | **Spec**: [spec.md](spec.md)

**Input**: Feature specification from `/specs/001-virtual-tour-guide/spec.md`

## Summary

App mobile-first (Flutter, build ra PWA) có hai chế độ: gợi ý nhanh quán gần đây và tour tham quan
có lời dẫn kiểu hướng dẫn viên, giới hạn ở 5 thành phố. Backend ASP.NET Core 8 Web API giữ toàn bộ
API key, lấy dữ liệu từ Google Places API và Wikipedia/Wikidata, rồi gọi OpenAI API để viết lời dẫn
chỉ từ dữ liệu đã lấy được.

Điểm then chốt của thiết kế:
- **Chọn điểm dừng và sắp lộ trình là code tất định ở backend**, không do LLM quyết định.
- LLM chỉ viết lời dẫn cho các điểm đã chọn, trả JSON có trích dẫn ID nguồn.
- Một bộ kiểm tra (grounding validator) loại mọi nội dung không khớp nguồn trước khi trả về app.
- Kết quả tour và dữ liệu địa điểm được cache trong PostgreSQL. Mục yêu thích lưu ở
  `localStorage` của trình duyệt.

## Technical Context

**Language/Version**: C# 12 / .NET 8 (backend); Dart 3 / Flutter 3.x stable (frontend)

**Primary Dependencies**:
- Backend: ASP.NET Core 8 Web API, EF Core 8 + Npgsql, `Microsoft.AspNetCore.RateLimiting`,
  `HttpClientFactory`, OpenAI .NET SDK (hoặc HttpClient gọi Chat Completions với JSON schema)
- Frontend: Flutter web (PWA), `http`, `geolocator`, `shared_preferences` (trên web lưu vào
  `localStorage`), `url_launcher` (mở Google Maps)

**Storage**: PostgreSQL 16 (cache tour, cache địa điểm, cache tra cứu gần đây, cache Wikipedia);
`localStorage` trên thiết bị cho mục đã lưu

**Testing**: xUnit + NSubstitute (mock API ngoài) cho backend; `flutter test` cho vài widget/logic lưu trữ

**Target Platform**: PWA chạy trên trình duyệt điện thoại (Chrome Android, Safari iOS 16.4+);
backend chạy Linux container

**Project Type**: mobile web app (PWA) + web service

**Performance Goals**: gợi ý nhanh ≤ 5 s (p90); tour mới ≤ 20 s (p90); tour đã cache ≤ 3 s

**Constraints**: không lộ API key ra client; không lưu vị trí chính xác; dữ liệu địa điểm cũ tối đa
7 ngày; mục đã lưu xem được khi offline; chỉ hỗ trợ 5 thành phố; PWA phải chạy qua HTTPS trên
điện thoại (trình duyệt chỉ cấp vị trí cho trang HTTPS) — khi phát triển dùng tunnel HTTPS cho cả
app và API; không lưu bền nội dung Google Places ngoài `place_id` và tọa độ (research.md §7)

**Scale/Scope**: MVP, vài trăm người dùng thử; ~6 màn hình; 5 thành phố

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

| Nguyên tắc | Đánh giá | Trạng thái |
|------------|----------|------------|
| I. MVP nhỏ, chạy trên điện thoại | Một client Flutter build PWA, chạy trên trình duyệt điện thoại; không làm native song song. Ba user story tách được, làm lần lượt P1 → P3. | PASS |
| II. .NET 8 + unit test logic chính | Backend .NET 8. Logic chính nằm trong `DiDau.Core` không phụ thuộc HTTP: dựng lộ trình, dựng prompt, kiểm tra grounding, tạo khóa cache, kiểm tra thành phố. Có unit test, mọi API ngoài đi qua interface và được mock. | PASS |
| III. Nội dung AI có nguồn thật | LLM không chọn địa điểm và không viết địa chỉ, giờ mở cửa hay giá. Các trường này lấy thẳng từ Places. Lời dẫn phải trích ID nguồn; validator loại phần nào không có nguồn. Có unit test cho validator. | PASS |
| IV. Bí mật ở server | Key Google và OpenAI chỉ ở biến môi trường của backend; app chỉ gọi backend; endpoint tốn phí có rate limit theo IP; log không ghi key. | PASS |
| V. Cache giảm chi phí | Cache PostgreSQL: tour theo (địa điểm, thời lượng, sở thích, phương án); chi tiết địa điểm TTL 7 ngày; tra cứu gần đây theo tọa độ làm tròn; Wikipedia TTL 30 ngày. Không cache dữ liệu cá nhân. | PASS (xem Complexity Tracking về PostgreSQL) |

**Re-check sau Phase 1**: thiết kế trong [data-model.md](data-model.md) và [contracts/api.yaml](contracts/api.yaml)
vẫn giữ nguyên các điều trên. Không có vi phạm mới.

## Project Structure

### Documentation (this feature)

```text
specs/001-virtual-tour-guide/
├── plan.md
├── research.md
├── data-model.md
├── quickstart.md
├── contracts/
│   └── api.yaml
└── tasks.md             # tạo bởi /speckit-tasks
```

### Source Code (repository root)

```text
backend/
├── DiDau.sln
├── src/
│   ├── DiDau.Api/                 # ASP.NET Core 8: endpoints, DI, rate limit, cấu hình
│   │   ├── Endpoints/             # CitiesEndpoints, SuggestionsEndpoints, ToursEndpoints
│   │   └── Program.cs
│   ├── DiDau.Core/                # Logic thuần, không gọi mạng
│   │   ├── Cities/                # 5 thành phố + kiểm tra vị trí thuộc thành phố
│   │   ├── Suggestions/           # lọc/xếp hạng gợi ý, tính khoảng cách, trạng thái mở cửa
│   │   ├── Tours/                 # RouteBuilder, LegEstimator, TourService
│   │   ├── Narration/             # PromptBuilder, GroundingValidator
│   │   ├── Caching/               # CacheKey, TTL policy, LocationRounding
│   │   └── Abstractions/          # IPlacesClient, IWikiClient, INarrationClient, ICacheStore
│   └── DiDau.Infrastructure/      # Adapter API ngoài + EF Core
│       ├── GooglePlaces/
│       ├── Wiki/                  # Wikipedia REST + Wikidata
│       ├── OpenAi/
│       └── Persistence/           # DbContext, migrations, PostgresCacheStore
└── tests/
    └── DiDau.Core.Tests/          # xUnit, mock mọi interface trong Abstractions

app/                               # Flutter (build web/PWA)
├── lib/
│   ├── main.dart
│   ├── api/                       # client gọi backend
│   ├── features/
│   │   ├── suggestions/
│   │   ├── tours/
│   │   └── saved/                 # SavedStore dùng shared_preferences (localStorage)
│   └── widgets/
├── web/                           # manifest.json, icons cho PWA
└── test/
```

**Structure Decision**: Hai thư mục gốc `backend/` (ASP.NET Core) và `app/` (Flutter). Backend tách ba
project để `DiDau.Core` test được mà không cần mạng hay DB, đúng Nguyên tắc II. Không tách thêm
service nào khác.

## Complexity Tracking

| Violation | Why Needed | Simpler Alternative Rejected Because |
|-----------|------------|-------------------------------------|
| Cache bền bằng PostgreSQL thay vì in-memory (Nguyên tắc V nói MVP ưu tiên cache đơn giản nhất) | Tour sinh bằng LLM đắt và chậm; cache phải sống qua lần khởi động lại/deploy để thực sự giảm chi phí. Người dùng cũng yêu cầu rõ PostgreSQL. | In-memory mất hết khi restart, mỗi lần deploy phải trả lại chi phí sinh tour. |
