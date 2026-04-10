import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../auth/dao_users.dart';
import '../auth/roles.dart';
import '../data/dao_worker_attendance.dart';
import '../theme/app_theme.dart';
import '../util/money.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Worker List Screen
// ─────────────────────────────────────────────────────────────────────────────

class WorkerCalendarScreen extends StatefulWidget {
  const WorkerCalendarScreen({super.key});

  @override
  State<WorkerCalendarScreen> createState() => _WorkerCalendarScreenState();
}

class _WorkerCalendarScreenState extends State<WorkerCalendarScreen> {
  List<AppUserRow> _workers = [];
  Map<int, ({int workedDays, int advanceCents})> _attendanceStats = {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final all = await UsersDao.I.listUsers();
      if (!mounted) return;
      final workers = all
          .where((u) =>
              u.isActive &&
              (u.role == UserRole.waiter || u.role == UserRole.manager))
          .toList();
      final statsMap = <int, ({int workedDays, int advanceCents})>{};
      for (final w in workers) {
        statsMap[w.id] = await WorkerAttendanceDao.I.getAllTimeSummary(w.id);
      }
      if (!mounted) return;
      setState(() {
        _workers = workers;
        _attendanceStats = statsMap;
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _setSalary(AppUserRow worker) async {
    final ctrl = TextEditingController(
      text: worker.dailySalaryCents == 0
          ? ''
          : (worker.dailySalaryCents / 100).toStringAsFixed(0),
    );
    final result = await showDialog<int>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppTheme.surface,
        shape: RoundedRectangleBorder(borderRadius: AppTheme.radiusLarge),
        title: Text(
          'Paga ditore – ${worker.fullName ?? worker.username}',
          style: AppTheme.titleSmall,
        ),
        content: TextField(
          controller: ctrl,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Paga ditore (€)',
            prefixIcon: Icon(Icons.euro_rounded, size: 18),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Anulo'),
          ),
          ElevatedButton(
            onPressed: () {
              final v = int.tryParse(ctrl.text) ?? 0;
              Navigator.pop(context, v * 100);
            },
            child: const Text('Ruaj'),
          ),
        ],
      ),
    );
    if (result != null && mounted) {
      await UsersDao.I.setDailySalary(worker.id, result);
      _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bg,
      appBar: AppBar(
        title: const Text('Kalendari i Punonjësve'),
        backgroundColor: AppTheme.surface,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _load,
          ),
        ],
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: AppTheme.primary))
          : _workers.isEmpty
              ? _EmptyState(
                  icon: Icons.people_outline_rounded,
                  message: 'Nuk ka punonjës aktivë.',
                )
              : ListView(
                  padding: const EdgeInsets.all(20),
                  children: [
                    WorkerSalaryStatsPanel(
                      workers: _workers,
                      stats: _attendanceStats,
                    ),
                    const SizedBox(height: 4),
                    ...List.generate(_workers.length, (i) => Padding(
                      padding: EdgeInsets.only(
                          bottom: i < _workers.length - 1 ? 12 : 0),
                      child: _WorkerCard(
                        worker: _workers[i],
                        onSetSalary: () => _setSalary(_workers[i]),
                        onOpenCalendar: () async {
                          await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) =>
                                  _WorkerMonthCalendar(worker: _workers[i]),
                            ),
                          );
                          _load();
                        },
                      ),
                    )),
                  ],
                ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Worker Card
// ─────────────────────────────────────────────────────────────────────────────

class _WorkerCard extends StatelessWidget {
  final AppUserRow worker;
  final VoidCallback onSetSalary;
  final VoidCallback onOpenCalendar;

  const _WorkerCard({
    required this.worker,
    required this.onSetSalary,
    required this.onOpenCalendar,
  });

