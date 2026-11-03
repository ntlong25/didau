<!--
Sync Impact Report
- Version change: (template, unversioned) → 1.0.0
- Modified principles (template placeholders → new titles):
  - [PRINCIPLE_1_NAME] → I. MVP nhỏ, chạy trên điện thoại
  - [PRINCIPLE_2_NAME] → II. Backend .NET 8 có unit test cho logic chính
  - [PRINCIPLE_3_NAME] → III. Nội dung AI dựa trên nguồn có thật (NON-NEGOTIABLE)
  - [PRINCIPLE_4_NAME] → IV. Bí mật chỉ nằm ở server
  - [PRINCIPLE_5_NAME] → V. Cache để giảm chi phí API ngoài
- Added sections: Ràng buộc kỹ thuật; Quy trình phát triển & cổng chất lượng
- Removed sections: none
- Templates: not modified (dependent templates read the constitution at runtime)
- Follow-up TODOs: none
-->

# Đi Đâu (di-dau) Constitution

## Core Principles

### I. MVP nhỏ, chạy trên điện thoại

- Mỗi tính năng PHẢI được cắt về phạm vi nhỏ nhất mà người dùng thật có thể dùng được
  trên điện thoại; tính năng "để sau" PHẢI ghi rõ là ngoài phạm vi trong spec.
- Ứng dụng client PHẢI chạy được trên thiết bị di động thật, viết bằng Flutter hoặc native
  iOS. Lựa chọn cụ thể PHẢI được ghi trong plan của tính năng đầu tiên và giữ nhất quán
  sau đó; không duy trì song song hai client trong giai đoạn MVP.
- Không thêm thư viện, service hay tầng trừu tượng nếu MVP hiện tại không cần đến (YAGNI).

**Lý do**: Ra được bản chạy thật trên điện thoại sớm quan trọng hơn kiến trúc hoàn chỉnh.

### II. Backend .NET 8 có unit test cho logic chính

- Backend PHẢI dùng .NET 8 (ASP.NET Core).
- Logic nghiệp vụ chính (sinh/lọc tour, chọn nguồn dữ liệu, kiểm tra trích dẫn, quy tắc
  cache, ánh xạ dữ liệu từ API ngoài) PHẢI có unit test chạy được bằng `dotnet test`.
- Logic nghiệp vụ PHẢI tách khỏi controller và HTTP client để test được mà không gọi
  mạng; API ngoài (bản đồ, địa điểm, LLM) PHẢI được gọi qua interface có thể mock.
- Một thay đổi làm hỏng test hiện có không được merge.

**Lý do**: Logic tour và cache là nơi dễ sai âm thầm; test là cách rẻ nhất để giữ đúng.

### III. Nội dung AI dựa trên nguồn có thật (NON-NEGOTIABLE)

- Mọi nội dung tour do AI sinh (địa điểm, địa chỉ, giờ mở cửa, sự kiện, lịch sử, mô tả)
  PHẢI được dựng từ dữ liệu lấy từ nguồn có thật (API địa điểm/bản đồ, cơ sở dữ liệu
  đã kiểm chứng, nguồn mở có ghi nguồn) và được đưa vào prompt làm ngữ cảnh.
- AI KHÔNG ĐƯỢC tự bịa sự kiện, địa điểm, địa chỉ, số điện thoại, giá hay giờ mở cửa.
  Dữ kiện không có trong nguồn PHẢI bị bỏ hoặc hiển thị là "chưa có thông tin".
- Mỗi điểm dừng trong tour PHẢI giữ được tham chiếu tới bản ghi nguồn (ID/URL nguồn) và
  server PHẢI kiểm tra rằng mọi địa điểm trong kết quả AI đều khớp với một bản ghi nguồn
  trước khi trả về client; kết quả không khớp PHẢI bị loại.
- Quy tắc kiểm tra này là logic chính theo Nguyên tắc II và PHẢI có unit test.

**Lý do**: Một địa chỉ sai làm người dùng đi lạc; độ tin cậy là giá trị cốt lõi của app.

### IV. Bí mật chỉ nằm ở server

- API key và secret (LLM, bản đồ, địa điểm, v.v.) PHẢI chỉ nằm ở backend, đọc từ biến
  môi trường hoặc secret store; KHÔNG ĐƯỢC commit vào repo hay nhúng vào app di động.
- App di động PHẢI gọi API ngoài thông qua backend; không gọi trực tiếp bằng key của
  dịch vụ thứ ba.
- Backend PHẢI có giới hạn tần suất (rate limit) cho các endpoint gây tốn phí gọi API ngoài.
- Log KHÔNG ĐƯỢC ghi ra key hay token.

**Lý do**: Key trong app di động có thể bị trích xuất và dùng trái phép, gây mất tiền.

### V. Cache để giảm chi phí API ngoài

- Phản hồi từ API ngoài (địa điểm, bản đồ, LLM) PHẢI được cache ở backend với khóa xác
  định (ví dụ: loại truy vấn + tham số đã chuẩn hóa) và TTL rõ ràng cho từng loại dữ liệu.
- Kết quả tour đã sinh cho cùng đầu vào chuẩn hóa PHẢI được dùng lại từ cache thay vì
  gọi lại LLM, trừ khi người dùng yêu cầu tạo mới.
- Không cache dữ liệu cá nhân của người dùng vào cache dùng chung.
- MVP dùng cache đơn giản nhất đáp ứng được (in-memory hoặc lưu bền đơn giản); chỉ thêm
  cache phân tán khi có nhu cầu đo được.

**Lý do**: Chi phí gọi LLM và API bản đồ là chi phí vận hành lớn nhất của MVP.

## Ràng buộc kỹ thuật

- Client: Flutter hoặc native iOS (chọn một, ghi trong plan).
- Backend: .NET 8, xUnit (hoặc tương đương) cho unit test.
- Cấu hình và secret qua biến môi trường / user-secrets khi phát triển; có file mẫu cấu
  hình không chứa giá trị thật.
- Mọi tích hợp API ngoài đi qua một lớp adapter có interface, để mock trong test và để
  gắn cache tại một chỗ.

## Quy trình phát triển & cổng chất lượng

- Mỗi tính năng đi theo luồng Spec Kit: specify → plan → tasks → implement.
- Phần "Constitution Check" trong plan PHẢI xác nhận từng nguyên tắc I–V; vi phạm PHẢI
  được ghi lý do trong bảng Complexity Tracking.
- Trước khi coi một tính năng là xong: `dotnet test` xanh, app chạy được trên điện thoại
  (thiết bị thật hoặc emulator/simulator), không có secret trong mã nguồn client hay repo.
- Mọi thay đổi chạm vào prompt hoặc logic sinh tour PHẢI kèm test cho việc loại bỏ dữ kiện
  không có nguồn.

## Governance

- Constitution này ưu tiên hơn mọi quy ước khác của dự án.
- Sửa đổi PHẢI thực hiện qua `/speckit-constitution`, kèm Sync Impact Report và cập nhật
  ngày sửa đổi.
- Phiên bản theo semantic versioning: MAJOR khi bỏ hoặc định nghĩa lại nguyên tắc; MINOR
  khi thêm nguyên tắc/mục hoặc mở rộng đáng kể; PATCH khi chỉ làm rõ câu chữ.
- Mỗi plan và mỗi lần review thay đổi PHẢI kiểm tra tuân thủ các nguyên tắc trên.

**Version**: 1.0.0 | **Ratified**: 2026-11-03 | **Last Amended**: 2026-11-03
