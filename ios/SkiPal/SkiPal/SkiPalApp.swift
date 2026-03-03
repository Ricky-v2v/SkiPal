//
//  SkiPalApp.swift
//  SkiPal
//
//  应用入口
//

import SwiftUI

@main
struct SkiPalApp: App {
    // 核心服务
    @StateObject private var locationService = LocationService()
    @StateObject private var skiSessionStore = SkiSessionStore()
    @StateObject private var recordingService: RecordingService
    @StateObject private var resortDatabase = SkiResortDatabase.shared
    @StateObject private var weatherService = WeatherService.shared
    @StateObject private var syncService = CloudKitSyncService.shared

    // 高级功能服务 (Phase 3)
    @StateObject private var fallDetectionService = FallDetectionService.shared
    @StateObject private var videoRecordingService = VideoRecordingService.shared
    @StateObject private var watchConnectivityService = WatchConnectivityService.shared
    @StateObject private var aiCoachService = AICoachService.shared
    @StateObject private var shareCardService = ShareCardService.shared

    init() {
        // 初始化服务
        let locService = LocationService()
        _locationService = StateObject(wrappedValue: locService)
        _recordingService = StateObject(wrappedValue: RecordingService(locationService: locService))
        _skiSessionStore = StateObject(wrappedValue: SkiSessionStore())

        // 设置服务间依赖
        fallDetectionService.locationService = locService
        videoRecordingService.locationService = locService
        aiCoachService.sessionStore = skiSessionStore

        // 预加载雪场数据
        Task {
            await resortDatabase.loadResorts()
        }

        // 请求通知权限（跌倒检测需要）
        fallDetectionService.requestNotificationPermission()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(locationService)
                .environmentObject(recordingService)
                .environmentObject(skiSessionStore)
                .environmentObject(resortDatabase)
                .environmentObject(weatherService)
                .environmentObject(syncService)
                .environmentObject(fallDetectionService)
                .environmentObject(videoRecordingService)
                .environmentObject(watchConnectivityService)
                .environmentObject(aiCoachService)
                .environmentObject(shareCardService)
                .preferredColorScheme(.dark)  // 强制深色模式
        }
    }
}

// MARK: - Version Info
/// SkiPal Version: 1.0.0
/// Build: 2026.03.03
/// Phase 3 Complete
