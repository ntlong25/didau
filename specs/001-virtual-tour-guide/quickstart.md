# Quickstart & Validation: Hướng dẫn viên tour ảo

## Yêu cầu

- .NET 8 SDK, Flutter 3.x stable (bật web), Docker (cho PostgreSQL 16)
- Goong API key, OpenAI API key, chỉ dùng ở backend; Overpass (OSM) không cần key nhưng cần User-Agent có liên hệ (`Osm:UserAgent`, mặc định dùng `Wiki:UserAgent`)

## Cài đặt

```bash
docker compose up -d postgres
```

```bash
dotnet tool restore
dotnet user-secrets set "Goong:ApiKey" "<key>" --project backend/src/DiDau.Api
dotnet user-secrets set "OpenAi:ApiKey" "<key>" --project backend/src/DiDau.Api
dotnet user-secrets set "OpenAi:Model" "<model-ho-tro-Structured-Outputs>" --project backend/src/DiDau.Api
dotnet user-secrets set "Wiki:UserAgent" "DiDau/0.1 (mailto:<email-lien-he>)" --project backend/src/DiDau.Api
dotnet user-secrets set "ConnectionStrings:Default" "Host=localhost;Database=didau;Username=postgres;Password=<mat-khau-dev>" --project backend/src/DiDau.Api
dotnet user-secrets set "Cors:AllowedOrigins:0" "http://localhost:8088" --project backend/src/DiDau.Api
dotnet ef database update --project backend/src/DiDau.Infrastructure --startup-project backend/src/DiDau.Api
dotnet run --project backend/src/DiDau.Api --no-launch-profile --urls http://localhost:5000
```

```bash
cd app
flutter run -d chrome --web-port=8088 --dart-define=API_BASE_URL=http://localhost:5000/api
```

## Chạy trên điện thoại thật

Trình duyệt điện thoại chỉ cho lấy vị trí trên trang HTTPS, nên `http://<IP-LAN>` không dùng được.

```bash
./scripts/run-mobile.ps1
```

Mở một tunnel HTTPS tới API (vd. `cloudflared tunnel --url http://localhost:5000`) và một tunnel
khác phục vụ `app/build/web`; thêm origin của app vào `Cors:AllowedOrigins`. Mở URL app trên Safari
iOS 16.4+ và Chrome Android. Script `scripts/run-mobile.ps1` (T063) gói các bước này.

## Kiểm tra tự động

```bash
dotnet test backend/DiDau.sln
```

Phải xanh, gồm các nhóm test: RouteBuilder (không vượt thời lượng, không trùng điểm, đủ/thiếu dữ
liệu), GroundingValidator (loại section không nguồn/ID lạ/số bịa), PromptBuilder (chỉ chứa
facts đã cung cấp), CacheKey, LocationRounding, CityLocator, OpeningHours. Mọi API ngoài được mock.

## Kịch bản thủ công (xem [contracts/api.yaml](contracts/api.yaml))

1. **Gợi ý nhanh (US1)**: `POST /api/suggestions` với tọa độ Hồ Hoàn Kiếm, `need=Coffee`. Mong đợi
   3–5 kết quả có tên, địa chỉ, lý do, giờ, giá, khoảng cách, phản hồi ≤ 5 s. Trường thiếu hiển thị
   "chưa có thông tin" trên app.
2. **Ngoài phạm vi (FR-010a)**: tọa độ ở Cần Thơ → 422 `CITY_NOT_SUPPORTED`.
3. **Tour (US2)**: `POST /api/tours` với `cityId=hanoi`, `duration=HalfDay`, `interests=[History]`.
   Mong đợi `totalMinutes ≤ 240`, mỗi section narration có ≥ 1 nguồn mở được. Gọi lại cùng
   tham số → ≤ 3 s (từ cache). Gọi với `variant=1` → tour khác.
