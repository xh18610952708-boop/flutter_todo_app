import 'package:sqflite/sqflite.dart';

import '../models/todo.dart';
import 'db_helper.dart';

/// 列表筛选条件
enum TodoFilter { all, active, done }

/// 排序方式
enum TodoSort { smart, due, priority, created }

/// 待办数据访问层：页面不直接写 SQL，全部走这里。
/// 每个方法都带 owner，保证账号之间的数据互相看不见。
class TodoRepository {
  TodoRepository._();
  static final TodoRepository instance = TodoRepository._();

  Future<Database> get _db => DbHelper.instance.database;

  /// 组装排序子句：未完成始终排在最前。
  String _orderBy(TodoSort sort) {
    switch (sort) {
      case TodoSort.due:
        // 有截止日期的按时间升序，没截止的沉底；同级再按优先级
        return '${Todo.colDone} ASC, (${Todo.colDueAt} IS NULL) ASC, '
            '${Todo.colDueAt} ASC, ${Todo.colPriority} DESC';
      case TodoSort.priority:
        return '${Todo.colDone} ASC, ${Todo.colPriority} DESC, ${Todo.colCreatedAt} DESC';
      case TodoSort.created:
        return '${Todo.colDone} ASC, ${Todo.colCreatedAt} DESC';
      case TodoSort.smart:
        return '${Todo.colDone} ASC, ${Todo.colPriority} DESC, ${Todo.colCreatedAt} DESC';
    }
  }

  Future<List<Todo>> list(
    String owner, {
    TodoFilter filter = TodoFilter.all,
    TodoSort sort = TodoSort.smart,
    String? keyword,
    String? category,
  }) async {
    final Database db = await _db;
    final List<String> conditions = <String>['${Todo.colOwner} = ?'];
    final List<Object?> args = <Object?>[owner];
    if (filter == TodoFilter.active) conditions.add('${Todo.colDone} = 0');
    if (filter == TodoFilter.done) conditions.add('${Todo.colDone} = 1');
    if (category != null && category.isNotEmpty) {
      conditions.add('${Todo.colCategory} = ?');
      args.add(category);
    }
    if (keyword != null && keyword.trim().isNotEmpty) {
      final String kw = '%${keyword.trim()}%';
      conditions.add('(${Todo.colTitle} LIKE ? OR ${Todo.colNote} LIKE ?)');
      args.add(kw);
      args.add(kw);
    }

    final List<Map<String, Object?>> rows = await db.query(
      Todo.table,
      where: conditions.join(' AND '),
      whereArgs: args,
      orderBy: _orderBy(sort),
    );
    return rows.map((Map<String, Object?> row) => Todo.fromMap(row)).toList();
  }

  /// 该账号下用过的所有分类（去重、排除空），用于列表筛选 chips。
  Future<List<String>> categories(String owner) async {
    final Database db = await _db;
    final List<Map<String, Object?>> rows = await db.query(
      Todo.table,
      distinct: true,
      columns: <String>[Todo.colCategory],
      where: '${Todo.colOwner} = ? AND ${Todo.colCategory} <> ?',
      whereArgs: <Object?>[owner, ''],
      orderBy: Todo.colCategory,
    );
    return rows
        .map((Map<String, Object?> r) => (r[Todo.colCategory] as String?) ?? '')
        .where((String c) => c.isNotEmpty)
        .toList();
  }

  Future<Todo> add(Todo todo) async {
    final Database db = await _db;
    final int id = await db.insert(Todo.table, todo.toMap());
    return todo.copyWith(id: id);
  }

  /// 按 id 取单条待办（带 owner 校验，跨账号取不到）。取不到返回 null。
  Future<Todo?> getById(int id, String owner) async {
    final Database db = await _db;
    final List<Map<String, Object?>> rows = await db.query(
      Todo.table,
      where: '${Todo.colId} = ? AND ${Todo.colOwner} = ?',
      whereArgs: <Object?>[id, owner],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return Todo.fromMap(rows.first);
  }

  Future<void> update(Todo todo) async {
    final Database db = await _db;
    await db.update(
      Todo.table,
      todo.toMap(),
      where: '${Todo.colId} = ? AND ${Todo.colOwner} = ?',
      whereArgs: <Object?>[todo.id, todo.owner],
    );
  }

  Future<void> remove(int id, String owner) async {
    final Database db = await _db;
    await db.delete(
      Todo.table,
      where: '${Todo.colId} = ? AND ${Todo.colOwner} = ?',
      whereArgs: <Object?>[id, owner],
    );
  }

  /// 勾选 / 取消勾选：顺手记录完成时间，取消时清掉完成时间。
  Future<void> setDone(Todo todo, bool value) async {
    await update(todo.copyWith(
      done: value,
      doneAt: value ? DateTime.now() : null,
      clearDoneAt: !value,
    ));
  }

  Future<void> clearDone(String owner) async {
    final Database db = await _db;
    await db.delete(
      Todo.table,
      where: '${Todo.colOwner} = ? AND ${Todo.colDone} = 1',
      whereArgs: <Object?>[owner],
    );
  }
}
