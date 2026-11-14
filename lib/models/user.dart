import 'dart:convert';

/// 本地账号模型。
/// 只存在这台手机里，不上传服务器；密码永远不明文保存，
/// 只保存「随机盐 salt」和「加盐后算出来的哈希 passwordHash」。
class LocalUser {
  final String username;
  final String salt;
  final String passwordHash;

  const LocalUser({
    required this.username,
    required this.salt,
    required this.passwordHash,
  });

  Map<String, String> toJson() => <String, String>{
        'salt': salt,
        'hash': passwordHash,
      };

  factory LocalUser.fromJson(String username, Map<String, dynamic> json) =>
      LocalUser(
        username: username,
        salt: json['salt'] as String? ?? '',
        passwordHash: json['hash'] as String? ?? '',
      );

  /// 把 shared_preferences 里的一整串 JSON 还原成账号表。
  /// 数据损坏时不抛异常、不让 App 崩溃，按「一个账号都没有」处理。
  static Map<String, LocalUser> decodeAll(String? raw) {
    if (raw == null || raw.isEmpty) return <String, LocalUser>{};
    try {
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      return decoded.map<String, LocalUser>(
        (String key, dynamic value) => MapEntry<String, LocalUser>(
          key,
          LocalUser.fromJson(key, value as Map<String, dynamic>),
        ),
      );
    } catch (_) {
      return <String, LocalUser>{};
    }
  }

  /// 把账号表序列化成一整串 JSON 存回本地。
  static String encodeAll(Map<String, LocalUser> users) => jsonEncode(
        users.map<String, Map<String, String>>(
          (String key, LocalUser value) =>
              MapEntry<String, Map<String, String>>(key, value.toJson()),
        ),
      );
}
