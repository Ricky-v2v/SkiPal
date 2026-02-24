//
//  SkiSession.swift
//  SkiPal
//
//  滑雪会话数据模型
//

import Foundation
import CoreLocation

/// 滑雪会话模型
struct SkiSession: Identifiable, Codable {
    let id: UUID
    var startTime: Date
    var endTime: Date?
    var locations: [SkiLocation]
    var resortName: String?
    
    // 计算属性
    var duration: TimeInterval {
        guard let endTime = endTime else { return Date().timeIntervalSince(startTime) }
        return endTime.timeIntervalSince(startTime)
    }
    
    var totalDistance: Double {
        guard locations.count > 1 else { return 0 }
        var distance: Double = 0
        for i in 1..<locations.count {
            let prev = locations[i-1]
            let curr = locations[i]
            distance += curr.location.distance(from: prev.location)
        }
        return distance
    }
    
    var maxSpeed: Double {
        locations.map { $0.speed }.max() ?? 0
    }
    
    var averageSpeed: Double {
        guard !locations.isEmpty else { return 0 }
        let totalSpeed = locations.reduce(0) { $0 + $1.speed }
        return totalSpeed / Double(locations.count)
    }
    
    var elevationGain: Double {
        guard locations.count > 1 else { return 0 }
        var gain: Double = 0
        for i in 1..<locations.count {
            let prev = locations[i-1]
            let curr = locations[i]
            if curr.altitude > prev.altitude {
                gain += curr.altitude - prev.altitude
            }
        }
        return gain
    }
    
    var formattedDuration: String {
        let hours = Int(duration) / 3600
        let minutes = Int(duration) / 60 % 60
        let seconds = Int(duration) % 60
        
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        } else {
            return String(format: "%02d:%02d", minutes, seconds)
        }
    }
    
    // 初始化
    init(id: UUID = UUID(), startTime: Date = Date(), locations: [SkiLocation] = [], resortName: String? = nil) {
        self.id = id
        self.startTime = startTime
        self.locations = locations
        self.resortName = resortName
    }
}

/// 滑雪位置点
struct SkiLocation: Identifiable, Codable {
    let id: UUID
    let timestamp: Date
    let latitude: Double
    let longitude: Double
    let altitude: Double
    let speed: Double
    let course: Double
    
    var location: CLLocation {
        CLLocation(
            coordinate: CLLocationCoordinate2D(latitude: latitude, longitude: longitude),
            altitude: altitude,
            horizontalAccuracy: 0,
            verticalAccuracy: 0,
            timestamp: timestamp
        )
    }
    
    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
    
    init(from location: CLLocation) {
        self.id = UUID()
        self.timestamp = location.timestamp
        self.latitude = location.coordinate.latitude
        self.longitude = location.coordinate.longitude
        self.altitude = location.altitude
        self.speed = max(0, location.speed)
        self.course = location.course
    }
}

// MARK: - 统计扩展
extension SkiSession {
    /// 获取坡度百分比（基于最后两个点）
    var currentSlope: Double {
        guard locations.count >= 2 else { return 0 }
        let last = locations[locations.count - 1]
        let prev = locations[locations.count - 2]
        
        let distance = last.location.distance(from: prev.location)
        guard distance > 0 else { return 0 }
        
        let elevationDiff = last.altitude - prev.altitude
        return atan(elevationDiff / distance) * 180 / .pi
    }
    
    /// 坡度等级
    var slopeLevel: SlopeLevel {
        let slope = abs(currentSlope)
        switch slope {
        case 0..<15: return .beginner
        case 15..<30: return .intermediate
        case 30..<40: return .advanced
        default: return .expert
        }
    }
}

/// 坡度等级
enum SlopeLevel: String, CaseIterable {
    case beginner = "初级"
    case intermediate = "中级"
    case advanced = "高级"
    case expert = "专家"
    
    var color: String {
        switch self {
        case .beginner: return "#34C759"  // 绿色
        case .intermediate: return "#007AFF"  // 蓝色
        case .advanced: return "#000000"  // 黑色
        case .expert: return "#FF3B30"  // 红色
        }
    }
    
    var icon: String {
        switch self {
        case .beginner: return "🟢"
        case .intermediate: return "🔵"
        case .advanced: return "⚫"
        case .expert: return "🔴"
        }
    }
}

// MARK: - 成就系统
extension SkiSession {
    /// 计算成就星级 (0-5)
    var achievementStars: Int {
        var stars = 1  // 完成即1星
        
        if maxSpeed > 30 { stars += 1 }  // 速度>30km/h
        if totalDistance > 5000 { stars += 1 }  // 距离>5km
        if totalDistance > 10000 { stars += 1 }  // 距离>10km
        if isPersonalRecord { stars += 1 }  // 破纪录
        
        return min(stars, 5)
    }
    
    /// 是否打破个人记录
    var isPersonalRecord: Bool {
        // 简化实现，实际应该对比历史数据
        return maxSpeed > 40 || totalDistance > 8000
    }
    
    /// 成就标题
    var achievementTitle: String {
        switch achievementStars {
        case 5: return "🏆 传奇滑手"
        case 4: return "⭐⭐⭐⭐ 滑雪健将"
        case 3: return "⭐⭐⭐ 耐力王"
        case 2: return "⭐⭐ 速度达人"
        default: return "⭐ 初雪者"
        }
    }
}
