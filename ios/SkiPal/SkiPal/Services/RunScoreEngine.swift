//
//  RunScoreEngine.swift
//  SkiPal
//
//  F1 滑行评分引擎（纯逻辑，不依赖 UI）
//
//  @Input      SkiSession（locations 的速度/时间、distance、duration、elevationGain）
//  @Output     RunScoreEngine.score(for:) -> RunScoreResult（总分、三项分、三条 RunScoreAdvice）
//  @Pos        Services 层纯逻辑引擎，PRD F1；目前未接入任何视图
//  @UpdateRule 修改规则或接口时同步更新此头、Services/README.md 与 RunScoreEngineTests
//
//  设计目标：
//  - 输入一次滑行会话（SkiSession），输出 0–100 的本次评分、三个维度分（线路/节奏/体能）
//    以及三条可执行建议（线路 / 节奏 / 体能 各一条）。
//  - 全部为纯函数式计算，便于在没有真机的情况下被单元测试逐条验证。
//  - 所有速度单位统一按「米/秒（m/s）」处理，与 SkiLocation.speed（来自 CLLocation.speed）一致。
//

import Foundation

// MARK: - 输出结构

/// 单条可执行建议：包含标题与具体可执行动作
struct RunScoreAdvice: Equatable {
    /// 建议维度
    enum Dimension: String, Equatable {
        case route = "线路"
        case rhythm = "节奏"
        case stamina = "体能"
    }

    /// 所属维度
    let dimension: Dimension
    /// 建议标题（一句话结论）
    let title: String
    /// 具体可执行动作（告诉用户下一次该怎么做）
    let action: String
}

/// 滑行评分结果
struct RunScoreResult: Equatable {
    /// 总分（0–100，四舍五入为整数）
    let totalScore: Int
    /// 线路维度分（0–100）
    let routeScore: Int
    /// 节奏维度分（0–100）
    let rhythmScore: Int
    /// 体能维度分（0–100）
    let staminaScore: Int
    /// 三条可执行建议（顺序固定：线路、节奏、体能）
    let advices: [RunScoreAdvice]
    /// 本次评分是否基于有效数据得出
    /// - 空轨迹 / 单点轨迹 / 清洗后有效点不足时为 false，此时各维度给保底分
    let isReliable: Bool
}

// MARK: - 评分引擎

/// 滑行评分引擎
///
/// 评分规则总览（可被单元测试逐条验证）：
///
/// 一、数据清洗
///   - 剔除速度为负或超过 `maxValidSpeed`（默认 30 m/s）的「脏点」；
///     30 m/s ≈ 108 km/h，超过视为 GPS 异常跳点，不参与速度相关计算。
///
/// 二、可靠性判定（isReliable）
///   - 有效定位点 < 2，或总距离 < `minValidDistance`（默认 20 m）时判为不可靠；
///   - 不可靠时三个维度分统一给保底分 `fallbackScore`（默认 30），总分按权重计算，
///     并给出「数据不足」类的保守建议。
///
/// 三、线路分（routeScore，权重见 weightRoute）
///   - 基于有效距离：距离越长，线路分越高（线性映射到 0–100，`routeFullDistance` 封顶）。
///   - 距离 >= `routeFullDistance`（默认 3000 m）得满分 100；距离为 0 得 0 分。
///
/// 四、节奏分（rhythmScore，权重见 weightRhythm）
///   - 衡量速度的平稳度：用「平均速度 / 最大速度」的比值反映节奏是否均匀。
///     比值越接近理想区间，节奏分越高。
///   - 比值 >= `rhythmIdealRatio`（默认 0.6）得满分；比值 <= 0 得 0 分，中间线性映射。
///
/// 五、体能分（staminaScore，权重见 weightStamina）
///   - 综合「时长」与「累计爬升」：时长越长、爬升越多，体能投入越大。
///   - 时长映射：>= `staminaFullDuration`（默认 1800 s = 30 min）封顶；
///     爬升映射：>= `staminaFullGain`（默认 300 m）封顶；两者各占 50%。
///
/// 六、总分
///   - totalScore = round(routeScore*weightRoute + rhythmScore*weightRhythm + staminaScore*weightStamina)
///   - 默认权重：线路 0.35、节奏 0.35、体能 0.30，三者之和为 1。
///
enum RunScoreEngine {

