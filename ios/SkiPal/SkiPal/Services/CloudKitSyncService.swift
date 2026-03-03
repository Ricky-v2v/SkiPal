//
//  CloudKitSyncService.swift
//  SkiPal
//
//  iCloud 同步服务 - 使用 CloudKit 同步滑雪记录
//

import Foundation
import CloudKit
import Combine
import Network

/// 同步状态
enum SyncStatus: Equatable {
    case idle
    case syncing(progress: Double)
    case success(lastSync: Date)
    case error(message: String)
    case offline
    
    var description: String {
        switch self {
        case .idle: return "未同步"
        case .syncing(let progress): return String(format: "同步中 %.0f%%", progress * 100)
        case .success(let lastSync): return "已同步 • \(formatDate(lastSync))"
        case .error(let message): return "同步失败：\(message)"
        case .offline: return "离线模式"
        }
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

/// CloudKit 同步服务
class CloudKitSyncService: ObservableObject {
    @Published var syncStatus: SyncStatus = .idle
    @Published var isOfflineMode = false
    @Published var pendingChanges: Int = 0
    
    static let shared = CloudKitSyncService()
    
    private let database: CKDatabase
    private let recordType = "SkiSession"
    private let queue = DispatchQueue(label: "com.skipal.cloudkit", qos: .userInitiated)
    private var networkMonitor: NWPathMonitor?
    
    // 本地缓存的 record ID
    private var localRecordIDs: [UUID: CKRecord.ID] = [:]
    
    private init() {
        self.database = CKContainer.default().privateCloudDatabase
        setupNetworkMonitoring()
    }
    
    deinit {
        networkMonitor?.cancel()
        NotificationCenter.default.removeObserver(self)
    }
    
    // MARK: - 网络状态监控
    
    private func setupNetworkMonitoring() {
        // 使用 NWPathMonitor 监控网络状态
        let monitor = NWPathMonitor()
        monitor.pathUpdateHandler = { [weak self] path in
            DispatchQueue.main.async {
                self?.isOfflineMode = (path.status == .unsatisfied)
                self?.syncStatus = (path.status == .unsatisfied) ? .offline : .idle
            }
        }
        monitor.start(queue: queue)
        networkMonitor = monitor
    }
    
    // MARK: - 同步操作
    
    /// 同步单个会话到 CloudKit
    func syncSession(_ session: SkiSession) async throws {
        guard !isOfflineMode else {
            print("⚠️ 离线模式，跳过同步")
            return
        }
        
        await MainActor.run {
            syncStatus = .syncing(progress: 0.1)
        }
        
        do {
            // 创建或更新记录
            let record = try await createOrUpdateRecord(for: session)
            
            // 保存记录
            try await database.save(record)
            
            await MainActor.run {
                syncStatus = .success(lastSync: Date())
                print("✅ 会话同步成功：\(session.id)")
            }
        } catch CKError.networkUnavailable, CKError.networkConnectionFailure {
            await MainActor.run {
                isOfflineMode = true
                syncStatus = .offline
                pendingChanges += 1
            }
            print("⚠️ 网络不可用，标记为待同步")
        } catch {
            await MainActor.run {
                syncStatus = .error(message: error.localizedDescription)
            }
            print("❌ 同步失败：\(error.localizedDescription)")
            throw error
        }
    }
    
    /// 从 CloudKit 获取所有会话
    func fetchAllSessions() async throws -> [SkiSession] {
        guard !isOfflineMode else {
            return []
        }
        
        let query = CKQuery(recordType: recordType, predicate: NSPredicate(value: true))
        query.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        
        do {
            let results = try await database.fetch(withQuery: query)
            
            var sessions: [SkiSession] = []
            for record in results {
                if let session = decodeSession(from: record) {
                    sessions.append(session)
                    localRecordIDs[session.id] = record.recordID
                }
            }
            
            print("✅ 从 iCloud 获取 \(sessions.count) 个会话")
            return sessions
        } catch {
            print("❌ 获取会话失败：\(error.localizedDescription)")
            throw error
        }
    }
    
    /// 删除 CloudKit 中的会话
    func deleteSession(_ session: SkiSession) async throws {
        guard let recordID = localRecordIDs[session.id] else {
            // 尝试通过查询找到记录 ID
            let query = CKQuery(recordType: recordType, predicate: NSPredicate(format: "sessionID == %@", session.id.uuidString))
            let results = try await database.fetch(withQuery: query)
            
            if let recordID = results.first?.recordID {
                try await database.deleteRecord(withID: recordID)
                localRecordIDs.removeValue(forKey: session.id)
            }
            return
        }
        
        try await database.deleteRecord(withID: recordID)
        localRecordIDs.removeValue(forKey: session.id)
        print("✅ 会话已从 iCloud 删除")
    }
    
    /// 解决冲突 (最新获胜)
    func resolveConflict(local session: SkiSession, remote: SkiSession) -> SkiSession {
        // 最新修改获胜
        if let localEnd = session.endTime, let remoteEnd = remote.endTime {
            return localEnd > remoteEnd ? session : remote
        }
        return session.startTime > remote.startTime ? session : remote
    }
    
    // MARK: - 私有方法
    
    private func createOrUpdateRecord(for session: SkiSession) async throws -> CKRecord {
        let recordID = localRecordIDs[session.id] ?? CKRecord.ID(recordName: session.id.uuidString)
        let record = CKRecord(recordType: recordType, recordID: recordID)
        
        // 编码会话数据 - 直接存储 Data 到 CKRecord
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(session)
        
        // 使用 CKRecordValue 协议正确存储数据
        record["sessionData"] = data
        record["sessionID"] = session.id.uuidString
        record["startTime"] = session.startTime
        record["endTime"] = session.endTime ?? Date()
        record["resortName"] = session.resortName ?? ""
        record["modifiedDate"] = Date()
        
        // 缓存记录 ID
        localRecordIDs[session.id] = record.recordID
        
        return record
    }
    
    private func decodeSession(from record: CKRecord) -> SkiSession? {
        guard let sessionData = record["sessionData"] as? Data else {
            return nil
        }
        
        do {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            return try decoder.decode(SkiSession.self, from: sessionData)
        } catch {
            print("❌ 解码会话失败：\(error.localizedDescription)")
        }
        
        return nil
    }
}
