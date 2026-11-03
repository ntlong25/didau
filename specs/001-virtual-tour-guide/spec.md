# Feature Specification: Hướng dẫn viên tour ảo & gợi ý địa điểm

**Feature Branch**: `001-virtual-tour-guide`

**Created**: 2026-11-03

**Status**: Draft

**Input**: User description: "Một app gợi ý địa điểm đi chơi, đóng vai người dẫn tour ảo. Có 2 chế độ: Chế độ 1 - Tour tham quan (chọn điểm du lịch/khu vực, tạo lộ trình có điểm dừng theo thứ tự, lời giới thiệu như hướng dẫn viên, thời gian dự kiến, đường đi; chọn thời lượng 1h/nửa ngày/cả ngày và sở thích lịch sử/ẩm thực/chụp ảnh). Chế độ 2 - Gợi ý nhanh (vị trí + nhu cầu cà phê/ăn uống/ăn sáng/ăn tối → vài địa điểm gần kèm lý do, giờ mở cửa, mức giá, khoảng cách). Lưu tour/địa điểm đã thích và xem lại. Dùng trên điện thoại, tiếng Việt là chính. Ngoài phạm vi: đặt chỗ, thanh toán, đăng nhập, chia sẻ xã hội."

## Clarifications

### Session 2026-11-03

- Q: Bản đầu cho phép tạo tour ở khu vực nào? → A: Danh sách cố định 5 thành phố: Hà Nội, TP. Hồ Chí Minh, Đà Lạt, Nha Trang, Đà Nẵng.
- Q: Gợi ý nhanh có chỉ hoạt động trong 5 thành phố này không? → A: Có, chỉ trong 5 thành phố, giống tour.
- Q: Lộ trình tour bắt đầu từ đâu? → A: Từ vị trí người dùng nếu họ đang ở trong thành phố của tour (đoạn đầu tính vào tổng thời gian); nếu không, bắt đầu từ điểm dừng đầu tiên.
- Q: Vị trí người dùng có được lưu trên server không? → A: Không lưu vị trí chính xác; chỉ dùng trong lúc xử lý yêu cầu, cache chỉ giữ toạ độ đã làm tròn (~200 m).
- Q: Thông tin địa điểm (giờ mở cửa, mức giá) được phép cũ tối đa bao lâu? → A: Tối đa 7 ngày; trạng thái đang mở/đóng vẫn tính lại theo giờ hiện tại mỗi lần hiển thị.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Gợi ý nhanh địa điểm gần đây (Priority: P1)

Người dùng đang ở ngoài, muốn tìm nhanh chỗ uống cà phê hoặc ăn uống. Họ cho app biết vị trí
(dùng vị trí hiện tại hoặc nhập địa chỉ/khu vực) và chọn nhu cầu: cà phê, ăn uống, ăn sáng hoặc
ăn tối. App trả về vài địa điểm gần đó, mỗi địa điểm có lý do nên đi, giờ mở cửa, mức giá và
khoảng cách tới người dùng.

**Why this priority**: Nhu cầu hằng ngày, tần suất dùng cao, phạm vi nhỏ nhất mà vẫn mang lại giá
trị rõ ràng — phù hợp làm MVP đầu tiên.

**Independent Test**: Chọn một vị trí ở trung tâm thành phố và nhu cầu "cà phê"; kiểm tra danh
sách trả về có địa điểm thật, đủ thông tin, sắp theo khoảng cách hợp lý.

**Acceptance Scenarios**:

1. **Given** người dùng cho phép dùng vị trí, **When** chọn nhu cầu "cà phê", **Then** app hiển thị
   3–5 địa điểm trong bán kính mặc định, mỗi địa điểm có tên, địa chỉ, lý do nên đi, giờ mở cửa,
   mức giá và khoảng cách.
2. **Given** người dùng từ chối quyền vị trí, **When** mở chế độ gợi ý nhanh, **Then** app cho phép
   nhập địa chỉ hoặc tên khu vực thay thế.
