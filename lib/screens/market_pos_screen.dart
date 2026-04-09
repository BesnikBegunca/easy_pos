import 'package:flutter/material.dart';
import '../auth/session.dart';
import '../data/app_settings.dart';
import '../data/dao_orders.dart';
import '../data/dao_products.dart';
import '../data/dao_tables.dart';
import '../l10n/app_l10n.dart';
import '../theme/app_theme.dart';
import '../util/money.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Cart model
// ─────────────────────────────────────────────────────────────────────────────
class _CartItem {
  final int productId;
  final String name;
  final int unitPriceCents;
  int qty = 1;

  _CartItem({
    required this.productId,
    required this.name,
    required this.unitPriceCents,
  });

  int get lineTotalCents => unitPriceCents * qty;
}

// ─────────────────────────────────────────────────────────────────────────────
class MarketPosScreen extends StatefulWidget {
  const MarketPosScreen({super.key});

  @override
  State<MarketPosScreen> createState() => _MarketPosScreenState();
}

class _MarketPosScreenState extends State<MarketPosScreen> {
  // ── Data ───────────────────────────────────────────────────────────────────
  bool _loading = true;
  int _marketTableId = 0;
  List<CategoryRow> _categories = [];
  int? _selectedCategoryId;
  List<ProductRow> _products = [];

  // ── Search / barcode ───────────────────────────────────────────────────────
  final _searchCtrl = TextEditingController();
  final _barcodeCtrl = TextEditingController();
  final _barcodeFocus = FocusNode();

  // ── Cart ───────────────────────────────────────────────────────────────────
  final List<_CartItem> _cart = [];
  int _discountPct = 0; // 0–100
  bool _showDiscount = false;

  // ── Payment ────────────────────────────────────────────────────────────────
  bool _paying = false;

  // ── Computed ───────────────────────────────────────────────────────────────
  int get _grossCents => _cart.fold(0, (s, i) => s + i.lineTotalCents);
  int get _discountCents => (_grossCents * _discountPct / 100).round();
  int get _finalCents => _grossCents - _discountCents;
  int get _cartCount => _cart.fold(0, (s, i) => s + i.qty);

  @override
  void initState() {
    super.initState();
    _searchCtrl.addListener(_reloadProducts);
    _init();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _barcodeCtrl.dispose();
    _barcodeFocus.dispose();
    super.dispose();
  }

