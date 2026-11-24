// ZUS 1.1.3 — đọc tin nhắn Zalo mà bên kia không thấy "đã xem", tắt "đang nhập...".
//
// SỬA GỐC VỤ VĂNG CỦA 1.0.4 (đã chứng minh ở mức lệnh máy từ file .ips và đúng
// file .deb đã cài): hàm thay thế chung ZUSGenericHook khai tham số kiểu `id`,
// dưới ARC trình biên dịch tự chèn objc_retain cho CẢ hai tham số ngay khi vào
// hàm. Hàm đích nào có tham số thứ hai là SỐ NGUYÊN (ví dụ phần `type:` của
// ConversationModel.updateLastSeenWithMessage:type:) thì lệnh retain đó đọc
// con số như một địa chỉ bộ nhớ → EXC_BAD_ACCESS tại đúng giá trị của con số
// (0x20), trên hàng đợi của model nhóm, chết trước khi kịp chặn hay ghi log.
// 1.0.5: mọi hàm thay thế khai tham số là __unsafe_unretained / void* — ARC
// không retain bất cứ tham số nào nữa; chữ ký gọi bản gốc cũng khai tương ứng.
//
// Cơ chế DANH SÁCH TRẮNG (từ 1.0.4): chỉ móc đúng các hàm GỬI trạng thái
// đã xem / đang nhập đã được kiểm chứng — từ log máy thật của bản 1.0.3 và từ bộ
// móc của ZaloTools (BVN) mà Quoc đã thử trên đúng bản Zalo này: lớp màn hình chat
// (BaseChatTVC), lớp xử lý (BaseChatProcessor), lớp quản lý hàng đợi + gửi
// (ChatSendSeenDataManager, ChatDataManager), lớp socket (ChatSocketCmdHelper)
// và lớp trạng thái trong máy (ConversationModel); 1.0.6 thêm lớp dữ liệu
// (ChatDataManager, ChatDataFlow, InboxDataManager, ChatProcessor). Tổng 36 hàm.
// 1.0.5 bỏ hai hàm sendGetChatSeen/sendGetGroupSeen từng có trong danh sách dự
// thảo: hai hàm đó LẤY danh sách người đã xem tin của CHÍNH mình — không thuộc
// luồng cần chặn, móc chúng có nguy cơ làm hỏng mục "ai đã xem" trong nhóm.
// Thêm ghi nhận "lần đầu được gọi" cho từng cửa: vòng thử sau chỉ cần nhìn log
// là biết cửa nào thật sự chạy khi mở đoạn chat, kể cả cửa được chuyển tiếp.
//
// 1.0.6 — HAI THAY ĐỔI TỪ LOG MÁY THẬT CỦA 1.0.5 (phiên 01:20 ngày 11-24):
// (a) 1.0.5 HẾT VĂNG THẬT nhưng chữ vẫn mất đậm, dù log chứng minh cả 25 cửa
// lắp được đều chạy và bị chặn khi mở nhóm — kể cả setLastSeenObject: trong
// máy và forceSendSeenServer ra máy chủ. Kết luận: luồng đánh dấu đã đọc còn
// chạy qua LỚP DỮ LIỆU (ghi trạng thái đã xem vào giao diện + cơ sở dữ liệu)
// nằm ngoài 25 cửa. 1.0.6 thêm 9 cửa lớp dữ liệu (tổng 36): họ
// processUpdateStatus...withUI:withDB: của ChatDataManager / ChatDataFlow /
// InboxDataManager, processResetUnread... của ChatProcessor, và
// updateMaxSeenGlobalId: / checkSendClearUnreadType: của ChatDataManager —
// tên hàm lấy từ danh sách ứng viên trong chính bản Zalo của máy (log 1.0.3).
// (b) ĐANG NHẬP: log 1.0.5 ghi rõ mã kiểu — sendTyping... trả về B,
// sendStatusTyping... trả về Q. Nguyên nhân bị từ chối ở 1.0.4 KHÔNG phải ký
// tự định tính (giả thuyết cũ đã sai): cổng chỉ nhận hàm trả về void. 1.0.6
// nới cổng cho mọi kiểu trả về vô hướng/con trỏ và mọi hàm thay thế trả lại
// long long: chuyển tiếp thì trả nguyên giá trị gốc, chặn thì trả 0.
//
// 1.1.0 — BẢN TÍNH NĂNG CHÍNH THỨC (anh duyệt ngày 2026-11-24, đổi tên ZUS).
// Nguyên tắc cứng: 36 cửa của 1.0.6 giữ nguyên; mọi thứ mới đều cộng thêm,
// tắt được từng món, hỏng thì chỉ hỏng phần mới.
// - Đổi thương hiệu ZU → ZUS (nút, bảng cài đặt, tên gói hiển thị); mã gói
//   com.anhdang.zalounseen và kho cài đặt giữ nguyên để không mất dữ liệu cũ.
// - Tách "đã nhận" thành nhóm riêng (nhóm 3, khoá hideDelivered, mặc định BẬT
//   = đúng hành vi 1.0.6): 5 cửa delivered của ChatSocketCmdHelper. Riêng lần
//   gọi nào mang cờ isSeen=YES thì vẫn chặn theo nhóm đã-xem dù đã-nhận đang
//   tắt — không để lọt đã-xem qua cửa hậu.
// - Chống thu hồi (nhóm 4, khoá antiRecall, mặc định BẬT): 7 cửa ở chuỗi xử
//   lý thu hồi (Zalo gọi là "undo"), điểm móc lấy từ chính dylib của
//   ZaloTools (BVN) vốn nhắm đúng thế hệ Zalo này: MSDataCoordinator
//   (handleRecallMessageNotification:, _handleRecallWithData:),
//   UndoChatProcessor.updateDBUndo... (hàm class), ChatUIManager
//   (processUndoWithSocketChatEntity:, handleUpdateUndo... — hàm class),
//   ChatEntity.preprocessMessageUndo, TalkTableItem.updateUndoWithParser:.
// - Ẩn "đã xem" cho Story (nhóm 1): StoryManager.updateSeenStoryStatus: +
//   StoryEntity.updateSeen: — tên hàm trong chính bản Zalo của máy (log 1.0.3).
// - Giữ màn hình sáng (khoá keepAwake, mặc định TẮT): không móc hàm nào —
//   chỉ đặt idleTimerDisabled lúc nạp và mỗi khi đổi cài đặt.
// - Cửa cài đặt ngay trong Zalo (khoá inAppUI, mặc định BẬT): nút tròn "ZUS"
//   trong màn hình chat (móc viewWillAppear: của BaseChatTVC, LUÔN chuyển
//   tiếp bản gốc trước, bọc try/catch) mở bảng công tắc ZUSSettingsController
//   viết riêng trong file này — ghi cùng kho prefs + cùng thông báo Darwin
//   nên đổi trong Zalo là ăn ngay; trang Cài đặt của máy vẫn giữ nguyên.
// - Vá vụ "tắt mà vẫn unseen" (từ log 2026-11-24): nạp lại kho cài đặt mỗi
//   khi mở đoạn chat + ghi log mỗi khi phát hiện cài đặt thay đổi.
// - Tải Story về máy (khoá storyDownload, mặc định TẮT): trả YES cho
//   isAllowDownloadCurrentStory trên lớp Story (điểm móc theo ZaloZen 3.0.0
//   vốn nhắm đúng thế hệ Zalo này) để Zalo tự hiện nút lưu của chính nó.
// - Màn chắn riêng tư (khoá privacyShield, mặc định TẮT): phủ mờ mọi cửa sổ
//   khi Zalo sắp rời tiền cảnh (ảnh chụp đa nhiệm không lộ nội dung), gỡ ra
//   ngay khi quay lại. Không móc hàm nào của Zalo.
// - Cảnh báo khi Zalo đổi phiên bản: ghi log + mốc chẩn đoán để đối chiếu
//   cửa móc sau mỗi lần Zalo cập nhật.
// - Backup/restore DANH BẠ (yêu cầu riêng của anh): xuất ZUS-Contacts.json /
//   .csv / .vcf vào Documents của Zalo; khôi phục = đối chiếu bản sao với
//   danh bạ hiện tại, liệt kê người đã mất, chạm để mở trang Zalo (có số)
//   hoặc chép mã Zalo. Nguồn bạn bè đi đường DÒ CÓ KIỂM SOÁT (xem
//   ZUSCollectFriends) vì chưa có bản đồ lớp bạn bè trong log cũ.
// - Hồ sơ ZUS: xuất/nhập toàn bộ công tắc ra file ZUS-Profile.json.
// ĐÃ LOẠI theo đúng quy tắc "chưa chắc thì khỏi" của anh: chỉnh riêng từng
// hội thoại, khoá đoạn chat bằng Face ID, ẩn trạng thái đang hoạt động (chưa
// có cửa), gửi ảnh gốc, tải media hàng loạt, gán nhãn bạn bè, ẩn avatar/tên/
// tin cuối + ẩn tab (nhóm giao diện — cần vòng dò riêng), chặn quảng cáo,
// chạm 2 lần sao chép, kho lưu tin nhắn, dịch trong chat, cảnh báo link lạ
// (cả bốn món sau cần đường đọc nội dung tin — vòng dò riêng), lên lịch gửi
// tin, ghi âm cuộc gọi, phát nền khi tắt màn hình (anh tự bỏ).
//
// Vì sao bỏ cơ chế dò theo mẫu của 1.0.0–1.0.3: log 1.0.3 cho thấy mẫu khớp theo
// chuỗi con đã nổ tung — chữ "read" nằm trong "thread", "already", "ready", "reader"
// nên 1.162 ứng viên lọt lưới, 877 hàm bị móc, phần lớn là hàm gán dữ liệu
// (setThreadId:...) khắp app. Chặn các hàm gán đó làm Zalo sập ngay khi mở.
// Từ 1.0.4: không quét, không khớp mẫu — danh sách cố định, hàm nào không thấy
// hoặc kiểu dữ liệu không khớp kỳ vọng thì ghi log và bỏ qua, tuyệt đối không
// đụng vào phần còn lại của app.

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import <objc/message.h>
#import <substrate.h>
#import "ZUSShared.h"

// ---------------- Cài đặt ----------------
static BOOL gEnabled = YES;
static BOOL gUnseen = YES;
static BOOL gHideTyping = YES;
static BOOL gDebug = YES;
static BOOL gHideDelivered = YES; // 1.1.0: mặc định BẬT = đúng hành vi 1.0.6
static BOOL gAntiRecall = YES;
static BOOL gKeepAwake = NO;
static BOOL gInAppUI = YES;
static BOOL gLongPressTab = YES; // 1.1.1: ấn giữ thanh tab mở bảng ZUS
static BOOL gStoryDownload = NO;
static BOOL gPrivacyShield = NO;
static BOOL gPrefsSeen = NO;

static void ZUSLog(NSString *fmt, ...);

// ----- Kho prefs CHUNG (1.1.2) -----
// Bài học đắt của 1.1.1: CFPreferences gọi từ trong Zalo rơi vào kho
// container của Zalo, còn trang Cài đặt ghi vào file chung
// /var/mobile/Library/Preferences — hai kho lệch nhau khiến anh tắt tổng
// trong Zalo rồi gạt lại ở Cài đặt suốt một giờ mà tweak không hề biết.
// Từ 1.1.2: FILE CHUNG là nguồn chính — đọc file trước (không có khoá mới
// ngã về CFPreferences rồi mặc định), ghi thì ghi CẢ HAI nơi cho hai kho
// hội tụ dần. Kết quả đọc/ghi file đều có log để kiểm chứng trên máy thật.
static NSString *ZUSSharedPrefsPath(void) {
    // 1.1.3: tiến trình nằm trong container của Zalo thì file domain nằm
    // ngay trong container đó — đọc/ghi trực tiếp được, không qua cfprefsd
    // (1.1.2 đã chứng minh đường /var/mobile bị sandbox chặn cả hai chiều).
    // Ngoài container thì giữ đường toàn cục.
    NSString *home = NSHomeDirectory();
    if ([home containsString:@"/Containers/"]) {
        return [[[home stringByAppendingPathComponent:@"Library/Preferences"]
                 stringByAppendingPathComponent:ZUS_DOMAIN] stringByAppendingString:@".plist"];
    }
    return [@"/var/mobile/Library/Preferences/" stringByAppendingString:[ZUS_DOMAIN stringByAppendingString:@".plist"]];
}
static NSDictionary *ZUSReadFilePrefs(void) {
    return [NSDictionary dictionaryWithContentsOfFile:ZUSSharedPrefsPath()];
}
static BOOL gFileWriteLogged = NO;
// Mọi lần sửa file chung đều qua một khoá duy nhất (đọc–sửa–ghi là một khối)
// để luồng chặn tin và luồng giao diện không ghi đè lẫn nhau.
static NSObject *ZUSPrefsFileLock(void) {
    static NSObject *lock = nil;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ lock = [[NSObject alloc] init]; });
    return lock;
}
static void ZUSWriteSharedValue(NSString *key, id value) {
    NSMutableDictionary *fp = nil;
    BOOL wok = NO;
    @synchronized (ZUSPrefsFileLock()) {
        fp = [ZUSReadFilePrefs() mutableCopy];
        if (!fp) fp = [NSMutableDictionary dictionary];
        if (value) fp[key] = value; else [fp removeObjectForKey:key];
        wok = [fp writeToFile:ZUSSharedPrefsPath() atomically:YES];
    }
    if (!gFileWriteLogged) {
        gFileWriteLogged = YES;
        ZUSLog(@"ghi file prefs chung: %@", wok ? @"OK" : @"THẤT BẠI (có thể bị sandbox chặn ghi — đọc log nguồn cài đặt để đối chiếu)");
    }
    CFPreferencesSetAppValue((__bridge CFStringRef)key, (__bridge CFPropertyListRef)value, (__bridge CFStringRef)ZUS_DOMAIN);
    CFPreferencesAppSynchronize((__bridge CFStringRef)ZUS_DOMAIN);
}