3. **Given** đang 21:00, **When** người dùng chọn "ăn sáng", **Then** app chỉ gợi ý nơi phục vụ bữa
   sáng và ghi rõ trạng thái đang mở/đã đóng, giờ mở cửa lần tới.
4. **Given** một địa điểm thiếu giờ mở cửa hoặc mức giá trong nguồn dữ liệu, **When** hiển thị,
   **Then** trường đó ghi "chưa có thông tin" thay vì một giá trị đoán.

---

### User Story 2 - Tạo tour tham quan có hướng dẫn (Priority: P2)

Người dùng chọn một điểm du lịch nổi tiếng hoặc một khu vực/thành phố, chọn thời lượng (1 giờ,
nửa ngày, cả ngày) và một hoặc nhiều sở thích (lịch sử, ẩm thực, chụp ảnh). App tạo lộ trình gồm
các điểm dừng theo thứ tự; mỗi điểm có lời giới thiệu theo giọng hướng dẫn viên (lịch sử, điều thú
vị, mẹo tham quan), thời gian dự kiến ở lại, và chỉ dẫn đường đi tới điểm kế tiếp (cách di chuyển,
quãng đường, thời gian di chuyển).

**Why this priority**: Là điểm khác biệt chính của app ("hướng dẫn viên ảo") nhưng phức tạp hơn
gợi ý nhanh, nên làm sau khi luồng cơ bản đã chạy.

**Independent Test**: Chọn "Phố cổ Hà Nội", thời lượng nửa ngày, sở thích lịch sử; kiểm tra lộ trình
có thứ tự hợp lý, tổng thời gian nằm trong thời lượng, mọi điểm dừng và dữ kiện đều có nguồn.

**Acceptance Scenarios**:

1. **Given** người dùng chọn một khu vực, thời lượng 1 giờ và sở thích "chụp ảnh", **When** yêu
   cầu tạo tour, **Then** app hiển thị lộ trình 2–4 điểm dừng, tổng thời gian (tham quan + di
   chuyển) không vượt quá 1 giờ.
2. **Given** một tour đã được tạo, **When** người dùng mở một điểm dừng, **Then** thấy lời giới
   thiệu tiếng Việt gồm phần lịch sử/bối cảnh, điều thú vị, mẹo tham quan, kèm tham chiếu nguồn.
3. **Given** một tour đã được tạo, **When** người dùng xem đoạn giữa hai điểm dừng, **Then** thấy
   phương thức di chuyển gợi ý, quãng đường và thời gian ước tính, và có thể mở chỉ đường trên bản đồ.
4. **Given** nguồn dữ liệu không có thông tin lịch sử cho một điểm, **When** tạo lời giới thiệu,
   **Then** app bỏ phần lịch sử của điểm đó thay vì tự viết nội dung không có nguồn.

---

### User Story 3 - Lưu và xem lại tour/địa điểm yêu thích (Priority: P3)

Người dùng bấm lưu một tour hoặc một địa điểm. Sau đó, kể cả khi mở lại app, họ vào mục "Đã lưu"
để xem lại danh sách và nội dung chi tiết, và có thể bỏ lưu.

**Why this priority**: Tăng giá trị dùng lại nhưng phụ thuộc vào việc đã có tour/địa điểm để lưu.

**Independent Test**: Lưu một địa điểm và một tour, đóng hẳn app, mở lại, kiểm tra cả hai vẫn
xuất hiện trong "Đã lưu" và mở được nội dung đầy đủ.

**Acceptance Scenarios**:

1. **Given** người dùng đang xem một địa điểm, **When** bấm lưu, **Then** địa điểm xuất hiện trong
   "Đã lưu" và nút đổi trạng thái thành "Đã lưu".
2. **Given** đã lưu một tour, **When** mở lại app khi không có mạng, **Then** vẫn xem được thứ tự
   điểm dừng, thời gian và lời giới thiệu của tour; tên và chi tiết địa điểm ghi "cần kết nối mạng".
