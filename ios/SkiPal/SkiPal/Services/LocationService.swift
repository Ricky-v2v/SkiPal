//
//  LocationService.swift
//  SkiPal
//
//  位置服务 - 管理GPS定位和权限
//

import Foundation
import CoreLocation
import Combine

/// 位置服务
class LocationService: NSObject, ObservableObject {
    private let locationManager = CLLocationManager()
    private var cancellables = Set<AnyCancellable>()
    
    // 发布属性
    @Published var currentLocation: CLLocation?
    @Published var currentSpeed: Double = 0
    @Published var currentAltitude: Double = 0
    @Published var hasLocation = false
    @Published var authorizationStatus: CLAuthorizationStatus = .notDetermined
    @Published var locationAccuracyLevel: Int = 0
    
    // 精度阈值
    private let minimumAccuracy: CLLocationAccuracy = 50  // 50米以内视为可用
    
    override init() {
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBestForNavigation
        locationManager.distanceFilter = 5  // 每5米更新一次
        locationManager.allowsBackgroundLocationUpdates = true
        locationManager.pausesLocationUpdatesAutomatically = false
        locationManager.activityType = .fitness  // 运动模式
        
        // 初始化时检查状态
        authorizationStatus = locationManager.authorizationStatus
    }
    
    /// 请求定位权限
    func requestAuthorization() {
        locationManager.requestWhenInUseAuthorization()
        // 延迟请求后台权限
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) { [weak self] in
            self?.locationManager.requestAlwaysAuthorization()
        }
    }
    
    /// 开始定位更新
    func startUpdatingLocation() {
        locationManager.startUpdatingLocation()
        hasLocation = false
    }
    
    /// 停止定位更新
    func stopUpdatingLocation() {
        locationManager.stopUpdatingLocation()
    }
    
    /// 计算信号强度等级 (0-4)
    private func calculateAccuracyLevel(_ location: CLLocation) -> Int {
        let accuracy = location.horizontalAccuracy
        if accuracy < 10 { return 4 }
        if accuracy < 20 { return 3 }
        if accuracy < 50 { return 2 }
        if accuracy < 100 { return 1 }
        return 0
    }
}

// MARK: - CLLocationManagerDelegate
extension LocationService: CLLocationManagerDelegate {
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        
        // 过滤低精度位置
        guard location.horizontalAccuracy <= minimumAccuracy else {
            print("⚠️ 位置精度不足: \(location.horizontalAccuracy)m")
            return
        }
        
        DispatchQueue.main.async { [weak self] in
            self?.currentLocation = location
            self?.currentSpeed = max(0, location.speed)  // 转换为km/h在UI层
            self?.currentAltitude = location.altitude
            self?.hasLocation = true
            self?.locationAccuracyLevel = self?.calculateAccuracyLevel(location) ?? 0
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("❌ 定位失败: \(error.localizedDescription)")
        DispatchQueue.main.async { [weak self] in
            self?.hasLocation = false
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        DispatchQueue.main.async { [weak self] in
            self?.authorizationStatus = status
            
            switch status {
            case .authorizedWhenInUse, .authorizedAlways:
                self?.startUpdatingLocation()
            case .denied, .restricted:
                self?.hasLocation = false
            case .notDetermined:
                break
            @unknown default:
                break
            }
        }
    }
}

// MARK: - 权限检查扩展
extension LocationService {
    var canUseLocation: Bool {
        authorizationStatus == .authorizedWhenInUse || authorizationStatus == .authorizedAlways
    }
    
    var needsAuthorization: Bool {
        authorizationStatus == .notDetermined
    }
    
    var isDenied: Bool {
        authorizationStatus == .denied || authorizationStatus == .restricted
    }
}
