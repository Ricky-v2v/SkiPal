# SkiPal Phase 2 - Quick Start Guide

## 🚀 Getting Started

### Prerequisites
- Xcode 15+ (iOS 17+ SDK)
- macOS 14+
- Apple Developer Account (for CloudKit)
- Physical device for location testing

### Setup Steps

1. **Enable CloudKit**
   ```
   Xcode → Project → Signing & Capabilities
   → Add Capability → iCloud
   → Check "CloudKit"
   → Select/Create Container: "iCloud.com.yourcompany.skipal"
   ```

2. **Add Location Permissions**
   
   In `Info.plist`:
   ```xml
   <key>NSLocationWhenInUseUsageDescription</key>
   <string>SkiPal needs location access to track your skiing</string>
   <key>NSLocationAlwaysAndWhenInUseUsageDescription</key>
   <string>SkiPal tracks your ski runs in the background</string>
   ```

3. **Build & Run**
   ```bash
   cd ios/SkiPal
   open SkiPal.xcodeproj
   # Build and run on device (Cmd+R)
   ```

## 📱 Features Overview

### Tab 1: 滑雪 (Skiing)
- Real-time GPS tracking
- Auto-detect ski resorts within 5km
- Record speed, distance, elevation
- Pause/Resume functionality

### Tab 2: 地图 (Map)
- View ski trail on map
- GPS path visualization

### Tab 3: 历史 (History)
- All past ski sessions
- iCloud sync status indicator
- Swipe to delete
- Tap to view details

### Tab 4: 天气 (Weather) ⭐ NEW
- Select from 55+ ski resorts
- Real-time weather data
- 5-day forecast
- Ski quality index (0-100)

### Tab 5: 统计 (Statistics)
- Personal bests
- Total stats
- Charts and graphs

## 🎨 Share Card Feature

1. Complete a ski session
2. Tap session in History
3. Tap "生成分享卡片" (Generate Share Card)
4. Choose template:
   - 经典黑金 (Classic Black/Gold)
   - 清新蓝白 (Fresh Blue/White)
   - 活力橙红 (Vibrant Orange/Red)
5. Share or Save to Photos

## ☁️ iCloud Sync

Sync status shown at top of History tab:
- 🔵 同步中 (Syncing)
- ✅ 已同步 (Synced)
- ⚠️ 离线模式 (Offline)
- ❌ 错误 (Error)

## 🎿 Ski Resort Database

55 resorts included:
- 🇨🇳 China: 10 (Nanshan, Wanlong, Thaiwoo, etc.)
- 🇺🇸 USA: 7 (Vail, Aspen, Park City, etc.)
- 🇨🇦 Canada: 3 (Whistler, Lake Louise, Sunshine)
- 🇫🇷 France: 4 (Chamonix, Val d'Isère, etc.)
- 🇨🇭 Switzerland: 4 (Zermatt, St. Moritz, etc.)
- 🇦🇹 Austria: 4 (Kitzbühel, St. Anton, etc.)
- 🇯🇵 Japan: 4 (Niseko, Hakuba, etc.)
- 🇦🇺 Australia: 3 (Thredbo, Perisher, etc.)
- 🇳🇿 New Zealand: 3 (Cardrona, Coronet Peak, etc.)
- 🇰🇷 South Korea: 2 (Yongpyong, Alpensia)
- 🇦🇷 Argentina: 1 (Cerro Catedral)
- 🇨🇱 Chile: 2 (Valle Nevado, Portillo)
- 🇬🇪 Georgia: 1 (Gudauri)
- 🇧🇬 Bulgaria: 1 (Bansko)
- 🇷🇴 Romania: 1 (Poiana Brașov)
- 🇫🇮 Finland: 1 (Levi)
- 🇸🇪 Sweden: 1 (Åre)
- 🇳🇴 Norway: 2 (Trysil, Hemsedal)
- 🇸🇮 Slovenia: 1 (Krvavec)
- 🇷🇸 Serbia: 1 (Kopaonik)

## 🌡️ Weather API

Using Open-Meteo (free, no API key):
- Temperature & feels-like
- Snowfall amount
- Wind speed
- Visibility
- 5-day forecast

Ski Index calculation:
- Perfect: 90-100
- Excellent: 80-89
- Very Good: 60-79
- Good: 40-59
- Fair: 20-39
- Poor: 0-19

## 📊 Data Structure

### SkiSession
```swift
struct SkiSession {
    let id: UUID
    var startTime: Date
    var endTime: Date?
    var locations: [SkiLocation]
    var resortName: String?
    
    // Computed
    var duration: TimeInterval
    var totalDistance: Double
    var maxSpeed: Double
    var elevationGain: Double
    var achievementStars: Int  // 1-5
}
```

### SkiWeather
```swift
struct SkiWeather {
    let temperature: Double
    let snowfall: Double
    let windSpeed: Double
    let visibility: Double
    let skiIndex: Int  // 0-100
    let forecast: [DailyForecast]
}
```

## 🛠️ Troubleshooting

### Location not working?
- Check Settings → Privacy → Location → SkiPal
- Ensure "While Using App" or "Always" is selected

### iCloud sync not working?
- Check Settings → [Your Name] → iCloud → iCloud Drive
- Ensure SkiPal is enabled
- Check network connection

### Weather not loading?
- Check network connection
- Open-Meteo API may be rate-limited
- Try selecting a different resort

### Share card not generating?
- Ensure session has location data
- Check device storage space
- Try different template

## 📝 Next Steps

1. Test on physical device
2. Enable CloudKit in production
3. Add App Store screenshots
4. Submit for review!

---

**Questions?** Check `PHASE2_IMPLEMENTATION.md` for detailed docs.

Happy skiing! 🎿
