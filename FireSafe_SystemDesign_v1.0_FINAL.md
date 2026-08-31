# FireSafe

Fire Safety Asset Management · OCR/QR · Inspection · Reminder

**System Design & Software Requirements  
Specification**

**Quản lý thiết bị PCCC theo cơ sở/khu vực, số hóa nhãn và tem bằng OCR/QR, ghi nhận kiểm tra định kỳ, nhắc việc và hỗ trợ đồng bộ ngoại tuyến.**

Đặc tả tham chiếu cho việc triển khai ứng dụng FireSafe.

**Phiên bản:** v1.0 — Internal Planning Document

**Trạng thái: DRAFT – For Review**

**Mã dự án:** FRS-SYS-SPEC

**Ngày phát hành:** 31/08/2026

**Đối tượng đọc:** Tech Lead · Product · Mobile · Backend · AI/CV · QA · Reviewer

# Mục lục

**0\. Revision History** 5

**1\. Executive Summary** 5

1.1 Purpose & Audience 5

1.2 Product Overview 5

1.3 Design Principles 5

1.4 Goals & Non-Goals 6

1.5 Success Criteria 6

**2\. Project Context & Scope** 6

2.1 Primary User Journey 6

2.2 In Scope 7

2.3 Out of Scope 7

2.4 User & Ownership Model 7

2.5 External Dependencies 7

2.6 Data Source-of-Truth Policy 8

**3\. Functional Requirements** 8

3.1 Requirement Model & Priorities 8

3.2 M1 — Authentication & Onboarding 8

3.3 M2 — Facility & Area Management 9

3.4 M3 — Asset Registration & OCR/QR 9

3.5 M4 — Asset Detail & Lifecycle Data 10

3.6 M5 — Periodic Inspection 10

3.7 M6 — History & Audit Trail 10

3.8 M7 — Reminders & Notifications 11

3.9 M8 — Offline Sync & Recovery 11

3.10 M9 — Reporting & Export 11

3.11 M10 — Settings & Profile 12

3.12 Future Features F1–F7 12

**4\. System Architecture** 13

4.1 Architecture Principles 13

4.2 System Context 13

4.3 Logical Components 14

4.4 Device Registration Flow 15

4.5 Periodic Inspection Flow 15

4.6 Offline Sync Flow 16

4.7 Degraded Modes & Failure Boundaries 16

**5\. Domain & Data Design** 17

5.1 Core Domain Model 17

5.2 Asset & Inspection State 17

5.3 Data Provenance 18

5.4 Proposed Relational Model 18

**6\. OCR / Recognition Design** 19

6.1 Recognition Pipeline 19

6.2 QR Resolution 19

6.3 OCR Field Extraction 19

6.4 Confidence & Human Confirmation 19

6.5 Failure Fallback & Guardrails 19

6.6 Evidence Storage 20

**7\. Inspection & Reminder Design** 20

7.1 Checklist Model 20

7.2 Inspection Event Model 20

7.3 Reminder Scheduling 20

7.4 Notification Rules 20

7.5 Safety & Legal Boundary 21

**8\. API Design** 21

8.1 API Conventions 21

8.2 Endpoint Catalog 21

8.3 Core Request / Response Contracts 22

8.4 Error Model 22

8.5 Concurrency, Sync & Idempotency 22

**9\. External Integration Design** 23

9.1 OCR / Recognition Provider 23

9.2 Push Notification Gateway 23

9.3 Object Storage 23

9.4 Report Generation 23

9.5 Cost & Quota Control 23

**10\. Non-Functional Requirements** 23

10.1 Performance 23

10.2 Correctness & Data Integrity 24

10.3 Reliability & Offline Capability 24

10.4 Security 24

10.5 Privacy 24

10.6 Usability & Accessibility 25

10.7 Maintainability 25

10.8 Scalability 25

10.9 Observability 25

10.10 Testability 26

**11\. Security & Privacy Design** 26

**12\. Observability & Operations** 26

**13\. Test Strategy** 27

13.1 Required Regression Scenarios 27

**14\. Risk Register & Mitigations** 28

**15\. Delivery Plan** 28

**16\. Acceptance & Release Gates** 29

**17\. Open Questions & Future Evolution** 29

**18\. Glossary** 30

# 0\. Revision History

| **Version** | **Ngày** | **Tác giả** | **Người duyệt** | **Tóm tắt thay đổi** |
| --- | --- | --- | --- | --- |
| **V1.0** | 31/08/2026 | Hưng |     | Bản nháp đầu tiên cho FireSafe: phạm vi sản phẩm, FR/NFR, kiến trúc, OCR/QR, kiểm tra định kỳ, reminder, offline sync, API, kiểm thử và kế hoạch triển khai. |
| **v1.x** |     |     |     | Mốc cơ sở sau vòng review đầu tiên và sau khi chốt các câu hỏi mở. |
|     |     |     |     | Cập nhật sau prototype usability test và benchmark OCR. |

|     |     |
| --- | --- |
| **!** | **Document status: Tài liệu này là mốc cơ sở thiết kế phục vụ review. Các phần gắn nhãn “Proposed” là quyết định kiến trúc đề xuất từ prototype hiện tại, chưa phải cam kết sản phẩm đã được phê duyệt.** |

# 1\. Executive Summary

## 1.1 Purpose & Audience

Tài liệu này chuyển prototype FireSafe thành một đặc tả có thể triển khai và kiểm thử, bao gồm phạm vi, yêu cầu chức năng, yêu cầu phi chức năng, kiến trúc logic, mô hình dữ liệu, pipeline OCR/QR, kiểm tra định kỳ, nhắc việc, đồng bộ ngoại tuyến, hợp đồng API, chiến lược kiểm thử và điều kiện phát hành.

Đối tượng sử dụng chính là Tech Lead, Product/BA, Mobile, Backend, nhóm AI/CV hoặc OCR integration, QA và người phản biện đồ án. Mục tiêu là để các nhóm có cùng một nguồn tham chiếu thống nhất về “hệ thống phải làm gì”, “dữ liệu nào được xem là đã xác nhận”, “thành phần nào chịu trách nhiệm” và “khi lỗi thì hệ thống phải suy giảm như thế nào”.

## 1.2 Product Overview

FireSafe là ứng dụng quản lý thiết bị phòng cháy chữa cháy theo cơ sở và khu vực. Người dùng có thể tạo cơ sở, quét QR/nhãn/tem bằng camera, xem và sửa dữ liệu nhận diện, xác nhận vị trí thiết bị, theo dõi mốc bảo dưỡng/kiểm tra, thực hiện checklist định kỳ, lưu ảnh bằng chứng, xem lịch sử, nhận nhắc việc và xuất báo cáo.

Điểm khác biệt của luồng prototype là nguyên tắc “human-in-the-loop”: OCR/QR chỉ hỗ trợ nhập liệu; dữ liệu nhận diện, mốc thời gian và vị trí phải được người dùng xem lại trước khi trở thành dữ liệu vận hành. Các trạng thái OCR lỗi, QR không có dữ liệu, thiếu quyền Camera, offline và lỗi đồng bộ đều có đường phục hồi rõ ràng thay vì chặn toàn bộ công việc hiện trường.

|     |     |
| --- | --- |
| **P** | **Core product promise: Quét hoặc nhập thiết bị → xác nhận dữ liệu và vị trí → theo dõi mốc → ghi nhận kiểm tra tại hiện trường → lưu lịch sử/bằng chứng → nhắc việc và xuất báo cáo.** |

## 1.3 Design Principles

- Human-confirmed data: OCR/QR không được tự động biến kết quả nhận diện thành dữ liệu chính thức nếu người dùng chưa xác nhận.
- Offline-first for field work: quét, nhập thiết bị và ghi nhận kiểm tra phải tiếp tục được khi mạng không ổn định; đồng bộ là bước có thể trì hoãn.
- Traceability by default: thay đổi quan trọng phải tạo lịch sử/audit event và giữ nguồn dữ liệu để có thể đối chiếu.
- Evidence-aware: ảnh thiết bị, ảnh tem và ảnh vị trí có vấn đề là bằng chứng bổ trợ; chỉ lưu khi người dùng xác nhận theo chính sách quyền riêng tư.
- Safety-support, not legal authority: ứng dụng hỗ trợ quản lý và nhắc việc, không tự suy luận rằng một mốc OCR là kết luận pháp lý hoặc chứng nhận an toàn.
- Graceful degradation: lỗi OCR, quyền Camera, mạng, push hoặc report không được làm mất dữ liệu đã ghi nhận hợp lệ trên thiết bị.

