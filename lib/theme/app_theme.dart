import 'package:flutter/material.dart';
import '../util/money.dart';

class AppTheme {
  // Colors (Dark + Orange)
  static const Color primary = Color(0xFFFF8C42);
  static const Color primaryDark = Color(0xFFE56F1F);
  static const Color secondary = Color(0xFF9CA3AF);

  static const Color success = Color(0xFF22C55E);
  static const Color warning = Color(0xFFFFA726);
  static const Color error = Color(0xFFEF4444);

  static const Color background = Color(0xFF0B0B0D);
  static const Color surface = Color(0xFF121214);
  static const Color tile = Color(0xFF1A1A1D);
  static const Color tileAlt = Color(0xFF202126);

  static const Color textPrimary = Colors.white;
  static const Color textSecondary = Color(0xFFB0B3B8);
  static const Color borderColor = Color(0x33FF8C42);

  // Spacing
  static const double spaceXS = 4;
  static const double spaceS = 8;
  static const double spaceM = 16;
  static const double spaceL = 24;
  static const double spaceXL = 32;

  // Border radius
  static const BorderRadius borderRadius = BorderRadius.all(
    Radius.circular(12),
  );
  static const BorderRadius radiusSmall = BorderRadius.all(Radius.circular(8));

  static Border get border => Border.all(color: borderColor);

  // Text styles
  static const TextStyle titleLarge = TextStyle(
    fontSize: 24,
    fontWeight: FontWeight.w700,
    color: textPrimary,
  );

  static const TextStyle titleMedium = TextStyle(
    fontSize: 20,
    fontWeight: FontWeight.w600,
    color: textPrimary,
  );

  static const TextStyle titleSmall = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w600,
    color: textPrimary,
  );

  static const TextStyle bodyLarge = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w400,
    color: textPrimary,
  );

  static const TextStyle bodyMedium = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w400,
    color: textPrimary,
  );

  static const TextStyle bodySmall = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w400,
    color: textSecondary,
  );

  static ThemeData darkOrangeTheme() {
    return ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: background,
      primaryColor: primary,
      colorScheme: const ColorScheme.dark(
        primary: primary,
        secondary: warning,
        surface: surface,
        error: error,
      ),
      cardColor: tile,
      dividerColor: borderColor,
      appBarTheme: const AppBarTheme(
        backgroundColor: surface,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: textPrimary,
          fontSize: 20,
          fontWeight: FontWeight.w700,
        ),
        iconTheme: IconThemeData(color: primary),
      ),
      textTheme: const TextTheme(
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
      case 'free':
        statusColor = const Color(0xFF6B7280);
        statusText = 'FREE';
        statusIcon = Icons.event_seat_outlined;
        break;
      case 'open':
        statusColor = AppTheme.warning;
        statusText = 'OPEN';
        statusIcon = Icons.restaurant_menu;
        break;
      case 'paid':
        statusColor = AppTheme.success;
        statusText = 'PAID';
        statusIcon = Icons.check_circle_outline;
        break;
      default:
        statusColor = Colors.grey;
        statusText = 'UNKNOWN';
        statusIcon = Icons.help_outline;
    }

    return InkWell(
      onTap: onTap,
      borderRadius: AppTheme.borderRadius,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.all(AppTheme.spaceM),
        decoration: BoxDecoration(
          color: AppTheme.tile,
          borderRadius: AppTheme.borderRadius,
          border: Border.all(
            color: status == 'free'
                ? Colors.white.withOpacity(0.06)
                : statusColor.withOpacity(0.35),
            width: 1.2,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.28),
              blurRadius: 12,
              offset: const Offset(0, 6),
            ),
            if (status != 'free')
              BoxShadow(
                color: statusColor.withOpacity(0.10),
                blurRadius: 16,
                spreadRadius: 1,
              ),
          ],
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AppTheme.tileAlt,
              status == 'free' ? AppTheme.tile : statusColor.withOpacity(0.10),
            ],
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: statusColor.withOpacity(0.14),
                borderRadius: AppTheme.radiusSmall,
              ),
              child: Icon(statusIcon, size: 22, color: statusColor),
            ),
            const Spacer(),
            Text(
              name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTheme.bodyMedium.copyWith(
                fontWeight: FontWeight.w700,
                color: AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: AppTheme.spaceXS),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: statusColor.withOpacity(0.14),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: statusColor.withOpacity(0.22)),
              ),
              child: Text(
                statusText,
                style: TextStyle(
                  fontSize: 10,
                  color: statusColor,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.4,
                ),
              ),
            ),
            if (status == 'open') ...[
              const SizedBox(height: AppTheme.spaceS),
              Text(
                moneyFromCents(totalCents),
                style: AppTheme.bodySmall.copyWith(
                  color: AppTheme.primary,
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
