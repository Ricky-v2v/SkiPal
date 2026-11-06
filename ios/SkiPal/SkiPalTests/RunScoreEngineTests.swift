//
//  RunScoreEngineTests.swift
//  SkiPalTests
//
//  F1 滑行评分引擎单元测试
//
//  @Input      RunScoreEngine（@testable import SkiPal）、CLLocation 构造的 SkiLocation
//  @Output     F1 评分规则与边界（空轨迹、单点、异常速度、极短距离）的 XCTest 用例
//  @Pos        SkiPalTests target，PRD F1 的验收证据来源
//  @UpdateRule 评分规则变化时同步用例、此头与 SkiPalTests/README.md
//
//  测试策略：
//  - 通过 CLLocation 构造 SkiLocation，避免依赖模型的具体内存初始化器，保持与生产代码解耦。
//  - 逐条覆盖评分规则与四类边界：空轨迹、单点轨迹、异常速度脏点、极短距离。
//

import XCTest
import CoreLocation
@testable import SkiPal

final class RunScoreEngineTests: XCTestCase {

    // MARK: - 构造工具

    /// 以给定经纬度、海拔、速度、时间偏移构造一个 SkiLocation
    /// - Parameters:
    ///   - lat: 纬度
    ///   - lon: 经度
    ///   - altitude: 海拔（m）
    ///   - speed: 速度（m/s），负值表示 CLLocation 无效速度
    ///   - secondsOffset: 相对基准时间的秒偏移，用于拉开时长
    private func makeLocation(lat: Double,
                              lon: Double,
                              altitude: Double,
                              speed: Double,
                              secondsOffset: TimeInterval) -> SkiLocation {
        let base = Date(timeIntervalSince1970: 1_700_000_000)
        let cl = CLLocation(
            coordinate: CLLocationCoordinate2D(latitude: lat, longitude: lon),
            altitude: altitude,
            horizontalAccuracy: 5,
            verticalAccuracy: 5,
            course: 0,
            speed: speed,
            timestamp: base.addingTimeInterval(secondsOffset)
        )
        return SkiLocation(from: cl)
    }

    /// 构造一个包含若干点、首尾时间可控的会话
    private func makeSession(locations: [SkiLocation],
                            durationSeconds: TimeInterval) -> SkiSession {
        let start = Date(timeIntervalSince1970: 1_700_000_000)
        var session = SkiSession(startTime: start, locations: locations)
        session.endTime = start.addingTimeInterval(durationSeconds)
        return session
    }

    // MARK: - 边界一：空轨迹

    func testEmptyTrackIsUnreliableWithFallback() {
        let session = makeSession(locations: [], durationSeconds: 0)
        let result = RunScoreEngine.score(for: session)

        // 空轨迹必须判为不可靠，并给保底分
        XCTAssertFalse(result.isReliable, "空轨迹应判为不可靠")
        XCTAssertEqual(result.routeScore, RunScoreEngine.fallbackScore)
        XCTAssertEqual(result.rhythmScore, RunScoreEngine.fallbackScore)
        XCTAssertEqual(result.staminaScore, RunScoreEngine.fallbackScore)
        // 总分应在 0–100 之间，且等于保底分加权结果
        XCTAssertGreaterThanOrEqual(result.totalScore, 0)
        XCTAssertLessThanOrEqual(result.totalScore, 100)
        // 必须有三条建议，顺序为线路/节奏/体能
        XCTAssertEqual(result.advices.count, 3)
        XCTAssertEqual(result.advices[0].dimension, .route)
        XCTAssertEqual(result.advices[1].dimension, .rhythm)
        XCTAssertEqual(result.advices[2].dimension, .stamina)
        // 建议必须有标题与可执行动作
        for advice in result.advices {
            XCTAssertFalse(advice.title.isEmpty)
            XCTAssertFalse(advice.action.isEmpty)
        }
    }

    // MARK: - 边界二：单点轨迹

