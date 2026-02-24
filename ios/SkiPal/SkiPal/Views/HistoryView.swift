//
//  HistoryView.swift
//  SkiPal
//
//  历史记录列表
//

import SwiftUI

struct HistoryView: View {
    @EnvironmentObject var skiSessionStore: SkiSessionStore
    @State private var selectedSession: SkiSession?
    @State private var showingDeleteConfirmation = false
    @State private var sessionToDelete: SkiSession?
    
    var body: some View {
        NavigationView {
            List {
                // 统计摘要
                SummarySection()
                
                // 记录列表
                Section {
                    ForEach(skiSessionStore.sessions) { session in
                        HistoryRow(session: session)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                selectedSession = session
                            }
                    }
                    .onDelete(perform: deleteSessions)
                } header: {
                    Text("所有记录 (\(skiSessionStore.sessions.count))")
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("历史记录")
            .sheet(item: $selectedSession) { session in
                SessionDetailView(session: session)
            }
            .alert("确认删除？", isPresented: $showingDeleteConfirmation) {
                Button("删除", role: .destructive) {
                    if let session = sessionToDelete {
                        skiSessionStore.deleteSession(session)
                    }
                }
                Button("取消", role: .cancel) {}
            } message: {
                Text("此操作无法撤销")
            }
            .overlay {
                if skiSessionStore.sessions.isEmpty {
                    EmptyHistoryView()
                }
            }
        }
    }
    
    private func deleteSessions(at offsets: IndexSet) {
        skiSessionStore.deleteSession(at: offsets)
    }
}

// MARK: - 统计摘要
struct SummarySection: View {
    @EnvironmentObject var skiSessionStore: SkiSessionStore
    
    var body: some View {
        Section {
            HStack(spacing: 20) {
                SummaryItem(
                    icon: "number",
                    value: "\(skiSessionStore.sessionCount)",
                    label: "总次数"
                )
                
                Divider()
                
                SummaryItem(
                    icon: "ruler",
                    value: String(format: "%.1f", skiSessionStore.totalDistance / 1000),
                    unit: "km",
                    label: "总距离"
                )
                
                Divider()
                
                SummaryItem(
                    icon: "clock",
                    value: formatDuration(skiSessionStore.totalDuration),
                    label: "总时长"
                )
            }
            .padding(.vertical, 8)
        }
        .listRowBackground(
            LinearGradient(
                colors: [.blue.opacity(0.1), .purple.opacity(0.1)],
                startPoint: .leading,
                endPoint: .trailing
            )
        )
    }
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let hours = Int(duration) / 3600
        if hours >= 100 {
            return "\(hours)h"
        } else {
            let minutes = Int(duration) / 60 % 60
            return String(format: "%d:%02d", hours, minutes)
        }
    }
}

// MARK: - 统计项
struct SummaryItem: View {
    let icon: String
    let value: String
    var unit: String? = nil
    let label: String
    
    var body: some View {
        VStack(spacing: 4) {
            HStack(spacing: 4) {
                Text(value)
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundStyle(.primary)
                
                if let unit = unit {
                    Text(unit)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            
            Label(label, systemImage: icon)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - 历史记录行
struct HistoryRow: View {
    let session: SkiSession
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(session.startTime, style: .date)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                
                Spacer()
                
                // 成就星级
                Text(String(repeating: "⭐", count: session.achievementStars))
                    .font(.caption)
            }
            
            if let resort = session.resortName {
                Label(resort, systemImage: "mappin.and.ellipse")
                    .font(.caption)
                    .foregroundStyle(.blue)
            }
            
            // 进度条
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color.blue.opacity(0.2))
                        .frame(height: 4)
                    
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color.blue)
                        .frame(width: geometry.size.width * min(session.totalDistance / 10000, 1), height: 4)
                }
            }
            .frame(height: 4)
            
            HStack(spacing: 12) {
                StatLabel(
                    icon: "ruler",
                    value: String(format: "%.1f km", session.totalDistance / 1000)
                )
                
                StatLabel(
                    icon: "clock",
                    value: session.formattedDuration
                )
                
                StatLabel(
                    icon: "speedometer",
                    value: String(format: "%.1f km/h", session.averageSpeed * 3.6)
                )
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
    }
}

// MARK: - 统计标签
struct StatLabel: View {
    let icon: String
    let value: String
    
    var body: some View {
        Label(value, systemImage: icon)
    }
}

// MARK: - 空状态视图
struct EmptyHistoryView: View {
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "figure.skiing.downhill")
                .font(.system(size: 80))
                .foregroundStyle(.secondary.opacity(0.5))
            
            Text("还没有滑雪记录")
                .font(.title3)
                .fontWeight(.semibold)
            
            Text("开始你的第一次滑雪之旅吧！")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
    }
}

#Preview {
    HistoryView()
        .environmentObject(SkiSessionStore())
}