static BOOL ZUSReadBool(NSString *key, BOOL def) {
    id fv = ZUSReadFilePrefs()[key];
    if ([fv isKindOfClass:[NSNumber class]]) return [fv boolValue];
    CFPropertyListRef v = CFPreferencesCopyAppValue((__bridge CFStringRef)key, (__bridge CFStringRef)ZUS_DOMAIN);
    if (!v) return def;
    BOOL r = def;
    if (CFGetTypeID(v) == CFBooleanGetTypeID()) r = CFBooleanGetValue((CFBooleanRef)v);
    else if (CFGetTypeID(v) == CFNumberGetTypeID()) { int n = 0; CFNumberGetValue((CFNumberRef)v, kCFNumberIntType, &n); r = (n != 0); }
    CFRelease(v);
    return r;
}

static void ZUSLoadPrefs(void) {
    BOOL oEnabled = gEnabled, oUnseen = gUnseen, oTyping = gHideTyping, oDeliv = gHideDelivered, oRecall = gAntiRecall;
    CFPreferencesAppSynchronize((__bridge CFStringRef)ZUS_DOMAIN);
    gEnabled = ZUSReadBool(ZUS_KEY_ENABLED, YES);
    gUnseen = ZUSReadBool(ZUS_KEY_UNSEEN, YES);
    gHideTyping = ZUSReadBool(ZUS_KEY_TYPING, YES);
    gDebug = ZUSReadBool(ZUS_KEY_DEBUG, YES);
    gHideDelivered = ZUSReadBool(ZUS_KEY_DELIVERED, YES);
    gAntiRecall = ZUSReadBool(ZUS_KEY_ANTIRECALL, YES);
    gKeepAwake = ZUSReadBool(ZUS_KEY_AWAKE, NO);
    gInAppUI = ZUSReadBool(ZUS_KEY_INAPP, YES);
    gLongPressTab = ZUSReadBool(ZUS_KEY_LONGTAB, YES);
    gStoryDownload = ZUSReadBool(ZUS_KEY_STORYDL, NO);
    gPrivacyShield = ZUSReadBool(ZUS_KEY_SHIELD, NO);
    if (gPrefsSeen && (oEnabled != gEnabled || oUnseen != gUnseen || oTyping != gHideTyping || oDeliv != gHideDelivered || oRecall != gAntiRecall))
        ZUSLog(@"cài đặt đổi: bật=%d đã-xem=%d đã-nhận=%d đang-nhập=%d thu-hồi=%d", gEnabled, gUnseen, gHideDelivered, gHideTyping, gAntiRecall);
    gPrefsSeen = YES;
}

// Giữ màn hình sáng: không móc hàm nào của Zalo — chỉ đặt cờ của hệ thống
// trên luồng chính, lúc nạp và mỗi khi cài đặt thay đổi.
static void ZUSApplyAwake(void) {
    BOOL want = gEnabled && gKeepAwake;
    dispatch_async(dispatch_get_main_queue(), ^{
        [UIApplication sharedApplication].idleTimerDisabled = want;
    });
}

static void ZUSPrefsChanged(CFNotificationCenterRef center, void *observer, CFStringRef name, const void *object, CFDictionaryRef userInfo) {
    ZUSLoadPrefs();
    ZUSApplyAwake();
}

// Ghi một khoá cài đặt rồi phát thông báo để chính tweak nạp lại ngay (dùng
// cho bảng công tắc trong Zalo; trang Cài đặt của máy đi đường Preferences).
static void ZUSSetPrefBool(NSString *key, BOOL val) {
    ZUSWriteSharedValue(key, @(val));
    CFNotificationCenterPostNotification(CFNotificationCenterGetDarwinNotifyCenter(), ZUS_NOTIFY, NULL, NULL, true);
}

// ---------------- Log ----------------
static NSString *gLogPath = nil;
static id gLogLock = nil;
static NSDateFormatter *gLogFmt = nil;

static void ZUSLog(NSString *fmt, ...) {
    if (!gDebug) return;
    va_list ap; va_start(ap, fmt);
    NSString *msg = [[NSString alloc] initWithFormat:fmt arguments:ap];
    va_end(ap);
    NSLog(@"[ZUS] %@", msg);
    if (!gLogPath || !gLogLock) return;
    NSString *line = [NSString stringWithFormat:@"%@ %@\n", [gLogFmt stringFromDate:[NSDate date]], msg];
    @synchronized (gLogLock) {
        NSFileHandle *h = [NSFileHandle fileHandleForWritingAtPath:gLogPath];
        if (h) { [h seekToEndOfFile]; [h writeData:[line dataUsingEncoding:NSUTF8StringEncoding]]; [h closeFile]; }
        else [line writeToFile:gLogPath atomically:YES encoding:NSUTF8StringEncoding error:nil];
    }
}

// ---------------- Chẩn đoán (ghi vào kho cài đặt cho trang Cài đặt đọc) ----------------
static long gBlockedRead = 0;
static long gBlockedTyping = 0;
static long gBlockedDelivered = 0;
static long gBlockedRecall = 0;
static NSString *gLastEvent = @"";
static NSTimeInterval gLastDiagWrite = 0;

static void ZUSWriteDiag(void) {
    CFPreferencesSetAppValue((__bridge CFStringRef)ZUS_DIAG_BLOCKED_READ, (__bridge CFPropertyListRef)@(gBlockedRead), (__bridge CFStringRef)ZUS_DOMAIN);
    CFPreferencesSetAppValue((__bridge CFStringRef)ZUS_DIAG_BLOCKED_TYPE, (__bridge CFPropertyListRef)@(gBlockedTyping), (__bridge CFStringRef)ZUS_DOMAIN);
    CFPreferencesSetAppValue((__bridge CFStringRef)ZUS_DIAG_BLOCKED_DELIV, (__bridge CFPropertyListRef)@(gBlockedDelivered), (__bridge CFStringRef)ZUS_DOMAIN);
    CFPreferencesSetAppValue((__bridge CFStringRef)ZUS_DIAG_BLOCKED_RECALL, (__bridge CFPropertyListRef)@(gBlockedRecall), (__bridge CFStringRef)ZUS_DOMAIN);
    CFPreferencesSetAppValue((__bridge CFStringRef)ZUS_DIAG_LAST, (__bridge CFPropertyListRef)gLastEvent, (__bridge CFStringRef)ZUS_DOMAIN);
    CFPreferencesAppSynchronize((__bridge CFStringRef)ZUS_DOMAIN);
    gLastDiagWrite = [NSDate timeIntervalSinceReferenceDate];
    // 1.1.2: chụp thêm xuống file chung (tối đa 15 giây một lần) để mục
    // trạng thái dò ở trang Cài đặt của máy đọc được số thật.
    static NSTimeInterval sLastFileDiag = 0;
    if (gLastDiagWrite - sLastFileDiag >= 15.0) {
        sLastFileDiag = gLastDiagWrite;
        @synchronized (ZUSPrefsFileLock()) {
            NSMutableDictionary *fp = [ZUSReadFilePrefs() mutableCopy];
            if (!fp) fp = [NSMutableDictionary dictionary];
            fp[ZUS_DIAG_BLOCKED_READ] = @(gBlockedRead);
            fp[ZUS_DIAG_BLOCKED_TYPE] = @(gBlockedTyping);
            fp[ZUS_DIAG_BLOCKED_DELIV] = @(gBlockedDelivered);
            fp[ZUS_DIAG_BLOCKED_RECALL] = @(gBlockedRecall);
            fp[ZUS_DIAG_LAST] = gLastEvent;
            [fp writeToFile:ZUSSharedPrefsPath() atomically:YES];
        }
    }
}

static void ZUSWriteDiagThrottled(void) {
    if ([NSDate timeIntervalSinceReferenceDate] - gLastDiagWrite < 2.0) return;
    ZUSWriteDiag();
}

// ---------------- Kiểm tra kiểu dữ liệu ----------------
// Kiểu trả về an toàn cho hàm thay thế trả long long: void, BOOL, mọi số nguyên
// và mọi con trỏ/object đều về qua thanh ghi x0 (void thì nơi gọi bỏ qua x0),
// nên giá trị gốc được giữ nguyên bit khi chuyển tiếp, chặn thì trả 0.
// Loại trừ: float/double (về qua thanh ghi s/d riêng) và struct/mảng/hợp —
// cơ chế trả khác hẳn, gặp là bỏ qua cửa đó.
// Bài học từ log 1.0.5: hai hàm đang nhập trả về B và Q đã bị cổng cũ (chỉ nhận
// void) từ chối oan — đó là nguyên nhân thật của vụ từ chối ở 1.0.4, không phải
// các ký tự định tính như đã đoán trước đây.
static BOOL ZUSReturnTypeIsSafe(const char *enc) {
    if (!enc) return NO;
    char c = enc[0];
    if (c == 'r' || c == 'n' || c == 'N' || c == 'o' || c == 'O' || c == 'R' || c == 'V') c = enc[1];
    return (c == 'v' || c == 'B' || c == 'c' || c == 'C' || c == 's' || c == 'S' ||
            c == 'i' || c == 'I' || c == 'l' || c == 'L' || c == 'q' || c == 'Q' ||
            c == '@' || c == '#' || c == ':' || c == '*' || c == '^');
}

// Hàm thường (tối đa 2 tham số thật): kiểu trả về phải qua được cổng trên và
// mọi tham số đều là con trỏ/số nguyên (đi qua thanh ghi, chuyển tiếp an toàn).
static BOOL ZUSEncodingIsSafe(Method m) {
    const char *enc = method_getTypeEncoding(m);
    if (!ZUSReturnTypeIsSafe(enc)) return NO;
    unsigned argc = method_getNumberOfArguments(m);
    if (argc < 2 || argc > 4) return NO;
    for (unsigned i = 2; i < argc; i++) {
        char t[64];
        method_getArgumentType(m, i, t, sizeof(t));
        char c = t[0];
        // Bỏ qua ký tự định tính của mã kiểu (const/in/out/byref...) nếu nó đứng
        // đầu mã kiểu của tham số: chúng chỉ là chú thích, không ảnh hưởng thanh ghi.
        if (c == 'r' || c == 'n' || c == 'N' || c == 'o' || c == 'O' || c == 'R' || c == 'V') c = t[1];
        if (c == '@' || c == '#' || c == ':' || c == 'i' || c == 'I' || c == 's' || c == 'S' ||
            c == 'l' || c == 'L' || c == 'q' || c == 'Q' || c == 'c' || c == 'C' || c == 'B' ||
            c == '*' || c == '^') continue;
        return NO;
    }
    return YES;
}

// Hàm nhiều tham số (3–6): trên ARM64 tham số nguyên/con trỏ đều nằm trọn
// trong thanh ghi 64-bit nên chuyển tiếp theo từng ô nhớ là an toàn — với điều kiện
// mã kiểu KHÔNG chứa float/double/struct/mảng/hợp/bitfield. Quét toàn bộ chuỗi mã
// kiểu: chỉ cho phép các ký tự của kiểu nguyên/con trỏ/chữ ký số, cộng '?' của
// tham số block (@?) — hai cửa lớp dữ liệu có tham số hoàn-tất dạng block.
static BOOL ZUSEncodingIsSafeN(Method m, int n) {
    const char *enc = method_getTypeEncoding(m);
    if (!ZUSReturnTypeIsSafe(enc)) return NO;
    if (method_getNumberOfArguments(m) != (unsigned)(n + 2)) return NO;
    for (const char *p = enc; *p; p++) {
        char c = *p;
        if (c == 'v' || c == '@' || c == ':' || c == '#' || c == 'i' || c == 'I' ||
            c == 's' || c == 'S' || c == 'l' || c == 'L' || c == 'q' || c == 'Q' ||
            c == 'c' || c == 'C' || c == 'B' || c == '*' || c == '^' || c == '?' ||
            c == 'r' || c == 'n' || c == 'N' || c == 'o' || c == 'O' || c == 'R' || c == 'V' ||
            (c >= '0' && c <= '9')) continue;
        return NO;
    }
    return YES;
}

