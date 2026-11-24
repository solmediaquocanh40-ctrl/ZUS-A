# ZUS 1.1.7 (gói com.anhdang.zalounseen)

Tweak chích vào Zalo trên máy đã jailbreak: đọc tin nhắn mà bên kia không thấy
"đã xem" — đoạn chat vẫn giữ chữ đậm như chưa đọc — kèm tắt "đang nhập...",
chặn "đã nhận", chống thu hồi, ẩn đã xem Story và bộ công cụ danh bạ riêng.

## Tính năng

- **Chặn "đã xem"**: đọc tin thoải mái, đoạn chat vẫn in đậm, bên kia không
  thấy "đã xem". Trả lời lại thì seen bình thường. Áp dụng mọi người + nhóm.
- **Chặn "đã nhận"** (công tắc riêng, mặc định bật như 1.0.6): bên kia chỉ
  thấy "đã gửi". Lần gọi nào mang cờ đã-xem vẫn bị chặn theo nhóm đã-xem.
- **Tắt "đang nhập..."** khi gõ trong đoạn chat.
- **Chống thu hồi**: tin bị thu hồi vẫn hiện nguyên nội dung trên máy này
  (cả xoá-cho-mọi-người vì cùng đường "undo").
- **Ẩn "đã xem" Story** theo nhóm đã-xem.
- **Tải Story về máy** (mặc định tắt): Zalo tự hiện nút lưu Story của chính nó.
- **Giữ màn hình sáng** khi dùng Zalo (mặc định tắt).
- **Màn chắn riêng tư** (mặc định tắt): phủ mờ Zalo khi thoát ra đa nhiệm,
  ảnh chụp màn hình đa nhiệm không lộ nội dung.
- **Backup danh bạ Zalo**: xuất ZUS-Contacts.json / .csv / .vcf vào thư mục
  Documents của Zalo (tên, mã Zalo, số điện thoại khi Zalo có, avatar).
- **Restore danh bạ**: đối chiếu bản sao lưu với danh bạ hiện tại, liệt kê
  người đã mất, chạm để mở trang Zalo của họ (có số) hoặc chép mã Zalo.
- **Hồ sơ ZUS**: xuất/nhập toàn bộ công tắc ra file ZUS-Profile.json.
- **Cảnh báo khi Zalo đổi phiên bản**: ghi log để đối chiếu lại cửa móc.

## Cài đặt — hai nơi, một kho

- Trong Zalo: **ấn giữ thanh tab dưới đáy** (bất kỳ tab nào, ~0,5 giây) mở
  bảng công tắc + mục Danh bạ & hồ sơ + xem trạng thái dò; nút tròn **ZUS**
  ở màn hình chat vẫn còn làm lối vào dự phòng. (1.1.1)
- **1.1.7 — sửa giao diện + tính năng mới**: theme viết lại kiểu
  ZaloZen (xanh chỉ là điểm nhấn, tách màu ô khỏi màu thanh, nhuộm cả
  chữ header/footer); icon Cài đặt thành huy hiệu tròn nhỏ; nút trong
  Zalo hiện đúng logo con mắt (ép nguyên bản, hết bị nhuộm thành chấm
  xanh). Mới: kho tin đã thu hồi; ấn giữ tin trong chat để tải video
  (chọn chất lượng theo link trích được), tải ảnh gốc, dịch tin nhắn;
  dò quảng cáo trong danh sách chat (mức dò — chỉ mặt qua log, chưa
  giấu). Ấn-giữ/dò quảng cáo đều là vòng dò: log ghi bản đồ lớp ô và
  model để hiệu chỉnh vòng sau.
- **1.1.6 — sửa khung bảng ZUS**: thanh tab của bảng bị chui dưới tai
  thỏ/thanh trạng thái trên máy 12 Pro (ghim khung từ y=0). Neo lại theo
  vùng an toàn + tắt tiêu đề lớn của thanh điều hướng. Chỉ sửa khung,
  không đổi tính năng.
- **1.1.5 — bản gộp theo ý anh**: icon Cài đặt thu lại bằng icon khác;
  nút trong chat đổi chữ ZUS thành icon con mắt; sao lưu danh bạ mang
  ngày-giờ, hiện đường dẫn + nút Chia sẻ, khôi phục có danh sách chọn bản;
  bảng ZUS chia 4 tab (Chặn / Dữ liệu / Giao diện / Thông tin) và nhuộm
  màu được (3 bộ sẵn + tự chọn từng phần); chặn theo giờ (mặc định TẮT,
  anh chủ động đặt mới chạy); cài riêng theo đoạn chat (Chung/Bật/Tắt),
  khoá đoạn chat tại chỗ bằng Face ID, nhật ký chặn theo đoạn chat;
  cảnh báo link đáng ngờ (mức dò). Ba món theo đoạn chat dùng chung chìa
  khoá trích mã đoạn chat từ màn hình chat — log sẽ cho biết trúng chưa.
