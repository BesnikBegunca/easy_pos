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
  static const int kPinLength = 4;

  bool _loading = false;
  bool _pinMode = true;
  final TextEditingController _passC = TextEditingController();
  String _pin = '';

  late final AnimationController _shakeCtrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 420),
  );
  late final AnimationController _fadeCtrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 600),
  );

  @override
  void initState() {
    super.initState();
    _fadeCtrl.forward();
  }

  @override
  void dispose() {
    _passC.dispose();
    _shakeCtrl.dispose();
    _fadeCtrl.dispose();
    super.dispose();
  }

  Future<void> _loginWithPassword(String raw) async {
    final pass = raw.trim();
    if (pass.isEmpty) return;
    setState(() => _loading = true);
    try {
      final u = await AuthService.I.login(pass);
      if (!mounted) return;
      if (u == null) {
        _showError('PIN ose fjalëkalimi është i gabuar.');
        _shake();
        return;
      }
      Session.I.setUser(u);
      Navigator.of(context).pushReplacementNamed('/shell');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(
          content: Row(children: [
            const Icon(Icons.error_outline_rounded, color: _kError, size: 18),
            const SizedBox(width: 10),
            Text(msg, style: const TextStyle(color: Colors.white)),
          ]),
          backgroundColor: const Color(0xFF1C1C2E),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          margin: const EdgeInsets.all(16),
        ),
      );
  }

  void _shake() {
    setState(() { _pin = ''; _passC.clear(); });
    _shakeCtrl.forward(from: 0);
  }

  void _onDigitTap(String d) {
    if (_loading) return;
    if (!_pinMode) {
      _passC.text = _passC.text + d;
      _passC.selection = TextSelection.collapsed(offset: _passC.text.length);
      return;
    }
    if (_pin.length >= kPinLength) return;
    setState(() => _pin += d);
    if (_pin.length == kPinLength) _loginWithPassword(_pin);
  }

  void _onBackspace() {
    if (_loading) return;
    if (!_pinMode) {
      if (_passC.text.isEmpty) return;
      _passC.text = _passC.text.substring(0, _passC.text.length - 1);
      _passC.selection = TextSelection.collapsed(offset: _passC.text.length);
      return;
    }
    if (_pin.isEmpty) return;
    setState(() => _pin = _pin.substring(0, _pin.length - 1));
  }

  void _onClear() {
    if (_loading) return;
    setState(() { _pin = ''; _passC.clear(); });
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isWide = size.width >= 900;

    return Scaffold(
      backgroundColor: _kBg,
      body: Stack(
        children: [
          const _AnimatedBackground(),
          FadeTransition(
            opacity: _fadeCtrl,
            child: SafeArea(
              child: isWide
                  ? _buildWideLayout()
                  : _buildNarrowLayout(),
            ),
          ),
        ],
      ),
    );
  }

  // ── Wide (desktop): left branding + right login ────────────────────────────
  Widget _buildWideLayout() {
    return Row(
      children: [
        // Left — Brand panel
        Expanded(
          flex: 5,
          child: _BrandPanel(),
        ),
        // Right — Login panel
        Expanded(
          flex: 4,
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 32),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: _buildLoginCard(),
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ── Narrow (mobile): centered card ────────────────────────────────────────
  Widget _buildNarrowLayout() {
    return Column(
      children: [
        // Compact brand bar
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          child: Row(
            children: [
              _LogoMark(size: 36),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Text('EasyPOS',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                      fontSize: 16,
                    ),
                  ),
                  Text('Restaurant System',
                    style: TextStyle(color: _kTextSub, fontSize: 11),
                  ),
                ],
              ),
            ],
          ),
        ),
        Expanded(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: _buildLoginCard(),
            ),
          ),
        ),
      ],
    );
  }

  // ── Login card ─────────────────────────────────────────────────────────────
  Widget _buildLoginCard() {
    return AnimatedBuilder(
      animation: _shakeCtrl,
      builder: (context, child) {
        final t = Curves.elasticIn.transform(_shakeCtrl.value);
        final dx = math.sin(t * math.pi * 6) * 10 * (1 - _shakeCtrl.value);
        return Transform.translate(offset: Offset(dx, 0), child: child);
      },
      child: Container(
        decoration: BoxDecoration(
          color: _kPanel,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.50),
              blurRadius: 40,
              offset: const Offset(0, 20),
            ),
            BoxShadow(
              color: _kAccent.withValues(alpha: 0.06),
              blurRadius: 60,
              spreadRadius: 10,
            ),
          ],
        ),
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildModeToggle(),
            const SizedBox(height: 24),
            if (_pinMode) ...[
              _buildPinHeader(),
              const SizedBox(height: 20),
              _PinDots(length: kPinLength, filled: _pin.length),
              const SizedBox(height: 24),
            ] else ...[
              _buildPasswordHeader(),
              const SizedBox(height: 16),
              _buildPasswordField(),
              const SizedBox(height: 20),
            ],
            _Keypad(
              onDigit: _onDigitTap,
              onBackspace: _onBackspace,
              onClear: _onClear,
              enabled: !_loading,
            ),
            const SizedBox(height: 20),
            _buildActions(),
          ],
        ),
      ),
    );
  }

  Widget _buildModeToggle() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _ToggleBtn(
            label: 'Hyrje PIN',
            icon: Icons.grid_view_rounded,
            selected: _pinMode,
            onTap: () {
              if (!_loading) setState(() { _pinMode = true; _pin = ''; _passC.clear(); });
            },
          ),
          _ToggleBtn(
            label: 'Fjalëkalim',
            icon: Icons.lock_outline_rounded,
            selected: !_pinMode,
            onTap: () {
              if (!_loading) setState(() { _pinMode = false; _pin = ''; _passC.clear(); });
            },
          ),
        ],
      ),
    );
  }

  Widget _buildPinHeader() {
    return Column(
      children: [
        const Text(
          'Fut PIN-in personal',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w700,
            fontSize: 15,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Hyrja do të bëhet automatikisht',
          style: TextStyle(color: _kTextSub, fontSize: 12),
        ),
      ],
    );
  }

  Widget _buildPasswordHeader() {
    return Column(
      children: [
        const Text(
          'Fut fjalëkalimin',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w700,
            fontSize: 15,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Fjalëkalimi i llogarisë',
          style: TextStyle(color: _kTextSub, fontSize: 12),
        ),
      ],
    );
  }

  Widget _buildPasswordField() {
    return TextField(
      controller: _passC,
      obscureText: true,
      enableSuggestions: false,
      autocorrect: false,
      style: const TextStyle(color: Colors.white, fontSize: 16),
      cursorColor: _kAccent,
      onSubmitted: (_) => _loginWithPassword(_passC.text),
      decoration: InputDecoration(
        filled: true,
        fillColor: _kTile,
        hintText: 'Fjalëkalimi',
        hintStyle: const TextStyle(color: Colors.white38),
        prefixIcon: const Icon(Icons.lock_outline_rounded, color: Colors.white38, size: 20),
        suffixIcon: IconButton(
          onPressed: _loading ? null : _onClear,
          icon: const Icon(Icons.close_rounded, color: Colors.white38, size: 18),
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: _kAccent, width: 1.5),
        ),
      ),
    );
  }

  Widget _buildActions() {
    return Row(
      children: [
        Expanded(
          child: _ActionBtn(
            label: 'Reset',
            icon: Icons.restart_alt_rounded,
            onTap: _loading ? null : _onClear,
            primary: false,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _ActionBtn(
            label: _loading ? 'Duke hyrë…' : 'Hyr',
            icon: _loading ? Icons.hourglass_empty_rounded : Icons.arrow_forward_rounded,
            onTap: _loading
                ? null
                : () => _loginWithPassword(_pinMode ? _pin : _passC.text),
            primary: true,
          ),
        ),
      ],
    );
  }
}

