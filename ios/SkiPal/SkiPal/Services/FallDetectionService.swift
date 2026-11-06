//
//  FallDetectionService.swift
//  SkiPal
//
//  跌倒检测服务 - 使用 CoreMotion 检测异常加速度
//

import Foundation
import CoreMotion
import Combine
import UIKit

/// 跌倒警报状态
enum FallAlertState {
    case monitoring
    case potentialFall(timestamp: Date, magnitude: Double)
    case confirmed
    case dismissed

    var description: String {
        switch self {
        case .monitoring: return "监控中"
        case .potentialFall: return "检测到跌倒"
        case .confirmed: return "已确认跌倒"
        case .dismissed: return "已取消"
        }
    }
}

/// 跌倒警报记录
struct FallAlertRecord: Identifiable, Codable {
    let id: UUID
    let timestamp: Date
    let magnitude: Double
    let duration: Double
    var latitude: Double?
    var longitude: Double?
    var altitude: Double?
    var confirmed: Bool = false
    var dismissed: Bool = false

    init(magnitude: Double, duration: Double, location: (lat: Double, lon: Double, alt: Double)? = nil) {
        self.id = UUID()
        self.timestamp = Date()
        self.magnitude = magnitude
        self.duration = duration
        self.latitude = location?.lat
        self.longitude = location?.lon
        self.altitude = location?.alt
    }
}

/// 跌倒检测服务
class FallDetectionService: NSObject, ObservableObject {
    static let shared = FallDetectionService()

    // 发布属性
    @Published private(set) var isEnabled = true
    @Published private(set) var state: FallAlertState = .monitoring
    @Published private(set) var recentFallEvents: [FallAlertRecord] = []
    @Published private(set) var isMonitoring = false

    // 检测阈值
    @Published var fallThreshold: Double = 2.5  // g值阈值
    @Published var impactDurationThreshold: Double = 0.3  // 持续时间阈值（秒）

    // 回调
    let fallDetected = PassthroughSubject<FallAlertRecord, Never>()

    // Motion Manager
    private let motionManager = CMMotionManager()
    private var accelerometerHandler: CMAccelerometerHandler?
    private var fallStartTime: Date?
    private var peakMagnitude: Double = 0
    private var consecutiveHighReadings = 0

    // 位置服务引用
    weak var locationService: LocationService?

    // 计时器
    private var confirmationTimer: Timer?
    private let confirmationTimeout: TimeInterval = 60  // 60秒超时

    // 历史数据用于平滑
    private var recentMagnitudes: [Double] = []
    private let smoothingWindowSize = 5

    // 紧急联系人
    @Published var emergencyContactName: String?
    @Published var emergencyContactPhone: String?

    private override init() {
        super.init()
        loadSettings()
        loadFallHistory()
    }

    // MARK: - 公开方法

    /// 开始监控
    func startMonitoring() {
        guard isEnabled, motionManager.isAccelerometerAvailable else {
            print("⚠️ 加速度计不可用或跌倒检测已禁用")
            return
        }

        motionManager.accelerometerUpdateInterval = 0.05  // 20Hz
        isMonitoring = true
        state = .monitoring

        motionManager.startAccelerometerUpdates(to: .main) { [weak self] data, error in
            guard let self = self, let data = data, error == nil else { return }
            self.processAccelerometerData(data)
        }

        print("✅ 跌倒检测已启动")
    }

    /// 停止监控
    func stopMonitoring() {
        motionManager.stopAccelerometerUpdates()
        isMonitoring = false
        print("⏹️ 跌倒检测已停止")
    }

    /// 启用/禁用跌倒检测
    func setEnabled(_ enabled: Bool) {
        isEnabled = enabled
        UserDefaults.standard.set(enabled, forKey: "fallDetectionEnabled")

        if enabled && !isMonitoring {
            startMonitoring()
        } else if !enabled && isMonitoring {
            stopMonitoring()
        }
    }

    /// 确认跌倒
    func confirmFall() {
        guard case .potentialFall = state else { return }

        state = .confirmed

        // 更新最近的跌倒事件
        if var event = recentFallEvents.first {
            event.confirmed = true
            recentFallEvents[0] = event
            saveFallHistory()

            // CRITICAL: 发送跌倒确认事件
            fallDetected.send(event)
        }

        // 触发紧急响应
        triggerEmergencyResponse()

        // 通知 Watch
        #if os(iOS)
        WatchConnectivityService.shared.sendMessage(WatchMessage(type: .fallConfirmed))
        #endif

        // 重置状态
        DispatchQueue.main.asyncAfter(deadline: .now() + 5) { [weak self] in
            self?.resetState()
        }
    }

