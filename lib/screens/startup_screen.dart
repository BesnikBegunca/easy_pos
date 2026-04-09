import 'package:flutter/material.dart';
import '../auth/license_service.dart';

class StartupScreen extends StatefulWidget {
  const StartupScreen({super.key});

  @override
  State<StartupScreen> createState() => _StartupScreenState();
}

class _StartupScreenState extends State<StartupScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _navigate());
  }

  Future<void> _navigate() async {
    await LicenseService.I.init();
    if (!mounted) return;
    if (LicenseService.I.isExpired) {
      Navigator.of(context).pushReplacementNamed('/license-lock');
      return;
    }
    Navigator.of(context).pushReplacementNamed('/login');
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Color(0xFF080E1E),
      body: Center(child: CircularProgressIndicator(color: Colors.white)),
    );
  }
}
