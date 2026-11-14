import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 全局主题设置：浅色 / 深色 / 跟随系统，持久化到本地。
/// 用 ValueNotifier 让 MaterialApp 实时跟随切换，不用重启 App。
class AppSettings {
  AppSettings._();
  static final AppSettings instance = AppSettings._();

  static const String _kTheme = 'settings.theme_mode.v1';

  final ValueNotifier<ThemeMode> themeMode =
      ValueNotifier<ThemeMode>(ThemeMode.system);

  bool _ready = false;

  /// 启动时读一次本地保存的主题偏好。
  Future<void> init() async {
    if (_ready) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final int? v = prefs.getInt(_kTheme);
      if (v != null && v >= 0 && v < ThemeMode.values.length) {
        themeMode.value = ThemeMode.values[v];
      }
    } catch (_) {
      // 读不到就用默认值，不影响启动
    }
    _ready = true;
  }

  /// 切换并保存主题偏好。
  Future<void> setMode(ThemeMode mode) async {
    themeMode.value = mode;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_kTheme, mode.index);
    } catch (_) {
      // 保存失败也不影响本次会话
    }
  }
}
