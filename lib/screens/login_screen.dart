import 'dart:math' as math;
import 'package:flutter/material.dart';

import '../auth/auth_service.dart';
import '../auth/session.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with TickerProviderStateMixin {
  // ===== CONFIG =====
  // sa shifra me lyp per PIN. Nese passwordet e tua jane p.sh. 4 shifra: 4.
  // Nese do 6 shifra: 6.
  static const int kPinLength = 4;

  // ===== STATE =====
  bool loading = false;
  bool pinMode = true; // default si ne foto
  final TextEditingController passC = TextEditingController();

  // PIN input si string
  String _pin = '';

  // anim i lehte per dots
  late final AnimationController _shakeCtrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 420),
  );

  Future<void> _loginWithPassword(String raw) async {
    final pass = raw.trim();
    if (pass.isEmpty) return;

    setState(() => loading = true);
    try {
      final u = await AuthService.I.login(pass);
      if (!mounted) return;

      if (u == null) {
        _showError('Password/PIN gabim.');
        _shake();
        return;
      }

      Session.I.setUser(u);
      Navigator.of(context).pushReplacementNamed('/shell');
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  void _shake() {
    // reset inputs
    setState(() {
      _pin = '';
      passC.clear();
    });
    _shakeCtrl.forward(from: 0);
  }

  void _onDigitTap(String d) {
    if (loading) return;

    if (!pinMode) {
      // nese je ne USER LOGIN mode, digit e shton ne TextField (opsionale)
      passC.text = (passC.text + d);
      passC.selection = TextSelection.collapsed(offset: passC.text.length);
      return;
    }

    if (_pin.length >= kPinLength) return;
    setState(() => _pin += d);

    if (_pin.length == kPinLength) {
      // auto login
      _loginWithPassword(_pin);
    }
  }

  void _onBackspace() {
    if (loading) return;

    if (!pinMode) {
      if (passC.text.isEmpty) return;
      passC.text = passC.text.substring(0, passC.text.length - 1);
      passC.selection = TextSelection.collapsed(offset: passC.text.length);
      return;
    }

    if (_pin.isEmpty) return;
    setState(() => _pin = _pin.substring(0, _pin.length - 1));
  }

  void _onClear() {
    if (loading) return;
    setState(() {
      _pin = '';
      passC.clear();
    });
  }

  @override
  void dispose() {
    passC.dispose();
    _shakeCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // ===== COLORS (3-4 colors) =====
    const bg = Color(0xFF0B0F14);
    const panel = Color(0xFF10161D);
    const tile = Color(0xFF1A222C);
    const accent = Color(0xFF2F6BFF);

    final size = MediaQuery.of(context).size;
    final isWide = size.width >= 720;

    return Scaffold(
      backgroundColor: bg,
      body: Stack(
        children: [
          // subtle gradient
          const _SoftGlowBackground(),

          SafeArea(
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: isWide ? 28 : 18,
                vertical: 18,
              ),
              child: Column(
                children: [
                  // ===== TOP BAR =====
                  Row(
                    children: [
                      _TopChip(
                        icon: Icons.info_outline_rounded,
                        label: 'v1.0.0',
                        onTap: () {},
                      ),
                      const Spacer(),
                      Row(
                        children: const [
                          Icon(
                            Icons.local_dining_rounded,
                            color: Colors.white70,
                            size: 18,
                          ),
                          SizedBox(width: 10),
                          Text(
                            'Restaurant POS',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.2,
                            ),
                          ),
                        ],
                      ),
                      const Spacer(),
                      _TopChip(
                        icon: Icons.help_outline_rounded,
                        label: 'Help',
                        onTap: () {},
                      ),
                    ],
                  ),

                  const SizedBox(height: 22),

                  // ===== TOGGLE =====
                  _SegmentedToggle(
                    left: 'USER LOGIN',
                    right: 'PIN LOGIN',
                    valueRightSelected: pinMode,
                    onChanged: (rightSelected) {
                      if (loading) return;
                      setState(() {
                        pinMode = rightSelected;
                        _pin = '';
                        passC.clear();
                      });
                    },
                    accent: accent,
                  ),

                  const SizedBox(height: 18),

                  // ===== CENTER PANEL =====
                  Expanded(
                    child: Center(
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          maxWidth: 460,
                          maxHeight: isWide ? 610 : 640,
                        ),
                        child: AnimatedBuilder(
                          animation: _shakeCtrl,
                          builder: (context, child) {
                            final t = Curves.elasticIn.transform(
                              _shakeCtrl.value,
                            );
                            final dx =
                                (math.sin(t * math.pi * 6) * 10) *
                                (1 - _shakeCtrl.value);
                            return Transform.translate(
                              offset: Offset(dx, 0),
                              child: child,
                            );
                          },
                          child: Container(
                            decoration: BoxDecoration(
                              color: panel.withOpacity(0.90),
                              borderRadius: BorderRadius.circular(18),
                              border: Border.all(
                                color: Colors.white.withOpacity(0.06),
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.35),
                                  blurRadius: 30,
                                  offset: const Offset(0, 18),
                                ),
                              ],
                            ),
                            padding: const EdgeInsets.fromLTRB(22, 20, 22, 18),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const SizedBox(height: 6),
                                Text(
                                  pinMode
                                      ? 'Enter personal PIN'
                                      : 'Enter password',
                                  style: const TextStyle(
                                    color: Colors.white70,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 14),

                                // Dots / TextField
                                if (pinMode) ...[
                                  _PinDots(
                                    length: kPinLength,
                                    filled: _pin.length,
                                    accent: accent,
                                  ),
                                  const SizedBox(height: 18),
                                ] else ...[
                                  TextField(
                                    controller: passC,
                                    obscureText: true,
                                    enableSuggestions: false,
                                    autocorrect: false,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 16,
                                    ),
                                    cursorColor: accent,
                                    decoration: InputDecoration(
                                      filled: true,
                                      fillColor: tile,
                                      hintText: 'Password',
                                      hintStyle: const TextStyle(
                                        color: Colors.white38,
                                      ),
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(14),
                                        borderSide: BorderSide.none,
                                      ),
                                      prefixIcon: const Icon(
                                        Icons.lock_outline_rounded,
                                        color: Colors.white60,
                                      ),
                                      suffixIcon: IconButton(
                                        onPressed: loading ? null : _onClear,
                                        icon: const Icon(
                                          Icons.close_rounded,
                                          color: Colors.white54,
                                        ),
                                      ),
                                    ),
                                    onSubmitted: (_) =>
                                        _loginWithPassword(passC.text),
                                  ),
                                  const SizedBox(height: 16),
                                ],

                                // Keypad
                                Expanded(
                                  child: _Keypad(
                                    tileColor: tile,
                                    onDigit: _onDigitTap,
                                    onBackspace: _onBackspace,
                                    onClear: _onClear,
                                    enabled: !loading,
                                  ),
                                ),

                                const SizedBox(height: 12),

                                // Bottom actions
                                Row(
                                  children: [
                                    Expanded(
                                      child: _QuietButton(
                                        label: pinMode ? 'Clear' : 'Reset',
                                        icon: Icons.restart_alt_rounded,
                                        onTap: loading ? null : _onClear,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: _PrimaryButton(
                                        label: loading
                                            ? 'Signing in…'
                                            : 'Login',
                                        icon: Icons.arrow_forward_rounded,
                                        accent: accent,
                                        onTap: loading
                                            ? null
                                            : () => _loginWithPassword(
                                                pinMode ? _pin : passC.text,
                                              ),
                                      ),
                                    ),
                                  ],
                                ),

                                const SizedBox(height: 10),

                                // Hint (keep it subtle)
                                const Opacity(
                                  opacity: 0.35,
                                  child: Text(
                                    'Tip: PIN/password determines role (admin / waiter)',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),

                  // ===== FOOTER =====
                  Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: Row(
                      children: const [
                        Text(
                          'Restaurant Manager',
                          style: TextStyle(color: Colors.white38),
                        ),
                        Spacer(),
                        Text('Tools', style: TextStyle(color: Colors.white38)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/* =========================
   UI COMPONENTS (same file)
   ========================= */

class _SoftGlowBackground extends StatelessWidget {
  const _SoftGlowBackground();

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment(0.05, -0.25),
            radius: 1.2,
            colors: [Color(0x221B3A7A), Color(0x11000000), Color(0xFF0B0F14)],
            stops: [0.0, 0.55, 1.0],
          ),
        ),
      ),
    );
  }
}

class _TopChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _TopChip({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.04),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: Colors.white.withOpacity(0.06)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18, color: Colors.white70),
            const SizedBox(width: 8),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white70,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SegmentedToggle extends StatelessWidget {
  final String left;
  final String right;
  final bool valueRightSelected;
  final ValueChanged<bool> onChanged;
  final Color accent;

  const _SegmentedToggle({
    required this.left,
    required this.right,
    required this.valueRightSelected,
    required this.onChanged,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    final leftSelected = !valueRightSelected;
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.04),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withOpacity(0.06)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _SegBtn(
            text: left,
            selected: leftSelected,
            accent: accent,
            onTap: () => onChanged(false),
          ),
          _SegBtn(
            text: right,
            selected: valueRightSelected,
            accent: accent,
            onTap: () => onChanged(true),
          ),
        ],
      ),
    );
  }
}

class _SegBtn extends StatelessWidget {
  final String text;
  final bool selected;
  final Color accent;
  final VoidCallback onTap;

  const _SegBtn({
    required this.text,
    required this.selected,
    required this.accent,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? accent : Colors.transparent,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          text,
          style: TextStyle(
            color: selected ? Colors.white : Colors.white70,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.2,
          ),
        ),
      ),
    );
  }
}

class _PinDots extends StatelessWidget {
  final int length;
  final int filled;
  final Color accent;

  const _PinDots({
    required this.length,
    required this.filled,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(length, (i) {
        final isFilled = i < filled;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          margin: const EdgeInsets.symmetric(horizontal: 10),
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: isFilled ? accent : Colors.white24,
            shape: BoxShape.circle,
          ),
        );
      }),
    );
  }
}

