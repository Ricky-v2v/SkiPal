//
//  WatchConnectivityService.swift
//  SkiPal
//
//  Watch-iPhone 同步服务 - 使用 WatchConnectivity
//

import Foundation
import WatchConnectivity
import Combine

/// Watch 消息类型
enum WatchMessageType: String, Codable {
    // 录制控制
    case startRecording
    case pauseRecording
    case resumeRecording
    case stopRecording
    case recordingStateChanged

    // 实时数据
    case locationUpdate
    sessionData

    // 同步
    case requestSessionSync
    case sessionSync
    case deleteSession

    // 跌倒检测
    case fallDetected
    case fallConfirmed
    case fallCancelled

    // 设置
    case emergencyContact
    case userSettings
}

/// Watch 消息
struct WatchMessage: Codable {
    let type: WatchMessageType
    let timestamp: Date
    let payload: [String: CodableValue]?

    init(type: WatchMessageType, payload: [String: CodableValue]? = nil) {
        self.type = type
        self.timestamp = Date()
        self.payload = payload
    }
}

/// 可编码值包装器 - CRITICAL: 添加 Equatable
enum CodableValue: Codable, Equatable {
    case string(String)
    case double(Double)
    case int(Int)
    case bool(Bool)
    case data(Data)
    case array([CodableValue])
    case dictionary([String: CodableValue])

    var stringValue: String? {
        if case .string(let value) = self { return value }
        return nil
    }

    var doubleValue: Double? {
        if case .double(let value) = self { return value }
        return nil
    }

    var boolValue: Bool? {
        if case .bool(let value) = self { return value }
        return nil
    }

    var dataValue: Data? {
        if case .data(let value) = self { return value }
        return nil
    }

    // MARK: - Equatable 实现
    static func == (lhs: CodableValue, rhs: CodableValue) -> Bool {
        switch (lhs, rhs) {
        case (.string(let l), .string(let r)):
            return l == r
        case (.double(let l), .double(let r)):
            return l == r
        case (.int(let l), .int(let r)):
            return l == r
        case (.bool(let l), .bool(let r)):
            return l == r
        case (.data(let l), .data(let r)):
            return l == r
        case (.array(let l), .array(let r)):
            return l == r
        case (.dictionary(let l), .dictionary(let r)):
            return l == r
        default:
            return false
        }
    }
}

/// Watch 连接状态
enum WatchConnectionState {
    case notSupported
    case notInstalled
    case notPaired
    case pairedButNotReachable
    case reachable
}

/// WatchConnectivity 服务
class WatchConnectivityService: NSObject, ObservableObject {
    static let shared = WatchConnectivityService()

    // 发布属性
    @Published private(set) var isReachable = false
    @Published private(set) var connectionState: WatchConnectionState = .notSupported
    @Published private(set) var lastSyncTime: Date?
    @Published private(set) var isSyncing = false

    // 消息回调
    let messageReceived = PassthroughSubject<WatchMessage, Never>()

    // WCSession
    private var session: WCSession?

    // 缓存待发送数据（离线支持）
    private var pendingMessages: [WatchMessage] = []
    private let maxPendingMessages = 100

    private override init() {
        super.init()
        setupSession()
    }

    private func setupSession() {
        guard WCSession.isSupported() else {
            connectionState = .notSupported
            return
        }

        session = WCSession.default
        session?.delegate = self
        session?.activate()
    }

    // MARK: - 发送消息

    /// 发送消息到配对设备
    func sendMessage(_ message: WatchMessage) {
        guard let session = session, session.isReachable else {
            // 缓存消息等待后续发送
            cachePendingMessage(message)
            return
        }

        do {
            let data = try JSONEncoder().encode(message)
            let dictionary = ["messageData": data]
            session.sendMessage(dictionary, replyHandler: nil) { error in
                print("❌ Watch消息发送失败: \(error.localizedDescription)")
                self.cachePendingMessage(message)
            }
        } catch {
            print("❌ Watch消息编码失败: \(error.localizedDescription)")
        }
    }

    /// 发送即时消息（需要回复）
    func sendMessageWithReply(_ message: WatchMessage, replyHandler: @escaping ([String: Any]) -> Void) {
        guard let session = session, session.isReachable else {
            replyHandler(["error": "设备不可达"])
            return
        }

        do {
            let data = try JSONEncoder().encode(message)
            let dictionary = ["messageData": data]
            session.sendMessage(dictionary, replyHandler: replyHandler) { error in
                print("❌ Watch消息发送失败: \(error.localizedDescription)")
                replyHandler(["error": error.localizedDescription])
            }
        } catch {
            replyHandler(["error": error.localizedDescription])
        }
    }

