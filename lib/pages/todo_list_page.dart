import 'package:flutter/material.dart';

import '../models/todo.dart';
import '../services/auth_service.dart';
import '../services/backup_service.dart';
import '../services/notify_service.dart';
import '../services/settings_service.dart';
import '../services/todo_repository.dart';
import '../widgets/todo_item.dart';
import 'todo_edit_page.dart';

/// 首页：待办列表。所有读写都带上当前账号名，天然隔离。
class TodoListPage extends StatefulWidget {
  final String username;
  final VoidCallback onLoggedOut;

  const TodoListPage({
    super.key,
    required this.username,
    required this.onLoggedOut,
  });

  @override
  State<TodoListPage> createState() => _TodoListPageState();
}

class _TodoListPageState extends State<TodoListPage> {
  TodoFilter _filter = TodoFilter.all;
  TodoSort _sort = TodoSort.smart;
  final TextEditingController _keywordCtrl = TextEditingController();
  String? _category;
  List<Todo> _items = <Todo>[];
  List<String> _categories = <String>[];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
    _notifyDueOnce();
    // 注册「点击通知打开对应待办」回调；dispose 时清掉，避免持有过期 context
    NotifyService.instance.onTapOpenTodo = _openTodoFromNotification;
  }

  @override
  void dispose() {
    // 单订阅模式：本页是唯一注册者，离开时无条件清掉，避免持有过期 context
    NotifyService.instance.onTapOpenTodo = null;
    _keywordCtrl.dispose();
    super.dispose();
  }

  /// 通知点击后：按 id 取出该待办并打开编辑页（定位到具体项）。
  Future<void> _openTodoFromNotification(int? id) async {
    if (id == null) return;
    try {
      final todo = await TodoRepository.instance.getById(id, widget.username);
      if (todo == null || !mounted) return;
      await _openEditor(todo);
    } catch (_) {
      // 取不到就忽略，不影响主流程
    }
  }

  Future<void> _load() async {
    try {
      final list = await TodoRepository.instance.list(
        widget.username,
        filter: _filter,
        sort: _sort,
        keyword: _keywordCtrl.text,
        category: _category,
      );
      final cats = await TodoRepository.instance.categories(widget.username);
      if (!mounted) return;
      setState(() {
        _items = list;
        _categories = cats;
        _loading = false;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = '读取本地数据失败：$e';
      });
    }
  }

  /// 进入列表后检查一次到期情况，必要时发本地通知提醒。
  Future<void> _notifyDueOnce() async {
    try {
      await NotifyService.instance.requestPermissionIfNeeded();
      final active = await TodoRepository.instance.list(
        widget.username,
        filter: TodoFilter.active,
      );
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      int overdue = 0;
      int dueToday = 0;
      Todo? focus;
      for (final t in active) {
        if (t.dueAt == null) continue;
        final due = DateTime(t.dueAt!.year, t.dueAt!.month, t.dueAt!.day);
        if (due.isBefore(today)) {
          overdue++;
          if (focus == null ||
              due.isBefore(
                  DateTime(focus.dueAt!.year, focus.dueAt!.month, focus.dueAt!.day))) {
            focus = t;
          }
        } else if (due.isAtSameMomentAs(today)) {
          dueToday++;
          focus ??= t;
        }
      }
      await NotifyService.instance.showDueSummary(
        overdue: overdue,
        dueToday: dueToday,
        focusTodoId: focus?.id,
      );
    } catch (_) {
      // 通知失败不影响主流程
    }
  }

  void _toast(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _openEditor([Todo? todo]) async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => TodoEditPage(owner: widget.username, todo: todo),
      ),
    );
    if (changed == true) await _load();
  }

  Future<void> _toggle(Todo todo, bool value) async {
    await TodoRepository.instance.setDone(todo, value);
    await _load();
  }

  Future<void> _delete(Todo todo) async {
    if (todo.id == null) return;
    await TodoRepository.instance.remove(todo.id!, widget.username);
    await _load();
    if (mounted) _toast('已删除「${todo.title}」');
  }

  Future<void> _clearDone() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('清空已完成'),
        content: const Text('只删除当前账号里已完成的待办，未完成的会保留。'),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('确认清空'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await TodoRepository.instance.clearDone(widget.username);
    await _load();
    if (mounted) _toast('已完成的待办已清空');
  }

  Future<void> _logout() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('退出登录'),
        content: const Text('待办和账号都会保留，下次登录还能看到。'),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('退出'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await AuthService.instance.logout();
    widget.onLoggedOut();
  }

  Future<void> _export() async {
    try {
      final path = await BackupService.instance.exportJson(widget.username);
      if (!mounted) return;
      _toast('已导出备份到：\n$path');
      await _load();
    } catch (e) {
      if (!mounted) return;
      _toast('导出失败：$e');
    }
  }

  Future<void> _exportAll() async {
    try {
      final path = await BackupService.instance.exportAllJson();
      if (!mounted) return;
      _toast('已导出全部账号备份到：\n$path');
    } catch (e) {
      if (!mounted) return;
      _toast('导出失败：$e');
    }
  }

  Future<void> _import() async {
    try {
      final count = await BackupService.instance.importJson(widget.username);
      if (!mounted) return;
      if (count == 0) {
        _toast('已取消导入');
        return;
      }
      await _load();
      _toast('已导入 $count 条待办');
    } catch (e) {
      if (!mounted) return;
      _toast('导入失败：$e');
    }
  }

  Future<void> _chooseTheme() async {
    final current = AppSettings.instance.themeMode.value;
    final picked = await showDialog<ThemeMode>(
      context: context,
      builder: (BuildContext ctx) => AlertDialog(
        title: const Text('主题外观'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            RadioListTile<ThemeMode>(
              title: const Text('跟随系统'),
              value: ThemeMode.system,
              groupValue: current,
              onChanged: (v) => Navigator.of(ctx).pop(v),
            ),
            RadioListTile<ThemeMode>(
              title: const Text('浅色'),
              value: ThemeMode.light,
              groupValue: current,
              onChanged: (v) => Navigator.of(ctx).pop(v),
            ),
            RadioListTile<ThemeMode>(
              title: const Text('深色'),
              value: ThemeMode.dark,
              groupValue: current,
              onChanged: (v) => Navigator.of(ctx).pop(v),
            ),
          ],
        ),
      ),
    );
    if (picked != null) await AppSettings.instance.setMode(picked);
  }

  Widget _filterChip(TodoFilter value, String label) => FilterChip(
        label: Text(label),
        selected: _filter == value,
        onSelected: (_) {
          setState(() {
            _filter = value;
            _loading = true;
          });
          _load();
        },
      );

  Widget _categoryChip(String? value, String label) => FilterChip(
        label: Text(label),
        selected: _category == value,
        onSelected: (_) {
          setState(() {
            _category = value;
            _loading = true;
          });
          _load();
        },
      );

  int get _active => _items.where((t) => !t.done).length;
  int get _done => _items.where((t) => t.done).length;
  double get _rate => _items.isEmpty ? 0 : _done / _items.length;

  int get _overdue {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    int n = 0;
    for (final t in _items) {
      if (t.done || t.dueAt == null) continue;
      final due = DateTime(t.dueAt!.year, t.dueAt!.month, t.dueAt!.day);
      if (due.isBefore(today)) n++;
    }
    return n;
  }

  int get _dueToday {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    int n = 0;
    for (final t in _items) {
      if (t.done || t.dueAt == null) continue;
      final due = DateTime(t.dueAt!.year, t.dueAt!.month, t.dueAt!.day);
      if (due.isAtSameMomentAs(today)) n++;
    }
    return n;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('我的待办'),
        actions: <Widget>[
          PopupMenuButton<TodoSort>(
            icon: const Icon(Icons.sort),
            tooltip: '排序',
            onSelected: (TodoSort v) {
              setState(() {
                _sort = v;
                _loading = true;
              });
              _load();
            },
            itemBuilder: (_) => const <PopupMenuEntry<TodoSort>>[
              PopupMenuItem<TodoSort>(
                  value: TodoSort.smart, child: Text('智能排序')),
              PopupMenuItem<TodoSort>(
                  value: TodoSort.due, child: Text('按截止时间')),
              PopupMenuItem<TodoSort>(
                  value: TodoSort.priority, child: Text('按优先级')),
              PopupMenuItem<TodoSort>(
                  value: TodoSort.created, child: Text('按创建时间')),
            ],
          ),
          PopupMenuButton<String>(
            onSelected: (String value) {
              if (value == 'clear') _clearDone();
              if (value == 'export') _export();
              if (value == 'exportAll') _exportAll();
              if (value == 'import') _import();
              if (value == 'theme') _chooseTheme();
              if (value == 'logout') _logout();
            },
            itemBuilder: (_) => const <PopupMenuEntry<String>>[
              PopupMenuItem<String>(value: 'export', child: Text('导出当前账号')),
              PopupMenuItem<String>(
                  value: 'exportAll', child: Text('导出全部账号')),
              PopupMenuItem<String>(value: 'import', child: Text('导入备份')),
              PopupMenuItem<String>(value: 'theme', child: Text('主题外观')),
              PopupMenuItem<String>(value: 'clear', child: Text('清空已完成')),
              PopupMenuItem<String>(value: 'logout', child: Text('退出登录')),
            ],
          ),
        ],
      ),
      body: Column(
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
            child: Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    '当前账号：${widget.username}',
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: TextField(
              controller: _keywordCtrl,
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                hintText: '搜索标题或备注',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _keywordCtrl.text.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _keywordCtrl.clear();
                          _load();
                        },
                      ),
                border: const OutlineInputBorder(),
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 8),
              ),
              onChanged: (_) => _load(),
            ),
          ),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: <Widget>[
                _filterChip(TodoFilter.all, '全部'),
                const SizedBox(width: 8),
                _filterChip(TodoFilter.active, '未完成'),
                const SizedBox(width: 8),
                _filterChip(TodoFilter.done, '已完成'),
                const SizedBox(width: 16),
                _categoryChip(null, '全部分类'),
                for (final c in _categories) ...<Widget>[
                  const SizedBox(width: 8),
                  _categoryChip(c, '#$c'),
                ],
              ],
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: <Widget>[
                        Text('未完成 $_active · 已完成 $_done'),
                        Text('完成率 ${(_rate * 100).toStringAsFixed(0)}%'),
                      ],
                    ),
                    const SizedBox(height: 6),
                    LinearProgressIndicator(value: _rate),
                    const SizedBox(height: 8),
                    Row(
                      children: <Widget>[
                        const Icon(Icons.warning_amber_rounded,
                            size: 16, color: Colors.red),
                        const SizedBox(width: 4),
                        Text('逾期 $_overdue',
                            style: const TextStyle(color: Colors.red)),
                        const SizedBox(width: 16),
                        const Icon(Icons.today,
                            size: 16, color: Colors.orange),
                        const SizedBox(width: 4),
                        Text('今日到期 $_dueToday',
                            style: const TextStyle(color: Colors.orange)),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
          const Divider(height: 8),
          Expanded(child: _buildBody()),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _openEditor(),
        tooltip: '新增待办',
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading && _items.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              const Icon(Icons.error_outline, size: 40, color: Colors.red),
              const SizedBox(height: 12),
              Text(_error!, textAlign: TextAlign.center),
              const SizedBox(height: 12),
              OutlinedButton(onPressed: _load, child: const Text('重试')),
            ],
          ),
        ),
      );
    }
    if (_items.isEmpty) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(Icons.inbox_outlined, size: 56, color: Colors.grey),
            SizedBox(height: 12),
            Text('这里还没有待办', style: TextStyle(color: Colors.grey)),
            SizedBox(height: 4),
            Text('点右下角「+」添加一条',
                style: TextStyle(fontSize: 12, color: Colors.grey)),
          ],
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.only(bottom: 80),
        itemCount: _items.length,
        itemBuilder: (BuildContext context, int index) {
          final todo = _items[index];
          return TodoItem(
            todo: todo,
            onToggle: (bool v) => _toggle(todo, v),
            onTap: () => _openEditor(todo),
            onDelete: () => _delete(todo),
          );
        },
      ),
    );
  }
}
