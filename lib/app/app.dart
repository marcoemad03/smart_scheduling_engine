import 'package:flutter/material.dart';
import '../core/theme/app_theme.dart';
import 'routes.dart';

class ReceptionSchedulerApp extends StatelessWidget {
  const ReceptionSchedulerApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Reception Workforce Scheduler',
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: ThemeMode.system,
      routerConfig: AppRoutes.router,
      debugShowCheckedModeBanner: false,
    );
  }
}