// ---------------- Kho bản gốc ----------------
static NSMutableDictionary *gOrigs = nil; // "khoá" -> IMP gốc
static NSMutableDictionary *gCats = nil;  // "khoá" -> nhóm (1/2)

static NSString *ZUSKeyFor(Class cls, SEL sel, BOOL isClass) {
    return [NSString stringWithFormat:@"%@%@|%@", isClass ? @"+" : @"-", NSStringFromClass(cls), NSStringFromSelector(sel)];
}

// Đi dọc chuỗi class cha để tìm bản gốc đã móc (self có thể là class con của class đã móc).
static NSMutableSet *gCalledOnce = nil; // khoá của các cửa đã ghi "lần đầu được gọi"

static void ZUSFindOrigCat(id self, SEL _cmd, void **outOrig, int *outCat, NSString **outKey) {
    *outOrig = NULL; *outCat = 0;
    if (outKey) *outKey = nil;
    BOOL meta = class_isMetaClass(object_getClass(self));
    Class walk = meta ? (Class)self : object_getClass(self);
    while (walk) {
        NSString *k = ZUSKeyFor(walk, _cmd, meta);
        NSValue *v = nil; NSNumber *c = nil;
        @synchronized (gOrigs) { v = gOrigs[k]; c = gCats[k]; }
        if (v) { *outOrig = [v pointerValue]; *outCat = [c intValue]; if (outKey) *outKey = k; return; }
        walk = class_getSuperclass(walk);
    }
}

// Ghi đúng một dòng cho lần đầu mỗi cửa thật sự được gọi trong phiên chạy này —
// bằng chứng cửa nào nằm trên luồng mở đoạn chat, kể cả khi cửa đó được chuyển tiếp.
static void ZUSNoteCalledOnce(id self, SEL _cmd, NSString *key) {
    if (!key || !gCalledOnce) return;
    BOOL first = NO;
    @synchronized (gCalledOnce) {
        if (![gCalledOnce containsObject:key]) { [gCalledOnce addObject:key]; first = YES; }
    }
    if (first) ZUSLog(@"lần đầu được gọi: %@.%@", NSStringFromClass(object_getClass(self)), NSStringFromSelector(_cmd));
}

static void ZUSNoteBlocked(id self, SEL _cmd, int cat) {
    NSString *desc = [NSString stringWithFormat:@"%@.%@", NSStringFromClass(object_getClass(self)), NSStringFromSelector(_cmd)];
    NSString *event = nil;
    // Các hàm bị móc chạy trên nhiều hàng đợi khác nhau (socket, model nhóm...):
    // bộ đếm và sự kiện gần nhất phải cập nhật trong khoá, tránh hai luồng cùng ghi.
    @synchronized (gOrigs) {
        if (cat == 1) { gBlockedRead++; gLastEvent = [NSString stringWithFormat:@"chặn đã-xem: %@", desc]; }
        else if (cat == 2) { gBlockedTyping++; gLastEvent = [NSString stringWithFormat:@"chặn đang-nhập: %@", desc]; }
        else if (cat == 3) { gBlockedDelivered++; gLastEvent = [NSString stringWithFormat:@"chặn đã-nhận: %@", desc]; }
        else { gBlockedRecall++; gLastEvent = [NSString stringWithFormat:@"chặn thu-hồi: %@", desc]; }
        event = gLastEvent;
    }
    ZUSLog(@"ĐÃ CHẶN %@", event);
    ZUSWriteDiagThrottled();
}

// Nhóm của một cửa có đang bật hay không (1.1.0: 4 nhóm).
static BOOL ZUSActiveForCat(int cat) {
    if (!gEnabled) return NO;
    switch (cat) {
        case 1: return gUnseen;
        case 2: return gHideTyping;
        case 3: return gHideDelivered;
        case 4: return gAntiRecall;
        default: return NO;
    }
}

// Riêng nhóm đã-nhận: tắt công tắc đã-nhận thì các lần gọi THUẦN đã-nhận được
// đi qua, nhưng lần gọi nào mang cờ isSeen=YES (tham số thứ hai của cả 5 cửa
// delivered) vẫn bị chặn theo nhóm đã-xem — chống lọt đã-xem qua cửa hậu.
static BOOL ZUSActiveDelivered(BOOL isSeen) {
    if (!gEnabled) return NO;
    if (gHideDelivered) return YES;
    return gUnseen && isSeen;
}

static NSString *ZUSCatLabel(int cat) {
    switch (cat) {
        case 1: return @"đã-xem";
        case 2: return @"đang-nhập";
        case 3: return @"đã-nhận";
        case 4: return @"thu-hồi";
        default: return @"?";
    }
}

// Hàm thay thế chung cho các hàm tối đa 2 tham số: bật tính năng thì chặn
// (không chạy gốc, trả 0), tắt thì chạy gốc và trả NGUYÊN giá trị gốc.
// Từ 1.0.6 mọi hàm thay thế trả long long: hàm đích trả số nguyên/BOOL/con trỏ
// đều về qua x0 nên giữ nguyên bit; hàm trả void thì nơi gọi bỏ qua x0.
// QUAN TRỌNG (gốc vụ văng 1.0.4): tham số PHẢI khai __unsafe_unretained.
// Khai `id` thường thì ARC coi chúng là strong và tự chèn objc_retain cho từng
// tham số ngay khi vào hàm — hàm đích nào có tham số là số nguyên (không phải
// object) sẽ bị retain như một địa chỉ bộ nhớ và sập ngay tại cửa, trước khi
// kịp chặn hay ghi log (đã chứng minh ở mức lệnh máy từ file .ips của 1.0.4).
static long long ZUSGenericHook(__unsafe_unretained id self, SEL _cmd, __unsafe_unretained id a1, __unsafe_unretained id a2) {
    void *orig = NULL; int cat = 0; NSString *key = nil;
    ZUSFindOrigCat(self, _cmd, &orig, &cat, &key);
    ZUSNoteCalledOnce(self, _cmd, key);
    // Cờ isSeen nằm ở byte thấp của thanh ghi tham số thứ hai. PHẢI vòng qua
    // void* trước khi ép sang số nguyên: bít-mặt-nạ trực tiếp trên con trỏ id
    // là lỗi cứng -Wdeprecated-objc-pointer-introspection trên SDK mới nhất
    // (build đầu của ZUS 1.1.0 chết đúng dòng này). Dưới ARC, phép ép id ->
    // void* bắt buộc ghi (__bridge void*) — ép trần (void*) cũng là lỗi cứng.
    void *a2Raw = (__bridge void *)a2;
    BOOL active = (cat == 3) ? ZUSActiveDelivered(((uintptr_t)a2Raw & 0xFF) != 0) : ZUSActiveForCat(cat);
    if (active) { ZUSNoteBlocked(self, _cmd, cat); return 0; }
    if (orig) return ((long long (*)(__unsafe_unretained id, SEL, __unsafe_unretained id, __unsafe_unretained id))orig)(self, _cmd, a1, a2);
    return 0;
}

// Hàm thay thế cho các hàm 5 tham số nguyên/con trỏ (sendStatusTyping trả về Q;
// từ 1.0.6 thêm cửa lớp dữ liệu 5 tham số thuộc nhóm đã-xem — điều kiện kích
// hoạt phải xét cả hai nhóm như các hàm thay thế khác, nếu chỉ xét nhóm
// đang-nhập như trước đây thì cửa đã-xem 5 tham số sẽ không bao giờ bị chặn).
static long long ZUSHook5(__unsafe_unretained id self, SEL _cmd, void *a1, void *a2, void *a3, void *a4, void *a5) {
    void *orig = NULL; int cat = 0; NSString *key = nil;
    ZUSFindOrigCat(self, _cmd, &orig, &cat, &key);
    ZUSNoteCalledOnce(self, _cmd, key);
    BOOL active = ZUSActiveForCat(cat);
    if (active) { ZUSNoteBlocked(self, _cmd, cat); return 0; }
    if (orig) return ((long long (*)(__unsafe_unretained id, SEL, void *, void *, void *, void *, void *))orig)(self, _cmd, a1, a2, a3, a4, a5);
    return 0;
}

// Hàm thay thế cho các hàm 3 tham số nguyên/con trỏ (cùng nguyên tắc thanh ghi).
static long long ZUSHook3(__unsafe_unretained id self, SEL _cmd, void *a1, void *a2, void *a3) {
    void *orig = NULL; int cat = 0; NSString *key = nil;
    ZUSFindOrigCat(self, _cmd, &orig, &cat, &key);
    ZUSNoteCalledOnce(self, _cmd, key);
    BOOL active = (cat == 3) ? ZUSActiveDelivered(((uintptr_t)a2 & 0xFF) != 0) : ZUSActiveForCat(cat);
    if (active) { ZUSNoteBlocked(self, _cmd, cat); return 0; }
    if (orig) return ((long long (*)(__unsafe_unretained id, SEL, void *, void *, void *))orig)(self, _cmd, a1, a2, a3);
    return 0;
}

// Hàm thay thế cho các hàm 4 tham số nguyên/con trỏ (gửi đang nhập ở ChatDataManager).
static long long ZUSHook4(__unsafe_unretained id self, SEL _cmd, void *a1, void *a2, void *a3, void *a4) {
    void *orig = NULL; int cat = 0; NSString *key = nil;
    ZUSFindOrigCat(self, _cmd, &orig, &cat, &key);
    ZUSNoteCalledOnce(self, _cmd, key);
    BOOL active = ZUSActiveForCat(cat);
    if (active) { ZUSNoteBlocked(self, _cmd, cat); return 0; }
    if (orig) return ((long long (*)(__unsafe_unretained id, SEL, void *, void *, void *, void *))orig)(self, _cmd, a1, a2, a3, a4);
    return 0;
}

// Hàm thay thế cho các hàm 6 tham số nguyên/con trỏ (mới ở 1.0.6, cho cửa lớp
// dữ liệu InboxDataManager.processUpdateStatusInboxEntityThreadId:msgType:
// newStatus:seenTime:updateUI:updateDB:). 6 tham số thật vẫn nằm trọn trong
// thanh ghi x2–x7; từ 7 tham số trở lên tham số tràn xuống ngăn xếp nên KHÔNG
// dùng mẫu này — đó là lý do cửa 7 tham số của InboxDataManager tạm chưa móc.
static long long ZUSHook6(__unsafe_unretained id self, SEL _cmd, void *a1, void *a2, void *a3, void *a4, void *a5, void *a6) {
    void *orig = NULL; int cat = 0; NSString *key = nil;
    ZUSFindOrigCat(self, _cmd, &orig, &cat, &key);
    ZUSNoteCalledOnce(self, _cmd, key);
    BOOL active = ZUSActiveForCat(cat);
    if (active) { ZUSNoteBlocked(self, _cmd, cat); return 0; }
    if (orig) return ((long long (*)(__unsafe_unretained id, SEL, void *, void *, void *, void *, void *, void *))orig)(self, _cmd, a1, a2, a3, a4, a5, a6);
    return 0;
}

// ---------------- Danh sách trắng (log máy thật 1.0.3 + điểm móc ZaloTools đã kiểm chứng) ----------------
// cat: 1 = đã-xem, 2 = đang-nhập. argc = số tham số thật kỳ vọng (không tính self/_cmd).
typedef struct {
    const char *cls;
    const char *sel;
    int cat;
    int argc;
} ZUSEntry;