    /// 发送录制状态更新
    func sendRecordingState(_ state: RecordingState, currentPath: [SkiLocation], distance: Double, duration: TimeInterval) {
        var payload: [String: CodableValue] = [
            "distance": .double(distance),
            "duration": .double(duration)
        ]

        switch state {
        case .idle:
            payload["state"] = .string("idle")
        case .recording:
            payload["state"] = .string("recording")
        case .paused:
            payload["state"] = .string("paused")
        }

        // 发送最近的位置点（限制数量以减少传输）
        let recentLocations = currentPath.suffix(10)
        if let locationData = try? JSONEncoder().encode(Array(recentLocations)) {
            payload["recentLocations"] = .data(locationData)
        }

        let message = WatchMessage(type: .recordingStateChanged, payload: payload)
        sendMessage(message)
    }

    /// 发送位置更新
    func sendLocationUpdate(latitude: Double, longitude: Double, altitude: Double, speed: Double) {
        let payload: [String: CodableValue] = [
            "latitude": .double(latitude),
            "longitude": .double(longitude),
            "altitude": .double(altitude),
            "speed": .double(speed)
        ]

        let message = WatchMessage(type: .locationUpdate, payload: payload)
        sendMessage(message)
    }

    /// 发送跌倒检测警报
    func sendFallDetected(latitude: Double, longitude: Double) {
        let payload: [String: CodableValue] = [
            "latitude": .double(latitude),
            "longitude": .double(longitude),
            "timestamp": .double(Date().timeIntervalSince1970)
        ]

        let message = WatchMessage(type: .fallDetected, payload: payload)
        sendMessage(message)
    }

    /// 同步会话数据到 Watch
    func syncSessionsToWatch(_ sessions: [SkiSession]) {
        guard let session = session else { return }

        isSyncing = true

        // 只同步最近10个会话摘要
        let recentSessions = Array(sessions.prefix(10))
        let summaries = recentSessions.map { session -> [String: CodableValue] in
            return [
                "id": .string(session.id.uuidString),
                "startTime": .double(session.startTime.timeIntervalSince1970),
                "duration": .double(session.duration),
                "distance": .double(session.totalDistance),
                "maxSpeed": .double(session.maxSpeed),
                "resortName": .string(session.resortName ?? "未知雪场")
            ]
        }

        do {
            let data = try JSONEncoder().encode(summaries)
            let message = WatchMessage(type: .sessionSync, payload: ["sessions": .data(data)])
            let messageData = try JSONEncoder().encode(message)

            // 使用 transferUserInfo 用于后台传输
            session.transferUserInfo(["messageData": messageData])

            lastSyncTime = Date()
        } catch {
            print("❌ 会话同步失败: \(error.localizedDescription)")
        }

        isSyncing = false
    }

    // MARK: - 私有方法

    /// 缓存待发送消息 - IMPORTANT: 添加清理逻辑
    private func cachePendingMessage(_ message: WatchMessage) {
        pendingMessages.append(message)

        // 超过最大数量时移除最旧的消息
        while pendingMessages.count > maxPendingMessages {
            pendingMessages.removeFirst()
            print("⚠️ 已移除最旧的待发送消息，当前数量: \(pendingMessages.count)")
        }
    }

    /// 清理过期的待发送消息
    private func cleanupPendingMessages() {
        // 移除超过24小时的消息
        let cutoffTime = Date().addingTimeInterval(-24 * 60 * 60)
        pendingMessages = pendingMessages.filter { message in
            return message.timestamp > cutoffTime
        }

        // 确保不超过最大数量
        while pendingMessages.count > maxPendingMessages {
            pendingMessages.removeFirst()
        }
    }

    private func processPendingMessages() {
        guard isReachable else { return }

        // 先清理过期消息
        cleanupPendingMessages()

        while !pendingMessages.isEmpty {
            let message = pendingMessages.removeFirst()
            sendMessage(message)
        }
    }
}

