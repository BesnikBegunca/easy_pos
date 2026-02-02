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
              foregroundColor: Colors.white,
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
    return AppBar(leading: leading, title: Text(title), actions: actions);
  }
}

/// A simple card widget
class AppCard extends StatelessWidget {
  final Widget child;
  final EdgeInsets? padding;
  final VoidCallback? onTap;

  const AppCard({super.key, required this.child, this.padding, this.onTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: AppTheme.borderRadius,
        border: Border.all(color: Colors.white.withOpacity(0.06)),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: AppTheme.borderRadius,
        child: Padding(
          padding: padding ?? const EdgeInsets.all(16),
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
      style: ElevatedButton.styleFrom(
        backgroundColor: AppTheme.primary,
        foregroundColor: Colors.white,
      ),
      icon: icon != null ? Icon(icon) : const SizedBox.shrink(),
      label: Text(label),
    );
  }
}

/// Secondary/quiet button
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
      style: OutlinedButton.styleFrom(
        side: BorderSide(color: Colors.white.withOpacity(0.3)),
        foregroundColor: onPressed == null ? Colors.white38 : Colors.white,
      ),
      icon: icon != null
          ? Icon(icon, color: onPressed == null ? Colors.white38 : Colors.white)
          : const SizedBox.shrink(),
      label: Text(
        label,
        style: TextStyle(
          color: onPressed == null ? Colors.white38 : Colors.white,
        ),
      ),
    );
  }
}

/// Text input field with consistent styling
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
      style: const TextStyle(color: Colors.white),
      cursorColor: AppTheme.primary,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.white),
        hintText: hint,
        hintStyle: const TextStyle(color: Colors.white),
        suffixIcon: suffixIcon,
        prefixIcon: prefixIcon != null
            ? Icon(prefixIcon, color: Colors.white)
            : null,
        border: OutlineInputBorder(
          borderSide: BorderSide(color: Colors.white.withOpacity(0.3)),
        ),
        enabledBorder: OutlineInputBorder(
          borderSide: BorderSide(color: Colors.white.withOpacity(0.3)),
        ),
        focusedBorder: OutlineInputBorder(
          borderSide: BorderSide(color: AppTheme.primary),
        ),
      ),
      keyboardType: keyboardType,
      obscureText: obscureText,
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
      borderRadius: BorderRadius.circular(20),
      onTap: onTap,
      child: Chip(
        avatar: Icon(icon, size: 18, color: Colors.white),
        label: Text(label, style: const TextStyle(color: Colors.white)),
        backgroundColor: Colors.transparent,
        side: BorderSide(color: Colors.white.withOpacity(0.06)),
      ),
    );
  }
}
