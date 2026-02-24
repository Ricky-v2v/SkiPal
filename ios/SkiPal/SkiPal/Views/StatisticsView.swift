//
//  StatisticsView.swift
//  SkiPal
//
//  统计概览 - 个人成就和数据分析
//

import SwiftUI
import Charts

struct StatisticsView: View {
    @EnvironmentObject var skiSessionStore: SkiSessionStore
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // 总览卡片
                    OverviewCard()
                    
                    // 个人最佳
                    PersonalBestsSection()
                    
                    // 最近活动趋势
                    if skiSessionStore.sessions.count >= 3 {
                        TrendSection()
                    }
                    
                    // 成就徽章
                    AchievementsSection()
                }
                .padding(.vertical)
            }
            .navigationTitle("统计概览")
            .navigationBarTitleDisplayMode(.large)
        }
    }
}

// MARK: - 总览卡片
struct OverviewCard: View {
    @EnvironmentObject var skiSessionStore: SkiSessionStore
    
    var body: some View {
        VStack(spacing: 20) {
            HStack(spacing: 20) {
                OverviewItem(
                    icon: "figure.skiing.downhill",
                    value: "\(skiSessionStore.sessionCount)",
                    label: "滑雪次数",
                    color: .blue
                )
                
                Divider()
                
                OverviewItem(
                    icon: "ruler",
                    value: String(format: "%.1f", skiSessionStore.totalDistance / 1000),
                    unit: "km",
                    label: "总里程",
                    color: .green
                )
            }
            
            Divider()
            
            HStack(spacing: 20) {
                OverviewItem(
                    icon: "clock",
                    value: formatDuration(skiSessionStore.totalDuration),
                    label: "总时长",
                    color: .orange
                )
                
                Divider()
                
                OverviewItem(
                    icon: "mountain.2",
                    value: String(format: "%.0f", skiSessionStore.sessions.reduce(0) { $0 + $1.elevationGain }),
                    unit: "m",
                    label: "累计爬升",
                    color: .purple
                )
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(.ultraThinMaterial)
        )
        .padding(.horizontal)
    }
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let hours = Int(duration) / 3600
        if hours >= 100 {
            return "\(hours)h"
        } else {
            return String(format: "%d:%02d", hours, (Int(duration) / 60) % 60)
        }
    }
}

// MARK: - 总览项
struct OverviewItem: View {
    let icon: String
    let value: String
    var unit: String? = nil
    let label: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(color)
            
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text(value)
                    .font(.title)
                    .fontWeight(.bold)
                
                if let unit = unit {
                    Text(unit)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - 个人最佳
struct PersonalBestsSection: View {
    @EnvironmentObject var skiSessionStore: SkiSessionStore
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("个人最佳")
                .font(.title3)
                .fontWeight(.bold)
                .padding(.horizontal)
            
            VStack(spacing: 12) {
                BestRow(
                    icon: "bolt.fill",
                    title: "最快速度",
                    value: String(format: "%.1f km/h", skiSessionStore.personalBestSpeed * 3.6),
                    color: .yellow
                )
                
                BestRow(
                    icon: "ruler.fill",
                    title: "最长距离",
                    value: String(format: "%.1f km", skiSessionStore.longestDistance / 1000),
                    color: .blue
                )
                
                BestRow(
                    icon: "clock.fill",
                    title: "最长时长",
                    value: formatDuration(skiSessionStore.longestDuration),
                    color: .green
                )
            }
            .padding()
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .padding(.horizontal)
        }
    }
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let hours = Int(duration) / 3600
        let minutes = Int(duration) / 60 % 60
        return String(format: "%d:%02d", hours, minutes)
    }
}

// MARK: - 最佳记录行
struct BestRow: View {
    let icon: String
    let title: String
    let value: String
    let color: Color
    
    var body: some View {
        HStack {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .foregroundStyle(color)
                Text(title)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            Text(value)
                .font(.headline)
                .fontWeight(.semibold)
        }
    }
}

