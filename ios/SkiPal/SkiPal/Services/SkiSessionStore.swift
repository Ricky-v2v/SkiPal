//
//  SkiSessionStore.swift
//  SkiPal
//
//  会话存储 - 管理历史记录持久化
//

import Foundation
import Combine

/// 滑雪会话存储
class SkiSessionStore: ObservableObject {
    @Published var sessions: [SkiSession] = []
    @Published var totalDistance: Double = 0
    @Published var totalDuration: TimeInterval = 0
    @Published var sessionCount: Int = 0
    
    private let saveKey = "skipal_sessions"
    private let userDefaults = UserDefaults.standard
    
    init() {
        loadSessions()
    }
    
    // MARK: - 数据操作
    
    /// 添加新会话
    func addSession(_ session: SkiSession) {
        sessions.insert(session, at: 0)  // 最新的在前面
        saveSessions()
        updateStatistics()
    }
    
    /// 删除会话
    func deleteSession(_ session: SkiSession) {
        sessions.removeAll { $0.id == session.id }
        saveSessions()
        updateStatistics()
    }
    
    /// 删除指定索引的会话
    func deleteSession(at indexSet: IndexSet) {
        sessions.remove(atOffsets: indexSet)
        saveSessions()
        updateStatistics()
    }
    
    /// 获取最近的几条记录
    func recentSessions(limit: Int = 5) -> [SkiSession] {
        Array(sessions.prefix(limit))
    }
    
    // MARK: - 统计计算
    
    private func updateStatistics() {
        sessionCount = sessions.count
        totalDistance = sessions.reduce(0) { $0 + $1.totalDistance }
        totalDuration = sessions.reduce(0) { $0 + $1.duration }
    }
    
    /// 个人最佳速度
    var personalBestSpeed: Double {
        sessions.map { $0.maxSpeed }.max() ?? 0
    }
    
    /// 最长距离
    var longestDistance: Double {
        sessions.map { $0.totalDistance }.max() ?? 0
    }
    
    /// 最长时长
    var longestDuration: TimeInterval {
        sessions.map { $0.duration }.max() ?? 0
    }
    
    /// 累计滑行次数
    var totalRuns: Int {
        sessions.count
    }
    
    // MARK: - 持久化
    
    private func saveSessions() {
        do {
            let data = try JSONEncoder().encode(sessions)
            userDefaults.set(data, forKey: saveKey)
            updateStatistics()
        } catch {
            print("❌ 保存会话失败: \(error.localizedDescription)")
        }
    }
    
    private func loadSessions() {
        guard let data = userDefaults.data(forKey: saveKey) else {
            sessions = []
            updateStatistics()
            return
        }
        
        do {
            sessions = try JSONDecoder().decode([SkiSession].self, from: data)
            updateStatistics()
        } catch {
            print("❌ 加载会话失败: \(error.localizedDescription)")
            sessions = []
        }
    }
    
    // MARK: - 导出功能
    
    /// 导出为GPX格式
    func exportSessionAsGPX(_ session: SkiSession) -> String {
        var gpx = """<?xml version="1.0" encoding="UTF-8"?>
<gpx version="1.1" creator="SkiPal" xmlns="http://www.topografix.com/GPX/1/1">
  <trk>
    <name>\(session.resortName ?? "滑雪记录")</name>
    <time>\(ISO8601DateFormatter().string(from: session.startTime))</time>
    <trkseg>
"""
        
        for location in session.locations {
            gpx += """
      <trkpt lat="\(location.latitude)" lon="\(location.longitude)">
        <ele>\(location.altitude)</ele>
        <time>\(ISO8601DateFormatter().string(from: location.timestamp))</time>
      </trkpt>
"""
        }
        
        gpx += """
    </trkseg>
  </trk>
</gpx>
"""
        return gpx
    }
    
    /// 生成分享文本
    func generateShareText(for session: SkiSession) -> String {
        """
        🎿 刚完成一次超棒的滑雪！
        
        📍 雪场：\(session.resortName ?? "未知雪场")
        📏 距离：\(String(format: "%.1f", session.totalDistance / 1000)) km
        ⏱️ 用时：\(session.formattedDuration)
        🏃 平均速度：\(String(format: "%.1f", session.averageSpeed * 3.6)) km/h
        🚀 最大速度：\(String(format: "%.1f", session.maxSpeed * 3.6)) km/h
        ⬆️ 海拔上升：\(String(format: "%.0f", session.elevationGain)) m
        
        \(session.achievementTitle)
        
        #SkiPal #滑雪 # wintersports
        """
    }
}
