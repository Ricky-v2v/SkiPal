//
//  SkiCoach.swift
//  SkiPal
//
//  AI 滑雪教练分析服务 - 分析滑雪数据提供改进建议
//

import Foundation
import CoreLocation

// MARK: - Analysis Models

/// 滑雪分析结果
struct SkiAnalysis: Codable {
    let sessionId: UUID
    let analysisDate: Date
    let overallScore: Int
    let speedScore: Int
    let techniqueScore: Int
    let consistencyScore: Int
    let safetyScore: Int
    let suggestions: [SkiSuggestion]
    let insights: [SkiInsight]
    let comparisonWithAverage: PerformanceComparison?

    /// 获取评分等级描述
    var scoreLevel: ScoreLevel {
        switch overallScore {
        case 0..<40: return .beginner
        case 40..<60: return .intermediate
        case 60..<80: return .advanced
        case 80...100: return .expert
        default: return .beginner
        }
    }

    enum ScoreLevel: String {
        case beginner = "初学者水平"
        case intermediate = "中等水平"
        case advanced = "高级水平"
        case expert = "专家水平"

        var color: String {
            switch self {
            case .beginner: return "绿色"
            case .intermediate: return "蓝色"
            case .advanced: return "黑色"
            case .expert: return "红色"
            }
        }
    }
}

/// 改进建议
struct SkiSuggestion: Identifiable, Codable {
    let id: UUID
    let category: SuggestionCategory
    let title: String
    let description: String
    let action: String
    let priority: Priority

    enum Priority: Int, Codable {
        case low = 1
        case medium = 2
        case high = 3

        var color: String {
            switch self {
            case .low: return "灰色"
            case .medium: return "橙色"
            case .high: return "红色"
            }
        }
    }
}

/// 建议分类
enum SuggestionCategory: String, Codable, CaseIterable {
    case speed = "速度"
    case technique = "技巧"
    case safety = "安全"
    case endurance = "耐力"
    case equipment = "装备"

    var icon: String {
        switch self {
        case .speed: return "speedometer"
        case .technique: return "figure.skiing.downhill"
        case .safety: return "shield.checkered"
        case .endurance: return "heart.fill"
        case .equipment: return "skis"
        }
    }
}

/// 滑雪洞察
struct SkiInsight: Identifiable, Codable {
    let id: UUID
    let type: InsightType
    let title: String
    let detail: String
    let data: [String: Double]?

    enum InsightType: String, Codable {
        case strength = "优势"
        case improvement = "改进点"
        case trend = "趋势"
        case achievement = "成就"
    }
}

/// 与平均水平对比
struct PerformanceComparison: Codable {
    let speedVsAverage: Double  // 百分比差异
    let distanceVsAverage: Double
    let durationVsAverage: Double
    let techniqueVsAverage: Double
}

/// 训练计划
struct TrainingPlan: Identifiable, Codable {
    let id: UUID
    let title: String
    let description: String
    let duration: Int  // 分钟
    let difficulty: Difficulty
    let focusAreas: [SuggestionCategory]
    let exercises: [TrainingExercise]

    enum Difficulty: String, Codable {
        case easy = "简单"
        case medium = "中等"
        case hard = "困难"
    }
}

/// 训练练习
struct TrainingExercise: Identifiable, Codable {
    let id: UUID
    let name: String
    let description: String
    let duration: Int  // 秒
    let repetitions: Int
}

// MARK: - SkiCoach Service

/// AI 滑雪教练服务
class SkiCoach {

    // MARK: - Analysis Constants

    /// 速度等级阈值 (km/h)
    private struct SpeedThresholds {
        static let beginner = 15.0
        static let intermediate = 25.0
        static let advanced = 35.0
        static let expert = 50.0
    }

    /// 坡度等级阈值 (度)
    private struct SlopeThresholds {
        static let beginner = 15.0
        static let intermediate = 25.0
        static let advanced = 35.0
    }

    // MARK: - Main Analysis

