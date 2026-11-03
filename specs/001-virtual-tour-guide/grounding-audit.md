# Grounding audit

Ngày: 2026-11-03. Trạng thái: **CHƯA CHẠY kiểm chứng thủ công 50 tour/gợi ý thật (T066)**.

Chưa có cấu hình tài khoản Google Places/OpenAI và PostgreSQL hoạt động trong phiên triển khai. Không thay dữ liệu giả lập thành bằng chứng về chất lượng dữ liệu thật.

Kiểm tra tự động đã có: loại place ID lạ; source ID rỗng/lạ/thuộc địa điểm khác; năm/số điện thoại bịa; câu không chứa số nhưng không khớp nguồn; trường thiếu không được tự điền; nơi đóng cửa vĩnh viễn bị loại. Mọi HTTP provider trong test đều giả lập.

Khi có môi trường thật, kiểm tra 10 kết quả mỗi thành phố (Hà Nội, TP. Hồ Chí Minh, Đà Lạt, Nha Trang, Đà Nẵng), cân bằng gợi ý và tour. Với mỗi kết quả ghi request không chứa vị trí cá nhân chính xác, thời điểm, place ID, URL nguồn, đối chiếu tên/địa chỉ/giờ/giá và từng câu lời dẫn, kết luận cùng sai khác. Chỉ đánh dấu T066 sau khi đủ 50 mẫu đã đối chiếu.

| Mẫu | Thành phố | Loại | Place ID / Tour ID | Nguồn | Đối chiếu | Kết quả |
|---|---|---|---|---|---|---|
| Chưa có dữ liệu thật | | | | | | Chưa chạy |
