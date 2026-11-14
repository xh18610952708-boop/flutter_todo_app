import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app.dart';
import 'services/db_helper.dart';
import 'services/notify_service.dart';
import 'services/settings_service.dart';

Future<void> main() async {
  // 用了数据库 / shared_preferences 这类原生能力，必须先绑定引擎
  WidgetsFlutterBinding.ensureInitialized();

  // 待办清单是单手使用场景，锁竖屏
  await SystemChrome.setPreferredOrientations(<DeviceOrientation>[
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // 主题偏好 + 通知插件提前初始化（失败也不影响启动）
  await AppSettings.instance.init();
  await NotifyService.instance.init();

  // 提前把数据库打开，进首页时不会卡一下；失败也不影响启动
  try {
    await DbHelper.instance.database;
  } catch (_) {
    // 忽略，交由页面层处理
  }

  runApp(const TodoApp());
}
