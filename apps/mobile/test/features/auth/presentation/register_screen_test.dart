import 'package:firesafe_mobile/app.dart';
import 'package:firesafe_mobile/core/storage/credential_store.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/test_credential_store.dart';

void main() {
  testWidgets('registration requires valid fields and explicit consent', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          credentialStoreProvider.overrideWithValue(EmptyTestCredentialStore()),
        ],
        child: const FireSafeApp(),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Chưa có tài khoản? Đăng ký'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Tạo tài khoản'));
    await tester.pump();

    expect(find.text('Nhập địa chỉ email hợp lệ.'), findsOneWidget);
    expect(find.text('Mật khẩu phải có từ 12 đến 128 ký tự.'), findsOneWidget);
    expect(
      find.text('Bạn cần đồng ý cả Điều khoản và Chính sách quyền riêng tư.'),
      findsOneWidget,
    );
    expect(find.text('Phiên bản phát triển: draft-v1'), findsNWidgets(2));
  });
}
