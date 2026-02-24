//
//  RecordingService.swift
//  SkiPal
//
//  滑雪记录服务 - 管理记录状态和数据收集
//

import Foundation
import CoreLocation
import Combine

/// 记录状态
enum RecordingState: Equatable {
    case idle
    case recording(startTime: Date)
    case paused(startTime: Date, pausedDuration: TimeInterval)
    
    var isRecording: Bool {
        if case .recording = self { return true }
        return false
    }
    
    var isPaused: Bool {
        if case .paused = self { return true }
        return false
    }
    
    var isActive: Bool {
        isRecording || isPaused
    }
}

/// 记录服务
class RecordingService: ObservableObject {
    @Published private(set) var state: RecordingState = .idle
    @Published var currentPath: [SkiLocation] = []
    @Published var currentDistance: Double = 0
    @Published var currentDuration: TimeInterval = 0
    
    private var locationService: LocationService
    private var cancellables = Set<AnyCancellable>()
    private var timer: Timer?
    private var startTime: Date?
    private var pausedDuration: TimeInterval = 0
    
    var isRecording: Bool { state.isRecording }
    var isPaused: Bool { state.isPaused }
    var hasPausedRecording: Bool { isPaused || (isRecording && pausedDuration > 0) }
    
    init(locationService: LocationService) {
        self.locationService = locationService
        setupBindings()
    }
    
    private func setupBindings() {
        // 监听位置更新，记录路径
        locationService.$currentLocation
            .compactMap { $0 }
            .filter { [weak self] _ in self?.state.isRecording ?? false }
            .sink { [weak self] location in
                self?.addLocation(location)
            }
            .store(in: &cancellables)
    }
    
    // MARK: - 记录控制
    
    /// 开始记录
    func startRecording() {
        guard locationService.canUseLocation else {
            print("⚠️ 无法开始记录：定位权限未授权")
            return
        }
        
        let now = Date()
        startTime = now
        state = .recording(startTime: now)
        currentPath = []
        currentDistance = 0
        pausedDuration = 0
        
        // 启动定时器更新持续时间
        startTimer()
        
        // 保持屏幕常亮
        UIApplication.shared.isIdleTimerDisabled = true
        
        print("✅ 开始记录滑雪")
    }
    
    /// 暂停记录
    func pauseRecording() {
        guard case .recording(let startTime) = state else { return }
        
        let currentDuration = Date().timeIntervalSince(startTime) - pausedDuration
        state = .paused(startTime: startTime, pausedDuration: currentDuration)
        stopTimer()
        
        print("⏸️ 暂停记录")
    }
    
    /// 恢复记录
    func resumeRecording() {
        guard case .paused(let startTime, let pausedDuration) = state else { return }
        
        self.pausedDuration = pausedDuration
        state = .recording(startTime: startTime)
        startTimer()
        
        print("▶️ 恢复记录")
    }
    
    /// 结束记录
    func stopRecording() -> SkiSession? {
        guard state.isActive else { return nil }
        
        stopTimer()
        
        var session: SkiSession?
        
        switch state {
        case .recording(let startTime), .paused(let startTime, _):
            session = SkiSession(
                startTime: startTime,
                locations: currentPath,
                resortName: detectResortName()
            )
            session?.endTime = Date()
            
        case .idle:
            break
        }
        
        // 重置状态
        state = .idle
        currentDuration = 0
        pausedDuration = 0
        
        // 恢复屏幕自动锁定
        UIApplication.shared.isIdleTimerDisabled = false
        
        print("⏹️ 结束记录")
        return session
    }
    
    // MARK: - 私有方法
    
    private func addLocation(_ location: CLLocation) {
        let skiLocation = SkiLocation(from: location)
        currentPath.append(skiLocation)
        
        // 计算距离
        if currentPath.count > 1 {
            let lastIndex = currentPath.count - 1
            let distance = skiLocation.location.distance(from: currentPath[lastIndex - 1].location)
            currentDistance += distance
        }
    }
    
    private func startTimer() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            self?.updateDuration()
        }
    }
    
    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }
    
    private func updateDuration() {
        guard case .recording(let startTime) = state else { return }
        currentDuration = Date().timeIntervalSince(startTime) - pausedDuration
    }
    
    private func detectResortName() -> String? {
        // 简化实现：基于位置检测雪场名称
        // 实际应用应该使用雪场数据库或地理围栏
        guard let location = locationService.currentLocation else { return nil }
        
        let lat = location.coordinate.latitude
        let lon = location.coordinate.longitude
        
        // 示例：检测一些知名雪场（简化版）
        // 南山滑雪场 (北京) ~ 40.3, 116.6
        if abs(lat - 40.3) < 0.1 && abs(lon - 116.6) < 0.1 {
            return "南山滑雪场"
        }
        // 万龙滑雪场 (崇礼) ~ 40.9, 115.4
        if abs(lat - 40.9) < 0.1 && abs(lon - 115.4) < 0.1 {
            return "万龙滑雪场"
        }
        
        return nil
    }
    
    deinit {
        stopTimer()
        UIApplication.shared.isIdleTimerDisabled = false
    }
}

// MARK: - UIApplication 扩展
import UIKit

extension UIApplication {
    static var isIdleTimerDisabled: Bool {
        get { shared.isIdleTimerDisabled }
        set { shared.isIdleTimerDisabled = newValue }
    }
}
