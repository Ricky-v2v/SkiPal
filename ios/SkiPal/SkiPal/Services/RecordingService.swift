//
//  RecordingService.swift
//  SkiPal
//
//  滑雪记录服务 - 管理记录状态和数据收集
//

import Foundation
import CoreLocation
import Combine
import UIKit

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
    @Published var detectedResort: SkiResort?
    @Published var nearbyResorts: [SkiResort] = []
    
    private var locationService: LocationService
    private var resortDatabase: SkiResortDatabase
    private var cancellables = Set<AnyCancellable>()
    private var timer: Timer?
    private var startTime: Date?
    private var pausedDuration: TimeInterval = 0
    
    var isRecording: Bool { state.isRecording }
    var isPaused: Bool { state.isPaused }
    var hasPausedRecording: Bool { isPaused || (isRecording && pausedDuration > 0) }
    
    init(locationService: LocationService, resortDatabase: SkiResortDatabase = .shared) {
        self.locationService = locationService
        self.resortDatabase = resortDatabase
        setupBindings()
    }
    
    private func setupBindings() {
        // 监听位置更新，记录路径
        locationService.$currentLocation
            .compactMap { $0 }
            .filter { [weak self] _ in self?.state.isRecording ?? false }
            .sink { [weak self] location in
                self?.addLocation(location)
                self?.detectNearbyResort(location: location)
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
        setIdleTimerDisabled(true)
        
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
                resortName: detectedResort?.localizedName
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
        setIdleTimerDisabled(false)
        
        print("⏹️ 结束记录，雪场：\(detectedResort?.name ?? "未知")")
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
    
    private func detectNearbyResort(location: CLLocation) {
        // 使用雪场数据库检测附近雪场 (5km 范围)
        resortDatabase.detectNearbyResorts(location: location, radius: 5000)
        
        // 更新检测到的雪场
        if let closest = resortDatabase.nearbyResorts.first {
            DispatchQueue.main.async {
                self.detectedResort = closest
                self.nearbyResorts = self.resortDatabase.nearbyResorts
            }
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

    private func setIdleTimerDisabled(_ disabled: Bool) {
        if Thread.isMainThread {
            MainActor.assumeIsolated {
                UIApplication.shared.isIdleTimerDisabled = disabled
            }
        } else {
            Task { @MainActor in
                UIApplication.shared.isIdleTimerDisabled = disabled
            }
        }
    }
    
    deinit {
        stopTimer()
        setIdleTimerDisabled(false)
    }
}