3. **Given** một mục đã lưu, **When** người dùng bỏ lưu, **Then** mục đó biến mất khỏi "Đã lưu".

---

### Edge Cases

- Khu vực/điểm du lịch không tìm thấy, nằm ngoài 5 thành phố được hỗ trợ, hoặc không đủ dữ liệu để
  tạo tour → báo rõ và gợi ý chọn một trong các thành phố được hỗ trợ, không tạo tour rỗng hoặc bịa.
- Người dùng ở ngoài 5 thành phố được hỗ trợ dùng gợi ý nhanh → thông báo chưa hỗ trợ, có thể nhập
  địa chỉ trong một thành phố được hỗ trợ.
- Không có địa điểm nào phù hợp trong bán kính mặc định → đề nghị mở rộng bán kính.
- Mất mạng khi tạo tour hoặc gợi ý → thông báo lỗi thân thiện, cho phép thử lại; mục đã lưu vẫn xem được.
- Thời lượng quá ngắn so với khoảng cách giữa các điểm → tour ít điểm hơn chứ không vượt thời lượng.
- Địa điểm trong nguồn đã đóng cửa vĩnh viễn → không được gợi ý.
- Người dùng chọn nhiều sở thích cùng lúc → tour cân bằng giữa các sở thích đã chọn.
- Tên địa điểm/địa chỉ chỉ có bằng tiếng Anh trong nguồn → vẫn hiển thị nguyên tên gốc, phần mô tả bằng tiếng Việt.
- Tạo lại tour với cùng lựa chọn → trả kết quả nhanh như lần trước; người dùng có thể yêu cầu tạo phương án khác.

## Requirements *(mandatory)*

### Functional Requirements

**Chung**

- **FR-001**: App MUST hoạt động trên điện thoại, giao diện và nội dung mặc định bằng tiếng Việt.
- **FR-002**: Mọi địa điểm, địa chỉ, giờ mở cửa, mức giá và dữ kiện lịch sử hiển thị cho người dùng
  MUST lấy từ nguồn dữ liệu có thật; app MUST NOT hiển thị dữ kiện không có nguồn.
- **FR-003**: Khi một trường thông tin không có trong nguồn, app MUST hiển thị "chưa có thông tin".
- **FR-004**: Mỗi địa điểm và lời giới thiệu MUST có cách cho người dùng xem nguồn tham chiếu.
- **FR-005**: App MUST NOT yêu cầu đăng nhập hay tạo tài khoản để dùng bất kỳ chức năng nào.
- **FR-006**: Hệ thống MUST NOT lưu lâu dài vị trí chính xác của người dùng; vị trí chỉ được dùng
  trong lúc xử lý yêu cầu. Kết quả dùng lại (cache) chỉ được gắn với toạ độ đã làm tròn khoảng 200 m
  và MUST NOT chứa thông tin định danh thiết bị hay người dùng.

**Gợi ý nhanh**

- **FR-010**: Người dùng MUST chọn được vị trí bằng vị trí hiện tại của thiết bị hoặc nhập địa chỉ/khu vực.
  Khi nhập địa chỉ, app MUST hiển thị tối đa 5 kết quả khớp nằm trong các thành phố được hỗ trợ để
  người dùng chọn.
- **FR-010a**: Gợi ý nhanh MUST chỉ hoạt động khi vị trí nằm trong 5 thành phố được hỗ trợ; ngoài
  phạm vi này app MUST báo rõ chưa hỗ trợ và liệt kê các thành phố được hỗ trợ.
- **FR-011**: Người dùng MUST chọn được một nhu cầu: cà phê, ăn uống, ăn sáng, ăn tối.
- **FR-012**: App MUST trả về 3–5 địa điểm phù hợp nhu cầu trong bán kính mặc định 2 km, sắp theo
  mức phù hợp và khoảng cách.
- **FR-013**: Mỗi gợi ý MUST gồm: tên, địa chỉ, lý do nên đi (1–2 câu), giờ mở cửa và trạng thái
  đang mở/đóng, mức giá, khoảng cách từ vị trí người dùng.
