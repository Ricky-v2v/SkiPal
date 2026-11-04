# 技术上下文（SkiPal）

## 技术栈

- SwiftUI + Swift Charts + MapKit + Core Location + Core Motion
- CloudKit（私有库同步）、WatchConnectivity（iPhone ⇄ Apple Watch）、AVFoundation（视频）
- Swift 5.9 · iOS 17+ · watchOS 10+ · Xcode 15+
- XcodeGen（`ios/SkiPal/project.yml`）生成工程，GitHub Actions（`ios-build.yml`）做构建校验

## 架构分层

```
Views/      SwiftUI 界面，只依赖服务暴露的 @Published 状态
Services/   单一职责的可观察服务（定位、录制、天气、AI 教练、跌倒检测、视频、CloudKit、Watch）
Models/     纯数据与可计算属性（距离、速度、坡度、成就星级）
Resources/  zh-Hans / en 本地化字符串
Data/       雪场坐标库（ski_resorts.json）
```

## 约定

- 服务通过 SwiftUI `@EnvironmentObject` 注入；服务之间用 Combine 订阅，不互相持有强引用
- 位置采集：后台持续定位 + 5m 距离过滤，水平精度差于 50m 的定位点直接丢弃
- 持久化：UserDefaults + JSON（会话），CloudKit 仅用于跨设备同步
- 新增服务必须能在没有真机的情况下被单元测试覆盖纯逻辑部分

## 构建与验证

```bash
cd ios/SkiPal && xcodegen generate
xcodebuild -project ios/SkiPal/SkiPal.xcodeproj -scheme SkiPal \
  -destination 'platform=iOS Simulator,name=iPhone 15' clean build
```
