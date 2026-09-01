import 'dart:async';

import 'package:firesafe_mobile/features/areas/data/area_models.dart';
import 'package:firesafe_mobile/features/areas/data/area_repository.dart';
import 'package:firesafe_mobile/features/areas/presentation/create_area_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../../helpers/sprint2_fakes.dart';

void main() {
  testWidgets('Area create disables duplicate submit and returns on success', (
    tester,
  ) async {
    final completer = Completer<Area>();
    final repository = FakeAreaRepository(createCompleter: completer.future);
    final router = _router();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [areaRepositoryProvider.overrideWithValue(repository)],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    router.push('/new');
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextFormField), 'Tầng 1');
    await tester.tap(find.text('Lưu khu vực'));
    await tester.pump();
    await tester.tap(find.byType(FilledButton));

    expect(repository.createCalls, 1);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    completer.complete(areaFixture(name: 'Tầng 1'));
    await tester.pumpAndSettle();
    expect(find.text('Root'), findsOneWidget);
  });

  testWidgets('recoverable Area error retains the draft', (tester) async {
    final repository = FakeAreaRepository(
      error: const AreaRequestException('Mất kết nối.', isTransient: true),
    );
    final router = _router();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [areaRepositoryProvider.overrideWithValue(repository)],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    router.push('/new');
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextFormField), 'Tầng chưa lưu');
    await tester.tap(find.text('Lưu khu vực'));
    await tester.pumpAndSettle();

    expect(find.text('Tầng chưa lưu'), findsOneWidget);
    expect(find.textContaining('Không tự động gửi lại'), findsOneWidget);
  });
}

GoRouter _router() => GoRouter(
  initialLocation: '/',
  routes: [
    GoRoute(
      path: '/',
      builder: (_, _) => const Scaffold(body: Text('Root')),
    ),
    GoRoute(
      path: '/new',
      builder: (_, _) => const CreateAreaScreen(facilityId: 'facility-id'),
    ),
  ],
);
