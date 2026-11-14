# 打包与测试指南（Flutter 待办 App）

> 适用项目：`D:/WorkBuddy/flutter_todo_app`
> 适用环境：Windows 开发者电脑 + 安卓手机（iOS 需额外 Mac）
> 本文覆盖：单元测试怎么跑、APK 怎么重新出包与签名、iOS 怎么出包、账号数据安全提醒。

---

## 一、项目概况

一款**带本地账号登录 + 本地存储**的待办清单 App（Flutter 跨端，一套代码打包 Android / iOS）。已实现的 4 个增强：

1. 搜索 + 排序 + 分类筛选（列表顶部搜索框、多种排序、分类 chips）
2. 数据备份 / 恢复（导出 / 导入 JSON，按账号隔离）
3. 深色模式 + 完成率进度条（浅 / 深 / 跟随系统）
4. 到期智能提醒（逾期标红、临期标橙、首页到期概览、可选本地通知）

源码共 16 个 dart 文件；`flutter analyze` 0 错误；`flutter build apk --release` 已验证成功。

---

## 二、测试现状

| 测试文件 | 内容 | 是否依赖 Flutter 引擎 | 纯 `dart test` 可跑 | `flutter test` 可跑 |
|---|---|---|---|---|
| `test/todo_test.dart` | Todo 模型：序列化往返 / copyWith / 优先级 / 日期格式化 / 逾期·临期判定 | 否 | ✅ 已验证 25/25 全过 | ✅ |
| `test/user_test.dart` | LocalUser 序列化 / 损坏 JSON 兜底 | 否 | ✅（含在上面的 25 个里） | ✅ |
| `test/auth_service_test.dart` | 注册 / 登录 / 退出 / 加盐哈希 / 无明文密码 | 是（`shared_preferences`） | ❌ | ✅ |

> 说明：`auth_service_test` 依赖 `shared_preferences → flutter` 引擎，`flutter test` 在 Windows 上需要先编译一个桌面测试运行器（需 MSVC + Windows SDK + CMake）。纯逻辑的两个文件已用 `dart test` 在无 C++ 工具链下验证通过。

---

## 三、在开发者电脑上跑全量测试（3 个文件全绿）

### 方案 A：只跑纯逻辑（最快，无需装 VS）
```bash
cd D:/WorkBuddy/flutter_todo_app
dart test test/todo_test.dart test/user_test.dart
```
预期：`All tests passed!`（25 个）。

### 方案 B：跑全部（含登录/注册测试）
1. 安装 **Visual Studio 2022 Community**，勾选 **「使用 C++ 的桌面开发」** 工作负载（需联网正常安装，确保 MSVC + Windows SDK + CMake 都装上）。
2. 终端执行：
```bash
cd D:/WorkBuddy/flutter_todo_app
flutter pub get
flutter test
```
预期：3 个文件全部通过。

---

## 四、Android APK

### 1. 重新出包（零命令）
双击项目根目录的 **`build_apk.bat`**（已内置 JAVA_HOME / ANDROID_HOME / 镜像设置）。
产物：`build\app\outputs\flutter-apk\app-release.apk`（约 51MB）。

### 2. 当前包状态
已产出的是「未签名 release」包，可**直接侧载安装**到安卓手机，但**不能上应用商店**。

### 3. 正式签名（可选，用于上架或长期分发）
只需做一次：

**第 1 步：生成签名密钥**（在项目根目录执行）
```bash
keytool -genkey -v -keystore upload-keystore.jks -keyalg RSA -keysize 2048 -validity 10000 -alias upload
```
按提示设置密码、姓名等信息，会生成 `upload-keystore.jks`。

**第 2 步：新建 `android/key.properties`**，填入：
```
storePassword=你设的密码
keyPassword=你设的密码
keyAlias=upload
storeFile=../upload-keystore.jks
```

**第 3 步：在 `android/app/build.gradle.kts` 启用签名**，加入：
```kotlin
import java.util.Properties

val keystoreProps = Properties().apply {
    val f = rootProject.file("key.properties")
    if (f.exists()) load(f.inputStream())
}
android {
    signingConfigs {
        create("release") {
            keyAlias = keystoreProps["keyAlias"] as String
            keyPassword = keystoreProps["keyPassword"] as String
            storeFile = file(keystoreProps["storeFile"] as String)
            storePassword = keystoreProps["storePassword"] as String
        }
    }
    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("release")
            isMinifyEnabled = false
            isShrinkResources = false
        }
    }
}
```

