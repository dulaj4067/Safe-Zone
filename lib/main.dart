import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'providers/session_provider.dart';
import 'screens/shell_screen.dart';
import 'theme/app_theme.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<FocusState>(
      create: (_) => FocusState(),
      child: MaterialApp(
        title: 'Focus App',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme,
        home: const ShellScreen(),
      ),
    );
  }
}