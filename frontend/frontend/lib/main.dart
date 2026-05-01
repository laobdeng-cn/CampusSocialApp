import 'package:flutter/material.dart';

import 'screens/auth_screens.dart';
import 'theme/app_theme.dart';

void main() {
  runApp(const CampusSocialApp());
}

class CampusSocialApp extends StatelessWidget {
  const CampusSocialApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '校园社交',
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
      builder: (context, child) {
        final mediaQuery = MediaQuery.of(context);
        return MediaQuery(
          data: mediaQuery.copyWith(textScaler: const TextScaler.linear(0.9)),
          child: child ?? const SizedBox.shrink(),
        );
      },
      home: const LoginScreen(),
    );
  }
}
