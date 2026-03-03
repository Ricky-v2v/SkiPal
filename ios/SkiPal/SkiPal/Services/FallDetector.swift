//
//  FallDetector.swift
//  SkiPal
//
//  摔倒检测服务 - 使用 CoreMotion 检测滑雪摔倒事件
//

import Foundation
import CoreMotion
import Combine
import UIKit
import AudioToolbox

/// 摔倒检测结果
struct FallEvent: Identifiable {
    let id = UUID()
    let timestamp: Date
    let impactMagnitude: Double
    let location: FallLocation?
    var confirmed: Bool = false
    var userResponse: FallResponse?
}

/// 摔倒位置（如果可用）
struct FallLocation: Codable {
    let latitude: Double
    let longitude: Double
    let altitude: Double
}

/// 用户响应类型
enum FallResponse {
    case imOkay      // 用户确认没事
    case needHelp    // 用户需要帮助
    case noResponse  // 用户无响应
}

/// 摔倒检测状态
enum FallDetectionState: Equatable {
    case idle
    case monitoring
    case potentialFall(impactTime: Date)
    case fallDetected(FallEvent)
    case alarmTriggered(FallEvent)

    var isMonitoring: Bool {
        if case .monitoring = self { return true }
        return false
    }

    var hasFall: Bool {
        switch self {
        case .fallDetected, .alarmTriggered:
            return true
        default:
            return false
        }
    }
}

/// 摔倒检测服务
class FallDetector: ObservableObject {
    // MARK: - Published Properties

    @Published private(set) var state: FallDetectionState = .idle
    @Published var isEnabled: Bool = true
    @Published var sensitivity: FallSensitivity = .normal
    @Published var fallHistory: [FallEvent] = []

    // MARK: - Configuration

    /// 检测灵敏度
    enum FallSensitivity: String, CaseIterable, Codable {
        case low = "低"
        case normal = "正常"
        case high = "高"

        /// 触发阈值 (g)
        var impactThreshold: Double {
            switch self {
            case .low: return 3.0
            case .normal: return 2.5
            case .high: return 2.0
            }
        }

        /// 静止检测时间 (秒)
        var stillnessDuration: TimeInterval {
            switch self {
            case .low: return 3.0
            case .normal: return 2.0
            case .high: return 1.5
            }
        }
    }

    // MARK: - Private Properties

    private let motionManager = CMMotionManager()
    private var accelerometerHandler: Any?
    private var fallConfirmationTimer: Timer?
    private var alarmTimer: Timer?
    private var stillnessStartTime: Date?

    // 检测算法参数
    private var lastImpactTime: Date?
    private var impactMagnitudes: [Double] = []
    private var postImpactStillness = false

    // 采样缓冲
    private var accelerationBuffer: [CMAcceleration] = []
    private let bufferSize = 10

    // 依赖服务
    private var locationService: LocationService?

    // MARK: - Initialization

    init(locationService: LocationService? = nil) {
        self.locationService = locationService
        setupMotionManager()
    }

    private func setupMotionManager() {
        motionManager.accelerometerUpdateInterval = 0.02  // 50Hz 采样
    }

    // MARK: - Public Methods

    /// 开始摔倒检测
    func startDetection() {
        guard isEnabled else {
            print("⚠️ 摔倒检测已禁用")
            return
        }

        guard motionManager.isAccelerometerAvailable else {
            print("❌ 加速度计不可用")
            return
        }

        state = .monitoring
        accelerationBuffer = []
        impactMagnitudes = []

        motionManager.startAccelerometerUpdates(to: .main) { [weak self] data, error in
            guard let self = self, let data = data, error == nil else { return }
            self.processAccelerometerData(data.acceleration)
        }

        print("✅ 摔倒检测已启动")
    }

    /// 停止摔倒检测
    func stopDetection() {
        motionManager.stopAccelerometerUpdates()
        fallConfirmationTimer?.invalidate()
        alarmTimer?.invalidate()
        state = .idle
        print("⏹️ 摔倒检测已停止")
    }

    /// 用户确认没事
    func confirmOkay() {
        guard case .fallDetected(let event) = state ||
              case .alarmTriggered(let event) = state else { return }

        var updatedEvent = event
        updatedEvent.confirmed = true
        updatedEvent.userResponse = .imOkay
        fallHistory.append(updatedEvent)

        stopAlarm()
        state = .monitoring
        print("✅ 用户确认没事")
    }