## 1.4 Goals & Non-Goals

| **Loại** | **Nội dung** |
| --- | --- |
| **Goals** | Quản lý cơ sở/khu vực và thiết bị; đăng ký thiết bị bằng OCR/QR hoặc nhập tay; theo dõi mốc đã xác nhận; checklist kiểm tra; bằng chứng; lịch sử; reminder/notification; offline sync; báo cáo PDF/CSV; cài đặt/profile. |
| **Non-Goals** | Không thay thế cơ quan kiểm định hoặc đánh giá chuyên môn; không tự xác nhận thiết bị đạt quy chuẩn; không bảo đảm dữ liệu OCR chính xác tuyệt đối; không thay thế quy trình bảo trì của nhà cung cấp; không tự động mua/nạp/bảo dưỡng thiết bị. |
| **Initial deployment** | Một tài khoản quản lý dữ liệu của mình; mobile-first; nhiều cơ sở/khu vực; tập trung thiết bị PCCC như bình chữa cháy; hỗ trợ trạng thái offline và đồng bộ khi có mạng. |

## 1.5 Success Criteria

- Người dùng có thể hoàn thành luồng từ đăng ký → onboarding → quét thiết bị → xác nhận → xem Asset Detail mà không cần nhập lại các trường OCR đã nhận diện đúng.
- Không có dữ liệu OCR/QR nào được lưu dưới trạng thái đã xác nhận nếu người dùng chưa thực hiện hành động xác nhận rõ ràng.
- Một lần kiểm tra hoàn tất phải tạo được bản ghi kết quả, checklist snapshot, ghi chú/bằng chứng (nếu có) và audit event tương ứng.
- Khi offline, thao tác ghi dữ liệu phải lưu bền vững vào local store; khi có mạng, hàng đợi đồng bộ có thể retry mà không tạo bản ghi trùng.
- Lịch sử, reminder và report phải truy vết được tới Asset/Facility và nguồn dữ liệu liên quan.
- Lỗi Camera/OCR/QR/network phải có fallback hợp lệ: thử lại, nhập thủ công, tiếp tục offline hoặc quay về màn hình an toàn.

# 2\. Project Context & Scope

## 2.1 Primary User Journey

1.  Người dùng đăng nhập hoặc đăng ký tài khoản; với tài khoản mới, onboarding thu thập loại hình cơ sở và tạo cơ sở đầu tiên.
2.  Người dùng mở Camera để quét QR/nhãn/tem thiết bị; hệ thống trả các trường nhận diện và mức độ tin cậy khi có.
3.  Người dùng sửa các trường cần thiết, chọn cơ sở/khu vực/vị trí chi tiết và xác nhận lưu thiết bị.
4.  Tại Asset Detail, người dùng xem thông tin thiết bị, mốc theo dõi, reminder và lịch sử hoạt động.
5.  Người dùng thực hiện kiểm tra định kỳ, đánh dấu checklist, trạng thái tổng thể, ghi chú và ảnh bằng chứng.
6.  Hệ thống lưu History Detail/Audit, cập nhật reminder/notification và cho phép xuất báo cáo theo cơ sở/khoảng thời gian.
7.  Khi mất mạng, các thao tác phù hợp được lưu local và đẩy lên backend khi kết nối trở lại.

## 2.2 In Scope

- Authentication: Login, Register, Forgot Password và trạng thái reset link đã gửi.
- Onboarding 3 bước: loại cơ sở, tạo cơ sở, quét thiết bị đầu tiên hoặc bỏ qua để vào Home.
- Quản lý Facility/Area: xem danh sách, thêm, chỉnh sửa và dùng facility selector xuyên suốt app.
- Asset: danh sách, tìm kiếm/lọc, thêm bằng OCR/QR, nhập tay fallback, chỉnh sửa, xem chi tiết và vị trí.
- Inspection: checklist định kỳ, kết quả tổng thể, ghi chú, ảnh toàn thiết bị/ảnh vấn đề, lưu tạm và hoàn tất.
- History/Audit: timeline sự kiện, bộ lọc, chi tiết kiểm tra và nguồn dữ liệu.
- Reminders/Notifications: quá hạn, 7 ngày/30 ngày, calendar view cơ bản, nguồn reminder, trạng thái đã đọc.
- Offline/Sync: hàng đợi thay đổi, retry, trạng thái sync error và tiếp tục thao tác hiện trường.
- Reporting: chọn cơ sở, khoảng thời gian, tập dữ liệu, PDF/CSV và trạng thái export success.
- Settings/Profile: notification toggles, lead time mặc định, scan mode, evidence retention toggle, facility management, export, logout, profile và xóa tài khoản.

## 2.3 Out of Scope

- Tự động chứng nhận tuân thủ pháp lý hoặc thay thế biên bản kiểm định chính thức.
- Computer vision tự đánh giá đầy đủ tình trạng vật lý của thiết bị chỉ từ ảnh.
- Tự động đặt lịch/đặt dịch vụ với đơn vị bảo dưỡng, thanh toán hoặc quản lý hóa đơn.
- Theo dõi vị trí GPS liên tục của thiết bị hoặc người dùng.
- Quản lý kho vật tư, tồn kho phụ tùng hoặc procurement end-to-end.
- Realtime collaboration phức tạp, phân quyền doanh nghiệp nhiều cấp và SSO trong bản baseline.

## 2.4 User & Ownership Model

Baseline coi User là gốc quyền sở hữu dữ liệu. Facility, Area, Asset, Inspection, Reminder và Export Job đều phải truy vết về người dùng hiện tại. Prototype chưa thể hiện vai trò nhiều người dùng trong cùng cơ sở; do đó RBAC nâng cao được xem là Future scope. Backend không được tin cậy user_id do client tự gửi để xác định quyền truy cập.

## 2.5 External Dependencies

| **Dependency** | **Vai trò** | **Failure behavior** |
| --- | --- | --- |
| OCR / Recognition provider | Nhận dạng text từ nhãn/tem và có thể hỗ trợ chữ viết tay; trả field + confidence. | Cho phép thử lại hoặc nhập tay; không tự tạo dữ liệu đã xác nhận. |
| QR parser / resolver | Đọc payload QR, phân tích serial/URL/mã nội bộ nếu có. | Nếu QR hợp lệ nhưng không có dữ liệu usable, chuyển trạng thái QR No Data và cho OCR/nhập tay. |
| Push notification gateway | Đẩy reminder/notification ra thiết bị. | Reminder vẫn tồn tại trong backend/app; retry hoặc hiển thị khi người dùng mở app. |
| Object storage | Lưu ảnh thiết bị, ảnh tem, ảnh kiểm tra và file report. | Không làm mất bản ghi core; có trạng thái upload pending/retry và chính sách orphan cleanup. |
| Email provider | Gửi link reset password. | Trả trạng thái gửi có kiểm soát; không tiết lộ email có tồn tại hay không. |

## 2.6 Data Source-of-Truth Policy

| **Dữ liệu** | **Source ưu tiên** | **Policy** |
| --- | --- | --- |
| Facility / Area / vị trí | Người dùng | Dữ liệu xác nhận do user nhập/chọn là authoritative trong phạm vi app. |
| Asset type / serial / model | User-confirmed OCR/QR hoặc nhập tay | Lưu provenance; OCR raw chỉ là candidate cho tới khi xác nhận. |
| Mốc bảo dưỡng / kiểm tra | User-confirmed milestone | Không biến ngày OCR thành “hạn pháp lý” nếu user chưa xác định loại mốc. |
| Inspection result | User action tại checklist | Là nguồn chuẩn cho lần kiểm tra đã ghi nhận. |
| Evidence image | Camera upload sau consent/xác nhận | Metadata retention phải tách khỏi dữ liệu core. |
| Reminder status | Scheduler + user action | Derived từ milestone, lead time và trạng thái complete/cancel. |
| Sync state | Server revision + local operation log | Local pending không được xem là synced cho tới khi có ACK hợp lệ. |

# 3\. Functional Requirements

## 3.1 Requirement Model & Priorities

M1–M10 là các nhóm chức năng của phạm vi chính. Bảng chi tiết giữ tinh thần của prototype và bổ sung tiêu chí Verification / Acceptance để phục vụ triển khai và QA.

| **Priority** | **Ý nghĩa** |
| --- | --- |
| **P0** | Bắt buộc để happy path, dữ liệu chính xác hoặc phục hồi lỗi cơ bản hoạt động. |
| **P1** | Cần cho bản sản phẩm/đồ án hoàn chỉnh nhưng có thể triển khai sau P0. |
| **Future** | Không chặn baseline release; chỉ triển khai sau khi luồng core ổn định. |