    /// 分析滑雪会话
    func analyze(session: SkiSession) -> SkiAnalysis {
        // 计算各项分数
        let speedScore = calculateSpeedScore(session: session)
        let techniqueScore = calculateTechniqueScore(session: session)
        let consistencyScore = calculateConsistencyScore(session: session)
        let safetyScore = calculateSafetyScore(session: session)

        // 综合评分 (加权平均)
        let overallScore = Int(
            Double(speedScore) * 0.25 +
            Double(techniqueScore) * 0.30 +
            Double(consistencyScore) * 0.25 +
            Double(safetyScore) * 0.20
        )

        // 生成建议
        let suggestions = generateSuggestions(
            session: session,
            speedScore: speedScore,
            techniqueScore: techniqueScore,
            consistencyScore: consistencyScore,
            safetyScore: safetyScore
        )

        // 生成洞察
        let insights = generateInsights(session: session)

        return SkiAnalysis(
            sessionId: session.id,
            analysisDate: Date(),
            overallScore: overallScore,
            speedScore: speedScore,
            techniqueScore: techniqueScore,
            consistencyScore: consistencyScore,
            safetyScore: safetyScore,
            suggestions: suggestions,
            insights: insights,
            comparisonWithAverage: nil
        )
    }

    /// 与历史数据对比分析
    func compareWithHistory(session: SkiSession, historicalSessions: [SkiSession]) -> SkiAnalysis {
        var analysis = analyze(session: session)

        // 计算历史平均
        guard !historicalSessions.isEmpty else { return analysis }

        let avgSpeed = historicalSessions.map { $0.averageSpeed }.reduce(0, +) / Double(historicalSessions.count)
        let avgDistance = historicalSessions.map { $0.totalDistance }.reduce(0, +) / Double(historicalSessions.count)
        let avgDuration = historicalSessions.map { $0.duration }.reduce(0, +) / Double(historicalSessions.count)

        // 计算对比
        let speedVsAvg = session.averageSpeed > 0 ? ((session.averageSpeed - avgSpeed) / avgSpeed) * 100 : 0
        let distanceVsAvg = session.totalDistance > 0 ? ((session.totalDistance - avgDistance) / avgDistance) * 100 : 0
        let durationVsAvg = session.duration > 0 ? ((session.duration - avgDuration) / avgDuration) * 100 : 0

        let comparison = PerformanceComparison(
            speedVsAverage: speedVsAvg,
            distanceVsAverage: distanceVsAvg,
            durationVsAverage: durationVsAvg,
            techniqueVsAverage: 0 // 简化计算
        )

        // 更新分析结果
        analysis = SkiAnalysis(
            sessionId: analysis.sessionId,
            analysisDate: analysis.analysisDate,
            overallScore: analysis.overallScore,
            speedScore: analysis.speedScore,
            techniqueScore: analysis.techniqueScore,
            consistencyScore: analysis.consistencyScore,
            safetyScore: analysis.safetyScore,
            suggestions: analysis.suggestions,
            insights: generateComparativeInsights(session: session, historical: historicalSessions),
            comparisonWithAverage: comparison
        )

        return analysis
    }

    // MARK: - Score Calculations

    /// 计算速度分数 (0-100)
    private func calculateSpeedScore(session: SkiSession) -> Int {
        let avgSpeedKmh = session.averageSpeed * 3.6  // 转换为 km/h
        let maxSpeedKmh = session.maxSpeed * 3.6

        // 平均速度得分 (40%)
        let avgScore: Double
        switch avgSpeedKmh {
        case 0..<SpeedThresholds.beginner:
            avgScore = 20
        case SpeedThresholds.beginner..<SpeedThresholds.intermediate:
            avgScore = 40 + (avgSpeedKmh - SpeedThresholds.beginner) / (SpeedThresholds.intermediate - SpeedThresholds.beginner) * 20
        case SpeedThresholds.intermediate..<SpeedThresholds.advanced:
            avgScore = 60 + (avgSpeedKmh - SpeedThresholds.intermediate) / (SpeedThresholds.advanced - SpeedThresholds.intermediate) * 20
        case SpeedThresholds.advanced..<SpeedThresholds.expert:
            avgScore = 80 + (avgSpeedKmh - SpeedThresholds.advanced) / (SpeedThresholds.expert - SpeedThresholds.advanced) * 15
        default:
            avgScore = 95
        }

        // 最大速度得分 (30%)
        let maxScore: Double
        switch maxSpeedKmh {
        case 0..<30: maxScore = 30
        case 30..<50: maxScore = 30 + (maxSpeedKmh - 30) / 20 * 40
        case 50..<70: maxScore = 70 + (maxSpeedKmh - 50) / 20 * 20
        default: maxScore = 90
        }

        // 速度稳定性得分 (30%)
        let speedVariance = calculateSpeedVariance(session: session)
        let stabilityScore = max(0, 100 - speedVariance * 2)

        let totalScore = avgScore * 0.4 + maxScore * 0.3 + stabilityScore * 0.3
        return Int(min(100, max(0, totalScore)))
    }