    /// 用户请求帮助
    func requestHelp() {
        guard case .fallDetected(let event) = state ||
              case .alarmTriggered(let event) = state else { return }

        var updatedEvent = event
        updatedEvent.confirmed = true
        updatedEvent.userResponse = .needHelp
        fallHistory.append(updatedEvent)

        stopAlarm()
        // 触发紧急联系人通知（由调用方处理）
        print("🆘 用户请求帮助")
    }

    /// 取消报警
    func dismissAlarm() {
        stopAlarm()
        state = .monitoring
    }

    // MARK: - Private Methods - Accelerometer Processing

    private func processAccelerometerData(_ acceleration: CMAcceleration) {
        // 计算合加速度 (减去重力基准 1g)
        let magnitude = sqrt(
            acceleration.x * acceleration.x +
            acceleration.y * acceleration.y +
            acceleration.z * acceleration.z
        )

        // 更新缓冲区
        accelerationBuffer.append(acceleration)
        if accelerationBuffer.count > bufferSize {
            accelerationBuffer.removeFirst()
        }

        // 根据当前状态处理
        switch state {
        case .monitoring:
            checkForImpact(magnitude: magnitude)
        case .potentialFall:
            checkForStillness(acceleration: acceleration)
        default:
            break
        }
    }

    private func checkForImpact(magnitude: Double) {
        // 检测突发冲击 (超过阈值)
        guard magnitude > sensitivity.impactThreshold else { return }

        let now = Date()
        lastImpactTime = now
        impactMagnitudes.append(magnitude)

        // 防止短时间内多次触发
        let recentImpacts = impactMagnitudes.suffix(5)
        let averageImpact = recentImpacts.reduce(0, +) / Double(recentImpacts.count)

        // 如果连续高冲击，可能是跳跃或颠簸，过滤掉
        if recentImpacts.count >= 3 && averageImpact > sensitivity.impactThreshold * 0.8 {
            // 可能是颠簸，记录但暂不报警
            print("⚡️ 检测到连续冲击，可能是颠簸")
            impactMagnitudes.removeAll()
            return
        }

        // 进入潜在摔倒状态
        state = .potentialFall(impactTime: now)
        stillnessStartTime = nil

        // 设置确认定时器
        fallConfirmationTimer = Timer.scheduledTimer(
            withTimeInterval: sensitivity.stillnessDuration,
            repeats: false
        ) { [weak self] _ in
            self?.confirmFall()
        }

        print("⚠️ 检测到潜在摔倒，冲击力: \(String(format: "%.2f", magnitude))g")
    }

    private func checkForStillness(acceleration: CMAcceleration) {
        // 计算加速度变化率
        let variance = calculateAccelerationVariance()

        // 检测摔倒后的静止状态
        if variance < 0.1 {  // 低方差表示静止
            if stillnessStartTime == nil {
                stillnessStartTime = Date()
            }

            let stillnessDuration = Date().timeIntervalSince(stillnessStartTime!)

            // 如果静止超过阈值，确认摔倒
            if stillnessDuration > 0.5 {
                postImpactStillness = true
            }
        } else {
            stillnessStartTime = nil
            postImpactStillness = false
        }
    }

    private func calculateAccelerationVariance() -> Double {
        guard accelerationBuffer.count >= 3 else { return 0 }

        let recentBuffer = accelerationBuffer.suffix(5)
        let count = Double(recentBuffer.count)

        // 计算均值
        var meanX = 0.0, meanY = 0.0, meanZ = 0.0
        for acc in recentBuffer {
            meanX += acc.x
            meanY += acc.y
            meanZ += acc.z
        }
        meanX /= count
        meanY /= count
        meanZ /= count

        // 计算方差
        var variance = 0.0
        for acc in recentBuffer {
            variance += pow(acc.x - meanX, 2)
            variance += pow(acc.y - meanY, 2)
            variance += pow(acc.z - meanZ, 2)
        }
        variance /= count

        return variance
    }

    private func confirmFall() {
        guard case .potentialFall(let impactTime) = state else { return }

        // 获取当前位置
        var fallLocation: FallLocation?
        if let location = locationService?.currentLocation {
            fallLocation = FallLocation(
                latitude: location.coordinate.latitude,
                longitude: location.coordinate.longitude,
                altitude: location.altitude
            )
        }

        // 计算冲击力
        let impactMagnitude = impactMagnitudes.last ?? 0

        // 创建摔倒事件
        let event = FallEvent(
            timestamp: impactTime,
            impactMagnitude: impactMagnitude,
            location: fallLocation
        )

        state = .fallDetected(event)

        // 触发触觉反馈
        triggerHapticFeedback()

        print("🚨 摔倒已确认！冲击力: \(String(format: "%.2f", impactMagnitude))g")

        // 开始报警定时器
        startAlarmTimer()
    }