## 3.2 M1 — Authentication & Onboarding

| **ID** | **Requirement** | **Pri.** | **Verification / Acceptance** |
| --- | --- | --- | --- |
| **FR-M1.1** | Người dùng có thể đăng nhập bằng email và mật khẩu. | P0  | Sai thông tin xác thực không được tạo session. |
| **FR-M1.2** | Người dùng có thể đăng ký tài khoản và đồng ý điều khoản/quyền riêng tư. | P0  | Tạo account thành công mới chuyển onboarding. |
| **FR-M1.3** | Người dùng có thể yêu cầu reset password qua email. | P1  | UI dùng thông báo trung tính, không rò rỉ account existence. |
| **FR-M1.4** | Tài khoản mới đi qua onboarding: loại cơ sở → tạo cơ sở → quét thiết bị đầu tiên. | P0  | Progress 1/3, 2/3, 3/3 và state được lưu. |
| **FR-M1.5** | Onboarding cho phép bỏ qua bước quét đầu tiên để vào Home. | P0  | Skip không tạo asset giả. |
| **FR-M1.6** | Logout phải xóa credential/session local nhưng không xóa dữ liệu server. | P0  | Sau logout route protected yêu cầu đăng nhập lại. |

## 3.3 M2 — Facility & Area Management

| **ID** | **Requirement** | **Pri.** | **Verification / Acceptance** |
| --- | --- | --- | --- |
| **FR-M2.1** | Người dùng có thể tạo Facility với tên, loại hình, tỉnh/thành và địa chỉ. | P0  | Field bắt buộc được validate. |
| **FR-M2.2** | Người dùng có thể xem danh sách Facility và số khu vực/thiết bị/việc cần làm. | P1  | Số liệu tổng hợp nhất quán với backend. |
| **FR-M2.3** | Người dùng có thể chỉnh sửa thông tin Facility. | P0  | Update tạo audit event và không làm mất asset. |
| **FR-M2.4** | Người dùng có thể tạo Area bên trong một Facility. | P0  | Area phải thuộc đúng Facility owner. |
| **FR-M2.5** | Người dùng có thể chỉnh sửa Area và xem thiết bị thuộc Area. | P1  | Không xóa Area đang có asset nếu chưa xử lý quan hệ. |
| **FR-M2.6** | Facility selector được dùng ở Home, Assets, History, Reminders và Report. | P0  | Context đổi Facility không trộn dữ liệu giữa các cơ sở. |

## 3.4 M3 — Asset Registration & OCR/QR

| **ID** | **Requirement** | **Pri.** | **Verification / Acceptance** |
| --- | --- | --- | --- |
| **FR-M3.1** | Người dùng có thể mở Camera và quét QR/OCR ở chế độ tự động. | P0  | Khi chưa có permission, hiển thị Camera Permission state. |
| **FR-M3.2** | Hệ thống hiển thị các field nhận diện cùng confidence/status cần kiểm tra. | P0  | Field low-confidence có thể sửa trước khi lưu. |
| **FR-M3.3** | QR được ưu tiên parse; OCR có thể bổ sung các field text còn thiếu. | P1  | Nguồn từng field được lưu nếu có. |
| **FR-M3.4** | Người dùng phải xác nhận kết quả nhận diện trước khi tạo Asset. | P0  | Không lưu confirmed asset chỉ từ raw OCR. |
| **FR-M3.5** | Người dùng chọn Facility, Area và vị trí chi tiết cho Asset. | P0  | Asset không được gắn Area thuộc Facility khác. |
| **FR-M3.6** | Nếu OCR thất bại, người dùng có thể thử lại hoặc nhập tay. | P0  | OCR Failed state không làm mất ảnh/session hiện tại nếu policy cho phép retry. |
| **FR-M3.7** | Nếu QR đọc được nhưng không có dữ liệu usable, người dùng có thể chuyển OCR hoặc nhập tay. | P0  | QR No Data có đường phục hồi. |
| **FR-M3.8** | Người dùng có thể thêm Asset hoàn toàn thủ công. | P0  | Các field bắt buộc vẫn được validate như luồng scan. |
| **FR-M3.9** | Ảnh OCR/evidence chỉ được lưu theo chính sách consent/xác nhận. | P0  | Retention metadata được tạo cùng media record. |

## 3.5 M4 — Asset Detail & Lifecycle Data

| **ID** | **Requirement** | **Pri.** | **Verification / Acceptance** |
| --- | --- | --- | --- |
| **FR-M4.1** | Asset Detail hiển thị mã thiết bị, loại, serial, vị trí, mốc theo dõi và source. | P0  | UI khớp dữ liệu backend. |
| **FR-M4.2** | Người dùng có thể bật/tắt reminder cho mốc đã xác nhận. | P0  | Toggle cập nhật reminder state idempotently. |
| **FR-M4.3** | Người dùng có thể chỉnh sửa profile Asset và vị trí. | P0  | Thay đổi tạo audit event. |
| **FR-M4.4** | Người dùng có thể quét lại nhãn để cập nhật dữ liệu candidate. | P1  | Kết quả re-scan không ghi đè confirmed field nếu chưa review. |
| **FR-M4.5** | Asset Detail hiển thị lịch sử hoạt động gần nhất và bằng chứng. | P1  | History entries truy ngược tới event gốc. |
| **FR-M4.6** | Asset có thể ngừng theo dõi/archived thay vì xóa cứng mặc định. | P1  | Archived asset không xuất hiện trong active reminder mới. |

## 3.6 M5 — Periodic Inspection

| **ID** | **Requirement** | **Pri.** | **Verification / Acceptance** |
| --- | --- | --- | --- |
| **FR-M5.1** | Người dùng có thể bắt đầu kiểm tra định kỳ từ Asset Detail. | P0  | Inspection draft được gắn Asset + thời điểm. |
| **FR-M5.2** | Checklist gồm các hạng mục có trạng thái bình thường/vấn đề/không áp dụng theo template. | P0  | Snapshot checklist được lưu cùng Inspection. |
| **FR-M5.3** | Người dùng chọn kết quả tổng thể: Bình thường / Cần theo dõi / Cần xử lý. | P0  | Result bắt buộc trước Complete. |
| **FR-M5.4** | Người dùng có thể thêm ghi chú và ảnh bằng chứng. | P1  | Ảnh upload gắn đúng Inspection. |
| **FR-M5.5** | Người dùng có thể lưu tạm và tiếp tục Inspection. | P1  | Draft không tạo completed history event. |
| **FR-M5.6** | Hoàn tất Inspection phải tạo History Detail và Audit event. | P0  | Transaction hoàn tất nguyên tử hoặc rollback. |
| **FR-M5.7** | Nếu có vấn đề, hệ thống có thể tạo/cập nhật reminder theo policy. | P1  | Không tự tạo “kết luận pháp lý”; reminder chỉ là nhắc việc vận hành. |

## 3.7 M6 — History & Audit Trail

| **ID** | **Requirement** | **Pri.** | **Verification / Acceptance** |
| --- | --- | --- | --- |
| **FR-M6.1** | History hiển thị sự kiện theo thời gian và Facility hiện tại. | P0  | Sort timestamp nhất quán. |
| **FR-M6.2** | Người dùng có thể tìm kiếm/lọc theo loại sự kiện. | P1  | Filter không thay đổi dữ liệu gốc. |
| **FR-M6.3** | History Detail hiển thị checklist, ghi chú, ảnh và người ghi nhận. | P0  | Detail tham chiếu Inspection/Event tồn tại. |
| **FR-M6.4** | Các thay đổi quan trọng tạo AuditEvent append-only. | P0  | Không update nội dung event đã commit, chỉ bổ sung event mới. |
| **FR-M6.5** | Nguồn dữ liệu (OCR/QR/manual/inspection) được giữ để truy vết. | P0  | Source enum được trả trong API relevant. |

## 3.8 M7 — Reminders & Notifications

| **ID** | **Requirement** | **Pri.** | **Verification / Acceptance** |
| --- | --- | --- | --- |
| **FR-M7.1** | Reminders phân nhóm quá hạn, 7 ngày tới, 30 ngày tới và sau đó. | P0  | Nhóm được tính từ due_at và clock server. |
| **FR-M7.2** | Reminder có thể bắt nguồn từ mốc OCR đã xác nhận hoặc cấu hình người dùng. | P0  | Source được hiển thị/ghi nhận. |
| **FR-M7.3** | Người dùng có thể xem Asset liên quan trực tiếp từ Reminder. | P0  | Deep link mở đúng Asset. |
| **FR-M7.4** | Notifications hỗ trợ unread/read và mark-all-read. | P1  | Read state đồng bộ theo account. |
| **FR-M7.5** | Settings cho phép bật/tắt nhóm reminder và lead time mặc định. | P1  | Thay đổi chỉ áp dụng theo policy đã chọn. |
| **FR-M7.6** | Không gửi notification trùng cho cùng reminder window nếu job retry. | P0  | Notification delivery có idempotency key. |

