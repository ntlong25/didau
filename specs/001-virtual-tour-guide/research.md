# Research: Hướng dẫn viên tour ảo & gợi ý địa điểm

## 1. Client: Flutter (PWA) hay native iOS Swift

- **Decision**: Flutter 3.x, build bản web dạng PWA. Có thể build thêm Android/iOS sau từ cùng mã.
- **Rationale**: Yêu cầu là PWA mobile-first. Swift không build ra PWA và cần máy Mac, trong khi máy
  phát triển là Windows. Flutter web có sẵn `manifest.json` và service worker cho PWA, và
  `shared_preferences` trên web lưu vào `localStorage`, khớp yêu cầu lưu yêu thích.
- **Alternatives considered**: Swift/SwiftUI (không phải PWA, chỉ iOS, cần macOS); React/TS PWA thuần
  (nhẹ hơn trên web nhưng ngoài lựa chọn người dùng đưa ra).

## 2. "OpenAPI API" để sinh lời dẫn

- **Decision**: Hiểu là **OpenAI API** (Chat Completions/Responses với Structured Outputs theo JSON
  schema). Tên model đặt trong cấu hình (`OpenAi:Model`), mặc định một model nhỏ, rẻ.
- **Rationale**: Structured Outputs buộc kết quả đúng schema có trường `sourceIds`, nhờ đó
  validator kiểm tra được.
- **Alternatives considered**: Sinh văn bản tự do rồi tách bằng regex (không kiểm tra được nguồn một
  cách tin cậy).

## 3. Ai chọn điểm dừng tour

- **Decision**: Backend chọn và sắp xếp điểm dừng bằng thuật toán tất định (`RouteBuilder`). LLM
  chỉ viết lời dẫn cho các điểm đã chọn.
- **Rationale**: Nguyên tắc III. LLM không thể đưa vào một địa điểm không có thật, và việc tour
  không vượt thời lượng (SC-004) được đảm bảo bằng code có test.
- **Thuật toán**:
  1. Lấy ứng viên: điểm tham quan nổi tiếng của thành phố/khu vực qua Places Text Search
     (`tourist_attraction`, `museum`, `historical_landmark`, `restaurant` khi chọn ẩm thực), sau đó
     ghép với Wikidata/Wikipedia.
  2. Chấm điểm: mức khớp sở thích + rating/số lượt đánh giá + có bài Wikipedia (ưu tiên khi chọn
     lịch sử).
  3. Sắp thứ tự: láng giềng gần nhất bắt đầu từ điểm xuất phát.
  4. Thêm điểm cho tới khi cộng thêm sẽ vượt thời lượng.
  5. Thời gian ở lại mỗi điểm theo loại: 20–90 phút.
- **Alternatives considered**: Để LLM lên lộ trình (dễ bịa, khó kiểm thử); bài toán TSP tối ưu
  (thừa với 2–8 điểm).

## 4. Đường đi giữa các điểm

- **Decision**: Ước tính bằng khoảng cách haversine × hệ số đường 1,3. Đi bộ 4,5 km/h nếu ≤ 1,5 km,
  ngược lại xe máy/taxi 20 km/h. Nút "Chỉ đường" mở Google Maps bằng URL
  `https://www.google.com/maps/dir/?api=1&...`.
- **Rationale**: Spec chỉ cần ước tính và chuyển chỉ đường chi tiết cho app bản đồ. Không gọi
  Directions/Routes API thì tiết kiệm chi phí, và hàm thuần dễ test.
- **Alternatives considered**: Google Routes API (chính xác hơn nhưng tốn phí cho mỗi đoạn; để dành
  cho bản sau).

## 5. Nguồn dữ liệu

- **Quán/địa điểm**: Google Places API (New) — Nearby Search, Text Search, Place Details. Dùng
  field mask để chỉ lấy `id, displayName, formattedAddress, location, types, regularOpeningHours,
  priceLevel, rating, userRatingCount, businessStatus, editorialSummary, googleMapsUri` (giảm chi phí).
  Loại `businessStatus = CLOSED_PERMANENTLY`.
- **Lịch sử/điều thú vị**: Wikidata (tìm theo tên + tọa độ gần, lấy QID, mô tả, năm thành lập,
  sitelink viwiki/enwiki) → Wikipedia REST `page/summary` (ưu tiên tiếng Việt, không có thì
  tiếng Anh). Mỗi đoạn trích là một "fact" có ID và URL nguồn.
- **Lý do nên đi (gợi ý nhanh)**: ghép từ dữ liệu Places (`editorialSummary`, rating, số đánh giá,
  đang mở). Không gọi LLM cho gợi ý nhanh ở MVP, để giữ ≤ 5 s và chi phí thấp.
- **Alternatives considered**: OpenStreetMap/Overpass (miễn phí nhưng giờ mở cửa và giá ở Việt Nam
  thiếu nhiều).

## 6. Grounding validator

