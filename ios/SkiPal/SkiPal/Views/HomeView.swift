//
//  HomeView.swift
//  SkiPal
//
//  首页 - 开始记录和实时数据显示
//

import SwiftUI

struct HomeView: View {
    @EnvironmentObject var locationService: LocationService
    @EnvironmentObject var recordingService: RecordingService
    @EnvironmentObject var skiSessionStore: SkiSessionStore
    
    var body: some View {
        NavigationView {
            ZStack {
                // 背景
                Color(.systemBackground)
                    .ignoresSafeArea()
                
                VStack(spacing: 20) {
                    // 状态卡片
                    LocationStatusCard()
                        .padding(.horizontal)
                    
                    // 主内容区
                    if recordingService.isRecording || recordingService.isPaused {
                        RecordingView()
                    } else {
                        StartView()
                    }
                    
                    Spacer()
                    
                    // 最近记录
                    if !skiSessionStore.sessions.isEmpty {
                        RecentRecordsSection()
                            .padding(.horizontal)
                    }
                }
                .padding(.vertical)
            }
            .navigationTitle("SkiPal")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        // 设置
                    }) {
                        Image(systemName: "gear")
                            .font(.title3)
                    }
                }
            }
        }
    }
}

// MARK: - 开始视图
struct StartView: View {
    @EnvironmentObject var locationService: LocationService
    @EnvironmentObject var recordingService: RecordingService
    
    var body: some View {
        VStack(spacing: 30) {
            Spacer()
            
            // 滑雪图标
            Image(systemName: "figure.skiing.downhill")
                .font(.system(size: 100))
                .foregroundStyle(.blue)
                .symbolEffect(.pulse)
            
            VStack(spacing: 12) {
                Text("准备滑雪")
                    .font(.title2)
                    .fontWeight(.bold)
                
                Text(locationService.canUseLocation 
                     ? "点击开始记录你的滑雪轨迹"
                     : "请授权定位权限以开始记录")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            
            Spacer()
            
            // 开始按钮
            Button(action: {
                if locationService.canUseLocation {
                    recordingService.startRecording()
                } else {
                    locationService.requestAuthorization()
                }
            }) {
                HStack(spacing: 12) {
                    Image(systemName: "record.circle.fill")
                        .font(.title2)
                    Text("开始滑雪")
                        .font(.title3)
                        .fontWeight(.bold)
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 70)
                .background(
                    RoundedRectangle(cornerRadius: 20)
                        .fill(.blue)
                        .shadow(color: .blue.opacity(0.3), radius: 10, x: 0, y: 5)
                )
            }
            .padding(.horizontal, 40)
            .disabled(!locationService.canUseLocation)
            .opacity(locationService.canUseLocation ? 1 : 0.6)
            
            Spacer()
        }
        .padding()
    }
}

// MARK: - 记录中视图
struct RecordingView: View {
    @EnvironmentObject var locationService: LocationService
    @EnvironmentObject var recordingService: RecordingService
    @EnvironmentObject var skiSessionStore: SkiSessionStore
    
    @State private var showingEndConfirmation = false
    
    var body: some View {
        VStack(spacing: 20) {
            // 记录状态
            HStack {
                Circle()
                    .fill(recordingService.isRecording ? .green : .orange)
                    .frame(width: 10, height: 10)
                
                Text(recordingService.isRecording ? "记录中..." : "已暂停")
                    .font(.headline)
                    .foregroundStyle(recordingService.isRecording ? .green : .orange)
                
                Spacer()
            }
            .padding(.horizontal)
            
            // 时间显示
            Text(formatDuration(recordingService.currentDuration))
                .font(.system(size: 60, weight: .bold, design: .rounded))
                .monospacedDigit()
            
            // 数据统计
            HStack(spacing: 15) {
                StatCard(
                    icon: "speedometer",
                    value: String(format: "%.1f", locationService.currentSpeed * 3.6),
                    unit: "km/h",
                    label: "速度",
                    color: .blue
                )
                
                StatCard(
                    icon: "arrow.up",
                    value: String(format: "%.0f", locationService.currentAltitude),
                    unit: "m",
                    label: "海拔",
                    color: .orange
                )
                
                StatCard(
                    icon: "ruler",
                    value: String(format: "%.1f", recordingService.currentDistance / 1000),
                    unit: "km",
                    label: "距离",
                    color: .green
                )
            }
            .padding(.horizontal)
            
            // 控制按钮
            HStack(spacing: 40) {
                if recordingService.isRecording {
                    // 暂停按钮
                    ControlButton(
                        icon: "pause.fill",
                        label: "暂停",
                        color: .orange
                    ) {
                        recordingService.pauseRecording()
                    }
                    
                    // 结束按钮
                    ControlButton(
                        icon: "stop.fill",
                        label: "结束",
                        color: .red
                    ) {
                        showingEndConfirmation = true
                    }
                } else {
                    // 继续按钮
                    ControlButton(
                        icon: "play.fill",
                        label: "继续",
                        color: .green
                    ) {
                        recordingService.resumeRecording()
                    }
                    
                    // 结束按钮
                    ControlButton(
                        icon: "stop.fill",
                        label: "结束",
                        color: .red
                    ) {
                        showingEndConfirmation = true
                    }
                }
            }
            .padding(.top, 30)
            
            Spacer()
        }
        .padding()
        .confirmationDialog("结束滑雪记录？", isPresented: $showingEndConfirmation) {
            Button("保存记录", role: .none) {
                if let session = recordingService.stopRecording() {
                    skiSessionStore.addSession(session)
                }
            }
            Button("取消", role: .cancel) {}
        } message: {
            Text("你的滑雪数据将被保存到历史记录中")
        }
    }
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let hours = Int(duration) / 3600
        let minutes = Int(duration) / 60 % 60
        let seconds = Int(duration) % 60
        