## 3.9 M8 — Offline Sync & Recovery

| **ID** | **Requirement** | **Pri.** | **Verification / Acceptance** |
| --- | --- | --- | --- |
| **FR-M8.1** | Quét/nhập Asset và ghi Inspection có thể lưu local khi offline. | P0  | Local transaction bền vững qua app restart. |
| **FR-M8.2** | App hiển thị số thay đổi đang chờ đồng bộ. | P1  | Count khớp pending operation log. |
| **FR-M8.3** | Khi có mạng, app tự/cho phép retry sync các operation pending. | P0  | Retry không tạo duplicate. |
| **FR-M8.4** | Sync Error không được xóa local data chưa được ACK. | P0  | Pending payload tồn tại sau failure. |
| **FR-M8.5** | Server phát hiện version conflict cho update cùng resource. | P1  | Conflict trả metadata để client quyết định refresh/reapply. |
| **FR-M8.6** | File/evidence upload có thể pending tách khỏi core record nếu cần. | P1  | Core record giữ media state PENDING/FAILED/READY. |

## 3.10 M9 — Reporting & Export

| **ID** | **Requirement** | **Pri.** | **Verification / Acceptance** |
| --- | --- | --- | --- |
| **FR-M9.1** | Người dùng chọn Facility và khoảng thời gian xuất báo cáo. | P0  | Date range hợp lệ. |
| **FR-M9.2** | Người dùng chọn dữ liệu gồm device list, inspection history, maintenance/service events và evidence images. | P1  | Summary dự kiến phản ánh filter. |
| **FR-M9.3** | Hỗ trợ định dạng PDF và CSV. | P0  | File tải về mở được và dữ liệu đúng filter. |
| **FR-M9.4** | Export Success hiển thị phạm vi và nội dung đã xuất. | P1  | Không báo thành công khi artifact chưa sẵn sàng. |
| **FR-M9.5** | Report job lớn có thể chạy bất đồng bộ. | P1  | Job status truy vấn được; retry an toàn. |

## 3.11 M10 — Settings & Profile

| **ID** | **Requirement** | **Pri.** | **Verification / Acceptance** |
| --- | --- | --- | --- |
| **FR-M10.1** | Người dùng có thể xem/chỉnh sửa profile cá nhân. | P1  | Update validate email/name. |
| **FR-M10.2** | Người dùng cấu hình default scan mode và lưu evidence. | P1  | Setting được áp dụng cho session mới. |
| **FR-M10.3** | Người dùng truy cập Facility management và Export từ Settings. | P0  | Navigation đúng context. |
| **FR-M10.4** | Người dùng có thể đổi mật khẩu. | P1  | Yêu cầu xác thực phù hợp. |
| **FR-M10.5** | Người dùng có thể yêu cầu xóa tài khoản. | P1  | Có confirm và quy trình dữ liệu/retention rõ ràng. |

## 3.12 Future Features F1–F7

| **ID** | **Feature** | **Scope summary** | **Priority** |
| --- | --- | --- | --- |
| F1  | Multi-user & RBAC | Chủ cơ sở, kỹ thuật viên, reviewer; lời mời thành viên và quyền theo Facility/Area. | Future |
| F2  | Bulk import / migration | Nhập CSV/Excel danh sách thiết bị cũ và đối chiếu trùng serial. | Future |
| F3  | Vendor / maintenance integration | Gửi yêu cầu dịch vụ, lưu nhà cung cấp và liên kết biên bản. | Future |
| F4  | NFC / barcode support | Thêm phương thức nhận diện vật lý ngoài QR/OCR. | Future |
| F5  | Advanced analytics | Dashboard xu hướng overdue, inspection result, coverage theo Area. | Future |
| F6  | AI-assisted anomaly review | Gợi ý vùng ảnh bất thường để người dùng xem lại; không tự kết luận an toàn. | Future |
| F7  | Enterprise compliance package | Template checklist theo doanh nghiệp/quy chuẩn nội bộ, audit export nâng cao. | Future |

# 4\. System Architecture

## 4.1 Architecture Principles

- Backend là nguồn chuẩn cho ownership, revision và dữ liệu đã đồng bộ; mobile local store là nguồn làm việc khi offline.
- Mọi integration bên ngoài (OCR, push, object storage, email) nằm sau adapter để có thể mock/test và thay provider.
- Asset/Inspection writes được đóng gói trong use-case transaction; media upload có thể tách trạng thái nhưng không được làm mất liên kết.
- OCR/QR không trực tiếp write confirmed domain data; phải đi qua Review/Confirmation boundary.
- AuditEvent được thiết kế append-only cho các thay đổi quan trọng.
- Sync operation phải idempotent và có client_operation_id để retry an toàn.

## 4.2 System Context

Hình 1. Ngữ cảnh hệ thống và các phụ thuộc bên ngoài của FireSafe

## 4.3 Logical Components

Hình 2. Kiến trúc thành phần đề xuất (reference architecture độc lập công nghệ)

| **Component** | **Responsibility** | **Key outputs** |
| --- | --- | --- |
| Mobile Client | UI mobile, camera, local persistence, offline queue, navigation và cache. | User actions, local drafts, sync operations. |
| Auth / Account | Login/register/reset/profile/session. | Authenticated principal, account state. |
| Facility & Asset Service | CRUD Facility/Area/Asset, ownership, revision, search/filter. | Resource IDs, authoritative asset data. |
| Scan Orchestrator | Quản lý scan session, merge QR/OCR, confidence, review contract. | Candidate fields + provenance. |
| Inspection Service | Checklist snapshot, result, notes, evidence refs, audit. | Inspection record + history event. |
| Reminder Scheduler | Tính due window, overdue, lead time và delivery dedupe. | Reminder/notification candidates. |
| Notification Service | In-app notification + push delivery state. | Delivery logs, read state. |
| Reporting Service | Query theo filter, generate PDF/CSV, artifact lifecycle. | ExportJob + file URI. |
| Sync Service | Delta upload/download, version check, idempotency. | ACK, conflict metadata, server revision. |
| Persistence | Relational data, audit, object metadata. | Durable state, traceability. |

## 4.4 Device Registration Flow

Hình 3. Trình tự đăng ký thiết bị bằng QR/OCR và xác nhận của người dùng

## 4.5 Periodic Inspection Flow

Hình 4. Trình tự ghi nhận kiểm tra định kỳ và bằng chứng

## 4.6 Offline Sync Flow

Hình 5. Luồng offline-first, hàng đợi thay đổi và đồng bộ idempotent

## 4.7 Degraded Modes & Failure Boundaries

| **Failure** | **Required behavior** | **Not allowed** |
| --- | --- | --- |
| Camera permission denied | Hiển thị lý do, nút xin quyền và lựa chọn quay về Home/nhập tay. | Không crash hoặc vòng lặp permission vô hạn. |
| OCR failed | Giữ flow phục hồi: thử lại, đổi góc, nhập thủ công. | Không tự điền field với dữ liệu đoán. |
| QR has no usable data | Thông báo QR đã đọc nhưng không map được; cho OCR/manual. | Không coi QR tồn tại là Asset hợp lệ. |
| Offline | Cho phép các write hỗ trợ offline; hiển thị pending count. | Không báo “đã đồng bộ” khi chưa có ACK. |
| Sync error | Giữ local queue, retry và conflict metadata. | Không xóa operation pending. |
| Object storage unavailable | Core record có thể ở media_pending nếu policy cho phép. | Không mất inspection/asset record đã commit. |
| Push unavailable | Reminder vẫn hiển thị trong app và retry delivery. | Không mất reminder source. |
| Report generation failed | Giữ ExportJob failed/retryable và thông báo rõ. | Không hiển thị Export Success khi artifact không tồn tại. |

# 5\. Domain & Data Design

## 5.1 Core Domain Model

Hình 6. Mô hình miền logic đề xuất cho Facility, Asset, Scan, Inspection, Reminder và Audit

## 5.2 Asset & Inspection State

