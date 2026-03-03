# SkiPal 阶段 2 开发任务

## 项目背景

SkiPal 是一个 iOS 滑雪记录应用，MVP（阶段 1）已完成核心功能：
- ✅ GPS 轨迹记录
- ✅ 实时数据显示
- ✅ 历史记录
- ✅ 成就系统

## 阶段 2 开发目标

实现以下 4 个核心功能：

### 1. 雪场数据库（自动识别）

**需求：**
- 内置全球主要滑雪场数据库（至少包含 50 个知名雪场）
- 根据用户 GPS 位置自动识别当前雪场（半径 5km 内匹配）
- 雪场信息包含：名称、国家、省份、经纬度、海拔范围、雪道数量、难度分布
- 支持手动选择/搜索雪场
- 支持用户提交新雪场（本地暂存，未来可同步）

**数据结构：**
```swift
struct SkiResort: Identifiable, Codable {
    let id: UUID
    let name: String
    let country: String
    let region: String
    let latitude: Double
    let longitude: Double
    let baseElevation: Double      // 基础海拔 (m)
    let summitElevation: Double    // 顶峰海拔 (m)
    let totalRuns: Int             // 雪道总数
    let difficultyDistribution: DifficultyDistribution
    let website: String?
    let imageUrl: String?
}

struct DifficultyDistribution: Codable {
    let beginner: Int      // 初级道数量
    let intermediate: Int  // 中级道数量
    let advanced: Int      // 高级道数量
    let expert: Int        // 专家道数量
}
```

**实现要点：**
- 使用 GeoJSON 或本地 JSON 文件存储雪场数据
- 使用 Core Location 的 `CLLocation.distance(from:)` 计算距离
- 在 `RecordingService` 中添加自动检测逻辑
- UI 显示：在 HomeView 顶部显示当前雪场卡片

---

### 2. 天气集成

**需求：**
- 集成天气预报 API（推荐使用 Open-Meteo，免费无需 API Key）
- 显示当前雪场天气：温度、降雪量、风速、能见度、天气状况
- 显示 5-7 天天气预报
- 滑雪指数评分（基于温度、降雪、风速综合计算）
- 恶劣天气预警（大风、暴雪、极寒）

**API 选择：**
```
Open-Meteo: https://api.open-meteo.com/v1/forecast
参数：latitude, longitude, hourly=temperature_2m,precipitation,snowfall,windspeed_10m
免费、无需 API Key、适合个人项目
```

**数据结构：**
```swift
struct WeatherData: Codable {
    let current: CurrentWeather
    let hourly: HourlyForecast
    let daily: DailyForecast
    let skiIndex: SkiIndex  // 自定义计算
}

struct SkiIndex {
    let score: Int           // 0-100
    let level: SkiCondition  // Poor/Fair/Good/Excellent
    let factors: [String]    // 影响因素说明
}
```

**UI 要求：**
- 在 HomeView 添加天气卡片
- 在雪场详情页显示详细天气预报
- 恶劣天气用醒目颜色警告

---

### 3. 社交分享卡片（图片生成）

**需求：**
- 生成精美的滑雪统计卡片图片（用于分享到微信/朋友圈/Instagram）
- 卡片内容：雪场名称、日期、轨迹地图、关键数据（距离、速度、海拔、时长）、成就星级
- 支持自定义卡片模板（至少 3 种风格）
- 一键分享到系统分享菜单

**技术实现：**
- 使用 SwiftUI 的 `ViewImageGenerator` 或 `UIGraphicsImageRenderer`
- 使用 MapKit 生成静态地图截图
- 使用 Swift Charts 生成海拔/速度图表

**卡片模板：**
1. **经典黑金**：深色背景 + 金色数据（高端感）
2. **清新蓝白**：浅色背景 + 蓝色点缀（清爽感）
3. **活力橙红**：渐变背景 + 大字体（运动感）

