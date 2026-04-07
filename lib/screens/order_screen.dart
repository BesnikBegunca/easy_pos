import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../auth/session.dart';
import '../data/dao_orders.dart';
import '../data/dao_products.dart';
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

  final _searchC = TextEditingController();
  final Set<int> _busy = {}; // itemIds currently being mutated

  @override
  void initState() {
    super.initState();
    _searchC.addListener(() => _reloadProducts());
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
      await Future.wait([_reloadProducts(), _refreshCart()]);
    } catch (e) {
      _error = e.toString();
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _refreshCart() async {
    if (_orderId == 0) return;
    final lines = await OrdersDao.I.getOrderLines(_orderId);
    final total = await OrdersDao.I.getOrderTotalCents(_orderId);
    if (!mounted) return;
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
    if (!mounted) return;
    setState(() => _products = prods);
  }

  // ── Cart mutations (all direct DB writes) ──────────────────────────────────

  Future<void> _addProduct(ProductRow p) async {
    await OrdersDao.I.addProductToOrder(
      orderId: _orderId,
      productId: p.id,
      unitPriceCents: p.priceCents,
    );
    await _refreshCart();
  }

  Future<void> _incrementLine(OrderLine line) async {
    if (_busy.contains(line.itemId)) return;
    setState(() => _busy.add(line.itemId));
    try {
      await OrdersDao.I.setItemQty(
        itemId: line.itemId,
        orderId: _orderId,
        newQty: line.qty + 1,
      );
      await _refreshCart();
    } finally {
      if (mounted) setState(() => _busy.remove(line.itemId));
    }
  }

  Future<void> _decrementLine(OrderLine line) async {
    if (_busy.contains(line.itemId)) return;
    setState(() => _busy.add(line.itemId));
    try {
      await OrdersDao.I.setItemQty(
        itemId: line.itemId,
        orderId: _orderId,
        newQty: line.qty - 1,
      );
      await _refreshCart();
    } finally {
      if (mounted) setState(() => _busy.remove(line.itemId));
    }
  }

  Future<void> _removeLine(OrderLine line) async {
    if (_busy.contains(line.itemId)) return;
    setState(() => _busy.add(line.itemId));
    try {
      await OrdersDao.I.removeOrderItem(line.itemId, _orderId);
      await _refreshCart();
    } finally {
      if (mounted) setState(() => _busy.remove(line.itemId));
    }
  }

  // ── Print (send to kitchen) ────────────────────────────────────────────────

  Future<void> _onPrinto() async {
    if (_lines.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Shporta është bosh.')),
      );
      return;
    }
    await OrdersDao.I.markItemsAsPrinted(_orderId);
    if (!mounted) return;
    Session.I.logout();
    Navigator.of(context).pushReplacementNamed('/login');
  }

  // ── Payment ────────────────────────────────────────────────────────────────

  Future<void> _onPay() async {
    if (_lines.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Shporta është bosh.')),
      );
      return;
    }

    final method = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _PaymentDialog(
        totalCents: _totalCents,
        tableName: widget.tableName,
      ),
    );
    if (method == null || !mounted) return;

    try {
      await OrdersDao.I.payAndClose(
        orderId: _orderId,
        tableId: widget.tableId,
        waiterId: widget.waiterId,
        paymentMethod: method,
      );
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gabim në pagesë: $e')),
      );
    }
  }

  // ── Close table (waiter release, no settlement impact) ────────────────────

  Future<void> _onCloseTable() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppTheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Mbyll ${widget.tableName}', style: AppTheme.titleMedium),
        content: Text(
          'Klientët u larguan pa paguar.\nTavolina lirohet për klientë të rinj.\n\nTotali yt i settlement-it nuk ndryshohet.',
          style: AppTheme.bodyMedium.copyWith(color: AppTheme.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Anulo'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.warning,
              foregroundColor: Colors.black87,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              'Mbyll Tavolinen',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );

    if (ok != true || !mounted) return;

    await TablesDao.I.releaseTableAsWaiter(widget.tableId);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${widget.tableName} u lirua.'),
        backgroundColor: AppTheme.warning,
      ),
    );
    Navigator.pop(context, true);
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return AppScaffold(
        topBar: AppTopBar(title: widget.tableName),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_orderId == 0 || _error != null) {
      return AppScaffold(
        topBar: AppTopBar(title: widget.tableName),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 48, color: Colors.red),
              const SizedBox(height: 16),
              Text('Gabim në hapjen e tavolinës', style: AppTheme.titleMedium),
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
                icon: Icons.arrow_back,
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
        ),
      );
    }

    return AppScaffold(
      topBar: AppTopBar(
        title: widget.tableName,
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            child: ElevatedButton.icon(
              onPressed: _onCloseTable,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.warning,
                foregroundColor: Colors.black87,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              icon: const Icon(Icons.exit_to_app_rounded, size: 16),
              label: const Text(
                'Mbyll',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
      body: Row(
        children: [
          SizedBox(width: 320, child: _buildCartPanel()),
          Expanded(child: _buildProductBrowser()),
        ],
      ),
    );
  }

  // ── Cart panel ─────────────────────────────────────────────────────────────

  Widget _buildCartPanel() {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surface,
        border: Border(
          right: BorderSide(color: Colors.white.withValues(alpha: 0.06)),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Row(
              children: [
                const Icon(
                  Icons.receipt_long_rounded,
                  color: AppTheme.primary,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text('Porosia', style: AppTheme.titleSmall),
                const Spacer(),
                if (_lines.isNotEmpty)
                  Text(
                    '${_lines.length} produkt${_lines.length > 1 ? 'e' : ''}',
                    style: AppTheme.bodySmall,
                  ),
              ],
            ),
          ),
          Divider(height: 1, color: Colors.white.withValues(alpha: 0.06)),

          // Lines
          Expanded(
            child: _lines.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.add_shopping_cart_rounded,
                          size: 40,
                          color: Colors.white.withValues(alpha: 0.12),
                        ),
                        const SizedBox(height: 12),
                        Text('Shto produkte nga lista', style: AppTheme.bodySmall),
                      ],
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    itemCount: _lines.length,
                    separatorBuilder: (_, _) => Divider(
                      height: 1,
                      color: Colors.white.withValues(alpha: 0.05),
                    ),
                    itemBuilder: (_, i) => _buildCartLine(_lines[i]),
                  ),
          ),

          // Total + pay button
          Container(
            decoration: BoxDecoration(
              color: AppTheme.tile,
              border: Border(
                top: BorderSide(color: Colors.white.withValues(alpha: 0.07)),
              ),
            ),
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Text(
                      'TOTALI',
                      style: AppTheme.bodySmall.copyWith(
                        letterSpacing: 1,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      moneyFromCents(_totalCents),
                      style: AppTheme.titleMedium.copyWith(
                        color: AppTheme.primary,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                // PRINTO — send to kitchen, table stays open
                SizedBox(
                  height: 44,
                  child: ElevatedButton.icon(
                    onPressed: _lines.isNotEmpty ? _onPrinto : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF3B82F6),
                      foregroundColor: Colors.white,
                      disabledBackgroundColor:
                          const Color(0xFF3B82F6).withValues(alpha: 0.25),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    icon: const Icon(Icons.print_rounded, size: 18),
                    label: const Text(
                      'PRINTO',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                // PAGUAJ — full payment, closes table
                SizedBox(
                  height: 48,
                  child: ElevatedButton.icon(
                    onPressed: _lines.isNotEmpty ? _onPay : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.success,
                      foregroundColor: Colors.white,
                      disabledBackgroundColor:
                          AppTheme.success.withValues(alpha: 0.25),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    icon: const Icon(Icons.payments_rounded, size: 20),
                    label: const Text(
                      'PAGUAJ',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
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
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
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
                Text(moneyFromCents(line.unitPriceCents), style: AppTheme.bodySmall),
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
            width: 62,
            child: Text(
              moneyFromCents(line.lineTotalCents),
              textAlign: TextAlign.right,
              style: AppTheme.bodyMedium.copyWith(
                fontWeight: FontWeight.w700,
                color: AppTheme.primary,
              ),
            ),
          ),
          // Remove button
          IconButton(
            onPressed: isBusy ? null : () => _removeLine(line),
            icon: const Icon(Icons.close_rounded, size: 15),
            color: Colors.white30,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
          ),
        ],
      ),
    );
  }

  // ── Product browser ────────────────────────────────────────────────────────

  Widget _buildProductBrowser() {
    return Column(
      children: [
        // Category chips
        if (_categories.isNotEmpty)
          SizedBox(
            height: 50,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              itemCount: _categories.length,
              itemBuilder: (_, i) {
                final c = _categories[i];
                final selected = _selectedCategoryId == c.id;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(c.name),
                    selected: selected,
                    onSelected: (_) async {
                      setState(() => _selectedCategoryId = c.id);
                      await _reloadProducts();
                    },
                    selectedColor: AppTheme.primary,
                    backgroundColor: AppTheme.tile,
                    labelStyle: TextStyle(
                      color: selected ? Colors.white : AppTheme.textSecondary,
                      fontWeight:
                          selected ? FontWeight.w700 : FontWeight.w400,
                      fontSize: 13,
                    ),
                    side: BorderSide(
                      color: selected
                          ? AppTheme.primary
                          : Colors.white.withValues(alpha: 0.1),
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                    showCheckmark: false,
                  ),
                );
              },
            ),
          ),

        // Search bar
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
          child: AppTextField(
            controller: _searchC,
            hint: 'Kërko produkt…',
            prefixIcon: Icons.search_rounded,
          ),
        ),

        // Product grid
        Expanded(
          child: _products.isEmpty
              ? Center(
                  child: Text('S\u2019ka produkte.', style: AppTheme.bodySmall),
                )
              : GridView.builder(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                  gridDelegate:
                      const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 4,
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 10,
                    childAspectRatio: 1.05,
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
    final qtyInCart = cartLine?.qty ?? 0;

    return Material(
      color: AppTheme.tile,
      borderRadius: AppTheme.borderRadius,
      child: InkWell(
        borderRadius: AppTheme.borderRadius,
        onTap: () => _addProduct(p),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: AppTheme.borderRadius,
            border: Border.all(
              color: inCart
                  ? AppTheme.primary.withValues(alpha: 0.55)
                  : AppTheme.borderColor,
              width: inCart ? 1.5 : 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.local_cafe_rounded,
                    size: 16,
                    color: AppTheme.primary.withValues(alpha: 0.6),
                  ),
                  const Spacer(),
                  if (inCart)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: AppTheme.primary,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        '$qtyInCart',
                        style: const TextStyle(
                          fontSize: 11,
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
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
                ),
              ),
              const SizedBox(height: 4),
              Text(
                moneyFromCents(p.priceCents),
                style: AppTheme.bodySmall.copyWith(
                  color: AppTheme.primary,
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

// ─── Qty control ──────────────────────────────────────────────────────────────

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
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2),
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
          color: AppTheme.tileAlt,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        ),
        child: Icon(
          icon,
          size: 14,
          color: busy ? Colors.white24 : AppTheme.primary,
        ),
      ),
    );
  }
}

// ─── Payment dialog ───────────────────────────────────────────────────────────

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
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: SizedBox(
        width: 380,
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              Row(
                children: [
                  const Icon(
                    Icons.payments_rounded,
                    color: AppTheme.primary,
                    size: 22,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Pagesa — ${widget.tableName}',
                      style: AppTheme.titleSmall,
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(
                      Icons.close,
                      size: 20,
                      color: AppTheme.textSecondary,
                    ),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Total amount
              Container(
                padding: const EdgeInsets.symmetric(vertical: 20),
                decoration: BoxDecoration(
                  color: AppTheme.tile,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.borderColor),
                ),
                child: Column(
                  children: [
                    Text(
                      'TOTALI',
                      style: AppTheme.bodySmall.copyWith(letterSpacing: 1.5),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      moneyFromCents(widget.totalCents),
                      style: const TextStyle(
                        fontSize: 36,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.primary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

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
                      'CARD',
                    ),
                  ),
                ],
              ),

              // Cash input + change
              if (_method == 'cash') ...[
                const SizedBox(height: 16),
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
                    labelStyle:
                        const TextStyle(color: AppTheme.textSecondary),
                    filled: true,
                    fillColor: AppTheme.tile,
                    prefixIcon: const Icon(
                      Icons.euro,
                      color: AppTheme.primary,
                      size: 20,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: AppTheme.borderColor),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: AppTheme.borderColor),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(
                        color: AppTheme.primary,
                        width: 1.5,
                      ),
                    ),
                  ),
                  onChanged: (v) {
                    final parsed =
                        double.tryParse(v.replaceAll(',', '.')) ?? 0;
                    setState(() => _cashGivenCents = (parsed * 100).round());
                  },
                ),
                const SizedBox(height: 12),
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
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: _changeCents >= 0
                          ? AppTheme.success.withValues(alpha: 0.3)
                          : AppTheme.error.withValues(alpha: 0.3),
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
                          fontWeight: FontWeight.w800,
                          color: _changeCents >= 0
                              ? AppTheme.success
                              : AppTheme.error,
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 24),

              // Confirm
              SizedBox(
                height: 52,
                child: ElevatedButton(
                  onPressed: _canConfirm
                      ? () => Navigator.pop(context, _method)
                      : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.success,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor:
                        AppTheme.success.withValues(alpha: 0.22),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: Text(
                    'PAGUAJ ${moneyFromCents(widget.totalCents)}',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
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
          color: selected
              ? AppTheme.primary.withValues(alpha: 0.12)
              : AppTheme.tile,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selected
                ? AppTheme.primary
                : Colors.white.withValues(alpha: 0.08),
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              color: selected ? AppTheme.primary : AppTheme.textSecondary,
              size: 24,
            ),
            const SizedBox(height: 6),
            Text(
              label,
              style: TextStyle(
                color:
                    selected ? AppTheme.primary : AppTheme.textSecondary,
                fontWeight:
                    selected ? FontWeight.w700 : FontWeight.w400,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