4. **Bắt đầu từ vị trí (FR-023a)**: thêm `userLocation` trong Hà Nội → `start=UserLocation`, có
   leg `fromOrder=null`; tổng vẫn ≤ thời lượng.
5. **Bí mật (Nguyên tắc IV)**: tìm trong `app/build/web` không thấy chuỗi key; gọi `POST /api/tours`
   6 lần/phút → lần thứ 6 nhận 429.
6. **Đã lưu (US3)**: trên app lưu một quán và một tour → kiểm tra `localStorage` key
   `flutter.saved_items_v1` chỉ chứa ID/tọa độ, không có tên/địa chỉ/giờ/giá → bật offline trong
   DevTools → tải lại → mở tour thấy lời dẫn, chi tiết địa điểm ghi "cần kết nối mạng" → bật mạng
   lại → mở lại thấy đủ chi tiết. Bỏ lưu → biến mất.
7. **Quyền riêng tư (FR-006)**: kiểm tra các bảng cache không có cột/giá trị tọa độ chưa làm tròn.

## Kết quả triển khai và kiểm tra — 2026-11-03

Các lệnh setup trên chạy từ gốc repo. Đặt `POSTGRES_PASSWORD` cho Compose và `ASPNETCORE_ENVIRONMENT=Development` để API/EF đọc user-secrets. Hướng dẫn PowerShell đầy đủ và build offline ở [README](../../README.md).

| Kiểm tra | Kết quả | Phạm vi bằng chứng |
|---|---|---|
| Backend Release build + `dotnet test` | PASS, 61 test | Logic thuần, HTTP API, provider adapter giả lập; không gọi dịch vụ trả phí |
| `flutter analyze` | PASS | Không có issues |
| `flutter test` | PASS, 9 test | Điều hướng và lưu snapshot: ghi đè, thứ tự, bỏ lưu, dữ liệu hỏng, ghi đồng thời |
| Build PWA release | PASS | `scripts/build-web.ps1`, 38 app-shell assets gồm CanvasKit và font cục bộ |
| Gợi ý → lưu địa điểm → tạo/lưu tour | PASS với fixture | Chrome headless viewport 390×844; không chứng minh chất lượng dữ liệu Places thật |
| Offline reload → mở tour/place → bỏ lưu | PASS | Tắt mạng và bỏ route API giả lập trước reload; kiểm tra ảnh chụp có chữ/font đầy đủ |
| Ngoài phạm vi Cần Thơ | PASS | HTTP 422, `CITY_NOT_SUPPORTED` |
| Rate limit | PASS | Request tour thứ 6 nhận HTTP 429, `RATE_LIMITED` |
| Validation & upstream errors | PASS | JSON lỗi trả 400; lỗi provider trả 502, không lộ chi tiết |
| Geocode | PASS với fixture | Giới hạn 5 kết quả trong thành phố; từ khóa quá ngắn trả 400 |
| Tour cache / quyền riêng tư | PASS trong test + SQL review | Không lưu vị trí xuất phát; không lưu tên/địa chỉ/giờ/giá/rating Places; hit gọi lại GetDetails, không gọi LLM |
| Places request scope | PASS | Hai GetDetails cùng request được gộp; request mới gọi provider lại |
| Secret scan | PASS | Bao gồm mã nguồn và `app/build/web`; không in giá trị nhạy cảm |
| Migration SQL | PASS khi sinh SQL | Tạo cache; migration mới drop `place_cache` và clear tour cache cũ. Chưa áp dụng vào PostgreSQL thật |
| Script mobile + CI | Đã tạo, script parse PASS | Chưa mở tunnel thật; chưa có remote GitHub để chạy CI |

**Chưa hoàn tất**:

