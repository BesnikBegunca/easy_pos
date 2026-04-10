import 'db.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Categories
// ─────────────────────────────────────────────────────────────────────────────

enum ExpenseCategory {
  electricity,
  water,
  waste,
  investment,
  unexpected,
  custom,
}

extension ExpenseCategoryX on ExpenseCategory {
  String get key => switch (this) {
    ExpenseCategory.electricity => 'electricity',
    ExpenseCategory.water => 'water',
    ExpenseCategory.waste => 'waste',
    ExpenseCategory.investment => 'investment',
    ExpenseCategory.unexpected => 'unexpected',
    ExpenseCategory.custom => 'custom',
  };

  String get label => switch (this) {
    ExpenseCategory.electricity => 'Elektricitet',
    ExpenseCategory.water => 'Ujë',
    ExpenseCategory.waste => 'Mbeturina',
    ExpenseCategory.investment => 'Investim',
    ExpenseCategory.unexpected => 'Papritur',
    ExpenseCategory.custom => 'Tjetër',
  };
}

ExpenseCategory categoryFromKey(String key) {
  return ExpenseCategory.values.firstWhere(
    (e) => e.key == key,
    orElse: () => ExpenseCategory.custom,
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// Model
// ─────────────────────────────────────────────────────────────────────────────

class ExpenseRow {
  final int id;
  final ExpenseCategory category;
  final int amountCents;
  final String expenseDate; // YYYY-MM-DD
  final String? note;
  final int createdAt;

  const ExpenseRow({
    required this.id,
    required this.category,
    required this.amountCents,
    required this.expenseDate,
    this.note,
    required this.createdAt,
  });
}

// ─────────────────────────────────────────────────────────────────────────────
// DAO
// ─────────────────────────────────────────────────────────────────────────────

class ExpensesDao {
  ExpensesDao._();
  static final ExpensesDao I = ExpensesDao._();

  String _monthPrefix(int year, int month) =>
      '${year.toString().padLeft(4, '0')}-${month.toString().padLeft(2, '0')}-';

  Future<List<ExpenseRow>> getMonthExpenses(int year, int month) async {
    final db = await AppDb.I.db;
    final prefix = _monthPrefix(year, month);
    final rows = await db.query(
      'expenses',
      where: 'expense_date LIKE ?',
      whereArgs: ['$prefix%'],
      orderBy: 'expense_date DESC, id DESC',
    );
    return rows.map(_fromMap).toList();
  }

  Future<int> getMonthTotal(int year, int month) async {
    final db = await AppDb.I.db;
    final prefix = _monthPrefix(year, month);
    final rows = await db.rawQuery(
      "SELECT COALESCE(SUM(amount_cents),0) AS s FROM expenses WHERE expense_date LIKE ?",
      ['$prefix%'],
    );
    return (rows.first['s'] as int?) ?? 0;
  }

  Future<int> insert({
    required ExpenseCategory category,
    required int amountCents,
    required String expenseDate,
    String? note,
  }) async {
    final db = await AppDb.I.db;
    return db.insert('expenses', {
      'category': category.key,
      'amount_cents': amountCents,
      'expense_date': expenseDate,
      'note': note?.trim().isEmpty == true ? null : note?.trim(),
      'created_at': DateTime.now().millisecondsSinceEpoch,
    });
  }

  Future<void> update({
    required int id,
    required ExpenseCategory category,
    required int amountCents,
    required String expenseDate,
    String? note,
  }) async {
    final db = await AppDb.I.db;
    await db.update(
      'expenses',
      {
        'category': category.key,
        'amount_cents': amountCents,
        'expense_date': expenseDate,
        'note': note?.trim().isEmpty == true ? null : note?.trim(),
      },
      where: 'id=?',
      whereArgs: [id],
    );
  }

  Future<void> delete(int id) async {
    final db = await AppDb.I.db;
    await db.delete('expenses', where: 'id=?', whereArgs: [id]);
  }

  ExpenseRow _fromMap(Map<String, dynamic> m) {
    return ExpenseRow(
      id: m['id'] as int,
      category: categoryFromKey(m['category'] as String),
      amountCents: m['amount_cents'] as int,
      expenseDate: m['expense_date'] as String,
      note: m['note'] as String?,
      createdAt: m['created_at'] as int,
    );
  }
}
