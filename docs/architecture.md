# SkiPal 技术方案

> 本文件维护架构、服务装配与构建/测试命令。规则见 [AGENTS.md](../AGENTS.md)，需求见 [PRD](PRD.md)，当前状态见 [progress](progress.md)。

## 技术栈

- SwiftUI + Swift Charts + MapKit + Core Location + Core Motion
- CloudKit（私有库同步）、WatchConnectivity（iPhone ⇄ Apple Watch）、AVFoundation（视频）
- Swift 5.9 · iOS 17+ · watchOS 10+ · Xcode 15+
- XcodeGen（`ios/SkiPal/project.yml`）生成工程；GitHub Actions（`.github/workflows/ios-build.yml`）在 push/PR 到 `main` 时做构建校验（只构建，不跑测试）
- 单元测试：XCTest，`@testable import SkiPal`

## 目录

所有代码在 `ios/SkiPal/` 下，各目录职责见对应 README：

- [ios/SkiPal/README.md](../ios/SkiPal/README.md)：工程根（`project.yml`、`Package.swift`）
- [SkiPal/](../ios/SkiPal/SkiPal/README.md)：App 源码，含 Models / Services / Views / Resources / Data
- [SkiPalTests/](../ios/SkiPal/SkiPalTests/README.md)：单元测试
- [WatchApp/WatchApp/](../ios/SkiPal/WatchApp/WatchApp/README.md)：watchOS App

## 架构分层

```
Views/      SwiftUI 界面，只渲染，依赖服务暴露的 @Published 状态
Services/   ObservableObject 服务（定位、录制、天气、AI 教练、跌倒检测、视频、CloudKit、Watch）与纯逻辑引擎
Models/     Codable 数据与可计算属性（距离、速度、坡度、成就星级）
Resources/  zh-Hans / en 本地化字符串
Data/       雪场坐标库（ski_resorts.json）
```

视图不得直接接触 `CLLocationManager` 或传感器。

## 服务装配（`SkiPal/SkiPalApp.swift`）

- 所有服务在 `SkiPalApp` 中以 `@StateObject` 创建，经 `.environmentObject` 注入 `ContentView`。多数第三阶段服务为单例（`.shared`）。
- `LocationService` 在 `init()` 中创建一次并共享：`RecordingService(locationService:)` 订阅其 Combine publisher；`FallDetectionService.locationService`、`VideoRecordingService.locationService` 赋同一实例；`AICoachService.sessionStore` 同理。
- App 强制深色模式，并在 `.task` 中加载雪场数据库。

## 录制流程

`LocationService`（5 m 距离过滤，丢弃水平精度差于 50 m 的定位点，支持后台更新）
→ `RecordingService` 状态机（`idle → recording → paused → idle`）构建 `currentPath: [SkiLocation]`，
并查询 `SkiResortDatabase`（加载 `Data/ski_resorts.json`，5 km 半径）设置 `detectedResort`
→ 结束时生成 `SkiSession` 交给 `SkiSessionStore`。

## 持久化与同步

- `SkiSessionStore`：会话以 JSON 存 UserDefaults（键 `skipal_sessions`），计算汇总与个人最佳，并负责 GPX 导出和分享文本。
- CloudKit：`CloudKitSyncService` 与 `SkiSession+CloudKit` / `SkiSessionStore+CloudKit` 扩展（私有库）。`CloudKitSyncService.makeDatabase()` 先检查 `ubiquityIdentityToken` 再访问 `CKContainer`，因为无 iCloud 权限时创建容器会在启动时崩溃。**保留此保护。**
- `WatchConnectivityService`：向手表同步录制状态、位置、跌倒告警和会话，手表不可达时排队。手表端在 `WatchApp/WatchApp/`（`InterfaceController.swift` 是 SwiftUI `@main`，`WatchAppDelegate.swift` 持有 `WatchSessionModel`）。

## 指标与评分

- `SkiSession` 计算属性：距离、最高/平均速度、累计爬升、1–5 星成就、由最后两个点得出的坡度等级。
- `RunScoreEngine`（[F1](PRD.md#f1-滑行评分引擎)）：纯函数评分器，`SkiSession` → 0–100 总分 + 线路/节奏/体能分项 + 三条建议。速度单位全部为 m/s（同 `CLLocation.speed`）；负速度或 > 30 m/s 的点视为 GPS 噪声丢弃。规则写在文件头，由 `RunScoreEngineTests` 逐条验证。目前尚未接入任何界面。

## 并行 / 未接线的实现（修改前先确认）

- 两套教练：`AICoachService` + `AICoachView`，`SkiCoach` + `SkiCoachView`。两个视图都无法从 `ContentView` 的标签页进入。
- 两套跌倒检测（仅加速度计，未用陀螺仪）：`FallDetectionService`（单例，20 Hz，启动时注入）与 `FallDetector`（50 Hz，带灵敏度设置，仅 `FallDetectionSettingsView` 使用）。
- `VideoRecordingService` 已注入但没有界面入口。

后续取舍见 [roadmap](roadmap.md)。

主标签页（`Views/ContentView.swift`）：滑雪 Home、地图 Map、历史 History（含 `SyncStatusView`，详情 → `ShareCardView`）、天气 Weather（Open-Meteo API）、统计 Statistics。

## 构建与测试

Xcode 工程由 XcodeGen 从 `ios/SkiPal/project.yml` 生成。增删源文件后重新运行 `xcodegen generate`；不要手改 `project.pbxproj`。

```bash
cd ios/SkiPal
xcodegen generate

# 构建（与 CI 相同）
xcodebuild -project SkiPal.xcodeproj -scheme SkiPal \
  -destination 'platform=iOS Simulator,name=iPhone 15' clean build

# 全部单元测试
xcodebuild test -project SkiPal.xcodeproj -scheme SkiPal \
  -destination 'platform=iOS Simulator,name=iPhone 15'

# 单个测试类 / 方法
xcodebuild test -project SkiPal.xcodeproj -scheme SkiPal \
  -destination 'platform=iOS Simulator,name=iPhone 15' \
  -only-testing:SkiPalTests/RunScoreEngineTests/testEmptyTrackIsUnreliableWithFallback
```

- 模拟器名必须在本机存在（`xcrun simctl list devices available`）。CI 用 `iPhone 15`，较新的 Xcode 可能只带更新机型。
- `swift build` + `Package.swift` **不可用**：它以 macOS 为目标，编译 `LaunchScreen.storyboard` 时失败。请用 `xcodebuild`。
- 测试 target 将 `PRODUCT_NAME` / `PRODUCT_MODULE_NAME` 覆盖为 `SkiPalTests`，以避免与 App 模块冲突（见 `project.yml`）。
- `Info.plist` 手工维护（权限说明与 `SkiPalCloudKitContainerIdentifier` 键），所以 `project.yml` 故意没有 `info:` 段。
- CloudKit、紧急联系人、摄像头/麦克风等能力的签名与容器配置见 [QUICKSTART.md](../QUICKSTART.md)。