static const ZUSEntry kZUSWhitelist[] = {
    // Lớp màn hình chat: điểm phát sinh "đã xem" khi mở đoạn chat
    { "BaseChatTVC", "sendSeenInfoInboxEntity:", 1, 1 },
    { "BaseChatTVC", "sendSeenForLastReadMessage", 1, 0 },
    { "BaseChatTVC", "sendSeenMessageWithChatEntity:", 1, 1 },
    { "BaseChatTVC", "sendSeenMessageWithTalkTableItem:", 1, 1 },
    // Lớp xử lý chat
    { "BaseChatProcessor", "sendSeenMessages:messageDict:incomingData:", 1, 3 },
    // Lớp quản lý hàng đợi + gửi "đã xem" lên máy chủ
    { "ChatSendSeenDataManager", "sendSeenWithChatEntity:", 1, 1 },
    { "ChatSendSeenDataManager", "addChatSeenWithLastChatEntity:", 1, 1 },
    { "ChatSendSeenDataManager", "_sendSeenMessageWithSeenData:messageType:", 1, 2 },
    { "ChatSendSeenDataManager", "sendSeenLastMessageWithThreadIds:withMessageType:", 1, 2 },
    { "ChatSendSeenDataManager", "sendSeenServer", 1, 0 },
    { "ChatSendSeenDataManager", "forceSendSeenServer", 1, 0 },
    { "ChatSendSeenDataManager", "sendSeenServerPeriodicallyIfNeeded", 1, 0 },
    { "ChatSendSeenDataManager", "sendAllFailedSeenMessage", 1, 0 },
    // Lớp socket: xác nhận đã nhận/đã xem đi thẳng ra đường truyền
    { "ChatSocketCmdHelper", "sendSeenChatACK:withSubCommandType:", 1, 2 },
    { "ChatSocketCmdHelper", "sendSeenGroupChatACKByData:withSubCommandType:", 1, 2 },
    { "ChatSocketCmdHelper", "sendSingleChatDeliveredMessages:isSeen:", 3, 2 },
    { "ChatSocketCmdHelper", "sendE2eeSingleChatDeliveredMessages:isSeen:", 3, 2 },
    { "ChatSocketCmdHelper", "sendGroupChatDeliveredMessages:isSeen:", 3, 2 },
    { "ChatSocketCmdHelper", "sendE2eeGroupChatDeliveredMessages:isSeen:", 3, 2 },
    { "ChatSocketCmdHelper", "sendChatDeliveredMessages:isSeen:commandType:", 3, 3 },
    // Lớp cập nhật trạng thái đã xem ngay trong máy (giữ chữ đậm trong danh sách chat)
    { "ConversationModel", "updateLastSeenWithMessage:type:", 1, 2 },
    { "ConversationModel", "_updateLastSeenWithMessage:type:", 1, 2 },
    { "ConversationModel", "updateLocalLastSeenMessageWithDelay", 1, 0 },
    { "ConversationModel", "clearMentionAndUpdateLastSeenWithDelay:", 1, 1 },
    { "ConversationModel", "setLastSeenObject:", 1, 1 },
    // Story: cập nhật trạng thái đã xem Story (tên hàm trong chính bản Zalo
    // của máy, log 1.0.3) — đi theo nhóm đã-xem.
    { "StoryManager", "updateSeenStoryStatus:", 1, 1 },
    { "StoryEntity", "updateSeen:", 1, 1 },
    // Lớp dữ liệu: ghi trạng thái đã xem thẳng vào giao diện + cơ sở dữ liệu —
    // đường rò mà log 1.0.5 đã chứng minh (cả 25 cửa trên đều chặn mà chữ vẫn
    // mất đậm). Tên hàm lấy từ danh sách ứng viên trong chính bản Zalo của máy
    // (log 1.0.3). Cửa InboxDataManager 7 tham số (processUpdateStatusInbox-
    // EntityForThreadId:globalId:clientId:messageType:newStatus:updateUI:
    // updateDB:) tạm chưa móc — xem ghi chú ở ZUSHook6.
    { "ChatDataManager", "processUpdateStatusChatSeenChatGroup:withNewStatusSeen:withUI:withDB:", 1, 4 },
    { "ChatDataFlow", "processUpdateStatusSeenChatGroup:withNewStatusSeen:withUI:withDB:", 1, 4 },
    { "InboxDataManager", "processUpdateStatusInboxEntityThreadId:msgType:withNewStatus:withUI:withDB:", 1, 5 },
    { "InboxDataManager", "processUpdateStatusInboxEntityThreadId:msgType:newStatus:seenTime:updateUI:updateDB:", 1, 6 },
    { "InboxDataManager", "processDecreaseUnreadOfThread:withType:shouldUpdateDB:shouldUpdateUI:", 1, 4 },
    { "ChatProcessor", "processResetUnreadWithSeenData:msgType:withCompletion:", 1, 3 },
    { "ChatProcessor", "processResetUnreadOfThread:msgType:msgMarker:", 1, 3 },
    { "ChatDataManager", "updateMaxSeenGlobalId:withMessageType:withCompletion:", 1, 3 },
    { "ChatDataManager", "checkSendClearUnreadType:withInboxEntity:messageType:withToUserId:", 1, 4 },
    // Chống thu hồi: chuỗi xử lý "undo" của Zalo — điểm móc lấy từ dylib của
    // ZaloTools (BVN) nhắm đúng thế hệ Zalo này (ký hiệu Logos trong dylib ghi
    // đủ class + selector + số tham số; hai mục ChatUIManager và một mục
    // UndoChatProcessor là HÀM CLASS, bộ lắp móc tự nhận diện qua metaclass).
    { "MSDataCoordinator", "handleRecallMessageNotification:", 4, 1 },
    { "MSDataCoordinator", "_handleRecallWithData:", 4, 1 },
    { "UndoChatProcessor", "updateDBUndoWithChatEntity:undoGlobalId:undoClientId:fromSrc:completion:", 4, 5 },
    { "ChatUIManager", "processUndoWithSocketChatEntity:", 4, 1 },
    { "ChatUIManager", "handleUpdateUndoWithChatEntity:fromSrc:shouldDeleteMsg:shouldRemovePage:completion:", 4, 5 },
    { "ChatEntity", "preprocessMessageUndo", 4, 0 },
    { "TalkTableItem", "updateUndoWithParser:", 4, 1 },
    // Lớp gửi "đang nhập..."
    { "ChatDataManager", "sendTypingWithType:toUserId:messageType:isE2eeChat:", 2, 4 },
    { "ChatSocketCmdHelper", "sendStatusTyping:withCommand:withSubCommand:withDestType:withGlobalMessageId:", 2, 5 },
};
static const unsigned kZUSWhitelistCount = sizeof(kZUSWhitelist) / sizeof(kZUSWhitelist[0]);

// ===== Cửa seenTime: móc RIÊNG đúng kiểu (1.1.3 bổ sung) =====
// InboxDataManager.processUpdateStatus…seenTime:… có tham số double nên bộ
// móc chung bị cổng an toàn từ chối ở mọi bản trước: cửa này không để lại
// dòng log nào và không bị chặn — đúng triệu chứng "đang mở sẵn đoạn chat,
// tin mới tới thì bị seen" mà anh gặp. Hàm thay thế khai ĐÚNG chữ ký gốc
// (double đi qua nguyên vẹn khi chuyển tiếp). Chặn khi nhóm đã-xem đang
// bật VÀ lần gọi mang mốc seenTime > 0; 10 lần gọi đầu ghi lại giá trị
// (status/seenTime/UI/DB + quyết định) để đối chiếu trên máy thật.
typedef void (*ZUSSeenTimeIMP)(__unsafe_unretained id, SEL, __unsafe_unretained id, long long, unsigned long long, double, BOOL, BOOL);
static ZUSSeenTimeIMP gZUSOrigSeenTime = NULL;
static int gZUSSeenTimeCalls = 0;

static void ZUSSeenTimeHook(__unsafe_unretained id self, SEL _cmd, __unsafe_unretained id threadId, long long msgType, unsigned long long newStatus, double seenTime, BOOL updateUI, BOOL updateDB) {
    BOOL block = ZUSActiveForCat(1) && seenTime > 0;
    if (gZUSSeenTimeCalls < 10) {
        gZUSSeenTimeCalls++;
        ZUSLog(@"cửa seenTime gọi lần %d: status=%llu seenTime=%.0f UI=%d DB=%d -> %@", gZUSSeenTimeCalls, newStatus, seenTime, updateUI, updateDB, block ? @"CHẶN" : @"cho qua");
    }
    if (block) {
        ZUSNoteBlocked(self, _cmd, 1);
        return;
    }
    if (gZUSOrigSeenTime) gZUSOrigSeenTime(self, _cmd, threadId, msgType, newStatus, seenTime, updateUI, updateDB);
}

static void ZUSInstallSeenTimeHook(Class cls, Method m, BOOL isClass) {
    if (gZUSOrigSeenTime) return;
    SEL sel = method_getName(m);
    Class target = isClass ? object_getClass(cls) : cls;
    void *orig = NULL;
    MSHookMessageEx(target, sel, (IMP)ZUSSeenTimeHook, (IMP *)&orig);
    if (!orig) {
        ZUSLog(@"móc HỎNG: %@ %@", NSStringFromClass(cls), NSStringFromSelector(sel));
        return;
    }
    gZUSOrigSeenTime = (ZUSSeenTimeIMP)orig;
    gHookedTotal++;
    ZUSLog(@"đã móc [đã-xem] %@.%@ enc=%s (móc riêng đúng kiểu — có tham số double)", NSStringFromClass(cls), NSStringFromSelector(sel), method_getTypeEncoding(m));
}

// ---------------- Lắp móc theo danh sách ----------------
static long gHookedTotal = 0;

static void ZUSInstallHook(Class cls, Method m, BOOL isClass, int cat, IMP repl) {
    SEL sel = method_getName(m);
    NSString *key = ZUSKeyFor(cls, sel, isClass);
    @synchronized (gOrigs) { if (gOrigs[key]) return; }
    Class target = isClass ? object_getClass(cls) : cls;
    void *orig = NULL;
    MSHookMessageEx(target, sel, repl, (IMP *)&orig);
    if (!orig) {
        ZUSLog(@"móc HỎNG: %@ %@", NSStringFromClass(cls), NSStringFromSelector(sel));
        return;
    }
    @synchronized (gOrigs) {
        gOrigs[key] = [NSValue valueWithPointer:orig];
        gCats[key] = @(cat);
    }
    gHookedTotal++;
    ZUSLog(@"đã móc [%@] %@.%@ enc=%s", ZUSCatLabel(cat), NSStringFromClass(cls), NSStringFromSelector(sel), method_getTypeEncoding(m));
}

static void ZUSInstallWhitelist(void) {
    for (unsigned i = 0; i < kZUSWhitelistCount; i++) {
        const ZUSEntry *e = &kZUSWhitelist[i];
        Class cls = objc_getClass(e->cls);
        if (!cls) {
            ZUSLog(@"chưa thấy class %s (mục %s)", e->cls, e->sel);
            continue;
        }
        SEL sel = sel_registerName(e->sel);
        Method m = class_getInstanceMethod(cls, sel);
        BOOL isClass = NO;
        if (!m) { m = class_getClassMethod(cls, sel); isClass = YES; }
        if (!m) {
            ZUSLog(@"không thấy hàm %s.%s", e->cls, e->sel);
            continue;
        }
        if ((int)method_getNumberOfArguments(m) - 2 != e->argc) {
            ZUSLog(@"bỏ qua (số tham số khác kỳ vọng): %s.%s", e->cls, e->sel);
            continue;
        }
        if (e->argc == 6 && strcmp(e->cls, "InboxDataManager") == 0 &&
            strcmp(e->sel, "processUpdateStatusInboxEntityThreadId:msgType:newStatus:seenTime:updateUI:updateDB:") == 0) {
            ZUSInstallSeenTimeHook(cls, m, isClass);
            continue;
        }
        BOOL safe; IMP repl;
        if (e->argc <= 2)      { safe = ZUSEncodingIsSafe(m);        repl = (IMP)ZUSGenericHook; }
        else if (e->argc == 3) { safe = ZUSEncodingIsSafeN(m, 3);    repl = (IMP)ZUSHook3; }
        else if (e->argc == 4) { safe = ZUSEncodingIsSafeN(m, 4);    repl = (IMP)ZUSHook4; }
        else if (e->argc == 5) { safe = ZUSEncodingIsSafeN(m, 5);    repl = (IMP)ZUSHook5; }
        else                   { safe = ZUSEncodingIsSafeN(m, 6);    repl = (IMP)ZUSHook6; }
        if (!safe) {
            ZUSLog(@"bỏ qua (kiểu dữ liệu không an toàn): %s.%s enc=%s", e->cls, e->sel, method_getTypeEncoding(m));
            continue;
        }
        ZUSInstallHook(cls, m, isClass, e->cat, repl);
    }
    ZUSLog(@"danh sách trắng: %u mục, đã móc tổng %ld", kZUSWhitelistCount, gHookedTotal);
    ZUSWriteSharedValue(ZUS_DIAG_CANDIDATES, @(kZUSWhitelistCount));
    ZUSWriteSharedValue(ZUS_DIAG_HOOKED, @(gHookedTotal));
    ZUSWriteSharedValue(ZUS_DIAG_SKIPPED, @((long)kZUSWhitelistCount - gHookedTotal));
    ZUSWriteSharedValue(ZUS_DIAG_SCAN, [gLogFmt stringFromDate:[NSDate date]]);
    ZUSWriteDiag();
}


// ---------------- Tính năng thêm (1.1.0 chính thức) ----------------
// Toàn bộ phần này tách rời khỏi machinery chặn: mỗi món có công tắc riêng,
// mặc định TẮT (trừ khi ghi chú khác), hỏng thì chỉ hỏng phần đó.

