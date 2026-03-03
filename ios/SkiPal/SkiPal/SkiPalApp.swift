//
//  SkiPalApp.swift
//  SkiPal
//
//  应用入口
//

import SwiftUI

@main
struct SkiPalApp: App {
    @StateObject private var locationService = LocationService()
    @StateObject private var skiSessionStore = SkiSessionStore()
    @StateObject private var recordingService: RecordingService
    @StateObject private var resortDatabase = SkiResortDatabase.shared
    @StateObject private var weatherService = WeatherService.shared
    @StateObject private var syncService = CloudKitSyncService.shared
    
    init() {
        // 初始化服务
        let locService = LocationService()
        _locationService = StateObject(wrappedValue: locService)
        _recordingService = StateObject(wrappedValue: RecordingService(locationService: locService))
        _skiSessionStore = StateObject(wrappedValue: SkiSessionStore())
        
        // 预加载雪场数据
        Task {
            await resortDatabase.loadResorts()
        }
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
                .preferredColorScheme(.dark)  // 强制深色模式
        }
    }
}