  @override
  Widget build(BuildContext context) {
    final name = worker.fullName?.trim().isNotEmpty == true
        ? worker.fullName!
        : worker.username;
    final letter = name[0].toUpperCase();
    final hasSalary = worker.dailySalaryCents > 0;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.card,
        borderRadius: AppTheme.borderRadius,
        border: Border.all(color: AppTheme.border),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              gradient: AppTheme.primaryGrad,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Center(
              child: Text(
                letter,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 20,
                ),
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: AppTheme.bodyMedium.copyWith(
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 3),
                Row(
                  children: [
                    StatusBadge(
                      label: worker.role == UserRole.manager
                          ? 'Manager'
                          : 'Kamerier',
                      color: worker.role == UserRole.manager
                          ? AppTheme.info
                          : AppTheme.primary,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      hasSalary
                          ? '${(worker.dailySalaryCents / 100).toStringAsFixed(0)} €/ditë'
                          : 'Pa pagë',
                      style: AppTheme.caption.copyWith(
                        color: hasSalary
                            ? AppTheme.warning
                            : AppTheme.textMuted,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: onSetSalary,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
              margin: const EdgeInsets.only(right: 8),
              decoration: BoxDecoration(
                color: AppTheme.warning.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                    color: AppTheme.warning.withValues(alpha: 0.25)),
              ),
              child: const Icon(Icons.euro_rounded,
                  color: AppTheme.warning, size: 16),
            ),
          ),
          GestureDetector(
            onTap: onOpenCalendar,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
              decoration: BoxDecoration(
                color: AppTheme.primary.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                    color: AppTheme.primary.withValues(alpha: 0.25)),
              ),
              child: const Icon(Icons.calendar_month_rounded,
                  color: AppTheme.primary, size: 16),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Monthly Calendar
// ─────────────────────────────────────────────────────────────────────────────

class _WorkerMonthCalendar extends StatefulWidget {
  final AppUserRow worker;
  const _WorkerMonthCalendar({required this.worker});

  @override
  State<_WorkerMonthCalendar> createState() => _WorkerMonthCalendarState();
}

class _WorkerMonthCalendarState extends State<_WorkerMonthCalendar> {
  late DateTime _month;
  Map<String, AttendanceRow> _attendance = {};
  bool _loading = true;

  AppUserRow get _worker => widget.worker;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _month = DateTime(now.year, now.month);
    _loadMonth();
  }

  Future<void> _loadMonth() async {
    setState(() => _loading = true);
    final rows = await WorkerAttendanceDao.I.getMonthAttendance(
      _worker.id,
      _month.year,
      _month.month,
    );
    if (!mounted) return;
    setState(() {
      _attendance = {for (final r in rows) r.workDate: r};
      _loading = false;
    });
  }

  void _prevMonth() {
    setState(() {
      _month = DateTime(_month.year, _month.month - 1);
    });
    _loadMonth();
  }

  void _nextMonth() {
    final now = DateTime.now();
    final next = DateTime(_month.year, _month.month + 1);
    if (next.isAfter(DateTime(now.year, now.month))) return;
    setState(() => _month = next);
    _loadMonth();
  }

  String _dateKey(int day) {
    return '${_month.year.toString().padLeft(4, '0')}-'
        '${_month.month.toString().padLeft(2, '0')}-'
        '${day.toString().padLeft(2, '0')}';
  }

  Future<void> _tapDay(int day) async {
    final key = _dateKey(day);
    final existing = _attendance[key];
    final nowWorked = existing?.worked ?? false;
    final nowAdvance = existing?.advanceCents ?? 0;

    final result = await showDialog<({bool worked, int advanceCents})>(
      context: context,
      builder: (_) => _DayDialog(
        day: day,
        month: _month,
        workerName: _worker.fullName ?? _worker.username,
        initialWorked: nowWorked,
        initialAdvanceCents: nowAdvance,
      ),
    );

    if (result != null && mounted) {
      await WorkerAttendanceDao.I.upsertDay(
        userId: _worker.id,
        year: _month.year,
        month: _month.month,
        day: day,
        worked: result.worked,
        advanceCents: result.advanceCents,
      );
      _loadMonth();
    }
  }

  int get _daysInMonth =>
      DateTime(_month.year, _month.month + 1, 0).day;

  int get _startWeekday =>
      DateTime(_month.year, _month.month, 1).weekday; // 1=Mon..7=Sun

  int get _workedDays =>
      _attendance.values.where((r) => r.worked).length;

  int get _totalAdvanceCents =>
      _attendance.values.fold(0, (s, r) => s + r.advanceCents);

  int get _totalEarnedCents =>
      (_workedDays * _worker.dailySalaryCents) - _totalAdvanceCents;

  @override
  Widget build(BuildContext context) {
    final name = _worker.fullName?.trim().isNotEmpty == true
        ? _worker.fullName!
        : _worker.username;

    const months = [
      'Janar', 'Shkurt', 'Mars', 'Prill', 'Maj', 'Qershor',
      'Korrik', 'Gusht', 'Shtator', 'Tetor', 'Nëntor', 'Dhjetor',
    ];

    return Scaffold(
      backgroundColor: AppTheme.bg,
      appBar: AppBar(
        backgroundColor: AppTheme.surface,
        title: Text(name),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: AppTheme.primary))
          : Column(
              children: [
                // Month navigator
                Container(
                  color: AppTheme.surface,
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
                  child: Row(
                    children: [
                      IconButton(
                        onPressed: _prevMonth,
                        icon: const Icon(Icons.chevron_left_rounded,
                            color: AppTheme.textPrimary),
                        style: IconButton.styleFrom(
                          backgroundColor:
                              AppTheme.card,
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
                        icon: const Icon(Icons.chevron_right_rounded,
                            color: AppTheme.textPrimary),
                        style: IconButton.styleFrom(
                          backgroundColor: AppTheme.card,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                    ],
                  ),
                ),

                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        // Weekday headers
                        _buildWeekdayHeaders(),
                        const SizedBox(height: 8),
                        // Calendar grid
                        _buildCalendarGrid(),
                        const SizedBox(height: 20),
                        // Summary card
                        _buildSummaryCard(),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildWeekdayHeaders() {
    const days = ['Hë', 'Ma', 'Më', 'En', 'Pr', 'Sh', 'Di'];
    return Row(
      children: days.map((d) {
        return Expanded(
          child: Center(
            child: Text(
              d,
              style: AppTheme.caption.copyWith(
                fontWeight: FontWeight.w700,
                letterSpacing: 0.6,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildCalendarGrid() {
    final totalCells = (_startWeekday - 1) + _daysInMonth;
    final rows = (totalCells / 7).ceil();

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 7,
        mainAxisSpacing: 6,
        crossAxisSpacing: 6,
        childAspectRatio: 0.85,
      ),
      itemCount: rows * 7,
      itemBuilder: (_, index) {
        final dayNum = index - (_startWeekday - 1) + 1;
        if (dayNum < 1 || dayNum > _daysInMonth) {
          return const SizedBox.shrink();
        }
        return _DayCell(
          day: dayNum,
          attendance: _attendance[_dateKey(dayNum)],
          onTap: () => _tapDay(dayNum),
        );
      },
    );
  }

  Widget _buildSummaryCard() {
    final hasSalary = _worker.dailySalaryCents > 0;
    final grossCents = _workedDays * _worker.dailySalaryCents;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppTheme.primary.withValues(alpha: 0.12),
            AppTheme.surface,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: AppTheme.radiusLarge,
        border: Border.all(
            color: AppTheme.primary.withValues(alpha: 0.25)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              const Icon(Icons.calculate_rounded,
                  color: AppTheme.primary, size: 20),
              const SizedBox(width: 8),
              const Text('Llogaritja e Pagës',
                  style: AppTheme.titleSmall),
            ],
          ),
          const SizedBox(height: 16),
          _SummaryRow(
            label: 'Ditë të punuara',
            value: '$_workedDays ditë',
            color: AppTheme.primary,
          ),
          if (hasSalary) ...[
            const SizedBox(height: 8),
            _SummaryRow(
              label: 'Paga ditore',
              value: moneyFromCents(_worker.dailySalaryCents),
              color: AppTheme.textSecondary,
            ),
            const SizedBox(height: 8),
            _SummaryRow(
              label: 'Bruto',
              value: moneyFromCents(grossCents),
              color: AppTheme.warning,
            ),
          ],
          if (_totalAdvanceCents > 0) ...[
            const SizedBox(height: 8),
            _SummaryRow(
              label: 'Avanse',
              value: '− ${moneyFromCents(_totalAdvanceCents)}',
              color: AppTheme.error,
            ),
          ],
          if (hasSalary) ...[
            const Divider(color: AppTheme.border, height: 24),
            _SummaryRow(
              label: 'Neto të pagueshëm',
              value: moneyFromCents(_totalEarnedCents),
              color: _totalEarnedCents >= 0
                  ? AppTheme.success
                  : AppTheme.error,
              large: true,
            ),
          ] else ...[
            const SizedBox(height: 8),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: AppTheme.warning.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                    color: AppTheme.warning.withValues(alpha: 0.25)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline_rounded,
                      color: AppTheme.warning, size: 16),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'Vendos pagën ditore për të llogaritur totalin.',
                      style: TextStyle(
                          color: AppTheme.warning, fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Day Cell
// ─────────────────────────────────────────────────────────────────────────────

class _DayCell extends StatelessWidget {
  final int day;
  final AttendanceRow? attendance;
  final VoidCallback onTap;

  const _DayCell({
    required this.day,
    required this.attendance,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final worked = attendance?.worked ?? false;
    final advance = attendance?.advanceCents ?? 0;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        decoration: BoxDecoration(
          gradient: worked
              ? LinearGradient(
                  colors: [
                    AppTheme.success.withValues(alpha: 0.22),
                    AppTheme.success.withValues(alpha: 0.08),
                  ],
                )
              : null,
          color: worked ? null : AppTheme.card,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: worked
                ? AppTheme.success.withValues(alpha: 0.40)
                : AppTheme.border,
            width: worked ? 1.2 : 1,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              '$day',
              style: TextStyle(
                color: worked ? AppTheme.primaryLight : AppTheme.textSecondary,
                fontWeight:
                    worked ? FontWeight.w800 : FontWeight.w500,
                fontSize: 13,
              ),
            ),
            if (worked)
              const Icon(Icons.check_rounded,
                  color: AppTheme.success, size: 13),
            if (advance > 0)
              Text(
                '${(advance / 100).toStringAsFixed(0)}€',
                style: const TextStyle(
                    color: AppTheme.warning,
                    fontSize: 9,
                    fontWeight: FontWeight.w700),
              ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Day Dialog
// ─────────────────────────────────────────────────────────────────────────────

class _DayDialog extends StatefulWidget {
  final int day;
  final DateTime month;
  final String workerName;
  final bool initialWorked;
  final int initialAdvanceCents;

  const _DayDialog({
    required this.day,
    required this.month,
    required this.workerName,
    required this.initialWorked,
    required this.initialAdvanceCents,
  });

  @override
  State<_DayDialog> createState() => _DayDialogState();
}

class _DayDialogState extends State<_DayDialog> {
  late bool _worked;
  late TextEditingController _advanceCtrl;

  @override
  void initState() {
    super.initState();
    _worked = widget.initialWorked;
    _advanceCtrl = TextEditingController(
      text: widget.initialAdvanceCents == 0
          ? ''
          : (widget.initialAdvanceCents / 100).toStringAsFixed(0),
    );
  }

  @override
  void dispose() {
    _advanceCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const months = [
      'Janar', 'Shkurt', 'Mars', 'Prill', 'Maj', 'Qershor',
      'Korrik', 'Gusht', 'Shtator', 'Tetor', 'Nëntor', 'Dhjetor',
    ];
    final dateStr =
        '${widget.day} ${months[widget.month.month - 1]} ${widget.month.year}';

    return AlertDialog(
      backgroundColor: AppTheme.surface,
      shape: RoundedRectangleBorder(borderRadius: AppTheme.radiusLarge),
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(dateStr, style: AppTheme.titleSmall),
          Text(widget.workerName,
              style: AppTheme.caption),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Worked toggle
          GestureDetector(
            onTap: () => setState(() => _worked = !_worked),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              padding: const EdgeInsets.symmetric(
                  horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: _worked
                    ? AppTheme.success.withValues(alpha: 0.12)
                    : AppTheme.card,
                borderRadius: AppTheme.radiusSmall,
                border: Border.all(
                  color: _worked
                      ? AppTheme.success.withValues(alpha: 0.40)
                      : AppTheme.border,
                  width: _worked ? 1.2 : 1,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    _worked
                        ? Icons.check_circle_rounded
                        : Icons.radio_button_unchecked_rounded,
                    color: _worked
                        ? AppTheme.success
                        : AppTheme.textMuted,
                    size: 22,
                  ),
                  const SizedBox(width: 12),
                  Text(
                    _worked ? 'Ditë e punuar ✓' : 'Ditë jo punuar',
                    style: TextStyle(
                      color: _worked
                          ? AppTheme.primaryLight
                          : AppTheme.textSecondary,
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          // Advance input
          TextField(
            controller: _advanceCtrl,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: const InputDecoration(
              labelText: 'Avans (€)',
              prefixIcon: Icon(Icons.money_rounded, size: 18),
              hintText: '0',
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Anulo'),
        ),
        ElevatedButton(
          onPressed: () {
            final advEur = int.tryParse(_advanceCtrl.text) ?? 0;
            Navigator.pop(
              context,
              (worked: _worked, advanceCents: advEur * 100),
            );
          },
          child: const Text('Ruaj'),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Helpers
// ─────────────────────────────────────────────────────────────────────────────

class _SummaryRow extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final bool large;

  const _SummaryRow({
    required this.label,
    required this.value,
    required this.color,
    this.large = false,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: large
                ? AppTheme.bodyMedium.copyWith(fontWeight: FontWeight.w700)
                : AppTheme.bodySmall,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            color: color,
            fontWeight: large ? FontWeight.w900 : FontWeight.w700,
            fontSize: large ? 18 : 14,
          ),
        ),
      ],
    );
  }
}

class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String message;
  const _EmptyState({required this.icon, required this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 56, color: AppTheme.textMuted),
          const SizedBox(height: 12),
          Text(message,
              style: AppTheme.bodyMedium.copyWith(
                  color: AppTheme.textSecondary)),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Worker Salary Statistics Panel (public – reused in AdminDashboard)
// ─────────────────────────────────────────────────────────────────────────────

class WorkerSalaryStatsPanel extends StatelessWidget {
  final List<AppUserRow> workers;
  final Map<int, ({int workedDays, int advanceCents})> stats;
  final bool loading;

  const WorkerSalaryStatsPanel({
    super.key,
    required this.workers,
    required this.stats,
    this.loading = false,
  });

  @override
  Widget build(BuildContext context) {
    if (workers.isEmpty && !loading) return const SizedBox.shrink();

    // Totals across all workers
    int totalEarnedCents = 0;
    int totalRemainingCents = 0;
    for (final w in workers) {
      final s = stats[w.id];
      final earned = (s?.workedDays ?? 0) * w.dailySalaryCents;
      final remaining = earned - (s?.advanceCents ?? 0);
      totalEarnedCents += earned;
      totalRemainingCents += remaining;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppTheme.primary.withValues(alpha: 0.10),
            AppTheme.surface,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: AppTheme.radiusLarge,
        border: Border.all(color: AppTheme.primary.withValues(alpha: 0.22)),
        boxShadow: AppTheme.shadowGlowColor(AppTheme.primary, a: 0.06),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header ──────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 14),
            child: Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    gradient: AppTheme.primaryGrad,
                    borderRadius: BorderRadius.circular(11),
                    boxShadow:
                        AppTheme.shadowGlowColor(AppTheme.primary, a: 0.30),
                  ),
                  child: const Icon(Icons.bar_chart_rounded,
                      color: Colors.white, size: 18),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Statistikat e Pagave',
                          style: AppTheme.titleSmall),
                      Text(
                        '${workers.length} punonjës • të gjitha kohët',
                        style: AppTheme.caption,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          if (loading)
            const Padding(
              padding: EdgeInsets.only(bottom: 14),
              child: LinearProgressIndicator(
                  color: AppTheme.primary, minHeight: 2),
            )
          else ...[
            const Divider(color: AppTheme.border, height: 1),

            // ── Per-worker rows ────────────────────────────────────────────
            ...workers.map((w) {
              final s = stats[w.id];
              final workedDays = s?.workedDays ?? 0;
              final advanceCents = s?.advanceCents ?? 0;
              final earnedCents = workedDays * w.dailySalaryCents;
              final remainingCents = earnedCents - advanceCents;
              return _WorkerStatRow(
                worker: w,
                workedDays: workedDays,
                advanceCents: advanceCents,
                earnedCents: earnedCents,
                remainingCents: remainingCents,
              );
            }),

            // ── Footer totals ──────────────────────────────────────────────
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
              decoration: BoxDecoration(
                color: AppTheme.cardAlt,
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(20),
                  bottomRight: Radius.circular(20),
                ),
                border: const Border(top: BorderSide(color: AppTheme.border)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: _TotalChip(
                      label: 'Total bruto',
                      value: moneyFromCents(totalEarnedCents),
                      color: AppTheme.warning,
                      icon: Icons.euro_rounded,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _TotalChip(
                      label: 'Total neto',
                      value: moneyFromCents(totalRemainingCents),
                      color: totalRemainingCents >= 0
                          ? AppTheme.success
                          : AppTheme.error,
                      icon: Icons.account_balance_wallet_rounded,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ── Per-worker stat row ───────────────────────────────────────────────────────

class _WorkerStatRow extends StatelessWidget {
  final AppUserRow worker;
  final int workedDays;
  final int advanceCents;
  final int earnedCents;
  final int remainingCents;

  const _WorkerStatRow({
    required this.worker,
    required this.workedDays,
    required this.advanceCents,
    required this.earnedCents,
    required this.remainingCents,
  });

  @override
  Widget build(BuildContext context) {
    final name = worker.fullName?.trim().isNotEmpty == true
        ? worker.fullName!
        : worker.username;
    final letter = name[0].toUpperCase();
    final isManager = worker.role == UserRole.manager;
    final hasSalary = worker.dailySalaryCents > 0;
    final remainColor =
        remainingCents >= 0 ? AppTheme.success : AppTheme.error;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppTheme.border)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Name + remaining badge
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  gradient: AppTheme.primaryGrad,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Center(
                  child: Text(letter,
                      style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: 15)),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name,
                        style: AppTheme.bodyMedium
                            .copyWith(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        StatusBadge(
                          label: isManager ? 'Manager' : 'Kamerier',
                          color: isManager ? AppTheme.info : AppTheme.primary,
                        ),
                        if (hasSalary) ...[
                          const SizedBox(width: 6),
                          Text(
                            '${(worker.dailySalaryCents / 100).toStringAsFixed(0)} €/ditë',
                            style: AppTheme.caption
                                .copyWith(color: AppTheme.warning),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              // Remaining salary chip
              if (hasSalary)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
                  decoration: BoxDecoration(
                    color: remainColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                        color: remainColor.withValues(alpha: 0.32)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        moneyFromCents(remainingCents),
                        style: TextStyle(
                          color: remainColor,
                          fontWeight: FontWeight.w900,
                          fontSize: 14,
                        ),
                      ),
                      Text('neto',
                          style: TextStyle(
                              color: remainColor.withValues(alpha: 0.70),
                              fontSize: 10,
                              fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),

          // Stat chips row
          Wrap(
            spacing: 7,
            runSpacing: 6,
            children: [
              _StatChip(
                label: 'Ditë punuar',
                value: '$workedDays',
                icon: Icons.calendar_today_rounded,
                color: AppTheme.primary,
              ),
              if (hasSalary)
                _StatChip(
                  label: 'Total fituar',
                  value: moneyFromCents(earnedCents),
                  icon: Icons.euro_rounded,
                  color: AppTheme.warning,
                ),
              if (advanceCents > 0)
                _StatChip(
                  label: 'Avanse',
                  value: '−${moneyFromCents(advanceCents)}',
                  icon: Icons.money_off_rounded,
                  color: AppTheme.error,
                ),
              if (!hasSalary)
                _StatChip(
                  label: 'Paga',
                  value: 'Pa vendosur',
                  icon: Icons.warning_amber_rounded,
                  color: AppTheme.textMuted,
                ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Stat chip ─────────────────────────────────────────────────────────────────

class _StatChip extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _StatChip({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.20)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 12),
          const SizedBox(width: 5),
          Text(label,
              style: TextStyle(
                  color: AppTheme.textMuted,
                  fontSize: 10,
                  fontWeight: FontWeight.w500)),
          const SizedBox(width: 5),
          Text(value,
              style: TextStyle(
                  color: color, fontWeight: FontWeight.w800, fontSize: 12)),
        ],
      ),
    );
  }
}

// ── Total chip (footer) ───────────────────────────────────────────────────────

class _TotalChip extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final IconData icon;

  const _TotalChip({
    required this.label,
    required this.value,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.26)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: TextStyle(
                        color: color.withValues(alpha: 0.80),
                        fontSize: 10,
                        fontWeight: FontWeight.w600)),
                Text(value,
                    style: TextStyle(
                        color: color,
                        fontWeight: FontWeight.w900,
                        fontSize: 15)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