// ── Brand Panel ───────────────────────────────────────────────────────────────
class _BrandPanel extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF0A0C1E), Color(0xFF070810)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border(
          right: BorderSide(color: Color(0xFF1E2340)),
        ),
      ),
      child: Stack(
        children: [
          // Subtle decorative glows
          Positioned(top: -60, left: -60,
            child: Container(
              width: 320, height: 320,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(colors: [
                  _kAccent.withValues(alpha: 0.10),
                  Colors.transparent,
                ]),
              ),
            ),
          ),
          Positioned(bottom: -80, right: -40,
            child: Container(
              width: 280, height: 280,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(colors: [
                  const Color(0xFF8B5CF6).withValues(alpha: 0.08),
                  Colors.transparent,
                ]),
              ),
            ),
          ),
          // Content
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 48),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _LogoMark(size: 64),
                  const SizedBox(height: 28),
                  const Text(
                    'EasyPOS',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 38,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -1,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Sistemi i menaxhimit\ntë restorantit',
                    style: TextStyle(
                      color: Color(0xFF8892B0),
                      fontSize: 17,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 48),
                  ...[
                    _FeatureRow(icon: Icons.table_restaurant_rounded, label: 'Menaxhim i tavolinave'),
                    _FeatureRow(icon: Icons.receipt_long_rounded, label: 'Porosi dhe faturim'),
                    _FeatureRow(icon: Icons.groups_rounded, label: 'Menaxhim i stafit'),
                    _FeatureRow(icon: Icons.bar_chart_rounded, label: 'Raporte ditore'),
                  ],
                  const SizedBox(height: 48),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.04),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 6, height: 6,
                          decoration: const BoxDecoration(
                            color: Color(0xFF10B981),
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Text(
                          'v2.0.0 — Premium Edition',
                          style: TextStyle(color: Color(0xFF8892B0), fontSize: 12),
                        ),
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

class _FeatureRow extends StatelessWidget {
  final IconData icon;
  final String label;
  const _FeatureRow({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        children: [
          Container(
            width: 32, height: 32,
            decoration: BoxDecoration(
              color: _kAccent.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: _kAccent, size: 16),
          ),
          const SizedBox(width: 12),
          Text(label, style: const TextStyle(color: Color(0xFFCDD5F3), fontSize: 14)),
        ],
      ),
    );
  }
}