        if hours > 0 {
            return String(format: "%02d:%02d:%02d", hours, minutes, seconds)
        } else {
            return String(format: "%02d:%02d", minutes, seconds)
        }
    }
}

// MARK: - 位置状态卡片
struct LocationStatusCard: View {
    @EnvironmentObject var locationService: LocationService
    
    var body: some View {
        HStack(spacing: 15) {
            VStack(alignment: .leading, spacing: 6) {
                Text("当前位置")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                
                HStack(spacing: 6) {
                    Image(systemName: locationService.hasLocation ? "location.fill" : "location.slash")
                        .foregroundStyle(locationService.hasLocation ? .green : .orange)
                    
                    Text(locationService.hasLocation ? "GPS 已就绪" : "等待定位...")
                        .font(.subheadline)
                        .fontWeight(.medium)
                }
            }
            
            Spacer()
            
            // 信号强度
            VStack(alignment: .trailing, spacing: 6) {
                Text("信号强度")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                
                HStack(spacing: 3) {
                    ForEach(0..<4) { index in
                        RoundedRectangle(cornerRadius: 1)
                            .fill(index < locationService.locationAccuracyLevel ? Color.green : Color.gray.opacity(0.3))
                            .frame(width: 4, height: CGFloat((index + 1) * 4))
                    }
                }
            }
        }
        .padding()
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 15))
    }
}

// MARK: - 最近记录区域
struct RecentRecordsSection: View {
    @EnvironmentObject var skiSessionStore: SkiSessionStore
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("最近记录")
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
            
            ForEach(skiSessionStore.recentSessions(limit: 3)) { session in
                SessionRow(session: session)
            }
        }
    }
}

// MARK: - 会话行
struct SessionRow: View {
    let session: SkiSession
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(session.startTime, style: .date)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                
                Spacer()
                
                Text(session.startTime, style: .time)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            if let resort = session.resortName {
                Text(resort)
                    .font(.caption)
                    .foregroundStyle(.blue)
            }
            
            HStack(spacing: 12) {
                Label(
                    String(format: "%.1f km", session.totalDistance / 1000),
                    systemImage: "ruler"
                )
                .font(.caption)
                
                Text("•")
                    .foregroundStyle(.secondary)
                
                Label(
                    session.formattedDuration,
                    systemImage: "clock"
                )
                .font(.caption)
                
                Text("•")
                    .foregroundStyle(.secondary)
                
                Label(
                    String(format: "%.1f km/h", session.averageSpeed * 3.6),
                    systemImage: "speedometer"
                )
                .font(.caption)
            }
            .foregroundStyle(.secondary)
        }
        .padding()
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - 统计卡片
struct StatCard: View {
    let icon: String
    let value: String
    let unit: String
    let label: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(color)
            
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text(value)
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundStyle(.primary)
                
                Text(unit)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

// MARK: - 控制按钮
struct ControlButton: View {
    let icon: String
    let label: String
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 28))
                
                Text(label)
                    .font(.caption)
                    .fontWeight(.semibold)
            }
            .foregroundStyle(.white)
            .frame(width: 80, height: 80)
            .background(color)
            .clipShape(Circle())
            .shadow(color: color.opacity(0.4), radius: 10, x: 0, y: 5)
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    HomeView()
        .environmentObject(LocationService())
        .environmentObject(RecordingService(locationService: LocationService()))
        .environmentObject(SkiSessionStore())
}