- **T058**: Chưa chạy trọn quickstart với Goong/OSM/OpenAI/PostgreSQL thật. Docker Linux engine không kết nối được; chưa có cấu hình key/model/DB cho phiên này.
- **T064**: Chưa có thiết bị Safari iOS/Chrome Android thật để cấp GPS, cài PWA và kiểm tra offline. Chrome viewport điện thoại không thay thế bước này.
- **T065**: Chưa đo p90 20 mẫu thật cho mỗi loại. Đã chuẩn bị `scripts/measure-performance.ps1` (gọi provider thật, có thể phát sinh phí, chờ giữa request để tôn trọng rate limit); kết quả sẽ ở `artifacts/performance.json`.
- **T066**: Chưa đối chiếu 50 mẫu thật. Xem [grounding-audit.md](grounding-audit.md).

Ảnh kiểm tra cục bộ: `artifacts/place-mobile.png`, `artifacts/saved-offline-mobile.png`. Báo cáo coverage: `artifacts/final-tests/`. Artifact test không đưa vào git.

**Điều chỉnh so với bản kế hoạch đầu**: service worker riêng và font cục bộ để offline hoạt động; Goong không cache giữa request; OSM dùng osm_cache theo research §7 mới; lời dẫn chỉ trích nguyên văn nguồn Wiki tiếng Việt để kiểm chứng nội dung tất định. Bản cache có `generatedAt` ngoài stops/facts để giữ đúng thời điểm sinh tour, không chứa nội dung Places bổ sung. Tọa độ địa điểm công khai trong tour cache không phải tọa độ riêng tư của người dùng.


### Rà soát 2026-11-04

Đã chạy lại backend Release (61 test), Flutter analyze, Flutter test (9 test), PWA release (38 assets), browser smoke Chrome mobile với API fixture và secret scan. Đã sửa lỗi cache Goong mất category, ID chứa slash, Overpass thiếu tọa độ node/gọi thừa từng stop và lưu vị trí xuất phát. Kiểm thử browser xác nhận localStorage không lưu tên/địa chỉ provider và mở được mục đã lưu sau reload offline. Không có Goong/OpenAI/model/DB trong user-secrets hay cấu hình development; Docker engine hiện không kết nối được. Bốn mục kiểm chứng thật bên trên vẫn chưa hoàn tất.

### Android native — 2026-11-04

- Thêm runner Android `vn.didau.di_dau`, quyền Internet/GPS foreground và biểu tượng Đi Đâu; giữ web.
- Máy ảo `DiDau_Test`, Pixel 7 / Android 16 (API 36), `emulator-5556`, dữ liệu 10 GB.
  Máy ảo Pixel_7 cũ thiếu dung lượng nên dùng máy mới; không xóa dữ liệu máy cũ.
- PASS: APK debug và release split theo ABI (armeabi-v7a, arm64-v8a, x86_64).
- PASS: integration test native trong 18 giây: GPS qua plugin Android thật, HTTP fixture,
  tìm địa chỉ, giữ vị trí đã chọn sau khi tìm, gợi ý, lưu địa điểm, tạo/lưu tour, khởi tạo lại
  giao diện với storage Android, tắt API và đọc lời dẫn offline, bỏ lưu. GPS do emulator giả lập.
- PASS: 9 unit/widget tests và `flutter analyze`. Release được cài và mở trên máy ảo,
  gọi được HTTP fixture trên máy tính qua `10.0.2.2:5000`.
- Đã sửa GPS bằng Android LocationManager, trạng thái LocationPicker khi chèn attribution,
  cấu hình network security qua release lint và cache Kotlin khi repo/Pub ở khác ổ đĩa.
- Chạy lại: `scripts/test-android.ps1 -Device emulator-5556` (reset dữ liệu app trên máy ảo).
  Fixture thủ công: `node scripts/android-fixture-server.cjs`; ảnh: `artifacts/android-release.png`.
- APK đang dùng debug signing để thử nghiệm, API_BASE_URL trỏ về máy tính qua emulator.
  Muốn dùng điện thoại thật phải build với URL backend HTTPS có thể truy cập từ điện thoại.
  Chưa kiểm chứng Goong/OSM/OpenAI/PostgreSQL thật; đây không thay thế T058/T064/T065/T066.