**分享功能：**
```swift
struct ShareCardView: View {
    var session: SkiSession
    var resort: SkiResort?
    var weather: WeatherData?
    
    var body: some View {
        // 卡片 UI
    }
}

// 生成图片
func generateShareImage() -> UIImage {
    // 渲染 ShareCardView 为 UIImage
}

// 系统分享
func share() {
    let image = generateShareImage()
    let vc = UIActivityViewController(
        activityItems: [image],
        applicationActivities: nil
    )
    // 呈现
}
```

---

### 4. iCloud 同步

**需求：**
- 使用 CloudKit 同步滑雪记录到 iCloud
- 支持多设备自动同步（iPhone/iPad）
- 冲突解决：以最新修改为准
- 离线模式：本地保存，网络恢复后同步
- 同步状态指示（同步中/已同步/同步失败）

**CloudKit 数据结构：**
```swift
// CloudKit Record Type: SkiSession
{
    "sessionID": String (UUID),
    "startTime": Date,
    "endTime": Date,
    "locations": Data (Codable),
    "resortName": String,
    "resortID": String,
    "totalDistance": Double,
    "maxSpeed": Double,
    "elevationGain": Double,
    "createdAt": Date,
    "modifiedAt": Date
}
```

**实现要点：**
- 使用 `CKDatabase` 私有数据库
- 使用 `CKOperationQueue` 管理批量操作
- 监听 `CKDatabaseChangedNotification`
- 在 `SkiSessionStore` 中添加同步层

**代码结构：**
```swift
class CloudKitSyncManager: ObservableObject {
    private let container: CKContainer
    private let database: CKDatabase
    
    func saveSession(_ session: SkiSession) async throws
    func fetchAllSessions() async throws -> [SkiSession]
    func deleteSession(_ session: SkiSession) async throws
    func startObservingChanges()
}
```

---

## 技术约束

- **iOS 版本**: 最低 iOS 17.0
- **UI 框架**: SwiftUI
- **数据存储**: UserDefaults (本地) + CloudKit (云端)
- **地图**: MapKit
- **图表**: Swift Charts
- **网络**: URLSession (原生，不依赖第三方)
- **代码风格**: 遵循现有代码风格，保持 Swift 最佳实践

---

## 交付要求

### 代码质量
1. 所有新代码必须有注释（关键逻辑、公共 API）
2. 遵循现有项目结构（Models/Services/Views 分层）
3. 使用 Swift 5.9+ 特性（async/await, Result 类型）
4. 错误处理使用 `Result` 或 `throws`，避免隐式 unwrap

### 测试要求
1. 核心功能需要单元测试（天气解析、雪场匹配算法）
2. 手动测试清单（每个功能点）

### 文档要求
1. 更新 README.md，说明新功能使用方法
2. 在代码中添加必要的文档注释

---

## 开发顺序建议

1. **雪场数据库**（基础数据，其他功能依赖）
2. **天气集成**（依赖雪场位置）
3. **社交分享卡片**（依赖前两者数据）
4. **iCloud 同步**（独立模块，可并行）

---

## 验收标准

### 雪场数据库
- [ ] 内置至少 50 个雪场数据
- [ ] 自动识别准确率 > 90%（5km 半径内）
- [ ] 支持手动搜索和选择
- [ ] UI 显示当前雪场信息

### 天气集成
- [ ] 正确获取并显示当前天气
- [ ] 显示 5 天天气预报
- [ ] 滑雪指数计算合理
- [ ] 恶劣天气有警告提示

### 社交分享卡片
- [ ] 至少 3 种卡片模板
- [ ] 生成的图片清晰美观
- [ ] 一键分享到系统分享菜单
- [ ] 卡片包含所有关键数据

### iCloud 同步
- [ ] 新记录自动同步到 iCloud
- [ ] 多设备数据一致
- [ ] 离线模式正常工作
- [ ] 同步状态可见

---

## 注意事项

1. **隐私保护**: 位置数据仅用于雪场识别和天气查询，不上传第三方
2. **API 限制**: Open-Meteo 免费层有调用限制，需要缓存天气数据（1 小时更新）
3. **电量优化**: 后台记录时优化 GPS 采样频率
4. **用户体验**: 所有网络请求需要加载状态和错误提示

---

*开始开发前，请先阅读现有代码结构，保持代码风格一致。*
