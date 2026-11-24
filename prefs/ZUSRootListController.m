// ZUSRootListController 1.1.2 — trang Cài đặt của ZaloUnseen.
#import "ZUSRootListController.h"
#import "ZUSShared.h"

@implementation ZUSRootListController

- (NSArray *)specifiers {
    if (!_specifiers) {
        _specifiers = [self loadSpecifiersFromPlistName:@"Root" target:self];
    }
    return _specifiers;
}

static id ZUSDiagValue(NSString *key) {
    CFPropertyListRef v = CFPreferencesCopyAppValue((__bridge CFStringRef)key, (__bridge CFStringRef)ZUS_DOMAIN);
    return (__bridge_transfer id)v;
}

- (void)showDiag {
    NSNumber *cand = ZUSDiagValue(ZUS_DIAG_CANDIDATES);
    NSNumber *hooked = ZUSDiagValue(ZUS_DIAG_HOOKED);
    NSNumber *skipped = ZUSDiagValue(ZUS_DIAG_SKIPPED);
    NSNumber *blockedRead = ZUSDiagValue(ZUS_DIAG_BLOCKED_READ);
    NSNumber *blockedType = ZUSDiagValue(ZUS_DIAG_BLOCKED_TYPE);
    NSNumber *blockedDeliv = ZUSDiagValue(ZUS_DIAG_BLOCKED_DELIV);
    NSNumber *blockedRecall = ZUSDiagValue(ZUS_DIAG_BLOCKED_RECALL);
    NSString *last = ZUSDiagValue(ZUS_DIAG_LAST);
    NSString *scan = ZUSDiagValue(ZUS_DIAG_SCAN);
    NSString *ctor = ZUSDiagValue(ZUS_DIAG_CTOR);
    NSNumber *friends = ZUSDiagValue(ZUS_DIAG_FRIENDS);
    NSString *friendsrc = ZUSDiagValue(ZUS_DIAG_FRIENDSRC);
    NSString *zaloupd = ZUSDiagValue(ZUS_DIAG_ZALOUPD);
    NSString *msg;
    if (!cand && !hooked) {
        if (ctor.length) {
            msg = [NSString stringWithFormat:
                @"Tweak ĐÃ nạp vào Zalo lúc %@ nhưng chưa quét được dữ liệu.\n\nMở app Zalo, vào một đoạn chat bất kỳ, đợi vài giây rồi quay lại đây kiểm tra.", ctor];
        } else {
            msg = @"Tweak CHƯA từng nạp vào Zalo (không có mốc nạp).\n\nMở app Zalo một lúc rồi quay lại đây kiểm tra. Nếu vẫn trống thì gửi mình file log trong Documents của Zalo (Filza → Apps → Zalo → Documents → ZaloUnseen.log).";
        }
    } else {
        msg = [NSString stringWithFormat:
            @"Đã nạp vào Zalo: %@\nLần quét gần nhất: %@\nỨng viên tìm thấy: %@\nĐã móc thành công: %@\nBỏ qua (kiểu dữ liệu không an toàn): %@\nĐã chặn 'đã xem': %@ lần\nĐã chặn 'đang nhập': %@ lần\nĐã chặn 'đã nhận': %@ lần\nĐã chặn 'thu hồi': %@ lần\nSự kiện gần nhất: %@\nBạn bè đã sao lưu: %@ (nguồn: %@)\nZalo đã đổi bản: %@",
            ctor.length ? ctor : @"—", scan ?: @"—", cand ?: @0, hooked ?: @0, skipped ?: @0,
            blockedRead ?: @0, blockedType ?: @0, blockedDeliv ?: @0, blockedRecall ?: @0, last.length ? last : @"—", friends ?: @0, friendsrc.length ? friendsrc : @"—", zaloupd.length ? zaloupd : @"—"];
    }
    UIAlertController *a = [UIAlertController alertControllerWithTitle:@"Trạng thái dò" message:msg preferredStyle:UIAlertControllerStyleAlert];
    [a addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil]];
    [self presentViewController:a animated:YES completion:nil];
}

@end