Asset lifecycle nên tách trạng thái vòng đời khỏi trạng thái vận hành suy ra. Vòng đời baseline: ACTIVE → ARCHIVED. Trạng thái vận hành (NORMAL, DUE_SOON, OVERDUE, NEEDS_FOLLOW_UP) được tính từ reminder/milestone/inspection mới nhất thay vì ghi đè lẫn nhau trong một field duy nhất.

| **State model** | **State** | **Ý nghĩa / transition** |
| --- | --- | --- |
| Asset lifecycle | ACTIVE | Đang được theo dõi và tham gia reminder/inspection. |
| Asset lifecycle | ARCHIVED | Ngừng theo dõi; giữ history, không tạo reminder mới mặc định. |
| Inspection | DRAFT | Checklist đang làm hoặc lưu tạm. |
| Inspection | COMPLETED | Đã ghi nhận kết quả; snapshot bất biến theo record. |
| Inspection result | NORMAL | Không ghi nhận vấn đề đáng chú ý theo checklist hiện tại. |
| Inspection result | FOLLOW_UP | Có điểm cần theo dõi ở lần tiếp theo. |
| Inspection result | ACTION_REQUIRED | Có vấn đề cần xử lý theo quy trình vận hành của người dùng. |

## 5.3 Data Provenance

| **Enum đề xuất** | **Meaning** |
| --- | --- |
| **MANUAL** | Người dùng nhập hoặc chỉnh sửa trực tiếp. |
| **QR** | Field đến từ payload QR đã parse. |
| **OCR** | Field đến từ engine nhận dạng; chưa authoritative cho tới khi confirmed. |
| **OCR_CONFIRMED** | Field OCR đã được người dùng xác nhận. |
| **SYSTEM_DERIVED** | Giá trị suy ra như overdue/due soon từ các mốc đã xác nhận. |
| **INSPECTION** | Giá trị phát sinh từ lần kiểm tra đã hoàn tất. |

## 5.4 Proposed Relational Model

| **Table** | **Key fields** | **Notes** |
| --- | --- | --- |
| users | id, email, password_hash, display_name, created_at | Gốc account/ownership. |
| facilities | id, user_id, name, type, province, address, internal_code | Một địa điểm vận hành. |
| areas | id, facility_id, name, type, code, description | Phân vùng bên trong Facility. |
| assets | id, user_id, facility_id, area_id, asset_code, type, subtype, capacity, manufacturer, model, serial, location_text, lifecycle_state, revision | Hồ sơ thiết bị chính. |
| scan_sessions | id, user_id, mode, captured_at, status, image_media_id, qr_payload | Một lần scan. |
| scan_fields | id, scan_session_id, field_name, raw_value, normalized_value, confidence, source, confirmed_value | Giữ raw/candidate/confirmed tách biệt. |
| service_milestones | id, asset_id, milestone_type, milestone_date, source, confirmed_by, created_at | Mốc bảo dưỡng/kiểm tra đã xác nhận. |
| reminders | id, asset_id, milestone_id, due_at, lead_time_days, state, source | Nguồn cho reminders view. |
| inspections | id, asset_id, user_id, status, result, note, started_at, completed_at, checklist_version | Một lần kiểm tra. |
| inspection_items | id, inspection_id, item_key, label_snapshot, result, note | Snapshot từng hạng mục. |
| media_objects | id, owner_id, kind, storage_key, mime_type, checksum, state, retention_until | Ảnh/evidence/export artifact metadata. |
| inspection_evidence | inspection_id, media_id, evidence_type | Join ảnh với Inspection. |
| audit_events | id, user_id, facility_id, asset_id, event_type, actor_id, timestamp, payload_json | Append-only history. |
| notifications | id, user_id, reminder_id, type, title, body, read_at, created_at | In-app notification. |
| notification_deliveries | id, notification_id, channel, status, provider_message_id, idempotency_key | Theo dõi push/email delivery. |
| export_jobs | id, user_id, facility_id, filter_json, format, status, artifact_media_id, created_at | PDF/CSV lifecycle. |
| sync_operations | id, user_id, device_id, client_operation_id, resource_type, resource_id, base_revision, payload_json, server_status | Idempotent offline operation log. |

# 6\. OCR / Recognition Design

## 6.1 Recognition Pipeline

1\. Camera capture / image selection tạo ScanSession và metadata thiết bị.

2\. QR detector chạy trước hoặc song song; payload được parse thành candidate fields nếu schema/format nhận diện được.

3\. OCR engine chạy trên vùng nhãn/tem; kết quả được normalize (ngày, serial, model, loại thiết bị).

4\. Scan Orchestrator merge các nguồn, giữ confidence và provenance của từng field.

5\. Mobile Review UI hiển thị field, đánh dấu low-confidence và cho phép sửa.

6\. Chỉ sau hành động “Xác nhận/Lưu” thì candidate field được materialize thành Asset/ServiceMilestone authoritative.

## 6.2 QR Resolution

QR payload có thể là mã nội bộ, serial, JSON ngắn hoặc URL. Baseline không giả định mọi QR đều có backend public. Resolver phải phân loại payload và chỉ map các field hiểu được. Nếu QR đọc thành công nhưng không có dữ liệu usable, app hiển thị trạng thái “QR No Data” và cho phép chuyển OCR hoặc nhập tay.

## 6.3 OCR Field Extraction

| **Field** | **Normalization** | **Validation / note** |
| --- | --- | --- |
| asset_type / subtype | Map text về enum nội bộ. | Không auto-guess nếu confidence thấp hoặc text mơ hồ. |
| serial_number | Trim, normalize separators, uppercase nếu policy. | Cho phép alphanumeric; phát hiện duplicate sau confirmation. |
| manufacturer / model | Text cleanup; optional dictionary. | Không bắt buộc nếu không đọc được. |
| capacity | Tách số + unit (kg, L...). | Unit phải nằm trong enum cho loại thiết bị tương ứng. |
| service_date | Parse dd/mm/yyyy, mm/yyyy hoặc handwritten candidate. | Bắt buộc người dùng xác nhận loại mốc trước khi tạo milestone. |
| qr_payload | Giữ raw payload + parsed representation. | Không coi URL bên ngoài là trusted data nếu chưa verify. |

## 6.4 Confidence & Human Confirmation

Confidence threshold là cấu hình của adapter/UI, không phải quyết định domain. Field dưới ngưỡng hoặc mâu thuẫn giữa QR và OCR phải được đánh dấu “cần kiểm tra”. Backend lưu cả candidate và confirmed value để phục vụ audit/benchmark nhưng chỉ confirmed value được dùng cho hồ sơ vận hành.

|     |     |
| --- | --- |
| **H** | **Human-in-the-loop invariant: Raw OCR/QR → candidate → user review → confirmed domain value. Không có đường tắt từ engine recognition tới hồ sơ Asset chính thức.** |

## 6.5 Failure Fallback & Guardrails

- Không đọc được nhãn: hướng dẫn khoảng cách/ánh sáng/góc chụp, cho retry và manual entry.
- Camera permission denied: giải thích mục đích, xin quyền khi người dùng bấm và vẫn có đường nhập tay.
- QR payload lạ: giữ raw cho debug nhưng không đưa vào field authoritative.
- OCR timeout/provider unavailable: cho phép manual; nếu ảnh đã chụp, chỉ upload/lưu theo consent policy.
- Duplicate serial: cảnh báo và gợi ý mở Asset hiện có thay vì tạo trùng; quyết định cuối cùng phụ thuộc policy.

## 6.6 Evidence Storage

Media object nên tách khỏi Asset/Inspection row. Mỗi file có checksum, MIME type, size, upload state, owner và retention metadata. Ảnh phục vụ OCR có thể có policy khác ảnh evidence kiểm tra. Prototype nêu rõ ảnh chỉ được lưu khi người dùng xác nhận; hệ thống phải phản ánh nguyên tắc đó trong cả UI lẫn API.

# 7\. Inspection & Reminder Design

## 7.1 Checklist Model

Checklist được version hóa bằng template key/version. Khi bắt đầu Inspection, server hoặc client nhận snapshot của label và rule để kết quả lịch sử không thay đổi khi template tương lai được chỉnh sửa. Các hạng mục prototype gồm vị trí dễ tiếp cận, niêm phong/chốt, đồng hồ áp suất, thân bình, vòi/bộ phận phun; bộ dữ liệu thực tế nên cấu hình theo loại thiết bị.

| **Item state** | **Ý nghĩa** |
| --- | --- |
| **OK** | Hạng mục quan sát bình thường theo checklist. |
| **ISSUE** | Có vấn đề/khác thường cần ghi chú hoặc evidence. |
| **N/A** | Không áp dụng cho loại thiết bị cụ thể. |
| **UNSET** | Chưa đánh giá; không cho Complete nếu item bắt buộc. |

