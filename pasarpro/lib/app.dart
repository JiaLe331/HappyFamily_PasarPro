import 'package:flutter/material.dart';
import 'core/theme/app_theme.dart';
import 'features/main_shell.dart';

class PasarProApp extends StatelessWidget {
  const PasarProApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'PasarPro',
      theme: AppTheme.light,
      debugShowCheckedModeBanner: false,
      home: const MainShell(),
    );
  }
}
