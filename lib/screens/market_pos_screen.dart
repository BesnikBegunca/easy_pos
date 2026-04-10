import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../auth/session.dart';
import '../data/dao_orders.dart';
import '../data/dao_products.dart';
import '../data/dao_tables.dart';
import '../theme/app_theme.dart';
import '../util/money.dart';

// ─── Cart item (in-memory only) ───────────────────────────────────────────────
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

// ─── Screen ───────────────────────────────────────────────────────────────────
class MarketPosScreen extends StatefulWidget {
  const MarketPosScreen({super.key});

  @override
  State<MarketPosScreen> createState() => _MarketPosScreenState();
}

class _MarketPosScreenState extends State<MarketPosScreen> {
  bool _loading = true;
  int _marketTableId = 0;

  List<CategoryRow> _categories = [];
  int? _selectedCategoryId;
  List<ProductRow> _products = [];

  final List<_CartItem> _cart = [];
  int _discountCents = 0;

  final _searchC = TextEditingController();
  final _barcodeC = TextEditingController();
  final _discountC = TextEditingController();
  final _barcodeFocus = FocusNode();

  int get _grossCents => _cart.fold(0, (s, i) => s + i.lineTotalCents);
  int get _finalCents => (_grossCents - _discountCents).clamp(0, _grossCents);

  @override
  void initState() {
    super.initState();
    _searchC.addListener(_reloadProducts);
    _init();
  }

  @override
  void dispose() {
    _searchC.dispose();
    _barcodeC.dispose();
    _discountC.dispose();
    _barcodeFocus.dispose();
    super.dispose();
  }

  Future<void> _init() async {
    setState(() => _loading = true);
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
    final prods = await ProductsDao.I.listActiveProducts(
      categoryId: _selectedCategoryId,
      search: _searchC.text,
    );
    if (!mounted) return;
    setState(() => _products = prods);
  }

  void _addToCart(ProductRow p) {
    setState(() {
      final idx = _cart.indexWhere((i) => i.productId == p.id);
      if (idx >= 0) {
        _cart[idx].qty++;
      } else {
        _cart.add(
          _CartItem(
            productId: p.id,
            name: p.name,
            unitPriceCents: p.priceCents,
          ),
        );
      }
    });
  }

  void _incrementCart(int idx) => setState(() => _cart[idx].qty++);

  void _decrementCart(int idx) {
    setState(() {
      if (_cart[idx].qty <= 1) {
        _cart.removeAt(idx);
      } else {
        _cart[idx].qty--;
      }
    });
  }

  void _clearCart() {
    setState(() {
      _cart.clear();
      _discountCents = 0;
      _discountC.clear();
    });
  }

  Future<void> _onBarcodeSubmit(String raw) async {
    final code = raw.trim();
    _barcodeC.clear();
    if (code.isEmpty) return;

    final p = await ProductsDao.I.findActiveProductByScanCode(code);
    if (!mounted) return;
    if (p == null) {
      _showSnack('Produkti nuk u gjet: $code', color: AppTheme.error);
      return;
    }
    _addToCart(p);
    _barcodeFocus.requestFocus();
  }

  Future<void> _onPay(String method) async {
    if (_cart.isEmpty) {
      _showSnack('Shporta është bosh.', color: AppTheme.warning);
      return;
    }
    final me = Session.I.current!;
    final gross = _grossCents;
    final discount = _discountCents;
    final items = _cart
        .map(
          (i) => {
            'productId': i.productId,
            'qty': i.qty,
            'unitPriceCents': i.unitPriceCents,
          },
        )
        .toList();

    try {
      await OrdersDao.I.createMarketTransaction(
        tableId: _marketTableId,
        waiterId: me.id,
        paymentMethod: method,
        grossCents: gross,
        discountCents: discount,
        items: items,
      );
      if (!mounted) return;
      _showSnack(
        'Pagesa u krye  ${moneyFromCents(gross - discount)}',
        color: AppTheme.success,
      );
      _clearCart();
    } catch (e) {
      if (!mounted) return;
      _showSnack('Gabim: $e', color: AppTheme.error);
    }
  }

