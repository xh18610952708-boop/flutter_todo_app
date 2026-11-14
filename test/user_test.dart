import 'package:test/test.dart';
import 'package:flutter_todo_app/models/user.dart';

void main() {
  group('LocalUser.encodeAll / decodeAll', () {
    test('空表往返为 {}', () {
      expect(LocalUser.decodeAll(LocalUser.encodeAll(<String, LocalUser>{})), isEmpty);
    });

    test('单账号往返保留 salt 与 hash', () {
      final users = <String, LocalUser>{
        'alice': const LocalUser(username: 'alice', salt: 'abc123', passwordHash: 'deadbeef'),
      };
      final back = LocalUser.decodeAll(LocalUser.encodeAll(users));
      expect(back.length, 1);
      expect(back['alice']!.salt, 'abc123');
      expect(back['alice']!.passwordHash, 'deadbeef');
      expect(back['alice']!.username, 'alice');
    });

    test('多账号往返互不影响', () {
      final users = <String, LocalUser>{
        'a': const LocalUser(username: 'a', salt: 's1', passwordHash: 'h1'),
        'b': const LocalUser(username: 'b', salt: 's2', passwordHash: 'h2'),
      };
      final back = LocalUser.decodeAll(LocalUser.encodeAll(users));
      expect(back.keys.toSet(), <String>{'a', 'b'});
      expect(back['b']!.salt, 's2');
    });

    test('decodeAll(null) 返回空表', () {
      expect(LocalUser.decodeAll(null), isEmpty);
    });

    test('decodeAll(空字符串) 返回空表', () {
      expect(LocalUser.decodeAll(''), isEmpty);
    });

    test('decodeAll(损坏 JSON) 不抛异常、返回空表', () {
      expect(() => LocalUser.decodeAll('这不是 json {{{'), returnsNormally);
      expect(LocalUser.decodeAll('这不是 json {{{'), isEmpty);
    });
  });
}
