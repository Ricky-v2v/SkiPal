//
//  AICoachService.swift
//  SkiPal
//
//  AI 教练分析服务 - 分析滑雪数据并提供改进建议
//

import Foundation
import Combine

/// 教练分析结果
struct CoachAnalysis: Identifiable, Codable {
    let id: UUID
    let sessionId: UUID?
    let timestamp: Date
    let overallScore: Int  // 0-100
    let speedAnalysis: SpeedAnalysis
    let techniqueAnalysis: TechniqueAnalysis
    let improvementSuggestions: [ImprovementSuggestion]
    let comparisonWithHistory: HistoryComparison?

    init(
        sessionId: UUID? = nil,
        overallScore: Int,
        speedAnalysis: SpeedAnalysis,
        techniqueAnalysis: TechniqueAnalysis,
        suggestions: [ImprovementSuggestion],
        comparison: HistoryComparison? = nil
    ) {
        self.id = UUID()
        self.sessionId = sessionId
        self.timestamp = Date()
        self.overallScore = overallScore
        self.speedAnalysis = speedAnalysis
        self.techniqueAnalysis = techniqueAnalysis
        self.improvementSuggestions = suggestions
        self.comparisonWithHistory = comparison
    }
}

/// 速度分析
struct SpeedAnalysis: Codable {
    let averageSpeed: Double  // km/h
    let maxSpeed: Double  // km/h
    let speedConsistency: Double  // 0-100 速度一致性
    let speedDistribution: SpeedDistribution
    let speedTrend: SpeedTrend
    let speedScore: Int  // 0-100

    /// 速度分布
    struct SpeedDistribution: Codable {
        var slow: Int  // 0-20 km/h 百分比
        var moderate: Int  // 20-40 km/h 百分比
        var fast: Int  // 40-60 km/h 百分比
        var veryFast: Int  // 60+ km/h 百分比
    }

    /// 速度趋势
    enum SpeedTrend: String, Codable {
        case accelerating = "加速中"
        case steady = "稳定"
        case declining = "减速"
        case variable = "多变"
    }
}

/// 技术分析
struct TechniqueAnalysis: Codable {
    let smoothnessScore: Int  // 0-100 平滑度
    let turnAnalysis: TurnAnalysis
    let slopeHandling: SlopeHandling
    let controlScore: Int  // 0-100 控制力
    let techniqueScore: Int  // 0-100 总分

    /// 转弯分析
    struct TurnAnalysis: Codable {
        var estimatedTurns: Int
        var averageTurnInterval: TimeInterval  // 秒
        var turnSmoothness: Double  // 0-100
    }

    /// 坡度处理
    struct SlopeHandling: Codable {
        var beginnerPercentage: Int
        var intermediatePercentage: Int
        var advancedPercentage: Int
        var expertPercentage: Int
        var comfortLevel: ComfortLevel
    }

    /// 舒适度等级
    enum ComfortLevel: String, Codable {
        case comfortable = "舒适"
        case moderate = "中等"
        case challenging = "有挑战"
        case difficult = "困难"
    }
}

/// 改进建议
struct ImprovementSuggestion: Identifiable, Codable {
    let id: UUID
    let category: SuggestionCategory
    let priority: Priority
    let title: String
    let description: String
    let actionableTip: String
    let relatedMetric: String?

    init(
        category: SuggestionCategory,
        priority: Priority,
        title: String,
        description: String,
        tip: String,
        metric: String? = nil
    ) {
        self.id = UUID()
        self.category = category
        self.priority = priority
        self.title = title
        self.description = description
        self.actionableTip = tip
        self.relatedMetric = metric
    }

    enum SuggestionCategory: String, Codable {
        case speed = "速度控制"
        case technique = "滑行技术"
        case safety = "安全建议"
        case endurance = "耐力提升"
        case equipment = "装备建议"
    }

    enum Priority: String, Codable {
        case high = "重要"
        case medium = "建议"
        case low = "提示"
    }
}

/// 历史对比
struct HistoryComparison: Codable {
    let isPersonalRecord: Bool
    let speedImprovement: Double?  // 相比上次提升百分比
    let distanceImprovement: Double?
    let techniqueTrend: TechniqueTrend
    let sessionsCompared: Int

