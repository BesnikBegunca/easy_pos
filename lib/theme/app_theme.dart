import 'package:flutter/material.dart';
import '../util/money.dart';

class AppTheme {
  // Colors (Dark Mode matching login)
  static const Color primary = Color(0xFF2F6BFF);
  static const Color secondary = Color(0xFF64748B);
  static const Color success = Color(0xFF10B981);
  static const Color warning = Color(0xFFF59E0B);
  static const Color error = Color(0xFFEF4444);
  static const Color background = Color(0xFF080C10);
  static const Color surface = Color(0xFF0D1217);
  static const Color tile = Color(0xFF0F1419);

  // Spacing
  static const double spaceXS = 4;
  static const double spaceS = 8;
  static const double spaceM = 16;
  static const double spaceL = 24;
  static const double spaceXL = 32;

  // Border radius
  static const BorderRadius borderRadius = BorderRadius.all(Radius.circular(8));
  static Border get border => Border.all(color: Colors.grey.withOpacity(0.2));

  // Text styles (Dark Mode)
  static const TextStyle titleLarge = TextStyle(
    fontSize: 24,
    fontWeight: FontWeight.w700,
    color: Colors.white,
  );

  static const TextStyle titleMedium = TextStyle(
    fontSize: 20,
    fontWeight: FontWeight.w600,
    color: Colors.white,
  );

  static const TextStyle titleSmall = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w600,
    color: Colors.white,
  );

  static const TextStyle bodyLarge = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w400,
    color: Colors.white,
  );

  static const TextStyle bodyMedium = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w400,
    color: Colors.white,
  );

  static const TextStyle bodySmall = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w400,
    color: Colors.white,
  );
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

    switch (status) {
      case 'free':
        statusColor = Colors.grey;
        statusText = 'FREE';
        break;
      case 'open':
        statusColor = AppTheme.warning;
        statusText = 'OPEN';
        break;
      case 'paid':
        statusColor = AppTheme.success;
        statusText = 'PAID';
        break;
      default:
        statusColor = Colors.grey;
        statusText = 'UNKNOWN';
    }

    return InkWell(
      onTap: onTap,
      borderRadius: AppTheme.borderRadius,
      child: Container(
        padding: const EdgeInsets.all(AppTheme.spaceM), // reduced padding
        decoration: BoxDecoration(
          color: statusColor.withOpacity(0.1),
          borderRadius: AppTheme.borderRadius,
          border: Border.all(color: statusColor.withOpacity(0.2)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              Icons.table_restaurant,
              size: 24,
              color: statusColor,
            ), // smaller icon
            const Spacer(),
            Text(
              name,
              style: AppTheme.bodySmall.copyWith(fontWeight: FontWeight.w600),
            ), // smaller font
            const SizedBox(height: AppTheme.spaceXS),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 4,
                vertical: 1,
              ), // smaller padding
              decoration: BoxDecoration(
                color: statusColor.withOpacity(0.2),
                borderRadius: BorderRadius.circular(3), // smaller radius
              ),
              child: Text(
                statusText,
                style: TextStyle(
                  fontSize: 9, // smaller font
                  color: statusColor,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            if (status == 'open') ...[
              const SizedBox(height: AppTheme.spaceXS), // smaller space
              Text(
                moneyFromCents(totalCents),
                style: AppTheme.bodySmall.copyWith(
                  // smaller font
                  color: statusColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
