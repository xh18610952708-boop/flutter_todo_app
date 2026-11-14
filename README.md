# Flutter 待办事项 App

一个面向个人的本地优先（local-first）待办事项应用，使用 Flutter 构建，支持 Android / iOS / 桌面端。

## 功能特性

- **本地多账号**：注册 / 登录 / 退出；密码加盐哈希存储，绝不落明文。
- **待办增删改查**：标题、备注、分类、优先级、到期时间、完成状态。
- **检索与组织**：关键词搜索、按到期 / 优先级 / 创建时间排序、按分类筛选。
- **深色模式**：跟随系统 / 浅色 / 深色三态，设置持久化。
- **到期智能提醒**：逾期标红、临期高亮、概览卡片、本地通知。
- **数据备份与恢复**：导出 / 导入 JSON。
- **可测试**：核心业务逻辑抽成纯函数，便于单元测试。

## 技术栈

- Flutter 3.50.0 / Dart
- SQLite（`sqflite`）本地存储
- `shared_preferences` 持久化设置
- `flutter_local_notifications` 本地通知

## 快速开始

```bash
flutter pub get
flutter run
```

Windows 上可直接双击 `setup.bat`（首次环境自检 + 取依赖）或 `run_app.bat`（直接运行）。

## 构建 APK

双击 `build_apk.bat`（脚本已内置 JDK / Android SDK / 国内镜像环境变量），产物位于：

```
build/app/outputs/flutter-apk/app-release.apk
```

## 测试

纯逻辑测试可用 `dart test` 直接运行（无需 C++ 工具链）：

```bash
dart test test/todo_test.dart test/user_test.dart
```

完整测试（含依赖 Flutter 引擎的 `auth_service_test`）使用：

```bash
flutter test
```

## CI

每次 push / PR 到 `main` 自动运行静态分析（`flutter analyze`）与单元测试（`flutter test`），运行于 `ubuntu-latest`，规避 Windows C++ 工具链限制。

![Flutter CI](https://github.com/xh18610952708-boop/flutter_todo_app/actions/workflows/flutter-ci.yml/badge.svg)

详细打包 / 测试说明见 [PACKAGING_AND_TEST_GUIDE.md](./PACKAGING_AND_TEST_GUIDE.md)。
