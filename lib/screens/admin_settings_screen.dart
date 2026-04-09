import 'package:flutter/material.dart';
import '../data/dao_settings.dart';
import '../theme/app_theme.dart';

class AdminSettingsScreen extends StatefulWidget {
  const AdminSettingsScreen({super.key});

  @override
  State<AdminSettingsScreen> createState() => _AdminSettingsScreenState();
}

class _AdminSettingsScreenState extends State<AdminSettingsScreen> {
  bool _loading = true;
  int _tableColumns = SettingsDao.defaultTableColumns;
  int _productColumns = SettingsDao.defaultProductColumns;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final tc = await SettingsDao.I.getInt(
      SettingsDao.tableGridColumns,
      SettingsDao.defaultTableColumns,
    );
    final pc = await SettingsDao.I.getInt(
      SettingsDao.productGridColumns,
      SettingsDao.defaultProductColumns,
    );
    if (!mounted) return;
    setState(() {
      _tableColumns = tc;
      _productColumns = pc;
      _loading = false;
    });
  }

  Future<void> _saveTableColumns(int v) async {
    setState(() => _tableColumns = v);
    await SettingsDao.I.setInt(SettingsDao.tableGridColumns, v);
  }

  Future<void> _saveProductColumns(int v) async {
    setState(() => _productColumns = v);
    await SettingsDao.I.setInt(SettingsDao.productGridColumns, v);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator(color: AppTheme.primary));
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Cilësimet e ekranit',
                style: AppTheme.titleMedium.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 6),
              Text(
                'Rregullon numrin e kolonave në rrjetat e tavolinave dhe produkteve.',
                style: AppTheme.bodySmall.copyWith(color: AppTheme.textSecondary),
              ),
              const SizedBox(height: 24),

              _SettingCard(
                icon: Icons.table_restaurant_rounded,
                iconColor: AppTheme.primary,
                title: 'Kolonat e tavolinave',
                subtitle: 'Sa tavolina shfaqen në një rresht',
                value: _tableColumns,
                min: 3,
                max: 12,
                onChanged: _saveTableColumns,
              ),

              const SizedBox(height: 16),

              _SettingCard(
                icon: Icons.local_cafe_rounded,
                iconColor: AppTheme.success,
                title: 'Kolonat e produkteve',
                subtitle: 'Sa produkte shfaqen në një rresht',
                value: _productColumns,
                min: 2,
                max: 8,
                onChanged: _saveProductColumns,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SettingCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final int value;
  final int min;
  final int max;
  final ValueChanged<int> onChanged;

  const _SettingCard({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppTheme.tile,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppTheme.borderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: iconColor, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: AppTheme.bodyMedium.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      subtitle,
                      style: AppTheme.bodySmall.copyWith(
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  gradient: AppTheme.primaryGrad,
                  borderRadius: BorderRadius.circular(999),
                  boxShadow: AppTheme.shadowGlowColor(AppTheme.primary, a: 0.25),
                ),
                child: Text(
                  '$value',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 16,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Text(
                '$min',
                style: AppTheme.bodySmall.copyWith(color: AppTheme.textSecondary),
              ),
              Expanded(
                child: Slider(
                  value: value.toDouble(),
                  min: min.toDouble(),
                  max: max.toDouble(),
                  divisions: max - min,
                  activeColor: AppTheme.primary,
                  inactiveColor: AppTheme.primary.withValues(alpha: 0.15),
                  onChanged: (v) => onChanged(v.round()),
                ),
              ),
              Text(
                '$max',
                style: AppTheme.bodySmall.copyWith(color: AppTheme.textSecondary),
              ),
            ],
          ),
          // Preview dots
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(value, (i) {
                return Container(
                  margin: const EdgeInsets.symmetric(horizontal: 2),
                  width: (200 / value).clamp(8, 28).toDouble(),
                  height: (200 / value).clamp(8, 28).toDouble(),
                  decoration: BoxDecoration(
                    color: iconColor.withValues(alpha: 0.25),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: iconColor.withValues(alpha: 0.40)),
                  ),
                );
              }),
            ),
          ),
        ],
      ),
    );
  }
}
