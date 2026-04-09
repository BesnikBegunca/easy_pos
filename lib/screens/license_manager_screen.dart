import 'package:flutter/material.dart';
import '../auth/license_service.dart';
import '../auth/session.dart';

class LicenseManagerScreen extends StatefulWidget {
  const LicenseManagerScreen({super.key});

  @override
  State<LicenseManagerScreen> createState() => _LicenseManagerScreenState();
}

class _LicenseManagerScreenState extends State<LicenseManagerScreen> {
  bool _loading = false;
  DateTime? _activationDate;
  DateTime? _expirationDate;

  @override
  void initState() {
    super.initState();
    _checkAccess();
  }

  Future<void> _checkAccess() async {
    await LicenseService.I.init();
    if (!LicenseService.I.developerAccessGranted) {
      if (mounted) {
        Navigator.of(context).pushReplacementNamed('/license-lock');
      }
      return;
    }
    await _loadLicense();
  }

  Future<void> _loadLicense() async {
    if (mounted) setState(() => _loading = true);
    await LicenseService.I.init();
    if (!mounted) return;
    setState(() {
      _activationDate = LicenseService.I.activationDate;
      _expirationDate = LicenseService.I.expirationDate;
      _loading = false;
    });
  }

  Future<void> _extendLicense() async {
    if (_loading) return;
    setState(() => _loading = true);
    try {
      await LicenseService.I.extendOneYear();
      LicenseService.I.revokeDeveloperAccess();
      Session.I.logout();
      if (!mounted) return;
      Navigator.of(context).pushReplacementNamed('/login');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _setLicenseDuration({
    int? months,
    Duration? duration,
    required String label,
  }) async {
    if (_loading) return;
    setState(() => _loading = true);
    try {
      if (months != null) {
        await LicenseService.I.setExpirationInMonths(months);
      } else if (duration != null) {
        await LicenseService.I.setExpirationFromNow(duration);
      }

      LicenseService.I.revokeDeveloperAccess();
      Session.I.logout();
      if (!mounted) return;
      Navigator.of(context).pushReplacementNamed('/login');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _formatDate(DateTime? value) {
    if (value == null) return '--';
    final day = value.day.toString().padLeft(2, '0');
    final month = value.month.toString().padLeft(2, '0');
    final year = value.year.toString();
    final hour = value.hour.toString().padLeft(2, '0');
    final minute = value.minute.toString().padLeft(2, '0');
    return '$day.$month.$year  •  $hour:$minute';
  }

  String _remainingText() {
    final expiration = _expirationDate;
    if (expiration == null) return 'Nuk ka të dhëna për skadimin.';
    final now = DateTime.now();
    final diff = expiration.difference(now);

    if (diff.isNegative) {
      return 'Licenca ka skaduar.';
    }

    if (diff.inDays >= 1) {
      return 'Mbeten ${diff.inDays} ditë aktive.';
    }
    if (diff.inHours >= 1) {
      return 'Mbeten ${diff.inHours} orë aktive.';
    }
    return 'Mbeten ${diff.inMinutes} minuta aktive.';
  }

  @override
  Widget build(BuildContext context) {
    final expired = LicenseService.I.isExpired;

    return Scaffold(
      backgroundColor: const Color(0xFF070B17),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF070B17), Color(0xFF0E1630), Color(0xFF151E3F)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Stack(
          children: [
            const _BackgroundGlow(top: -80, left: -40, size: 220),
            const _BackgroundGlow(
              bottom: -100,
              right: -50,
              size: 260,
              color: Color(0xFF3B82F6),
            ),
            SafeArea(
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 24,
                  ),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 760),
                    child: Column(
                      children: [
                        _GlassPanel(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    width: 64,
                                    height: 64,
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(20),
                                      gradient: const LinearGradient(
                                        colors: [
                                          Color(0xFF22C55E),
                                          Color(0xFF06B6D4),
                                        ],
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: const Color(
                                            0xFF06B6D4,
                                          ).withOpacity(0.28),
                                          blurRadius: 24,
                                          spreadRadius: 1,
                                        ),
                                      ],
                                    ),
                                    child: const Icon(
                                      Icons.verified_rounded,
                                      color: Colors.white,
                                      size: 32,
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        const Text(
                                          'License Manager',
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 28,
                                            fontWeight: FontWeight.w800,
                                            letterSpacing: -0.3,
                                          ),
                                        ),
                                        const SizedBox(height: 6),
                                        Text(
                                          expired
                                              ? 'Licenca ka skaduar. Duhet rinovim për ta vazhduar përdorimin.'
                                              : 'Panel premium për menaxhimin dhe rinovimin e licencës.',
                                          style: const TextStyle(
                                            color: Colors.white70,
                                            fontSize: 14.5,
                                            height: 1.5,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 24),
                              _StatusBanner(
                                expired: expired,
                                subtitle: _remainingText(),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 18),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: _GlassPanel(
                                padding: const EdgeInsets.all(22),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const _SectionTitle(
                                      title: 'Detajet e licencës',
                                      icon: Icons.schedule_rounded,
                                    ),
                                    const SizedBox(height: 18),
                                    _ModernInfoTile(
                                      icon: Icons.play_circle_fill_rounded,
                                      label: 'Data e aktivizimit',
                                      value: _formatDate(_activationDate),
                                    ),
                                    const SizedBox(height: 14),
                                    _ModernInfoTile(
                                      icon: Icons.event_busy_rounded,
                                      label: 'Data e skadimit',
                                      value: _formatDate(_expirationDate),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 18),
                        _GlassPanel(
                          padding: const EdgeInsets.all(22),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const _SectionTitle(
                                title: 'Shkurtore për testim',
                                icon: Icons.bolt_rounded,
                              ),
                              const SizedBox(height: 8),
                              const Text(
                                'Vendos kohëzgjatje të re të licencës me një klikim.',
                                style: TextStyle(
                                  color: Colors.white70,
                                  fontSize: 14,
                                  height: 1.5,
                                ),
                              ),
                              const SizedBox(height: 18),
                              Wrap(
                                spacing: 12,
                                runSpacing: 12,
                                children: [
                                  _DurationChip(
                                    label: '1 vit',
                                    icon: Icons.workspace_premium_rounded,
                                    enabled: !_loading,
                                    onTap: () => _setLicenseDuration(
                                      months: 12,
                                      label: '1 vit',
                                    ),
                                  ),
                                  _DurationChip(
                                    label: '6 muaj',
                                    icon: Icons.calendar_view_month_rounded,
                                    enabled: !_loading,
                                    onTap: () => _setLicenseDuration(
                                      months: 6,
                                      label: '6 muaj',
                                    ),
                                  ),
                                  _DurationChip(
                                    label: '3 muaj',
                                    icon: Icons.date_range_rounded,
                                    enabled: !_loading,
                                    onTap: () => _setLicenseDuration(
                                      months: 3,
                                      label: '3 muaj',
                                    ),
                                  ),
                                  _DurationChip(
                                    label: '1 muaj',
                                    icon: Icons.calendar_month_rounded,
                                    enabled: !_loading,
                                    onTap: () => _setLicenseDuration(
                                      months: 1,
                                      label: '1 muaj',
                                    ),
                                  ),
                                  _DurationChip(
                                    label: '1 javë',
                                    icon: Icons.view_week_rounded,
                                    enabled: !_loading,
                                    onTap: () => _setLicenseDuration(
                                      duration: const Duration(days: 7),
                                      label: '1 javë',
                                    ),
                                  ),
                                  _DurationChip(
                                    label: '1 orë',
                                    icon: Icons.access_time_filled_rounded,
                                    enabled: !_loading,
                                    onTap: () => _setLicenseDuration(
                                      duration: const Duration(hours: 1),
                                      label: '1 orë',
                                    ),
                                  ),
                                  _DurationChip(
                                    label: '1 minut',
                                    icon: Icons.timer_rounded,
                                    enabled: !_loading,
                                    onTap: () => _setLicenseDuration(
                                      duration: const Duration(minutes: 1),
                                      label: '1 minut',
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 18),
                        _GlassPanel(
                          padding: const EdgeInsets.all(22),
                          child: Column(
                            children: [
                              SizedBox(
                                width: double.infinity,
                                child: _PrimaryActionButton(
                                  loading: _loading,
                                  icon: Icons.autorenew_rounded,
                                  text: 'Rinovo për 1 vit',
                                  onTap: _extendLicense,
                                ),
                              ),
                              const SizedBox(height: 14),
                              SizedBox(
                                width: double.infinity,
                                child: _SecondaryActionButton(
                                  text: 'Kthehu tek hyrja',
                                  icon: Icons.login_rounded,
                                  enabled: !_loading,
                                  onTap: () {
                                    Session.I.logout();
                                    LicenseService.I.revokeDeveloperAccess();
                                    Navigator.of(
                                      context,
                                    ).pushReplacementNamed('/login');
                                  },
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BackgroundGlow extends StatelessWidget {
  final double? top;
  final double? left;
  final double? right;
  final double? bottom;
  final double size;
  final Color color;

  const _BackgroundGlow({
    this.top,
    this.left,
    this.right,
    this.bottom,
    required this.size,
    this.color = const Color(0xFF22C55E),
  });

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: top,
      left: left,
      right: right,
      bottom: bottom,
      child: IgnorePointer(
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: color.withOpacity(0.12),
            boxShadow: [
              BoxShadow(
                color: color.withOpacity(0.22),
                blurRadius: 120,
                spreadRadius: 35,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GlassPanel extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;

  const _GlassPanel({
    required this.child,
    this.padding = const EdgeInsets.all(20),
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        color: Colors.white.withOpacity(0.06),
        border: Border.all(color: Colors.white.withOpacity(0.10), width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.30),
            blurRadius: 35,
            offset: const Offset(0, 18),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;
  final IconData icon;

  const _SectionTitle({required this.title, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            color: Colors.white.withOpacity(0.08),
          ),
          child: Icon(icon, color: Colors.white, size: 21),
        ),
        const SizedBox(width: 12),
        Text(
          title,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _StatusBanner extends StatelessWidget {
  final bool expired;
  final String subtitle;

  const _StatusBanner({required this.expired, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    final Color tone = expired
        ? const Color(0xFFFF5A5F)
        : const Color(0xFF10B981);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        gradient: LinearGradient(
          colors: [tone.withOpacity(0.18), tone.withOpacity(0.08)],
        ),
        border: Border.all(color: tone.withOpacity(0.35)),
      ),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: tone.withOpacity(0.18),
            ),
            child: Icon(
              expired ? Icons.gpp_bad_rounded : Icons.gpp_good_rounded,
              color: tone,
              size: 28,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  expired ? 'Licenca e skaduar' : 'Licenca aktive',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: Colors.white70,
                    height: 1.5,
                    fontSize: 13.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ModernInfoTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _ModernInfoTile({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: Colors.white.withOpacity(0.045),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              gradient: LinearGradient(
                colors: [
                  Colors.white.withOpacity(0.12),
                  Colors.white.withOpacity(0.04),
                ],
              ),
            ),
            child: Icon(icon, color: Colors.white, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    color: Colors.white60,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  value,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DurationChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final bool enabled;

  const _DurationChip({
    required this.label,
    required this.icon,
    required this.onTap,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: enabled ? 1 : 0.55,
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            color: Colors.white.withOpacity(0.05),
            border: Border.all(color: Colors.white.withOpacity(0.08)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: Colors.white, size: 18),
              const SizedBox(width: 10),
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PrimaryActionButton extends StatelessWidget {
  final bool loading;
  final String text;
  final IconData icon;
  final VoidCallback onTap;

  const _PrimaryActionButton({
    required this.loading,
    required this.text,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: loading ? null : onTap,
      borderRadius: BorderRadius.circular(20),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        padding: const EdgeInsets.symmetric(vertical: 17, horizontal: 18),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: const LinearGradient(
            colors: [Color(0xFF12B981), Color(0xFF06B6D4)],
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF06B6D4).withOpacity(0.25),
              blurRadius: 24,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Center(
          child: loading
              ? const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.2,
                    color: Colors.white,
                  ),
                )
              : Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(icon, color: Colors.white, size: 20),
                    const SizedBox(width: 10),
                    Text(
                      text,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15.5,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}

class _SecondaryActionButton extends StatelessWidget {
  final String text;
  final IconData icon;
  final VoidCallback onTap;
  final bool enabled;

  const _SecondaryActionButton({
    required this.text,
    required this.icon,
    required this.onTap,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: enabled ? 1 : 0.55,
      child: OutlinedButton.icon(
        onPressed: enabled ? onTap : null,
        icon: Icon(icon, color: Colors.white),
        label: Text(
          text,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w700,
          ),
        ),
        style: OutlinedButton.styleFrom(
          minimumSize: const Size.fromHeight(56),
          side: BorderSide(color: Colors.white.withOpacity(0.12)),
          backgroundColor: Colors.white.withOpacity(0.03),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
        ),
      ),
    );
  }
}