static NSString *ZUSReadString(NSString *key) {
    id fv = ZUSReadFilePrefs()[key];
    if ([fv isKindOfClass:[NSString class]]) return fv;
    CFPropertyListRef v = CFPreferencesCopyAppValue((__bridge CFStringRef)key, (__bridge CFStringRef)ZUS_DOMAIN);
    if (!v) return nil;
    NSString *r = nil;
    if (CFGetTypeID(v) == CFStringGetTypeID()) r = [(__bridge NSString *)v copy];
    CFRelease(v);
    return r;
}

static NSString *ZUSDocsPath(void) {
    return [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) firstObject];
}

// ----- Tải Story về máy: cho Zalo tự hiện nút lưu của chính nó -----
static BOOL (*gOrigStoryCanDownload)(__unsafe_unretained id, SEL) = NULL;
static BOOL gStoryInstalled = NO;

static BOOL ZUSStoryCanDownload(__unsafe_unretained id self, SEL _cmd) {
    if (gEnabled && gStoryDownload) return YES;
    if (gOrigStoryCanDownload) return gOrigStoryCanDownload(self, _cmd);
    return NO;
}

static void ZUSInstallStoryDownload(void) {
    if (gStoryInstalled) return;
    SEL sel = sel_registerName("isAllowDownloadCurrentStory");
    NSArray *cands = @[@"UXStoryMediaViewController", @"UXStoryMediaPage", @"UXStoryMediaObject"];
    for (NSString *name in cands) {
        Class cls = objc_getClass(name.UTF8String);
        if (!cls) continue;
        Method m = class_getInstanceMethod(cls, sel);
        if (!m) continue;
        if (!ZUSEncodingIsSafe(m)) { ZUSLog(@"tải Story: bỏ qua %@ (kiểu dữ liệu không an toàn)", name); continue; }
        MSHookMessageEx(cls, sel, (IMP)ZUSStoryCanDownload, (IMP *)&gOrigStoryCanDownload);
        if (gOrigStoryCanDownload) { gStoryInstalled = YES; ZUSLog(@"đã lắp tính năng tải Story trên %@", name); return; }
    }
    ZUSLog(@"tải Story: không thấy cửa isAllowDownloadCurrentStory trên lớp Story nào");
}

// ----- Màn chắn riêng tư khi rời tiền cảnh -----
static void ZUSShieldSet(BOOL show) {
    dispatch_async(dispatch_get_main_queue(), ^{
        NSSet *scenes = [UIApplication sharedApplication].connectedScenes;
        for (UIScene *scene in scenes) {
            if (![scene isKindOfClass:[UIWindowScene class]]) continue;
            for (UIWindow *w in [(UIWindowScene *)scene windows]) {
                UIView *old = [w viewWithTag:23126];
                if (show) {
                    if (old) { [w bringSubviewToFront:old]; continue; }
                    UIVisualEffectView *blur = [[UIVisualEffectView alloc] initWithEffect:[UIBlurEffect effectWithStyle:UIBlurEffectStyleSystemMaterial]];
                    blur.frame = w.bounds;
                    blur.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
                    blur.tag = 23126;
                    [w addSubview:blur];
                } else {
                    [old removeFromSuperview];
                }
            }
        }
    });
}

static void ZUSInstallShieldObservers(void) {
    [[NSNotificationCenter defaultCenter] addObserverForName:UIApplicationWillResignActiveNotification object:nil queue:[NSOperationQueue mainQueue] usingBlock:^(NSNotification *note) {
        if (gEnabled && gPrivacyShield) ZUSShieldSet(YES);
    }];
    [[NSNotificationCenter defaultCenter] addObserverForName:UIApplicationDidBecomeActiveNotification object:nil queue:[NSOperationQueue mainQueue] usingBlock:^(NSNotification *note) {
        ZUSShieldSet(NO);
    }];
}

// ----- Cảnh báo khi Zalo đổi phiên bản -----
static void ZUSCheckZaloVersion(void) {
    NSString *cur = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleShortVersionString"];
    if (!cur.length) return;
    NSString *last = ZUSReadString(ZUS_KEY_ZALOVER);
    if (last.length && ![last isEqualToString:cur]) {
        ZUSLog(@"Zalo vừa đổi phiên bản: %@ -> %@ — nếu có tính năng lạ, gửi log để kiểm tra lại cửa móc", last, cur);
        ZUSWriteSharedValue(ZUS_DIAG_ZALOUPD, cur);
        CFPreferencesAppSynchronize((__bridge CFStringRef)ZUS_DOMAIN);
    }
    if (![last isEqualToString:cur]) {
        ZUSWriteSharedValue(ZUS_KEY_ZALOVER, cur);
    }
}

// ----- Danh bạ: dò nguồn bạn bè trong Zalo -----
// Chưa có bản đồ lớp bạn bè của Zalo (log 1.0.3 chỉ quét luồng đã-xem), nên
// bản đầu đi đường DÒ CÓ KIỂM SOÁT: thử danh sách lớp quản lý + tên hàm lấy
// bạn bè quen thuộc, đọc trường bằng KVC với danh sách khoá ứng viên, và ghi
// log toàn bộ những gì tìm thấy. Dò không ra thì log chứa bản đồ hàm "friend"
// của các lớp ứng viên để vòng sau chốt đúng nguồn — cùng cách đã crack
// luồng đã-xem ở 1.0.5/1.0.6.
static id ZUSInstanceOf(Class cls) {
    if (!cls) return nil;
    NSArray *sels = @[@"sharedInstance", @"sharedManager", @"defaultManager", @"shared", @"defaultInstance", @"manager", @"sharedCoordinator", @"defaultCoordinator", @"coordinator", @"sharedCenter", @"defaultCenter", @"center", @"sharedDataManager", @"dataManager", @"main", @"current"];
    for (NSString *s in sels) {
        SEL sel = sel_registerName(s.UTF8String);
        if (!class_getClassMethod(cls, sel)) continue;
        @try {
            id inst = ((id (*)(id, SEL))objc_msgSend)(cls, sel);
            if (inst) return inst;
        } @catch (NSException *e) {}
    }
    return nil;
}

static NSString *ZUSStringField(id obj, NSArray *keys) {
    for (NSString *k in keys) {
        @try {
            id v = [obj valueForKey:k];
            if ([v isKindOfClass:[NSString class]] && [(NSString *)v length]) return v;
            if ([v isKindOfClass:[NSNumber class]]) return [(NSNumber *)v stringValue];
            if ([v isKindOfClass:[NSURL class]]) return [(NSURL *)v absoluteString];
        } @catch (NSException *e) {}
    }
    return @"";
}

// ===== Vòng 3: bắt thực thể quản lý bạn bè qua hàm khởi tạo =====
// Log 1.1.2 đã chứng minh: FriendFlowManager không có accessor tĩnh thường
// gặp, ChatDataManager không giữ nó qua KVC (quan hệ ngược). Đường tin cậy
// nhất còn lại: móc các hàm init của FriendFlowManager và MSDataCoordinator
// ngay từ lúc tweak nạp — Zalo tạo thực thể lúc nào, thực thể được giữ yếu
// ở đây lúc đó. Các thay thế chỉ gọi bản gốc rồi ghi lại, không đổi hành vi.
static __weak id gZUSCapFFM = nil;
static __weak id gZUSCapCoord = nil;
static BOOL gZUSCapFFMLogged = NO;
static BOOL gZUSCapCoordLogged = NO;

static void ZUSCaptureInstance(BOOL isFFM, __unsafe_unretained id obj) {
    if (!obj) return;
    if (isFFM) {
        if (gZUSCapFFM != obj) {
            gZUSCapFFM = obj;
            if (!gZUSCapFFMLogged) { gZUSCapFFMLogged = YES; ZUSLog(@"danh bạ: đã bắt được thực thể FriendFlowManager qua hàm khởi tạo"); }
        }
    } else {
        if (gZUSCapCoord != obj) {
            gZUSCapCoord = obj;
            if (!gZUSCapCoordLogged) { gZUSCapCoordLogged = YES; ZUSLog(@"danh bạ: đã bắt được thực thể MSDataCoordinator qua hàm khởi tạo"); }
        }
    }
}

typedef id (*ZUSInitIMP0)(__unsafe_unretained id, SEL);
typedef id (*ZUSInitIMP1)(__unsafe_unretained id, SEL, void *);
static ZUSInitIMP0 gZUSOrigFFMInit0 = NULL;
static ZUSInitIMP0 gZUSOrigCoordInit0 = NULL;
static ZUSInitIMP1 gZUSOrigFFMInit1 = NULL;
static ZUSInitIMP1 gZUSOrigCoordInit1 = NULL;

static id ZUSCapFFMInit0(__unsafe_unretained id self, SEL _cmd) { id r = gZUSOrigFFMInit0 ? gZUSOrigFFMInit0(self, _cmd) : self; ZUSCaptureInstance(YES, r); return r; }
static id ZUSCapCoordInit0(__unsafe_unretained id self, SEL _cmd) { id r = gZUSOrigCoordInit0 ? gZUSOrigCoordInit0(self, _cmd) : self; ZUSCaptureInstance(NO, r); return r; }
static id ZUSCapFFMInit1(__unsafe_unretained id self, SEL _cmd, void *a1) { id r = gZUSOrigFFMInit1 ? gZUSOrigFFMInit1(self, _cmd, a1) : self; ZUSCaptureInstance(YES, r); return r; }
static id ZUSCapCoordInit1(__unsafe_unretained id self, SEL _cmd, void *a1) { id r = gZUSOrigCoordInit1 ? gZUSOrigCoordInit1(self, _cmd, a1) : self; ZUSCaptureInstance(NO, r); return r; }

static void ZUSHookInitsForClass(Class cls, BOOL isFFM) {
    if (!cls) { ZUSLog(@"danh bạ: không thấy lớp %@ để móc init", isFFM ? @"FriendFlowManager" : @"MSDataCoordinator"); return; }
    unsigned int count = 0;
    Method *methods = class_copyMethodList(cls, &count);
    NSMutableArray *names = [NSMutableArray array];
    BOOL hooked0 = NO, hooked1 = NO;
    for (unsigned int i = 0; i < count; i++) {
        SEL sel = method_getName(methods[i]);
        NSString *name = NSStringFromSelector(sel);
        if (![name hasPrefix:@"init"]) continue;
        [names addObject:name];
        const char *enc = method_getTypeEncoding(methods[i]);
        if (!enc || (enc[0] != '@' && enc[0] != '#')) continue;
        if (strchr(enc, '{') || strchr(enc, '(') || strchr(enc, '[')) continue;
        unsigned nargs = method_getNumberOfArguments(methods[i]);
        if (nargs == 2 && !hooked0) {
            if (isFFM) MSHookMessageEx(cls, sel, (IMP)ZUSCapFFMInit0, (IMP *)&gZUSOrigFFMInit0);
            else MSHookMessageEx(cls, sel, (IMP)ZUSCapCoordInit0, (IMP *)&gZUSOrigCoordInit0);
            hooked0 = YES;
        } else if (nargs == 3 && !hooked1) {
            if (isFFM) MSHookMessageEx(cls, sel, (IMP)ZUSCapFFMInit1, (IMP *)&gZUSOrigFFMInit1);
            else MSHookMessageEx(cls, sel, (IMP)ZUSCapCoordInit1, (IMP *)&gZUSOrigCoordInit1);
            hooked1 = YES;
        }
    }
    if (methods) free(methods);
    if (!hooked0 && !names.count) {
        // Lớp không khai init riêng: móc -init thừa kế, chỉ áp cho lớp này.
        SEL sel = @selector(init);
        if (isFFM) { MSHookMessageEx(cls, sel, (IMP)ZUSCapFFMInit0, (IMP *)&gZUSOrigFFMInit0); hooked0 = YES; }
        else { MSHookMessageEx(cls, sel, (IMP)ZUSCapCoordInit0, (IMP *)&gZUSOrigCoordInit0); hooked0 = YES; }
    }
    ZUSLog(@"danh bạ: %@ — các hàm init: %@; đã móc bắt thực thể: %@",
           NSStringFromClass(cls),
           names.count ? [names componentsJoinedByString:@", "] : @"(không có init riêng)",
           (hooked0 || hooked1) ? @"có" : @"không");
}

static void ZUSInstallCaptureHooks(void) {
    ZUSHookInitsForClass(objc_getClass("FriendFlowManager"), YES);
    ZUSHookInitsForClass(objc_getClass("MSDataCoordinator"), NO);
}

