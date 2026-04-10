import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../data/dao_expenses.dart';
import '../theme/app_theme.dart';
import '../util/money.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Category metadata
// ─────────────────────────────────────────────────────────────────────────────

IconData _categoryIcon(ExpenseCategory c) => switch (c) {
      ExpenseCategory.electricity => Icons.bolt_rounded,
      ExpenseCategory.water => Icons.water_drop_rounded,
      ExpenseCategory.waste => Icons.delete_outline_rounded,
      ExpenseCategory.investment => Icons.trending_up_rounded,
      ExpenseCategory.unexpected => Icons.warning_amber_rounded,
      ExpenseCategory.custom => Icons.receipt_long_rounded,
    };

Color _categoryColor(ExpenseCategory c) => switch (c) {
      ExpenseCategory.electricity => const Color(0xFFFBBF24),
      ExpenseCategory.water => const Color(0xFF38BDF8),
      ExpenseCategory.waste => const Color(0xFF94A3B8),
      ExpenseCategory.investment => const Color(0xFF34D399),
      ExpenseCategory.unexpected => const Color(0xFFF87171),
      ExpenseCategory.custom => const Color(0xFFA78BFA),
    };

// ─────────────────────────────────────────────────────────────────────────────
// Screen
// ─────────────────────────────────────────────────────────────────────────────

class ExpensesScreen extends StatefulWidget {
  const ExpensesScreen({super.key});

  @override
  State<ExpensesScreen> createState() => _ExpensesScreenState();
}