class _Keypad extends StatelessWidget {
  final Color tileColor;
  final void Function(String) onDigit;
  final VoidCallback onBackspace;
  final VoidCallback onClear;
  final bool enabled;

  const _Keypad({
    required this.tileColor,
    required this.onDigit,
    required this.onBackspace,
    required this.onClear,
    required this.enabled,
  });

  @override
  Widget build(BuildContext context) {
    // 1..9, clear, 0, backspace (si POS)
    final keys = <_Key>[
      const _Key.digit('1'),
      const _Key.digit('2'),
      const _Key.digit('3'),
      const _Key.digit('4'),
      const _Key.digit('5'),
      const _Key.digit('6'),
      const _Key.digit('7'),
      const _Key.digit('8'),
      const _Key.digit('9'),
      const _Key.clear(),
      const _Key.digit('0'),
      const _Key.backspace(),
    ];

    return LayoutBuilder(
      builder: (context, c) {
        final w = c.maxWidth;
        final tileW = (w - 16) / 3; // 2 gaps *8
        final tileH = math.min(86.0, tileW * 0.72);

        return Wrap(
          spacing: 8,
          runSpacing: 8,
          children: keys.map((k) {
            return SizedBox(
              width: tileW,
              height: tileH,
              child: _KeypadTile(
                keyData: k,
                color: tileColor,
                enabled: enabled,
                onTap: () {
                  if (!enabled) return;
                  switch (k.type) {
                    case _KeyType.digit:
                      onDigit(k.value!);
                      break;
                    case _KeyType.clear:
                      onClear();
                      break;
                    case _KeyType.backspace:
                      onBackspace();
                      break;
                  }
                },
              ),
            );
          }).toList(),
        );
      },
    );
  }
}