  void _showSnack(String msg, {required Color color}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          msg,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(color: AppTheme.primary),
      );
    }

    return Scaffold(
      resizeToAvoidBottomInset: false,
      backgroundColor: AppTheme.bg,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── Left: product picker ─────────────────────────────────────────────
              Expanded(
                flex: 60,
                child: Column(
                  children: [
                    _buildBarcodeBar(),
                    _buildCategoryTabs(),
                    Expanded(child: _buildProductGrid()),
                  ],
                ),
              ),
              // ── Divider ──────────────────────────────────────────────────────────
              Container(width: 1, color: AppTheme.border),
              // ── Right: cart ──────────────────────────────────────────────────────
              SizedBox(width: 320, child: _buildCartPanel()),
            ],
          ),
        ),
      ),
    );
  }

  // ── Barcode + search bar ───────────────────────────────────────────────────
  Widget _buildBarcodeBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        border: Border(bottom: BorderSide(color: AppTheme.border)),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 5,
            child: _BarField(
              controller: _barcodeC,
              focusNode: _barcodeFocus,
              onSubmit: _onBarcodeSubmit,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(flex: 5, child: _SearchField(controller: _searchC)),
        ],
      ),
    );
  }

  // ── Category tabs ──────────────────────────────────────────────────────────
  Widget _buildCategoryTabs() {
    if (_categories.isEmpty) return const SizedBox.shrink();

    return Container(
      height: 44,
      decoration: BoxDecoration(
        color: AppTheme.surface,
        border: Border(bottom: BorderSide(color: AppTheme.border)),
      ),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        itemCount: _categories.length + 1, // +1 for "Të gjitha"
        separatorBuilder: (_, __) => const SizedBox(width: 6),
        itemBuilder: (_, i) {
          if (i == 0) {
            return _CategoryChip(
              label: 'Të gjitha',
              selected: _selectedCategoryId == null,
              onTap: () {
                setState(() => _selectedCategoryId = null);
                _reloadProducts();
              },
            );
          }
          final cat = _categories[i - 1];
          return _CategoryChip(
            label: cat.name,
            selected: _selectedCategoryId == cat.id,
            onTap: () {
              setState(() => _selectedCategoryId = cat.id);
              _reloadProducts();
            },
          );
        },
      ),
    );
  }

  // ── Product grid ───────────────────────────────────────────────────────────
  Widget _buildProductGrid() {
    if (_products.isEmpty) {
      return Center(
        child: Text(
          'Nuk ka produkte.',
          style: AppTheme.bodySmall.copyWith(color: AppTheme.textMuted),
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final crossAxisCount = constraints.maxWidth > 350 ? 4 : 3;
        return GridView.builder(
          padding: const EdgeInsets.all(12),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            crossAxisSpacing: 8,
            mainAxisSpacing: 8,
            childAspectRatio: 1.1,
          ),
          itemCount: _products.length,
          itemBuilder: (_, i) => _ProductTile(
            product: _products[i],
            onTap: () => _addToCart(_products[i]),
          ),
        );
      },
    );
  }

  // ── Cart panel ─────────────────────────────────────────────────────────────
  Widget _buildCartPanel() {
    return Column(
      children: [
        // Header
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: AppTheme.surface,
            border: Border(bottom: BorderSide(color: AppTheme.border)),
          ),
          child: Row(
            children: [
              const Icon(
                Icons.shopping_cart_rounded,
                color: AppTheme.primary,
                size: 18,
              ),
              const SizedBox(width: 8),
              const Expanded(
                child: Text('Shporta', style: AppTheme.titleSmall),
              ),
              if (_cart.isNotEmpty)
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: _clearCart,
                    borderRadius: BorderRadius.circular(20),
                    child: const Padding(
                      padding: EdgeInsets.all(4),
                      child: Icon(
                        Icons.delete_sweep_rounded,
                        color: AppTheme.error,
                        size: 18,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        // Cart items
        Expanded(
          child: _cart.isEmpty
              ? Center(
                  child: Text(
                    'Asnjë produkt',
                    style: AppTheme.bodySmall.copyWith(
                      color: AppTheme.textMuted,
                    ),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  itemCount: _cart.length,
                  itemBuilder: (_, i) => _CartRow(
                    item: _cart[i],
                    onIncrement: () => _incrementCart(i),
                    onDecrement: () => _decrementCart(i),
                  ),
                ),
        ),
        // Discount + totals + pay
        _buildCheckoutPanel(),
      ],
    );
  }

  Widget _buildCheckoutPanel() {
    final hasCart = _cart.isNotEmpty;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        border: Border(top: BorderSide(color: AppTheme.border)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Discount input
          TextField(
            controller: _discountC,
            focusNode: FocusNode(),
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            style: const TextStyle(color: AppTheme.textPrimary, fontSize: 13),
            onEditingComplete: () => _barcodeFocus.requestFocus(),
            decoration: InputDecoration(
              hintText: 'Zbritje (qindarka)',
              hintStyle: TextStyle(color: AppTheme.textMuted, fontSize: 12),
              prefixIcon: const Icon(
                Icons.discount_rounded,
                size: 16,
                color: AppTheme.textMuted,
              ),
              filled: true,
              fillColor: AppTheme.card,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 10,
                vertical: 10,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: AppTheme.border),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: AppTheme.border),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: AppTheme.primary),
              ),
            ),
            onChanged: (v) {
              setState(() => _discountCents = int.tryParse(v) ?? 0);
            },
          ),
          const SizedBox(height: 12),
          // Gross
          if (_discountCents > 0) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Subtotal',
                  style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                ),
                Text(
                  moneyFromCents(_grossCents),
                  style: const TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Zbritje',
                  style: TextStyle(color: AppTheme.warning, fontSize: 12),
                ),
                Text(
                  '- ${moneyFromCents(_discountCents)}',
                  style: const TextStyle(color: AppTheme.warning, fontSize: 12),
                ),
              ],
            ),
            const SizedBox(height: 4),
          ],
          // Total
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'TOTAL',
                style: TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                ),
              ),
              Text(
                moneyFromCents(_finalCents),
                style: const TextStyle(
                  color: AppTheme.primary,
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Pay buttons
          Row(
            children: [
              Expanded(
                child: _PayButton(
                  label: 'Kesh',
                  icon: Icons.payments_rounded,
                  color: AppTheme.success,
                  enabled: hasCart,
                  onTap: () => _onPay('cash'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _PayButton(
                  label: 'Kartë',
                  icon: Icons.credit_card_rounded,
                  color: AppTheme.info,
                  enabled: hasCart,
                  onTap: () => _onPay('card'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─── Sub-widgets ──────────────────────────────────────────────────────────────

class _BarField extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final ValueChanged<String> onSubmit;

  const _BarField({
    required this.controller,
    required this.focusNode,
    required this.onSubmit,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      focusNode: focusNode,
      autofocus: true,
      style: const TextStyle(color: AppTheme.textPrimary, fontSize: 13),
      decoration: InputDecoration(
        hintText: 'Skano barkod…',
        hintStyle: TextStyle(color: AppTheme.textMuted, fontSize: 12),
        prefixIcon: const Icon(
          Icons.qr_code_scanner_rounded,
          size: 16,
          color: AppTheme.textMuted,
        ),
        filled: true,
        fillColor: AppTheme.card,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 10,
          vertical: 10,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: AppTheme.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: AppTheme.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppTheme.primary),
        ),
      ),
      textInputAction: TextInputAction.search,
      onSubmitted: onSubmit,
    );
  }
}

class _SearchField extends StatelessWidget {
  final TextEditingController controller;
  const _SearchField({required this.controller});

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      style: const TextStyle(color: AppTheme.textPrimary, fontSize: 13),
      decoration: InputDecoration(
        hintText: 'Kërko produkt…',
        hintStyle: TextStyle(color: AppTheme.textMuted, fontSize: 12),
        prefixIcon: const Icon(
          Icons.search_rounded,
          size: 16,
          color: AppTheme.textMuted,
        ),
        filled: true,
        fillColor: AppTheme.card,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 10,
          vertical: 10,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: AppTheme.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: AppTheme.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppTheme.primary),
        ),
      ),
    );
  }
}

class _CategoryChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _CategoryChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        splashColor: AppTheme.primary.withValues(alpha: 0.20),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: selected
                ? AppTheme.primary.withValues(alpha: 0.15)
                : AppTheme.card,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: selected
                  ? AppTheme.primary.withValues(alpha: 0.60)
                  : AppTheme.border,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: selected ? AppTheme.primary : AppTheme.textSecondary,
              fontSize: 12,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }
}