    // MARK: - 可调参数（集中管理，便于测试对齐规则）

    /// 判定脏点的最大有效速度（m/s）。>30 m/s（≈108 km/h）视为 GPS 跳点
    static let maxValidSpeed: Double = 30.0
    /// 判定会话可靠所需的最小总距离（m）
    static let minValidDistance: Double = 20.0
    /// 不可靠数据时各维度的保底分
    static let fallbackScore: Int = 30

    /// 线路分封顶距离（m）：达到即满分
    static let routeFullDistance: Double = 3000.0
    /// 节奏分理想比值（平均速度 / 最大速度）：达到即满分
    static let rhythmIdealRatio: Double = 0.6
    /// 体能分时长封顶（s）
    static let staminaFullDuration: Double = 1800.0
    /// 体能分爬升封顶（m）
    static let staminaFullGain: Double = 300.0

    /// 权重（三者之和应为 1）
    static let weightRoute: Double = 0.35
    static let weightRhythm: Double = 0.35
    static let weightStamina: Double = 0.30

    // MARK: - 对外主入口

    /// 对一次滑行会话评分
    /// - Parameter session: 待评分的滑行会话
    /// - Returns: 评分结果（总分、三维度分、三条建议、可靠性）
    static func score(for session: SkiSession) -> RunScoreResult {
        // 1) 清洗脏点：只保留速度在 [0, maxValidSpeed] 的点
        let cleanLocations = session.locations.filter { loc in
            loc.speed >= 0 && loc.speed <= maxValidSpeed
        }

        // 2) 可靠性判定：有效点 < 2 或总距离过短 → 不可靠
        let distance = session.totalDistance
        let reliable = cleanLocations.count >= 2 && distance >= minValidDistance

        guard reliable else {
            return unreliableResult()
        }

        // 3) 计算三维度分
        let route = routeScore(distance: distance)
        let rhythm = rhythmScore(locations: cleanLocations)
        let stamina = staminaScore(duration: session.duration,
                                   elevationGain: session.elevationGain)

        // 4) 加权总分
        let total = weightedTotal(route: route, rhythm: rhythm, stamina: stamina)

        // 5) 建议
        let advices = [
            routeAdvice(score: route, distance: distance),
            rhythmAdvice(score: rhythm),
            staminaAdvice(score: stamina, duration: session.duration)
        ]

        return RunScoreResult(
            totalScore: total,
            routeScore: route,
            rhythmScore: rhythm,
            staminaScore: stamina,
            advices: advices,
            isReliable: true
        )
    }

    // MARK: - 维度分计算（纯函数）

    /// 线路分：距离线性映射到 0–100，routeFullDistance 封顶
    static func routeScore(distance: Double) -> Int {
        guard distance > 0 else { return 0 }
        let ratio = min(distance / routeFullDistance, 1.0)
        return clampScore(ratio * 100.0)
    }

    /// 节奏分：平均速度 / 最大速度 的比值，rhythmIdealRatio 封顶
    static func rhythmScore(locations: [SkiLocation]) -> Int {
        let speeds = locations.map { $0.speed }
        guard let maxSpeed = speeds.max(), maxSpeed > 0 else { return 0 }
        let avgSpeed = speeds.reduce(0, +) / Double(speeds.count)
        let ratio = avgSpeed / maxSpeed // 理论范围 (0, 1]
        let normalized = min(ratio / rhythmIdealRatio, 1.0)
        return clampScore(normalized * 100.0)
    }

    /// 体能分：时长与爬升各占 50%，分别封顶后合成
    static func staminaScore(duration: Double, elevationGain: Double) -> Int {
        let durationRatio = max(0, min(duration / staminaFullDuration, 1.0))
        let gainRatio = max(0, min(elevationGain / staminaFullGain, 1.0))
        let combined = durationRatio * 0.5 + gainRatio * 0.5
        return clampScore(combined * 100.0)
    }

    /// 加权总分（四舍五入为整数，钳制到 0–100）
    static func weightedTotal(route: Int, rhythm: Int, stamina: Int) -> Int {
        let raw = Double(route) * weightRoute
            + Double(rhythm) * weightRhythm
            + Double(stamina) * weightStamina
        return clampScore(raw)
    }

