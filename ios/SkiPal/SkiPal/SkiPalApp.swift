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
    
    init() {
        // 初始化 recordingService
        let locService = LocationService()
        _locationService = StateObject(wrappedValue: locService)
        _recordingService = StateObject(wrappedValue: RecordingService(locationService: locService))
        _skiSessionStore = StateObject(wrappedValue: SkiSessionStore())
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(locationService)
                .environmentObject(recordingService)
                .environmentObject(skiSessionStore)
                .preferredColorScheme(.dark)  // 强制深色模式
        }
    }
}