// MARK: - WCSessionDelegate
extension WatchConnectivityService: WCSessionDelegate {
    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        DispatchQueue.main.async {
            self.updateConnectionState(session)

            if let error = error {
                print("⚠️ WCSession 激活错误: \(error.localizedDescription)")
            }
        }
    }

    func sessionDidBecomeInactive(_ session: WCSession) {
        // 会话变为非活跃
    }

    func sessionDidDeactivate(_ session: WCSession) {
        // 会话停用，重新激活
        session.activate()
    }

    func sessionReachabilityDidChange(_ session: WCSession) {
        DispatchQueue.main.async {
            self.isReachable = session.isReachable
            self.updateConnectionState(session)

            if session.isReachable {
                self.processPendingMessages()
            }
        }
    }

    func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        guard let data = message["messageData"] as? Data,
              let watchMessage = try? JSONDecoder().decode(WatchMessage.self, from: data) else {
            print("⚠️ 收到无效的Watch消息")
            return
        }

        DispatchQueue.main.async {
            self.handleMessage(watchMessage)
        }
    }

    func session(_ session: WCSession, didReceiveUserInfo userInfo: [String: Any] = [:]) {
        guard let data = userInfo["messageData"] as? Data,
              let watchMessage = try? JSONDecoder().decode(WatchMessage.self, from: data) else {
            return
        }

        DispatchQueue.main.async {
            self.handleMessage(watchMessage)
        }
    }

    private func updateConnectionState(_ session: WCSession) {
        #if os(iOS)
        if !session.isWatchAppInstalled {
            connectionState = .notInstalled
        } else if !session.isPaired {
            connectionState = .notPaired
        } else if session.isReachable {
            connectionState = .reachable
        } else {
            connectionState = .pairedButNotReachable
        }
        #else
        if session.isReachable {
            connectionState = .reachable
        } else {
            connectionState = .pairedButNotReachable
        }
        #endif

        isReachable = session.isReachable
    }

    private func handleMessage(_ message: WatchMessage) {
        messageReceived.send(message)

        switch message.type {
        case .startRecording, .pauseRecording, .resumeRecording, .stopRecording:
            print("📱 收到录制控制消息: \(message.type)")

        case .fallDetected:
            print("⚠️ 收到跌倒检测警报")
            // 触发 iPhone 端的跌倒处理

        case .fallConfirmed, .fallCancelled:
            print("📱 跌倒确认状态: \(message.type)")

        default:
            break
        }
    }
}

// MARK: - iOS 特定扩展
#if os(iOS)
import UIKit

extension WatchConnectivityService {
    /// 获取 Watch 状态描述
    var connectionStateDescription: String {
        switch connectionState {
        case .notSupported:
            return "此设备不支持 Watch"
        case .notInstalled:
            return "请先在 Apple Watch 上安装 SkiPal"
        case .notPaired:
            return "未配对 Apple Watch"
        case .pairedButNotReachable:
            return "Apple Watch 未连接"
        case .reachable:
            return "Apple Watch 已连接"
        }
    }

    /// Watch 图标
    var connectionIcon: String {
        switch connectionState {
        case .reachable:
            return "watch.connect"
        default:
            return "watch"
        }
    }
}
#endif

// MARK: - watchOS 特定扩展
#if os(watchOS)
import WatchKit

extension WatchConnectivityService {
    /// 请求 iPhone 开始录制
    func requestStartRecording() {
        let message = WatchMessage(type: .startRecording)
        sendMessage(message)
    }

    /// 请求 iPhone 暂停录制
    func requestPauseRecording() {
        let message = WatchMessage(type: .pauseRecording)
        sendMessage(message)
    }

    /// 请求 iPhone 恢复录制
    func requestResumeRecording() {
        let message = WatchMessage(type: .resumeRecording)
        sendMessage(message)
    }

    /// 请求 iPhone 停止录制
    func requestStopRecording() {
        let message = WatchMessage(type: .stopRecording)
        sendMessage(message)
    }

    /// 报告跌倒检测到 iPhone
    func reportFallDetected() {
        let message = WatchMessage(type: .fallDetected)
        sendMessage(message)
    }

    /// 确认跌倒
    func confirmFall() {
        let message = WatchMessage(type: .fallConfirmed)
        sendMessage(message)
    }

    /// 取消跌倒警报
    func cancelFallAlert() {
        let message = WatchMessage(type: .fallCancelled)
        sendMessage(message)
    }
}
#endif