**第 4 步：重新构建**
```bash
flutter build apk --release
```
产物即为**已签名**的 `app-release.apk`。

### 4. 真机安装测试
- 手机「设置 → 关于手机 → 连续点版本号」开启开发者模式 → 打开「USB 调试」。
- 数据线连电脑，`flutter install` 或直接把 apk 拷到手机点开安装。
- 也可直接用文件管理器打开 `app-release.apk` 安装（需允许「未知来源」）。

---

## 五、iOS IPA（需 Mac）

1. Mac 上安装 **Xcode** 与 **CocoaPods**：
   ```bash
   sudo gem install cocoapods
   ```
2. 进入项目：
   ```bash
   cd D:/WorkBuddy/flutter_todo_app   # 或用 Mac 上的项目路径
   flutter pub get
   cd ios && pod install && cd ..
   ```
3. 用 Xcode 打开 `ios/Runner.xcworkspace`，配置 **Bundle Identifier** 与 **开发团队（Signing & Capabilities）**。
4. 构建：
   ```bash
   flutter build ipa
   ```
5. 用 Xcode「Organizer」或 **TestFlight** 装到手机。

> 边界说明：iOS 装真机必须走苹果开发者账号或 TestFlight；本指南只做本地打包，不做应用商店上架与资质审核。安卓 APK 可直接安装，门槛低得多。

---

## 六、账号与数据安全

- 这是**本地账号**，没有远程服务器。首次打开点登录页底部「去注册」自建账号（如账号 `demo`、密码 `123456`）。
- 同一台手机可注册多个账号，各账号待办数据**互相隔离**；备份 / 恢复也按账号走。
- **卸载 App 或清除应用数据 = 账号和清单一起丢失** → 重要清单请用首页菜单「导出备份」存一份 JSON 到手机文档目录。
- 密码以「加盐 SHA-256 哈希」存本机，明文不落盘；记住登录态用 `SharedPreferences`，下次打开自动进首页；「退出登录」只清当前身份，账号与待办仍在。

---

## 七、快速试用清单（装好 APK 后）

1. 用 `demo` 账号登录（或自己注册一个）。
2. 试试 4 个增强：
   - **深色模式**：首页菜单 → 主题切换（浅 / 深 / 跟随系统）。
   - **搜索 / 排序 / 分类**：列表顶部搜索框、排序菜单、分类标签筛选。
   - **到期提醒**：新建带截止日期的待办，看是否「已逾期」标红 / 「即将到期」标橙。
   - **导出备份**：首页菜单 → 导出 → 用文件管理器找到那个 JSON。
3. Android 13+ 首次会弹「通知权限」授权，允许后到期摘要通知才会推送。

---

## 八、常见打包报错排查

| 报错 | 原因 | 解决 |
|---|---|---|
| `cmdline-tools not found` | 未装 Android SDK Command-line Tools | Android Studio → SDK Manager 勾选安装 |
| `CocoaPods not installed` | iOS 环境缺 CocoaPods | `sudo gem install cocoapods` |
| `Gradle build failed` | 缓存 / 配置问题 | `flutter clean` 后重编 |
| keystore 密码错误 | `key.properties` 填错 | 核对密码与 alias |
| iOS `Provisioning profile` 不匹配 | 签名团队 / Bundle ID 不对 | Xcode 里重选团队、改 Bundle ID |
| 构建要求 `compileSdk ≥ 36` | 插件要求宿主 SDK 高 | `android/app/build.gradle.kts` 设 `compileSdk = 36` |
| `flutter_local_notifications` 报需 desugaring | 未开核心库脱糖 | 开启 `isCoreLibraryDesugaringEnabled=true` + 加 `desugar_jdk_libs` 依赖 |

---

## 九、环境踩坑备忘（本机沙箱）