- **1.1.4 — chữa trích xuất danh bạ**: log 1.1.3 cho thấy bắt thực thể +
  cloneFriendList đã chạy (266 bạn, lớp BuddyEntity) nhưng tên trường của
  BuddyEntity là chữ thường (displayname, zaloid, userid, avatarurl,
  contactname, mobile) trong khi danh sách khoá cũ dùng camelCase nên
  trích ra toàn rỗng và sao lưu ghi 0 bạn. Đổi danh sách khoá theo đúng
  dump. Bump version lần này rà đủ cả prefs/Resources/Info.plist và
  workflow trong cây (hai chỗ từng sót ở 1.1.3).
- **1.1.3 — hợp nhất kho cài đặt qua container + danh bạ vòng 3**: trang Cài
  đặt tự tìm file domain trong container của Zalo và đọc/ghi thẳng vào đó
  (hai điểm ghi đè chuẩn của PSListController), soi gương sang kho toàn cục
  và bắn thông báo để tweak nạp lại ngay; phía tweak cũng ưu tiên đọc/ghi
  file ngay trong container của mình (đường /var/mobile bị sandbox chặn —
  log 1.1.2 đã chứng minh). Danh bạ: móc các hàm init của FriendFlowManager
  và MSDataCoordinator để bắt thực thể ngay khi Zalo tạo ra, dump thuộc
  tính của coordinator, thêm các selector trả danh sách mà bản đồ đã lộ
  (copySortedFriendsArray, copyNonBlockedFriendsDictionary...). Bổ sung
  cùng bản: móc riêng đúng kiểu cho cửa seenTime của InboxDataManager —
  cửa duy nhất bị cổng an toàn từ chối ở mọi bản trước vì tham số double,
  nghi phạm của lỗi "đang mở chat, tin mới tới thì bị seen"; chặn khi nhóm
  đã-xem bật và lần gọi mang seenTime > 0, 10 lần gọi đầu ghi lại giá trị
  để đối chiếu.
- **1.1.2 — chữa lỗi hai kho cài đặt**: tweak đọc/ghi thẳng file prefs chung
  `/var/mobile/Library/Preferences/com.anhdang.zalounseen.plist` (đọc file
  trước, ghi cả hai kho) nên gạt trong Zalo và trong Cài đặt của máy từ nay
  là MỘT. Nút ZUS + ấn giữ thanh tab luôn hiện kể cả khi công tắc tổng tắt
  (chúng là lối vào cài đặt) — lỡ tắt ở đâu cũng mở lại ngay tại đó.
- Sao lưu danh bạ vòng 2 (1.1.1): bám thẳng `FriendFlowManager.cloneFriendList`
  — nguồn log 1.1.0 đã chỉ — qua `ChatDataManager.friendFlowManager`.
- Trong Cài đặt của máy: mục **ZUS** (có icon) với cùng các công tắc.
Hai nơi ghi cùng một kho cài đặt, gạt ở đâu là ăn ngay ở đó. Tweak còn nạp
lại cài đặt mỗi khi mở đoạn chat và ghi log mỗi lần cài đặt thay đổi.

## Log

File `ZUS.log` trong Documents của Zalo (Filza → Apps → Zalo → Documents).
Mọi lần chặn, lần đổi cài đặt, mốc nạp và kết quả dò danh bạ đều ghi vào đó.

## Cấu trúc gói

- `tweak/` — dylib ZUS chích vào Zalo (filter vn.com.vng.zingalo), danh sách
  trắng 45 cửa móc cố định (không quét theo mẫu), cổng kiểm tra kiểu dữ liệu
  cho từng cửa, hàm thay thế không giữ tham số (bài học văng 1.0.4).
- `prefs/` — gói Cài đặt ZUSPrefs (chỉ link UIKit + dynamic_lookup).
- `layout/` — mục PreferenceLoader (isController = true, icon ZUSIcon.png).

## Chưa làm (để vòng riêng, theo quy tắc "chưa chắc thì khỏi")

Chỉnh riêng từng hội thoại; khoá đoạn chat bằng Face ID; ẩn trạng thái đang
hoạt động (chưa có cửa); gửi ảnh gốc; tải media hàng loạt; gán nhãn bạn bè;
ẩn avatar/tên/tin cuối và ẩn tab (nhóm giao diện); chặn quảng cáo; chạm 2 lần
sao chép; kho lưu tin nhắn; dịch trong chat; cảnh báo link lạ; lên lịch gửi
tin; ghi âm cuộc gọi; phát nền khi tắt màn hình.
