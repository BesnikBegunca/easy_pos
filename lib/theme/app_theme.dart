import 'package:flutter/material.dart';
import '../util/money.dart';

class AppTheme {
  // ── Core Palette ─────────────────────────────────────────────────────────
  static const Color bg         = Color(0xFF07080F);
  static const Color surface    = Color(0xFF0D0F1C);
  static const Color card       = Color(0xFF111327);
  static const Color cardAlt    = Color(0xFF161929);
  static const Color border     = Color(0xFF1E2340);

  // ── Brand / Accent ────────────────────────────────────────────────────────
  static const Color primary      = Color(0xFF6366F1);
  static const Color primaryLight = Color(0xFF818CF8);
  static const Color violet       = Color(0xFF8B5CF6);
  static const Color violet2      = Color(0xFFA78BFA);

  // ── Semantic ──────────────────────────────────────────────────────────────
  static const Color success    = Color(0xFF10B981);
  static const Color successDim = Color(0xFF059669);
  static const Color warning    = Color(0xFFF59E0B);
  static const Color warningDim = Color(0xFFD97706);
  static const Color error      = Color(0xFFEF4444);
  static const Color errorDim   = Color(0xFFDC2626);
  static const Color info       = Color(0xFF38BDF8);

  // ── Text ──────────────────────────────────────────────────────────────────
  static const Color textPrimary   = Color(0xFFF1F5F9);
  static const Color textSecondary = Color(0xFF8892B0);
  static const Color textMuted     = Color(0xFF3D4A6B);

  // ── Legacy aliases ────────────────────────────────────────────────────────
  static const Color background  = bg;
  static const Color tile        = card;
  static const Color tileAlt     = cardAlt;
  static const Color borderColor = border;

  // ── Gradients ─────────────────────────────────────────────────────────────
  static const LinearGradient primaryGrad = LinearGradient(
    colors: [primary, violet],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  static const LinearGradient successGrad = LinearGradient(
    colors: [success, Color(0xFF34D399)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  static const LinearGradient warningGrad = LinearGradient(
    colors: [warning, Color(0xFFFBBF24)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // ── Radius ────────────────────────────────────────────────────────────────
  static const BorderRadius borderRadius = BorderRadius.all(Radius.circular(16));
  static const BorderRadius radiusSmall  = BorderRadius.all(Radius.circular(10));
  static const BorderRadius radiusLarge  = BorderRadius.all(Radius.circular(24));
  static const BorderRadius radiusXL     = BorderRadius.all(Radius.circular(32));

  // ── Shadows ───────────────────────────────────────────────────────────────
  static List<BoxShadow> get shadowSm => [
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.30),
      blurRadius: 8,
      offset: const Offset(0, 4),
    ),
  ];
  static List<BoxShadow> get shadowMd => [
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.40),
      blurRadius: 20,
      offset: const Offset(0, 8),
    ),
  ];
  static List<BoxShadow> get shadowGlow => [
    BoxShadow(color: primary.withValues(alpha: 0.20), blurRadius: 24),
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.40),
      blurRadius: 16,
      offset: const Offset(0, 8),
    ),
  ];
  static List<BoxShadow> shadowGlowColor(Color c, {double a = 0.22}) => [
    BoxShadow(color: c.withValues(alpha: a), blurRadius: 20, spreadRadius: 1),
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.35),
      blurRadius: 12,
      offset: const Offset(0, 6),
    ),
  ];

  // ── Spacing ───────────────────────────────────────────────────────────────
  static const double spaceXS = 4;
  static const double spaceS  = 8;
  static const double spaceM  = 16;
  static const double spaceL  = 24;
  static const double spaceXL = 32;

  // ── Typography ────────────────────────────────────────────────────────────
  static const TextStyle displayLarge = TextStyle(
    fontSize: 32, fontWeight: FontWeight.w800,
    color: textPrimary, letterSpacing: -0.5,
  );
  static const TextStyle displayMedium = TextStyle(
    fontSize: 26, fontWeight: FontWeight.w800,
    color: textPrimary, letterSpacing: -0.5,
  );
  static const TextStyle titleLarge = TextStyle(
    fontSize: 22, fontWeight: FontWeight.w700,
    color: textPrimary, letterSpacing: -0.3,
  );
  static const TextStyle titleMedium = TextStyle(
    fontSize: 18, fontWeight: FontWeight.w700,
    color: textPrimary, letterSpacing: -0.2,
  );
  static const TextStyle titleSmall = TextStyle(
    fontSize: 15, fontWeight: FontWeight.w700,
    color: textPrimary,
  );
  static const TextStyle bodyLarge = TextStyle(
    fontSize: 15, fontWeight: FontWeight.w400, color: textPrimary,
  );
  static const TextStyle bodyMedium = TextStyle(
    fontSize: 14, fontWeight: FontWeight.w400, color: textPrimary,
  );
  static const TextStyle bodySmall = TextStyle(
    fontSize: 12, fontWeight: FontWeight.w400, color: textSecondary,
  );
  static const TextStyle labelLarge = TextStyle(
    fontSize: 13, fontWeight: FontWeight.w700,
    color: textPrimary, letterSpacing: 0.3,
  );
  static const TextStyle caption = TextStyle(
    fontSize: 11, fontWeight: FontWeight.w500,
    color: textMuted, letterSpacing: 0.5,
  );

  // ── ThemeData ─────────────────────────────────────────────────────────────
  static ThemeData darkOrangeTheme() {
    return ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: bg,
      primaryColor: primary,
      colorScheme: const ColorScheme.dark(
        primary: primary,
        secondary: violet,
        surface: surface,
        error: error,
        onPrimary: Colors.white,
        onSurface: textPrimary,
      ),
      cardColor: card,
      dividerColor: border,
      splashColor: Color(0x146366F1),
      highlightColor: Color(0x0A6366F1),
      appBarTheme: const AppBarTheme(
        backgroundColor: surface,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: titleMedium,
        iconTheme: IconThemeData(color: primary),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: cardAlt,
        contentTextStyle: bodyMedium,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: borderRadius),
        elevation: 8,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: radiusLarge),
        elevation: 24,
      ),
      textTheme: const TextTheme(
        displayLarge: displayLarge,
        displayMedium: displayMedium,
        headlineLarge: titleLarge,
        headlineMedium: titleMedium,
        titleMedium: titleSmall,
        bodyLarge: bodyLarge,
        bodyMedium: bodyMedium,
        bodySmall: bodySmall,
      ),
    );
  }
}