    /// 取消跌倒警报
    func dismissFall() {
        guard case .potentialFall = state else { return }

        state = .dismissed
        cancelConfirmationTimer()

        // 更新事件
        if var event = recentFallEvents.first {
            event.dismissed = true
            recentFallEvents[0] = event
            saveFallHistory()
        }

        // 通知 Watch
        #if os(iOS)
        WatchConnectivityService.shared.sendMessage(WatchMessage(type: .fallCancelled))
        #endif

        // 重置状态
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) { [weak self] in
            self?.resetState()
        }
    }

    /// 设置紧急联系人
    func setEmergencyContact(name: String, phone: String) {
        emergencyContactName = name
        emergencyContactPhone = phone
        UserDefaults.standard.set(name, forKey: "emergencyContactName")
        UserDefaults.standard.set(phone, forKey: "emergencyContactPhone")
    }

    /// 清除跌倒历史
    func clearFallHistory() {
        recentFallEvents.removeAll()
        saveFallHistory()
    }

    // MARK: - 私有方法

    private func processAccelerometerData(_ data: CMAccelerometerData) {
        // 计算总加速度大小
        let acceleration = data.acceleration
        let magnitude = sqrt(
            acceleration.x * acceleration.x +
            acceleration.y * acceleration.y +
            acceleration.z * acceleration.z
        )

        // 平滑处理
        recentMagnitudes.append(magnitude)
        if recentMagnitudes.count > smoothingWindowSize {
            recentMagnitudes.removeFirst()
        }
        let smoothedMagnitude = recentMagnitudes.reduce(0, +) / Double(recentMagnitudes.count)

        // 状态机处理
        switch state {
        case .monitoring:
            checkForFall(smoothedMagnitude)

        case .potentialFall:
            // 已经检测到潜在跌倒，等待确认
            break

        case .confirmed, .dismissed:
            break
        }
    }

    private func checkForFall(_ magnitude: Double) {
        if magnitude > fallThreshold {
            consecutiveHighReadings += 1

            if consecutiveHighReadings == 1 {
                fallStartTime = Date()
                peakMagnitude = magnitude
            } else {
                peakMagnitude = max(peakMagnitude, magnitude)
            }

            // 检查持续时间
            if let startTime = fallStartTime,
               Date().timeIntervalSince(startTime) >= impactDurationThreshold {
                // 确认跌倒
                triggerFallDetection(magnitude: peakMagnitude)
            }
        } else {
            // 重置计数器
            consecutiveHighReadings = 0
            fallStartTime = nil
            peakMagnitude = 0
        }
    }

    private func triggerFallDetection(magnitude: Double) {
        // 获取当前位置
        var location: (lat: Double, lon: Double, alt: Double)?
        if let loc = locationService?.currentLocation {
            location = (loc.coordinate.latitude, loc.coordinate.longitude, loc.altitude)
        }

        // 创建跌倒事件
        let duration = fallStartTime.map { Date().timeIntervalSince($0) } ?? 0
        let event = FallAlertRecord(magnitude: magnitude, duration: duration, location: location)

        // 更新状态
        state = .potentialFall(timestamp: Date(), magnitude: magnitude)

        // 保存事件
        recentFallEvents.insert(event, at: 0)
        if recentFallEvents.count > 50 {
            recentFallEvents.removeLast()
        }
        saveFallHistory()

        // 触发回调
        fallDetected.send(event)

        // 触发触觉反馈
        triggerHapticFeedback()

        // 通知 Watch
        #if os(iOS)
        if let loc = location {
            WatchConnectivityService.shared.sendFallDetected(latitude: loc.lat, longitude: loc.lon)
        }
        #endif

        // 启动确认计时器
        startConfirmationTimer()

        // 重置检测变量
        consecutiveHighReadings = 0
        fallStartTime = nil
        peakMagnitude = 0

        print("⚠️ 检测到跌倒！强度: \(String(format: "%.2f", magnitude))g")
    }

    private func triggerHapticFeedback() {
        let generator = UINotificationFeedbackGenerator()
        generator.prepare()
        generator.notificationOccurred(.warning)

        // 多次震动
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            generator.notificationOccurred(.error)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            generator.notificationOccurred(.error)
        }
    }

    private func startConfirmationTimer() {
        confirmationTimer?.invalidate()
        confirmationTimer = Timer.scheduledTimer(withTimeInterval: confirmationTimeout, repeats: false) { [weak self] _ in
            // 超时自动确认
            self?.confirmFall()
        }
    }

    private func cancelConfirmationTimer() {
        confirmationTimer?.invalidate()
        confirmationTimer = nil
    }

    private func resetState() {
        state = .monitoring
        consecutiveHighReadings = 0
        fallStartTime = nil
        peakMagnitude = 0
    }

    private func triggerEmergencyResponse() {
        // 发送通知
        let content = UNMutableNotificationContent()
        content.title = "跌倒已确认"
        content.body = "正在通知紧急联系人..."
        content.sound = .defaultCritical

        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request)

        // IMPORTANT: 紧急联系人 - 发送短信和拨打电话
        if let phone = emergencyContactPhone {
            print("📞 应通知紧急联系人: \(phone)")

            #if os(iOS)
            // 发送短信
            sendEmergencySMS(to: phone)

            // 延迟后拨打电话
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) { [weak self] in
                self?.makeEmergencyCall(to: phone)
            }
            #endif
        }
    }

    #if os(iOS)
    /// 发送紧急短信
    private func sendEmergencySMS(to phone: String) {
        // 获取当前位置信息
        var locationText = "位置未知"
        if let location = locationService?.currentLocation {
            let lat = location.coordinate.latitude
            let lon = location.coordinate.longitude
            locationText = "https://maps.apple.com/?ll=\(lat),\(lon)"
        }

        let messageBody = "【SkiPal紧急求助】检测到跌倒！请立即联系我。我的位置: \(locationText)"

        // 使用 URL Scheme 发送短信
        if let url = URL(string: "sms:\(phone)?body=\(messageBody.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")") {
            if UIApplication.shared.canOpenURL(url) {
                UIApplication.shared.open(url) { success in
                    if success {
                        print("✅ 已打开短信应用")
                    }
                }
            }
        }
    }

    /// 拨打紧急电话
    private func makeEmergencyCall(to phone: String) {
        // 清理电话号码格式
        let cleanPhone = phone.components(separatedBy: CharacterSet.decimalDigits.inverted).joined()

        if let url = URL(string: "tel://\(cleanPhone)") {
            if UIApplication.shared.canOpenURL(url) {
                UIApplication.shared.open(url) { success in
                    if success {
                        print("✅ 已拨打电话: \(cleanPhone)")
                    }
                }
            }
        }
    }
    #endif

    // MARK: - 持久化

    private func loadSettings() {
        isEnabled = UserDefaults.standard.bool(forKey: "fallDetectionEnabled")
        if !UserDefaults.standard.contains(key: "fallDetectionEnabled") {
            isEnabled = true  // 默认开启
        }

        fallThreshold = UserDefaults.standard.double(forKey: "fallThreshold")
        if fallThreshold == 0 { fallThreshold = 2.5 }

        emergencyContactName = UserDefaults.standard.string(forKey: "emergencyContactName")
        emergencyContactPhone = UserDefaults.standard.string(forKey: "emergencyContactPhone")
    }

    private func loadFallHistory() {
        guard let data = UserDefaults.standard.data(forKey: "fallEvents"),
              let events = try? JSONDecoder().decode([FallAlertRecord].self, from: data) else {
            return
        }
        recentFallEvents = events
    }

    private func saveFallHistory() {
        guard let data = try? JSONEncoder().encode(recentFallEvents) else { return }
        UserDefaults.standard.set(data, forKey: "fallEvents")
    }
}

// MARK: - UserDefaults 扩展
extension UserDefaults {
    func contains(key: String) -> Bool {
        return object(forKey: key) != nil
    }
}

// MARK: - UNUserNotificationCenter 扩展
import UserNotifications

extension FallDetectionService {
    /// 请求通知权限
    func requestNotificationPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .criticalAlert]) { granted, error in
            if granted {
                print("✅ 跌倒检测通知权限已授权")
            } else if let error = error {
                print("⚠️ 通知权限请求失败: \(error.localizedDescription)")
            }
        }
    }
}

// MARK: - watchOS 特定扩展
#if os(watchOS)
// import WatchKit // Only needed for Watch Extension

extension FallDetectionService {
    /// Watch 端触发跌倒（手动报告）
    func manualReportFall() {
        let event = FallAlertRecord(magnitude: 0, duration: 0)
        recentFallEvents.insert(event, at: 0)
        saveFallHistory()

        // 通知 iPhone
        WatchConnectivityService.shared.reportFallDetected()

        // 触发触觉反馈
        WKInterfaceDevice.current().play(.failure)
    }
}
#endif
