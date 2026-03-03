//
//  AICoachView.swift
//  SkiPal
//
//  AI 教练视图 - 展示滑雪分析和改进建议
//

import SwiftUI
import Charts

struct AICoachView: View {
    @EnvironmentObject var skiSessionStore: SkiSessionStore
    @StateObject private var coachService = AICoachService.shared

    @State private var selectedSession: SkiSession?
    @State private var showingAnalysis = false

    var body: some View {
        NavigationView {
            ZStack {
                Color(.systemGroupedBackground)
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 20) {
                        // 总体评分卡片
                        if let analysis = coachService.currentAnalysis {
                            OverallScoreCard(analysis: analysis)
                        } else {
                            EmptyStateCard()
                        }

                        // 最近会话分析
                        RecentSessionsSection(
                            sessions: skiSessionStore.recentSessions(limit: 5),
                            onSelectSession: { session in
                                selectedSession = session
                                Task {
                                    await analyzeSession(session)
                                }
                            }
                        )

                        // 如果有分析结果，显示详情
                        if let analysis = coachService.currentAnalysis {
                            AnalysisDetailView(analysis: analysis)
                        }
                    }
                    .padding()
                }
            }
            .navigationTitle("AI 教练")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    if coachService.isAnalyzing {
                        ProgressView()
                    }
                }
            }
            .sheet(item: $selectedSession) { session in
                SessionAnalysisSheet(session: session)
            }
        }
    }

    private func analyzeSession(_ session: SkiSession) {
        coachService.sessionStore = skiSessionStore
        coachService.analyzeAndUpdate(session)
    }
}

// MARK: - 总体评分卡片
struct OverallScoreCard: View {
    let analysis: CoachAnalysis

    var body: some View {
        VStack(spacing: 15) {
            Text("综合评分")
                .font(.headline)
                .foregroundStyle(.secondary)

            ZStack {
                Circle()
                    .stroke(Color.gray.opacity(0.2), lineWidth: 15)
                    .frame(width: 150, height: 150)

                Circle()
                    .trim(from: 0, to: CGFloat(analysis.overallScore) / 100)
                    .stroke(
                        LinearGradient(
                            colors: [.blue, .cyan],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        style: StrokeStyle(lineWidth: 15, lineCap: .round)
                    )
                    .frame(width: 150, height: 150)
                    .rotationEffect(.degrees(-90))

                VStack(spacing: 4) {
                    Text("\(analysis.overallScore)")
                        .font(.system(size: 48, weight: .bold, design: .rounded))
                        .foregroundStyle(.primary)

                    Text(analysis.scoreLevel)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            // 分项评分
            HStack(spacing: 20) {
                ScoreBadge(title: "速度", score: analysis.speedAnalysis.speedScore, color: .blue)
                ScoreBadge(title: "技术", score: analysis.techniqueAnalysis.techniqueScore, color: .green)
                ScoreBadge(title: "平滑", score: analysis.techniqueAnalysis.smoothnessScore, color: .orange)
            }
        }
        .padding()
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 20))
    }
}

// MARK: - 评分徽章
struct ScoreBadge: View {
    let title: String
    let score: Int
    let color: Color

    var body: some View {
        VStack(spacing: 4) {
            Text(title)
                .font(.caption2)
                .foregroundStyle(.secondary)

            Text("\(score)")
                .font(.title3)
                .fontWeight(.bold)
                .foregroundStyle(color)
        }
        .frame(width: 60)
    }
}

// MARK: - 空状态卡片
struct EmptyStateCard: View {
    var body: some View {
        VStack(spacing: 15) {
            Image(systemName: "brain.head.profile")
                .font(.system(size: 50))
                .foregroundStyle(.blue.opacity(0.6))

            Text("开始分析你的滑雪数据")
                .font(.headline)

            Text("选择一次滑雪记录，AI 教练将为你分析并提供建议")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(40)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 20))
    }
}

// MARK: - 最近会话区域
struct RecentSessionsSection: View {
    let sessions: [SkiSession]
    let onSelectSession: (SkiSession) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("选择分析")
                .font(.headline)

            ForEach(sessions) { session in
                Button {
                    onSelectSession(session)
                } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(session.startTime, style: .date)
                                .font(.subheadline)
                                .fontWeight(.medium)

                            if let resort = session.resortName {
                                Text(resort)
                                    .font(.caption)
                                    .foregroundStyle(.blue)
                            }
                        }

                        Spacer()

                        VStack(alignment: .trailing, spacing: 4) {
                            Text(String(format: "%.1f km", session.totalDistance / 1000))
                                .font(.subheadline)
                                .fontWeight(.semibold)

                            Text(session.formattedDuration)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding()
                    .background(Color(.systemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .buttonStyle(.plain)
            }
        }
    }
}

// MARK: - 分析详情视图
struct AnalysisDetailView: View {
    let analysis: CoachAnalysis

