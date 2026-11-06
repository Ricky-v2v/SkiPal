# Services/

ObservableObject 服务与纯逻辑引擎；视图只依赖这里暴露的状态。装配关系见 [docs/architecture.md](../../../../docs/architecture.md#服务装配skipalskipalappswift)。

| 文件 | 职责 |
| --- | --- |
| `LocationService.swift` | GPS 定位与权限；5 m 过滤、丢弃精度差于 50 m 的点 |
| `RecordingService.swift` | 录制状态机，构建轨迹并识别雪场 |
| `SkiSessionStore.swift` | 会话持久化（UserDefaults JSON）、汇总、个人最佳、GPX 导出 |
| `SkiSessionStore+CloudKit.swift` | 会话存储的 CloudKit 同步扩展 |
| `CloudKitSyncService.swift` | CloudKit 私有库同步（含 `ubiquityIdentityToken` 保护） |
| `SkiResortDatabase.swift` | 加载 `Data/ski_resorts.json`，按半径匹配雪场 |
| `WeatherService.swift` | Open-Meteo 天气、预报与雪质指数 |
| `RunScoreEngine.swift` | F1 滑行评分纯函数引擎（未接入 UI） |
| `AICoachService.swift` | AI 教练分析（与 `SkiCoach` 并行存在） |
| `SkiCoach.swift` | 另一套 AI 教练分析（与 `AICoachService` 并行存在） |
| `FallDetectionService.swift` | 跌倒检测单例（20 Hz 加速度计），启动时注入 |
| `FallDetector.swift` | 另一套跌倒检测（50 Hz，带灵敏度），仅设置页使用 |
| `VideoRecordingService.swift` | 带数据叠加的视频录制（已注入，无 UI 入口） |
| `WatchConnectivityService.swift` | iPhone ⇄ Watch 同步与离线排队 |
| `ShareCardService.swift` | 分享卡片数据与模板 |
| `ShareCardGenerator.swift` | 用 `UIGraphicsImageRenderer` 渲染分享图 |

> 结构/内容变更需更新此文档。
