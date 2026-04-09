import 'package:flutter/material.dart';

/// Runtime language singleton.
///
/// Call [AppL10n.I.setLocale] when the user changes the language in settings.
/// Wrap [MaterialApp] in [AppL10nWidget] so the entire app rebuilds on locale change.
///
/// Screens retrieve translated strings via [AppL10n.I.t('key')] or the
/// convenience getters (e.g. [AppL10n.I.save]).
class AppL10n extends ChangeNotifier {
  AppL10n._();
  static final AppL10n I = AppL10n._();

  String _code = 'sq'; // 'sq' | 'en'

  String get code => _code;
  Locale get locale => Locale(_code);

  void setLocale(String code) {
    if (_code == code) return;
    _code = code;
    notifyListeners();
  }

  // ── Translation lookup ──────────────────────────────────────────────────────

  String t(String key) {
    final map = _code == 'en' ? _en : _sq;
    return map[key] ?? _sq[key] ?? key;
  }

  // ── Convenience getters ─────────────────────────────────────────────────────

  String get save => t('save');
  String get cancel => t('cancel');
  String get confirm => t('confirm');
  String get logout => t('logout');
  String get logoutTitle => t('logoutTitle');
  String get logoutConfirm => t('logoutConfirm');
  String get yes => t('yes');
  String get no => t('no');
  String get settings => t('settings');
  String get dashboard => t('dashboard');
  String get products => t('products');
  String get tables => t('tables');
  String get staff => t('staff');
  String get license => t('license');

  // Payment / POS
  String get cart => t('cart');
  String get emptyCart => t('emptyCart');
  String get payment => t('payment');
  String get payWithCash => t('payWithCash');
  String get payWithCard => t('payWithCard');
  String get payWithBank => t('payWithBank');
  String get total => t('total');
  String get subtotal => t('subtotal');
  String get discount => t('discount');
  String get vat => t('vat');
  String get net => t('net');
  String get paymentSuccess => t('paymentSuccess');
  String get paymentError => t('paymentError');
  String get cartEmpty => t('cartEmpty');
  String get discountNotAllowed => t('discountNotAllowed');
  String get deleteNotAllowed => t('deleteNotAllowed');

  // System
  String get inactivityLogout => t('inactivityLogout');

  // ── String maps ─────────────────────────────────────────────────────────────

  static const Map<String, String> _sq = {
    'save': 'Ruaj',
    'cancel': 'Anulo',
    'confirm': 'Konfirmo',
    'logout': 'Dil',
    'logoutTitle': 'Dil nga sistemi',
    'logoutConfirm': 'Jeni të sigurt që doni të dilni?',
    'yes': 'Po',
    'no': 'Jo',
    'settings': 'Cilësimet',
    'dashboard': 'Pasqyra',
    'products': 'Produktet',
    'tables': 'Tavolinat',
    'staff': 'Stafi',
    'license': 'Licenca',
    'cart': 'Shporta',
    'emptyCart': 'Shporta është bosh',
    'payment': 'Pagesa',
    'payWithCash': 'Cash',
    'payWithCard': 'Kartë',
    'payWithBank': 'Transfertë',
    'total': 'Totali',
    'subtotal': 'Nëntotali',
    'discount': 'Zbritja',
    'vat': 'TVSh',
    'net': 'Neto',
    'paymentSuccess': 'Pagesa u krye me sukses',
    'paymentError': 'Gabim gjatë pagesës',
    'cartEmpty': 'Shporta është bosh!',
    'discountNotAllowed': 'Nuk keni leje për të aplikuar zbritje.',
    'deleteNotAllowed': 'Nuk keni leje për të fshirë artikuj.',
    'inactivityLogout': 'U shkëputët automatikisht për shkak të inaktivitetit.',
  };

  static const Map<String, String> _en = {
    'save': 'Save',
    'cancel': 'Cancel',
    'confirm': 'Confirm',
    'logout': 'Logout',
    'logoutTitle': 'Log out of system',
    'logoutConfirm': 'Are you sure you want to log out?',
    'yes': 'Yes',
    'no': 'No',
    'settings': 'Settings',
    'dashboard': 'Dashboard',
    'products': 'Products',
    'tables': 'Tables',
    'staff': 'Staff',
    'license': 'License',
    'cart': 'Cart',
    'emptyCart': 'Cart is empty',
    'payment': 'Payment',
    'payWithCash': 'Cash',
    'payWithCard': 'Card',
    'payWithBank': 'Bank Transfer',
    'total': 'Total',
    'subtotal': 'Subtotal',
    'discount': 'Discount',
    'vat': 'VAT',
    'net': 'Net',
    'paymentSuccess': 'Payment completed successfully',
    'paymentError': 'Payment error',
    'cartEmpty': 'Cart is empty!',
    'discountNotAllowed': 'You do not have permission to apply discounts.',
    'deleteNotAllowed': 'You do not have permission to delete items.',
    'inactivityLogout': 'You were automatically logged out due to inactivity.',
  };
}

/// Wraps [MaterialApp] and rebuilds it whenever [AppL10n.I] fires.
/// Place this as the outermost widget in [main.dart].
class AppL10nWidget extends StatefulWidget {
  final Widget Function(Locale locale) builder;
  const AppL10nWidget({super.key, required this.builder});

  @override
  State<AppL10nWidget> createState() => _AppL10nWidgetState();
}

class _AppL10nWidgetState extends State<AppL10nWidget> {
  @override
  void initState() {
    super.initState();
    AppL10n.I.addListener(_onLocaleChange);
  }

  @override
  void dispose() {
    AppL10n.I.removeListener(_onLocaleChange);
    super.dispose();
  }

  void _onLocaleChange() => setState(() {});

  @override
  Widget build(BuildContext context) => widget.builder(AppL10n.I.locale);
}