- **VS 安装器在沙箱失效**：本机（沙箱）装 VS 时，安装器对「追加 C++ 组件（MSVC/Windows SDK/CMake）」静默 no-op，导致 `flutter test` 的 Windows 运行器起不来。普通电脑正常联网安装不会有此问题。
- **代理变量冲突**：沙箱同时设了 `HTTPS_PROXY`/`https_proxy`，Windows 大小写不敏感导致 VS 引导器崩溃（exit 138）；剥离小写副本（`env -u https_proxy -u http_proxy`）即可过引导器。
- **pub 镜像缺包**：`flutter-io.cn` 镜像缺 `flutter_lints`、`flutter_local_notifications` 等，`flutter pub get` 失败；改用默认 `pub.dev`（经代理）解析成功。项目 `pubspec.yaml` 已显式加 `test: ^1.32.0`。
- **中文文件名坑**：本沙箱 Git-Bash 无法可靠创建中文名文件（写入返回成功但后续按名查找不到），故本指南用 ASCII 文件名 `PACKAGING_AND_TEST_GUIDE.md`；在你自己的 Windows 上可随意改名回中文。

---

## 十、推送到 GitHub（含 CI 触发）

本项目已托管在 `https://github.com/xh18610952708-boop/flutter_todo_app`（公开仓库，默认分支 `main`），本机 `origin` 远端已配好。日常推送只需两步。

### 在你自己的 Windows 电脑上

> 用 **Git Bash**（开始菜单搜「Git Bash」）执行，不要用系统 `cmd.exe`（默认没有 git，且要 `cd` 到项目目录）。仓库在 `D:/WorkBuddy/flutter_todo_app`。

**首次推送（仓库已建好，只需关联远端并推送）**
```bash
cd /d/WorkBuddy/flutter_todo_app
git remote -v                      # 本机已配好 origin，可跳过下面两行
git remote add origin https://github.com/xh18610952708-boop/flutter_todo_app.git
git push -u origin main
```
首次推送时 Git Credential Manager 会弹浏览器登录 GitHub，登录后令牌被缓存，之后无需再登。

**日常提交 + 推送**
```bash
cd /d/WorkBuddy/flutter_todo_app
git add -A
git commit -m "你的改动说明"
git push                          # 已设 upstream，直接 push 即可
```

**从零新建仓库再推送（想重新建仓时）**
1. GitHub 网页 → 右上角 `+` → New repository → 名字 `flutter_todo_app`，**不要**勾 Add a README（保持空仓库）→ Create。
2. 本地：
```bash
git remote add origin https://github.com/<你的用户名>/flutter_todo_app.git
git push -u origin main
```

### 关于 PAT 与 CI 触发（重要）
- 用 **PAT（个人访问令牌）** 推送 Actions 工作流文件（`.github/workflows/*.yml`）时，令牌必须**额外勾选 `workflow` 作用域**——光有 `repo` 不够，否则整批推送会被
  `refusing to allow ... to create or update workflow ... without workflow scope` 拒绝。
- 你机器上日常推送走 Git Credential Manager 浏览器登录，**不需要 PAT**。PAT 只在临时脚本里用，用完应立即在 GitHub 撤销。
- 代码推到 GitHub 后，`.github/workflows/flutter-ci.yml` 会在每次 push / PR 自动跑 `flutter analyze` + `flutter test`（见下一节）。

### 已修复的两个 CI 红因（备查）
1. **Flutter 3.50 的 `flutter analyze` 把 info 级弃用提示当 fatal**（exit 1，典型为 `package:flutter/material.dart` 被框架建议改用 `material_ui`）。CI 命令已改为 `flutter analyze --no-fatal-infos`：`error/warning` 仍阻断构建，info 不阻断。
2. **`auth_service_test` 的「密码错误登录失败」用例原本写错**：`setUp` 的 `register` 会自动登录成 `carol`，用例却断言失败登录后 `currentUser` 为 null（实际仍是 `carol`）。已改为先 `logout()` 再验证，应用逻辑未动。

---

## 十一、CI 自动测试（GitHub Actions）

仓库根目录新增 `.github/workflows/flutter-ci.yml`：推送 / PR 时自动在 `ubuntu-latest` 跑 `flutter pub get` → `flutter analyze --no-fatal-infos` → `flutter test`。

- 跑在 Linux，无需 Windows C++ 工具链，因此连 `auth_service_test`（依赖 flutter 引擎）也能跑全。
- 用法：把项目推到 GitHub 仓库即可生效（见上一节）；本地无需任何额外操作。
- Flutter 版本固定 `3.50.0`（`stable`），与本地一致。
- 跑完状态可在 `https://github.com/xh18610952708-boop/flutter_todo_app/actions` 查看；README 顶部徽章随结果变绿 / 红。

---
*最后更新：2026-11-14*