// Dump tên + lớp của các thuộc tính CÓ giá trị của một thực thể (mỗi lớp một
// lần) — để tìm khoá giữ FriendFlowManager bên trong MSDataCoordinator.
static void ZUSDiagDumpProperties(__unsafe_unretained id obj, NSString *label) {
    if (!obj) return;
    static NSMutableSet *done = nil;
    if (!done) done = [NSMutableSet set];
    NSString *cn = NSStringFromClass([obj class]);
    if ([done containsObject:cn]) return;
    [done addObject:cn];
    unsigned int count = 0;
    objc_property_t *props = class_copyPropertyList([obj class], &count);
    NSMutableArray *parts = [NSMutableArray array];
    for (unsigned int i = 0; i < count; i++) {
        NSString *pn = @(property_getName(props[i]));
        id v = nil;
        @try { v = [obj valueForKey:pn]; } @catch (NSException *e) {}
        if (v) [parts addObject:[NSString stringWithFormat:@"%@=%@", pn, NSStringFromClass([v class])]];
        if (parts.count >= 40) break;
    }
    if (props) free(props);
    ZUSLog(@"danh bạ: thuộc tính có giá trị của %@: %@", label, [parts componentsJoinedByString:@", "]);
}

static NSDictionary *ZUSFriendDict(id f) {
    NSString *name = ZUSStringField(f, @[@"displayName", @"name", @"fullName", @"zaloName", @"username"]);
    NSString *fid  = ZUSStringField(f, @[@"userId", @"uid", @"zaloId", @"userID", @"friendId", @"id"]);
    NSString *phone = ZUSStringField(f, @[@"phoneNumber", @"phone", @"mobileNumber", @"mobile"]);
    NSString *avatar = ZUSStringField(f, @[@"avatarURL", @"avatarUrl", @"avatar", @"avatarPath", @"avatarLink"]);
    return @{@"name": name, @"id": fid, @"phone": phone, @"avatar": avatar};
}

static NSArray *ZUSFriendsFromManager(id inst, NSString *srcName) {
    if (!inst) return nil;
    NSArray *listSels = @[@"cloneFriendList", @"copySortedFriendsArray", @"copySortedNonBlockedFriendsArray", @"copyNonBlockedFriendsDictionary", @"copyZaloContactNewFriendDictionary", @"nonBlockedFriendSortedArray", @"getNewFriendArray", @"friendList", @"allFriends", @"friends", @"getFriendList", @"getAllFriends", @"listFriends", @"getFriends", @"friendArray", @"allContacts", @"contacts"];
    for (NSString *sn in listSels) {
        SEL sel = sel_registerName(sn.UTF8String);
        if (![inst respondsToSelector:sel]) continue;
        @try {
            id r = ((id (*)(id, SEL))objc_msgSend)(inst, sel);
            NSArray *arr = nil;
            if ([r isKindOfClass:[NSArray class]]) arr = r;
            else if ([r isKindOfClass:[NSSet class]]) arr = [(NSSet *)r allObjects];
            else if ([r isKindOfClass:[NSDictionary class]]) {
                NSMutableArray *flat = [NSMutableArray array];
                for (id v in [(NSDictionary *)r allValues]) {
                    if ([v isKindOfClass:[NSArray class]]) [flat addObjectsFromArray:v];
                    else if ([v isKindOfClass:[NSSet class]]) [flat addObjectsFromArray:[(NSSet *)v allObjects]];
                    else [flat addObject:v];
                }
                arr = flat;
            }
            if (arr.count) {
                ZUSLog(@"danh bạ: lấy được %lu bạn từ %@.%@", (unsigned long)arr.count, srcName, sn);
                ZUSWriteSharedValue(ZUS_DIAG_FRIENDSRC, [NSString stringWithFormat:@"%@.%@", srcName, sn]);
                return arr;
            }
            if (r) ZUSLog(@"danh bạ: %@.%@ có tồn tại nhưng trả về %@ (rỗng hoặc chưa sẵn sàng)", srcName, sn, NSStringFromClass([r class]));
        } @catch (NSException *e) {}
    }
    return nil;
}

static NSArray *ZUSCollectFriends(void) {
    // Vòng 3 (1.1.3): bám thực thể BẮT ĐƯỢC qua init trước (tin cậy nhất),
    // rồi accessor tĩnh nới rộng, rồi MSDataCoordinator (dump thuộc tính +
    // KVC nhiều khoá), cuối cùng mới là các đường cũ của vòng 1–2.
    Class ffmCls = objc_getClass("FriendFlowManager");
    if (gZUSCapFFM) {
        NSArray *r = ZUSFriendsFromManager(gZUSCapFFM, @"FriendFlowManager(bắt qua init)");
        if (r) return r;
    }
    if (ffmCls) {
        id inst = ZUSInstanceOf(ffmCls);
        if (inst) {
            NSArray *r = ZUSFriendsFromManager(inst, @"FriendFlowManager");
            if (r) return r;
        } else {
            ZUSLog(@"danh bạ: không lấy được thực thể FriendFlowManager qua các hàm shared thường gặp");
        }
    }
    Class coordCls = objc_getClass("MSDataCoordinator");
    id coord = gZUSCapCoord;
    if (!coord && coordCls) coord = ZUSInstanceOf(coordCls);
    if (coord) {
        ZUSDiagDumpProperties(coord, @"MSDataCoordinator");
        for (NSString *key in @[@"friendFlowManager", @"friendManager", @"friendFlowMgr", @"friendMgr", @"flowManager", @"friendFlow", @"ffManager", @"friendsManager"]) {
            id sub = nil;
            @try { sub = [coord valueForKey:key]; } @catch (NSException *e) {}
            if (sub) {
                NSArray *r = ZUSFriendsFromManager(sub, [@"MSDataCoordinator." stringByAppendingString:key]);
                if (r) return r;
            }
        }
        NSArray *r = ZUSFriendsFromManager(coord, @"MSDataCoordinator");
        if (r) return r;
    }
    for (NSString *hostName in @[@"ChatDataManager", @"MSDataCoordinator"]) {
        Class hostCls = objc_getClass(hostName.UTF8String);
        if (!hostCls) continue;
        id host = ZUSInstanceOf(hostCls);
        if (!host) continue;
        id ffm = nil;
        @try { ffm = [host valueForKey:@"friendFlowManager"]; } @catch (NSException *e) {}
        if (!ffm) { @try { ffm = [host valueForKey:@"friendManager"]; } @catch (NSException *e) {} }
        if (ffm) {
            NSArray *r = ZUSFriendsFromManager(ffm, [hostName stringByAppendingString:@".friendFlowManager"]);
            if (r) return r;
        } else {
            ZUSLog(@"danh bạ: %@ không lộ friendFlowManager qua KVC", hostName);
        }
    }
    // Dự phòng: quét chung các lớp quản lý như vòng 1.
    NSArray *classNames = @[@"FriendDataManager", @"FriendFlowManager", @"FriendRequestManager", @"FriendManager", @"ZAFriendManager", @"MSDataCoordinator", @"ChatDataManager"];
    for (NSString *cn in classNames) {
        Class cls = objc_getClass(cn.UTF8String);
        if (!cls) continue;
        id inst = ZUSInstanceOf(cls);
        if (!inst) continue;
        NSArray *r = ZUSFriendsFromManager(inst, cn);
        if (r) return r;
    }
    ZUSLog(@"danh bạ: chưa dò được nguồn bạn bè — bản đồ hàm friend của các lớp ứng viên:");
    for (NSString *cn in classNames) {
        Class cls = objc_getClass(cn.UTF8String);
        if (!cls) continue;
        unsigned n = 0; Method *list = class_copyMethodList(cls, &n);
        NSMutableArray *names = [NSMutableArray array];
        for (unsigned i = 0; i < n; i++) {
            NSString *mn = NSStringFromSelector(method_getName(list[i]));
            if ([mn.lowercaseString containsString:@"friend"]) [names addObject:mn];
        }
        free(list);
        if (names.count) ZUSLog(@"danh bạ: %@ có các hàm friend: %@", cn, [names componentsJoinedByString:@", "]);
    }
    // Bản đồ hàm LỚP (nơi accessor tĩnh thật sự sống) của hai lớp trọng điểm.
    for (NSString *cn in @[@"FriendFlowManager", @"MSDataCoordinator"]) {
        Class cls = objc_getClass(cn.UTF8String);
        if (!cls) continue;
        unsigned n = 0; Method *list = class_copyMethodList(object_getClass(cls), &n);
        NSMutableArray *names = [NSMutableArray array];
        for (unsigned i = 0; i < n; i++) [names addObject:NSStringFromSelector(method_getName(list[i]))];
        free(list);
        if (names.count) ZUSLog(@"danh bạ: hàm lớp của %@: %@", cn, [names componentsJoinedByString:@", "]);
    }
    return nil;
}

static NSString *ZUSCSVEscape(NSString *s) {
    if (![s containsString:@","] && ![s containsString:@"\""] && ![s containsString:@"\n"]) return s;
    return [NSString stringWithFormat:@"\"%@\"", [s stringByReplacingOccurrencesOfString:@"\"" withString:@"\"\""]];
}

static NSString *ZUSBackupContacts(void) {
    NSArray *raw = ZUSCollectFriends();
    if (!raw.count) return @"Chưa dò được danh sách bạn bè trong Zalo. Bật 'Ghi log gỡ lỗi', thử lại rồi gửi file ZUS.log — trong log có bản đồ hàm bạn bè để em chốt đúng nguồn cho vòng sau.";
    NSMutableArray *friends = [NSMutableArray array];
    for (id f in raw) {
        NSDictionary *d = ZUSFriendDict(f);
        if ([d[@"id"] length] || [d[@"name"] length]) [friends addObject:d];
    }
    if (!friends.count && raw.count) {
        // Lấy được danh sách nhưng trích trường ra rỗng: ghi lại lớp và
        // thuộc tính của phần tử đầu để vòng sau chốt đúng tên trường.
        id f0 = raw[0];
        NSMutableArray *props = [NSMutableArray array];
        unsigned pc = 0; objc_property_t *pl = class_copyPropertyList([f0 class], &pc);
        for (unsigned i = 0; i < pc; i++) [props addObject:@(property_getName(pl[i]))];
        free(pl);
        ZUSLog(@"danh bạ: lấy được %lu phần tử (lớp %@) nhưng trích tên/mã đều rỗng — thuộc tính của phần tử: %@", (unsigned long)raw.count, NSStringFromClass([f0 class]), [props componentsJoinedByString:@", "]);
    }
    NSString *docs = ZUSDocsPath();
    NSData *json = [NSJSONSerialization dataWithJSONObject:friends options:NSJSONWritingPrettyPrinted error:nil];
    [json writeToFile:[docs stringByAppendingPathComponent:@"ZUS-Contacts.json"] atomically:YES];
    NSMutableString *csv = [NSMutableString stringWithString:@"name,zalo_id,phone,avatar\n"];
    for (NSDictionary *d in friends)
        [csv appendFormat:@"%@,%@,%@,%@\n", ZUSCSVEscape(d[@"name"]), ZUSCSVEscape(d[@"id"]), ZUSCSVEscape(d[@"phone"]), ZUSCSVEscape(d[@"avatar"])];
    [csv writeToFile:[docs stringByAppendingPathComponent:@"ZUS-Contacts.csv"] atomically:YES encoding:NSUTF8StringEncoding error:nil];
    NSMutableString *vcf = [NSMutableString string];
    for (NSDictionary *d in friends) {
        if (![d[@"name"] length]) continue;
        [vcf appendFormat:@"BEGIN:VCARD\nVERSION:3.0\nFN:%@\n", d[@"name"]];
        if ([d[@"phone"] length]) [vcf appendFormat:@"TEL;TYPE=CELL:%@\n", d[@"phone"]];
        if ([d[@"id"] length]) [vcf appendFormat:@"NOTE:Mã Zalo: %@\n", d[@"id"]];
        [vcf appendString:@"END:VCARD\n"];
    }
    [vcf writeToFile:[docs stringByAppendingPathComponent:@"ZUS-Contacts.vcf"] atomically:YES encoding:NSUTF8StringEncoding error:nil];
    ZUSWriteSharedValue(ZUS_DIAG_FRIENDS, @(friends.count));
    ZUSLog(@"danh bạ: đã sao lưu %lu bạn vào Documents của Zalo (ZUS-Contacts.json/.csv/.vcf)", (unsigned long)friends.count);
    return [NSString stringWithFormat:@"Đã sao lưu %lu bạn bè vào thư mục Documents của Zalo:\nZUS-Contacts.json (cho khôi phục)\nZUS-Contacts.csv (mở bằng Excel)\nZUS-Contacts.vcf (đưa vào Danh bạ máy)", (unsigned long)friends.count];
}

static NSArray *ZUSMissingFriends(void) {
    NSString *path = [ZUSDocsPath() stringByAppendingPathComponent:@"ZUS-Contacts.json"];
    NSData *data = [NSData dataWithContentsOfFile:path];
    if (!data) return nil;
    NSArray *backup = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
    if (![backup isKindOfClass:[NSArray class]]) return nil;
    NSArray *raw = ZUSCollectFriends();
    NSMutableSet *current = [NSMutableSet set];
    for (id f in raw) {
        NSString *fid = ZUSFriendDict(f)[@"id"];
        if (fid.length) [current addObject:fid];
    }
    NSMutableArray *missing = [NSMutableArray array];
    for (NSDictionary *d in backup) {
        NSString *fid = d[@"id"];
        if (fid.length && ![current containsObject:fid]) [missing addObject:d];
    }
    return missing;
}

