import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';

class _VirtualTableSlot extends StatelessWidget {
  final int slotNum;
  final VoidCallback onTap;

  const _VirtualTableSlot({
    required this.slotNum,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: AppTheme.borderRadius,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppTheme.tileAlt.withValues(alpha: 0.5),
          borderRadius: AppTheme.borderRadius,
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.08),
            width: 1,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.table_restaurant_outlined,
              size: 20,
              color: Colors.white.withValues(alpha: 0.3),
            ),
            const SizedBox(height: 6),
            Text(
              'Slot $slotNum',
              style: AppTheme.bodySmall.copyWith(
                color: Colors.white.withValues(alpha: 0.4),
                fontWeight: FontWeight.w500,
                fontSize: 11,
              ),
            ),
            Text(
              'Krijo',
              style: AppTheme.bodySmall.copyWith(
                color: Colors.white.withValues(alpha: 0.25),
                fontSize: 9,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