    // MARK: - Alarm Management

    private func startAlarmTimer() {
        // 15秒后自动升级为紧急报警
        alarmTimer = Timer.scheduledTimer(withTimeInterval: 15.0, repeats: false) { [weak self] _ in
            self?.escalateToAlarm()
        }
    }

    private func escalateToAlarm() {
        guard case .fallDetected(let event) = state else { return }

        state = .alarmTriggered(event)

        // 强烈震动
        triggerUrgentHapticFeedback()

        // 播放警报声
        playAlarmSound()

        print("🚨🚨🚨 摔倒报警升级！")
    }

    private func stopAlarm() {
        alarmTimer?.invalidate()
        alarmTimer = nil
        stopAlarmSound()
    }

    // MARK: - Haptic & Audio Feedback

    private func triggerHapticFeedback() {
        let generator = UINotificationFeedbackGenerator()
        generator.prepare()
        generator.notificationOccurred(.warning)

        // 额外震动
        let impactGenerator = UIImpactFeedbackGenerator(style: .heavy)
        impactGenerator.prepare()
        impactGenerator.impactOccurred()
    }

    private func triggerUrgentHapticFeedback() {
        // 持续强烈震动模式
        let generator = UINotificationFeedbackGenerator()
        generator.prepare()

        for i in 0..<5 {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(i) * 0.3) {
                generator.notificationOccurred(.error)
            }
        }
    }

    private func playAlarmSound() {
        // 使用系统默认警报声
        AudioServicesPlaySystemSound(SystemSoundID(4095))  // 预览系统声音
    }

    private func stopAlarmSound() {
        // 停止所有声音
    }

    // MARK: - Filtering Logic

    /// 过滤误报 - 检查是否为跳跃或正常颠簸
    private func isLikelyFalsePositive() -> Bool {
        // 检查是否在最近时间有多次冲击（可能是颠簸）
        let recentImpacts = impactMagnitudes.suffix(10)
        guard recentImpacts.count >= 3 else { return false }

        // 如果频繁冲击，可能是颠簸
        let frequentImpacts = recentImpacts.filter { $0 > sensitivity.impactThreshold * 0.7 }
        return frequentImpacts.count > 5
    }

    // MARK: - Statistics

    /// 获取摔倒统计
    var fallCount: Int {
        fallHistory.count
    }

    /// 获取今日摔倒次数
    var todayFallCount: Int {
        let calendar = Calendar.current
        return fallHistory.filter { calendar.isDateInToday($0.timestamp) }.count
    }

    // MARK: - Codable Support

    /// 导出摔倒历史
    func exportFallHistory() -> Data? {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return try? encoder.encode(fallHistory)
    }

    /// 导入摔倒历史
    func importFallHistory(_ data: Data) {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        if let history = try? decoder.decode([FallEvent].self, from: data) {
            fallHistory = history
        }
    }
}

// MARK: - FallEvent Codable Extension

extension FallEvent: Codable {
    enum CodingKeys: String, CodingKey {
        case id, timestamp, impactMagnitude, location, confirmed, userResponse
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        timestamp = try container.decode(Date.self, forKey: .timestamp)
        impactMagnitude = try container.decode(Double.self, forKey: .impactMagnitude)
        location = try container.decodeIfPresent(FallLocation.self, forKey: .location)
        confirmed = try container.decodeIfPresent(Bool.self, forKey: .confirmed) ?? false
        userResponse = try container.decodeIfPresent(FallResponse.self, forKey: .userResponse)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(timestamp, forKey: .timestamp)
        try container.encode(impactMagnitude, forKey: .impactMagnitude)
        try container.encode(location, forKey: .location)
        try container.encode(confirmed, forKey: .confirmed)
        try container.encode(userResponse, forKey: .userResponse)
    }
}

// MARK: - FallResponse Codable Extension

extension FallResponse: Codable {
    enum CodingKeys: String, CodingKey {
        case imOkay = "im_okay"
        case needHelp = "need_help"
        case noResponse = "no_response"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let rawValue = try container.decode(String.self)
        switch rawValue {
        case "im_okay": self = .imOkay
        case "need_help": self = .needHelp
        default: self = .noResponse
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .imOkay: try container.encode("im_okay")
        case .needHelp: try container.encode("need_help")
        case .noResponse: try container.encode("no_response")
        }
    }
}