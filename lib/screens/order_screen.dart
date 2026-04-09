import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/dao_orders.dart';
import '../data/dao_products.dart';
import '../data/dao_settings.dart';
import '../data/dao_tables.dart';
import '../util/money.dart';
import '../theme/app_theme.dart';
import '../theme/app_widgets.dart';

class OrderScreen extends StatefulWidget {
  final int tableId;
  final String tableName;
  final int waiterId;

  const OrderScreen({
    super.key,
    required this.tableId,
    required this.tableName,
    required this.waiterId,
  });

  @override
  State<OrderScreen> createState() => _OrderScreenState();
}

class _OrderScreenState extends State<OrderScreen> {
  bool _loading = true;
  String? _error;
  int _orderId = 0;
  List<OrderLine> _lines = [];
  int _totalCents = 0;

  List<CategoryRow> _categories = [];
  int? _selectedCategoryId;
  List<ProductRow> _products = [];
  int _productColumns = SettingsDao.defaultProductColumns;

  final _searchC = TextEditingController();
  final Set<int> _busy = {};

  @override
  void initState() {
    super.initState();
    _searchC.addListener(_reloadProducts);
    _init();
  }

  @override
  void dispose() {
    _searchC.dispose();
    super.dispose();
  }

  Future<void> _init() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      _orderId = await OrdersDao.I.getOrCreateOpenOrder(
        tableId: widget.tableId,
        waiterId: widget.waiterId,
      );
      _categories = await ProductsDao.I.listCategories();
      _selectedCategoryId = _categories.isEmpty ? null : _categories.first.id;
      _productColumns = await SettingsDao.I.getInt(
        SettingsDao.productGridColumns,
        SettingsDao.defaultProductColumns,
      );
      await Future.wait([_reloadProducts(), _refreshCart()]);
    } catch (e) {
      _error = e.toString();
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _refreshCart() async {
    if (_orderId == 0) {
      return;
    }
    final lines = await OrdersDao.I.getOrderLines(_orderId);
    final total = await OrdersDao.I.getOrderTotalCents(_orderId);
    if (!mounted) {
      return;
    }
    setState(() {
      _lines = lines;
      _totalCents = total;
    });
  }

  Future<void> _reloadProducts() async {
    final prods = await ProductsDao.I.listActiveProducts(
      categoryId: _selectedCategoryId,
      search: _searchC.text,
    );
    if (!mounted) {
      return;
    }
    setState(() => _products = prods);
  }

  Future<void> _addProduct(ProductRow p) async {
    await OrdersDao.I.addProductToOrder(
      orderId: _orderId,
      productId: p.id,
      unitPriceCents: p.priceCents,
    );
    await _refreshCart();
  }

  Future<void> _incrementLine(OrderLine line) async {
    if (_busy.contains(line.itemId)) {
      return;
    }
    setState(() => _busy.add(line.itemId));
    try {
      await OrdersDao.I.setItemQty(
        itemId: line.itemId,
        orderId: _orderId,
        newQty: line.qty + 1,
      );
      await _refreshCart();
    } finally {
      if (mounted) {
        setState(() => _busy.remove(line.itemId));
      }
    }
  }

  Future<void> _decrementLine(OrderLine line) async {
    if (_busy.contains(line.itemId)) {
      return;
    }
    setState(() => _busy.add(line.itemId));
    try {
      await OrdersDao.I.setItemQty(
        itemId: line.itemId,
        orderId: _orderId,
        newQty: line.qty - 1,
      );
      await _refreshCart();
    } finally {
      if (mounted) {
        setState(() => _busy.remove(line.itemId));
      }
    }
  }

  Future<void> _removeLine(OrderLine line) async {
    if (_busy.contains(line.itemId)) {
      return;
    }
    setState(() => _busy.add(line.itemId));
    try {
      await OrdersDao.I.removeOrderItem(line.itemId, _orderId);
      await _refreshCart();
    } finally {
      if (mounted) {
        setState(() => _busy.remove(line.itemId));
      }
    }
  }

  // ── PRINTO: dërgon në kuzhinë + kthen te login ──────────────────────────
  Future<void> _onPrinto() async {
    if (_lines.isEmpty) {
      _showSnack('Shporta është bosh.', color: AppTheme.warning);
      return;
    }

    try {
      await OrdersDao.I.markItemsAsPrinted(_orderId);
      if (!mounted) {
        return;
      }

      _showSnack(
        'Porosia u dërgua. Kamarieri u logout.',
        color: const Color(0xFF3B82F6),
      );

      Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false);
    } catch (e) {
      if (!mounted) {
        return;
      }
      _showSnack('Gabim gjatë printimit: $e', color: AppTheme.error);
    }
  }

  // ── PAGUAJ: mbyll, tregon faturën ────────────────────────────────────────
  Future<void> _onPay() async {
    if (_lines.isEmpty) {
      _showSnack('Shporta është bosh.', color: AppTheme.warning);
      return;
    }
    final linesSnapshot = List<OrderLine>.from(_lines);
    final totalSnapshot = _totalCents;

    final method = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _PaymentDialog(
        totalCents: totalSnapshot,
        tableName: widget.tableName,
      ),
    );
    if (method == null || !mounted) {
      return;
    }

    try {
      await OrdersDao.I.payAndClose(
        orderId: _orderId,
        tableId: widget.tableId,
        waiterId: widget.waiterId,
        paymentMethod: method,
      );
      if (!mounted) {
        return;
      }
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (_) => _ReceiptDialog(
          tableName: widget.tableName,
          lines: linesSnapshot,
          totalCents: totalSnapshot,
          paymentMethod: method,
        ),
      );
      if (!mounted) {
        return;
      }
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) {
        return;
      }
      _showSnack('Gabim në pagesë: $e', color: AppTheme.error);
    }
  }

  // ── Close table ───────────────────────────────────────────────────────────
  Future<void> _onCloseTable() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppTheme.surface,
        shape: RoundedRectangleBorder(borderRadius: AppTheme.radiusLarge),
        title: Row(
          children: [
            IconBadge(
              icon: Icons.exit_to_app_rounded,
              color: AppTheme.warning,
              size: 36,
              iconSize: 18,
            ),
            const SizedBox(width: 12),
            Text('Mbyll ${widget.tableName}', style: AppTheme.titleSmall),
          ],
        ),
        content: const Text(
          'Klientët u larguan pa paguar.\nTavolina lirohet për klientë të rinj.',
          style: AppTheme.bodyMedium,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              'Anulo',
              style: TextStyle(color: AppTheme.textSecondary),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.warning,
              foregroundColor: Colors.black87,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: AppTheme.radiusSmall),
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              'Mbyll Tavolinen',
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
    );

    if (ok != true || !mounted) {
      return;
    }
    await TablesDao.I.releaseTableAsWaiter(widget.tableId);
    if (!mounted) {
      return;
    }
    Navigator.pop(context, true);
  }

  void _showSnack(String msg, {Color color = AppTheme.success}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: AppTheme.radiusSmall),
        margin: const EdgeInsets.all(12),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  // ── Build ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        backgroundColor: AppTheme.bg,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: AppTheme.primary.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Padding(
                  padding: EdgeInsets.all(14),
                  child: CircularProgressIndicator(
                    color: AppTheme.primary,
                    strokeWidth: 2.5,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Duke hapur ${widget.tableName}…',
                style: AppTheme.bodySmall,
              ),
            ],
          ),
        ),
      );
    }

    if (_orderId == 0 || _error != null) {
      return Scaffold(
        backgroundColor: AppTheme.bg,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const IconBadge(
                icon: Icons.error_outline_rounded,
                color: AppTheme.error,
                size: 56,
                iconSize: 28,
              ),
              const SizedBox(height: 16),
              const Text(
                'Gabim në hapjen e tavolinës',
                style: AppTheme.titleSmall,
              ),
              if (_error != null) ...[
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: Text(
                    _error!,
                    style: AppTheme.bodySmall,
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
              const SizedBox(height: 24),
              AppPrimaryButton(
                label: 'Kthehu',
                icon: Icons.arrow_back_rounded,
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppTheme.bg,
      body: Column(
        children: [
          _buildTopBar(),
          Expanded(
            child: Row(
              children: [
                SizedBox(width: 340, child: _buildCartPanel()),
                const VerticalDivider(width: 1, color: AppTheme.border),
                Expanded(child: _buildProductBrowser()),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Top bar ───────────────────────────────────────────────────────────────
  Widget _buildTopBar() {
    return Container(
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 8,
        bottom: 8,
        left: 16,
        right: 12,
      ),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        border: Border(bottom: BorderSide(color: AppTheme.border)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.20),
            blurRadius: 10,
          ),
        ],
      ),
      child: Row(
        children: [
          // Back button
          InkWell(
            borderRadius: BorderRadius.circular(10),
            onTap: () => Navigator.pop(context),
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: AppTheme.card,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppTheme.border),
              ),
              child: const Icon(
                Icons.arrow_back_rounded,
                color: AppTheme.textSecondary,
                size: 18,
              ),
            ),
          ),
          const SizedBox(width: 12),
          // Table info
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              gradient: AppTheme.primaryGrad,
              borderRadius: BorderRadius.circular(999),
              boxShadow: AppTheme.shadowGlowColor(AppTheme.primary, a: 0.25),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.table_restaurant_rounded,
                  color: Colors.white,
                  size: 14,
                ),
                const SizedBox(width: 6),
                Text(
                  widget.tableName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          if (_totalCents > 0)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: AppTheme.warning.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(
                  color: AppTheme.warning.withValues(alpha: 0.30),
                ),
              ),
              child: Text(
                moneyFromCents(_totalCents),
                style: const TextStyle(
                  color: AppTheme.warning,
                  fontWeight: FontWeight.w800,
                  fontSize: 12,
                ),
              ),
            ),
          const Spacer(),
          // Close table button
          InkWell(
            borderRadius: BorderRadius.circular(10),
            onTap: _onCloseTable,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: AppTheme.warning.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: AppTheme.warning.withValues(alpha: 0.25),
                ),
              ),
              child: Row(
                children: const [
                  Icon(
                    Icons.exit_to_app_rounded,
                    color: AppTheme.warning,
                    size: 15,
                  ),
                  SizedBox(width: 6),
                  Text(
                    'Mbyll',
                    style: TextStyle(
                      color: AppTheme.warning,
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Cart panel ────────────────────────────────────────────────────────────
  Widget _buildCartPanel() {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surface,
        border: Border(right: BorderSide(color: AppTheme.border)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: AppTheme.border)),
            ),
            child: Row(
              children: [
                const IconBadge(
                  icon: Icons.receipt_long_rounded,
                  color: AppTheme.primary,
                  size: 32,
                  iconSize: 16,
                ),
                const SizedBox(width: 10),
                Text('Porosia', style: AppTheme.titleSmall),
                const Spacer(),
                if (_lines.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: AppTheme.primary.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      '${_lines.length}',
                      style: const TextStyle(
                        color: AppTheme.primary,
                        fontWeight: FontWeight.w800,
                        fontSize: 12,
                      ),
                    ),
                  ),
              ],
            ),
          ),

          // Lines
          Expanded(
            child: _lines.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 56,
                          height: 56,
                          decoration: BoxDecoration(
                            color: AppTheme.primary.withValues(alpha: 0.06),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Icon(
                            Icons.add_shopping_cart_rounded,
                            size: 26,
                            color: AppTheme.primary.withValues(alpha: 0.40),
                          ),
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'Shto produkte nga lista',
                          style: AppTheme.bodySmall,
                        ),
                      ],
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    itemCount: _lines.length,
                    separatorBuilder: (_, i) =>
                        const PremiumDivider(indent: 16),
                    itemBuilder: (_, i) => _buildCartLine(_lines[i]),
                  ),
          ),

          // Total + actions
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.card,
              border: Border(top: BorderSide(color: AppTheme.border)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Total row
                Row(
                  children: [
                    Text(
                      'TOTALI',
                      style: AppTheme.caption.copyWith(
                        letterSpacing: 1.5,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      moneyFromCents(_totalCents),
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        color: AppTheme.warning,
                        letterSpacing: -0.5,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                // PRINTO
                GradientButton(
                  label: 'PRINTO',
                  icon: Icons.print_rounded,
                  height: 44,
                  fontSize: 13,
                  gradient: const LinearGradient(
                    colors: [Color(0xFF2563EB), Color(0xFF3B82F6)],
                  ),
                  onTap: _lines.isNotEmpty ? _onPrinto : null,
                ),
                const SizedBox(height: 8),
                // PAGUAJ
                GradientButton(
                  label: 'PAGUAJ',
                  icon: Icons.payments_rounded,
                  height: 52,
                  fontSize: 15,
                  gradient: AppTheme.successGrad,
                  onTap: _lines.isNotEmpty ? _onPay : null,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCartLine(OrderLine line) {
    final isBusy = _busy.contains(line.itemId);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Qty badge
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: AppTheme.primary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Center(
              child: Text(
                '${line.qty}',
                style: const TextStyle(
                  color: AppTheme.primary,
                  fontWeight: FontWeight.w800,
                  fontSize: 12,
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          // Name + unit price
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  line.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTheme.bodyMedium.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  moneyFromCents(line.unitPriceCents),
                  style: AppTheme.bodySmall,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          // Qty controls
          _QtyControl(
            qty: line.qty,
            busy: isBusy,
            onDecrement: () => _decrementLine(line),
            onIncrement: () => _incrementLine(line),
          ),
          const SizedBox(width: 8),
          // Line total
          SizedBox(
            width: 58,
            child: Text(
              moneyFromCents(line.lineTotalCents),
              textAlign: TextAlign.right,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AppTheme.textPrimary,
              ),
            ),
          ),
          // Remove
          GestureDetector(
            onTap: isBusy ? null : () => _removeLine(line),
            child: Container(
              margin: const EdgeInsets.only(left: 4),
              width: 26,
              height: 26,
              decoration: BoxDecoration(
                color: AppTheme.error.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Icon(
                Icons.close_rounded,
                size: 13,
                color: AppTheme.error.withValues(alpha: 0.70),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Product browser ───────────────────────────────────────────────────────
  Widget _buildProductBrowser() {
    return Column(
      children: [
        // Category + search bar
        Container(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
          decoration: BoxDecoration(
            color: AppTheme.surface,
            border: Border(bottom: BorderSide(color: AppTheme.border)),
          ),
          child: Column(
            children: [
              if (_categories.isNotEmpty)
                SizedBox(
                  height: 36,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: _categories.length,
                    itemBuilder: (_, i) {
                      final c = _categories[i];
                      final sel = _selectedCategoryId == c.id;
                      return Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: GestureDetector(
                          onTap: () async {
                            setState(() => _selectedCategoryId = c.id);
                            await _reloadProducts();
                          },
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 180),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              gradient: sel ? AppTheme.primaryGrad : null,
                              color: sel ? null : AppTheme.card,
                              borderRadius: BorderRadius.circular(999),
                              border: Border.all(
                                color: sel
                                    ? Colors.transparent
                                    : AppTheme.border,
                              ),
                              boxShadow: sel
                                  ? AppTheme.shadowGlowColor(
                                      AppTheme.primary,
                                      a: 0.20,
                                    )
                                  : [],
                            ),
                            child: Text(
                              c.name,
                              style: TextStyle(
                                color: sel
                                    ? Colors.white
                                    : AppTheme.textSecondary,
                                fontWeight: sel
                                    ? FontWeight.w700
                                    : FontWeight.w500,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              const SizedBox(height: 8),
              AppTextField(
                controller: _searchC,
                hint: 'Kërko produkt…',
                prefixIcon: Icons.search_rounded,
              ),
            ],
          ),
        ),

        // Product grid
        Expanded(
          child: _products.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      IconBadge(
                        icon: Icons.inventory_2_outlined,
                        color: AppTheme.textMuted,
                        size: 48,
                        iconSize: 24,
                      ),
                      const SizedBox(height: 12),
                      const Text('S\'ka produkte.', style: AppTheme.bodySmall),
                    ],
                  ),
                )
              : GridView.builder(
                  padding: const EdgeInsets.all(8),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: _productColumns,
                    crossAxisSpacing: 8,
                    mainAxisSpacing: 8,
                    childAspectRatio: 1.0,
                  ),
                  itemCount: _products.length,
                  itemBuilder: (_, i) => _buildProductCard(_products[i]),
                ),
        ),
      ],
    );
  }

  Widget _buildProductCard(ProductRow p) {
    final cartLine = _lines.cast<OrderLine?>().firstWhere(
      (l) => l?.productId == p.id,
      orElse: () => null,
    );
    final inCart = cartLine != null;
    final qty = cartLine?.qty ?? 0;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: AppTheme.borderRadius,
        onTap: () => _addProduct(p),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: inCart
                  ? [AppTheme.primary.withValues(alpha: 0.15), AppTheme.card]
                  : [AppTheme.cardAlt, AppTheme.card],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: AppTheme.borderRadius,
            border: Border.all(
              color: inCart
                  ? AppTheme.primary.withValues(alpha: 0.50)
                  : AppTheme.border,
              width: inCart ? 1.5 : 1,
            ),
            boxShadow: inCart
                ? AppTheme.shadowGlowColor(AppTheme.primary, a: 0.12)
                : AppTheme.shadowSm,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: AppTheme.primary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(7),
                    ),
                    child: const Icon(
                      Icons.local_cafe_rounded,
                      size: 14,
                      color: AppTheme.primary,
                    ),
                  ),
                  const Spacer(),
                  if (inCart)
                    Container(
                      width: 22,
                      height: 22,
                      decoration: BoxDecoration(
                        gradient: AppTheme.primaryGrad,
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Text(
                          '$qty',
                          style: const TextStyle(
                            fontSize: 10,
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              const Spacer(),
              Text(
                p.name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: AppTheme.bodyMedium.copyWith(
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                moneyFromCents(p.priceCents),
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.success,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Qty control ───────────────────────────────────────────────────────────────
class _QtyControl extends StatelessWidget {
  final int qty;
  final bool busy;
  final VoidCallback onDecrement;
  final VoidCallback onIncrement;

  const _QtyControl({
    required this.qty,
    required this.busy,
    required this.onDecrement,
    required this.onIncrement,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _btn(Icons.remove_rounded, onDecrement),
        SizedBox(
          width: 28,
          child: busy
              ? const Center(
                  child: SizedBox(
                    width: 12,
                    height: 12,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppTheme.primary,
                    ),
                  ),
                )
              : Text(
                  '$qty',
                  textAlign: TextAlign.center,
                  style: AppTheme.bodyMedium.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
        ),
        _btn(Icons.add_rounded, onIncrement),
      ],
    );
  }

  Widget _btn(IconData icon, VoidCallback fn) {
    return InkWell(
      onTap: busy ? null : fn,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        width: 26,
        height: 26,
        decoration: BoxDecoration(
          color: AppTheme.cardAlt,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: AppTheme.border),
        ),
        child: Icon(
          icon,
          size: 13,
          color: busy ? AppTheme.textMuted : AppTheme.primary,
        ),
      ),
    );
  }
}

// ── Payment dialog ────────────────────────────────────────────────────────────
class _PaymentDialog extends StatefulWidget {
  final int totalCents;
  final String tableName;

  const _PaymentDialog({required this.totalCents, required this.tableName});

  @override
  State<_PaymentDialog> createState() => _PaymentDialogState();
}

class _PaymentDialogState extends State<_PaymentDialog> {
  String _method = 'cash';
  final _cashC = TextEditingController();
  int _cashGivenCents = 0;

  @override
  void dispose() {
    _cashC.dispose();
    super.dispose();
  }

  int get _changeCents => _cashGivenCents - widget.totalCents;
  bool get _canConfirm =>
      _method == 'card' || _cashGivenCents >= widget.totalCents;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppTheme.surface,
      shape: RoundedRectangleBorder(borderRadius: AppTheme.radiusLarge),
      child: SizedBox(
        width: 400,
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      gradient: AppTheme.successGrad,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.payments_rounded,
                      color: Colors.white,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Procesimi i Pagesës',
                          style: AppTheme.titleSmall,
                        ),
                        Text(widget.tableName, style: AppTheme.bodySmall),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(
                      Icons.close_rounded,
                      color: AppTheme.textSecondary,
                      size: 20,
                    ),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Total
              Container(
                padding: const EdgeInsets.symmetric(vertical: 22),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AppTheme.success.withValues(alpha: 0.08),
                      AppTheme.card,
                    ],
                  ),
                  borderRadius: AppTheme.borderRadius,
                  border: Border.all(
                    color: AppTheme.success.withValues(alpha: 0.25),
                  ),
                ),
                child: Column(
                  children: [
                    Text(
                      'TOTALI',
                      style: AppTheme.caption.copyWith(
                        letterSpacing: 2,
                        color: AppTheme.textSecondary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      moneyFromCents(widget.totalCents),
                      style: const TextStyle(
                        fontSize: 38,
                        fontWeight: FontWeight.w900,
                        color: AppTheme.success,
                        letterSpacing: -1,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Method toggle
              Row(
                children: [
                  Expanded(
                    child: _methodBtn('cash', Icons.money_rounded, 'CASH'),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _methodBtn(
                      'card',
                      Icons.credit_card_rounded,
                      'KARTË',
                    ),
                  ),
                ],
              ),

              // Cash input
              if (_method == 'cash') ...[
                const SizedBox(height: 14),
                TextField(
                  controller: _cashC,
                  autofocus: true,
                  style: const TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[\d.,]')),
                  ],
                  decoration: InputDecoration(
                    labelText: 'Shuma e dhënë (€)',
                    labelStyle: const TextStyle(color: AppTheme.textSecondary),
                    filled: true,
                    fillColor: AppTheme.cardAlt,
                    prefixIcon: const Icon(
                      Icons.euro_rounded,
                      color: AppTheme.primary,
                      size: 20,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: AppTheme.borderRadius,
                      borderSide: BorderSide(color: AppTheme.border),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: AppTheme.borderRadius,
                      borderSide: BorderSide(color: AppTheme.border),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: AppTheme.borderRadius,
                      borderSide: const BorderSide(
                        color: AppTheme.primary,
                        width: 1.5,
                      ),
                    ),
                  ),
                  onChanged: (v) {
                    final parsed = double.tryParse(v.replaceAll(',', '.')) ?? 0;
                    setState(() => _cashGivenCents = (parsed * 100).round());
                  },
                ),
                const SizedBox(height: 10),
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: _changeCents >= 0
                        ? AppTheme.success.withValues(alpha: 0.08)
                        : AppTheme.error.withValues(alpha: 0.08),
                    borderRadius: AppTheme.radiusSmall,
                    border: Border.all(
                      color: _changeCents >= 0
                          ? AppTheme.success.withValues(alpha: 0.25)
                          : AppTheme.error.withValues(alpha: 0.25),
                    ),
                  ),
                  child: Row(
                    children: [
                      Text(
                        _changeCents >= 0 ? 'Kusuri:' : 'Mungon:',
                        style: AppTheme.bodyMedium.copyWith(
                          color: AppTheme.textSecondary,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        moneyFromCents(_changeCents.abs()),
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                          color: _changeCents >= 0
                              ? AppTheme.success
                              : AppTheme.error,
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 20),

              // Confirm button
              GradientButton(
                label: 'KONFIRMO  ${moneyFromCents(widget.totalCents)}',
                icon: Icons.check_rounded,
                height: 54,
                fontSize: 15,
                gradient: AppTheme.successGrad,
                onTap: _canConfirm
                    ? () => Navigator.pop(context, _method)
                    : null,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _methodBtn(String method, IconData icon, String label) {
    final selected = _method == method;
    return GestureDetector(
      onTap: () => setState(() {
        _method = method;
        if (method == 'card') {
          _cashC.clear();
          _cashGivenCents = 0;
        }
      }),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          gradient: selected ? AppTheme.primaryGrad : null,
          color: selected ? null : AppTheme.cardAlt,
          borderRadius: AppTheme.radiusSmall,
          border: Border.all(
            color: selected ? Colors.transparent : AppTheme.border,
          ),
          boxShadow: selected
              ? AppTheme.shadowGlowColor(AppTheme.primary, a: 0.20)
              : [],
        ),
        child: Column(
          children: [
            Icon(
              icon,
              color: selected ? Colors.white : AppTheme.textSecondary,
              size: 22,
            ),
            const SizedBox(height: 6),
            Text(
              label,
              style: TextStyle(
                color: selected ? Colors.white : AppTheme.textSecondary,
                fontWeight: selected ? FontWeight.w800 : FontWeight.w500,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Receipt dialog ────────────────────────────────────────────────────────────
class _ReceiptDialog extends StatelessWidget {
  final String tableName;
  final List<OrderLine> lines;
  final int totalCents;
  final String paymentMethod;

  const _ReceiptDialog({
    required this.tableName,
    required this.lines,
    required this.totalCents,
    required this.paymentMethod,
  });

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final timeStr =
        '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
    final dateStr =
        '${now.day.toString().padLeft(2, '0')}/${now.month.toString().padLeft(2, '0')}/${now.year}';

    return Dialog(
      backgroundColor: AppTheme.surface,
      shape: RoundedRectangleBorder(borderRadius: AppTheme.radiusLarge),
      child: SizedBox(
        width: 380,
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Success checkmark
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  gradient: AppTheme.successGrad,
                  shape: BoxShape.circle,
                  boxShadow: AppTheme.shadowGlowColor(
                    AppTheme.success,
                    a: 0.35,
                  ),
                ),
                child: const Icon(
                  Icons.check_rounded,
                  color: Colors.white,
                  size: 30,
                ),
              ),
              const SizedBox(height: 14),
              const Text(
                'FATURA',
                style: TextStyle(
                  color: AppTheme.textPrimary,
                  fontWeight: FontWeight.w900,
                  fontSize: 14,
                  letterSpacing: 3,
                ),
              ),
              const SizedBox(height: 4),
              Text(tableName, style: AppTheme.bodySmall),
              Text('$dateStr  ·  $timeStr', style: AppTheme.caption),
              const SizedBox(height: 16),
              const PremiumDivider(),
              const SizedBox(height: 10),

              // Line items
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 240),
                child: SingleChildScrollView(
                  child: Column(
                    children: lines.map((l) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 5),
                        child: Row(
                          children: [
                            Container(
                              width: 24,
                              height: 24,
                              decoration: BoxDecoration(
                                color: AppTheme.primary.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Center(
                                child: Text(
                                  '${l.qty}',
                                  style: const TextStyle(
                                    color: AppTheme.primary,
                                    fontWeight: FontWeight.w800,
                                    fontSize: 11,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                l.name,
                                style: AppTheme.bodyMedium,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            Text(
                              moneyFromCents(l.lineTotalCents),
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                color: AppTheme.textPrimary,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),

              const SizedBox(height: 10),
              const PremiumDivider(),
              const SizedBox(height: 12),

              // Total
              Row(
                children: [
                  Text(
                    'TOTALI',
                    style: AppTheme.caption.copyWith(
                      letterSpacing: 2,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    moneyFromCents(totalCents),
                    style: const TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w900,
                      color: AppTheme.success,
                      letterSpacing: -0.5,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(
                    paymentMethod == 'cash'
                        ? Icons.money_rounded
                        : Icons.credit_card_rounded,
                    size: 14,
                    color: AppTheme.textSecondary,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    paymentMethod == 'cash' ? 'Cash' : 'Kartë',
                    style: AppTheme.bodySmall,
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: AppTheme.success.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(
                        color: AppTheme.success.withValues(alpha: 0.25),
                      ),
                    ),
                    child: const Text(
                      'PAGUAR',
                      style: TextStyle(
                        color: AppTheme.success,
                        fontWeight: FontWeight.w800,
                        fontSize: 10,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Close button
              GradientButton(
                label: 'Mbyll Tavolinën',
                icon: Icons.check_circle_outline_rounded,
                height: 50,
                gradient: AppTheme.successGrad,
                onTap: () => Navigator.pop(context),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
