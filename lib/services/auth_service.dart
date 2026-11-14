import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/user.dart';

/// 本地账号服务：注册 / 登录 / 记住登录状态 / 退出登录。
/// 大白话：这是「本机账号」，不联网、没有服务器；卸载 App 或清除数据后账号就没了。
class AuthService {
  AuthService._();
  static final AuthService instance = AuthService._();

  static const String _kUsers = 'auth.users.v1';
  static const String _kCurrent = 'auth.current_user.v1';

  Future<SharedPreferences> get _prefs => SharedPreferences.getInstance();

  /// 每次注册生成一个 16 字节的随机「盐」，让同样的密码也算不出同样的哈希。
  String _newSalt() {
    final random = Random.secure();
    final bytes = List<int>.generate(16, (_) => random.nextInt(256));
    return bytes.map((int b) => b.toRadixString(16).padLeft(2, '0')).join();
  }

  String _hash(String salt, String password) =>
      sha256.convert(utf8.encode('$salt|$password|flutter_todo')).toString();

  // 账号：2–20 位中英文、数字、下划线
  static final RegExp _namePattern =
      RegExp(r'^[A-Za-z0-9_\u4e00-\u9fa5]{2,20}$');

  Future<Map<String, LocalUser>> _readUsers() async {
    final prefs = await _prefs;
    return LocalUser.decodeAll(prefs.getString(_kUsers));
  }

  /// 成功返回 null；失败返回一句能直接显示给用户的中文提示。
  Future<String?> register(String username, String password) async {
    final name = username.trim();
    if (!_namePattern.hasMatch(name)) {
      return '账号需 2–20 位，只能用中英文、数字或下划线';
    }
    if (password.length < 6) return '密码至少 6 位';

    final users = await _readUsers();
    if (users.containsKey(name)) return '这个账号已注册，请直接登录';

    final salt = _newSalt();
    users[name] = LocalUser(
      username: name,
      salt: salt,
      passwordHash: _hash(salt, password),
    );

    final prefs = await _prefs;
    await prefs.setString(_kUsers, LocalUser.encodeAll(users));
    // 注册完直接算已登录，省得再输一遍
    await prefs.setString(_kCurrent, name);
    return null;
  }

  /// 成功返回 null；失败返回中文提示。
  Future<String?> login(String username, String password) async {
    final name = username.trim();
    final users = await _readUsers();
    final user = users[name];
    if (user == null) return '账号不存在，请先注册';
    if (user.passwordHash != _hash(user.salt, password)) {
      return '密码不正确';
    }
    final prefs = await _prefs;
    await prefs.setString(_kCurrent, name);
    return null;
  }

  /// 上次登录的账号；没登录过返回 null。
  Future<String?> currentUser() async {
    final value = (await _prefs).getString(_kCurrent);
    return (value == null || value.isEmpty) ? null : value;
  }

  /// 退出登录只清「当前是谁」，账号和待办数据都保留。
  Future<void> logout() async {
    await (await _prefs).remove(_kCurrent);
  }
}
