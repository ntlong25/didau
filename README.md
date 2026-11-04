# Đi Đâu

Flutter PWA tiếng Việt + ASP.NET Core 8, hỗ trợ gợi ý gần đây, tour có nguồn và lưu offline tại Hà Nội, TP. Hồ Chí Minh, Đà Lạt, Nha Trang, Đà Nẵng.

## Kiến trúc

- `backend/src/DiDau.Core`: chọn/lọc địa điểm, xếp lộ trình, giờ mở cửa, khóa cache và kiểm chứng lời dẫn. Không phụ thuộc ASP.NET hay EF.
- `backend/src/DiDau.Infrastructure`: Goong (gợi ý, địa chỉ), OpenStreetMap Overpass (tour), Wikidata/Wikipedia, OpenAI Structured Outputs; PostgreSQL chỉ lưu cache tour tối giản, ID gần đây và Wiki, cleanup hàng ngày.
- `backend/src/DiDau.Api`: API, validation, CORS, rate limit theo IP.
- `app`: Flutter web, dữ liệu đã lưu trong localStorage. Không đăng nhập, không nhúng API key.

## Chạy backend

Cần .NET SDK có thể build `net8.0`, runtime ASP.NET Core 8, PostgreSQL 16; Flutter/Dart theo `app/pubspec.yaml`. Thêm `flutter/bin` vào PATH.

Tại thư mục gốc, đặt mật khẩu PostgreSQL dành riêng cho môi trường dev trong biến `POSTGRES_PASSWORD`, rồi chạy:

```powershell
docker compose up -d postgres
dotnet tool restore
dotnet user-secrets set 'ConnectionStrings:Default' 'Host=localhost;Database=didau;Username=postgres;Password=<mật-khẩu-dev>' --project backend/src/DiDau.Api
dotnet user-secrets set 'Goong:ApiKey' '<key>' --project backend/src/DiDau.Api
dotnet user-secrets set 'OpenAi:ApiKey' '<key>' --project backend/src/DiDau.Api
dotnet user-secrets set 'OpenAi:Model' '<model-hỗ-trợ-Structured-Outputs>' --project backend/src/DiDau.Api
dotnet user-secrets set 'Wiki:UserAgent' 'DiDau/0.1 (mailto:<email-liên-hệ-của-bạn>)' --project backend/src/DiDau.Api
dotnet user-secrets set 'Cors:AllowedOrigins:0' 'http://localhost:8088' --project backend/src/DiDau.Api
$env:ASPNETCORE_ENVIRONMENT='Development'
dotnet ef database update --project backend/src/DiDau.Infrastructure --startup-project backend/src/DiDau.Api
dotnet run --project backend/src/DiDau.Api --no-launch-profile --urls http://localhost:5000
```

Không gửi key vào chat hoặc lưu trong client. File cấu hình mẫu nằm ở `backend/src/DiDau.Api/appsettings.Example.json`. Có thể dùng biến môi trường `Goong__ApiKey`, `OpenAi__ApiKey`, `OpenAi__Model`, `ConnectionStrings__Default`, `Wiki__UserAgent`, `Cors__AllowedOrigins__0`. OSM Overpass dùng User-Agent liên hệ từ cấu hình Wiki.

Để chạy API bằng container, đặt thêm `GOONG_API_KEY`, `OPENAI_API_KEY`, `OPENAI_MODEL`, `WIKI_USER_AGENT`, `APP_ORIGIN` trong môi trường rồi `docker compose up --build -d`. Compose bật migration khi khởi động cho môi trường dev; production nên chạy migration riêng. Đặt API sau HTTPS; nếu có reverse proxy, cấu hình trusted forwarded headers trước khi sử dụng rate limit theo IP thực.

## Chạy app

```powershell
cd app
flutter pub get
flutter run -d chrome --web-port=8088 --dart-define=API_BASE_URL=http://localhost:5000/api
```

Build **có offline** từ thư mục gốc:

```powershell
./scripts/build-web.ps1 -ApiBaseUrl 'https://<api-host>/api'
```

Serve `app/build/web` bằng static web server qua HTTPS (localhost được chấp nhận khi dev). Script tạo service worker với manifest/hash của toàn bộ app shell và CanvasKit cục bộ. `flutter build web` đơn lẻ không tạo service worker riêng của dự án. Cần tải app online một lần và chờ cài cache xong trước khi offline. Cấu hình host để `index.html`, `sw.js` và `flutter_bootstrap.js` được revalidate. Bản mới được kích hoạt sau khi đóng các tab cũ.

Mục đã lưu giữ ID, tọa độ tối đa 30 ngày và lời dẫn Wiki; tên, địa chỉ, giờ, giá được tải lại khi mở. Offline vẫn đọc được lời dẫn. Không lưu đoạn đường xuất phát từ vị trí cá nhân. Xóa dữ liệu trình duyệt sẽ xóa mục lưu. Chỉ đường và mở nguồn cần Internet. Font Roboto được đóng gói trong app (giấy phép tại `app/assets/fonts/LICENSE.txt`).

