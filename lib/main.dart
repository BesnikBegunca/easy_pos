import 'package:easy_pos/screens/manage_users_screen.dart';
import 'package:flutter/material.dart';
import 'auth/auth_service.dart';
import 'auth/license_service.dart';
import 'auth/roles.dart';
import 'auth/session.dart';
import 'data/app_settings.dart';
import 'l10n/app_l10n.dart';
import 'screens/license_lock_screen.dart';
import 'screens/license_manager_screen.dart';
import 'screens/login_screen.dart';
import 'screens/shell.dart';
import 'screens/startup_screen.dart';
import 'theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AuthService.I.ensureSeed();
  await LicenseService.I.init();
  // Load all settings into memory once at startup.
  // Every screen can now read AppSettings.I synchronously.
  await AppSettings.I.load();
  // Sync the locale notifier with the saved language preference.
  AppL10n.I.setLocale(AppSettings.I.language);
  runApp(const App());
}

class App extends StatelessWidget {
  const App({super.key});

  ThemeData _getRoleTheme() {
    final u = Session.I.current;
    if (u == null) return AppTheme.darkOrangeTheme();

    if (canAccessAdminPanel(u.role)) {
      return ThemeData.dark(useMaterial3: true).copyWith(
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFFFF6B35),
          secondary: Color(0xFF4ECDC4),
          surface: AppTheme.surface,
        ).copyWith(surface: AppTheme.surface, onSurface: AppTheme.textPrimary),
        scaffoldBackgroundColor: const Color(0xFF0F0F23),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF1A1A2E),
          foregroundColor: Colors.white,
          elevation: 0,
        ),
      );
    }

    return ThemeData.dark(useMaterial3: true).copyWith(
      colorScheme: const ColorScheme.dark(
        primary: AppTheme.primary,
        secondary: AppTheme.orange,
        surface: AppTheme.surface,
      ).copyWith(onSurface: AppTheme.textPrimary),
      primaryColor: AppTheme.primary,
      scaffoldBackgroundColor: AppTheme.background,
      textTheme: ThemeData.dark().textTheme.apply(
        bodyColor: Colors.white,
        displayColor: Colors.white,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: AppTheme.surface,
        foregroundColor: Colors.white,
      ),
      iconTheme: const IconThemeData(color: Colors.white70),
    );
  }

  @override
  Widget build(BuildContext context) {
    // AppL10nWidget rebuilds MaterialApp whenever language changes.
    return AppL10nWidget(
      builder: (locale) => MaterialApp(
        debugShowCheckedModeBanner: false,
        locale: locale,
        theme: _getRoleTheme(),
        home: const StartupScreen(),
        routes: {
          '/login': (_) => const LoginScreen(),
          '/shell': (_) => const ShellScreen(),
          '/manage-users': (_) => const ManageUsersScreen(),
          '/license-lock': (_) => const LicenseLockScreen(),
          '/license-manager': (_) => const LicenseManagerScreen(),
        },
      ),
    );
  }
}
