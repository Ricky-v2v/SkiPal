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
        case .idle: return NSLocalizedString("未同步", comment: "Sync status")
        case .syncing(let progress):
            return String(format: NSLocalizedString("同步中 %.0f%%", comment: "Sync status"), progress * 100)
        case .success(let lastSync):
            return String(format: NSLocalizedString("已同步 • %@", comment: "Sync status"), formatDate(lastSync))
        case .error(let message):
            return String(format: NSLocalizedString("同步失败：%@", comment: "Sync status"), message)
        case .offline: return NSLocalizedString("离线模式", comment: "Sync status")
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
    
    /// iCloud 私有数据库。
    ///
    /// 为 nil 表示当前构建没有可用的 iCloud 能力（缺少 entitlement 或未登录 iCloud），
    /// 此时所有同步操作会优雅降级，不会崩溃。
    private let database: CKDatabase?
    private let recordType = "SkiSession"
    private let queue = DispatchQueue(label: "com.skipal.cloudkit", qos: .userInitiated)
    private var networkMonitor: NWPathMonitor?
    
    // 本地缓存的 record ID
    private var localRecordIDs: [UUID: CKRecord.ID] = [:]
    
    private init() {
        self.database = Self.makeDatabase()
        setupNetworkMonitoring()
        if self.database == nil {
            self.syncStatus = .error(message: "此构建未启用 iCloud 同步")
            self.isOfflineMode = true
        }
    }
    
    /// 创建 CloudKit 数据库；当前构建不具备 iCloud 能力时返回 nil。
    ///
    /// 注意：`CKContainer` 的任何初始化在缺少 iCloud entitlement 的构建中都会直接
    /// 触发 fatalError（未捕获异常，应用启动即崩溃）。因此必须先探测 iCloud 身份令牌，
    /// 确认可用后再触碰 CloudKit API。
    ///
    /// 开发者启用 iCloud 的步骤见 QUICKSTART.md：
    /// 1. 在 Xcode 为 SkiPal target 添加 iCloud capability 并勾选 CloudKit；
    /// 2. 在 Info.plist 填入 `SkiPalCloudKitContainerIdentifier`（你的容器 ID，
    ///    例如 `iCloud.com.yourcompany.skipal`），留空则使用默认容器。
    private static func makeDatabase() -> CKDatabase? {
        guard FileManager.default.ubiquityIdentityToken != nil else {
            print("ℹ️ 未检测到 iCloud 身份令牌，跳过 CloudKit 初始化（缺少 entitlement 或未登录 iCloud）")
            return nil
        }
        
        let container: CKContainer
        if let identifier = Bundle.main.object(forInfoDictionaryKey: "SkiPalCloudKitContainerIdentifier") as? String,
           !identifier.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            container = CKContainer(identifier: identifier)
        } else {
            container = CKContainer.default()
        }
        return container.privateCloudDatabase
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
        guard let database = database else {
            throw CloudKitUnavailableError.disabled
        }
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
            defer {
                removeTemporaryAssetFiles(from: record)
            }
            
            // 保存记录
            _ = try await database.save(record)
            
            await MainActor.run {
                syncStatus = .success(lastSync: Date())
                print("✅ 会话同步成功：\(session.id)")
            }
        } catch let error as CKError
            where error.code == .networkUnavailable || error.code == .networkFailure {
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
        guard let database = database else {
            throw CloudKitUnavailableError.disabled
        }
        guard !isOfflineMode else {
            return []
        }
        
        let query = CKQuery(recordType: recordType, predicate: NSPredicate(value: true))
        query.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        
        do {
            var sessions: [SkiSession] = []
            var results = try await database.records(matching: query)

            while true {
                for (_, recordResult) in results.matchResults {
                    let record = try recordResult.get()
                    if let session = decodeSession(from: record) {
                        sessions.append(session)
                        localRecordIDs[session.id] = record.recordID
                    }
                }

                guard let cursor = results.queryCursor else { break }
                results = try await database.records(continuingMatchFrom: cursor)
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
        guard let database = database else {
            throw CloudKitUnavailableError.disabled
        }
        guard let recordID = localRecordIDs[session.id] else {
            // 尝试通过查询找到记录 ID
            let query = CKQuery(recordType: recordType, predicate: NSPredicate(format: "sessionID == %@", session.id.uuidString))
            let results = try await database.records(matching: query)
            
            if let recordID = results.matchResults.first?.0 {
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
        let record = session.toCloudKitRecord()
        
        // 缓存记录 ID
        localRecordIDs[session.id] = record.recordID
        
        return record
    }
    
    private func decodeSession(from record: CKRecord) -> SkiSession? {
        SkiSession.fromCloudKitRecord(record)
    }

    /// 删除上传完成后不再需要的临时资产文件。
    private func removeTemporaryAssetFiles(from record: CKRecord) {
        for key in record.allKeys() {
            guard let asset = record[key] as? CKAsset, let fileURL = asset.fileURL else {
                continue
            }
            try? FileManager.default.removeItem(at: fileURL)
        }
    }
}

/// iCloud 同步不可用时的错误（当前构建未配置 iCloud 能力）
enum CloudKitUnavailableError: LocalizedError {
    case disabled
    
    var errorDescription: String? {
        switch self {
        case .disabled:
            return "此构建未启用 iCloud 同步（请配置 iCloud entitlement 与容器 ID）"
        }
    }
}
