# Views/

SwiftUI 界面，只做渲染与交互编排，不直接接触 `CLLocationManager` 或传感器。

| 文件 | 职责 |
| --- | --- |
| `ContentView.swift` | TabView 容器（滑雪、地图、历史、天气、统计） |
| `HomeView.swift` | 首页：开始/暂停/结束记录与实时数据 |
| `SkiMapView.swift` | 轨迹地图 |
| `HistoryView.swift` | 历史列表（含同步状态） |
| `SessionDetailView.swift` | 会话详情与分享入口 |
| `ShareCardView.swift` | 分享卡片预览与生成 |
| `StatisticsView.swift` | 统计概览与成就 |
| `WeatherView.swift` | 雪场天气与预报 |
| `SyncStatusView.swift` | iCloud 同步状态指示 |
| `FallDetectionView.swift` | 跌倒告警界面与 `FallDetectionSettingsView` |
| `AICoachView.swift` | AI 教练分析界面（标签页不可达） |
| `SkiCoachView.swift` | 另一套教练分析界面（标签页不可达） |

> 结构/内容变更需更新此文档。