// MARK: - 趋势图表
struct TrendSection: View {
    @EnvironmentObject var skiSessionStore: SkiSessionStore
    
    var recentSessions: [SkiSession] {
        Array(skiSessionStore.sessions.prefix(7).reversed())
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("最近7次趋势")
                .font(.title3)
                .fontWeight(.bold)
                .padding(.horizontal)
            
            VStack(alignment: .leading, spacing: 12) {
                Text("距离 (km)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                
                Chart(recentSessions) { session in
                    BarMark(
                        x: .value("日期", session.startTime, unit: .day),
                        y: .value("距离", session.totalDistance / 1000)
                    )
                    .foregroundStyle(.blue.gradient)
                    .cornerRadius(4)
                }
                .frame(height: 150)
                .chartXAxis {
                    AxisMarks(values: .stride(by: .day)) { value in
                        AxisValueLabel(format: .dateTime.day())
                    }
                }
            }
            .padding()
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .padding(.horizontal)
        }
    }
}

// MARK: - 成就徽章
struct AchievementsSection: View {
    @EnvironmentObject var skiSessionStore: SkiSessionStore
    
    let achievements = [
        Achievement(id: "first_run", icon: "🎿", title: "初雪者", description: "完成第一次滑雪", requirement: 1),
        Achievement(id: "speed_demon", icon: "⚡️", title: "速度达人", description: "速度超过30km/h", requirement: 1),
        Achievement(id: "distance_5k", icon: "🏃", title: "耐力王", description: "单次滑行超过5km", requirement: 1),
        Achievement(id: "distance_10k", icon: "🦅", title: "滑雪健将", description: "单次滑行超过10km", requirement: 1),
        Achievement(id: "total_10", icon: "🔟", title: "十次挑战", description: "累计滑雪10次", requirement: 10),
        Achievement(id: "total_100km", icon: "💯", title: "百公里", description: "累计滑行100km", requirement: 100)
    ]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("成就徽章")
                .font(.title3)
                .fontWeight(.bold)
                .padding(.horizontal)
            
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 100))], spacing: 16) {
                ForEach(achievements) { achievement in
                    AchievementBadge(
                        achievement: achievement,
                        isUnlocked: isUnlocked(achievement)
                    )
                }
            }
            .padding()
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .padding(.horizontal)
        }
    }
    
    private func isUnlocked(_ achievement: Achievement) -> Bool {
        switch achievement.id {
        case "first_run":
            return skiSessionStore.sessions.count >= 1
        case "speed_demon":
            return skiSessionStore.sessions.contains { $0.maxSpeed * 3.6 > 30 }
        case "distance_5k":
            return skiSessionStore.sessions.contains { $0.totalDistance > 5000 }
        case "distance_10k":
            return skiSessionStore.sessions.contains { $0.totalDistance > 10000 }
        case "total_10":
            return skiSessionStore.sessions.count >= 10
        case "total_100km":
            return skiSessionStore.totalDistance >= 100000
        default:
            return false
        }
    }
}

// MARK: - 成就模型
struct Achievement: Identifiable {
    let id: String
    let icon: String
    let title: String
    let description: String
    let requirement: Int
}

// MARK: - 成就徽章
struct AchievementBadge: View {
    let achievement: Achievement
    let isUnlocked: Bool
    
    var body: some View {
        VStack(spacing: 8) {
            Text(achievement.icon)
                .font(.system(size: 32))
                .opacity(isUnlocked ? 1 : 0.3)
            
            Text(achievement.title)
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundStyle(isUnlocked ? .primary : .secondary)
            
            Text(achievement.description)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .lineLimit(2)
        }
        .frame(height: 100)
        .frame(maxWidth: .infinity)
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(isUnlocked ? Color.yellow.opacity(0.1) : Color.clear)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(isUnlocked ? Color.yellow.opacity(0.3) : Color.gray.opacity(0.2), lineWidth: 1)
        )
    }
}

#Preview {
    StatisticsView()
        .environmentObject(SkiSessionStore())
}
