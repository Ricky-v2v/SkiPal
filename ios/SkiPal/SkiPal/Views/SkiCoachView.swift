//
//  SkiCoachView.swift
//  SkiPal
//
//  AI 滑雪教练分析视图
//

import SwiftUI
import Charts

/// AI 教练分析主视图
struct SkiCoachView: View {
    let session: SkiSession
    let historicalSessions: [SkiSession]

    @State private var analysis: SkiAnalysis?
    @State private var trainingPlan: TrainingPlan?
    @State private var isLoading = true
    @State private var selectedTab = 0

    private let coach = SkiCoach()

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                if isLoading {
                    ProgressView("分析中...")
                        .padding(.top, 100)
                } else if let analysis = analysis {
                    // 总评分卡片
                    OverallScoreCard(analysis: analysis)

                    // 分数详情
                    ScoreBreakdownCard(analysis: analysis)

                    // 切换标签
                    Picker("", selection: $selectedTab) {
                        Text("建议").tag(0)
                        Text("洞察").tag(1)
                        Text("训练").tag(2)
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal)

                    // 内容区域
                    switch selectedTab {
                    case 0:
                        SuggestionsView(suggestions: analysis.suggestions)
                    case 1:
                        InsightsView(insights: analysis.insights)
                    case 2:
                        if let plan = trainingPlan {
                            TrainingPlanView(plan: plan)
                        }
                    default:
                        EmptyView()
                    }
                }
            }
            .padding(.vertical)
        }
        .navigationTitle("AI 教练分析")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await performAnalysis()
        }
    }

    private func performAnalysis() async {
        // 后台执行分析
        let result = await Task.detached(priority: .userInitiated) {
            if self.historicalSessions.isEmpty {
                return self.coach.analyze(session: self.session)
            } else {
                return self.coach.compareWithHistory(session: self.session, historicalSessions: self.historicalSessions)
            }
        }.value

        let plan = await Task.detached(priority: .userInitiated) {
            return self.coach.generateTrainingPlan(basedOn: result)
        }.value

        await MainActor.run {
            self.analysis = result
            self.trainingPlan = plan
            self.isLoading = false
        }
    }
}

// MARK: - Score Cards

/// 总评分卡片
struct OverallScoreCard: View {
    let analysis: SkiAnalysis