class _LogoMark extends StatelessWidget {
  final double size;
  const _LogoMark({required this.size});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size, height: size,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(size * 0.28),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF6366F1).withValues(alpha: 0.40),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Icon(
        Icons.point_of_sale_rounded,
        color: Colors.white,
        size: size * 0.48,
      ),
    );
  }
}

// ── Animated background ───────────────────────────────────────────────────────
class _AnimatedBackground extends StatelessWidget {
  const _AnimatedBackground();

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment(0.6, -0.3),
            radius: 1.4,
            colors: [Color(0x1A1B3A7A), Color(0x08000000), _kBg],
            stops: [0.0, 0.5, 1.0],
          ),
        ),
      ),
    );
  }
}

// ── Toggle button ─────────────────────────────────────────────────────────────
class _ToggleBtn extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;
  const _ToggleBtn({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? _kAccent : Colors.transparent,
          borderRadius: BorderRadius.circular(999),
          boxShadow: selected ? [
            BoxShadow(
              color: _kAccent.withValues(alpha: 0.30),
              blurRadius: 12,
            ),
          ] : [],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14,
              color: selected ? Colors.white : const Color(0xFF8892B0)),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: selected ? Colors.white : const Color(0xFF8892B0),
                fontWeight: FontWeight.w700,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── PIN dots ──────────────────────────────────────────────────────────────────
class _PinDots extends StatelessWidget {
  final int length;
  final int filled;
  const _PinDots({required this.length, required this.filled});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(length, (i) {
        final isFilled = i < filled;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          curve: Curves.elasticOut,
          margin: const EdgeInsets.symmetric(horizontal: 10),
          width: isFilled ? 14 : 12,
          height: isFilled ? 14 : 12,
          decoration: BoxDecoration(
            color: isFilled ? _kAccent : Colors.transparent,
            shape: BoxShape.circle,
            border: Border.all(
              color: isFilled ? _kAccent : Colors.white24,
              width: 2,
            ),
            boxShadow: isFilled ? [
              BoxShadow(
                color: _kAccent.withValues(alpha: 0.50),
                blurRadius: 8,
              ),
            ] : [],
          ),
        );
      }),
    );
  }
}

