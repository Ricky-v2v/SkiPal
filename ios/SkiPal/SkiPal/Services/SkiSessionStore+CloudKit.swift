//
//  SkiSessionStore+CloudKit.swift
//  SkiPal
//
//  SkiSessionStore CloudKit 同步扩展
//

import Foundation
import CloudKit
import Combine

extension SkiSessionStore {
    /// 同步会话到 iCloud
    func syncSessionToCloud(_ session: SkiSession) async {
        do {
            try await CloudKitSyncService.shared.syncSession(session)
        } catch {
            print("❌ 同步会话到 iCloud 失败：\(error.localizedDescription)")
        }
    }
    
    /// 从 iCloud 加载所有会话
    func loadSessionsFromCloud() async {
        do {
            let cloudSessions = try await CloudKitSyncService.shared.fetchAllSessions()
            
            // 合并本地和云端会话 (去重)
            await MainActor.run {
                var mergedSessions = self.sessions
                
                for cloudSession in cloudSessions {
                    if !mergedSessions.contains(where: { $0.id == cloudSession.id }) {
                        mergedSessions.append(cloudSession)
                    }
                }
                
                // 按开始时间排序 (最新的在前)
                mergedSessions.sort { $0.startTime > $1.startTime }
                self.sessions = mergedSessions
                self.updateCloudKitStatistics()
                
                print("✅ 从 iCloud 同步完成，共 \(self.sessions.count) 个会话")
            }
        } catch {
            print("❌ 从 iCloud 加载会话失败：\(error.localizedDescription)")
        }
    }
    
    /// 删除会话 (包括云端)
    func deleteSessionWithSync(_ session: SkiSession) async {
        // 先从本地删除
        await MainActor.run {
            self.deleteSession(session)
        }
        
        // 然后从云端删除
        do {
            try await CloudKitSyncService.shared.deleteSession(session)
        } catch {
            print("❌ 从 iCloud 删除会话失败：\(error.localizedDescription)")
        }
    }

    /// 统计方法为 SkiSessionStore 的文件私有成员，云同步扩展在这里同步公开统计字段。
    private func updateCloudKitStatistics() {
        sessionCount = sessions.count
        totalDistance = sessions.reduce(0) { $0 + $1.totalDistance }
        totalDuration = sessions.reduce(0) { $0 + $1.duration }
    }
}