    var body: some View {
        VStack(spacing: 16) {
            // 圆形进度条
            ZStack {
                Circle()
                    .stroke(Color.gray.opacity(0.2), lineWidth: 12)
                    .frame(width: 150, height: 150)

                Circle()
                    .trim(from: 0, to: CGFloat(analysis.overallScore) / 100)
                    .stroke(
                        scoreColor(analysis.overallScore),
                        style: StrokeStyle(lineWidth: 12, lineCap: .round)
                    )
                    .frame(width: 150, height: 150)
                    .rotationEffect(.degrees(-90))

                VStack(spacing: 4) {
                    Text("\(analysis.overallScore)")
                        .font(.system(size: 48, weight: .bold, design: .rounded))
                        .foregroundColor(.white)

                    Text("综合评分")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
            }

            // 等级标签
            Text(LocalizedStringKey(analysis.scoreLevel.rawValue))
                .font(.headline)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(scoreColor(analysis.overallScore).opacity(0.2))
                .foregroundColor(scoreColor(analysis.overallScore))
                .cornerRadius(20)

            // 对比信息
            if let comparison = analysis.comparisonWithAverage {
                HStack(spacing: 24) {
                    ComparisonItem(
                        label: "速度",
                        value: comparison.speedVsAverage,
                        icon: "speedometer"
                    )

                    ComparisonItem(
                        label: "距离",
                        value: comparison.distanceVsAverage,
                        icon: "point.topleft.down.curvedto.point.bottomright.up"
                    )

                    ComparisonItem(
                        label: "时长",
                        value: comparison.durationVsAverage,
                        icon: "clock"
                    )
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(16)
        .padding(.horizontal)
    }

    private func scoreColor(_ score: Int) -> Color {
        switch score {
        case 0..<40: return .red
        case 40..<60: return .orange
        case 60..<80: return .blue
        default: return .green
        }
    }
}

/// 对比项
struct ComparisonItem: View {
    let label: String
    let value: Double
    let icon: String

    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .foregroundColor(value >= 0 ? .green : .red)

            Text(String(format: "%+.0f%%", value))
                .font(.caption)
                .fontWeight(.bold)
                .foregroundColor(value >= 0 ? .green : .red)

            Text(LocalizedStringKey(label))
                .font(.caption2)
                .foregroundColor(.gray)
        }
    }
}

/// 分数详情卡片
struct ScoreBreakdownCard: View {
    let analysis: SkiAnalysis

    var body: some View {
        VStack(spacing: 16) {
            Text("分数详情")
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .leading)

            // 雷达图
            RadarChartView(
                scores: [
                    ("速度", analysis.speedScore),
                    ("技巧", analysis.techniqueScore),
                    ("稳定性", analysis.consistencyScore),
                    ("安全", analysis.safetyScore)
                ]
            )
            .frame(height: 200)

            // 分数列表
            VStack(spacing: 12) {
                ScoreRow(label: "速度", score: analysis.speedScore, icon: "speedometer", color: .blue)
                ScoreRow(label: "技巧", score: analysis.techniqueScore, icon: "figure.skiing.downhill", color: .purple)
                ScoreRow(label: "稳定性", score: analysis.consistencyScore, icon: "waveform", color: .orange)
                ScoreRow(label: "安全", score: analysis.safetyScore, icon: "shield.checkered", color: .green)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(16)
        .padding(.horizontal)
    }
}

/// 分数行
struct ScoreRow: View {
    let label: String
    let score: Int
    let icon: String
    let color: Color

    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(color)
                .frame(width: 24)

            Text(LocalizedStringKey(label))
                .foregroundColor(.white)

            Spacer()

            // 进度条
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Rectangle()
                        .fill(Color.gray.opacity(0.3))
                        .frame(height: 8)
                        .cornerRadius(4)

                    Rectangle()
                        .fill(color)
                        .frame(width: geometry.size.width * CGFloat(score) / 100, height: 8)
                        .cornerRadius(4)
                }
            }
            .frame(width: 100)

            Text("\(score)")
                .font(.caption)
                .fontWeight(.bold)
                .foregroundColor(color)
                .frame(width: 30, alignment: .trailing)
        }
    }
}

// MARK: - Radar Chart

/// 雷达图视图
struct RadarChartView: View {
    let scores: [(String, Int)]

    var body: some View {
        GeometryReader { geometry in
            let center = CGPoint(x: geometry.size.width / 2, y: geometry.size.height / 2)
            let radius = min(geometry.size.width, geometry.size.height) / 2 - 30
            let angleStep = 2 * CGFloat.pi / CGFloat(scores.count)

            ZStack {
                // 背景网格
                ForEach(1...5, id: \.self) { ring in
                    Path { path in
                        for i in 0..<scores.count {
                            let angle = CGFloat(i) * angleStep - CGFloat.pi / 2
                            let point = CGPoint(
                                x: center.x + cos(angle) * radius * CGFloat(ring) / 5,
                                y: center.y + sin(angle) * radius * CGFloat(ring) / 5
                            )
                            if i == 0 {
                                path.move(to: point)
                            } else {
                                path.addLine(to: point)
                            }
                        }
                        path.closeSubpath()
                    }
                    .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                }

                // 数据区域
                Path { path in
                    for i in 0..<scores.count {
                        let angle = CGFloat(i) * angleStep - CGFloat.pi / 2
                        let value = CGFloat(scores[i].1) / 100
                        let point = CGPoint(
                            x: center.x + cos(angle) * radius * value,
                            y: center.y + sin(angle) * radius * value
                        )
                        if i == 0 {
                            path.move(to: point)
                        } else {
                            path.addLine(to: point)
                        }
                    }
                    path.closeSubpath()
                }
                .fill(Color.blue.opacity(0.3))
                .stroke(Color.blue, lineWidth: 2)

                // 标签
                ForEach(0..<scores.count, id: \.self) { i in
                    let angle = CGFloat(i) * angleStep - CGFloat.pi / 2
                    let labelPoint = CGPoint(
                        x: center.x + cos(angle) * (radius + 20),
                        y: center.y + sin(angle) * (radius + 20)
                    )

                    Text(LocalizedStringKey(scores[i].0))
                        .font(.caption)
                        .foregroundColor(.gray)
                        .position(labelPoint)
                }
            }
        }
    }
}

