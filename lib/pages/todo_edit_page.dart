import 'package:flutter/material.dart';

import '../models/todo.dart';
import '../services/todo_repository.dart';

/// 新增 / 编辑一条待办。返回 true 表示数据有变化，列表页会刷新。
class TodoEditPage extends StatefulWidget {
  final String owner;
  final Todo? todo; // null = 新增；非 null = 编辑

  const TodoEditPage({super.key, required this.owner, this.todo});

  @override
  State<TodoEditPage> createState() => _TodoEditPageState();
}

class _TodoEditPageState extends State<TodoEditPage> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late final TextEditingController _titleCtrl =
      TextEditingController(text: widget.todo?.title ?? '');
  late final TextEditingController _noteCtrl =
      TextEditingController(text: widget.todo?.note ?? '');
  late final TextEditingController _categoryCtrl =
      TextEditingController(text: widget.todo?.category ?? '');
  late int _priority = widget.todo?.priority ?? 0;
  late DateTime? _dueAt = widget.todo?.dueAt;
  bool _busy = false;

  bool get _isEditing => widget.todo != null;

  @override
  void dispose() {
    _titleCtrl.dispose();
    _noteCtrl.dispose();
    _categoryCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _dueAt ?? now,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 5),
      helpText: '选择截止日期',
    );
    if (picked != null) setState(() => _dueAt = picked);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    setState(() => _busy = true);

    final title = _titleCtrl.text.trim();
    final note = _noteCtrl.text.trim();
    final category = _categoryCtrl.text.trim();
    try {
      if (_isEditing) {
        await TodoRepository.instance.update(
          widget.todo!.copyWith(
            title: title,
            note: note,
            category: category,
            priority: _priority,
            dueAt: _dueAt,
            clearDueAt: _dueAt == null,
          ),
        );
      } else {
        await TodoRepository.instance.add(
          Todo(
            owner: widget.owner,
            title: title,
            note: note,
            category: category,
            priority: _priority,
            createdAt: DateTime.now(),
            dueAt: _dueAt,
          ),
        );
      }
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('保存失败：$e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_isEditing ? '编辑待办' : '新增待办')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                TextFormField(
                  controller: _titleCtrl,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                    labelText: '标题 *',
                    hintText: '例如：交房租、写周报',
                    border: OutlineInputBorder(),
                  ),
                  validator: (String? v) =>
                      (v == null || v.trim().isEmpty) ? '标题不能为空' : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _noteCtrl,
                  maxLines: 4,
                  minLines: 2,
                  decoration: const InputDecoration(
                    labelText: '备注（可不填）',
                    alignLabelWithHint: true,
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _categoryCtrl,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                    labelText: '分类（可不填）',
                    hintText: '如：工作 / 生活 / 学习',
                    prefixIcon: Icon(Icons.sell_outlined),
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<int>(
                  value: _priority,
                  decoration: const InputDecoration(
                    labelText: '优先级',
                    border: OutlineInputBorder(),
                  ),
                  items: <DropdownMenuItem<int>>[
                    for (int i = 0; i < Todo.priorityLabels.length; i++)
                      DropdownMenuItem<int>(
                        value: i,
                        child: Text(Todo.priorityLabels[i]),
                      ),
                  ],
                  onChanged: (int? v) => setState(() => _priority = v ?? 0),
                ),
                const SizedBox(height: 16),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.event_outlined),
                  title: Text(_dueAt == null
                      ? '截止日期：未设置'
                      : '截止日期：${fmtDate(_dueAt)}'),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      if (_dueAt != null)
                        IconButton(
                          tooltip: '清除日期',
                          icon: const Icon(Icons.close),
                          onPressed: () => setState(() => _dueAt = null),
                        ),
                      IconButton(
                        tooltip: '选择日期',
                        icon: const Icon(Icons.calendar_month),
                        onPressed: _pickDate,
                      ),
                    ],
                  ),
                  onTap: _pickDate,
                ),
                const SizedBox(height: 24),
                SizedBox(
                  height: 48,
                  child: FilledButton.icon(
                    onPressed: _busy ? null : _save,
                    icon: const Icon(Icons.save_outlined),
                    label: Text(_isEditing ? '保存修改' : '添加待办'),
                  ),
                ),
                const SizedBox(height: 8),
                OutlinedButton(
                  onPressed: _busy
                      ? null
                      : () => Navigator.of(context).pop(false),
                  child: const Text('取消'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
