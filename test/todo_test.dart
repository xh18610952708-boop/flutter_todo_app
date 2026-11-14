import 'package:test/test.dart';
import 'package:flutter_todo_app/models/todo.dart';

void main() {
  group('Todo 序列化往返', () {
    final full = Todo(
      id: 1,
      owner: 'alice',
      title: '写周报',
      note: '周五前',
      done: false,
      priority: 2,
      createdAt: DateTime(2026, 1, 1, 9, 0),
      dueAt: DateTime(2026, 1, 5, 18, 30),
      doneAt: DateTime(2026, 1, 4, 10, 0),
      category: '工作',
    );

    test('toMap / fromMap 往返字段一致（含分类/截止/完成时间）', () {
      final back = Todo.fromMap(full.toMap());
      expect(back.id, full.id);
      expect(back.owner, full.owner);
      expect(back.title, full.title);
      expect(back.note, full.note);
      expect(back.done, full.done);
      expect(back.priority, full.priority);
      expect(back.createdAt, full.createdAt);
      expect(back.dueAt, full.dueAt);
      expect(back.doneAt, full.doneAt);
      expect(back.category, full.category);
    });

    test('null 的 dueAt / doneAt 往返仍为 null', () {
      final t = Todo(
        owner: 'b',
        title: '无截止日',
        createdAt: DateTime(2026, 1, 1, 8, 0),
      );
      expect(t.dueAt, isNull);
      expect(t.doneAt, isNull);
      final back = Todo.fromMap(t.toMap());
      expect(back.dueAt, isNull);
      expect(back.doneAt, isNull);
    });

    test('done 在 map 中以 0/1 存储', () {
      expect(Todo.fromMap(full.copyWith(done: true).toMap()).done, isTrue);
      expect(Todo.fromMap(full.copyWith(done: false).toMap()).done, isFalse);
    });

    test('缺失/损坏字段有安全默认值（不抛异常）', () {
      final back = Todo.fromMap(<String, Object?>{
        Todo.colOwner: 'x',
        Todo.colTitle: 'y',
        // createdAt 缺失 → 用 now 兜底，不崩
      });
      expect(back.owner, 'x');
      expect(back.title, 'y');
      expect(back.done, isFalse);
      expect(back.priority, 0);
      expect(back.category, '');
    });
  });

  group('Todo.copyWith', () {
    final base = Todo(
      id: 7,
      owner: 'alice',
      title: '原标题',
      createdAt: DateTime(2026, 1, 1),
      dueAt: DateTime(2026, 1, 5),
    );

    test('不改任何参数时保持 id/owner/createdAt 不变', () {
      final c = base.copyWith();
      expect(c.id, base.id);
      expect(c.owner, base.owner);
      expect(c.createdAt, base.createdAt);
    });

    test('可更新普通字段', () {
      final c = base.copyWith(title: '新标题', priority: 1, category: '学习');
      expect(c.title, '新标题');
      expect(c.priority, 1);
      expect(c.category, '学习');
      // 其余保持
      expect(c.id, base.id);
      expect(c.owner, base.owner);
    });

    test('clearDueAt 能清空已有截止日', () {
      final c = base.copyWith(clearDueAt: true);
      expect(c.dueAt, isNull);
    });

    test('clearDoneAt 能清空已有完成时间', () {
      final withDone = base.copyWith(done: true, doneAt: DateTime(2026, 1, 3));
      expect(withDone.doneAt, isNotNull);
      final cleared = withDone.copyWith(clearDoneAt: true);
      expect(cleared.doneAt, isNull);
    });
  });

  group('Todo.priorityLabel', () {
    test('0/1/2 映射到 普通/重要/紧急', () {
      expect(Todo(owner: 'o', title: 't', createdAt: DateTime(2026), priority: 0).priorityLabel, '普通');
      expect(Todo(owner: 'o', title: 't', createdAt: DateTime(2026), priority: 1).priorityLabel, '重要');
      expect(Todo(owner: 'o', title: 't', createdAt: DateTime(2026), priority: 2).priorityLabel, '紧急');
    });
    test('越界优先级回落到 普通', () {
      expect(Todo(owner: 'o', title: 't', createdAt: DateTime(2026), priority: 9).priorityLabel, '普通');
    });
  });

  group('日期格式化', () {
    test('fmtDate 补零且不含时间', () {
      expect(fmtDate(DateTime(2026, 1, 5, 18, 30)), '2026-01-05');
      expect(fmtDate(null), '');
    });
    test('fmtDateTime 含时分', () {
      expect(fmtDateTime(DateTime(2026, 1, 5, 8, 9)), '2026-01-05 08:09');
      expect(fmtDateTime(null), '');
    });
  });

  group('逾期 / 临近 判定（纯函数）', () {
    final now = DateTime(2026, 6, 15, 12, 0); // 固定“现在”

    Todo mk({bool done = false, DateTime? dueAt}) => Todo(
          owner: 'o',
          title: 't',
          createdAt: DateTime(2026),
          done: done,
          dueAt: dueAt,
        );

    test('已完成 → 既不逾期也不临近', () {
      expect(isOverdue(mk(done: true, dueAt: DateTime(2026, 6, 10)), now), isFalse);
      expect(isDueSoon(mk(done: true, dueAt: DateTime(2026, 6, 15, 20)), now), isFalse);
    });

    test('无截止日 → 既不逾期也不临近', () {
      expect(isOverdue(mk(), now), isFalse);
      expect(isDueSoon(mk(), now), isFalse);
    });

    test('截止日早于今天 00:00 → 逾期', () {
      expect(isOverdue(mk(dueAt: DateTime(2026, 6, 14, 23, 59)), now), isTrue);
    });

    test('截止日就是今天 → 不逾期（按天比较）', () {
      expect(isOverdue(mk(dueAt: DateTime(2026, 6, 15, 23, 59)), now), isFalse);
    });

    test('截止日在未来且超过 24h → 不临近', () {
      expect(isDueSoon(mk(dueAt: DateTime(2026, 6, 17, 12)), now), isFalse);
    });

    test('截止日在未来 24h 内 → 临近', () {
      expect(isDueSoon(mk(dueAt: DateTime(2026, 6, 15, 20)), now), isTrue);
      expect(isDueSoon(mk(dueAt: DateTime(2026, 6, 16, 11, 59)), now), isTrue);
    });

    test('已逾期的不算临近', () {
      expect(isDueSoon(mk(dueAt: DateTime(2026, 6, 14, 0)), now), isFalse);
    });
  });
}