@interface ZUSMissingFriendsController : UITableViewController
@property (nonatomic, strong) NSArray *zusMissing;
@end

@implementation ZUSMissingFriendsController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"Bạn bè đã mất khỏi danh bạ";
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return (NSInteger)self.zusMissing.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"zm"];
    if (!cell) cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:@"zm"];
    NSDictionary *d = self.zusMissing[(NSUInteger)indexPath.row];
    cell.textLabel.text = [d[@"name"] length] ? d[@"name"] : d[@"id"];
    NSMutableArray *parts = [NSMutableArray array];
    if ([d[@"phone"] length]) [parts addObject:d[@"phone"]];
    if ([d[@"id"] length]) [parts addObject:[NSString stringWithFormat:@"Mã Zalo: %@", d[@"id"]]];
    cell.detailTextLabel.text = [parts componentsJoinedByString:@" • "];
    return cell;
}

- (NSString *)tableView:(UITableView *)tableView titleForFooterInSection:(NSInteger)section {
    return @"Chạm vào một người: có số điện thoại thì mở trang Zalo của họ để kết bạn lại; chỉ có mã thì chép mã để tìm.";
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    NSDictionary *d = self.zusMissing[(NSUInteger)indexPath.row];
    NSString *phone = d[@"phone"];
    if (phone.length) {
        NSString *clean = [[phone componentsSeparatedByCharactersInSet:[[NSCharacterSet decimalDigitCharacterSet] invertedSet]] componentsJoinedByString:@""];
        NSURL *url = [NSURL URLWithString:[NSString stringWithFormat:@"https://zalo.me/%@", clean]];
        [[UIApplication sharedApplication] openURL:url options:@{} completionHandler:nil];
    } else {
        [UIPasteboard generalPasteboard].string = d[@"id"];
        UIAlertController *a = [UIAlertController alertControllerWithTitle:@"Đã chép mã Zalo" message:@"Dán mã này vào ô tìm kiếm của Zalo để tìm và kết bạn lại." preferredStyle:UIAlertControllerStyleAlert];
        [a addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil]];
        [self presentViewController:a animated:YES completion:nil];
    }
}

@end

// ----- Hồ sơ ZUS: xuất/nhập toàn bộ công tắc -----
static NSArray *ZUSAllPrefKeys(void) {
    return @[ZUS_KEY_ENABLED, ZUS_KEY_UNSEEN, ZUS_KEY_DELIVERED, ZUS_KEY_TYPING, ZUS_KEY_ANTIRECALL,
             ZUS_KEY_AWAKE, ZUS_KEY_INAPP, ZUS_KEY_DEBUG, ZUS_KEY_STORYDL, ZUS_KEY_SHIELD];
}

static NSString *ZUSExportProfile(void) {
    NSMutableDictionary *prof = [NSMutableDictionary dictionary];
    for (NSString *k in ZUSAllPrefKeys()) prof[k] = @(ZUSReadBool(k, NO));
    prof[@"_app"] = @"ZUS";
    prof[@"_version"] = @"1.1.3";
    NSData *json = [NSJSONSerialization dataWithJSONObject:prof options:NSJSONWritingPrettyPrinted error:nil];
    NSString *path = [ZUSDocsPath() stringByAppendingPathComponent:@"ZUS-Profile.json"];
    return [json writeToFile:path atomically:YES] ? path : nil;
}

static NSString *ZUSImportProfile(void) {
    NSString *path = [ZUSDocsPath() stringByAppendingPathComponent:@"ZUS-Profile.json"];
    NSData *data = [NSData dataWithContentsOfFile:path];
    if (!data) return @"Chưa có file ZUS-Profile.json trong Documents của Zalo. Hãy 'Xuất hồ sơ ZUS' trước, hoặc chép file hồ sơ vào đó.";
    NSDictionary *prof = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
    if (![prof isKindOfClass:[NSDictionary class]]) return @"File hồ sơ không đọc được (không phải JSON hợp lệ).";
    int applied = 0;
    for (NSString *k in ZUSAllPrefKeys()) {
        id v = prof[k];
        if ([v isKindOfClass:[NSNumber class]]) { ZUSSetPrefBool(k, [v boolValue]); applied++; }
    }
    ZUSLoadPrefs();
    ZUSApplyAwake();
    return [NSString stringWithFormat:@"Đã nhập hồ sơ: áp dụng %d công tắc.", applied];
}

// ---------------- Cửa cài đặt ngay trong Zalo ----------------
// Lớp giao diện viết riêng của tweak (không dùng class nào của Zalo ngoài
// BaseChatTVC làm điểm bám): nút tròn "ZUS" ở góc màn hình chat mở bảng công
// tắc dưới đây. Bảng ghi cùng kho prefs + phát cùng thông báo Darwin như
// trang Cài đặt của máy, nên gạt trong Zalo là tweak ăn ngay. Toàn bộ phần
// này tách rời khỏi machinery chặn: lỗi ở đây thì tối đa là mất nút.

static NSArray *ZUSSettingRows(void) {
    static NSArray *rows = nil;
    if (!rows) rows = @[
        @[@"Bật ZUS", ZUS_KEY_ENABLED, @YES],
        @[@"Chặn “đã xem” khi đọc tin", ZUS_KEY_UNSEEN, @YES],
        @[@"Chặn “đã nhận”", ZUS_KEY_DELIVERED, @YES],
        @[@"Tắt “đang nhập...”", ZUS_KEY_TYPING, @YES],
        @[@"Chống thu hồi tin nhắn", ZUS_KEY_ANTIRECALL, @YES],
        @[@"Giữ màn hình sáng khi dùng Zalo", ZUS_KEY_AWAKE, @NO],
        @[@"Nút cài đặt trong Zalo", ZUS_KEY_INAPP, @YES],
        @[@"Ấn giữ thanh tab mở bảng ZUS", ZUS_KEY_LONGTAB, @YES],
        @[@"Tải Story về máy", ZUS_KEY_STORYDL, @NO],
        @[@"Che nội dung khi thoát ra đa nhiệm", ZUS_KEY_SHIELD, @NO],
        @[@"Ghi log gỡ lỗi", ZUS_KEY_DEBUG, @YES],
    ];
    return rows;
}

static id ZUSDiagRead(NSString *key) {
    CFPropertyListRef v = CFPreferencesCopyAppValue((__bridge CFStringRef)key, (__bridge CFStringRef)ZUS_DOMAIN);
    return (__bridge_transfer id)v;
}

@interface ZUSSettingsController : UIViewController <UITableViewDataSource, UITableViewDelegate>
@property (nonatomic, strong) UITableView *zusTV;
@end

@implementation ZUSSettingsController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"ZUS";
    self.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:@"Xong" style:UIBarButtonItemStyleDone target:self action:@selector(zu_done)];
    UITableView *tv = [[UITableView alloc] initWithFrame:self.view.bounds style:UITableViewStyleGrouped];
    tv.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    tv.dataSource = self;
    tv.delegate = self;
    [self.view addSubview:tv];
    self.zusTV = tv;
}

- (void)zu_done {
    [self dismissViewControllerAnimated:YES completion:nil];
}

- (void)zu_switchChanged:(UISwitch *)sender {
    NSArray *row = ZUSSettingRows()[(NSUInteger)sender.tag];
    ZUSSetPrefBool(row[1], sender.on);
}

- (void)zu_showDiag {
    NSNumber *cand = ZUSDiagRead(ZUS_DIAG_CANDIDATES);
    NSNumber *hooked = ZUSDiagRead(ZUS_DIAG_HOOKED);
    NSNumber *skipped = ZUSDiagRead(ZUS_DIAG_SKIPPED);
    NSNumber *blockedRead = ZUSDiagRead(ZUS_DIAG_BLOCKED_READ);
    NSNumber *blockedType = ZUSDiagRead(ZUS_DIAG_BLOCKED_TYPE);
    NSNumber *blockedDeliv = ZUSDiagRead(ZUS_DIAG_BLOCKED_DELIV);
    NSNumber *blockedRecall = ZUSDiagRead(ZUS_DIAG_BLOCKED_RECALL);
    NSString *last = ZUSDiagRead(ZUS_DIAG_LAST);
    NSString *scan = ZUSDiagRead(ZUS_DIAG_SCAN);
    NSString *ctor = ZUSDiagRead(ZUS_DIAG_CTOR);
    NSNumber *friends = ZUSDiagRead(ZUS_DIAG_FRIENDS);
    NSString *friendsrc = ZUSDiagRead(ZUS_DIAG_FRIENDSRC);
    NSString *msg;
    if (!cand && !hooked) {
        msg = ctor.length
            ? [NSString stringWithFormat:@"Tweak ĐÃ nạp vào Zalo lúc %@ nhưng chưa quét được dữ liệu.\n\nVào một đoạn chat bất kỳ, đợi vài giây rồi kiểm tra lại.", ctor]
            : @"Tweak CHƯA từng nạp vào Zalo (không có mốc nạp).";
    } else {
        msg = [NSString stringWithFormat:
            @"Đã nạp vào Zalo: %@\nLần quét gần nhất: %@\nỨng viên tìm thấy: %@\nĐã móc thành công: %@\nBỏ qua (kiểu dữ liệu không an toàn): %@\nĐã chặn 'đã xem': %@ lần\nĐã chặn 'đang nhập': %@ lần\nĐã chặn 'đã nhận': %@ lần\nĐã chặn 'thu hồi': %@ lần\nSự kiện gần nhất: %@\nBạn bè đã sao lưu: %@ (nguồn: %@)",
            ctor.length ? ctor : @"—", scan ?: @"—", cand ?: @0, hooked ?: @0, skipped ?: @0,
            blockedRead ?: @0, blockedType ?: @0, blockedDeliv ?: @0, blockedRecall ?: @0,
            last.length ? last : @"—", friends ?: @0, friendsrc.length ? friendsrc : @"—"];
    }
    UIAlertController *a = [UIAlertController alertControllerWithTitle:@"Trạng thái dò" message:msg preferredStyle:UIAlertControllerStyleAlert];
    [a addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil]];
    [self presentViewController:a animated:YES completion:nil];
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 3;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    if (section == 0) return (NSInteger)ZUSSettingRows().count;
    if (section == 1) return 4;
    return 1;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    if (section == 0) return @"Cài đặt";
    if (section == 1) return @"Danh bạ & hồ sơ";
    return nil;
}

- (NSString *)tableView:(UITableView *)tableView titleForFooterInSection:(NSInteger)section {
    return section == 2 ? @"ZUS 1.1.3 • Thay đổi ăn ngay, không cần mở lại Zalo." : nil;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    if (indexPath.section == 0) {
        UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"zus"];
        if (!cell) cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@"zus"];
        NSArray *row = ZUSSettingRows()[(NSUInteger)indexPath.row];
        cell.textLabel.text = row[0];
        UISwitch *sw = [[UISwitch alloc] initWithFrame:CGRectZero];
        sw.tag = indexPath.row;
        sw.on = ZUSReadBool(row[1], [row[2] boolValue]);
        [sw addTarget:self action:@selector(zu_switchChanged:) forControlEvents:UIControlEventValueChanged];
        cell.accessoryView = sw;
        cell.accessoryType = UITableViewCellAccessoryNone;
        cell.selectionStyle = UITableViewCellSelectionStyleNone;
        return cell;
    }
    if (indexPath.section == 1) {
        UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"zusa"];
        if (!cell) cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@"zusa"];
        NSArray *acts = @[@"Sao lưu danh bạ Zalo", @"Khôi phục danh bạ (đối chiếu)", @"Xuất hồ sơ ZUS", @"Nhập hồ sơ ZUS"];
        cell.textLabel.text = acts[(NSUInteger)indexPath.row];
        cell.accessoryView = nil;
        cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
        cell.selectionStyle = UITableViewCellSelectionStyleDefault;
        return cell;
    }
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"zud"];
    if (!cell) cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@"zud"];
    cell.textLabel.text = @"Xem trạng thái dò";
    cell.accessoryView = nil;
    cell.selectionStyle = UITableViewCellSelectionStyleDefault;
    return cell;
}

- (void)zus_showMessage:(NSString *)msg {
    UIAlertController *a = [UIAlertController alertControllerWithTitle:@"ZUS" message:msg preferredStyle:UIAlertControllerStyleAlert];
    [a addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil]];
    [self presentViewController:a animated:YES completion:nil];
}

- (void)zus_backupContacts {
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
        NSString *summary = ZUSBackupContacts();
        dispatch_async(dispatch_get_main_queue(), ^{ [self zus_showMessage:summary]; });
    });
}

