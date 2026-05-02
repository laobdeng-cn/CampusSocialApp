import 'package:flutter/material.dart';

import 'repositories/auth_session.dart';
import 'screens/auth_screens.dart';
import 'screens/main_shell.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AuthSession.restore();
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
      home: AuthSession.isLoggedIn ? const CampusShell() : const LoginScreen(),
    );
  }
}
