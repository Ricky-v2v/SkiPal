# SkiPal/ · iOS App 源码

App target 的全部源码与资源。分层：Views → Services → Models，详见 [docs/architecture.md](../../../docs/architecture.md#架构分层)。

| 路径 | 职责 |
| --- | --- |
| `SkiPalApp.swift` | `@main` 入口；创建并注入全部服务，强制深色模式，加载雪场库 |
| `Info.plist` | 手工维护：权限说明、后台模式、`SkiPalCloudKitContainerIdentifier` |
| `BackgroundTasks.plist` | 后台任务标识（`com.skipal.app.refresh` / `.processing`） |
| [Models/](Models/README.md) | Codable 数据模型与可计算指标 |
| [Services/](Services/README.md) | 可观察服务与纯逻辑引擎 |
| [Views/](Views/README.md) | SwiftUI 界面 |
| [Resources/](Resources/README.md) | 中英本地化字符串 |
| [Data/](Data/README.md) | 内置雪场坐标库 |
| `Base.lproj/LaunchScreen.storyboard` | 启动屏 |
| `Assets.xcassets/` | 图标与颜色资源（Xcode 管理，不写 README） |

> 结构/内容变更需更新此文档。
