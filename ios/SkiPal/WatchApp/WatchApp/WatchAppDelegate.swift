//
//  WatchAppDelegate.swift
//  SkiPal Watch Extension
//

import WatchKit
import WatchConnectivity

class WatchAppDelegate: NSObject, WKExtensionDelegate, WCSessionDelegate {
    
    func applicationDidFinishLaunching() {
        // 激活 WatchConnectivity
        if WCSession.isSupported() {
            WCSession.default.delegate = self
            WCSession.default.activate()
        }
        
        // 注册后台任务
        registerBackgroundTasks()
    }
    
    func applicationDidBecomeActive() {
        // 刷新 UI
    }
    
    func applicationWillResignActive() {
        // 保存状态
    }
    
    // MARK: - Background Tasks
    
    private func registerBackgroundTasks() {
        // 注册后台刷新任务
    }
    
    // MARK: - WCSessionDelegate
    
    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        print("⌚ WatchConnectivity 激活状态: \(activationState.rawValue)")
    }
    
    func session(_ session: WCSession, didReceiveMessage message: [String : Any]) {
        // 处理 iPhone 发来的消息
        handleMessage(message)
    }
    
    private func handleMessage(_ message: [String: Any]) {
        guard let type = message["type"] as? String else { return }
        
        switch type {
        case "realTimeData":
            // 更新 UI 显示实时数据
            print("⌚ 收到实时数据: \(message)")
        case "fallAlert":
            // 显示摔倒警报
            WKInterfaceDevice.current().play(.failure)
        default:
            print("⌚ 收到未知消息类型: \(type)")
        }
    }
}
