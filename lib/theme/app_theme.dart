import 'package:flutter/material.dart';
import '../util/money.dart';

class AppTheme {
  // ── Dark Premium Base ────────────────────────────────────────────────────
  static const Color bg = Color(0xFF0B0F14);
  static const Color surface = Color(0xFF11161D);
  static const Color card = Color(0xFF171D25);
  static const Color cardAlt = Color(0xFF1D242D);
  static const Color border = Color(0xFF2A3440);

  // ── Brand / Accent: Green + Orange ───────────────────────────────────────
  static const Color primary = Color(0xFF22C55E);
  static const Color primaryLight = Color(0xFF4ADE80);
  static const Color greenDark = Color(0xFF16A34A);

  static const Color orange = Color(0xFFF59E0B);
  static const Color orangeLight = Color(0xFFFBBF24);
  static const Color orangeDark = Color(0xFFD97706);

  // ── Semantic ─────────────────────────────────────────────────────────────
  static const Color success = Color(0xFF22C55E);
  static const Color successDim = Color(0xFF16A34A);
  static const Color warning = Color(0xFFF59E0B);
  static const Color warningDim = Color(0xFFD97706);
  static const Color error = Color(0xFFEF4444);
  static const Color errorDim = Color(0xFFDC2626);
  static const Color info = Color(0xFF38BDF8);

  // ── Text ─────────────────────────────────────────────────────────────────
  static const Color textPrimary = Color(0xFFF8FAFC);
  static const Color textSecondary = Color(0xFFB6C2CF);
  static const Color textMuted = Color(0xFF7C8A9A);

  // ── Legacy aliases ───────────────────────────────────────────────────────
  static const Color background = bg;
  static const Color tile = card;
  static const Color tileAlt = cardAlt;
  static const Color borderColor = border;

