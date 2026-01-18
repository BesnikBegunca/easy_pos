import 'db.dart';

class CategoryRow {
  final int id;
  final String name;
  CategoryRow({required this.id, required this.name});
}

class ProductRow {
  final int id;
  final String name;
  final int priceCents;
  final int? categoryId;
  final String? categoryName;

  ProductRow({required this.id, required this.name, required this.priceCents, required this.categoryId, required this.categoryName});
}

class ProductsDao {
  ProductsDao._();
  static final ProductsDao I = ProductsDao._();

  Future<List<CategoryRow>> listCategories() async {
    final db = await AppDb.I.db;
    final rows = await db.query('categories', orderBy: 'sort_index ASC, name ASC');
    return rows.map((e) => CategoryRow(id: e['id'] as int, name: e['name'] as String)).toList();
  }

  Future<int> addCategory(String name) async {
    final db = await AppDb.I.db;
    return db.insert('categories', {'name': name.trim(), 'sort_index': 0});
  }

  Future<List<ProductRow>> listActiveProducts({int? categoryId, String? search}) async {
    final db = await AppDb.I.db;

    final where = <String>['p.is_active=1'];
    final args = <Object?>[];

    if (categoryId != null) {
      where.add('p.category_id=?');
      args.add(categoryId);
    }

    final q = (search ?? '').trim();
    if (q.isNotEmpty) {
      where.add('LOWER(p.name) LIKE ?');
      args.add('%${q.toLowerCase()}%');
    }

    final rows = await db.rawQuery('''
SELECT p.id, p.name, p.price_cents, p.category_id, c.name AS category_name
FROM products p
LEFT JOIN categories c ON c.id = p.category_id
WHERE ${where.join(' AND ')}
ORDER BY c.sort_index ASC, c.name ASC, p.name ASC
''', args);

    return rows.map((e) => ProductRow(
      id: e['id'] as int,
      name: e['name'] as String,
      priceCents: e['price_cents'] as int,
      categoryId: e['category_id'] as int?,
      categoryName: e['category_name'] as String?,
    )).toList();
  }


  Future<int> addProduct({required String name, required int priceCents, int? categoryId}) async {
    final db = await AppDb.I.db;
    return db.insert('products', {
      'name': name.trim(),
      'price_cents': priceCents,
      'category_id': categoryId,
      'is_active': 1,
      'created_at': DateTime.now().millisecondsSinceEpoch,
    });
  }

  Future<void> setProductActive(int id, bool active) async {
    final db = await AppDb.I.db;
    await db.update('products', {'is_active': active ? 1 : 0}, where: 'id=?', whereArgs: [id]);
  }

}
