import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/main.dart';

void main() {
  testWidgets('campus social app launches on login', (tester) async {
    await tester.binding.setSurfaceSize(const Size(430, 932));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(const CampusSocialApp());
    await tester.pump();

    expect(find.text('登录'), findsWidgets);
    expect(find.text('校园活动圈'), findsOneWidget);

    final loginButton = find.widgetWithText(FilledButton, '登录');
    await tester.ensureVisible(loginButton);
    await tester.tap(loginButton);
    await tester.pump();

    expect(find.text('请输入手机号和密码'), findsOneWidget);
  });
}