// MARK: - Suggestions View

/// 建议列表视图
struct SuggestionsView: View {
    let suggestions: [SkiSuggestion]

    var body: some View {
        VStack(spacing: 16) {
            ForEach(suggestions) { suggestion in
                SuggestionCard(suggestion: suggestion)
            }
        }
        .padding(.horizontal)
    }
}

/// 建议卡片
struct SuggestionCard: View {
    let suggestion: SkiSuggestion

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // 标题行
            HStack {
                Image(systemName: suggestion.category.icon)
                    .foregroundColor(categoryColor(suggestion.category))
                    .frame(width: 24)

                VStack(alignment: .leading, spacing: 2) {
                    Text(LocalizedStringKey(suggestion.title))
                        .font(.headline)
                        .foregroundColor(.white)

                    Text(LocalizedStringKey(suggestion.category.rawValue))
                        .font(.caption)
                        .foregroundColor(.gray)
                }

                Spacer()

                // 优先级标签
                Text(LocalizedStringKey(priorityText(suggestion.priority)))
                    .font(.caption2)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(priorityColor(suggestion.priority).opacity(0.2))
                    .foregroundColor(priorityColor(suggestion.priority))
                    .cornerRadius(4)
            }

            // 描述
            Text(LocalizedStringKey(suggestion.description))
                .font(.subheadline)
                .foregroundColor(.gray)

            // 行动建议
            HStack(alignment: .top, spacing: 8) {
                Image(systemName: "lightbulb.fill")
                    .foregroundColor(.yellow)
                    .font(.caption)

                Text(LocalizedStringKey(suggestion.action))
                    .font(.caption)
                    .foregroundColor(.white)
            }
            .padding(12)
            .background(Color(.systemGray5))
            .cornerRadius(8)
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }

    private func categoryColor(_ category: SuggestionCategory) -> Color {
        switch category {
        case .speed: return .blue
        case .technique: return .purple
        case .safety: return .red
        case .endurance: return .orange
        case .equipment: return .gray
        }
    }

    private func priorityText(_ priority: SkiSuggestion.Priority) -> String {
        switch priority {
        case .low: return "建议"
        case .medium: return "重要"
        case .high: return "紧急"
        }
    }

    private func priorityColor(_ priority: SkiSuggestion.Priority) -> Color {
        switch priority {
        case .low: return .gray
        case .medium: return .orange
        case .high: return .red
        }
    }
}

// MARK: - Insights View

/// 洞察列表视图
struct InsightsView: View {
    let insights: [SkiInsight]

    var body: some View {
        VStack(spacing: 12) {
            ForEach(insights) { insight in
                InsightCard(insight: insight)
            }
        }
        .padding(.horizontal)
    }
}

/// 洞察卡片
struct InsightCard: View {
    let insight: SkiInsight

    var body: some View {
        HStack(spacing: 12) {
            // 图标
            ZStack {
                Circle()
                    .fill(insightColor(insight.type).opacity(0.2))
                    .frame(width: 40, height: 40)

                Image(systemName: insightIcon(insight.type))
                    .foregroundColor(insightColor(insight.type))
            }

            // 内容
            VStack(alignment: .leading, spacing: 4) {
                Text(LocalizedStringKey(insight.title))
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.white)

                Text(LocalizedStringKey(insight.detail))
                    .font(.caption)
                    .foregroundColor(.gray)
            }

            Spacer()
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }

