import 'package:flutter/material.dart';
import '../auth/auth_service.dart';
import '../auth/session.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final userC = TextEditingController();
  final passC = TextEditingController();
  bool loading = false;

  Future<void> _login() async {
    setState(() => loading = true);
    try {
      final u = await AuthService.I.login(userC.text.trim(), passC.text);
      if (!mounted) return;

      if (u == null) {
        showDialog(
          context: context,
          builder: (_) => const AlertDialog(
            title: Text('Gabim'),
            content: Text('Username ose password gabim.'),
          ),
        );
        return;
      }

      Session.I.setUser(u);
      Navigator.of(context).pushReplacementNamed('/shell');
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 360),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Restaurant POS', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 16),
                  TextField(controller: userC, decoration: const InputDecoration(labelText: 'Username')),
                  const SizedBox(height: 10),
                  TextField(
                    controller: passC,
                    obscureText: true,
                    decoration: const InputDecoration(labelText: 'Password'),
                    onSubmitted: (_) => _login(),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: loading ? null : _login,
                      child: Text(loading ? 'Duke u kyç...' : 'Kyçu'),
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text('Seed: admin / admin123', style: TextStyle(fontSize: 12)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
