import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'theme/app_theme.dart';
import 'package:provider/provider.dart';
import 'state/session_state.dart';
import 'services/notification_service.dart';
import 'screens/auth/login_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Supabase
  await Supabase.initialize(
    url: 'https://ezlyyxfpnxbaagzqysze.supabase.co',
    anonKey:
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImV6bHl5eGZwbnhiYWFnenF5c3plIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzEwMDc4ODksImV4cCI6MjA4NjU4Mzg4OX0.gYoOHqUBy5v4ZUZZQLKVpwezTx2bJYOl51ZuW1B0qQY',
  );

  // Set system UI style
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      systemNavigationBarColor: Colors.white,
      systemNavigationBarIconBrightness: Brightness.dark,
    ),
  );

  // Lock orientation
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  runApp(const DicaClinicMobile());
}

class DicaClinicMobile extends StatelessWidget {
  const DicaClinicMobile({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => SessionState()),
        ChangeNotifierProvider.value(value: NotificationService()),
      ],
      child: Consumer<SessionState>(
        builder:
            (context, state, _) => MaterialApp(
              title: 'Dica Clinic',
              debugShowCheckedModeBanner: false,
              theme:
                  state.isDarkTheme ? AppTheme.darkTheme : AppTheme.lightTheme,
              home: const LoginScreen(),
            ),
      ),
    );
  }
}