    private func insightColor(_ type: SkiInsight.InsightType) -> Color {
        switch type {
        case .strength: return .green
        case .improvement: return .orange
        case .trend: return .blue
        case .achievement: return .yellow
        }
    }

    private func insightIcon(_ type: SkiInsight.InsightType) -> String {
        switch type {
        case .strength: return "checkmark.circle.fill"
        case .improvement: return "arrow.up.circle.fill"
        case .trend: return "chart.line.uptrend.xyaxis"
        case .achievement: return "trophy.fill"
        }
    }
}

// MARK: - Training Plan View

/// 训练计划视图
struct TrainingPlanView: View {
    let plan: TrainingPlan
    @State private var expandedExercise: UUID?

    var body: some View {
        VStack(spacing: 16) {
            // 计划概览
            VStack(spacing: 12) {
                HStack {
                    Text(LocalizedStringKey(plan.title))
                        .font(.headline)
                        .foregroundColor(.white)

                    Spacer()

                    Text(LocalizedStringKey(plan.difficulty.rawValue))
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(difficultyColor(plan.difficulty).opacity(0.2))
                        .foregroundColor(difficultyColor(plan.difficulty))
                        .cornerRadius(4)
                }

                HStack {
                    Label("\(plan.duration) 分钟", systemImage: "clock")
                    Spacer()
                    Label("\(plan.exercises.count) 个练习", systemImage: "list.bullet")
                }
                .font(.caption)
                .foregroundColor(.gray)

                // 重点领域
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(plan.focusAreas, id: \.self) { area in
                            Text(LocalizedStringKey(area.rawValue))
                                .font(.caption)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 4)
                                .background(Color.blue.opacity(0.2))
                                .foregroundColor(.blue)
                                .cornerRadius(12)
                        }
                    }
                }
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(12)

            // 练习列表
            Text("练习项目")
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .leading)

            ForEach(plan.exercises) { exercise in
                ExerciseRow(exercise: exercise, isExpanded: expandedExercise == exercise.id) {
                    withAnimation {
                        expandedExercise = expandedExercise == exercise.id ? nil : exercise.id
                    }
                }
            }
        }
        .padding(.horizontal)
    }

    private func difficultyColor(_ difficulty: TrainingPlan.Difficulty) -> Color {
        switch difficulty {
        case .easy: return .green
        case .medium: return .orange
        case .hard: return .red
        }
    }
}

/// 练习行
struct ExerciseRow: View {
    let exercise: TrainingExercise
    let isExpanded: Bool
    let onToggle: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button(action: onToggle) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(LocalizedStringKey(exercise.name))
                            .font(.subheadline)
                            .foregroundColor(.white)

                        Text("\(exercise.repetitions) 组 · \(exercise.duration) 秒/组")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }

                    Spacer()

                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .foregroundColor(.gray)
                        .font(.caption)
                }
            }

            if isExpanded {
                Text(LocalizedStringKey(exercise.description))
                    .font(.caption)
                    .foregroundColor(.gray)
                    .padding(.top, 4)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(8)
    }
}

// MARK: - Preview

#Preview("Coach View") {
    NavigationView {
        SkiCoachView(
            session: SkiSession(
                startTime: Date().addingTimeInterval(-3600),
                locations: (0..<100).map { _ in
                    SkiLocation(from: CLLocation(
                        coordinate: CLLocationCoordinate2D(latitude: 39.9, longitude: 116.4),
                        altitude: 2000 + Double.random(in: -50...50),
                        horizontalAccuracy: 10,
                        verticalAccuracy: 5,
                        course: Double.random(in: 0...360),
                        speed: Double.random(in: 5...15),
                        timestamp: Date()
                    ))
                }
            ),
            historicalSessions: []
        )
    }
}
