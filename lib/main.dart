import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'services/database_service.dart';
import 'providers/auth_provider.dart';
import 'providers/routine_provider.dart';
import 'providers/repertoire_provider.dart';
import 'providers/history_provider.dart';
import 'providers/practice_provider.dart';
import 'providers/localization_provider.dart';
import 'screens/auth_screen.dart';
import 'screens/main_shell.dart';
import 'theme/app_theme.dart';

import 'package:intl/date_symbol_data_local.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize Local Offline Database
  final dbService = DatabaseService();
  await dbService.init();

  // Initialize Date Formatting for Calendar
  await initializeDateFormatting('es', null);
  await initializeDateFormatting('en', null);

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => LocalizationProvider()),
        ChangeNotifierProvider(create: (_) => AuthProvider()..checkAuthStatus()),
        ChangeNotifierProvider(create: (_) => RoutineProvider()),
        ChangeNotifierProvider(create: (_) => RepertoireProvider()),
        ChangeNotifierProvider(create: (_) => HistoryProvider()),
        ChangeNotifierProvider(create: (_) => PracticeProvider()),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: context.translate('app_title'),
      theme: AppTheme.darkTheme,
      debugShowCheckedModeBanner: false,
      home: const AuthenticationWrapper(),
    );
  }
}

class AuthenticationWrapper extends StatelessWidget {
  const AuthenticationWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    final authProv = Provider.of<AuthProvider>(context);
    
    // Redirect based on local authentication profile presence
    if (authProv.isAuthenticated) {
      return const MainShell();
    } else {
      return const AuthScreen();
    }
  }
}
