import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';

import '../models/todo.dart';
import 'auth_service.dart';
import 'todo_repository.dart';

/// 备份 / 恢复：把当前账号的待办导出成 JSON 文件，或导入还原。
/// 纯本地操作，不上传任何服务器。
class BackupService {
  BackupService._();
  static final BackupService instance = BackupService._();

  /// 导出当前账号的全部待办为 JSON，存放到应用文档目录，返回文件路径。
  Future<String> exportJson(String owner) async {
    final items = await TodoRepository.instance.list(owner);
    final payload = <String, Object?>{
      'app': 'flutter_todo_app',
      'version': 1,
      'owner': owner,
      'exportedAt': DateTime.now().toIso8601String(),
      'items': items.map((Todo t) => t.toMap()).toList(),
    };
    final dir = await getApplicationDocumentsDirectory();
    final stamp = DateTime.now()
        .toIso8601String()
        .replaceAll(':', '-')
        .replaceAll('.', '_');
    final file = File('${dir.path}/todo_backup_${owner}_$stamp.json');
    await file.writeAsString(jsonEncode(payload), flush: true);
    return file.path;
  }

  /// 一键导出本机全部账号及各自待办，合并成一个 JSON 文件。
  /// 结构：{ app, version, mode:'all_accounts', exportedAt, accounts:[ {owner, items:[...]}, ... ] }
  /// 返回文件路径。即使某个账号没有待办也会照常列出来（items 为空数组）。
  Future<String> exportAllJson() async {
    final usernames = await AuthService.instance.allUsernames();
    final accounts = <Map<String, Object?>>[];
    for (final String u in usernames) {
      final items = await TodoRepository.instance.list(u);
      accounts.add(<String, Object?>{
        'owner': u,
        'items': items.map((Todo t) => t.toMap()).toList(),
      });
    }
    final payload = <String, Object?>{
      'app': 'flutter_todo_app',
      'version': 1,
      'mode': 'all_accounts',
      'exportedAt': DateTime.now().toIso8601String(),
      'accounts': accounts,
    };
    final dir = await getApplicationDocumentsDirectory();
    final stamp = DateTime.now()
        .toIso8601String()
        .replaceAll(':', '-')
        .replaceAll('.', '_');
    final file = File('${dir.path}/todo_backup_ALL_$stamp.json');
    await file.writeAsString(jsonEncode(payload), flush: true);
    return file.path;
  }

  /// 从用户选择的 JSON 文件导入，逐条写回当前账号。
  /// 按 id 幂等：已存在则更新，否则新增。返回导入条数（0 表示用户取消）。
  Future<int> importJson(String owner) async {
    // file_picker 13.x：静态方法 pickFiles，返回 List<PlatformFile>
    final List<PlatformFile> files = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: <String>['json'],
    );
    if (files.isEmpty) return 0;
    final path = files.single.path;
    if (path == null) return 0;

    final content = await File(path).readAsString();
    final decoded = jsonDecode(content) as Map<String, dynamic>;
    final List<dynamic> rawItems =
        (decoded['items'] as List<dynamic>?) ?? <dynamic>[];

    // 先取一次当前账号已有 id 集合，避免循环里反复查库
    final existing = await TodoRepository.instance.list(owner);
    final existingIds =
        existing.map((Todo e) => e.id).whereType<int>().toSet();

    int imported = 0;
    for (final dynamic raw in rawItems) {
      final map = (raw as Map<String, dynamic>).cast<String, Object?>();
      final from = Todo.fromMap(map);
      // 导入到当前账号：强制把 owner 改成当前账号，其余字段照搬原记录。
      final todo = Todo(
        id: from.id,
        owner: owner,
        title: from.title,
        note: from.note,
        done: from.done,
        priority: from.priority,
        createdAt: from.createdAt,
        dueAt: from.dueAt,
        doneAt: from.doneAt,
        category: from.category,
      );
      if (todo.id != null && existingIds.contains(todo.id)) {
        await TodoRepository.instance.update(todo);
      } else {
        final added = await TodoRepository.instance.add(todo);
        if (todo.id != null) existingIds.add(added.id!);
      }
      imported++;
    }
    return imported;
  }
}