    var body: some View {
        VStack(spacing: 20) {
            // 速度分析
            SpeedAnalysisView(analysis: analysis.speedAnalysis)

            // 技术分析
            TechniqueAnalysisView(analysis: analysis.techniqueAnalysis)

            // 改进建议
            SuggestionsView(suggestions: analysis.improvementSuggestions)

            // 历史对比
            if let comparison = analysis.comparisonWithHistory {
                HistoryComparisonView(comparison: comparison)
            }
        }
    }
}

// MARK: - 速度分析视图
struct SpeedAnalysisView: View {
    let analysis: SpeedAnalysis

    var body: some View {
        VStack(alignment: .leading, spacing: 15) {
            HStack {
                Image(systemName: "speedometer")
                    .foregroundStyle(.blue)
                Text("速度分析")
                    .font(.headline)

                Spacer()

                Text("\(analysis.speedScore)分")
                    .font(.subheadline)
                    .fontWeight(.bold)
                    .foregroundStyle(.blue)
            }

            HStack(spacing: 20) {
                VStack(alignment: .leading) {
                    Text("平均")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(String(format: "%.1f km/h", analysis.averageSpeed))
                        .font(.title2)
                        .fontWeight(.bold)
                }

                VStack(alignment: .leading) {
                    Text("最高")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(String(format: "%.1f km/h", analysis.maxSpeed))
                        .font(.title2)
                        .fontWeight(.bold)
                }

                VStack(alignment: .leading) {
                    Text("一致性")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(String(format: "%.0f%%", analysis.speedConsistency))
                        .font(.title2)
                        .fontWeight(.bold)
                }
            }

            // 速度分布图
            VStack(alignment: .leading, spacing: 8) {
                Text("速度分布")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                HStack(spacing: 4) {
                    SpeedDistributionBar(label: "慢", value: analysis.speedDistribution.slow, color: .green)
                    SpeedDistributionBar(label: "中", value: analysis.speedDistribution.moderate, color: .blue)
                    SpeedDistributionBar(label: "快", value: analysis.speedDistribution.fast, color: .orange)
                    SpeedDistributionBar(label: "极速", value: analysis.speedDistribution.veryFast, color: .red)
                }
            }

            Label(analysis.speedTrend.rawValue, systemImage: "chart.line.uptrend.xyaxis")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding()
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

// MARK: - 速度分布条
struct SpeedDistributionBar: View {
    let label: String
    let value: Int
    let color: Color

    var body: some View {
        VStack(spacing: 4) {
            RoundedRectangle(cornerRadius: 4)
                .fill(color)
                .frame(height: CGFloat(value) * 0.8)

            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)

            Text("\(value)%")
                .font(.caption2)
                .fontWeight(.medium)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - 技术分析视图
struct TechniqueAnalysisView: View {
    let analysis: TechniqueAnalysis

    var body: some View {
        VStack(alignment: .leading, spacing: 15) {
            HStack {
                Image(systemName: "figure.skiing.downhill")
                    .foregroundStyle(.green)
                Text("技术分析")
                    .font(.headline)

                Spacer()

                Text("\(analysis.techniqueScore)分")
                    .font(.subheadline)
                    .fontWeight(.bold)
                    .foregroundStyle(.green)
            }

            // 平滑度和控制力
            HStack(spacing: 20) {
                MetricRing(title: "平滑度", value: analysis.smoothnessScore, color: .purple)
                MetricRing(title: "控制力", value: analysis.controlScore, color: .orange)
            }

            // 转弯分析
            HStack {
                VStack(alignment: .leading) {
                    Text("转弯次数")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("\(analysis.turnAnalysis.estimatedTurns)")
                        .font(.title3)
                        .fontWeight(.bold)
                }

                Spacer()

                VStack(alignment: .trailing) {
                    Text("转弯平滑度")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(String(format: "%.0f%%", analysis.turnAnalysis.turnSmoothness))
                        .font(.title3)
                        .fontWeight(.bold)
                }
            }

            // 坡度处理
            VStack(alignment: .leading, spacing: 8) {
                Text("坡度分布")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                HStack(spacing: 8) {
                    SlopeLevelBar(level: "初级", value: analysis.slopeHandling.beginnerPercentage, color: .green)
                    SlopeLevelBar(level: "中级", value: analysis.slopeHandling.intermediatePercentage, color: .blue)
                    SlopeLevelBar(level: "高级", value: analysis.slopeHandling.advancedPercentage, color: .orange)
                    SlopeLevelBar(level: "专家", value: analysis.slopeHandling.expertPercentage, color: .red)
                }
            }

            Label("舒适度: \(analysis.slopeHandling.comfortLevel.rawValue)", systemImage: "hand.thumbsup")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding()
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

// MARK: - 指标环形图
struct MetricRing: View {
    let title: String
    let value: Int
    let color: Color

    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                Circle()
                    .stroke(Color.gray.opacity(0.2), lineWidth: 8)
                    .frame(width: 60, height: 60)

                Circle()
                    .trim(from: 0, to: CGFloat(value) / 100)
                    .stroke(color, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                    .frame(width: 60, height: 60)
                    .rotationEffect(.degrees(-90))

                Text("\(value)")
                    .font(.headline)
                    .fontWeight(.bold)
            }

            Text(title)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - 坡度等级条
struct SlopeLevelBar: View {
    let level: String
    let value: Int
    let color: Color

    var body: some View {
        VStack(spacing: 4) {
            Text("\(value)%")
                .font(.caption2)
                .fontWeight(.medium)

            RoundedRectangle(cornerRadius: 2)
                .fill(color)
                .frame(width: 30, height: CGFloat(value) * 0.5)

            Text(level)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }
}

// MARK: - 建议视图
struct SuggestionsView: View {
    let suggestions: [ImprovementSuggestion]

    var body: some View {
        VStack(alignment: .leading, spacing: 15) {
            HStack {
                Image(systemName: "lightbulb.fill")
                    .foregroundStyle(.yellow)
                Text("改进建议")
                    .font(.headline)
            }

            ForEach(suggestions.prefix(5)) { suggestion in
                SuggestionCard(suggestion: suggestion)
            }
        }
        .padding()
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

// MARK: - 建议卡片
struct SuggestionCard: View {
    let suggestion: ImprovementSuggestion

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(suggestion.title)
                    .font(.subheadline)
                    .fontWeight(.semibold)

                Spacer()

                PriorityBadge(priority: suggestion.priority)
            }

            Text(suggestion.description)
                .font(.caption)
                .foregroundStyle(.secondary)

            HStack {
                Image(systemName: "arrow.right.circle.fill")
                    .foregroundStyle(.blue)
                Text(suggestion.actionableTip)
                    .font(.caption)
                    .foregroundStyle(.blue)
            }
            .padding(.top, 4)
        }
        .padding()
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}

// MARK: - 优先级徽章
struct PriorityBadge: View {
    let priority: ImprovementSuggestion.Priority

    var body: some View {
        Text(priority.rawValue)
            .font(.caption2)
            .fontWeight(.medium)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(priorityColor.opacity(0.2))
            .foregroundStyle(priorityColor)
            .clipShape(Capsule())
    }

    private var priorityColor: Color {
        switch priority {
        case .high: return .red
        case .medium: return .orange
        case .low: return .blue
        }
    }
}

// MARK: - 历史对比视图
struct HistoryComparisonView: View {
    let comparison: HistoryComparison

    var body: some View {
        VStack(alignment: .leading, spacing: 15) {
            HStack {
                Image(systemName: "chart.bar.xaxis")
                    .foregroundStyle(.purple)
                Text("历史对比")
                    .font(.headline)
            }

            if comparison.isPersonalRecord {
                HStack {
                    Image(systemName: "trophy.fill")
                        .foregroundStyle(.yellow)
                    Text("恭喜！你打破了个人的记录！")
                        .font(.subheadline)
                        .fontWeight(.medium)
                }
                .padding()
                .background(Color.yellow.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 10))
            }

            HStack(spacing: 20) {
                if let speedImprovement = comparison.speedImprovement {
                    ComparisonMetric(
                        title: "速度变化",
                        value: speedImprovement,
                        isPositive: speedImprovement > 0
                    )
                }

                if let distanceImprovement = comparison.distanceImprovement {
                    ComparisonMetric(
                        title: "距离变化",
                        value: distanceImprovement,
                        isPositive: distanceImprovement > 0
                    )
                }
            }

            Label("技术趋势: \(comparison.techniqueTrend.rawValue)", systemImage: "chart.line.uptrend.xyaxis")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding()
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

// MARK: - 对比指标
struct ComparisonMetric: View {
    let title: String
    let value: Double
    let isPositive: Bool

    var body: some View {
        VStack(spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)

            HStack(spacing: 2) {
                Image(systemName: isPositive ? "arrow.up.right" : "arrow.down.right")
                Text(String(format: "%.1f%%", abs(value)))
            }
            .font(.subheadline)
            .fontWeight(.bold)
            .foregroundStyle(isPositive ? .green : .red)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - 会话分析 Sheet
struct SessionAnalysisSheet: View {
    let session: SkiSession
    @StateObject private var coachService = AICoachService.shared
    @EnvironmentObject var skiSessionStore: SkiSessionStore
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            ScrollView {
                if coachService.isAnalyzing {
                    VStack(spacing: 20) {
                        ProgressView()
                            .scaleEffect(1.5)

                        Text("正在分析...")
                            .font(.headline)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.top, 100)
                } else if let analysis = coachService.currentAnalysis {
                    VStack(spacing: 20) {
                        OverallScoreCard(analysis: analysis)
                        AnalysisDetailView(analysis: analysis)
                    }
                    .padding()
                }
            }
            .navigationTitle(session.startTime, style: .date)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("完成") {
                        dismiss()
                    }
                }
            }
        }
        .onAppear {
            coachService.sessionStore = skiSessionStore
            coachService.analyzeAndUpdate(session)
        }
    }
}

#Preview {
    AICoachView()
        .environmentObject(SkiSessionStore())
}