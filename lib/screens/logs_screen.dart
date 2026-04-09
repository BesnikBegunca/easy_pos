import 'package:flutter/material.dart';
import '../data/dao_logs.dart';
import '../auth/session.dart';
import '../theme/app_theme.dart';

class LogsScreen extends StatefulWidget {
  const LogsScreen({super.key});

  @override
  State<LogsScreen> createState() => _LogsScreenState();
}

class _LogsScreenState extends State<LogsScreen> {
  List<AuditLogRow> _logs = [];
  bool _loading = true;
  final TextEditingController _searchC = TextEditingController();
  String _actionFilter = '';

  @override
  void initState() {
    super.initState();
    _loadLogs();
  }

  Future<void> _loadLogs() async {
    setState(() => _loading = true);
    try {
      final logs = await LogsDao.I.listLogs(
        actionFilter: _actionFilter.isEmpty ? null : _actionFilter,
      );
      if (mounted) setState(() => _logs = logs);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bg,
      appBar: AppBar(
        title: const Text('Audit Logs'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loadLogs),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchC,
                    decoration: InputDecoration(
                      hintText: 'Search actions...',
                      prefixIcon: const Icon(Icons.search),
                      border: OutlineInputBorder(
                        borderRadius: AppTheme.radiusSmall,
                      ),
                    ),
                    onChanged: (v) {
                      _actionFilter = v;
                      _loadLogs();
                    },
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _logs.isEmpty
                ? const Center(child: Text('No logs found'))
                : ListView.builder(
                    itemCount: _logs.length,
                    itemBuilder: (context, i) {
                      final log = _logs[i];
                      return Card(
                        margin: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 4,
                        ),
                        child: ListTile(
                          title: Text(log.action),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('By user ${log.userId}'),
                              Text(
                                DateTime.fromMillisecondsSinceEpoch(
                                  log.timestamp,
                                ).toString(),
                              ),
                              if (log.before.isNotEmpty)
                                Text('Before: ${log.before}'),
                              if (log.after.isNotEmpty)
                                Text('After: ${log.after}'),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