## 7.2 Inspection Event Model

Hoàn tất Inspection là một use case nguyên tử: validate checklist/result → bảo đảm media reference hợp lệ hoặc ở trạng thái được phép → commit Inspection + items → tạo AuditEvent → cập nhật derived status/reminder nếu policy yêu cầu. History Detail đọc từ snapshot Inspection chứ không dựng lại từ template hiện tại.

## 7.3 Reminder Scheduling

| **Input** | **Rule đề xuất** |
| --- | --- |
| Milestone date | Mốc đã được người dùng xác nhận hoặc được cấu hình trực tiếp. |
| Lead time | Default từ Settings, có thể override theo reminder/asset. |
| Due grouping | OVERDUE nếu due_at < now và chưa complete/cancel; UPCOMING_7D / UPCOMING_30D theo window. |
| Deduplication | Một reminder window chỉ tạo một notification logical; delivery retry dùng cùng idempotency key. |
| Completion | Inspection/service event phù hợp có thể đóng hoặc reschedule reminder theo rule cấu hình. |

## 7.4 Notification Rules

- Notification chỉ là kênh nhắc; Reminder là domain record gốc.
- Push delivery failure không thay đổi due state.
- Mark as read chỉ thay read_at; không được coi là hoàn thành reminder.
- Deep link phải chứa resource identifier và kiểm tra ownership lại tại backend/client.
- Notification text phải dùng dữ liệu đã xác nhận; không diễn đạt “đã vi phạm pháp luật” chỉ từ mốc app.

## 7.5 Safety & Legal Boundary

|     |     |
| --- | --- |
| **!** | **Safety boundary: FireSafe ghi nhận và nhắc theo dữ liệu do người dùng/hệ thống đã cấu hình. Ứng dụng không tự coi ngày đọc từ tem là hạn pháp lý, không thay thế đánh giá chuyên môn và không tự kết luận thiết bị “an toàn/đạt chuẩn” từ OCR hoặc checklist.** |

# 8\. API Design

## 8.1 API Conventions

