import 'package:firesafe_mobile/app.dart';
import 'package:firesafe_mobile/core/storage/credential_store.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/test_credential_store.dart';

void main() {
  testWidgets('login requires a valid email and a non-empty password', (
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

    await tester.tap(find.text('Đăng nhập'));
    await tester.pump();

    expect(find.text('Nhập địa chỉ email hợp lệ.'), findsOneWidget);
    expect(find.text('Nhập mật khẩu hợp lệ.'), findsOneWidget);
  });
}