class _ProductTile extends StatelessWidget {
  final ProductRow product;
  final VoidCallback onTap;

  const _ProductTile({required this.product, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppTheme.borderRadius,
        splashColor: AppTheme.primary.withValues(alpha: 0.10),
        child: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppTheme.card,
            borderRadius: AppTheme.borderRadius,
            border: Border.all(color: AppTheme.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: AppTheme.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.add_shopping_cart_rounded,
                  size: 14,
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
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                moneyFromCents(product.priceCents),
                style: const TextStyle(
                  color: AppTheme.primary,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CartRow extends StatelessWidget {
  final _CartItem item;
  final VoidCallback onIncrement;
  final VoidCallback onDecrement;

  const _CartRow({
    required this.item,
    required this.onIncrement,
    required this.onDecrement,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
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
                  moneyFromCents(item.lineTotalCents),
                  style: const TextStyle(
                    color: AppTheme.primary,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          _QtyButton(
            icon: Icons.remove,
            onTap: onDecrement,
            color: AppTheme.error,
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Text(
              '${item.qty}',
              style: const TextStyle(
                color: AppTheme.textPrimary,
                fontWeight: FontWeight.w800,
                fontSize: 13,
              ),
            ),
          ),
          _QtyButton(
            icon: Icons.add,
            onTap: onIncrement,
            color: AppTheme.success,
          ),
        ],
      ),
    );
  }
}

class _QtyButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final Color color;

  const _QtyButton({
    required this.icon,
    required this.onTap,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        splashColor: color.withValues(alpha: 0.20),
        child: Container(
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: color.withValues(alpha: 0.30)),
          ),
          child: Icon(icon, size: 14, color: color),
        ),
      ),
    );
  }
}

class _PayButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final bool enabled;
  final VoidCallback onTap;

  const _PayButton({
    required this.label,
    required this.icon,
    required this.color,
    required this.enabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final effective = enabled ? color : AppTheme.textMuted;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(12),
        splashColor: effective.withValues(alpha: 0.20),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: effective.withValues(alpha: enabled ? 0.15 : 0.06),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: effective.withValues(alpha: enabled ? 0.50 : 0.20),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 16, color: effective),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  color: effective,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