- **FR-014**: App MUST ưu tiên địa điểm đang mở cửa tại thời điểm tìm kiếm và MUST NOT gợi ý địa
  điểm đã đóng cửa vĩnh viễn.
- **FR-014a**: Thông tin địa điểm (giờ mở cửa, mức giá, trạng thái hoạt động) hiển thị cho người
  dùng MUST NOT cũ hơn 7 ngày so với nguồn; trạng thái đang mở/đóng MUST được tính lại theo thời
  điểm hiển thị.
- **FR-015**: Khi không đủ kết quả, app MUST cho phép mở rộng bán kính tìm kiếm.

**Tour tham quan**

- **FR-020**: Người dùng MUST chọn được một trong 5 thành phố được hỗ trợ (Hà Nội, TP. Hồ Chí Minh,
  Đà Lạt, Nha Trang, Đà Nẵng), hoặc một khu vực/điểm du lịch nổi tiếng thuộc các thành phố này.
  Tour ở nơi khác không được hỗ trợ trong bản đầu.
- **FR-021**: Người dùng MUST chọn được thời lượng: 1 giờ, nửa ngày (~4 giờ), cả ngày (~8 giờ).
- **FR-022**: Người dùng MUST chọn được một hoặc nhiều sở thích: lịch sử, ẩm thực, chụp ảnh.
- **FR-023**: App MUST tạo lộ trình gồm các điểm dừng theo thứ tự, tổng thời gian tham quan và di
  chuyển không vượt thời lượng đã chọn.
- **FR-023a**: Nếu người dùng cho phép dùng vị trí và đang ở trong thành phố của tour, lộ trình MUST
  bắt đầu từ vị trí đó và đoạn đường tới điểm dừng đầu tiên MUST được tính vào tổng thời gian; nếu
  không, lộ trình bắt đầu tại điểm dừng đầu tiên.
- **FR-024**: Mỗi điểm dừng MUST có lời giới thiệu theo giọng hướng dẫn viên gồm các phần (khi có
  nguồn): lịch sử/bối cảnh, điều thú vị, mẹo tham quan; và thời gian dự kiến ở lại.
- **FR-025**: Giữa hai điểm dừng liên tiếp, app MUST hiển thị phương thức di chuyển gợi ý, quãng
  đường, thời gian ước tính, và cho phép mở chỉ đường trên ứng dụng bản đồ của điện thoại.
- **FR-026**: Người dùng MUST yêu cầu được một phương án tour khác với cùng lựa chọn.
- **FR-027**: Khi dữ liệu không đủ để tạo tour, app MUST báo rõ lý do thay vì trả tour thiếu căn cứ.

**Đã lưu**

- **FR-030**: Người dùng MUST lưu và bỏ lưu được một địa điểm hoặc một tour.
- **FR-031**: Mục đã lưu MUST còn sau khi đóng/mở lại app. Thiết bị chỉ lưu ID địa điểm, tọa độ
  (xóa sau 30 ngày) và dữ liệu tour của app (thứ tự, thời gian, đường đi, lời dẫn có nguồn
  Wikipedia); tên, địa chỉ, giờ, giá MUST được tải lại khi mở (điều khoản Google Places). Khi
  offline, lời dẫn tour MUST xem được; chi tiết địa điểm hiển thị "cần kết nối mạng".
- **FR-032**: Mục "Đã lưu" MUST liệt kê tour và địa điểm, mới lưu nhất ở trên.

### Key Entities

- **Địa điểm (Place)**: một nơi có thật — tên, địa chỉ, toạ độ, loại (quán cà phê, nhà hàng, di
  tích…), giờ mở cửa, mức giá, trạng thái hoạt động, tham chiếu nguồn.