    /// 计算技巧分数 (0-100)
    private func calculateTechniqueScore(session: SkiSession) -> Int {
        guard session.locations.count > 10 else { return 50 }

        var score = 60.0  // 基础分

        // 1. 轨迹流畅度 (根据方向变化)
        let flowScore = calculateFlowScore(session: session)
        score += flowScore * 0.25

        // 2. 坡度适应能力
        let slopeScore = calculateSlopeAdaptation(session: session)
        score += slopeScore * 0.25

        // 3. 转弯技巧 (根据 course 变化)
        let turnScore = calculateTurnScore(session: session)
        score += turnScore * 0.20

        // 4. 速度控制
        let controlScore = calculateSpeedControl(session: session)
        score -= (100 - controlScore) * 0.10

        return Int(min(100, max(0, score)))
    }

    /// 计算一致性分数 (0-100)
    private func calculateConsistencyScore(session: SkiSession) -> Int {
        guard session.locations.count > 5 else { return 50 }

        // 速度标准差
        let speeds = session.locations.map { $0.speed }
        let meanSpeed = speeds.reduce(0, +) / Double(speeds.count)
        let variance = speeds.reduce(0) { $0 + pow($1 - meanSpeed, 2) } / Double(speeds.count)
        let stdDev = sqrt(variance)

        // 标准差越小，一致性越高
        let consistencyScore = max(0, 100 - stdDev * 5)

        return Int(consistencyScore)
    }

    /// 计算安全分数 (0-100)
    private func calculateSafetyScore(session: SkiSession) -> Int {
        var score = 100.0

        // 1. 检查是否有过度加速
        let maxAcceleration = calculateMaxAcceleration(session: session)
        if maxAcceleration > 5 {  // 超过 5 m/s²
            score -= min(20, (maxAcceleration - 5) * 5)
        }

        // 2. 检查速度是否过快
        let maxSpeedKmh = session.maxSpeed * 3.6
        if maxSpeedKmh > 60 {
            score -= min(15, (maxSpeedKmh - 60) * 0.5)
        }

        // 3. 检查高海拔变化速度 (下落过快)
        let maxDescentRate = calculateMaxDescentRate(session: session)
        if maxDescentRate > 10 {  // 超过 10 m/s
            score -= min(15, (maxDescentRate - 10) * 2)
        }

        return Int(max(0, score))
    }

    // MARK: - Helper Calculations

    private func calculateSpeedVariance(session: SkiSession) -> Double {
        let speeds = session.locations.map { $0.speed }
        guard !speeds.isEmpty else { return 0 }

        let mean = speeds.reduce(0, +) / Double(speeds.count)
        let variance = speeds.reduce(0) { $0 + pow($1 - mean, 2) } / Double(speeds.count)

        return sqrt(variance) * 3.6  // 转换为 km/h 标准差
    }

    private func calculateFlowScore(session: SkiSession) -> Double {
        guard session.locations.count > 2 else { return 50 }

        var directionChanges = 0
        var lastCourse: Double?

        for location in session.locations {
            if let last = lastCourse {
                // 计算方向变化
                let change = abs(location.course - last)
                let normalizedChange = min(change, 360 - change)  // 处理 360° 环绕

                // 如果方向变化平滑 (< 30°)，加分
                if normalizedChange < 30 {
                    directionChanges += 1
                }
            }
            lastCourse = location.course
        }

        let totalChanges = session.locations.count - 1
        let flowRatio = Double(directionChanges) / Double(totalChanges)

        return flowRatio * 100
    }