- REST/JSON qua HTTPS; prefix phiên bản \`/api/v1\` (Proposed).
- Principal người dùng được suy ra từ session/token; không tin user_id trong request body cho ownership.
- Timestamp ISO-8601; server là nguồn chuẩn cho created_at/updated_at và due calculations.
- Resource mutable có \`revision\`/ETag để optimistic concurrency.
- Write từ offline client có \`client_operation_id\`/Idempotency-Key.
- Media upload dùng signed upload hoặc multipart endpoint; core resource giữ media state.

## 8.2 Endpoint Catalog

| **Method** | **Endpoint** | **Purpose** |
| --- | --- | --- |
| POST | /auth/register | Tạo tài khoản. |
| POST | /auth/login | Tạo session/token. |
| POST | /auth/forgot-password | Yêu cầu email reset. |
| GET/POST | /facilities | List / create Facility. |
| GET/PATCH | /facilities/{id} | Detail / edit Facility. |
| POST | /facilities/{id}/areas | Create Area. |
| PATCH | /areas/{id} | Edit Area. |
| GET/POST | /assets | List/search / manual create Asset. |
| GET/PATCH | /assets/{id} | Asset detail / edit. |
| POST | /scans | Create scan session / submit recognition input. |
| POST | /scans/{id}/confirm | Confirm candidate fields and create/update Asset. |
| POST | /assets/{id}/inspections | Create Inspection draft. |
| PATCH | /inspections/{id} | Update checklist/note. |
| POST | /inspections/{id}/complete | Finalize inspection atomically. |
| GET | /history | Query audit/history events. |
| GET | /history/{id} | History detail. |
| GET/PATCH | /reminders | List/update reminder state/settings. |
| GET/PATCH | /notifications | List/mark read. |
| POST | /exports | Create PDF/CSV export job. |
| GET | /exports/{id} | Get job status/artifact. |
| POST | /sync/batch | Push offline operations and receive ACK/conflicts. |
| GET/PATCH | /me/settings | Account/app settings. |
| GET/PATCH | /me/profile | Profile. |

## 8.3 Core Request / Response Contracts

| **Contract** | **Required fields (summary)** |
| --- | --- |
| ScanCandidate | scan_id, mode, qr_payload?, fields\[{name, raw_value, normalized_value, confidence, source}\], image_ref? |
| AssetConfirmRequest | scan_id?, asset fields, facility_id, area_id?, location_text?, milestones\[\], save_evidence? |
| AssetResponse | id, revision, type/subtype, serial, facility/area, location, lifecycle_state, operational_status, provenance, milestones, reminder_summary |
| InspectionDraft | id, asset_id, checklist_version, items\[\], result?, note?, evidence\[\] |
| InspectionCompleteResponse | inspection_id, history_event_id, asset_operational_status, reminder_changes\[\] |
| SyncBatch | device_id, operations\[{client_operation_id, resource_type, action, base_revision, payload}\] |
| SyncAck | accepted\[\], conflicts\[\], rejected\[\], server_cursor |
| ExportRequest | facility_id, from, to, include{assets, inspections, service_events, evidence}, format |

## 8.4 Error Model

| **HTTP** | **Code examples** | **Meaning** |
| --- | --- | --- |
| 400 | INVALID_INPUT, DATE_INVALID | Dữ liệu client không hợp lệ. |
| 401/403 | UNAUTHENTICATED, FORBIDDEN | Lỗi xác thực/quyền sở hữu. |
| 404 | ASSET_NOT_FOUND, FACILITY_NOT_FOUND | Tài nguyên không tồn tại hoặc không được phép xem. |
| 409 | VERSION_CONFLICT, DUPLICATE_SERIAL | Xung đột revision hoặc khả năng trùng asset. |
| 422 | OCR_CONFIRMATION_REQUIRED, CHECKLIST_INCOMPLETE | Cú pháp hợp lệ nhưng thiếu điều kiện domain. |
| 429 | RATE_LIMITED | Bị giới hạn tần suất/quota. |
| 502/503 | OCR_UNAVAILABLE, STORAGE_UNAVAILABLE, PUSH_UNAVAILABLE | Phụ thuộc ngoài không khả dụng. |

## 8.5 Concurrency, Sync & Idempotency

Đề xuất optimistic concurrency cho Asset/Facility/Area bằng revision number hoặc ETag. Client offline gửi base_revision kèm operation. Nếu server revision đã thay đổi, server trả VERSION_CONFLICT thay vì ghi đè mù. Mọi operation retryable phải có client_operation_id duy nhất theo thiết bị để backend trả lại kết quả cũ nếu request được gửi lại sau timeout. Hoàn tất Inspection và confirm Asset từ ScanSession phải được bảo vệ chống double-submit.

# 9\. External Integration Design

## 9.1 OCR / Recognition Provider

Provider cụ thể chưa được prototype khóa cứng. Thiết kế adapter nên hỗ trợ on-device OCR, cloud OCR hoặc hybrid. Contract chuẩn hóa phải trả text block/field, confidence, optional bounding box và provider metadata; mọi provider-specific payload được giữ ngoài domain core. Benchmark cần dùng ảnh thật của tem/nhãn PCCC, đặc biệt chữ viết tay/tháng-năm, thay vì chỉ dataset generic.

## 9.2 Push Notification Gateway

Push gateway (ví dụ FCM hoặc dịch vụ tương đương) nhận NotificationDelivery do scheduler tạo. Backend giữ delivery state và provider_message_id để debug. Token thiết bị phải có lifecycle register/refresh/revoke; logout hoặc uninstall không được làm mất Reminder domain record.

## 9.3 Object Storage

Ảnh và report artifact nên lưu ở object storage với key không chứa PII trực tiếp, checksum, MIME type và owner metadata. Download sử dụng URL ngắn hạn/signed URL hoặc proxy endpoint có auth. Cần lifecycle policy cho ảnh OCR không còn cần thiết, export tạm và orphan uploads.

## 9.4 Report Generation

PDF/CSV có thể sinh trong worker nội bộ. PDF ưu tiên bố cục dễ in/chia sẻ; CSV ưu tiên dữ liệu thô. ExportJob lưu filter snapshot để tái hiện report. Nếu có evidence image, report generator phải giới hạn kích thước/độ phân giải để tránh file quá lớn và timeout.

## 9.5 Cost & Quota Control

| **Area** | **Control** |
| --- | --- |
| OCR | Resize/crop ảnh trước upload; không gọi provider lại khi scan session đã có kết quả hợp lệ; cache raw result theo scan ID. |
| Object storage | Lifecycle rules, thumbnail thay vì full-res ở list/detail, checksum dedupe khi phù hợp. |
| Push | Dedupe theo reminder window; batch scheduler; không retry vô hạn. |
| Reports | Giới hạn date range/evidence size; async job cho report lớn; xóa artifact tạm theo retention. |

# 10\. Non-Functional Requirements

## 10.1 Performance

| **ID** | **Requirement** | **Pri.** | **Verification** |
| --- | --- | --- | --- |
| **NFR-P1** | Các thao tác local như mở danh sách cache, ghi draft/offline queue phải phản hồi gần tức thời theo cảm nhận người dùng. | P0  | Đo p95 trên thiết bị mục tiêu; không block UI thread bởi network. |
| **NFR-P2** | Scan/OCR online phải có timeout và progress state; mục tiêu latency được benchmark theo provider/ảnh thật. | P1  | Không treo vô hạn; timeout dẫn tới retry/manual. |
| **NFR-P3** | Asset list/history/reminders dùng pagination hoặc incremental loading khi dữ liệu tăng. | P1  | Không tải toàn bộ lịch sử lớn vào một response. |

## 10.2 Correctness & Data Integrity

| **ID** | **Requirement** | **Pri.** | **Verification** |
| --- | --- | --- | --- |
| **NFR-C1** | Không lưu OCR candidate thành confirmed field nếu chưa có hành động xác nhận. | P0  | Invariant test ở API/domain. |
| **NFR-C2** | Hoàn tất Inspection tạo record, items và audit nhất quán. | P0  | Transaction rollback khi bất kỳ write bắt buộc thất bại. |
| **NFR-C3** | Sync retry không tạo duplicate asset/inspection/event. | P0  | Idempotency regression. |

## 10.3 Reliability & Offline Capability

| **ID** | **Requirement** | **Pri.** | **Verification** |
| --- | --- | --- | --- |
| **NFR-R1** | Local draft/pending operation sống qua app restart và mất mạng. | P0  | Kill/restart test. |
| **NFR-R2** | Sync có retry với backoff và không xóa payload trước ACK. | P0  | Network fault injection. |
| **NFR-R3** | Media upload failure không làm mất core record đã được phép commit. | P1  | Media state pending/failed recoverable. |

## 10.4 Security

| **ID** | **Requirement** | **Pri.** | **Verification** |
| --- | --- | --- | --- |
| **NFR-S1** | Tất cả API production dùng TLS; secret/token không ghi log plaintext. | P0  | Security configuration review. |
| **NFR-S2** | Password hash dùng thuật toán thích hợp với salt; reset token ngắn hạn và dùng một lần. | P0  | Auth test + review. |
| **NFR-S3** | Mọi resource check ownership ở server. | P0  | Cross-user access test. |

## 10.5 Privacy

| **ID** | **Requirement** | **Pri.** | **Verification** |
| --- | --- | --- | --- |
| **NFR-PR1** | Camera permission được xin đúng lúc và giải thích mục đích. | P0  | Permission UX test. |
| **NFR-PR2** | Ảnh OCR/evidence chỉ lưu theo consent/xác nhận và có cơ chế xóa. | P0  | Media retention test. |
| **NFR-PR3** | Xóa account có quy trình dữ liệu rõ ràng và audit theo policy. | P1  | Deletion workflow test. |

## 10.6 Usability & Accessibility

| **ID** | **Requirement** | **Pri.** | **Verification** |
| --- | --- | --- | --- |
| **NFR-U1** | Happy path từ Home tới Scan/Inspection phải đạt bằng CTA rõ ràng và có back navigation nhất quán. | P0  | Prototype usability test. |
| **NFR-U2** | Trạng thái lỗi luôn nêu hành động phục hồi, không chỉ hiển thị mã kỹ thuật. | P0  | Review edge-state copy. |
| **NFR-U3** | Touch target, contrast và font size đáp ứng guideline mobile cơ bản. | P1  | Accessibility audit. |

## 10.7 Maintainability

| **ID** | **Requirement** | **Pri.** | **Verification** |
| --- | --- | --- | --- |
| **NFR-M1** | External providers được cô lập bằng adapter/interface. | P0  | Unit test thay provider bằng fake. |
| **NFR-M2** | API contract có OpenAPI/schema và versioning. | P1  | CI validate schema. |
| **NFR-M3** | Checklist/reminder rules cấu hình được, tránh hard-code copy UI trong domain logic. | P1  | Config test. |

## 10.8 Scalability

| **ID** | **Requirement** | **Pri.** | **Verification** |
| --- | --- | --- | --- |
| **NFR-SC1** | List/history/reminder query có index theo user/facility/asset/time. | P1  | Query plan review với dataset lớn. |
| **NFR-SC2** | Report và notification jobs có thể tách background worker. | P1  | Load test queue/job. |
| **NFR-SC3** | Object storage không đi qua relational DB blob. | P1  | Architecture review. |

## 10.9 Observability

| **ID** | **Requirement** | **Pri.** | **Verification** |
| --- | --- | --- | --- |
| **NFR-O1** | Log có correlation/request ID nhưng không log raw password/token. | P0  | Log audit. |
| **NFR-O2** | Có metrics scan success/failure, OCR latency, sync pending/failure, notification delivery, export job. | P1  | Dashboard/metric smoke test. |
| **NFR-O3** | AuditEvent tách khỏi application log. | P0  | History vẫn tồn tại khi log retention hết. |

## 10.10 Testability

| **ID** | **Requirement** | **Pri.** | **Verification** |
| --- | --- | --- | --- |
| **NFR-T1** | Domain services chạy được với in-memory/fake adapters. | P0  | Unit test không gọi internet. |
| **NFR-T2** | OCR adapter có fixture ảnh/payload và deterministic contract tests. | P1  | Regression dataset. |
| **NFR-T3** | Offline sync có test conflict/idempotency/fault injection. | P0  | Automated integration suite. |

# 11\. Security & Privacy Design

| **Control area** | **Design decision** |
| --- | --- |
| Authentication | Session/token có expiry; refresh/revoke; reset token một lần; lock/rate limit theo policy. |
| Authorization | Server-side ownership check trên Facility/Area/Asset/Inspection/Export/Media. Future RBAC mở rộng trên cùng boundary. |
| Data in transit | TLS; signed upload/download URL ngắn hạn nếu dùng object storage. |
| Data at rest | DB/storage encryption theo platform; secret quản lý ngoài source code. |
| Image privacy | Chỉ lưu khi user xác nhận; phân loại image kind; retention/delete API. |
| Audit | Security-sensitive actions (login failures threshold, profile/delete, asset archive, inspection complete) có audit phù hợp. |
| Input safety | Validate file type/size, sanitize filename, reject unexpected JSON fields theo schema strict. |
| Logging | Không log password, reset token, full auth token; cân nhắc redaction với OCR raw text nếu có PII. |

# 12\. Observability & Operations

| **Signal** | **Examples** | **Why it matters** |
| --- | --- | --- |
| Metrics | scan_started, scan_success, ocr_failed, manual_fallback, sync_pending, sync_conflict, inspection_completed, notification_sent/failed, export_duration | Phát hiện bottleneck và regression UX. |
| Logs | request_id, user_id hash/internal id, resource_id, operation, provider status, retry count | Debug sự cố mà không phụ thuộc log raw PII. |
| Audit events | asset_created/edited/archived, inspection_completed, reminder_updated, facility_changed | Truy vết nghiệp vụ dài hạn. |
| Alerts | OCR failure spike, sync failure rate, job queue backlog, storage upload errors | Phát hiện lỗi hệ thống trước khi người dùng báo. |

Môi trường nên tách dev/staging/production; provider key và storage bucket không dùng chung. Migration DB có version, rollback/backup plan và seed dữ liệu demo phục vụ QA.

# 13\. Test Strategy

| **Level** | **Focus** | **Examples** |
| --- | --- | --- |
| Unit | Domain rules, normalization, state transitions, scheduler math. | OCR field normalization, reminder grouping, ownership predicate, checklist validation. |
| Contract | Adapter/API schemas. | OCR provider fake, push gateway fake, signed upload contract. |
| Integration | DB transactions, media metadata, sync batch. | Confirm asset, complete inspection, conflict revision, export job. |
| E2E | Prototype happy path + edge states. | Register → onboarding → scan → confirm → inspection → history; offline → sync. |
| Security | Auth, authorization, file upload, rate limit. | Cross-user read/write, oversized file, expired reset token. |
| Usability | Field workflow và recovery. | Camera permission, OCR failed, QR no data, export success comprehension. |

## 13.1 Required Regression Scenarios

| **Case** | **Expected result** |
| --- | --- |
| New account onboarding | Register thành công → chọn loại cơ sở → tạo cơ sở → scan hoặc skip → Home. |
| Camera permission denied | Hiển thị permission state; có CTA xin quyền và fallback an toàn. |
| OCR failed | Không tạo asset; retry/manual khả dụng. |
| QR no data | Không giả dữ liệu; chuyển OCR/manual. |
| Low-confidence OCR field | Field được đánh dấu review; user sửa và confirm mới lưu. |
| Duplicate confirm retry | Không tạo hai Asset/Inspection khi network timeout rồi retry. |
| Inspection with issue | Checklist + overall result + note/evidence lưu, History Detail phản ánh đúng. |
| Reminder overdue | Đúng nhóm overdue; mark notification read không complete reminder. |
| Offline create asset | Local record + pending operation tồn tại qua restart; sync sau khi có mạng. |
| Sync version conflict | Server không ghi đè mù; client nhận conflict metadata. |
| Storage upload failure | Core record không mất; media state recoverable. |
| Export PDF/CSV | Artifact mở được, đúng Facility/date/filter; success chỉ khi file sẵn sàng. |
| Cross-user resource access | Bị từ chối ở server. |

# 14\. Risk Register & Mitigations

| **Risk** | **Impact** | **Likelihood** | **Mitigation / Owner decision** |
| --- | --- | --- | --- |
| OCR handwritten date inaccurate | Sai mốc theo dõi nếu user không để ý | High | Human review bắt buộc; confidence cue; benchmark dataset thật; không auto-save. |
| QR heterogeneous / vendor-specific | QR đọc được nhưng không map | High | Provider-agnostic parser + QR No Data fallback; raw payload retained for debug. |
| User treats reminder as legal compliance | Hiểu sai phạm vi sản phẩm | Medium | Copy/disclaimer rõ; dữ liệu mốc có source; không dùng ngôn ngữ kết luận pháp lý. |
| Offline conflict on same Asset | Mất update hoặc ghi đè | Medium | Revision check; conflict metadata; idempotent operation log. |
| Evidence image storage grows | Chi phí và privacy tăng | Medium | Compression, lifecycle/retention, optional evidence export, delete controls. |
| Push delivery unreliable | Người dùng bỏ lỡ nhắc | Medium | Reminder in-app là source; retry/dedupe; badge khi mở app. |
| Checklist hard-coded too narrowly | Khó mở rộng loại thiết bị | Medium | Versioned configurable template; snapshot per Inspection. |
| Report with many images timeout | UX xấu / job fail | Medium | Async job, evidence size limit, thumbnails, status polling. |
| Ownership/RBAC underspecified | Rủi ro access khi mở rộng team | Medium | Giữ server-side ownership boundary; thiết kế future membership/RBAC trước enterprise release. |

# 15\. Delivery Plan

| **Phase** | **Scope** | **Exit criteria** |
| --- | --- | --- |
| 1   | Auth + onboarding + Facility/Area | Tài khoản mới vào được Home với Facility đầu tiên; CRUD cơ bản ổn định. |
| 2   | Manual Asset + Asset list/detail | Tạo/sửa/xem Asset không cần OCR; ownership và audit cơ bản hoạt động. |
| 3   | QR/OCR scan + confirmation | Scan candidate → review → confirmed asset; OCR failed/permission/QR no data có fallback. |
| 4   | Inspection + History | Checklist, result, evidence metadata, History Detail và audit transaction. |
| 5   | Reminder + Notifications | Due grouping, lead time, in-app notification, push adapter và dedupe. |
| 6   | Offline-first + Sync | Local operation log, retry, idempotency, conflict handling và sync states. |
| 7   | Reporting + Settings/Profile | PDF/CSV export, export success, app settings, profile/password/account flows. |
| 8   | Hardening | Security, observability, benchmark OCR, performance, regression E2E và accessibility. |
| 9   | Future expansion | RBAC, bulk import, vendor integration, analytics/AI assist. |

|     |     |
| --- | --- |
| **D** | **Evaluation focus: Đồ án nên chứng minh tốt ba năng lực kỹ thuật chính: pipeline OCR/QR có human confirmation, mô hình dữ liệu/audit cho quản lý thiết bị, và offline synchronization idempotent. Reminder/reporting là các use case giúp hoàn chỉnh giá trị sản phẩm.** |

# 16\. Acceptance & Release Gates

| **Gate** | **Required evidence** |
| --- | --- |
| G1 — Requirements | Mọi P0 FR/NFR có owner, test case và trạng thái pass/fail. |
| G2 — OCR safety | Không có đường code test nào lưu raw OCR thành confirmed domain value nếu chưa confirm. |
| G3 — Data integrity | Confirm Asset, Complete Inspection và Sync retry vượt transaction/idempotency regression. |
| G4 — Offline | Create/update supported flows sống qua airplane mode + app restart + reconnect. |
| G5 — Security | Không truy cập chéo account; auth/reset/upload controls đạt security checklist. |
| G6 — Edge states | Camera Permission, OCR Failed, QR No Data, Offline, Sync Error và Export Success đều có E2E route. |
| G7 — Observability | Metrics/logs/audit đủ để debug scan/sync/report failures mà không cần raw secret. |
| G8 — UX/Accessibility | Happy path prototype click-through tương ứng implementation; copy phục hồi lỗi rõ và touch target đạt guideline. |

# 17\. Open Questions & Future Evolution

| **Question** | **Why it matters** | **Decision needed** |
| --- | --- | --- |
| OCR chạy on-device, cloud hay hybrid? | Ảnh riêng tư, độ trễ, chi phí và offline capability. | Benchmark 2–3 lựa chọn trên ảnh tem thật. |
| Mốc nào được coi là “due date” mặc định? | Ảnh hưởng reminder semantics và copy pháp lý. | Product/domain expert chốt rule; không suy ra chỉ từ OCR. |
| Ảnh OCR giữ bao lâu? | Privacy và chi phí storage. | Retention policy + user delete control. |
| Có cần role kỹ thuật viên/chủ cơ sở trong MVP? | Thay đổi ownership và authorization model. | Baseline single-owner hay thêm membership ngay từ đầu. |
| Checklist theo loại thiết bị nào? | Data model và UX Inspection. | Chốt catalog thiết bị MVP và template version. |
| Conflict offline được auto-merge tới mức nào? | Complexity sync và nguy cơ mất update. | Baseline reject + refresh/reapply; field merge là Future. |
| Export có cần ký số/biên bản pháp lý? | Tăng mạnh yêu cầu compliance. | Out-of-scope baseline trừ khi stakeholder yêu cầu. |

# 18\. Glossary

| **Term** | **Definition** |
| --- | --- |
| Facility | Cơ sở vận hành chứa các khu vực và thiết bị. |
| Area | Khu vực bên trong Facility, ví dụ Xưởng A, Kho A, phòng máy. |
| Asset | Thiết bị PCCC được quản lý, có serial/mã, vị trí và lịch sử. |
| ScanSession | Một lần quét camera/QR/OCR và tập candidate fields. |
| Candidate field | Giá trị recognition chưa được xem là dữ liệu vận hành chính thức. |
| Confirmed field | Giá trị đã được người dùng xác nhận và lưu vào domain. |
| Provenance | Nguồn của dữ liệu: manual, QR, OCR, inspection hoặc system-derived. |
| Service Milestone | Mốc bảo dưỡng/kiểm tra/nạp sạc đã được xác nhận. |
| Reminder | Bản ghi nhắc việc tính từ milestone và lead time. |
| Notification | Thông điệp in-app/push phát sinh từ reminder hoặc sự kiện hệ thống. |
| Inspection | Một lần kiểm tra hiện trường với checklist snapshot, result, note và evidence. |
| Evidence | Ảnh/bằng chứng gắn với Asset hoặc Inspection. |
| AuditEvent | Sự kiện append-only dùng để truy vết thay đổi nghiệp vụ. |
| Operational status | Trạng thái suy ra như due soon/overdue/needs follow-up; khác lifecycle state. |
| Offline operation | Write được lưu local và chờ gửi backend khi có mạng. |
| Idempotency | Thuộc tính cho phép retry cùng operation mà không tạo side effect trùng. |
| Revision conflict | Client update dựa trên version cũ trong khi server resource đã thay đổi. |
| ExportJob | Job tạo báo cáo PDF/CSV theo filter snapshot. |
| Human-in-the-loop | Người dùng review/xác nhận kết quả AI/OCR trước khi dùng làm dữ liệu chính thức. |