import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flutter_todo_app/services/auth_service.dart';

// 注意：这个 key 与 AuthService 内部常量保持一致（auth.users.v1）
const String _kUsers = 'auth.users.v1';

void main() {
  setUp(() async {
    // flutter test 环境下 shared_preferences 走内存 mock；每次测试重置，保证隔离
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  group('注册', () {
    test('成功返回 null 并自动登录（记住当前账号）', () async {
      final err = await AuthService.instance.register('alice', 'secret1');
      expect(err, isNull);
      expect(await AuthService.instance.currentUser(), 'alice');
    });

    test('重复注册返回提示且不改变登录态', () async {
      await AuthService.instance.register('alice', 'secret1');
      final err = await AuthService.instance.register('alice', 'other99');
      expect(err, isNotNull);
      expect(err, contains('已注册'));
      // 二次注册失败不应覆盖已登录身份
      expect(await AuthService.instance.currentUser(), 'alice');
    });

    test('密码不足 6 位被拒绝', () async {
      final err = await AuthService.instance.register('bob', '123');
      expect(err, contains('至少 6 位'));
    });

    test('账号名非法（少于 2 位）被拒绝', () async {
      final err = await AuthService.instance.register('a', 'secret1');
      expect(err, contains('2–20'));
    });

    test('账号名含空格被拒绝', () async {
      final err = await AuthService.instance.register('a b', 'secret1');
      expect(err, contains('2–20'));
    });
  });

  group('登录', () {
    setUp(() async {
      await AuthService.instance.register('carol', 'secret1');
    });

    test('正确密码登录成功并设置当前账号', () async {
      final err = await AuthService.instance.login('carol', 'secret1');
      expect(err, isNull);
      expect(await AuthService.instance.currentUser(), 'carol');
    });

    test('密码错误登录失败', () async {
      // setUp 的 register 会自动登录成 carol；先退出，才能验证「失败登录不会让人登录」
      await AuthService.instance.logout();
      final err = await AuthService.instance.login('carol', 'wrong99');
      expect(err, contains('密码不正确'));
      expect(await AuthService.instance.currentUser(), isNull);
    });

    test('登录不存在的账号失败', () async {
      final err = await AuthService.instance.login('nobody', 'secret1');
      expect(err, contains('不存在'));
    });
  });

  group('退出登录', () {
    test('logout 清当前身份但账号仍在、可重新登录', () async {
      await AuthService.instance.register('dave', 'secret1');
      await AuthService.instance.logout();
      expect(await AuthService.instance.currentUser(), isNull);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString(_kUsers), isNotNull); // 账号表仍在

      final err = await AuthService.instance.login('dave', 'secret1');
      expect(err, isNull);
      expect(await AuthService.instance.currentUser(), 'dave');
    });
  });

  group('密码安全', () {
    test('相同密码的不同账号，哈希不同（加盐生效）', () async {
      await AuthService.instance.register('u1', 'samepw1');
      await AuthService.instance.register('u2', 'samepw1');

      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_kUsers)!;
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      expect(decoded['u1']['hash'], isNot(equals(decoded['u2']['hash'])));
      // 且哈希不是明文
      expect(decoded['u1']['hash'], isNot(equals('samepw1')));
    });

    test('存储中不含明文密码', () async {
      await AuthService.instance.register('ez', 'secret1');
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_kUsers)!;
      expect(raw.contains('secret1'), isFalse);
    });
  });
}