- **Decision**:
  - Prompt chỉ chứa JSON các điểm dừng (ID địa điểm) và danh sách facts (ID, văn bản, URL).
  - Schema đầu ra: mỗi stop có `placeId` và các section `history | trivia | tips`, mỗi section có
    `text` và `sourceIds[]`.
  - Validator loại section có `sourceIds` rỗng hoặc chứa ID không tồn tại trong ngữ cảnh, và
    loại stop có `placeId` lạ.
  - Validator loại section chứa số điện thoại, địa chỉ, năm hoặc con số không xuất hiện trong
    các fact được trích.
  - Địa chỉ, giờ, giá luôn hiển thị từ Places, không từ LLM.
- **Rationale**: Biến Nguyên tắc III thành quy tắc kiểm tra được bằng unit test.
- **Alternatives considered**: Gọi LLM lần 2 để tự kiểm tra (đắt, không tất định).

## 7. Cache & khóa cache

- **Ràng buộc điều khoản Google Maps Platform** (đã kiểm tra 2026-11-03 trên Service Specific Terms
  bản 2024-05-22, mục 5 Places API, và trang Places API Policies):
  - 5.4: chỉ được cache tạm `lat`/`lng` tối đa 30 ngày liên tục; `place_id` được lưu vô thời hạn.
    Không có điều khoản nào cho phép cache nội dung khác (tên, địa chỉ, giờ, giá, rating, summary).
  - 5.2: dùng nội dung Places mà không kèm bản đồ Google thì PHẢI hiển thị ghi công (attribution)
    Google theo tài liệu.
  - 5.3: không dùng nội dung Places cùng bản đồ không phải của Google.
  - Cần đối chiếu lại bản hiện hành của điều khoản trước khi phát hành.
- **Decision**: Bảng PostgreSQL qua EF Core:
  - `tour_cache`: khóa = SHA-256 của `cityId|areaPlaceId|duration|interests(sắp xếp)|variant|promptVersion`,
    TTL 7 ngày. Payload chỉ gồm danh sách stop `{placeId, location, order, stayMinutes}`, lời dẫn
    và facts từ Wikipedia/Wikidata; KHÔNG chứa nội dung Places khác. Khi trả tour, chi tiết địa
    điểm được lấy lại qua `IPlacesClient.GetDetails` (song song, qua cache bộ nhớ). Không gồm vị
    trí người dùng: đoạn từ vị trí người dùng tới điểm đầu được tính khi trả về, không lưu.
  - Chi tiết địa điểm: KHÔNG lưu PostgreSQL và KHÔNG cache giữa các request (điều khoản không cho
    phép cache nội dung ngoài lat/lng và place_id, kể cả trong bộ nhớ). Chỉ gộp các lần gọi trùng
    trong cùng một request. Nhờ đó dữ liệu hiển thị luôn mới, thỏa FR-014a.
  - `nearby_cache`: khóa = (lat, lng làm tròn 0,002° ≈ 200 m, need, radius), lưu danh sách place
    ID, TTL 24 giờ.
  - Chi phí: tour lấy từ cache tốn thêm N lần gọi Place Details (N = số stop) nhưng vẫn bỏ được lần
    gọi LLM, là chi phí lớn nhất.
  - `wiki_cache`: theo QID/tiêu đề, TTL 30 ngày.
  - Trạng thái mở/đóng luôn tính lại từ `regularOpeningHours` theo giờ Asia/Ho_Chi_Minh lúc trả về.
- **Rationale**: Đúng Nguyên tắc V và FR-006. Thêm `promptVersion` vào khóa để đổi prompt không
  trả về lời dẫn cũ.
- **Hệ quả của FR-023a**: Nếu người dùng ở trong thành phố, `RouteBuilder` chạy lại thứ tự từ vị
  trí người dùng trên các stop đã cache (rẻ, không gọi LLM). Bớt stop cuối nếu vượt thời lượng.

## 8. Giới hạn 5 thành phố

- **Decision**: Cấu hình tĩnh trong `DiDau.Core/Cities`: ID, tên, tâm, bounding polygon đơn giản
  (đa giác hành chính rút gọn). Hàm `CityLocator.Find(lat, lng)` dùng cho FR-010a và FR-023a.
- **Alternatives considered**: Reverse geocoding mỗi lần (tốn phí, chậm).

## 9. Rate limit & bí mật

- **Decision**: `AddRateLimiter` fixed window theo IP: 30 req/phút cho `/api/suggestions`, 5 req/phút
  cho `POST /api/tours`. Key đọc từ biến môi trường `GooglePlaces__ApiKey`, `OpenAi__ApiKey`;
  dev dùng `dotnet user-secrets`; có `appsettings.Example.json` không chứa giá trị thật.
  CORS chỉ cho origin của PWA.

## 10. Offline cho mục đã lưu

- **Decision**: Lưu bản chụp JSON đầy đủ (tour/địa điểm) vào `localStorage` qua `shared_preferences`.
  Service worker mặc định của Flutter cache app shell, nên app mở được khi offline.
- **Giới hạn**: `localStorage` ~5 MB, đủ cho hàng trăm tour. Xóa dữ liệu trình duyệt thì mất,
  đúng giả định của spec.
