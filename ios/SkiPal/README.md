# ios/SkiPal · 工程根

XcodeGen 工程根目录：`project.yml` 生成 `SkiPal.xcodeproj`，包含 iOS App、单元测试与 watchOS App 三个 target。
构建与测试命令见 [docs/architecture.md](../../docs/architecture.md#构建与测试)。

| 路径 | 职责 |
| --- | --- |
| `project.yml` | XcodeGen 工程定义（生成源，增删文件后运行 `xcodegen generate`） |
| `Package.swift` | SPM 清单；以 macOS 为目标，`swift build` 无法通过，不作为构建入口 |
| [SkiPal/](SkiPal/README.md) | iOS App 源码 |
| [SkiPalTests/](SkiPalTests/README.md) | 单元测试 |
| [WatchApp/WatchApp/](WatchApp/WatchApp/README.md) | watchOS App |
| `SkiPal.xcodeproj/`、`build/`、`.build/` | 生成物，不手改、不写 README |

> 结构/内容变更需更新此文档。
