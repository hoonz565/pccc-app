import 'package:firesafe_mobile/features/facilities/presentation/first_facility_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('first facility requires all minimum product fields', (
    tester,
  ) async {
    await tester.pumpWidget(
      const ProviderScope(child: MaterialApp(home: FirstFacilityScreen())),
    );

    final submitButton = find.text('Tạo cơ sở và vào Home');
    await tester.ensureVisible(submitButton);
    await tester.tap(submitButton);
    await tester.pump();

    expect(find.text('Trường này là bắt buộc.'), findsNWidgets(4));
    expect(find.text('Nhập tự do; chưa có danh mục đóng.'), findsOneWidget);
  });
}