    private func calculateSlopeAdaptation(session: SkiSession) -> Double {
        guard session.locations.count > 2 else { return 50 }

        var adaptationScore = 0.0
        var slopeCount = 0

        for i in 2..<session.locations.count {
            let prev = session.locations[i - 1]
            let curr = session.locations[i]

            let distance = curr.location.distance(from: prev.location)
            guard distance > 0 else { continue }

            let elevationChange = curr.altitude - prev.altitude
            let slope = atan(abs(elevationChange) / distance) * 180 / .pi

            // 在不同坡度下的速度适应
            let speed = curr.speed * 3.6  // km/h

            // 根据坡度评估合理速度
            let expectedSpeed: Double
            switch slope {
            case 0..<10: expectedSpeed = 15  // 缓坡
            case 10..<20: expectedSpeed = 25  // 中等坡
            case 20..<30: expectedSpeed = 35  // 陡坡
            default: expectedSpeed = 40  // 极陡坡
            }

            // 速度在预期范围内则加分
            if speed > expectedSpeed * 0.7 && speed < expectedSpeed * 1.3 {
                adaptationScore += 1
            }
            slopeCount += 1
        }

        return slopeCount > 0 ? (adaptationScore / Double(slopeCount)) * 100 : 50
    }

    private func calculateTurnScore(session: SkiSession) -> Double {
        guard session.locations.count > 5 else { return 50 }

        var turnCount = 0
        var goodTurns = 0
        var lastCourse: Double?

        for location in session.locations {
            if let last = lastCourse {
                let change = abs(location.course - last)
                let normalizedChange = min(change, 360 - change)

                // 检测转弯 (> 15° 变化)
                if normalizedChange > 15 {
                    turnCount += 1

                    // 平滑转弯 (< 45°)
                    if normalizedChange < 45 {
                        goodTurns += 1
                    }
                }
            }
            lastCourse = location.course
        }

        // 转弯质量 + 适量转弯频率
        let turnQuality = turnCount > 0 ? Double(goodTurns) / Double(turnCount) * 50 : 25
        let turnFrequency = min(25, Double(turnCount) / Double(session.locations.count) * 1000)

        return turnQuality + turnFrequency
    }

    private func calculateSpeedControl(session: SkiSession) -> Double {
        guard session.locations.count > 3 else { return 50 }

        var suddenChanges = 0

        for i in 1..<session.locations.count {
            let prev = session.locations[i - 1]
            let curr = session.locations[i]

            let timeDiff = curr.timestamp.timeIntervalSince(prev.timestamp)
            guard timeDiff > 0 else { continue }

            let speedDiff = abs(curr.speed - prev.speed)
            let acceleration = speedDiff / timeDiff

            // 检测突然加速/减速
            if acceleration > 3 {  // 3 m/s²
                suddenChanges += 1
            }
        }

        let totalPoints = session.locations.count - 1
        let stability = 1.0 - Double(suddenChanges) / Double(totalPoints)

        return stability * 100
    }

    private func calculateMaxAcceleration(session: SkiSession) -> Double {
        guard session.locations.count > 1 else { return 0 }

        var maxAccel = 0.0

        for i in 1..<session.locations.count {
            let prev = session.locations[i - 1]
            let curr = session.locations[i]

            let timeDiff = curr.timestamp.timeIntervalSince(prev.timestamp)
            guard timeDiff > 0 else { continue }

            let speedDiff = abs(curr.speed - prev.speed)
            let acceleration = speedDiff / timeDiff

            maxAccel = max(maxAccel, acceleration)
        }

        return maxAccel
    }

    private func calculateMaxDescentRate(session: SkiSession) -> Double {
        guard session.locations.count > 1 else { return 0 }

        var maxRate = 0.0

        for i in 1..<session.locations.count {
            let prev = session.locations[i - 1]
            let curr = session.locations[i]

            let timeDiff = curr.timestamp.timeIntervalSince(prev.timestamp)
            guard timeDiff > 0 else { continue }

            let descent = prev.altitude - curr.altitude  // 正值表示下降
            if descent > 0 {
                let rate = descent / timeDiff
                maxRate = max(maxRate, rate)
            }
        }

        return maxRate
    }

    // MARK: - Suggestions Generation

