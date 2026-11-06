# SkiPal Phase 2 - Implementation Checklist

## ✅ Code Implementation (Complete)

- [x] Ski resort database (55 resorts)
- [x] Weather service (Open-Meteo API)
- [x] Share card generation (3 templates)
- [x] CloudKit sync service
- [x] Auto-detect nearby resorts (5km)
- [x] Ski index calculation (0-100)
- [x] 5-day weather forecast
- [x] Sync status indicator
- [x] Offline mode support
- [x] Weather view UI
- [x] Share card view UI
- [x] Updated existing views

## ⚠️ Required Configuration (Manual Steps)

### 1. Xcode Project Setup

- [ ] Open project in Xcode
  ```bash
  open ios/SkiPal/SkiPal.xcodeproj
  ```

- [ ] Enable CloudKit capability
  - Select project in navigator
  - Go to "Signing & Capabilities"
  - Click "+ Capability"
  - Search and add "iCloud"
  - Check "CloudKit"
  - Create/select container: `iCloud.com.yourcompany.skipal`

- [ ] Add iCloud entitlements
  - Should auto-generate `SkiPal.entitlements`
  - Verify contains:
    ```xml
    <key>com.apple.security.application-groups</key>
    <array>
        <string>iCloud.com.yourcompany.skipal</string>
    </array>
    ```

### 2. Info.plist Permissions

- [ ] Add location permissions to `Info.plist`:
  ```xml
  <key>NSLocationWhenInUseUsageDescription</key>
  <string>SkiPal 需要定位权限来记录您的滑雪轨迹和检测附近雪场</string>
  
  <key>NSLocationAlwaysAndWhenInUseUsageDescription</key>
  <string>SkiPal 需要后台定位来持续记录滑雪数据，即使在应用关闭后也能保存您的滑雪记录</string>
  
  <key>UIBackgroundModes</key>
  <array>
      <string>location</string>
  </array>
  ```

- [ ] Add photo library usage (for share cards):
  ```xml
  <key>NSPhotoLibraryAddUsageDescription</key>
  <string>SkiPal 需要访问相册来保存您的分享卡片</string>
  ```

### 3. CloudKit Database Setup

- [ ] Go to [CloudKit Dashboard](https://icloud.developer.apple.com/dashboard)
- [ ] Select your container
- [ ] Create record types in Private Database:
  - **SkiSession** with fields:
    - `sessionData` (Asset)
    - `sessionID` (String)
    - `startTime` (Date)
    - `endTime` (Date)
    - `resortName` (String)
    - `modifiedDate` (Date)

- [ ] Create indexes:
  - `sessionID` - Queryable
  - `startTime` - Queryable, Sortable
  - `modifiedDate` - Queryable, Sortable

### 4. Build Settings

- [ ] Set minimum deployment target to iOS 17.0
- [ ] Ensure Swift version is 5.9+
- [ ] Add `-ObjC` to Other Linker Flags (if needed)

### 5. Data Files

- [ ] Verify `ski_resorts.json` is in Copy Bundle Resources:
  - In Xcode: Build Phases → Copy Bundle Resources
  - Add `Data/ski_resorts.json` if not present

### 6. Testing

#### On Device Testing (Required)
- [ ] Build and run on physical device (simulator has limited location)
- [ ] Grant location permissions when prompted
- [ ] Test each tab:
  - [ ] Ski: Start/pause/resume/stop recording
  - [ ] Map: View trail on map
  - [ ] History: View sessions, check sync status
  - [ ] Weather: Select resort, view forecast
  - [ ] Stats: View statistics

#### Feature Testing
- [ ] Auto-detect resort:
  - [ ] Go to actual ski resort (or simulate location)
  - [ ] Start recording
  - [ ] Verify resort name is detected
  
- [ ] Weather:
  - [ ] Select different resorts
  - [ ] Verify weather data loads
  - [ ] Check ski index calculation
  
- [ ] Share Cards:
  - [ ] Complete a session
  - [ ] Generate share card
  - [ ] Test all 3 templates
  - [ ] Save to photos
  - [ ] Share to social media
  
- [ ] iCloud Sync:
  - [ ] Create session on device 1
  - [ ] Verify sync status shows "已同步"
  - [ ] Check on device 2 (if available)
  - [ ] Test offline mode (airplane mode)
  - [ ] Verify sync resumes when online

#### Edge Cases
- [ ] No network connection
- [ ] Location services disabled
- [ ] iCloud not signed in
- [ ] Empty session (no locations)
- [ ] Very long session (>4 hours)
- [ ] Many sessions (>100)

### 7. App Store Preparation

- [ ] Update app icon (if needed)
- [ ] Create launch screen
- [ ] Prepare screenshots:
  - [ ] Home/ski recording screen
  - [ ] Weather view
  - [ ] Share card preview
  - [ ] History with sync status
  - [ ] Statistics view
  
- [ ] Write app description highlighting:
  - 55+ ski resorts worldwide
  - Real-time weather & ski index
  - Beautiful share cards
  - iCloud sync across devices
  
- [ ] Set up App Store Connect:
  - [ ] Create app record
  - [ ] Upload build
  - [ ] Add metadata
  - [ ] Submit for review

### 8. Performance Optimization

- [ ] Profile with Instruments:
  - [ ] Check for memory leaks
  - [ ] Optimize image generation
  - [ ] Monitor network requests
  
- [ ] Add caching:
  - [ ] Cache weather data (5 min TTL)
  - [ ] Cache resort database
  - [ ] Cache map snapshots

### 9. Error Handling

- [ ] Add user-friendly error messages
- [ ] Implement retry mechanisms
- [ ] Add analytics/crash reporting (optional)

### 10. Documentation

- [x] Implementation summary (`PHASE2_IMPLEMENTATION.md`)
- [x] Quick start guide (`QUICKSTART.md`)
- [x] This checklist
- [ ] Update README.md with new features
- [ ] Add inline code comments (where needed)

## 🎯 Priority Order

### Must Have (Before Beta)
1. ✅ All code implemented
2. ⚠️ CloudKit configuration
3. ⚠️ Info.plist permissions
4. ⚠️ On-device testing
5. ⚠️ Basic error handling

### Should Have (Before Release)
1. ⚠️ App Store screenshots
2. ⚠️ Performance optimization
3. ⚠️ Edge case testing
4. ⚠️ Documentation update

### Nice to Have (Post-Launch)
1. More ski resorts
2. Custom share card templates
3. Weather notifications
4. Social features

## 📞 Support

If you encounter issues:

1. **Build errors**: Check Xcode console, verify Swift version
2. **CloudKit errors**: Check entitlements, container ID
3. **Location issues**: Test on device, check permissions
4. **Weather not loading**: Check network, API rate limits

## 🎉 Completion Criteria

Phase 2 is complete when:
- ✅ All code files created
- ✅ CloudKit configured and working
- ✅ All features tested on device
- ✅ No critical bugs
- ✅ Ready for App Store submission

---

**Current Status**: Code Complete ✅ | Configuration Pending ⚠️

**Next Action**: Open in Xcode and configure CloudKit!
