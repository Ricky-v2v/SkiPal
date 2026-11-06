# SkiPal · 滑雪伴侣

[English](#english) | 中文

SkiPal 是一款面向滑雪爱好者的 iOS / watchOS 应用：记录每一次滑雪的 GPS 轨迹，
实时给出速度、海拔、距离与坡度，结束后自动生成统计、成就与可分享的雪场卡片。

![Platform](https://img.shields.io/badge/platform-iOS%2017%20%2B%20%7C%20watchOS%2010%20%2B-blue)
![License](https://img.shields.io/badge/license-MIT-green)
![CI](https://github.com/Ricky-v2v/SkiPal/actions/workflows/ios-build.yml/badge.svg)

## 功能特性

| 模块 | 说明 |
| --- | --- |
| 实时记录 | GPS 轨迹录制，支持暂停/继续；后台持续定位，实时显示速度（km/h）、海拔、累计距离与当前坡度分级 |
| 雪场识别 | 内置 55+ 雪场坐标库，按当前坐标自动识别所在雪场 |
| 地图轨迹 | MapKit 渲染本次滑行路线与历史路线 |
| 历史记录 | 全部滑行会话列表，滑动删除，进入详情查看逐点数据 |
| 统计与成就 | 累计距离/时长/次数、个人最佳（最高速度、最长距离、最长时长）、1–5 星成就体系 |
| 分享卡片 | 生成分享图与分享文本，一键分享到社交平台 |
| 天气与雪质 | 雪场实时天气、5 日预报与 0–100 雪质指数 |
| AI 教练 | 基于本次滑行数据给出线路与动作建议（AI Coach / Ski Coach） |
| 跌倒检测 | 运动传感器异常检测，触发紧急联系人通知流程 |
| 视频录制 | 录制滑行视频，保留精彩瞬间 |
| Apple Watch | watchOS App 与 iPhone 双向同步（WatchConnectivity），手表端查看雪况与关键数据 |
| iCloud 同步 | CloudKit 私有库同步会话数据，跨设备恢复 |
| 紧急联系人 | 选取系统联系人作为紧急联系人，跌倒时联动 |
| 双语 | 简体中文 / English（`zh-Hans`、`en` 本地化资源） |

## 技术栈

- SwiftUI、Swift Charts、MapKit、Core Location、Core Motion、CloudKit、WatchConnectivity、AVFoundation
- Swift 5.9 · iOS 17+ · watchOS 10+
- XcodeGen 生成工程，GitHub Actions 做构建校验，XCTest 单元测试

## 目录结构

```
SkiPal/
├── ios/SkiPal/            # iOS 主工程
│   ├── SkiPal/            # App 源码
│   │   ├── Models/        # 数据模型（SkiSession、SkiResort、EmergencyContact…）
│   │   ├── Services/      # 定位、录制、天气、AI 教练、跌倒检测、视频、CloudKit、Apple Watch
│   │   ├── Views/         # SwiftUI 界面
│   │   ├── Resources/     # zh-Hans / en 本地化
│   │   └── Data/          # 雪场坐标库
│   ├── WatchApp/          # watchOS App
│   ├── SkiPalTests/       # 单元测试
│   └── project.yml        # XcodeGen 工程定义
├── docs/                  # 需求、进度、想法池、技术方案、历史归档
├── AGENTS.md              # 协作与 AI 编码工具的统一规则
├── QUICKSTART.md          # 本地运行与 CloudKit 配置
└── LICENSE
```

## 文档导航

| 文档 | 用途 |
| --- | --- |
| [AGENTS.md](AGENTS.md) | 开发规则、文档规范、行数约束 |
| [docs/progress.md](docs/progress.md) | 当前进度与交付状态 |
| [docs/PRD.md](docs/PRD.md) | 产品需求与变更台账 |
| [docs/roadmap.md](docs/roadmap.md) | 想法池与后续工作 |
| [docs/architecture.md](docs/architecture.md) | 技术方案、构建与测试 |
| [docs/history/](docs/history/README.md) | 第二阶段历史文档 |

## 构建与运行

前置条件：Xcode 15+（iOS 17 SDK）、macOS 14+；真机体验定位功能需真机设备。

```bash
# 1) 生成 Xcode 工程
cd ios/SkiPal
xcodegen generate

# 2) 用 Xcode 打开并运行（真机或模拟器均可，定位建议真机）
open SkiPal.xcodeproj
```

也可以用命令行构建：

```bash
cd ios/SkiPal
xcodebuild -project SkiPal.xcodeproj -scheme SkiPal \
  -destination 'platform=iOS Simulator,name=iPhone 15' clean build
```

CloudKit 同步、紧急联系人、摄像头/麦克风录制等能力需要在 Xcode 中配置签名、
容器与权限说明，详见 [QUICKSTART.md](QUICKSTART.md)。

## 隐私

所有滑行数据默认仅保存在本机（UserDefaults / 本地存储），开启 iCloud 同步后写入用户
自己的 CloudKit 私有数据库。定位、运动、通讯录、摄像头、麦克风权限仅在对应功能启用时申请。

## 许可证

[MIT](LICENSE)

---

## English

SkiPal is an iOS + watchOS app for ski enthusiasts. It records every run with GPS,
shows live speed, altitude, distance and slope grade, and turns each session into
statistics, achievements and shareable cards.

**Highlights:** live GPS tracking with background location · resort auto-detection
from a 55+ resort database · MapKit route rendering · history, statistics and
personal bests · share cards · live weather and a 0–100 snow-quality index ·
AI coaching · fall detection with emergency contacts · video recording ·
Apple Watch app with two-way sync · CloudKit sync · Chinese / English UI.

**Stack:** SwiftUI, Swift Charts, MapKit, Core Location, Core Motion, CloudKit,
WatchConnectivity, AVFoundation. Swift 5.9, iOS 17+, watchOS 10+. The Xcode
project is generated with XcodeGen, CI builds on GitHub Actions, and unit tests
cover the model layer.

**Build:**

```bash
cd ios/SkiPal && xcodegen generate && open SkiPal.xcodeproj
```

See [QUICKSTART.md](QUICKSTART.md) for CloudKit and permission setup.
Licensed under [MIT](LICENSE).