    private func generateSuggestions(
        session: SkiSession,
        speedScore: Int,
        techniqueScore: Int,
        consistencyScore: Int,
        safetyScore: Int
    ) -> [SkiSuggestion] {
        var suggestions: [SkiSuggestion] = []

        // 速度建议
        if speedScore < 60 {
            if session.averageSpeed * 3.6 < SpeedThresholds.beginner {
                suggestions.append(SkiSuggestion(
                    id: UUID(),
                    category: .speed,
                    title: "提升滑行速度",
                    description: "您的平均速度较低，可以尝试在安全的情况下逐渐加速。",
                    action: "选择坡度适中的雪道，练习控制加速。保持身体重心略微前倾。",
                    priority: .medium
                ))
            } else if session.maxSpeed * 3.6 < SpeedThresholds.intermediate {
                suggestions.append(SkiSuggestion(
                    id: UUID(),
                    category: .speed,
                    title: "突破速度瓶颈",
                    description: "您的最大速度还有提升空间。",
                    action: "在宽直的雪道上练习加速，感受速度提升的同时保持控制。",
                    priority: .low
                ))
            }
        }

        // 技巧建议
        if techniqueScore < 70 {
            let turnScore = calculateTurnScore(session: session)
            if turnScore < 50 {
                suggestions.append(SkiSuggestion(
                    id: UUID(),
                    category: .technique,
                    title: "改善转弯技巧",
                    description: "您的转弯技巧需要提升，转弯不够流畅。",
                    action: "练习犁式转弯，控制转弯角度。尝试小弯和大弯的组合练习。",
                    priority: .high
                ))
            }

            let flowScore = calculateFlowScore(session: session)
            if flowScore < 60 {
                suggestions.append(SkiSuggestion(
                    id: UUID(),
                    category: .technique,
                    title: "提高滑行流畅度",
                    description: "您的滑行轨迹变化较多，可以尝试更流畅的滑行。",
                    action: "保持视线向前，预判路线。减少不必要的方向调整。",
                    priority: .medium
                ))
            }
        }

        // 一致性建议
        if consistencyScore < 60 {
            suggestions.append(SkiSuggestion(
                id: UUID(),
                category: .endurance,
                title: "提升滑行稳定性",
                description: "您的速度波动较大，影响整体表现。",
                action: "保持均匀的滑行节奏，避免频繁的速度变化。练习控制呼吸。",
                priority: .medium
            ))
        }

        // 安全建议
        if safetyScore < 80 {
            if calculateMaxAcceleration(session: session) > 5 {
                suggestions.append(SkiSuggestion(
                    id: UUID(),
                    category: .safety,
                    title: "注意速度控制",
                    description: "检测到多次急加速/急减速，可能存在安全隐患。",
                    action: "练习渐进式加速和减速，避免突然的速度变化。",
                    priority: .high
                ))
            }

            if session.maxSpeed * 3.6 > 60 {
                suggestions.append(SkiSuggestion(
                    id: UUID(),
                    category: .safety,
                    title: "高速滑行需谨慎",
                    description: "您的最高速度较快，请确保能够安全控制。",
                    action: "佩戴头盔和护具。在人员较少的雪道练习高速滑行。",
                    priority: .medium
                ))
            }
        }

        // 装备建议 (通用)
        if session.totalDistance > 10000 {
            suggestions.append(SkiSuggestion(
                id: UUID(),
                category: .equipment,
                title: "检查装备磨损",
                description: "长距离滑行后，建议检查滑雪板和固定器状态。",
                action: "检查板底是否有划痕，固定器是否松动。考虑定期打蜡保养。",
                priority: .low
            ))
        }

        return suggestions.sorted { $0.priority.rawValue > $1.priority.rawValue }
    }

    // MARK: - Insights Generation

    private func generateInsights(session: SkiSession) -> [SkiInsight] {
        var insights: [SkiInsight] = []

        // 速度洞察
        let avgSpeedKmh = session.averageSpeed * 3.6
        let maxSpeedKmh = session.maxSpeed * 3.6

        if maxSpeedKmh > 50 {
            insights.append(SkiInsight(
                id: UUID(),
                type: .achievement,
                title: "速度突破",
                detail: String(format: "最高速度达到 %.1f km/h，表现优秀！", maxSpeedKmh),
                data: ["maxSpeed": maxSpeedKmh]
            ))
        }

        // 距离洞察
        let distanceKm = session.totalDistance / 1000
        if distanceKm > 10 {
            insights.append(SkiInsight(
                id: UUID(),
                type: .achievement,
                title: "耐力表现",
                detail: String(format: "滑行距离 %.1f km，耐力很好！", distanceKm),
                data: ["distance": distanceKm]
            ))
        }

        // 海拔洞察
        if session.elevationGain > 500 {
            insights.append(SkiInsight(
                id: UUID(),
                type: .strength,
                title: "爬坡能力强",
                detail: String(format: "累计爬升 %.0f 米", session.elevationGain),
                data: ["elevationGain": session.elevationGain]
            ))
        }

        // 时长洞察
        let durationMinutes = session.duration / 60
        if durationMinutes > 120 {
            insights.append(SkiInsight(
                id: UUID(),
                type: .strength,
                title: "持久滑行",
                detail: String(format: "持续滑行 %.0f 分钟", durationMinutes),
                data: ["duration": durationMinutes]
            ))
        }

        // 速度分布
        let speedVariance = calculateSpeedVariance(session: session)
        if speedVariance > 10 {
            insights.append(SkiInsight(
                id: UUID(),
                type: .improvement,
                title: "速度波动较大",
                detail: String(format: "速度标准差 %.1f km/h，建议保持更稳定的节奏", speedVariance),
                data: ["speedVariance": speedVariance]
            ))
        }

        return insights
    }

