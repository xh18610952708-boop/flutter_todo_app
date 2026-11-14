import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// 本地通知：在 App 打开时，把「今天到期 / 已逾期」的待办汇总成一条提醒。
/// 所有调用都包了 try/catch，即使插件或权限不可用也绝不让 App 崩溃。
class NotifyService {
  NotifyService._();
  static final NotifyService instance = NotifyService._();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  bool _ready = false;

  /// 初始化插件（Android 用小图标 app_icon，纯矢量 drawable，无需二进制资源）。
  Future<void> init() async {
    if (_ready) return;
    try {
      const android = AndroidInitializationSettings('app_icon');
      const ios = DarwinInitializationSettings();
      await _plugin.initialize(
        const InitializationSettings(android: android, iOS: ios),
        onDidReceiveNotificationResponse: (_) {},
      );
      _ready = true;
    } catch (_) {
      _ready = false;
    }
  }

  /// Android 13+ 需要用户授权才能弹通知；这里只尝试请求，失败也无所谓。
  Future<void> requestPermissionIfNeeded() async {
    try {
      final androidImpl = _plugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();
      await androidImpl?.requestNotificationsPermission();
    } catch (_) {
      // 忽略
    }
  }

  /// 发一条「待办到期提醒」汇总通知。overdue/duetoday 为数量。
  Future<void> showDueSummary({
    required int overdue,
    required int dueToday,
  }) async {
    if (!_ready) return;
    if (overdue == 0 && dueToday == 0) return;
    try {
      final buffer = StringBuffer();
      if (overdue > 0) buffer.write('$overdue 项已逾期');
      if (dueToday > 0) {
        if (buffer.isNotEmpty) buffer.write('，');
        buffer.write('$dueToday 项今天到期');
      }
      const details = NotificationDetails(
        android: AndroidNotificationDetails(
          'todo_due_channel',
          '待办到期提醒',
          channelDescription: '待办临近截止或已逾期时的本地提醒',
          importance: Importance.defaultImportance,
          priority: Priority.defaultPriority,
        ),
        iOS: DarwinNotificationDetails(),
      );
      await _plugin.show(
        1001,
        '待办提醒',
        '$buffer，记得及时处理～',
        details,
      );
    } catch (_) {
      // 发通知失败不影响使用
    }
  }
}