  Future<void> _init() async {
    try {
      _marketTableId = await TablesDao.I.getOrCreateMarketTableId();
      _categories = await ProductsDao.I.listCategories();
      _selectedCategoryId = _categories.isEmpty ? null : _categories.first.id;
      await _reloadProducts();
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _reloadProducts() async {
    final search = _searchCtrl.text.trim();
    final prods = await ProductsDao.I.listActiveProducts(
      categoryId: search.isEmpty ? _selectedCategoryId : null,
      search: search.isEmpty ? null : search,
    );
    if (!mounted) return;
    setState(() => _products = prods);
  }

  // ── Cart operations ────────────────────────────────────────────────────────

  void _addProduct(ProductRow p) {
    setState(() {
      final idx = _cart.indexWhere((i) => i.productId == p.id);
      if (idx >= 0) {
        _cart[idx].qty++;
      } else {
        _cart.add(_CartItem(
          productId: p.id,
          name: p.name,
          unitPriceCents: p.priceCents,
        ));
      }
    });
  }

  void _incrementQty(int idx) => setState(() => _cart[idx].qty++);

  void _decrementQty(int idx) => setState(() {
        if (_cart[idx].qty <= 1) {
          _cart.removeAt(idx);
        } else {
          _cart[idx].qty--;
        }
      });

  void _removeItem(int idx) => setState(() => _cart.removeAt(idx));

  void _clearCart() => setState(() {
        _cart.clear();
        _discountPct = 0;
        _showDiscount = false;
      });

  // ── Barcode submit ─────────────────────────────────────────────────────────

  void _onBarcodeSubmit(String value) {
    final q = value.trim();
    _barcodeCtrl.clear();
    if (q.isEmpty) return;
    // Find product matching barcode/name
    final match = _products.cast<ProductRow?>().firstWhere(
          (p) => p!.name.toLowerCase().contains(q.toLowerCase()),
          orElse: () => null,
        );
    if (match != null) {
      _addProduct(match);
      _showToast('${match.name} shtuar!', color: AppTheme.success);
    } else {
      // Search for it across all products
      ProductsDao.I
          .listActiveProducts(search: q)
          .then((results) {
        if (!mounted) return;
        if (results.isNotEmpty) {
          _addProduct(results.first);
          _showToast('${results.first.name} shtuar!', color: AppTheme.success);
        } else {
          _showToast('Produkti "$q" nuk u gjet.', color: AppTheme.error);
        }
      });
    }
  }

  // ── Payment ────────────────────────────────────────────────────────────────

  Future<void> _pay(String method) async {
    if (_cart.isEmpty) {
      _showToast('Shporta është bosh!', color: AppTheme.warning);
      return;
    }
    final confirmed = await _showPaymentConfirm(method);
    if (confirmed != true || !mounted) return;

    setState(() => _paying = true);
    try {
      final me = Session.I.current!;
      await OrdersDao.I.createMarketTransaction(
        tableId: _marketTableId,
        waiterId: me.id,
        paymentMethod: method,
        grossCents: _grossCents,
        discountCents: _discountCents,
        items: _cart
            .map((i) => {
                  'productId': i.productId,
                  'qty': i.qty,
                  'unitPriceCents': i.unitPriceCents,
                })
            .toList(),
      );
      if (!mounted) return;
      _showToast(
        'Pagesa u krye: ${moneyFromCents(_finalCents)} — ${method == 'cash' ? 'Cash' : 'Kartë'}',
        color: AppTheme.success,
      );
      _clearCart();
      // Refocus barcode after sale
      Future.delayed(const Duration(milliseconds: 200), () {
        if (mounted) _barcodeFocus.requestFocus();
      });
    } catch (e) {
      if (!mounted) return;
      _showToast('Gabim gjatë pagesës: $e', color: AppTheme.error);
    } finally {
      if (mounted) setState(() => _paying = false);
    }
  }

  Future<bool?> _showPaymentConfirm(String method) {
    return showDialog<bool>(
      context: context,
      builder: (_) => _PayConfirmDialog(
        method: method,
        grossCents: _grossCents,
        discountCents: _discountCents,
        finalCents: _finalCents,
        discountPct: _discountPct,
        cartItems: List.unmodifiable(_cart),
      ),
    );
  }

  void _showToast(String msg, {required Color color}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 2),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator(color: AppTheme.primary));
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth > 680;
        if (wide) {
          return Row(
            children: [
              Expanded(flex: 3, child: _buildProductPanel()),
              Container(width: 1, color: AppTheme.border),
              SizedBox(width: 340, child: _buildCartPanel()),
            ],
          );
        }
        // Narrow: product panel with slide-up cart sheet
        return Stack(
          children: [
            _buildProductPanel(),
            if (_cart.isNotEmpty)
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                height: constraints.maxHeight * 0.48,
                child: _buildCartPanel(),
              ),
          ],
        );
      },
    );
  }

  // ── Product panel ──────────────────────────────────────────────────────────

  Widget _buildProductPanel() {
    return Container(
      color: AppTheme.bg,
      child: Column(
        children: [
          _buildSearchBar(),
          _buildCategoryBar(),
          Expanded(child: _buildProductGrid()),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
      color: AppTheme.surface,
      child: Row(
        children: [
          // Barcode input
          SizedBox(
            width: 180,
            child: TextField(
              controller: _barcodeCtrl,
              focusNode: _barcodeFocus,
              style: const TextStyle(color: AppTheme.textPrimary, fontSize: 13),
              textInputAction: TextInputAction.search,
              onSubmitted: _onBarcodeSubmit,
              decoration: InputDecoration(
                hintText: 'Skanoni barkod...',
                hintStyle: TextStyle(color: AppTheme.textMuted, fontSize: 12),
                prefixIcon: const Icon(Icons.qr_code_scanner_rounded, size: 17, color: AppTheme.orange),
                prefixIconConstraints: const BoxConstraints(minWidth: 38),
                filled: true,
                fillColor: AppTheme.card,
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: AppTheme.border),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: AppTheme.border),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: AppTheme.orange, width: 1.4),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          // Product search
          Expanded(
            child: TextField(
              controller: _searchCtrl,
              style: const TextStyle(color: AppTheme.textPrimary, fontSize: 13),
              decoration: InputDecoration(
                hintText: 'Kërko produkt...',
                hintStyle: TextStyle(color: AppTheme.textMuted, fontSize: 12),
                prefixIcon: const Icon(Icons.search_rounded, size: 17, color: AppTheme.textMuted),
                prefixIconConstraints: const BoxConstraints(minWidth: 38),
                suffixIcon: _searchCtrl.text.isNotEmpty
                    ? GestureDetector(
                        onTap: () => _searchCtrl.clear(),
                        child: const Icon(Icons.close_rounded, size: 16, color: AppTheme.textMuted),
                      )
                    : null,
                filled: true,
                fillColor: AppTheme.card,
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: AppTheme.border),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: AppTheme.border),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: AppTheme.primary, width: 1.4),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryBar() {
    if (_categories.isEmpty) return const SizedBox.shrink();
    return Container(
      height: 44,
      color: AppTheme.surface,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        itemCount: _categories.length,
        itemBuilder: (_, i) {
          final cat = _categories[i];
          final active = _selectedCategoryId == cat.id && _searchCtrl.text.isEmpty;
          return GestureDetector(
            onTap: () {
              _searchCtrl.clear();
              setState(() => _selectedCategoryId = cat.id);
              _reloadProducts();
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              margin: const EdgeInsets.only(right: 6),
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                color: active
                    ? AppTheme.primary.withValues(alpha: 0.18)
                    : AppTheme.card,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: active
                      ? AppTheme.primary.withValues(alpha: 0.45)
                      : AppTheme.border,
                ),
              ),
              child: Center(
                child: Text(
                  cat.name,
                  style: TextStyle(
                    color: active ? AppTheme.primary : AppTheme.textSecondary,
                    fontSize: 12,
                    fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildProductGrid() {
    if (_products.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inventory_2_rounded, size: 48, color: AppTheme.textMuted),
            const SizedBox(height: 12),
            Text(
              'Nuk u gjetën produkte',
              style: AppTheme.bodyMedium.copyWith(color: AppTheme.textMuted),
            ),
          ],
        ),
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.all(14),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 160,
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        childAspectRatio: 0.85,
      ),
      itemCount: _products.length,
      itemBuilder: (_, i) {
        final p = _products[i];
        final inCart = _cart.any((c) => c.productId == p.id);
        final cartQty = inCart
            ? _cart.firstWhere((c) => c.productId == p.id).qty
            : 0;
        return _ProductCard(
          product: p,
          cartQty: cartQty,
          onTap: () => _addProduct(p),
        );
      },
    );
  }

  // ── Cart panel ─────────────────────────────────────────────────────────────

  Widget _buildCartPanel() {
    return Container(
      color: AppTheme.surface,
      child: Column(
        children: [
          _buildCartHeader(),
          Expanded(child: _buildCartItems()),
          _buildDiscountSection(),
          _buildTotalSection(),
          _buildPaymentButtons(),
        ],
      ),
    );
  }

  Widget _buildCartHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppTheme.card,
        border: Border(bottom: BorderSide(color: AppTheme.border)),
      ),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              gradient: AppTheme.primaryGrad,
              borderRadius: BorderRadius.circular(9),
            ),
            child: const Icon(Icons.shopping_cart_rounded, color: Colors.white, size: 16),
          ),
          const SizedBox(width: 10),
          Text(
            'Shporta',
            style: AppTheme.titleSmall.copyWith(fontWeight: FontWeight.w800),
          ),
          const Spacer(),
          if (_cartCount > 0) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
              decoration: BoxDecoration(
                color: AppTheme.primary.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: AppTheme.primary.withValues(alpha: 0.35)),
              ),
              child: Text(
                '$_cartCount artikuj',
                style: const TextStyle(
                  color: AppTheme.primary,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: () {
                showDialog<bool>(
                  context: context,
                  builder: (_) => AlertDialog(
                    backgroundColor: AppTheme.surface,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                    title: const Text('Zbraz shportën?', style: AppTheme.titleSmall),
                    content: const Text(
                      'Të gjitha artikujt do të hiqen.',
                      style: AppTheme.bodyMedium,
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: const Text('Anulo'),
                      ),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.error,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        onPressed: () => Navigator.pop(context, true),
                        child: const Text('Zbraz'),
                      ),
                    ],
                  ),
                ).then((ok) { if (ok == true) _clearCart(); });
              },
              child: Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: AppTheme.error.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.delete_sweep_rounded, size: 15, color: AppTheme.error),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCartItems() {
    if (_cart.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.shopping_cart_outlined,
              size: 44,
              color: AppTheme.textMuted.withValues(alpha: 0.4),
            ),
            const SizedBox(height: 10),
            Text(
              'Shporta është bosh',
              style: AppTheme.bodySmall.copyWith(color: AppTheme.textMuted),
            ),
            const SizedBox(height: 4),
            Text(
              'Kliko produktin ose skanoni barkod',
              style: AppTheme.caption,
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 10),
      itemCount: _cart.length,
      itemBuilder: (_, i) {
        final item = _cart[i];
        return _CartItemRow(
          item: item,
          onIncrement: () => _incrementQty(i),
          onDecrement: () => _decrementQty(i),
          onRemove: () => _removeItem(i),
        );
      },
    );
  }

  Widget _buildDiscountSection() {
    final canDiscount = AppSettings.I.permDiscount;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppTheme.card,
        border: Border(
          top: BorderSide(color: AppTheme.border),
          bottom: BorderSide(color: AppTheme.border),
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              GestureDetector(
                onTap: canDiscount
                    ? () => setState(() => _showDiscount = !_showDiscount)
                    : () => _showToast(
                          AppL10n.I.discountNotAllowed,
                          color: AppTheme.warning,
                        ),
                child: Row(
                  children: [
                    Icon(
                      Icons.local_offer_rounded,
                      size: 15,
                      color: _discountPct > 0 ? AppTheme.warning : AppTheme.textMuted,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Zbritje',
                      style: TextStyle(
                        color: _discountPct > 0 ? AppTheme.warning : AppTheme.textMuted,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(
                      _showDiscount ? Icons.expand_less_rounded : Icons.expand_more_rounded,
                      size: 16,
                      color: AppTheme.textMuted,
                    ),
                  ],
                ),
              ),
              const Spacer(),
              if (_discountPct > 0) ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppTheme.warning.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: AppTheme.warning.withValues(alpha: 0.30)),
                  ),
                  child: Text(
                    '-$_discountPct% (${moneyFromCents(_discountCents)})',
                    style: const TextStyle(
                      color: AppTheme.warning,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                GestureDetector(
                  onTap: () => setState(() { _discountPct = 0; _showDiscount = false; }),
                  child: const Icon(Icons.close_rounded, size: 15, color: AppTheme.textMuted),
                ),
              ],
            ],
          ),
          if (_showDiscount) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                Text(
                  '0%',
                  style: AppTheme.caption,
                ),
                Expanded(
                  child: Slider(
                    value: _discountPct.toDouble(),
                    min: 0,
                    max: 50,
                    divisions: 50,
                    activeColor: AppTheme.warning,
                    inactiveColor: AppTheme.warning.withValues(alpha: 0.15),
                    onChanged: (v) => setState(() => _discountPct = v.round()),
                  ),
                ),
                Text(
                  '50%',
                  style: AppTheme.caption,
                ),
                const SizedBox(width: 8),
                // Quick preset buttons
                for (final pct in [5, 10, 15, 20])
                  GestureDetector(
                    onTap: () => setState(() {
                      _discountPct = pct;
                      _showDiscount = false;
                    }),
                    child: Container(
                      margin: const EdgeInsets.only(left: 4),
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
                      decoration: BoxDecoration(
                        color: _discountPct == pct
                            ? AppTheme.warning.withValues(alpha: 0.20)
                            : AppTheme.cardAlt,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: _discountPct == pct
                              ? AppTheme.warning.withValues(alpha: 0.45)
                              : AppTheme.border,
                        ),
                      ),
                      child: Text(
                        '$pct%',
                        style: TextStyle(
                          color: _discountPct == pct ? AppTheme.warning : AppTheme.textSecondary,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTotalSection() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppTheme.primary.withValues(alpha: 0.10),
            AppTheme.primary.withValues(alpha: 0.03),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Column(
        children: [
          if (_discountPct > 0) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Nëntotali',
                  style: AppTheme.bodySmall.copyWith(color: AppTheme.textSecondary),
                ),
                Text(
                  moneyFromCents(_grossCents),
                  style: AppTheme.bodySmall.copyWith(color: AppTheme.textSecondary),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Zbritje ($_discountPct%)',
                  style: AppTheme.bodySmall.copyWith(color: AppTheme.warning),
                ),
                Text(
                  '-${moneyFromCents(_discountCents)}',
                  style: AppTheme.bodySmall.copyWith(color: AppTheme.warning),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Container(height: 1, color: AppTheme.border),
            const SizedBox(height: 8),
          ],
          if (AppSettings.I.vatEnabled && AppSettings.I.vatPercent > 0) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  AppSettings.I.vatLabel,
                  style: AppTheme.bodySmall.copyWith(color: AppTheme.textSecondary),
                ),
                Text(
                  moneyFromCents(AppSettings.I.vatFromInclusive(_finalCents)),
                  style: AppTheme.bodySmall.copyWith(color: AppTheme.textSecondary),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Neto',
                  style: AppTheme.bodySmall.copyWith(color: AppTheme.textSecondary),
                ),
                Text(
                  moneyFromCents(AppSettings.I.netFromInclusive(_finalCents)),
                  style: AppTheme.bodySmall.copyWith(color: AppTheme.textSecondary),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Container(height: 1, color: AppTheme.border),
            const SizedBox(height: 8),
          ],
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'TOTALI',
                    style: AppTheme.caption.copyWith(
                      letterSpacing: 1.0,
                      color: AppTheme.textMuted,
                    ),
                  ),
                  Text(
                    '$_cartCount artikuj',
                    style: AppTheme.caption,
                  ),
                ],
              ),
              Text(
                moneyFromCents(_finalCents),
                style: TextStyle(
                  color: AppTheme.primary,
                  fontWeight: FontWeight.w900,
                  fontSize: 28,
                  letterSpacing: -0.5,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentButtons() {
    final canPay = _cart.isNotEmpty && !_paying;
    final s = AppSettings.I;
    final btns = <Widget>[];

    if (s.payMethodCash) {
      btns.add(Expanded(
        child: _PayButton(
          label: AppL10n.I.payWithCash,
          icon: Icons.payments_rounded,
          color: AppTheme.success,
          enabled: canPay,
          loading: _paying,
          onTap: () => _pay('cash'),
        ),
      ));
    }
    if (s.payMethodCard) {
      if (btns.isNotEmpty) btns.add(const SizedBox(width: 8));
      btns.add(Expanded(
        child: _PayButton(
          label: AppL10n.I.payWithCard,
          icon: Icons.credit_card_rounded,
          color: AppTheme.info,
          enabled: canPay,
          loading: _paying,
          onTap: () => _pay('card'),
        ),
      ));
    }
    if (s.payMethodBank) {
      if (btns.isNotEmpty) btns.add(const SizedBox(width: 8));
      btns.add(Expanded(
        child: _PayButton(
          label: AppL10n.I.payWithBank,
          icon: Icons.account_balance_rounded,
          color: AppTheme.warning,
          enabled: canPay,
          loading: _paying,
          onTap: () => _pay('bank'),
        ),
      ));
    }

    // Fallback: if admin disabled all methods, show cash anyway
    if (btns.isEmpty) {
      btns.add(Expanded(
        child: _PayButton(
          label: AppL10n.I.payWithCash,
          icon: Icons.payments_rounded,
          color: AppTheme.success,
          enabled: canPay,
          loading: _paying,
          onTap: () => _pay('cash'),
        ),
      ));
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.card,
        border: Border(top: BorderSide(color: AppTheme.border)),
      ),
      child: Row(children: btns),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Product card
// ─────────────────────────────────────────────────────────────────────────────
class _ProductCard extends StatelessWidget {
  final ProductRow product;
  final int cartQty;
  final VoidCallback onTap;

  const _ProductCard({
    required this.product,
    required this.cartQty,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final inCart = cartQty > 0;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        decoration: BoxDecoration(
          gradient: inCart
              ? LinearGradient(
                  colors: [
                    AppTheme.primary.withValues(alpha: 0.18),
                    AppTheme.primary.withValues(alpha: 0.06),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                )
              : null,
          color: inCart ? null : AppTheme.card,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: inCart
                ? AppTheme.primary.withValues(alpha: 0.45)
                : AppTheme.border,
            width: inCart ? 1.5 : 1,
          ),
          boxShadow: inCart
              ? AppTheme.shadowGlowColor(AppTheme.primary, a: 0.10)
              : AppTheme.shadowSm,
        ),
        child: Stack(
          children: [
            Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Category color accent
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: AppTheme.primary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.inventory_2_rounded,
                      size: 18,
                      color: AppTheme.primary,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    product.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppTheme.textPrimary,
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                      height: 1.3,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    moneyFromCents(product.priceCents),
                    style: TextStyle(
                      color: inCart ? AppTheme.primary : AppTheme.textSecondary,
                      fontWeight: FontWeight.w800,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
            // Cart badge
            if (inCart)
              Positioned(
                top: 6,
                right: 6,
                child: Container(
                  width: 22,
                  height: 22,
                  decoration: BoxDecoration(
                    gradient: AppTheme.primaryGrad,
                    shape: BoxShape.circle,
                    boxShadow: AppTheme.shadowGlowColor(AppTheme.primary, a: 0.40),
                  ),
                  child: Center(
                    child: Text(
                      '$cartQty',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
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

// ─────────────────────────────────────────────────────────────────────────────
// Cart item row
// ─────────────────────────────────────────────────────────────────────────────
class _CartItemRow extends StatelessWidget {
  final _CartItem item;
  final VoidCallback onIncrement;
  final VoidCallback onDecrement;
  final VoidCallback onRemove;

  const _CartItemRow({
    required this.item,
    required this.onIncrement,
    required this.onDecrement,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 3),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: AppTheme.card,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.border),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  moneyFromCents(item.unitPriceCents),
                  style: AppTheme.caption.copyWith(color: AppTheme.textSecondary),
                ),
              ],
            ),
          ),
          // Qty controls
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _QtyBtn(icon: Icons.remove_rounded, onTap: onDecrement),
              Container(
                width: 30,
                alignment: Alignment.center,
                child: Text(
                  '${item.qty}',
                  style: const TextStyle(
                    color: AppTheme.textPrimary,
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                  ),
                ),
              ),
              _QtyBtn(icon: Icons.add_rounded, onTap: onIncrement, isAdd: true),
            ],
          ),
          const SizedBox(width: 8),
          // Line total
          SizedBox(
            width: 70,
            child: Text(
              moneyFromCents(item.lineTotalCents),
              textAlign: TextAlign.right,
              style: const TextStyle(
                color: AppTheme.primary,
                fontWeight: FontWeight.w800,
                fontSize: 12,
              ),
            ),
          ),
          const SizedBox(width: 6),
          GestureDetector(
            onTap: onRemove,
            child: Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                color: AppTheme.error.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(7),
              ),
              child: const Icon(Icons.close_rounded, size: 13, color: AppTheme.error),
            ),
          ),
        ],
      ),
    );
  }
}

class _QtyBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final bool isAdd;

  const _QtyBtn({required this.icon, required this.onTap, this.isAdd = false});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 24,
        height: 24,
        decoration: BoxDecoration(
          color: isAdd
              ? AppTheme.primary.withValues(alpha: 0.15)
              : AppTheme.cardAlt,
          borderRadius: BorderRadius.circular(7),
          border: Border.all(
            color: isAdd
                ? AppTheme.primary.withValues(alpha: 0.35)
                : AppTheme.border,
          ),
        ),
        child: Icon(
          icon,
          size: 13,
          color: isAdd ? AppTheme.primary : AppTheme.textSecondary,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Pay button
// ─────────────────────────────────────────────────────────────────────────────
class _PayButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final bool enabled;
  final bool loading;
  final VoidCallback onTap;

  const _PayButton({
    required this.label,
    required this.icon,
    required this.color,
    required this.enabled,
    required this.loading,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          gradient: enabled
              ? LinearGradient(
                  colors: [color, color.withValues(alpha: 0.75)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                )
              : null,
          color: enabled ? null : AppTheme.cardAlt,
          borderRadius: BorderRadius.circular(12),
          boxShadow: enabled ? AppTheme.shadowGlowColor(color, a: 0.30) : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (loading)
              const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
              )
            else
              Icon(icon, color: enabled ? Colors.white : AppTheme.textMuted, size: 18),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: enabled ? Colors.white : AppTheme.textMuted,
                fontWeight: FontWeight.w800,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Payment confirm dialog
// ─────────────────────────────────────────────────────────────────────────────
class _PayConfirmDialog extends StatelessWidget {
  final String method;
  final int grossCents;
  final int discountCents;
  final int finalCents;
  final int discountPct;
  final List<_CartItem> cartItems;

  const _PayConfirmDialog({
    required this.method,
    required this.grossCents,
    required this.discountCents,
    required this.finalCents,
    required this.discountPct,
    required this.cartItems,
  });

  @override
  Widget build(BuildContext context) {
    final isCard = method == 'card';
    final isBank = method == 'bank';
    final methodColor = isCard ? AppTheme.info : isBank ? AppTheme.warning : AppTheme.success;
    final methodIcon = isCard
        ? Icons.credit_card_rounded
        : isBank
            ? Icons.account_balance_rounded
            : Icons.payments_rounded;
    final methodLabel = isCard
        ? AppL10n.I.payWithCard
        : isBank
            ? AppL10n.I.payWithBank
            : AppL10n.I.payWithCash;

    final s = AppSettings.I;
    final vatCents = s.vatFromInclusive(finalCents);
    final netCents = s.netFromInclusive(finalCents);

    return Dialog(
      backgroundColor: AppTheme.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: SizedBox(
        width: 380,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    methodColor.withValues(alpha: 0.18),
                    methodColor.withValues(alpha: 0.05),
                  ],
                ),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                border: Border(bottom: BorderSide(color: AppTheme.border)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: methodColor.withValues(alpha: 0.20),
                      borderRadius: BorderRadius.circular(13),
                    ),
                    child: Icon(methodIcon, color: methodColor, size: 22),
                  ),
                  const SizedBox(width: 14),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Konfirmo Pagesën',
                        style: AppTheme.titleSmall.copyWith(fontWeight: FontWeight.w800),
                      ),
                      Text(
                        'Metoda: $methodLabel',
                        style: AppTheme.caption,
                      ),
                    ],
                  ),
                ],
              ),
            ),
            // Items summary
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  ...cartItems.map((item) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 3),
                        child: Row(
                          children: [
                            Text(
                              '${item.qty}×',
                              style: AppTheme.bodySmall.copyWith(
                                color: AppTheme.primary,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                item.name,
                                style: AppTheme.bodySmall,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            Text(
                              moneyFromCents(item.lineTotalCents),
                              style: AppTheme.bodySmall.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      )),
                  const SizedBox(height: 12),
                  Container(height: 1, color: AppTheme.border),
                  const SizedBox(height: 12),
                  if (discountPct > 0) ...[
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Nëntotali', style: AppTheme.bodySmall),
                        Text(moneyFromCents(grossCents), style: AppTheme.bodySmall),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Zbritje ($discountPct%)',
                          style: AppTheme.bodySmall.copyWith(color: AppTheme.warning),
                        ),
                        Text(
                          '-${moneyFromCents(discountCents)}',
                          style: AppTheme.bodySmall.copyWith(color: AppTheme.warning),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                  ],
                  if (s.vatEnabled && s.vatPercent > 0) ...[
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(s.vatLabel, style: AppTheme.bodySmall.copyWith(color: AppTheme.textSecondary)),
                        Text(moneyFromCents(vatCents), style: AppTheme.bodySmall.copyWith(color: AppTheme.textSecondary)),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(AppL10n.I.net, style: AppTheme.bodySmall.copyWith(color: AppTheme.textSecondary)),
                        Text(moneyFromCents(netCents), style: AppTheme.bodySmall.copyWith(color: AppTheme.textSecondary)),
                      ],
                    ),
                    const SizedBox(height: 8),
                  ],
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'TOTAL',
                        style: AppTheme.labelLarge.copyWith(letterSpacing: 0.8),
                      ),
                      Text(
                        moneyFromCents(finalCents),
                        style: TextStyle(
                          color: methodColor,
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -0.3,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            // Actions
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context, false),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppTheme.textSecondary,
                        side: BorderSide(color: AppTheme.border),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text('Anulo'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton.icon(
                      onPressed: () => Navigator.pop(context, true),
                      icon: Icon(methodIcon, size: 16),
                      label: Text('Paguaj $methodLabel'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: methodColor,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        textStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
