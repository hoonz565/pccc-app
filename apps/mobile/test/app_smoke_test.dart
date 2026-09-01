import 'package:firesafe_mobile/app.dart';
import 'package:firesafe_mobile/core/storage/credential_store.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/test_credential_store.dart';

void main() {
  testWidgets('routes an unauthenticated cold start to login', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          credentialStoreProvider.overrideWithValue(EmptyTestCredentialStore()),
        ],
        child: const FireSafeApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Đăng nhập'), findsOneWidget);
    expect(find.text('Chưa có tài khoản? Đăng ký'), findsOneWidget);
  });
}
