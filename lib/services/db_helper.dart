import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import '../models/todo.dart';

/// SQLite 数据库单例：整个 App 只开一个数据库连接。
/// 数据文件叫 todo_app.db，放在 App 自己的私有目录里，别的 App 读不到。
class DbHelper {
  DbHelper._();
  static final DbHelper instance = DbHelper._();

  static const String _dbName = 'todo_app.db';
  // v2：新增「分类」字段（category），老库会自动 ALTER 升级。
  static const int _dbVersion = 2;

  Database? _db;

  Future<Database> get database async {
    final cached = _db;
    if (cached != null) return cached;
    final opened = await _open();
    _db = opened;
    return opened;
  }

  Future<Database> _open() async {
    final dir = await getDatabasesPath();
    final dbPath = p.join(dir, _dbName);
    return openDatabase(
      dbPath,
      version: _dbVersion,
      onCreate: (Database db, int version) async {
        await _createTables(db);
      },
      onUpgrade: (Database db, int oldVersion, int newVersion) async {
        if (oldVersion < 2) {
          // v1 -> v2：补一个分类列，默认值空字符串
          await db.execute(
            'ALTER TABLE ${Todo.table} ADD COLUMN ${Todo.colCategory} '
            "TEXT NOT NULL DEFAULT ''",
          );
        }
      },
    );
  }

  Future<void> _createTables(Database db) async {
    await db.execute('''
      CREATE TABLE ${Todo.table} (
        ${Todo.colId}       INTEGER PRIMARY KEY AUTOINCREMENT,
        ${Todo.colOwner}    TEXT    NOT NULL,
        ${Todo.colTitle}    TEXT    NOT NULL,
        ${Todo.colNote}     TEXT    NOT NULL DEFAULT '',
        ${Todo.colDone}     INTEGER NOT NULL DEFAULT 0,
        ${Todo.colPriority} INTEGER NOT NULL DEFAULT 0,
        ${Todo.colCreatedAt} TEXT   NOT NULL,
        ${Todo.colDueAt}    TEXT,
        ${Todo.colDoneAt}   TEXT,
        ${Todo.colCategory} TEXT    NOT NULL DEFAULT ''
      )
    ''');
    // 按账号查清单是最高频操作，给 owner 加索引
    await db.execute(
      'CREATE INDEX idx_todos_owner ON ${Todo.table} (${Todo.colOwner})',
    );
  }

  Future<void> close() async {
    final db = _db;
    _db = null;
    await db?.close();
  }
}