- (void)zus_restoreContacts {
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
        NSArray *missing = ZUSMissingFriends();
        dispatch_async(dispatch_get_main_queue(), ^{
            if (!missing) { [self zus_showMessage:@"Chưa có file sao lưu ZUS-Contacts.json trong Documents của Zalo. Hãy 'Sao lưu danh bạ Zalo' trước."]; return; }
            if (!missing.count) { [self zus_showMessage:@"Danh bạ hiện tại khớp hoàn toàn với bản sao lưu — không thiếu ai."]; return; }
            ZUSMissingFriendsController *vc = [[ZUSMissingFriendsController alloc] initWithStyle:UITableViewStyleGrouped];
            vc.zusMissing = missing;
            [self.navigationController pushViewController:vc animated:YES];
        });
    });
}

- (void)zus_exportProfile {
    NSString *path = ZUSExportProfile();
    if (!path) { [self zus_showMessage:@"Xuất hồ sơ không thành công."]; return; }
    UIActivityViewController *av = [[UIActivityViewController alloc] initWithActivityItems:@[[NSURL fileURLWithPath:path]] applicationActivities:nil];
    [self presentViewController:av animated:YES completion:nil];
}

- (void)zus_importProfile {
    NSString *summary = ZUSImportProfile();
    [self.zusTV reloadData];
    [self zus_showMessage:summary];
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    if (indexPath.section == 1) {
        switch (indexPath.row) {
            case 0: [self zus_backupContacts]; break;
            case 1: [self zus_restoreContacts]; break;
            case 2: [self zus_exportProfile]; break;
            case 3: [self zus_importProfile]; break;
        }
    } else if (indexPath.section == 2) {
        [self zu_showDiag];
    }
}

@end

@interface ZUSInAppHandler : NSObject
- (void)zu_openSettings:(id)sender;
- (void)zu_openSettingsFromGesture:(UILongPressGestureRecognizer *)g;
@end

@implementation ZUSInAppHandler

- (void)zu_openSettings:(id)sender {
    UIResponder *r = (UIResponder *)sender;
    UIViewController *vc = nil;
    while (r) {
        if ([r isKindOfClass:[UIViewController class]]) { vc = (UIViewController *)r; break; }
        r = [r nextResponder];
    }
    if (!vc) return;
    while (vc.presentedViewController) vc = vc.presentedViewController;
    ZUSSettingsController *panel = [[ZUSSettingsController alloc] init];
    UINavigationController *nav = [[UINavigationController alloc] initWithRootViewController:panel];
    [vc presentViewController:nav animated:YES completion:nil];
}

// 1.1.1 (anh chốt): ấn giữ trên thanh tab dưới đáy Zalo cũng mở bảng này.
// Chỉ chạy ở trạng thái Began (một lần mỗi lần ấn giữ), rung nhẹ xác nhận,
// và tự nạp lại cài đặt ngay trước khi quyết định — công tắc đã tắt là
// ấn giữ không làm gì cả.
- (void)zu_openSettingsFromGesture:(UILongPressGestureRecognizer *)g {
    if (g.state != UIGestureRecognizerStateBegan) return;
    ZUSLoadPrefs();
    if (!gLongPressTab) return;
    UIImpactFeedbackGenerator *fb = [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleMedium];
    [fb impactOccurred];
    UIResponder *r = (UIResponder *)g.view;
    UIViewController *vc = nil;
    while (r) {
        if ([r isKindOfClass:[UIViewController class]]) { vc = (UIViewController *)r; break; }
        r = [r nextResponder];
    }
    if (!vc) return;
    while (vc.presentedViewController) vc = vc.presentedViewController;
    ZUSSettingsController *panel = [[ZUSSettingsController alloc] init];
    UINavigationController *nav = [[UINavigationController alloc] initWithRootViewController:panel];
    [vc presentViewController:nav animated:YES completion:nil];
}

@end

static void (*gOrigChatAppear)(__unsafe_unretained id, SEL, BOOL) = NULL;
static BOOL gInAppInstalled = NO;
static ZUSInAppHandler *gInAppHandler = nil;
static void ZUSInstallTabBarGesture(void);

// Điểm bám duy nhất vào giao diện Zalo: viewWillAppear: của lớp màn hình chat.
// LUÔN chạy bản gốc trước; phần thêm nút bọc try/catch, tắt công tắc thì gỡ nút.
static void ZUSChatViewWillAppear(__unsafe_unretained id self, SEL _cmd, BOOL animated) {
    if (gOrigChatAppear) gOrigChatAppear(self, _cmd, animated);
    ZUSLoadPrefs();
    ZUSApplyAwake();
    ZUSInstallTabBarGesture();
    @try {
        UIViewController *vc = (UIViewController *)self;
        UIView *v = vc.view;
        if (!v) return;
        UIView *existing = [v viewWithTag:23125]; // "ZUS"
        if (!gInAppUI) { [existing removeFromSuperview]; return; } // 1.1.2: nút là lối vào cài đặt — luôn hiện kể cả khi tổng tắt, kẻo lỡ tắt là khoá ngoài
        if (existing) return;
        if (!gInAppHandler) gInAppHandler = [[ZUSInAppHandler alloc] init];
        UIButton *b = [UIButton buttonWithType:UIButtonTypeSystem];
        b.tag = 23125;
        [b setTitle:@"ZUS" forState:UIControlStateNormal];
        [b setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
        b.titleLabel.font = [UIFont boldSystemFontOfSize:13];
        b.backgroundColor = [[UIColor blackColor] colorWithAlphaComponent:0.45];
        b.layer.cornerRadius = 22;
        b.layer.masksToBounds = YES;
        b.frame = CGRectMake(v.bounds.size.width - 56, v.bounds.size.height - 150, 44, 44);
        b.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleTopMargin;
        [b addTarget:gInAppHandler action:@selector(zu_openSettings:) forControlEvents:UIControlEventTouchUpInside];
        [v addSubview:b];
    } @catch (NSException *e) {
        ZUSLog(@"lỗi khi thêm nút trong Zalo: %@", e.name);
    }
}

static void ZUSInstallInAppButton(void) {
    if (gInAppInstalled) return;
    Class cls = objc_getClass("BaseChatTVC");
    if (!cls) { ZUSLog(@"không thấy BaseChatTVC — không lắp nút trong Zalo"); return; }
    SEL sel = @selector(viewWillAppear:);
    Method m = class_getInstanceMethod(cls, sel);
    if (!m || !ZUSEncodingIsSafe(m)) { ZUSLog(@"không lắp nút trong Zalo (viewWillAppear: không đạt cổng kiểm tra)"); return; }
    MSHookMessageEx(cls, sel, (IMP)ZUSChatViewWillAppear, (IMP *)&gOrigChatAppear);
    if (gOrigChatAppear) { gInAppInstalled = YES; ZUSLog(@"đã lắp nút cài đặt trong màn hình chat"); }
    else ZUSLog(@"lắp nút trong Zalo HỎNG");
}

// ---------------- Điểm vào ----------------

// ----- Ấn giữ thanh tab mở bảng ZUS (1.1.1, anh chốt thay lối vào chính) -----
// Không móc hàm nào của Zalo: chỉ gắn UILongPressGestureRecognizer vào
// UITabBar. Tìm thanh theo hai đường: UITabBarController gốc trước, dự phòng
// quét cây view của cửa sổ chính (dùng ngăn xếp tường minh, KHÔNG đệ quy
// bằng block). Không thấy UITabBar (Zalo tự vẽ thanh riêng) thì ghi log cấu
// trúc cửa sổ để vòng sau bám đúng — tuyệt đối không gắn bừa vào view lạ.
static BOOL gTabGestureInstalled = NO;
static void ZUSInstallTabBarGesture(void) {
    if (gTabGestureInstalled) return;
    if (!gLongPressTab) return; // 1.1.2: không còn cổng công tắc tổng — ấn giữ là lối vào, phải gắn cả khi tweak đang tắt
    @try {
        UIWindow *win = nil;
        for (UIScene *scene in [UIApplication sharedApplication].connectedScenes) {
            if (![scene isKindOfClass:[UIWindowScene class]]) continue;
            for (UIWindow *w in ((UIWindowScene *)scene).windows) if (w.isKeyWindow) { win = w; break; }
            if (win) break;
        }
        if (!win) return; // giao diện chưa lên — lần mở chat / hẹn giờ sau sẽ gắn tiếp
        UITabBar *tabBar = nil;
        NSString *how = nil;
        UIViewController *root = win.rootViewController;
        if ([root isKindOfClass:[UITabBarController class]]) {
            tabBar = ((UITabBarController *)root).tabBar;
            how = @"UITabBarController gốc";
        }
        if (!tabBar) {
            NSMutableArray *stack = [NSMutableArray arrayWithObject:win];
            while (stack.count) {
                UIView *v = stack.lastObject;
                [stack removeLastObject];
                if ([v isKindOfClass:[UITabBar class]]) { tabBar = (UITabBar *)v; how = @"quét cây view"; break; }
                for (UIView *sub in v.subviews) [stack addObject:sub];
            }
        }
        if (!tabBar) {
            NSMutableArray *names = [NSMutableArray array];
            if (root.view) for (UIView *sub in root.view.subviews)
                [names addObject:[NSString stringWithFormat:@"%@(y=%.0f,h=%.0f)", NSStringFromClass([sub class]), sub.frame.origin.y, sub.frame.size.height]];
            ZUSLog(@"ấn-giữ tab: chưa thấy UITabBar (gốc=%@) — các view con của view gốc: %@", NSStringFromClass([root class]), [names componentsJoinedByString:@", "]);
            return;
        }
        if (!gInAppHandler) gInAppHandler = [[ZUSInAppHandler alloc] init];
        UILongPressGestureRecognizer *lp = [[UILongPressGestureRecognizer alloc] initWithTarget:gInAppHandler action:@selector(zu_openSettingsFromGesture:)];
        lp.minimumPressDuration = 0.5;
        lp.cancelsTouchesInView = YES; // ấn giữ ăn luôn cái chạm — không nhảy tab
        [tabBar addGestureRecognizer:lp];
        gTabGestureInstalled = YES;
        ZUSLog(@"đã gắn ấn-giữ mở bảng ZUS vào thanh tab (%@, lớp %@)", how, NSStringFromClass([tabBar class]));
    } @catch (NSException *e) {
        ZUSLog(@"lỗi khi gắn ấn-giữ thanh tab: %@", e.name);
    }
}

%ctor {
    @autoreleasepool {
        gOrigs = [[NSMutableDictionary alloc] init];
        gCats = [[NSMutableDictionary alloc] init];
        gCalledOnce = [[NSMutableSet alloc] init];
        gLogLock = [[NSObject alloc] init];
        gLogFmt = [[NSDateFormatter alloc] init];
        gLogFmt.dateFormat = @"MM-dd HH:mm:ss";
        NSString *docs = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) firstObject];
        gLogPath = [docs stringByAppendingPathComponent:@"ZUS.log"];
        ZUSLoadPrefs();
        ZUSApplyAwake();
        CFNotificationCenterAddObserver(CFNotificationCenterGetDarwinNotifyCenter(), NULL, ZUSPrefsChanged,
                                        ZUS_NOTIFY, NULL, CFNotificationSuspensionBehaviorDeliverImmediately);
        ZUSInstallShieldObservers();
        ZUSInstallCaptureHooks();
        ZUSLog(@"ZUS 1.1.3 nạp vào Zalo (bật=%d, unseen=%d, ẩn đang nhập=%d)", gEnabled, gUnseen, gHideTyping);
        {
            NSDictionary *fp0 = ZUSReadFilePrefs();
            id fe0 = fp0[ZUS_KEY_ENABLED];
            ZUSLog(@"nguồn cài đặt: file chung %@, khoá bật trong file: %@, hiệu lực bật=%d", fp0 ? @"đọc được" : @"KHÔNG đọc được", fe0 ? [fe0 description] : @"(chưa có)", gEnabled);
        }
        ZUSCheckZaloVersion();
        // Mốc "đã nạp" ghi thẳng vào kho prefs ngay khi ctor chạy (thêm ở 1.0.1):
        // bằng chứng tweak có chạy trong Zalo hay không, đọc được ở trang Cài đặt
        // lẫn file /var/mobile/Library/Preferences/com.anhdang.zalounseen.plist —
        // không phụ thuộc file log trong Documents của Zalo như bản 1.0.0.
        ZUSWriteSharedValue(ZUS_DIAG_CTOR, [gLogFmt stringFromDate:[NSDate date]]);
        // Lắp móc theo danh sách trắng sau 1 giây (thử lại 7 giây sau đó cho mục
        // nào class nạp muộn; hàm đã móc rồi thì tự bỏ qua).
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            ZUSInstallWhitelist();
            ZUSInstallInAppButton();
            ZUSInstallStoryDownload();
            ZUSInstallTabBarGesture();
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(7 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{ ZUSInstallWhitelist(); ZUSInstallTabBarGesture(); });
        });
    }
}