    enum TechniqueTrend: String, Codable {
        case improving = "进步中"
        case stable = "稳定"
        case declining = "需要加强"
    }
}

/// AI 教练服务
class AICoachService: ObservableObject {
    static let shared = AICoachService()

    // 发布属性
    @Published private(set) var currentAnalysis: CoachAnalysis?
    @Published private(set) var isAnalyzing = false
    @Published private(set) var recentAnalyses: [CoachAnalysis] = []

    // 历史数据引用
    weak var sessionStore: SkiSessionStore?

    // 缓存
    private var analysisCache: [UUID: CoachAnalysis] = [:]
    private let maxCacheSize = 50

    private init() {
        loadRecentAnalyses()
    }

    // MARK: - 分析方法

    /// 分析单个会话
    func analyzeSession(_ session: SkiSession) async -> CoachAnalysis {
        // 检查缓存
        if let cached = analysisCache[session.id] {
            return cached
        }

        return await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                guard let self = self else { return }

                let analysis = self.performAnalysis(session)
                self.analysisCache[session.id] = analysis

                // 限制缓存大小
                if self.analysisCache.count > self.maxCacheSize {
                    let oldestKey = self.analysisCache.keys.sorted { key1, key2 in
                        (self.analysisCache[key1]?.timestamp ?? Date.distantPast) <
                        (self.analysisCache[key2]?.timestamp ?? Date.distantPast)
                    }.first
                    if let key = oldestKey {
                        self.analysisCache.removeValue(forKey: key)
                    }
                }

                continuation.resume(returning: analysis)
            }
        }
    }

    /// 分析并更新当前分析
    func analyzeAndUpdate(_ session: SkiSession) {
        Task { @MainActor in
            isAnalyzing = true

            let analysis = await analyzeSession(session)

            self.currentAnalysis = analysis
            self.isAnalyzing = false

            // 保存到最近分析
            if !recentAnalyses.contains(where: { $0.sessionId == session.id }) {
                recentAnalyses.insert(analysis, at: 0)
                if recentAnalyses.count > 20 {
                    recentAnalyses.removeLast()
                }
                saveRecentAnalyses()
            }
        }
    }

    /// 获取历史对比
    func getHistoryComparison(for session: SkiSession) -> HistoryComparison? {
        guard let store = sessionStore, store.sessions.count > 1 else {
            return nil
        }

        let otherSessions = store.sessions.filter { $0.id != session.id }
        let recentSessions = Array(otherSessions.prefix(5))

        // 对比速度
        let avgSpeed = recentSessions.map { $0.averageSpeed }.reduce(0, +) / Double(max(recentSessions.count, 1))
        let speedImprovement = ((session.averageSpeed - avgSpeed) / avgSpeed) * 100

        // 对比距离
        let avgDistance = recentSessions.map { $0.totalDistance }.reduce(0, +) / Double(max(recentSessions.count, 1))
        let distanceImprovement = ((session.totalDistance - avgDistance) / avgDistance) * 100

        // 判断是否破纪录
        let isPersonalRecord = session.maxSpeed >= (store.personalBestSpeed ?? 0) ||
                               session.totalDistance >= (store.longestDistance ?? 0)

        // 判断趋势
        let trend: HistoryComparison.TechniqueTrend
        if speedImprovement > 5 || distanceImprovement > 10 {
            trend = .improving
        } else if speedImprovement < -10 || distanceImprovement < -10 {
            trend = .declining
        } else {
            trend = .stable
        }

        return HistoryComparison(
            isPersonalRecord: isPersonalRecord,
            speedImprovement: speedImprovement,
            distanceImprovement: distanceImprovement,
            techniqueTrend: trend,
            sessionsCompared: recentSessions.count
        )
    }

    // MARK: - 私有分析方法

    private func performAnalysis(_ session: SkiSession) -> CoachAnalysis {
        let speedAnalysis = analyzeSpeed(session)
        let techniqueAnalysis = analyzeTechnique(session)
        let suggestions = generateSuggestions(session, speed: speedAnalysis, technique: techniqueAnalysis)
        let comparison = getHistoryComparison(for: session)

        // 计算总分
        let overallScore = calculateOverallScore(
            speed: speedAnalysis.speedScore,
            technique: techniqueAnalysis.techniqueScore,
            distance: session.totalDistance,
            duration: session.duration
        )

        return CoachAnalysis(
            sessionId: session.id,
            overallScore: overallScore,
            speedAnalysis: speedAnalysis,
            techniqueAnalysis: techniqueAnalysis,
            suggestions: suggestions,
            comparison: comparison
        )
    }

    private func analyzeSpeed(_ session: SkiSession) -> SpeedAnalysis {
        let locations = session.locations
        guard !locations.isEmpty else {
            return SpeedAnalysis(
                averageSpeed: 0,
                maxSpeed: 0,
                speedConsistency: 0,
                speedDistribution: .init(slow: 0, moderate: 0, fast: 0, veryFast: 0),
                speedTrend: .steady,
                speedScore: 0
            )
        }

        // 转换速度为 km/h
        let speedsKmh = locations.map { $0.speed * 3.6 }
        let avgSpeed = speedsKmh.reduce(0, +) / Double(speedsKmh.count)
        let maxSpeed = speedsKmh.max() ?? 0

        // 计算速度一致性（标准差越小越一致）
        let speedVariance = speedsKmh.reduce(0) { $0 + pow($1 - avgSpeed, 2) } / Double(speedsKmh.count)
        let speedStdDev = sqrt(speedVariance)
        let consistency = max(0, min(100, 100 - (speedStdDev / avgSpeed) * 50))

        // 速度分布
        var slow = 0, moderate = 0, fast = 0, veryFast = 0
        for speed in speedsKmh {
            switch speed {
            case ..<20: slow += 1
            case 20..<40: moderate += 1
            case 40..<60: fast += 1
            default: veryFast += 1
            }
        }
        let total = Double(speedsKmh.count)
        let distribution = SpeedAnalysis.SpeedDistribution(
            slow: Int(Double(slow) / total * 100),
            moderate: Int(Double(moderate) / total * 100),
            fast: Int(Double(fast) / total * 100),
            veryFast: Int(Double(veryFast) / total * 100)
        )

        // 速度趋势
        let trend = determineSpeedTrend(speeds: speedsKmh)

        // 速度评分
        let speedScore = calculateSpeedScore(avgSpeed: avgSpeed, maxSpeed: maxSpeed, consistency: consistency)

        return SpeedAnalysis(
            averageSpeed: avgSpeed,
            maxSpeed: maxSpeed,
            speedConsistency: consistency,
            speedDistribution: distribution,
            speedTrend: trend,
            speedScore: speedScore
        )
    }

    private func analyzeTechnique(_ session: SkiSession) -> TechniqueAnalysis {
        let locations = session.locations
        guard locations.count >= 2 else {
            return TechniqueAnalysis(
                smoothnessScore: 0,
                turnAnalysis: .init(estimatedTurns: 0, averageTurnInterval: 0, turnSmoothness: 0),
                slopeHandling: .init(
                    beginnerPercentage: 0,
                    intermediatePercentage: 0,
                    advancedPercentage: 0,
                    expertPercentage: 0,
                    comfortLevel: .moderate
                ),
                controlScore: 0,
                techniqueScore: 0
            )
        }

        // 计算平滑度（基于方向变化）
        let smoothness = calculateSmoothness(locations: locations)

        // 转弯分析
        let turns = estimateTurns(locations: locations)

        // 坡度处理分析
        let slopeHandling = analyzeSlopeHandling(session)

        // 控制力评分
        let controlScore = calculateControlScore(smoothness: smoothness, turns: turns)

        // 综合技术评分
        let techniqueScore = (smoothness + controlScore) / 2

        return TechniqueAnalysis(
            smoothnessScore: smoothness,
            turnAnalysis: turns,
            slopeHandling: slopeHandling,
            controlScore: controlScore,
            techniqueScore: techniqueScore
        )
    }

    private func determineSpeedTrend(speeds: [Double]) -> SpeedAnalysis.SpeedTrend {
        guard speeds.count >= 10 else { return .steady }

        let firstHalf = Array(speeds.prefix(speeds.count / 2))
        let secondHalf = Array(speeds.suffix(speeds.count / 2))

        let firstAvg = firstHalf.reduce(0, +) / Double(firstHalf.count)
        let secondAvg = secondHalf.reduce(0, +) / Double(secondHalf.count)

        let change = (secondAvg - firstAvg) / firstAvg * 100

        if change > 10 { return .accelerating }
        if change < -10 { return .declining }

        // 检查多变性
        let variance = speeds.reduce(0) { $0 + pow($1 - (speeds.reduce(0, +) / Double(speeds.count)), 2) }
        let stdDev = sqrt(variance / Double(speeds.count))

        if stdDev > 15 { return .variable }

        return .steady
    }

    private func calculateSpeedScore(avgSpeed: Double, maxSpeed: Double, consistency: Double) -> Int {
        // 平均速度评分 (最高 40 分)
        let avgScore: Double
        switch avgSpeed {
        case ..<10: avgScore = 10
        case 10..<20: avgScore = 20
        case 20..<30: avgScore = 30
        case 30..<40: avgScore = 35
        default: avgScore = 40
        }

        // 最高速度评分 (最高 30 分)
        let maxScore: Double
        switch maxSpeed {
        case ..<20: maxScore = 10
        case 20..<40: maxScore = 20
        case 40..<60: maxScore = 25
        default: maxScore = 30
        }

        // 一致性评分 (最高 30 分)
        let consistencyScore = consistency * 0.3

        return Int(avgScore + maxScore + consistencyScore)
    }

    private func calculateSmoothness(locations: [SkiLocation]) -> Int {
        guard locations.count >= 3 else { return 50 }

        var directionChanges: [Double] = []

        for i in 2..<locations.count {
            let prev = locations[i - 1]
            let curr = locations[i]
            let next = locations[i]

            // 计算方向变化
            let angle1 = atan2(curr.latitude - prev.latitude, curr.longitude - prev.longitude)
            let angle2 = atan2(next.latitude - curr.latitude, next.longitude - curr.longitude)
            let angleChange = abs(angle2 - angle1)
            directionChanges.append(angleChange)
        }

        // 计算方向变化的方差
        let avgChange = directionChanges.reduce(0, +) / Double(directionChanges.count)
        let variance = directionChanges.reduce(0) { $0 + pow($1 - avgChange, 2) } / Double(directionChanges.count)

        // 方差越小，平滑度越高
        let smoothness = max(0, min(100, 100 - sqrt(variance) * 50))

        return Int(smoothness)
    }

    private func estimateTurns(locations: [SkiLocation]) -> TechniqueAnalysis.TurnAnalysis {
        guard locations.count >= 3 else {
            return TechniqueAnalysis.TurnAnalysis(estimatedTurns: 0, averageTurnInterval: 0, turnSmoothness: 0)
        }

        var turns: [(index: Int, time: Date)] = []
        var lastSign = 0

        for i in 1..<locations.count {
            let prev = locations[i - 1]
            let curr = locations[i]

            // 使用航向检测转弯
            let courseDiff = curr.course - prev.course
            let normalizedDiff = courseDiff > 180 ? courseDiff - 360 : (courseDiff < -180 ? courseDiff + 360 : courseDiff)
            let currentSign = normalizedDiff > 0 ? 1 : -1

            // 检测显著方向变化
            if abs(normalizedDiff) > 30 && currentSign != lastSign {
                turns.append((index: i, time: curr.timestamp))
                lastSign = currentSign
            }
        }

        // 计算转弯间隔
        var avgInterval: TimeInterval = 0
        if turns.count >= 2 {
            var intervals: [TimeInterval] = []
            for i in 1..<turns.count {
                intervals.append(turns[i].time.timeIntervalSince(turns[i - 1].time))
            }
            avgInterval = intervals.reduce(0, +) / TimeInterval(intervals.count)
        }

        return TechniqueAnalysis.TurnAnalysis(
            estimatedTurns: turns.count,
            averageTurnInterval: avgInterval,
            turnSmoothness: Double(max(0, 100 - turns.count))
        )
    }

    private func analyzeSlopeHandling(_ session: SkiSession) -> TechniqueAnalysis.SlopeHandling {
        let locations = session.locations
        guard !locations.isEmpty else {
            return TechniqueAnalysis.SlopeHandling(
                beginnerPercentage: 0,
                intermediatePercentage: 0,
                advancedPercentage: 0,
                expertPercentage: 0,
                comfortLevel: .moderate
            )
        }

        // 统计各级坡度时间
        var beginner = 0, intermediate = 0, advanced = 0, expert = 0

        for i in 1..<locations.count {
            let slope = abs(calculateSlope(from: locations[i - 1], to: locations[i]))
            switch slope {
            case 0..<15: beginner += 1
            case 15..<30: intermediate += 1
            case 30..<40: advanced += 1
            default: expert += 1
            }
        }

        let total = Double(locations.count - 1)
        let handling = TechniqueAnalysis.SlopeHandling(
            beginnerPercentage: Int(Double(beginner) / total * 100),
            intermediatePercentage: Int(Double(intermediate) / total * 100),
            advancedPercentage: Int(Double(advanced) / total * 100),
            expertPercentage: Int(Double(expert) / total * 100),
            comfortLevel: determineComfortLevel(
                advanced: advanced,
                expert: expert,
                total: Int(total)
            )
        )

        return handling
    }

    private func calculateSlope(from: SkiLocation, to: SkiLocation) -> Double {
        let horizontalDistance = from.location.distance(from: to.location)
        guard horizontalDistance > 0 else { return 0 }
        let elevationDiff = to.altitude - from.altitude
        return atan(elevationDiff / horizontalDistance) * 180 / .pi
    }

    private func determineComfortLevel(advanced: Int, expert: Int, total: Int) -> TechniqueAnalysis.ComfortLevel {
        guard total > 0 else { return .moderate }
        let difficultPercentage = Double(advanced + expert) / Double(total) * 100

        switch difficultPercentage {
        case 0..<10: return .comfortable
        case 10..<30: return .moderate
        case 30..<50: return .challenging
        default: return .difficult
        }
    }

    private func calculateControlScore(smoothness: Int, turns: TechniqueAnalysis.TurnAnalysis) -> Int {
        // 基于平滑度和转弯质量
        let smoothnessWeight = 0.6
        let turnWeight = 0.4

        let turnScore = min(100, turns.turnSmoothness)

        return Int(Double(smoothness) * smoothnessWeight + Double(turnScore) * turnWeight)
    }

    private func calculateOverallScore(speed: Int, technique: Int, distance: Double, duration: TimeInterval) -> Int {
        // 速度权重 40%，技术权重 40%，持久度权重 20%
        let speedWeight = 0.4
        let techniqueWeight = 0.4
        let enduranceWeight = 0.2

        // 持久度评分
        let durationMinutes = duration / 60
        let enduranceScore: Double
        switch durationMinutes {
        case ..<15: enduranceScore = 40
        case 15..<30: enduranceScore = 60
        case 30..<60: enduranceScore = 80
        case 60..<120: enduranceScore = 90
        default: enduranceScore = 100
        }

        let distanceKm = distance / 1000
        let distanceBonus = min(10, Int(distanceKm))  // 最多加 10 分

        let baseScore = Double(speed) * speedWeight +
                        Double(technique) * techniqueWeight +
                        enduranceScore * enduranceWeight

        return min(100, Int(baseScore) + distanceBonus)
    }

    // MARK: - 建议生成

    private func generateSuggestions(
        _ session: SkiSession,
        speed: SpeedAnalysis,
        technique: TechniqueAnalysis
    ) -> [ImprovementSuggestion] {
        var suggestions: [ImprovementSuggestion] = []

        // 速度相关建议
        if speed.averageSpeed < 15 {
            suggestions.append(ImprovementSuggestion(
                category: .speed,
                priority: .medium,
                title: "提升滑行速度",
                description: "你的平均速度较低，可以尝试更自信地滑行",
                tip: "保持重心前倾，用小腿压住雪鞋，减少制动滑行",
                metric: "平均速度: \(String(format: "%.1f", speed.averageSpeed)) km/h"
            ))
        }

        if speed.speedConsistency < 50 {
            suggestions.append(ImprovementSuggestion(
                category: .technique,
                priority: .high,
                title: "保持速度稳定",
                description: "你的速度波动较大，这会影响滑行效率",
                tip: "尝试保持稳定的滑行节奏，避免频繁刹车和加速",
                metric: "速度一致性: \(speed.speedConsistency)%"
            ))
        }

        // 技术相关建议
        if technique.smoothnessScore < 60 {
            suggestions.append(ImprovementSuggestion(
                category: .technique,
                priority: .high,
                title: "改善滑行平滑度",
                description: "你的滑行轨迹有较多颠簸，可以更加流畅",
                tip: "膝盖保持微曲，吸收地形起伏，上身保持稳定",
                metric: "平滑度: \(technique.smoothnessScore)分"
            ))
        }

        if technique.turnAnalysis.estimatedTurns > 50 && session.duration < 1800 {
            suggestions.append(ImprovementSuggestion(
                category: .technique,
                priority: .medium,
                title: "优化转弯频率",
                description: "转弯过于频繁可能影响滑行效率",
                tip: "选择更长的弧线转弯，减少不必要的短转弯",
                metric: "转弯次数: \(technique.turnAnalysis.estimatedTurns)"
            ))
        }

        // 坡度相关建议
        let expertPercent = technique.slopeHandling.expertPercentage
        if expertPercent > 30 {
            suggestions.append(ImprovementSuggestion(
                category: .safety,
                priority: .high,
                title: "注意高级道安全",
                description: "你在高难度坡道上花费较多时间，请确保安全",
                tip: "确保佩戴护具，结伴滑行，选择合适雪况",
                metric: "高级道占比: \(expertPercent)%"
            ))
        }

        // 耐力相关建议
        let durationMinutes = session.duration / 60
        if durationMinutes < 30 {
            suggestions.append(ImprovementSuggestion(
                category: .endurance,
                priority: .low,
                title: "增加滑行时长",
                description: "延长滑行时间可以提升体能和技巧",
                tip: "合理安排休息，保持充足水分和能量补充",
                metric: "滑行时长: \(Int(durationMinutes))分钟"
            ))
        }

        // 距离相关建议
        let distanceKm = session.totalDistance / 1000
        if distanceKm > 15 {
            suggestions.append(ImprovementSuggestion(
                category: .endurance,
                priority: .medium,
                title: "注意体能分配",
                description: "长距离滑行需要注意体力管理",
                tip: "前半程控制速度，保留体力应对后半程",
                metric: "滑行距离: \(String(format: "%.1f", distanceKm)) km"
            ))
        }

        // 按优先级排序
        return suggestions.sorted { $0.priority.rawValue < $1.priority.rawValue }
    }

    // MARK: - 持久化

    private func loadRecentAnalyses() {
        guard let data = UserDefaults.standard.data(forKey: "recentCoachAnalyses"),
              let analyses = try? JSONDecoder().decode([CoachAnalysis].self, from: data) else {
            return
        }
        recentAnalyses = analyses
    }

    private func saveRecentAnalyses() {
        guard let data = try? JSONEncoder().encode(recentAnalyses) else { return }
        UserDefaults.standard.set(data, forKey: "recentCoachAnalyses")
    }

    /// 清除缓存
    func clearCache() {
        analysisCache.removeAll()
    }
}

// MARK: - 分析扩展
extension CoachAnalysis {
    /// 评分等级描述
    var scoreLevel: String {
        switch overallScore {
        case 0..<20: return "初学者"
        case 20..<40: return "入门级"
        case 40..<60: return "中级"
        case 60..<80: return "高级"
        case 80..<90: return "专业级"
        default: return "大师级"
        }
    }

    /// 评分颜色
    var scoreColor: String {
        switch overallScore {
        case 0..<40: return "#FF3B30"  // 红色
        case 40..<60: return "#FF9500"  // 橙色
        case 60..<80: return "#34C759"  // 绿色
        default: return "#007AFF"  // 蓝色
        }
    }
}