    // MARK: - 建议生成（纯函数）

    /// 线路建议
    static func routeAdvice(score: Int, distance: Double) -> RunScoreAdvice {
        if score >= 80 {
            return RunScoreAdvice(
                dimension: .route,
                title: "线路里程充足，保持路线规划",
                action: "下次尝试在同一条雪道上串联更多转弯，用轨迹回放检查是否走了多余的直线。"
            )
        } else if score >= 50 {
            return RunScoreAdvice(
                dimension: .route,
                title: "线路里程中等，可延长单次滑行",
                action: "选择更长的雪道或减少中途停留，把单次下滑距离提升到 3 公里以上。"
            )
        } else {
            return RunScoreAdvice(
                dimension: .route,
                title: "线路偏短，建议完整滑完一条道",
                action: "从山顶一次性滑到山脚不中途下缆车，先把单次里程稳定在 1 公里以上。"
            )
        }
    }

    /// 节奏建议
    static func rhythmAdvice(score: Int) -> RunScoreAdvice {
        if score >= 80 {
            return RunScoreAdvice(
                dimension: .rhythm,
                title: "节奏均匀，速度控制稳定",
                action: "保持当前的匀速转弯节奏，可在缓坡尝试加入有规律的加减速练习提升控制力。"
            )
        } else if score >= 50 {
            return RunScoreAdvice(
                dimension: .rhythm,
                title: "节奏一般，存在明显忽快忽慢",
                action: "刻意用相同的转弯半径连续做 10 个弯，避免在直线段一次性冲到最高速。"
            )
        } else {
            return RunScoreAdvice(
                dimension: .rhythm,
                title: "节奏不稳，急加速急刹车较多",
                action: "在中级道上练习『匀速落叶飘』，用刻意减速把平均速度与最高速的差距缩小。"
            )
        }
    }

    /// 体能建议
    static func staminaAdvice(score: Int, duration: Double) -> RunScoreAdvice {
        if score >= 80 {
            return RunScoreAdvice(
                dimension: .stamina,
                title: "体能投入充足，续航良好",
                action: "注意补水与拉伸，下次可在同等时长下增加一条黑道挑战爬升与强度。"
            )
        } else if score >= 50 {
            return RunScoreAdvice(
                dimension: .stamina,
                title: "体能投入中等，可逐步加量",
                action: "每次多滑 2 趟或延长 10 分钟滑行，循序渐进提升单次运动时长与爬升。"
            )
        } else {
            return RunScoreAdvice(
                dimension: .stamina,
                title: "本次运动量偏小",
                action: "先以 20–30 分钟的持续滑行为目标，滑前做好热身，避免一上来就高强度。"
            )
        }
    }

    // MARK: - 不可靠数据的保底结果

    /// 空轨迹 / 单点 / 极短距离等不可靠场景的保底结果
    private static func unreliableResult() -> RunScoreResult {
        let base = fallbackScore
        let total = weightedTotal(route: base, rhythm: base, stamina: base)
        let advices = [
            RunScoreAdvice(
                dimension: .route,
                title: "本次轨迹数据不足，暂无法评估线路",
                action: "确认定位权限已开启，开始滑雪后保持 App 在前台或后台持续记录。"
            ),
            RunScoreAdvice(
                dimension: .rhythm,
                title: "采样点太少，暂无法评估节奏",
                action: "完整滑完至少一条雪道再结束记录，确保采集到连续的速度曲线。"
            ),
            RunScoreAdvice(
                dimension: .stamina,
                title: "运动量过小或记录过短",
                action: "下次记录一段完整滑行（建议 20 米以上、两个以上有效定位点）再查看评分。"
            )
        ]
        return RunScoreResult(
            totalScore: total,
            routeScore: base,
            rhythmScore: base,
            staminaScore: base,
            advices: advices,
            isReliable: false
        )
    }

    // MARK: - 工具

    /// 将浮点分数四舍五入并钳制到 [0, 100] 的整数
    private static func clampScore(_ value: Double) -> Int {
        let rounded = Int(value.rounded())
        return max(0, min(100, rounded))
    }
}
