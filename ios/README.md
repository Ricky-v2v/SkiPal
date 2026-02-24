# SkiPal iOS App

滑雪伴侣 App - 记录你的每一次滑雪之旅

## 功能特性

### MVP 核心功能 ✅
- [x] GPS 滑雪轨迹记录（开始/暂停/结束）
- [x] 实时数据显示（速度、海拔、距离、坡度）
- [x] 滑雪轨迹地图
- [x] 单次滑雪统计卡片（可分享）
- [x] 历史记录列表
- [x] 个人成就系统

### 设计特点
- **深色主题**：雪地阳光直射下依然清晰可见
- **大按钮设计**：戴手套也能轻松操作（最小60pt点击区域）
- **高对比度**：信息一目了然
- **实时反馈**：速度变化动画、震动反馈

## 项目结构

```
SkiPal/
├── SkiPalApp.swift           # 应用入口
├── Info.plist                # 应用配置
├── Package.swift             # Swift Package Manager
├── Models/
│   └── SkiSession.swift      # 数据模型
├── Services/
│   ├── LocationService.swift # 定位服务
│   ├── RecordingService.swift # 记录服务
│   └── SkiSessionStore.swift # 数据存储
└── Views/
    ├── ContentView.swift     # 主容器
    ├── HomeView.swift        # 首页/记录中
    ├── SkiMapView.swift      # 地图视图
    ├── HistoryView.swift     # 历史记录
    ├── SessionDetailView.swift # 详情页
    └── StatisticsView.swift  # 统计概览
```

## 技术栈

- **UI框架**: SwiftUI (iOS 17+)
- **地图**: MapKit
- **图表**: Swift Charts
- **数据存储**: UserDefaults (JSON)
- **定位**: Core Location

## 系统要求

- iOS 17.0+
- iPhone (需要GPS)
- 定位权限

## 安装运行

### 方式1: Xcode 直接运行
1. 打开 `SkiPal.xcodeproj` 或创建新的 SwiftUI 项目
2. 将代码文件导入项目
3. 配置 Bundle Identifier
4. 选择真机或模拟器运行

### 方式2: Swift Package Manager
```bash
cd ios/SkiPal
swift build
```

## 权限配置

App 需要以下权限：
- **定位（使用时）**: 记录轨迹
- **定位（始终）**: 后台持续记录
- **运动与健身**: 优化检测

在 `Info.plist` 中已配置权限描述。

## 核心功能说明

### 1. 滑雪记录
- 点击"开始滑雪"启动记录
- 后台持续记录GPS轨迹
- 自动计算速度、距离、海拔变化
- 支持暂停/继续/结束

### 2. 实时数据
- **速度**: 大字体显示，km/h
- **海拔**: 实时海拔高度
- **距离**: 累计滑行距离
- **坡度**: 当前坡度角度和等级

### 3. 坡度等级
- 🟢 初级道: 0-15°
- 🔵 中级道: 15-30°
- ⚫ 高级道: 30-40°
- 🔴 专家道: >40°

### 4. 成就系统
- ⭐ 初雪者: 完成第一次滑雪
- ⭐⭐ 速度达人: 速度>30km/h
- ⭐⭐⭐ 耐力王: 距离>5km
- ⭐⭐⭐⭐ 滑雪健将: 距离>10km
- ⭐⭐⭐⭐⭐ 传奇滑手: 打破个人记录

### 5. 数据持久化
- 自动保存到本地存储
- 支持导出 GPX 格式
- 生成分享文本

## 已知限制

1. 目前仅支持单设备存储
2. 雪场自动识别基于简单坐标匹配
3. 后台记录可能受系统限制
4. 长时间使用会增加电量消耗

## 后续规划

### 阶段1: 功能完善
- [ ] 雪场数据库
- [ ] 天气集成
- [ ] 更多统计图表
- [ ] iCloud 同步

### 阶段2: 社交功能
- [ ] 好友系统
- [ ] 排行榜
- [ ] 动态分享
- [ ] 活动组织

### 阶段3: 高级功能
- [ ] 视频记录
- [ ] AI 教练分析
- [ ] 装备管理
- [ ] 滑雪教学

## 开发者

Ricky - SkiPal 开发团队

## 许可证

MIT License
