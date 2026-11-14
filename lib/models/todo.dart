/// 一条待办。
/// owner 记录「这条属于哪个账号」，所以 A 账号登录看不到 B 账号的清单。
class Todo {
  // ---- 表名与列名常量：写 SQL 时统一引用，避免手滑拼错 ----
  static const String table = 'todos';
  static const String colId = 'id';
  static const String colOwner = 'owner';
  static const String colTitle = 'title';
  static const String colNote = 'note';
  static const String colDone = 'done';
  static const String colPriority = 'priority';
  static const String colCreatedAt = 'created_at';
  static const String colDueAt = 'due_at';
  static const String colDoneAt = 'done_at';
  static const String colCategory = 'category';

  /// 优先级：0 普通 / 1 重要 / 2 紧急
  static const List<String> priorityLabels = <String>['普通', '重要', '紧急'];

  final int? id;
  final String owner;
  final String title;
  final String note;
  final bool done;
  final int priority;
  final DateTime createdAt;
  final DateTime? dueAt;
  final DateTime? doneAt;
  final String category;

  const Todo({
    this.id,
    required this.owner,
    required this.title,
    this.note = '',
    this.done = false,
    this.priority = 0,
    required this.createdAt,
    this.dueAt,
    this.doneAt,
    this.category = '',
  });

  String get priorityLabel =>
      priority >= 0 && priority < priorityLabels.length
          ? priorityLabels[priority]
          : priorityLabels[0];

  /// 编辑时基于旧对象生成新对象（id / owner / createdAt 永远不变）。
  /// clearDueAt、clearDoneAt 用来把「可空时间」重新清空成 null。
  Todo copyWith({
    int? id,
    String? title,
    String? note,
    bool? done,
    int? priority,
    DateTime? dueAt,
    DateTime? doneAt,
    String? category,
    bool clearDueAt = false,
    bool clearDoneAt = false,
  }) =>
      Todo(
        id: id ?? this.id,
        owner: owner,
        title: title ?? this.title,
        note: note ?? this.note,
        done: done ?? this.done,
        priority: priority ?? this.priority,
        createdAt: createdAt,
        dueAt: clearDueAt ? null : (dueAt ?? this.dueAt),
        doneAt: clearDoneAt ? null : (doneAt ?? this.doneAt),
        category: category ?? this.category,
      );

  /// 转成 SQLite 的一行。布尔值存 0/1，时间存 ISO 字符串。
  Map<String, Object?> toMap() => <String, Object?>{
        colId: id,
        colOwner: owner,
        colTitle: title,
        colNote: note,
        colDone: done ? 1 : 0,
        colPriority: priority,
        colCreatedAt: createdAt.toIso8601String(),
        colDueAt: dueAt?.toIso8601String(),
        colDoneAt: doneAt?.toIso8601String(),
        colCategory: category,
      };

  factory Todo.fromMap(Map<String, Object?> map) => Todo(
        id: map[colId] as int?,
        owner: map[colOwner] as String? ?? '',
        title: map[colTitle] as String? ?? '',
        note: map[colNote] as String? ?? '',
        done: (map[colDone] as int? ?? 0) == 1,
        priority: map[colPriority] as int? ?? 0,
        createdAt:
            DateTime.tryParse(map[colCreatedAt] as String? ?? '') ??
                DateTime.now(),
        dueAt: _parseDate(map[colDueAt] as String?),
        doneAt: _parseDate(map[colDoneAt] as String?),
        category: map[colCategory] as String? ?? '',
      );

  static DateTime? _parseDate(String? raw) =>
      raw == null || raw.isEmpty ? null : DateTime.tryParse(raw);

  @override
  String toString() => 'Todo(#$id, $title, done=$done, owner=$owner)';
}

/// 是否逾期：未完成且截止日期早于「今天 00:00」。
/// 抽成纯函数（不依赖 DateTime.now()），方便单元测试与复用。
bool isOverdue(Todo todo, DateTime now) {
  if (todo.done || todo.dueAt == null) return false;
  final due = DateTime(todo.dueAt!.year, todo.dueAt!.month, todo.dueAt!.day);
  final today = DateTime(now.year, now.month, now.day);
  return due.isBefore(today);
}

/// 是否临近：未完成、未逾期、且距今 24 小时内。
bool isDueSoon(Todo todo, DateTime now) {
  if (todo.done || todo.dueAt == null || isOverdue(todo, now)) return false;
  final diff = todo.dueAt!.difference(now).inHours;
  return diff >= 0 && diff < 24;
}

/// 不引入 intl 包，自己格式化日期，减少一个依赖。
String fmtDate(DateTime? d) {
  if (d == null) return '';
  String two(int n) => n.toString().padLeft(2, '0');
  return '${d.year}-${two(d.month)}-${two(d.day)}';
}

String fmtDateTime(DateTime? d) {
  if (d == null) return '';
  String two(int n) => n.toString().padLeft(2, '0');
  return '${fmtDate(d)} ${two(d.hour)}:${two(d.minute)}';
}