class _ExpensesScreenState extends State<ExpensesScreen> {
  late DateTime _month;
  List<ExpenseRow> _expenses = [];
  int _total = 0;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _month = DateTime(now.year, now.month);
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final rows =
          await ExpensesDao.I.getMonthExpenses(_month.year, _month.month);
      final total =
          await ExpensesDao.I.getMonthTotal(_month.year, _month.month);
      if (!mounted) return;
      setState(() {
        _expenses = rows;
        _total = total;
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _prevMonth() {
    setState(() => _month = DateTime(_month.year, _month.month - 1));
    _load();
  }

  void _nextMonth() {
    final now = DateTime.now();
    final next = DateTime(_month.year, _month.month + 1);
    if (next.isAfter(DateTime(now.year, now.month))) return;
    setState(() => _month = next);
    _load();
  }

  Future<void> _openForm({ExpenseRow? editing}) async {
    final saved = await showDialog<bool>(
      context: context,
      builder: (_) => _ExpenseFormDialog(editing: editing, month: _month),
    );
    if (saved == true && mounted) _load();
  }

  Future<void> _delete(ExpenseRow row) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppTheme.surface,
        shape: RoundedRectangleBorder(borderRadius: AppTheme.radiusLarge),
        title: const Text('Fshi shpenzimin?', style: AppTheme.titleSmall),
        content: Text(
          '${row.category.label} – ${moneyFromCents(row.amountCents)}',
          style: AppTheme.bodyMedium,
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Anulo')),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: AppTheme.error),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Fshi'),
          ),
        ],
      ),
    );
    if (ok == true && mounted) {
      await ExpensesDao.I.delete(row.id);
      _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    const months = [
      'Janar', 'Shkurt', 'Mars', 'Prill', 'Maj', 'Qershor',
      'Korrik', 'Gusht', 'Shtator', 'Tetor', 'Nëntor', 'Dhjetor',
    ];

    return Scaffold(
      backgroundColor: AppTheme.bg,
      appBar: AppBar(
        backgroundColor: AppTheme.surface,
        title: const Text('Shpenzimet'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_rounded),
            onPressed: _openForm,
            tooltip: 'Shto shpenzim',
          ),
        ],
      ),
      body: Column(
        children: [
          // Month navigator + total
          Container(
            color: AppTheme.surface,
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
            child: Column(
              children: [
                Row(
                  children: [
                    IconButton(
                      onPressed: _prevMonth,
                      icon: const Icon(Icons.chevron_left_rounded),
                      style: IconButton.styleFrom(
                        backgroundColor: AppTheme.card,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        '${months[_month.month - 1]} ${_month.year}',
                        textAlign: TextAlign.center,
                        style: AppTheme.titleSmall,
                      ),
                    ),
                    IconButton(
                      onPressed: _nextMonth,
                      icon: const Icon(Icons.chevron_right_rounded),
                      style: IconButton.styleFrom(
                        backgroundColor: AppTheme.card,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                // Total banner
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 20, vertical: 12),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        AppTheme.error.withValues(alpha: 0.16),
                        AppTheme.error.withValues(alpha: 0.06),
                      ],
                    ),
                    borderRadius: AppTheme.radiusSmall,
                    border: Border.all(
                        color: AppTheme.error.withValues(alpha: 0.25)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.account_balance_wallet_rounded,
                          color: AppTheme.error, size: 20),
                      const SizedBox(width: 10),
                      const Text(
                        'Total shpenzime',
                        style: TextStyle(
                            color: AppTheme.textSecondary, fontSize: 13),
                      ),
                      const Spacer(),
                      Text(
                        moneyFromCents(_total),
                        style: const TextStyle(
                          color: AppTheme.error,
                          fontWeight: FontWeight.w800,
                          fontSize: 18,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // List
          Expanded(
            child: _loading
                ? const Center(
                    child: CircularProgressIndicator(color: AppTheme.primary))
                : _expenses.isEmpty
                    ? _EmptyState(
                        month: months[_month.month - 1],
                        onAdd: _openForm,
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.all(16),
                        itemCount: _expenses.length,
                        separatorBuilder: (_, i) =>
                            const SizedBox(height: 10),
                        itemBuilder: (_, i) => _ExpenseTile(
                          row: _expenses[i],
                          onEdit: () => _openForm(editing: _expenses[i]),
                          onDelete: () => _delete(_expenses[i]),
                        ),
                      ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _openForm,
        backgroundColor: AppTheme.primary,
        foregroundColor: Colors.white,
        child: const Icon(Icons.add_rounded),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Expense Tile
// ─────────────────────────────────────────────────────────────────────────────

class _ExpenseTile extends StatelessWidget {
  final ExpenseRow row;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _ExpenseTile({
    required this.row,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final color = _categoryColor(row.category);
    final icon = _categoryIcon(row.category);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.card,
        borderRadius: AppTheme.borderRadius,
        border: Border.all(color: AppTheme.border),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
              border:
                  Border.all(color: color.withValues(alpha: 0.25)),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  row.category.label,
                  style: AppTheme.bodyMedium
                      .copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Text(
                      _formatDate(row.expenseDate),
                      style: AppTheme.caption,
                    ),
                    if (row.note != null && row.note!.isNotEmpty) ...[
                      const Text(' · ',
                          style: TextStyle(
                              color: AppTheme.textMuted, fontSize: 11)),
                      Expanded(
                        child: Text(
                          row.note!,
                          style: AppTheme.caption,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            moneyFromCents(row.amountCents),
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w800,
              fontSize: 15,
            ),
          ),
          const SizedBox(width: 8),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert_rounded,
                color: AppTheme.textMuted, size: 18),
            color: AppTheme.surface,
            shape: RoundedRectangleBorder(
                borderRadius: AppTheme.radiusSmall),
            onSelected: (v) {
              if (v == 'edit') onEdit();
              if (v == 'delete') onDelete();
            },
            itemBuilder: (_) => [
              const PopupMenuItem(
                value: 'edit',
                child: Row(children: [
                  Icon(Icons.edit_rounded,
                      color: AppTheme.primary, size: 16),
                  SizedBox(width: 8),
                  Text('Ndrysho',
                      style: TextStyle(color: AppTheme.textPrimary)),
                ]),
              ),
              const PopupMenuItem(
                value: 'delete',
                child: Row(children: [
                  Icon(Icons.delete_rounded,
                      color: AppTheme.error, size: 16),
                  SizedBox(width: 8),
                  Text('Fshi',
                      style:
                          TextStyle(color: AppTheme.error)),
                ]),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _formatDate(String d) {
    // d = YYYY-MM-DD
    final parts = d.split('-');
    if (parts.length != 3) return d;
    const months = [
      'Jan', 'Shk', 'Mar', 'Pri', 'Maj', 'Qer',
      'Kor', 'Gus', 'Sht', 'Tet', 'Nën', 'Dhj',
    ];
    final m = int.tryParse(parts[1]) ?? 1;
    return '${parts[2]} ${months[m - 1]} ${parts[0]}';
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Form Dialog
// ─────────────────────────────────────────────────────────────────────────────

class _ExpenseFormDialog extends StatefulWidget {
  final ExpenseRow? editing;
  final DateTime month;

  const _ExpenseFormDialog({this.editing, required this.month});

  @override
  State<_ExpenseFormDialog> createState() => _ExpenseFormDialogState();
}

class _ExpenseFormDialogState extends State<_ExpenseFormDialog> {
  late ExpenseCategory _category;
  late TextEditingController _amountCtrl;
  late TextEditingController _noteCtrl;
  late DateTime _date;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final e = widget.editing;
    _category = e?.category ?? ExpenseCategory.electricity;
    _amountCtrl = TextEditingController(
      text: e == null ? '' : (e.amountCents / 100).toStringAsFixed(0),
    );
    _noteCtrl = TextEditingController(text: e?.note ?? '');
    if (e != null) {
      final parts = e.expenseDate.split('-');
      _date = DateTime(
        int.parse(parts[0]),
        int.parse(parts[1]),
        int.parse(parts[2]),
      );
    } else {
      final now = DateTime.now();
      _date = DateTime(now.year, now.month, now.day);
    }
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  String _dateFmt(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/'
      '${d.month.toString().padLeft(2, '0')}/'
      '${d.year}';

  String _dateKey(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.dark(
            primary: AppTheme.primary,
            surface: AppTheme.surface,
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null && mounted) {
      setState(() => _date = picked);
    }
  }

  Future<void> _save() async {
    final amtEur = int.tryParse(_amountCtrl.text.trim());
    if (amtEur == null || amtEur <= 0) {
      setState(() => _error = 'Shuma duhet të jetë > 0');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final note = _noteCtrl.text.trim().isEmpty ? null : _noteCtrl.text.trim();
      if (widget.editing != null) {
        await ExpensesDao.I.update(
          id: widget.editing!.id,
          category: _category,
          amountCents: amtEur * 100,
          expenseDate: _dateKey(_date),
          note: note,
        );
      } else {
        await ExpensesDao.I.insert(
          category: _category,
          amountCents: amtEur * 100,
          expenseDate: _dateKey(_date),
          note: note,
        );
      }
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppTheme.surface,
      shape: RoundedRectangleBorder(borderRadius: AppTheme.radiusLarge),
      title: Text(
        widget.editing == null ? 'Shto Shpenzim' : 'Ndrysho Shpenzim',
        style: AppTheme.titleSmall,
      ),
      content: SizedBox(
        width: 360,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Category selector
            const Text('Kategoria',
                style: TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: ExpenseCategory.values.map((cat) {
                final selected = _category == cat;
                final color = _categoryColor(cat);
                return GestureDetector(
                  onTap: () => setState(() => _category = cat),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 140),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 7),
                    decoration: BoxDecoration(
                      color: selected
                          ? color.withValues(alpha: 0.18)
                          : AppTheme.card,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: selected
                            ? color.withValues(alpha: 0.50)
                            : AppTheme.border,
                        width: selected ? 1.2 : 1,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(_categoryIcon(cat),
                            color: selected ? color : AppTheme.textMuted,
                            size: 14),
                        const SizedBox(width: 5),
                        Text(
                          cat.label,
                          style: TextStyle(
                            color: selected ? color : AppTheme.textSecondary,
                            fontWeight: selected
                                ? FontWeight.w700
                                : FontWeight.w500,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),
            // Amount
            TextField(
              controller: _amountCtrl,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: const InputDecoration(
                labelText: 'Shuma (€)',
                prefixIcon: Icon(Icons.euro_rounded, size: 18),
              ),
            ),
            const SizedBox(height: 12),
            // Date picker
            GestureDetector(
              onTap: _pickDate,
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: AppTheme.cardAlt,
                  borderRadius: AppTheme.borderRadius,
                  border: Border.all(color: AppTheme.border),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.calendar_today_rounded,
                        color: AppTheme.textMuted, size: 16),
                    const SizedBox(width: 10),
                    Text(
                      _dateFmt(_date),
                      style: AppTheme.bodyMedium,
                    ),
                    const Spacer(),
                    const Icon(Icons.edit_calendar_rounded,
                        color: AppTheme.textMuted, size: 14),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            // Note
            TextField(
              controller: _noteCtrl,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: 'Shënim (opsional)',
                prefixIcon: Icon(Icons.notes_rounded, size: 18),
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 10),
              Text(_error!,
                  style: const TextStyle(
                      color: AppTheme.error, fontSize: 12)),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.pop(context, false),
          child: const Text('Anulo'),
        ),
        ElevatedButton(
          onPressed: _saving ? null : _save,
          child: _saving
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white))
              : Text(widget.editing == null ? 'Shto' : 'Ruaj'),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Empty State
// ─────────────────────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  final String month;
  final VoidCallback onAdd;
  const _EmptyState({required this.month, required this.onAdd});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: AppTheme.card,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppTheme.border),
            ),
            child: const Icon(Icons.receipt_long_rounded,
                size: 32, color: AppTheme.textMuted),
          ),
          const SizedBox(height: 16),
          Text(
            'Nuk ka shpenzime për $month',
            style: AppTheme.bodyMedium
                .copyWith(color: AppTheme.textSecondary),
          ),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: onAdd,
            icon: const Icon(Icons.add_rounded, size: 18),
            label: const Text('Shto Shpenzim'),
          ),
        ],
      ),
    );
  }
}
