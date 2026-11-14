import 'package:flutter/material.dart';

import '../models/todo.dart';

/// 列表里的一行：勾选完成、点一下编辑、左滑删除。
class TodoItem extends StatelessWidget {
  final Todo todo;
  final ValueChanged<bool> onToggle;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const TodoItem({
    super.key,
    required this.todo,
    required this.onToggle,
    required this.onTap,
    required this.onDelete,
  });

  /// 是否逾期（未完成且截止日期早于今天 00:00）。
  bool get _isOverdue => isOverdue(todo, DateTime.now());

  /// 是否临近（未完成、未逾期、距今 24 小时内）。
  bool get _isDueSoon => isDueSoon(todo, DateTime.now());

  @override
  Widget build(BuildContext context) {
    final note = todo.note.trim();
    final due = fmtDate(todo.dueAt);
    final parts = <String>[
      if (todo.category.isNotEmpty) '#${todo.category}',
      if (note.isNotEmpty) note,
      if (todo.priority > 0) todo.priorityLabel,
      if (due.isNotEmpty) '截止 $due',
      if (todo.done && todo.doneAt != null) '完成于 ${fmtDateTime(todo.doneAt)}',
    ];

    final spans = <InlineSpan>[];
    if (parts.isNotEmpty) {
      spans.add(TextSpan(text: parts.join(' · ')));
    }
    if (_isOverdue) {
      spans.add(TextSpan(
        text: '${parts.isEmpty ? '' : '  ·  '}已逾期',
        style: const TextStyle(color: Colors.red, fontWeight: FontWeight.w600),
      ));
    } else if (_isDueSoon) {
      spans.add(TextSpan(
        text: '${parts.isEmpty ? '' : '  ·  '}即将到期',
        style:
            const TextStyle(color: Colors.orange, fontWeight: FontWeight.w600),
      ));
    }

    Widget deleteBackground() => Container(
          alignment: Alignment.centerRight,
          padding: const EdgeInsets.only(right: 20),
          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          color: Colors.red.shade400,
          child: const Icon(Icons.delete_outline, color: Colors.white),
        );

    return Dismissible(
      key: ValueKey<String>('todo-${todo.id}'),
      direction: DismissDirection.endToStart,
      background: deleteBackground(),
      secondaryBackground: deleteBackground(),
      onDismissed: (_) => onDelete(),
      child: Card(
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        child: ListTile(
          leading: Checkbox(
            value: todo.done,
            onChanged: (bool? v) => onToggle(v ?? false),
          ),
          title: Text(
            todo.title,
            style: TextStyle(
              decoration: todo.done ? TextDecoration.lineThrough : null,
              color: todo.done ? Colors.grey : null,
            ),
          ),
          subtitle: spans.isEmpty
              ? null
              : RichText(
                  text: TextSpan(
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(color: Colors.grey),
                    children: spans,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
          trailing: todo.priority == 2
              ? const Icon(Icons.flag, size: 20, color: Colors.red)
              : const Icon(Icons.chevron_right),
          onTap: onTap,
        ),
      ),
    );
  }
}
