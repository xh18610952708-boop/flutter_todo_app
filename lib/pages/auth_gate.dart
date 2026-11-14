import 'package:flutter/material.dart';

import '../services/auth_service.dart';
import 'login_page.dart';
import 'todo_list_page.dart';

/// 启动闸门：看看上次是不是已经登录过，决定第一屏显示什么。
/// 它一直待在页面树的根部，登录 / 退出只是换掉它的子树，
/// 所以不会出现「页面已经被关掉、回调还去跳转」的崩溃。
class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  String? _user;
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final user = await AuthService.instance.currentUser();
    if (!mounted) return;
    setState(() {
      _user = user;
      _ready = true;
    });
  }

  void _onLoggedIn(String username) => setState(() => _user = username);

  void _onLoggedOut() => setState(() => _user = null);

  @override
  Widget build(BuildContext context) {
    if (!_ready) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    final user = _user;
    if (user == null) {
      return LoginPage(onLoggedIn: _onLoggedIn);
    }
    return TodoListPage(username: user, onLoggedOut: _onLoggedOut);
  }
}