// ── Status Badge ──────────────────────────────────────────────────────────────
class StatusBadge extends StatelessWidget {
  final String label;
  final Color color;
  final double fontSize;
  const StatusBadge({
    super.key,
    required this.label,
    required this.color,
    this.fontSize = 9,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.30)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: fontSize,
          fontWeight: FontWeight.w800,
          color: color,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

// ── Legacy AppTableTile ───────────────────────────────────────────────────────
class AppTableTile extends StatelessWidget {
  final String name;
  final String status;
  final int totalCents;
  final VoidCallback onTap;

  const AppTableTile({
    super.key,
    required this.name,
    required this.status,
    required this.totalCents,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    Color statusColor;
    String statusText;
    IconData statusIcon;
    switch (status) {
      case 'open':
        statusColor = AppTheme.warning;
        statusText = 'E HAPUR';
        statusIcon = Icons.restaurant_rounded;
        break;
      case 'paid':
        statusColor = AppTheme.success;
        statusText = 'PAGUAR';
        statusIcon = Icons.check_circle_outline_rounded;
        break;
      default:
        statusColor = AppTheme.textMuted;
        statusText = 'E LIRË';
        statusIcon = Icons.event_seat_rounded;
    }
    final isOccupied = status == 'open';
    return InkWell(
      onTap: onTap,
      borderRadius: AppTheme.borderRadius,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: isOccupied
                ? [const Color(0xFF1A1400), AppTheme.card]
                : [AppTheme.cardAlt, AppTheme.card],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: AppTheme.borderRadius,
          border: Border.all(
            color: isOccupied
                ? AppTheme.warning.withValues(alpha: 0.40)
                : AppTheme.border,
            width: isOccupied ? 1.5 : 1,
          ),
          boxShadow: isOccupied
              ? AppTheme.shadowGlowColor(AppTheme.warning)
              : AppTheme.shadowSm,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 32, height: 32,
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(statusIcon, size: 16, color: statusColor),
                ),
                const Spacer(),
                StatusBadge(label: statusText, color: statusColor),
              ],
            ),
            const Spacer(),
            Text(name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTheme.titleSmall,
            ),
            if (isOccupied) ...[
              const SizedBox(height: 4),
              Text(
                moneyFromCents(totalCents),
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.warning,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