// ── Keypad ────────────────────────────────────────────────────────────────────
class _Keypad extends StatelessWidget {
  final void Function(String) onDigit;
  final VoidCallback onBackspace;
  final VoidCallback onClear;
  final bool enabled;

  const _Keypad({
    required this.onDigit,
    required this.onBackspace,
    required this.onClear,
    required this.enabled,
  });

  static const _keys = [
    '1','2','3','4','5','6','7','8','9','C','0','⌫',
  ];

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (_, c) {
        final tileW = (c.maxWidth - 16) / 3;
        final tileH = math.min(68.0, tileW * 0.60);
        return Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _keys.map((k) {
            return SizedBox(
              width: tileW, height: tileH,
              child: _KeyTile(
                label: k,
                enabled: enabled,
                onTap: () {
                  if (!enabled) { return; }
                  if (k == '⌫') { onBackspace(); }
                  else if (k == 'C') { onClear(); }
                  else { onDigit(k); }
                },
              ),
            );
          }).toList(),
        );
      },
    );
  }
}

class _KeyTile extends StatelessWidget {
  final String label;
  final bool enabled;
  final VoidCallback onTap;
  const _KeyTile({required this.label, required this.enabled, required this.onTap});

  bool get _isSpecial => label == '⌫' || label == 'C';

  @override
  Widget build(BuildContext context) {
    final isBackspace = label == '⌫';
    final isClear = label == 'C';

    Widget content;
    if (isBackspace) {
      content = Icon(Icons.backspace_outlined,
        color: enabled ? Colors.white70 : Colors.white24, size: 20);
    } else if (isClear) {
      content = Icon(Icons.refresh_rounded,
        color: enabled ? const Color(0xFFEF4444) : Colors.white24, size: 20);
    } else {
      content = Text(
        label,
        style: TextStyle(
          color: enabled ? Colors.white : Colors.white24,
          fontSize: 20,
          fontWeight: FontWeight.w700,
        ),
      );
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(12),
        splashColor: _kAccent.withValues(alpha: 0.15),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 100),
          decoration: BoxDecoration(
            color: _isSpecial
                ? Colors.white.withValues(alpha: 0.03)
                : _kTile,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: Colors.white.withValues(alpha: _isSpecial ? 0.04 : 0.07),
            ),
          ),
          child: Center(child: content),
        ),
      ),
    );
  }
}

// ── Action button ─────────────────────────────────────────────────────────────
class _ActionBtn extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback? onTap;
  final bool primary;
  const _ActionBtn({
    required this.label,
    required this.icon,
    required this.onTap,
    required this.primary,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        height: 50,
        decoration: BoxDecoration(
          gradient: primary && onTap != null
              ? const LinearGradient(
                  colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
                )
              : null,
          color: primary && onTap == null
              ? _kAccent.withValues(alpha: 0.25)
              : (!primary ? Colors.white.withValues(alpha: 0.06) : null),
          borderRadius: BorderRadius.circular(14),
          border: !primary
              ? Border.all(color: Colors.white.withValues(alpha: 0.07))
              : null,
          boxShadow: primary && onTap != null ? [
            BoxShadow(
              color: _kAccent.withValues(alpha: 0.35),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ] : [],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              label,
              style: TextStyle(
                color: onTap == null ? Colors.white30 : Colors.white,
                fontWeight: FontWeight.w800,
                fontSize: 14,
              ),
            ),
            const SizedBox(width: 8),
            Icon(icon,
              color: onTap == null ? Colors.white30 : Colors.white,
              size: 18,
            ),
          ],
        ),
      ),
    );
  }
}

// ── Colors ────────────────────────────────────────────────────────────────────
const _kBg    = Color(0xFF07080F);
const _kPanel = Color(0xFF0D0F1C);
const _kTile  = Color(0xFF161929);
const _kAccent = Color(0xFF6366F1);
const _kError  = Color(0xFFEF4444);
const _kTextSub = Color(0xFF8892B0);