    private func generateComparativeInsights(session: SkiSession, historical: [SkiSession]) -> [SkiInsight] {
        var insights = generateInsights(session: session)

        guard !historical.isEmpty else { return insights }

        // 与历史对比
        let avgSpeed = historical.map { $0.averageSpeed }.reduce(0, +) / Double(historical.count)
        let avgDistance = historical.map { $0.totalDistance }.reduce(0, +) / Double(historical.count)

        // 速度提升
        if session.averageSpeed > avgSpeed * 1.1 {
            let improvement = (session.averageSpeed - avgSpeed) / avgSpeed * 100
            insights.append(SkiInsight(
                id: UUID(),
                type: .trend,
                title: "速度提升",
                detail: String(format: "比平均速度快 %.0f%%，进步明显！", improvement),
                data: ["improvement": improvement]
            ))
        }

        // 距离突破
        if session.totalDistance > avgDistance * 1.2 {
            insights.append(SkiInsight(
                id: UUID(),
                type: .trend,
                title: "距离突破",
                detail: String(format: "滑行距离比平均多 %.0f%%", (session.totalDistance - avgDistance) / avgDistance * 100),
                data: nil
            ))
        }

        return insights
    }

    // MARK: - Training Plan Generation

    /// 生成个性化训练计划
    func generateTrainingPlan(basedOn analysis: SkiAnalysis) -> TrainingPlan {
        // 根据弱点生成训练重点
        var focusAreas: [SuggestionCategory] = []

        if analysis.speedScore < 70 {
            focusAreas.append(.speed)
        }
        if analysis.techniqueScore < 70 {
            focusAreas.append(.technique)
        }
        if analysis.consistencyScore < 70 {
            focusAreas.append(.endurance)
        }
        if analysis.safetyScore < 80 {
            focusAreas.append(.safety)
        }

        if focusAreas.isEmpty {
            focusAreas = [.technique, .speed]  // 默认
        }

        // 生成练习
        var exercises: [TrainingExercise] = []

        if focusAreas.contains(.speed) {
            exercises.append(contentsOf: [
                TrainingExercise(id: UUID(), name: "直线加速", description: "在平直雪道上练习加速", duration: 120, repetitions: 5),
                TrainingExercise(id: UUID(), name: "速度控制", description: "练习从高速平稳减速", duration: 90, repetitions: 5)
            ])
        }

        if focusAreas.contains(.technique) {
            exercises.append(contentsOf: [
                TrainingExercise(id: UUID(), name: "犁式转弯", description: "练习基础犁式转弯", duration: 180, repetitions: 10),
                TrainingExercise(id: UUID(), name: "平行转弯", description: "练习平行转弯技巧", duration: 120, repetitions: 8)
            ])
        }

        if focusAreas.contains(.endurance) {
            exercises.append(contentsOf: [
                TrainingExercise(id: UUID(), name: "节奏滑行", description: "保持均匀速度滑行", duration: 300, repetitions: 3)
            ])
        }

        let difficulty: TrainingPlan.Difficulty
        switch analysis.overallScore {
        case 0..<40: difficulty = .easy
        case 40..<70: difficulty = .medium
        default: difficulty = .hard
        }

        let totalDuration = exercises.reduce(0) { $0 + $1.duration * $1.repetitions } / 60

        return TrainingPlan(
            id: UUID(),
            title: "个性化训练计划",
            description: "根据您的滑雪分析生成的定制训练计划",
            duration: totalDuration,
            difficulty: difficulty,
            focusAreas: focusAreas,
            exercises: exercises
        )
    }
}