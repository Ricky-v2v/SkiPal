//
//  InterfaceController.swift
//  SkiPal Watch Extension
//

import WatchKit
import Foundation

class InterfaceController: WKInterfaceController {
    
    @IBOutlet var speedLabel: WKInterfaceLabel!
    @IBOutlet var distanceLabel: WKInterfaceLabel!
    @IBOutlet var durationLabel: WKInterfaceLabel!
    @IBOutlet var statusLabel: WKInterfaceLabel!
    
    private var isRecording = false
    
    override func awake(withContext context: Any?) {
        super.awake(withContext: context)
        updateUI(speed: 0, distance: 0, duration: 0)
    }
    
    override func willActivate() {
        super.willActivate()
    }
    
    override func didDeactivate() {
        super.didDeactivate()
    }
    
    // MARK: - Actions
    
    @IBAction func startButtonTapped() {
        if isRecording {
            // 暂停
            isRecording = false
            statusLabel.setText("已暂停")
        } else {
            // 开始
            isRecording = true
            statusLabel.setText("录制中...")
            // 发送消息到 iPhone
            sendMessageToPhone(action: "startRecording")
        }
    }
    
    @IBAction func stopButtonTapped() {
        isRecording = false
        statusLabel.setText("已停止")
        sendMessageToPhone(action: "stopRecording")
    }
    
    @IBAction func emergencyButtonTapped() {
        // 发送紧急警报
        WKInterfaceDevice.current().play(.failure)
        sendMessageToPhone(action: "emergency")
    }
    
    // MARK: - Helper Methods
    
    private func updateUI(speed: Double, distance: Double, duration: TimeInterval) {
        speedLabel.setText(String(format: "%.1f km/h", speed))
        distanceLabel.setText(String(format: "%.2f km", distance))
        
        let hours = Int(duration) / 3600
        let minutes = (Int(duration) % 3600) / 60
        let seconds = Int(duration) % 60
        durationLabel.setText(String(format: "%02d:%02d:%02d", hours, minutes, seconds))
    }
    
    private func sendMessageToPhone(action: String) {
        guard WCSession.default.isReachable else {
            print("⌚ iPhone 不可达")
            return
        }
        
        let message = ["action": action, "timestamp": Date().timeIntervalSince1970]
        WCSession.default.sendMessage(message, replyHandler: nil) { error in
            print("❌ 发送失败: \(error.localizedDescription)")
        }
    }
}