  // ── Gradients ────────────────────────────────────────────────────────────
  static const LinearGradient primaryGrad = LinearGradient(
    colors: [primary, greenDark],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient successGrad = LinearGradient(
    colors: [success, primaryLight],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient warningGrad = LinearGradient(
    colors: [orange, orangeLight],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient darkCardGrad = LinearGradient(
    colors: [Color(0xFF1C232C), Color(0xFF151B22)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // ── Radius ───────────────────────────────────────────────────────────────
  static const BorderRadius borderRadius = BorderRadius.all(
    Radius.circular(18),
  );
  static const BorderRadius radiusSmall = BorderRadius.all(Radius.circular(12));
  static const BorderRadius radiusLarge = BorderRadius.all(Radius.circular(26));
  static const BorderRadius radiusXL = BorderRadius.all(Radius.circular(32));

  // ── Shadows ──────────────────────────────────────────────────────────────
  static List<BoxShadow> get shadowSm => [
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.26),
      blurRadius: 10,
      offset: const Offset(0, 4),
    ),
  ];

  static List<BoxShadow> get shadowMd => [
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.34),
      blurRadius: 22,
      offset: const Offset(0, 10),
    ),
  ];

  static List<BoxShadow> get shadowGlow => [
    BoxShadow(
      color: primary.withValues(alpha: 0.18),
      blurRadius: 22,
      spreadRadius: 1,
    ),
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.35),
      blurRadius: 16,
      offset: const Offset(0, 8),
    ),
  ];

  static List<BoxShadow> shadowGlowColor(Color c, {double a = 0.20}) => [
    BoxShadow(color: c.withValues(alpha: a), blurRadius: 20, spreadRadius: 1),
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.30),
      blurRadius: 14,
      offset: const Offset(0, 6),
    ),
  ];

  // ── Spacing ──────────────────────────────────────────────────────────────
  static const double spaceXS = 4;
  static const double spaceS = 8;
  static const double spaceM = 16;
  static const double spaceL = 24;
  static const double spaceXL = 32;

  // ── Typography ───────────────────────────────────────────────────────────
  static const TextStyle displayLarge = TextStyle(
    fontSize: 32,
    fontWeight: FontWeight.w800,
    color: textPrimary,
    letterSpacing: -0.5,
  );

  static const TextStyle displayMedium = TextStyle(
    fontSize: 26,
    fontWeight: FontWeight.w800,
    color: textPrimary,
    letterSpacing: -0.4,
  );

  static const TextStyle titleLarge = TextStyle(
    fontSize: 22,
    fontWeight: FontWeight.w700,
    color: textPrimary,
    letterSpacing: -0.2,
  );

  static const TextStyle titleMedium = TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.w700,
    color: textPrimary,
    letterSpacing: -0.2,
  );

  static const TextStyle titleSmall = TextStyle(
    fontSize: 15,
    fontWeight: FontWeight.w700,
    color: textPrimary,
  );

  static const TextStyle bodyLarge = TextStyle(
    fontSize: 15,
    fontWeight: FontWeight.w400,
    color: textPrimary,
    height: 1.45,
  );

  static const TextStyle bodyMedium = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w400,
    color: textPrimary,
    height: 1.40,
  );

  static const TextStyle bodySmall = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w500,
    color: textSecondary,
  );

  static const TextStyle labelLarge = TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.w700,
    color: textPrimary,
    letterSpacing: 0.25,
  );

  static const TextStyle caption = TextStyle(
    fontSize: 11,
    fontWeight: FontWeight.w600,
    color: textMuted,
    letterSpacing: 0.4,
  );

  // ── ThemeData ────────────────────────────────────────────────────────────
  static ThemeData darkOrangeTheme() {
    final base = ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: bg,
      primaryColor: primary,
      fontFamily: 'Roboto',
      colorScheme: const ColorScheme.dark(
        primary: primary,
        secondary: orange,
        surface: surface,
        error: error,
        onPrimary: Colors.white,
        onSecondary: Colors.white,
        onSurface: textPrimary,
        onError: Colors.white,
      ),
    );

    return base.copyWith(
      cardColor: card,
      dividerColor: border,
      splashColor: primary.withValues(alpha: 0.10),
      highlightColor: primary.withValues(alpha: 0.05),

      appBarTheme: const AppBarTheme(
        backgroundColor: surface,
        foregroundColor: textPrimary,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: titleMedium,
        iconTheme: IconThemeData(color: textPrimary),
      ),

      snackBarTheme: SnackBarThemeData(
        backgroundColor: cardAlt,
        contentTextStyle: bodyMedium,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: borderRadius),
        elevation: 10,
      ),

      dialogTheme: DialogThemeData(
        backgroundColor: surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: radiusLarge),
        elevation: 20,
      ),

      cardTheme: CardThemeData(
        color: card,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: borderRadius,
          side: const BorderSide(color: border),
        ),
        margin: EdgeInsets.zero,
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: cardAlt,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
        hintStyle: bodyMedium.copyWith(color: textMuted),
        labelStyle: bodyMedium.copyWith(color: textSecondary),
        border: OutlineInputBorder(
          borderRadius: borderRadius,
          borderSide: const BorderSide(color: border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: borderRadius,
          borderSide: const BorderSide(color: border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: borderRadius,
          borderSide: const BorderSide(color: primary, width: 1.4),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: borderRadius,
          borderSide: const BorderSide(color: error),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: borderRadius,
          borderSide: const BorderSide(color: error, width: 1.4),
        ),
      ),

      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          elevation: 0,
          backgroundColor: primary,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          textStyle: labelLarge,
          shape: RoundedRectangleBorder(borderRadius: borderRadius),
        ),
      ),

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: textPrimary,
          side: BorderSide(color: orange.withValues(alpha: 0.35)),
          backgroundColor: orange.withValues(alpha: 0.08),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          textStyle: labelLarge,
          shape: RoundedRectangleBorder(borderRadius: borderRadius),
        ),
      ),

      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: orange,
          textStyle: labelLarge,
          shape: RoundedRectangleBorder(borderRadius: borderRadius),
        ),
      ),

      chipTheme: ChipThemeData(
        backgroundColor: cardAlt,
        selectedColor: primary.withValues(alpha: 0.16),
        disabledColor: border,
        deleteIconColor: textSecondary,
        labelStyle: bodySmall.copyWith(color: textPrimary),
        secondaryLabelStyle: bodySmall.copyWith(color: primary),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(999),
          side: BorderSide(color: orange.withValues(alpha: 0.18)),
        ),
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