    func testSinglePointTrackIsUnreliable() {
        let single = makeLocation(lat: 40.30, lon: 116.62, altitude: 500, speed: 5, secondsOffset: 0)
        let session = makeSession(locations: [single], durationSeconds: 10)
        let result = RunScoreEngine.score(for: session)

        // 单点无法构成距离/速度曲线，必须判为不可靠
        XCTAssertFalse(result.isReliable, "单点轨迹应判为不可靠")
        XCTAssertEqual(result.routeScore, RunScoreEngine.fallbackScore)
    }

    // MARK: - 边界三：异常速度脏点被剔除

    func testAbnormalSpeedIsFilteredOut() {
        // 构造两个正常点 + 一个异常速度脏点（>30 m/s）
        let p1 = makeLocation(lat: 40.3000, lon: 116.6200, altitude: 520, speed: 8, secondsOffset: 0)
        let p2 = makeLocation(lat: 40.3030, lon: 116.6200, altitude: 500, speed: 10, secondsOffset: 30)
        // 脏点：速度 100 m/s（≈360 km/h），超过 maxValidSpeed，应被剔除，不污染最大速度
        let dirty = makeLocation(lat: 40.3031, lon: 116.6200, altitude: 499, speed: 100, secondsOffset: 31)

        let session = makeSession(locations: [p1, p2, dirty], durationSeconds: 600)
        let result = RunScoreEngine.score(for: session)

        XCTAssertTrue(result.isReliable, "存在两个以上有效点且距离足够，应可靠")

        // 节奏分基于清洗后的点：最大速度应为 10 而非 100。
        // 用仅含干净点的会话对比，节奏分应一致，证明脏点被剔除。
        let cleanSession = makeSession(locations: [p1, p2], durationSeconds: 600)
        let cleanResult = RunScoreEngine.score(for: cleanSession)
        XCTAssertEqual(result.rhythmScore, cleanResult.rhythmScore,
                       "异常速度脏点应被剔除，不应影响节奏分")
    }

    func testNegativeSpeedIsFilteredOut() {
        // CLLocation 速度为负表示无效；SkiLocation 会 clamp 到 0，引擎仍应接受为有效点
        let p1 = makeLocation(lat: 40.3000, lon: 116.6200, altitude: 520, speed: -1, secondsOffset: 0)
        let p2 = makeLocation(lat: 40.3030, lon: 116.6200, altitude: 500, speed: 9, secondsOffset: 30)
        let session = makeSession(locations: [p1, p2], durationSeconds: 300)
        let result = RunScoreEngine.score(for: session)
        // 两点均有效（speed 被 clamp 到 >=0），距离足够 → 可靠
        XCTAssertTrue(result.isReliable)
    }

    // MARK: - 边界四：极短距离

    func testVeryShortDistanceIsUnreliable() {
        // 两个几乎重合的点，总距离远小于 minValidDistance（20 m）
        let p1 = makeLocation(lat: 40.30000, lon: 116.62000, altitude: 500, speed: 3, secondsOffset: 0)
        let p2 = makeLocation(lat: 40.30001, lon: 116.62000, altitude: 500, speed: 3, secondsOffset: 5)
        let session = makeSession(locations: [p1, p2], durationSeconds: 5)

        // 先确认该距离确实小于阈值，保证用例有效
        XCTAssertLessThan(session.totalDistance, RunScoreEngine.minValidDistance)

        let result = RunScoreEngine.score(for: session)
        XCTAssertFalse(result.isReliable, "极短距离应判为不可靠")
    }

    // MARK: - 规则逐条验证：线路分

    func testRouteScoreZeroAndFull() {
        // 距离 0 → 线路分 0
        XCTAssertEqual(RunScoreEngine.routeScore(distance: 0), 0)
        // 距离 >= 封顶 → 线路分 100
        XCTAssertEqual(RunScoreEngine.routeScore(distance: RunScoreEngine.routeFullDistance), 100)
        XCTAssertEqual(RunScoreEngine.routeScore(distance: RunScoreEngine.routeFullDistance * 2), 100)
        // 半程 → 约 50 分
        XCTAssertEqual(RunScoreEngine.routeScore(distance: RunScoreEngine.routeFullDistance / 2), 50)
    }

