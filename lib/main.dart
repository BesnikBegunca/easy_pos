import 'package:easy_pos/screens/manage_users_screen.dart';
import 'package:flutter/material.dart';
import 'auth/auth_service.dart';
import 'screens/login_screen.dart';
import 'screens/shell.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AuthService.I.ensureSeed();
  runApp(const App());
}

class App extends StatelessWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      initialRoute: '/login',
      routes: {
        '/login': (_) => const LoginScreen(),
        '/shell': (_) => const ShellScreen(),
        '/manage-users': (_) => const ManageUsersScreen(),

      },
    );
  }
}
