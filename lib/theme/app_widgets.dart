import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// A basic scaffold with consistent layout for the app
class AppScaffold extends StatelessWidget {
  final AppTopBar? topBar;
  final Widget body;
  final Widget? bottomNav;

  const AppScaffold({
    super.key,
    this.topBar,
    required this.body,
    this.bottomNav,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: topBar != null
          ? AppBar(
              leading: topBar!.leading,
              title: Text(topBar!.title, style: AppTheme.titleMedium),
              backgroundColor: AppTheme.surface,
              elevation: 0,
              foregroundColor: AppTheme.primary,
              actions: topBar!.actions,
            )
          : null,
      body: body,
      bottomNavigationBar: bottomNav,
    );
  }
}

/// Top bar widget for consistent header
class AppTopBar extends StatelessWidget {
  final String title;
  final List<Widget>? actions;
  final Widget? leading;

  const AppTopBar({super.key, required this.title, this.actions, this.leading});

  @override
  Widget build(BuildContext context) {
    return AppBar(
      backgroundColor: AppTheme.surface,
      elevation: 0,
      leading: leading,
      title: Text(title, style: AppTheme.titleMedium),
      actions: actions,
    );
  }
}

/// A modern card widget
class AppCard extends StatelessWidget {
  final Widget child;
  final EdgeInsets? padding;
  final VoidCallback? onTap;

  const AppCard({super.key, required this.child, this.padding, this.onTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.tile,
        borderRadius: AppTheme.borderRadius,
        border: Border.all(color: AppTheme.borderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.35),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: InkWell(
        borderRadius: AppTheme.borderRadius,
        onTap: onTap,
        child: Padding(
          padding: padding ?? const EdgeInsets.all(AppTheme.spaceM),
          child: child,
        ),
      ),
    );
  }
}

/// Primary action button
class AppPrimaryButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;

  const AppPrimaryButton({
    super.key,
    required this.label,
    this.onPressed,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return ElevatedButton.icon(
      onPressed: onPressed,
      icon: icon != null ? Icon(icon, size: 20) : const SizedBox.shrink(),
      label: Text(label),
      style: ElevatedButton.styleFrom(
        backgroundColor: AppTheme.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: AppTheme.borderRadius),
      ),
    );
  }
}

/// Secondary / quiet button
class AppQuietButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;

  const AppQuietButton({
    super.key,
    required this.label,
    this.onPressed,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: icon != null
          ? Icon(icon, size: 20, color: AppTheme.primary)
          : const SizedBox.shrink(),
      label: Text(label),
      style: OutlinedButton.styleFrom(
        foregroundColor: AppTheme.primary,
        side: BorderSide(color: AppTheme.primary.withOpacity(0.4)),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: AppTheme.borderRadius),
      ),
    );
  }
}

/// Text input field with dark + orange style
class AppTextField extends StatelessWidget {
  final TextEditingController? controller;
  final String? label;
  final String? hint;
  final TextInputType keyboardType;
  final bool obscureText;
  final Widget? suffixIcon;
  final IconData? prefixIcon;

  const AppTextField({
    super.key,
    this.controller,
    this.label,
    this.hint,
    this.keyboardType = TextInputType.text,
    this.obscureText = false,
    this.suffixIcon,
    this.prefixIcon,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      style: const TextStyle(color: AppTheme.textPrimary),
      cursorColor: AppTheme.primary,
      keyboardType: keyboardType,
      obscureText: obscureText,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: AppTheme.textSecondary),
        hintText: hint,
        hintStyle: const TextStyle(color: AppTheme.textSecondary),
        suffixIcon: suffixIcon,
        prefixIcon: prefixIcon != null
            ? Icon(prefixIcon, color: AppTheme.primary)
            : null,
        filled: true,
        fillColor: AppTheme.tile,
        border: OutlineInputBorder(
          borderRadius: AppTheme.borderRadius,
          borderSide: BorderSide(color: AppTheme.borderColor),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: AppTheme.borderRadius,
          borderSide: BorderSide(color: AppTheme.borderColor),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: AppTheme.borderRadius,
          borderSide: const BorderSide(color: AppTheme.primary, width: 1.5),
        ),
      ),
    );
  }
}

/// Small chip for top bar actions
class TopChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const TopChip({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(30),
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 6),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: AppTheme.tile,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppTheme.primary.withOpacity(0.4)),
        ),
        child: Row(
          children: [
            Icon(icon, size: 16, color: AppTheme.primary),
            const SizedBox(width: 6),
            Text(
              label,
              style: const TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
