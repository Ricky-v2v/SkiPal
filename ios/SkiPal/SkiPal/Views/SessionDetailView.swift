//
//  SessionDetailView.swift
//  SkiPal
//
//  会话详情 - 统计展示和分享
//

import SwiftUI

struct SessionDetailView: View {
    let session: SkiSession
    @EnvironmentObject var skiSessionStore: SkiSessionStore
    @Environment(\.dismiss) private var dismiss
    
    @State private var showingShareCard = false
    @State private var showingDeleteConfirmation = false
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // 成就区域
                    AchievementSection(session: session)
                    
                    // 统计卡片
                    StatsSection(session: session)
                    
                    // 轨迹预览
                    if !session.locations.isEmpty {
                        SessionTrajectoryPreview(locations: session.locations)
                            .padding(.horizontal)
                    }
                    
                    // 分享按钮
                    ShareButton(session: session, showingShareCard: $showingShareCard)
                    
                    // 删除按钮
                    DeleteButton {
                        showingDeleteConfirmation = true
                    }
                }
                .padding(.vertical)
            }
            .navigationTitle("滑雪详情")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("完成") {
                        dismiss()
                    }
                }
            }
            .sheet(isPresented: $showingShareCard) {
                ShareCardView(session: session)
            }
            .alert("确认删除？", isPresented: $showingDeleteConfirmation) {
                Button("删除", role: .destructive) {
                    Task {
                        await skiSessionStore.deleteSessionWithSync(session)
                    }
                    dismiss()
                }
                Button("取消", role: .cancel) {}
            } message: {
                Text("此操作无法撤销")
            }
        }
    }
}

// MARK: - 成就区域
struct AchievementSection: View {
    let session: SkiSession
    
    var body: some View {
        VStack(spacing: 16) {
            Text("🎉 滑雪完成!")
                .font(.title)
                .fontWeight(.bold)
            
            HStack(spacing: 4) {
                ForEach(0..<5) { index in
                    Image(systemName: index < session.achievementStars ? "star.fill" : "star")
                        .font(.title2)
                        .foregroundStyle(index < session.achievementStars ? .yellow : .gray.opacity(0.3))
                }
            }
            
            Text(LocalizedStringKey(session.achievementTitle))
                .font(.headline)
                .foregroundStyle(.orange)
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(.ultraThinMaterial)
        )
        .padding(.horizontal)
    }
}

// MARK: - 统计区域
struct StatsSection: View {
    let session: SkiSession
    
    var body: some View {
        VStack(spacing: 16) {
            // 主统计
            HStack(spacing: 16) {
                LargeStatCard(
                    icon: "ruler",
                    value: String(format: "%.1f", session.totalDistance / 1000),
                    unit: "km",
                    label: "总距离",
                    color: .blue
                )
                
                LargeStatCard(
                    icon: "clock",
                    value: session.formattedDuration,
                    unit: "",
                    label: "用时",
                    color: .green
                )
            }
            .padding(.horizontal)
            
            // 次要统计
            VStack(spacing: 12) {
                StatRow(icon: "speedometer", label: "平均速度", value: String(format: "%.1f km/h", session.averageSpeed * 3.6))
                StatRow(icon: "bolt", label: "最大速度", value: String(format: "%.1f km/h", session.maxSpeed * 3.6))
                StatRow(icon: "arrow.up", label: "海拔上升", value: String(format: "%.0f m", session.elevationGain))
                StatRow(icon: "arrow.down", label: "海拔下降", value: String(format: "%.0f m", max(0, -session.elevationGain)))
                StatRow(icon: "calendar", label: "日期", value: session.startTime.formatted(date: .long, time: .shortened))
            }
            .padding()
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .padding(.horizontal)
        }
    }
}

// MARK: - 大统计卡片
struct LargeStatCard: View {
    let icon: String
    let value: String
    let unit: String
    let label: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title)
                .foregroundStyle(color)
            
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(value)
                    .font(.system(size: 36, weight: .bold, design: .rounded))
                    .foregroundStyle(.primary)
                
                if !unit.isEmpty {
                    Text(unit)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            
            Text(LocalizedStringKey(label))
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

// MARK: - 统计行
struct StatRow: View {
    let icon: String
    let label: String
    let value: String
    
    var body: some View {
        HStack {
            Label(LocalizedStringKey(label), systemImage: icon)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            
            Spacer()
            
            Text(value)
                .font(.subheadline)
                .fontWeight(.semibold)
        }
    }
}

// MARK: - 分享按钮
struct ShareButton: View {
    let session: SkiSession
    @Binding var showingShareCard: Bool
    
    var body: some View {
        Button(action: {
            showingShareCard = true
        }) {
            HStack(spacing: 12) {
                Image(systemName: "photo.on.rectangle")
                    .font(.title3)
                Text("生成分享卡片")
                    .font(.headline)
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .background(
                LinearGradient(
                    colors: [.blue, .purple],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .shadow(color: .blue.opacity(0.3), radius: 10, x: 0, y: 5)
        }
        .padding(.horizontal)
    }
}

// MARK: - 删除按钮
struct DeleteButton: View {
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: "trash")
                Text("删除记录")
            }
            .foregroundStyle(.red)
            .frame(maxWidth: .infinity)
            .frame(height: 50)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .padding(.horizontal)
    }
}

// MARK: - 轨迹预览
struct SessionTrajectoryPreview: View {
    let locations: [SkiLocation]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("滑行轨迹")
                .font(.headline)
            
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(.systemGray6))
                
                // 简化的轨迹显示 (实际应该使用 MapKit)
                Text("🗺️ 轨迹预览")
                    .foregroundColor(.secondary)
            }
            .frame(height: 200)
        }
        .padding()
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

#Preview {
    SessionDetailView(session: SkiSession())
        .environmentObject(SkiSessionStore())
}