    // MARK: - 规则逐条验证：节奏分

    func testRhythmScoreMonotonic() {
        // 平均/最大 比值达到理想值应满分
        let steady = [
            makeLocation(lat: 40.3, lon: 116.6, altitude: 500, speed: 6, secondsOffset: 0),
            makeLocation(lat: 40.3, lon: 116.6, altitude: 500, speed: 6, secondsOffset: 10)
        ]
        // 两点速度相同 → 平均/最大 = 1.0 >= 理想比值 → 满分 100
        XCTAssertEqual(RunScoreEngine.rhythmScore(locations: steady), 100)

        // 一高一低：平均/最大 比值较小 → 分数更低
        let jerky = [
            makeLocation(lat: 40.3, lon: 116.6, altitude: 500, speed: 1, secondsOffset: 0),
            makeLocation(lat: 40.3, lon: 116.6, altitude: 500, speed: 20, secondsOffset: 10)
        ]
        let jerkyScore = RunScoreEngine.rhythmScore(locations: jerky)
        XCTAssertLessThan(jerkyScore, 100, "忽快忽慢的节奏分应低于匀速")
        XCTAssertGreaterThanOrEqual(jerkyScore, 0)
    }

    // MARK: - 规则逐条验证：体能分

    func testStaminaScoreBounds() {
        // 时长 0、爬升 0 → 体能分 0
        XCTAssertEqual(RunScoreEngine.staminaScore(duration: 0, elevationGain: 0), 0)
        // 时长与爬升均封顶 → 体能分 100
        XCTAssertEqual(
            RunScoreEngine.staminaScore(
                duration: RunScoreEngine.staminaFullDuration,
                elevationGain: RunScoreEngine.staminaFullGain
            ),
            100
        )
        // 仅时长封顶（爬升 0）→ 约 50 分（时长占 50%）
        XCTAssertEqual(
            RunScoreEngine.staminaScore(
                duration: RunScoreEngine.staminaFullDuration,
                elevationGain: 0
            ),
            50
        )
    }

    // MARK: - 规则逐条验证：加权总分

    func testWeightedTotalIsWithinBounds() {
        // 全满分 → 总分 100
        XCTAssertEqual(RunScoreEngine.weightedTotal(route: 100, rhythm: 100, stamina: 100), 100)
        // 全 0 → 总分 0
        XCTAssertEqual(RunScoreEngine.weightedTotal(route: 0, rhythm: 0, stamina: 0), 0)
        // 混合值落在 0–100
        let mixed = RunScoreEngine.weightedTotal(route: 80, rhythm: 40, stamina: 60)
        XCTAssertGreaterThanOrEqual(mixed, 0)
        XCTAssertLessThanOrEqual(mixed, 100)
    }

    // MARK: - 端到端：典型一次滑行

    func testTypicalRunProducesReliableResult() {
        // 构造一条沿纬度拉开、海拔持续下降、速度均匀的滑行，保证距离/时长足够
        var locations: [SkiLocation] = []
        for i in 0..<20 {
            locations.append(
                makeLocation(
                    lat: 40.3000 + Double(i) * 0.0005, // 每点约 55 m，总距约 1 km
                    lon: 116.6200,
                    altitude: 600 - Double(i) * 5,
                    speed: 9 + Double(i % 3),          // 速度在 9–11 m/s 波动
                    secondsOffset: Double(i) * 60       // 总时长约 19 分钟
                )
            )
        }
        let session = makeSession(locations: locations, durationSeconds: 19 * 60)
        let result = RunScoreEngine.score(for: session)

        XCTAssertTrue(result.isReliable)
        XCTAssertEqual(result.advices.count, 3)
        XCTAssertGreaterThanOrEqual(result.totalScore, 0)
        XCTAssertLessThanOrEqual(result.totalScore, 100)
        // 各维度分均在合法区间
        for s in [result.routeScore, result.rhythmScore, result.staminaScore] {
            XCTAssertGreaterThanOrEqual(s, 0)
            XCTAssertLessThanOrEqual(s, 100)
        }
    }
}