class _KeypadTile extends StatelessWidget {
  final _Key keyData;
  final Color color;
  final bool enabled;
  final VoidCallback onTap;

  const _KeypadTile({
    required this.keyData,
    required this.color,
    required this.enabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final fg = enabled ? Colors.white : Colors.white38;

    Widget child;
    if (keyData.type == _KeyType.digit) {
      child = Text(
        keyData.value!,
        style: TextStyle(color: fg, fontSize: 22, fontWeight: FontWeight.w800),
      );
    } else if (keyData.type == _KeyType.backspace) {
      child = Icon(Icons.backspace_outlined, color: fg, size: 22);
    } else {
      child = Icon(Icons.refresh_rounded, color: fg, size: 22);
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Ink(
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.white.withOpacity(0.06)),
          ),
          child: Center(child: child),
        ),
      ),
    );
  }
}

class _PrimaryButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color accent;
  final VoidCallback? onTap;

  const _PrimaryButton({
    required this.label,
    required this.icon,
    required this.accent,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: Container(
        height: 48,
        decoration: BoxDecoration(
          color: onTap == null ? accent.withOpacity(0.35) : accent,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(width: 10),
            Icon(icon, color: Colors.white),
          ],
        ),
      ),
    );
  }
}

class _QuietButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback? onTap;

  const _QuietButton({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: Container(
        height: 48,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.06),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white.withOpacity(0.06)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: onTap == null ? Colors.white30 : Colors.white70),
            const SizedBox(width: 10),
            Text(
              label,
              style: TextStyle(
                color: onTap == null ? Colors.white30 : Colors.white70,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

enum _KeyType { digit, clear, backspace }

class _Key {
  final _KeyType type;
  final String? value;
  const _Key._(this.type, this.value);

  const _Key.digit(String d) : this._(_KeyType.digit, d);
  const _Key.clear() : this._(_KeyType.clear, null);
  const _Key.backspace() : this._(_KeyType.backspace, null);
}
