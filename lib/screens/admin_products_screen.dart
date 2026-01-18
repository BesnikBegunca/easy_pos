import 'package:flutter/material.dart';
import '../data/dao_products.dart';
import '../util/money.dart';

class AdminProductsScreen extends StatefulWidget {
  const AdminProductsScreen({super.key});

  @override
  State<AdminProductsScreen> createState() => _AdminProductsScreenState();
}

class _AdminProductsScreenState extends State<AdminProductsScreen> {
  bool loading = true;
  List<CategoryRow> categories = [];
  List<ProductRow> products = [];
  int? selectedCategoryId;

  Future<void> _load() async {
    setState(() => loading = true);
    categories = await ProductsDao.I.listCategories();
    selectedCategoryId ??= categories.isEmpty ? null : categories.first.id;
    products = await ProductsDao.I.listActiveProducts(categoryId: selectedCategoryId);
    if (!mounted) return;
    setState(() => loading = false);
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _addProductDialog() async {
    final nameC = TextEditingController();
    final priceC = TextEditingController();
    int? catId = selectedCategoryId;

    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Shto Produkt'),
        content: SizedBox(
          width: 460,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: nameC, decoration: const InputDecoration(labelText: 'Emri')),
              const SizedBox(height: 10),
              TextField(controller: priceC, decoration: const InputDecoration(labelText: 'Çmimi (€) p.sh. 2.50')),
              const SizedBox(height: 10),
              DropdownButtonFormField<int>(
                value: catId,
                items: [for (final c in categories) DropdownMenuItem(value: c.id, child: Text(c.name))],
                onChanged: (v) => catId = v,
                decoration: const InputDecoration(labelText: 'Kategoria'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Anulo')),
          ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('Ruaj')),
        ],
      ),
    );

    if (ok != true) return;

    final price = double.tryParse(priceC.text.replaceAll(',', '.')) ?? 0;
    final cents = (price * 100).round();

    await ProductsDao.I.addProduct(name: nameC.text, priceCents: cents, categoryId: catId);
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Row(
            children: [
              const Text('Produktet', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
              const SizedBox(width: 12),
              SizedBox(
                width: 240,
                child: DropdownButtonFormField<int>(
                  value: selectedCategoryId,
                  items: [for (final c in categories) DropdownMenuItem(value: c.id, child: Text(c.name))],
                  onChanged: (v) async {
                    selectedCategoryId = v;
                    await _load();
                  },
                  decoration: const InputDecoration(labelText: 'Kategoria'),
                ),
              ),
              const Spacer(),
              ElevatedButton.icon(
                onPressed: _addProductDialog,
                icon: const Icon(Icons.add),
                label: const Text('Shto Produkt'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Expanded(
            child: loading
                ? const Center(child: CircularProgressIndicator())
                : Card(
              child: ListView.separated(
                itemCount: products.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (_, i) {
                  final p = products[i];
                  return ListTile(
                    title: Text(p.name),
                    subtitle: Text(p.categoryName ?? ''),
                    trailing: Text(moneyFromCents(p.priceCents), style: const TextStyle(fontWeight: FontWeight.w900)),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}