// ── Status Badge ────────────────────────────────────────────────────────────
class StatusBadge extends StatelessWidget {
  final String label;
  final Color color;
  final double fontSize;

  const StatusBadge({
    super.key,
    required this.label,
    required this.color,
    this.fontSize = 9.5,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.28)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: fontSize,
          fontWeight: FontWeight.w800,
          color: color,
          letterSpacing: 0.4,
        ),
      ),
    );
  }
}

// ── Premium Table Tile ──────────────────────────────────────────────────────
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
        statusIcon = Icons.check_circle_rounded;
        break;
      default:
        statusColor = AppTheme.textMuted;
        statusText = 'E LIRË';
        statusIcon = Icons.event_seat_rounded;
    }

    final bool isOccupied = status == 'open';
    final bool isPaid = status == 'paid';

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppTheme.borderRadius,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOut,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            gradient: isOccupied
                ? LinearGradient(
                    colors: [const Color(0xFF2A1F08), const Color(0xFF1A1F26)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  )
                : isPaid
                ? LinearGradient(
                    colors: [const Color(0xFF0E2216), const Color(0xFF171D25)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  )
                : AppTheme.darkCardGrad,
            borderRadius: AppTheme.borderRadius,
            border: Border.all(
              color: isOccupied
                  ? AppTheme.warning.withValues(alpha: 0.34)
                  : isPaid
                  ? AppTheme.success.withValues(alpha: 0.30)
                  : AppTheme.border,
              width: isOccupied || isPaid ? 1.4 : 1,
            ),
            boxShadow: isOccupied
                ? AppTheme.shadowGlowColor(AppTheme.warning, a: 0.16)
                : isPaid
                ? AppTheme.shadowGlowColor(AppTheme.success, a: 0.16)
                : AppTheme.shadowSm,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          statusColor.withValues(alpha: 0.22),
                          statusColor.withValues(alpha: 0.10),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(13),
                      border: Border.all(
                        color: statusColor.withValues(alpha: 0.18),
                      ),
                    ),
                    child: Icon(statusIcon, size: 20, color: statusColor),
                  ),
                  const Spacer(),
                  StatusBadge(label: statusText, color: statusColor),
                ],
              ),
              const Spacer(),
              Text(
                name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTheme.titleSmall.copyWith(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                isOccupied
                    ? 'Tavolina aktive'
                    : isPaid
                    ? 'Porosia e mbyllur'
                    : 'Gati për porosi',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTheme.bodySmall.copyWith(
                  color: AppTheme.textSecondary,
                ),
              ),
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: isOccupied
                      ? AppTheme.warning.withValues(alpha: 0.12)
                      : isPaid
                      ? AppTheme.success.withValues(alpha: 0.12)
                      : AppTheme.cardAlt,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: isOccupied
                        ? AppTheme.warning.withValues(alpha: 0.20)
                        : isPaid
                        ? AppTheme.success.withValues(alpha: 0.20)
                        : AppTheme.border.withValues(alpha: 0.7),
                  ),
                ),
                child: Text(
                  moneyFromCents(totalCents),
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: isOccupied
                        ? AppTheme.orangeLight
                        : isPaid
                        ? AppTheme.primaryLight
                        : AppTheme.textSecondary,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
