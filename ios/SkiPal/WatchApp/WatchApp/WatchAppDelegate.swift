//
//  WatchAppDelegate.swift
//  SkiPal Watch App
//
//  WatchConnectivity 数据模型与会话状态管理。
//  文件名保留用于兼容既有工程文件引用。
//

import Foundation
import SwiftUI
import WatchConnectivity
import WatchKit

/// 与 iOS 侧 WatchMessageType 完全同构的消息类型。
enum WatchMessageType: String, Codable {
    case startRecording
    case pauseRecording
    case resumeRecording
    case stopRecording
    case recordingStateChanged
    case locationUpdate
    case sessionData
    case requestSessionSync
    case sessionSync
    case deleteSession
    case fallDetected
    case fallConfirmed
    case fallCancelled
    case emergencyContact
    case userSettings
}

/// 与 iOS 侧一致的可编码值包装器。
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

    var intValue: Int? {
        if case .int(let value) = self { return value }
        return nil
    }
}

/// 与 iOS 侧一致的 WatchConnectivity 消息结构。
struct WatchMessage: Codable {
    let type: WatchMessageType
    let timestamp: Date
    let payload: [String: CodableValue]?
}

enum WatchRecordingState: String {
    case idle
    case recording
    case paused

    init(remoteValue: String) {
        self = WatchRecordingState(rawValue: remoteValue) ?? .idle
    }

    var displayName: String {
        switch self {
        case .idle:
            return "未在滑行"
        case .recording:
            return "记录中"
        case .paused:
            return "已暂停"
        }
    }

    var isActive: Bool {
        self != .idle
    }

    var primaryActionTitle: String {
        switch self {
        case .idle:
            return "开始"
        case .recording:
            return "暂停"
        case .paused:
            return "继续"
        }
    }

    var primaryActionIcon: String {
        switch self {
        case .idle:
            return "play.fill"
        case .recording:
            return "pause.fill"
        case .paused:
            return "play.fill"
        }
    }

    var primaryActionTint: Color {
        switch self {
        case .idle, .recording:
            return .green
        case .paused:
            return .orange
        }
    }

    var tint: Color {
        switch self {
        case .idle:
            return .secondary
        case .recording:
            return .red
        case .paused:
            return .orange
        }
    }
}

final class WatchSessionModel: NSObject, ObservableObject {
    @Published private(set) var isReachable = false
    @Published private(set) var recordingState: WatchRecordingState = .idle
    @Published private(set) var speedKilometersPerHour: Double = 0
    @Published private(set) var distanceKilometers: Double = 0
    @Published private(set) var durationSeconds: TimeInterval = 0

    private var durationReferenceDate = Date()
    private var hasActivatedSession = false
    private let durationFormatter = WatchDurationFormatter()

    var formattedDuration: String {
        durationFormatter.string(from: displayedDuration(at: Date()))
    }

    func activate() {
        guard !hasActivatedSession else { return }
        hasActivatedSession = true

        guard WCSession.isSupported() else {
            DispatchQueue.main.async {
                self.isReachable = false
            }
            return
        }

        let session = WCSession.default
        session.delegate = self
        session.activate()
    }

    func performPrimaryAction() {
        switch recordingState {
        case .idle:
            sendAction(.startRecording)
        case .recording:
            sendAction(.pauseRecording)
        case .paused:
            sendAction(.resumeRecording)
        }
    }

    func sendAction(_ type: WatchMessageType) {
        guard WCSession.default.isReachable else {
            print("⌚ iPhone 不可达")
            DispatchQueue.main.async {
                self.isReachable = false
            }
            return
        }

        let watchMessage = WatchMessage(type: type, timestamp: Date(), payload: nil)
        guard let messageData = try? JSONEncoder().encode(watchMessage) else {
            print("❌ Watch 控制消息编码失败")
            return
        }

        let message: [String: Any] = [
            "action": type.rawValue,
            "timestamp": Date().timeIntervalSince1970,
            "messageData": messageData
        ]

        WCSession.default.sendMessage(message, replyHandler: nil) { error in
            print("❌ Watch 控制消息发送失败: \(error.localizedDescription)")
            DispatchQueue.main.async {
                self.isReachable = false
            }
        }
    }

    func reportEmergency() {
        WKInterfaceDevice.current().play(.failure)
        sendAction(.fallDetected)
    }

    func displayedDuration(at date: Date) -> TimeInterval {
        guard recordingState == .recording else { return durationSeconds }
        return durationSeconds + max(0, date.timeIntervalSince(durationReferenceDate))
    }

    private func apply(_ message: WatchMessage) {
        switch message.type {
        case .locationUpdate:
            guard let metersPerSecond = message.payload?["speed"]?.doubleValue else { return }
            speedKilometersPerHour = max(0, metersPerSecond) * 3.6

        case .recordingStateChanged:
            applyRecordingPayload(message.payload, receivedAt: Date())

        case .sessionData:
            applyRecordingPayload(message.payload, receivedAt: Date())

        default:
            break
        }
    }

    private func applyRecordingPayload(_ payload: [String: CodableValue]?, receivedAt: Date) {
        guard let payload else { return }

        if let state = payload["state"]?.stringValue {
            recordingState = WatchRecordingState(remoteValue: state)
        }

        if let meters = payload["distance"]?.doubleValue {
            distanceKilometers = max(0, meters) / 1000
        }

        if let seconds = payload["duration"]?.doubleValue {
            durationSeconds = max(0, seconds)
            durationReferenceDate = receivedAt
        }

        if recordingState != .recording {
            speedKilometersPerHour = 0
        }
    }
}

extension WatchSessionModel: WCSessionDelegate {
    func session(
        _ session: WCSession,
        activationDidCompleteWith activationState: WCSessionActivationState,
        error: Error?
    ) {
        if let error {
            print("⚠️ WatchConnectivity 激活失败: \(error.localizedDescription)")
        }
        updateReachability(session.isReachable)
    }

    func sessionReachabilityDidChange(_ session: WCSession) {
        updateReachability(session.isReachable)
    }

    func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        handleMessageDictionary(message)
    }

    func session(_ session: WCSession, didReceiveUserInfo userInfo: [String: Any] = [:]) {
        handleMessageDictionary(userInfo)
    }

    private func handleMessageDictionary(_ dictionary: [String: Any]) {
        guard let data = dictionary["messageData"] as? Data,
              let message = try? JSONDecoder().decode(WatchMessage.self, from: data) else {
            print("⚠️ 收到无法解析的 Watch 消息")
            return
        }

        DispatchQueue.main.async {
            self.updateReachability(true)
            self.apply(message)
        }
    }

    private func updateReachability(_ reachable: Bool) {
        DispatchQueue.main.async {
            self.isReachable = reachable
        }
    }
}

private struct WatchDurationFormatter {
    func string(from duration: TimeInterval) -> String {
        let totalSeconds = max(0, Int(duration))
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        let seconds = totalSeconds % 60
        return String(format: "%02d:%02d:%02d", hours, minutes, seconds)
    }
}