Chạy thử trên điện thoại qua HTTPS: cài `cloudflared`, cấu hình PostgreSQL/key như trên, rồi chạy `./scripts/run-mobile.ps1`. Script mở hai tunnel, build PWA, thiết lập CORS cho tiến trình API và in URL điện thoại; nhấn Enter để dừng các tiến trình do script tạo. Không tự động đánh dấu kiểm thử thiết bị thật là hoàn tất.

## Kiểm tra

### Android native

Đã thêm Android (`vn.didau.di_dau`, tên hiển thị **Đi Đâu**) dùng cùng code Flutter.
Máy ảo truy cập backend trên máy tính qua `10.0.2.2`, không phải `localhost`.

```powershell
flutter emulators --launch Pixel_7
cd app
flutter build apk --debug --dart-define=API_BASE_URL=http://10.0.2.2:5000/api
flutter run -d emulator-5554 --dart-define=API_BASE_URL=http://10.0.2.2:5000/api
```

APK nằm tại `app/build/app/outputs/flutter-apk/app-debug.apk`. Manifest khai báo Internet và
quyền vị trí foreground; HTTP chỉ cho địa chỉ loopback/emulator, API từ xa phải HTTPS.
Bản release hiện dùng debug signing của Flutter để thử nghiệm; chưa dùng để phát hành lên store.
Android lưu mục đã lưu bằng SharedPreferences; tắt backup để dữ liệu chỉ ở thiết bị hiện tại.

Từ gốc repo, chạy `./scripts/test-android.ps1` để kiểm thử trên máy ảo đang bật. Script cấp quyền
GPS và đặt tọa độ Hà Nội, rồi chạy integration test với HTTP fixture trong máy ảo: gợi ý,
tour, lưu/bỏ lưu và đọc lời dẫn khi API tắt. Test dùng storage native thật và xóa dữ liệu lưu
của app kiểm thử lúc bắt đầu; không gọi Goong/OpenAI, không thay thế kiểm chứng backend thật.

Dùng `-Device emulator-5556` nếu máy ảo có ID khác (xem `flutter devices`). Nếu chưa có backend
được cấu hình, có thể chạy `node scripts/android-fixture-server.cjs` để thao tác thủ công với dữ
liệu demo được ghi nhãn rõ. Server fixture dùng cổng 5000; dừng nó trước khi chạy backend thật.
Android dùng bộ định vị hệ thống cho thao tác lấy vị trí một lần; không cần vị trí nền.
Trên Windows, incremental cache Kotlin bị tắt vì Pub cache và repo có thể ở hai ổ đĩa khác nhau.

```powershell
dotnet test backend/DiDau.sln
cd app
flutter analyze
flutter test
cd ..
./scripts/check-secrets.ps1
```

Kiểm thử trình duyệt tự động (cần Chrome; API được giả lập, không tốn phí):

```powershell
./scripts/build-web.ps1
npm install --prefix artifacts/browser-check playwright
node scripts/browser-smoke.cjs
```

Kết quả và các kiểm tra còn cần môi trường thật được ghi trong [quickstart](specs/001-virtual-tour-guide/quickstart.md).

## Quyết định và giới hạn MVP

- Backend tự chọn điểm và thời gian, AI không được thay đổi lộ trình. Khoảng cách là haversine × 1,3, chưa phải tuyến đường thực tế.
- Lời dẫn dùng trích đoạn nguyên văn có nguồn, kiểm tra cả `placeId`, `sourceIds`, số và nội dung. Quy tắc này chặt hơn việc chỉ kiểm tra mã trích dẫn; lời dẫn có thể ngắn hơn văn phong hướng dẫn viên tự do. Không có nguồn phù hợp thì ẩn phần đó. Wikipedia tiếng Anh được tra cứu fallback nhưng không dùng để tự tạo bản dịch chưa kiểm chứng.
- Đa giác thành phố là vùng bao phủ rút gọn cho MVP, không phải bản đồ ranh giới hành chính chính thức.
- Gợi ý ăn sáng cần bằng chứng loại `breakfast_restaurant`/`brunch_restaurant`; quán cafe chung chung không được coi mặc nhiên có bữa sáng. Ăn tối cần dữ liệu giờ phục vụ sau 17:00.
- Cache nearby chỉ lưu ID địa điểm theo ô tọa độ 0,002°. Tour cache không chứa vị trí người dùng, đoạn đường từ vị trí đó, tên/địa chỉ/giờ/giá/rating của Places. Chi tiết Places chỉ gộp trong cùng request, không cache giữa các request. Tọa độ địa điểm công khai có trong tour cache tối đa 7 ngày; đó không phải vị trí người dùng. Migration `RemovePersistentPlaceCache` xóa bảng cache Places cũ và làm rỗng cache tour cũ.
- Mục tiêu latency p90, đánh giá hữu ích và kiểm chứng 50 tour cần chạy với tài khoản API và người dùng thật; test giả lập không chứng minh các chỉ số này.

Tài liệu tích hợp: [Goong REST](https://docs.goong.io/rest/), [Overpass API](https://wiki.openstreetmap.org/wiki/Overpass_API), [OpenAI Structured Outputs](https://developers.openai.com/api/docs/guides/structured-outputs?api-mode=chat), [Flutter offline/service workers](https://docs.flutter.dev/platform-integration/web/faq).
