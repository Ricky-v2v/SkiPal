//
//  ContentView.swift
//  SkiPal
//
//  主内容视图 - TabView 容器
//

import SwiftUI

struct ContentView: View {
    @EnvironmentObject var locationService: LocationService
    @EnvironmentObject var recordingService: RecordingService
    @EnvironmentObject var skiSessionStore: SkiSessionStore
    @EnvironmentObject var resortDatabase: SkiResortDatabase
    @EnvironmentObject var weatherService: WeatherService
    
    @State private var selectedTab = 0
    @State private var showingSessionDetail: SkiSession?
    @State private var showingShareSheet = false
    
    var body: some View {
        TabView(selection: $selectedTab) {
            // 首页 - 实时记录
            HomeView()
                .tabItem {
                    Label("滑雪", systemImage: "figure.skiing.downhill")
                }
                .tag(0)
            
            // 地图视图
            SkiMapView()
                .tabItem {
                    Label("地图", systemImage: "map")
                }
                .tag(1)
            
            // 历史记录
            HistoryView()
                .tabItem {
                    Label("历史", systemImage: "clock")
                }
                .tag(2)
            
            // 雪场天气
            WeatherView(weatherService: weatherService, resortDatabase: resortDatabase)
                .tabItem {
                    Label("天气", systemImage: "cloud.sun")
                }
                .tag(3)
            
            // 统计概览
            StatisticsView()
                .tabItem {
                    Label("统计", systemImage: "chart.bar")
                }
                .tag(4)
        }
        .accentColor(.blue)
        .sheet(item: $showingSessionDetail) { session in
            SessionDetailView(session: session)
        }
        .onAppear {
            // 请求位置权限
            locationService.requestAuthorization()
        }
        // 监听新完成的会话
        .onChange(of: recordingService.state) { newState in
            if case .idle = newState {
                // 记录结束，切换到历史记录页
                selectedTab = 2
            }
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(LocationService())
        .environmentObject(RecordingService(locationService: LocationService()))
        .environmentObject(SkiSessionStore())
        .environmentObject(SkiResortDatabase.shared)
        .environmentObject(WeatherService.shared)
}