- **Yêu cầu gợi ý nhanh**: vị trí (không lưu lâu dài; khi dùng lại chỉ giữ bản làm tròn), nhu cầu, bán kính, thời điểm tìm kiếm.
- **Gợi ý (Suggestion)**: một địa điểm kèm lý do nên đi và khoảng cách, thuộc một yêu cầu gợi ý.
- **Tour**: thành phố/khu vực, điểm xuất phát (vị trí người dùng hoặc điểm dừng đầu tiên), thời lượng, sở thích, danh sách điểm dừng có thứ tự, tổng thời gian.
- **Điểm dừng (Tour Stop)**: tham chiếu tới một Địa điểm, thứ tự, thời gian dự kiến, lời giới thiệu
  (lịch sử, điều thú vị, mẹo) cùng nguồn của từng phần.
- **Đoạn đường (Leg)**: nối hai điểm dừng — phương thức di chuyển, quãng đường, thời gian ước tính.
- **Mục đã lưu (Saved Item)**: bản chụp của một Tour hoặc Địa điểm, thời điểm lưu; lưu trên thiết bị.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Người dùng nhận được gợi ý nhanh trong vòng 5 giây sau khi chọn nhu cầu, ở 90% lần dùng.
- **SC-002**: Người dùng nhận được một tour hoàn chỉnh trong vòng 20 giây ở 90% lần tạo mới; tour
  đã từng tạo với cùng lựa chọn hiển thị trong vòng 3 giây.
- **SC-003**: 100% địa điểm hiển thị đối chiếu được với một bản ghi nguồn có thật; trong kiểm tra
  thủ công 50 tour/gợi ý ngẫu nhiên, không có địa chỉ hay sự kiện nào bị bịa.
- **SC-004**: 100% tour có tổng thời gian không vượt thời lượng người dùng chọn.
- **SC-005**: Người dùng mới hoàn thành một lần gợi ý nhanh trong dưới 30 giây và tạo một tour trong
  dưới 1 phút (tính từ lúc mở app), không cần hướng dẫn.
- **SC-006**: Ít nhất 70% người dùng thử nghiệm đánh giá lời giới thiệu tour "hữu ích" hoặc "rất hữu ích".
- **SC-007**: Khi không có mạng, mục đã lưu mở được và lời dẫn tour hiển thị đầy đủ ở 100% lần thử;
  khi có mạng, chi tiết địa điểm được tải lại đầy đủ.

## Assumptions

- Phạm vi địa lý của bản đầu là Việt Nam; người dùng chính là người Việt đi chơi trong nước. Tour
  tham quan và gợi ý nhanh đều giới hạn ở 5 thành phố: Hà Nội, TP. Hồ Chí Minh, Đà Lạt, Nha Trang, Đà Nẵng.
- Không có tài khoản, nên mục đã lưu chỉ nằm trên thiết bị và mất khi gỡ app; không đồng bộ giữa thiết bị.
- Bán kính mặc định của gợi ý nhanh là 2 km; mở rộng lên tối đa 5 km.
- "Nửa ngày" ≈ 4 giờ, "cả ngày" ≈ 8 giờ, bao gồm cả thời gian di chuyển.
- Phương thức di chuyển mặc định trong tour là đi bộ khi các điểm gần nhau, xe máy/taxi khi xa hơn;
  app chỉ hiển thị gợi ý, chỉ đường chi tiết do ứng dụng bản đồ của điện thoại đảm nhận.
- Mức giá hiển thị theo thang tương đối (rẻ / vừa / cao) hoặc khoảng giá nếu nguồn có.
- Cần kết nối Internet để tạo tour và gợi ý mới.
- Ngoài phạm vi bản đầu: đặt chỗ, thanh toán, đăng nhập, chia sẻ xã hội, đánh giá/bình luận của
  người dùng, đa ngôn ngữ ngoài tiếng Việt, dẫn đường thời gian thực, thuyết minh bằng giọng nói.
- Phụ thuộc: một hoặc nhiều nguồn dữ liệu địa điểm/bản đồ và nguồn thông tin lịch sử/văn hoá có
  thật cho các điểm du lịch Việt Nam.
