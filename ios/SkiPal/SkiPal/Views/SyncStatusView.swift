//
//  SyncStatusView.swift
//  SkiPal
//
//  同步状态指示器视图
//

import SwiftUI

/// 同步状态指示器
struct SyncStatusView: View {
    @ObservedObject var syncService: CloudKitSyncService
    @State private var showingSyncDetails = false
    
    var body: some View {
        Button(action: { showingSyncDetails = true }) {
            HStack(spacing: 6) {
                syncStatusIcon
                
                Text(syncService.syncStatus.description)
                    .font(.caption2)
                    .foregroundColor(syncStatusColor)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(syncStatusBackgroundColor)
            .cornerRadius(8)
        }
        .sheet(isPresented: $showingSyncDetails) {
            SyncDetailsView()
        }
    }
    
    private var syncStatusIcon: some View {
        Group {
            switch syncService.syncStatus {
            case .idle:
                Image(systemName: "icloud")
                    .font(.caption)
            case .syncing:
                Image(systemName: "arrow.clockwise")
                    .font(.caption)
                    .rotationEffect(.degrees(isAnimating ? 360 : 0))
                    .animation(.linear(duration: 1).repeatForever(autoreverses: false), value: isAnimating)
            case .success:
                Image(systemName: "checkmark.circle.fill")
                    .font(.caption)
            case .error:
                Image(systemName: "exclamationmark.circle.fill")
                    .font(.caption)
            case .offline:
                Image(systemName: "slash.circle")
                    .font(.caption)
            }
        }
        .foregroundColor(syncStatusColor)
    }
    
    private var syncStatusColor: Color {
        switch syncService.syncStatus {
        case .idle:
            return .secondary
        case .syncing:
            return .blue
        case .success:
            return .green
        case .error:
            return .red
        case .offline:
            return .orange
        }
    }
    
    private var syncStatusBackgroundColor: Color {
        switch syncService.syncStatus {
        case .idle:
            return Color(.systemGray6)
        case .syncing:
            return Color.blue.opacity(0.1)
        case .success:
            return Color.green.opacity(0.1)
        case .error:
            return Color.red.opacity(0.1)
        case .offline:
            return Color.orange.opacity(0.1)
        }
    }
    
    @State private var isAnimating = false
    private var syncTimer: Timer?
    
    init(syncService: CloudKitSyncService = .shared) {
        self.syncService = syncService
        _isAnimating = State(initialValue: true)
    }
}

/// 同步详情视图
struct SyncDetailsView: View {
    @ObservedObject var syncService = CloudKitSyncService.shared
    @Environment(\.dismiss) var dismiss
    @State private var syncTask: Task<Void, Never>?
    @State private var isSyncing = false
    
    var body: some View {
        NavigationView {
            List {
                // 当前状态
                Section(header: Text("同步状态")) {
                    HStack {
                        Text("状态")
                        Spacer()
                        Text(syncService.syncStatus.description)
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Text("离线模式")
                        Spacer()
                        Toggle("", isOn: $syncService.isOfflineMode)
                    }
                    
                    if syncService.pendingChanges > 0 {
                        HStack {
                            Text("待同步更改")
                            Spacer()
                            Text("\(syncService.pendingChanges) 项")
                                .foregroundColor(.orange)
                        }
                    }
                }
                
                // 操作
                Section(header: Text("操作")) {
                    Button(action: syncNow) {
                        HStack {
                            Image(systemName: "arrow.clockwise")
                            Text("立即同步")
                            Spacer()
                            if isSyncing {
                                ProgressView()
                                    .scaleEffect(0.8)
                            }
                        }
                    }
                    .disabled(isSyncing || syncService.isOfflineMode)
                    
                    Button(action: showCloudKitSettings) {
                        HStack {
                            Image(systemName: "gear")
                            Text("iCloud 设置")
                            Spacer()
                        }
                    }
                }
                
                // 帮助
                Section(header: Text("说明")) {
                    Text("SkiPal 使用 iCloud 自动同步您的滑雪记录。所有设备上的数据将保持最新。")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    if syncService.isOfflineMode {
                        Text("⚠️ 当前处于离线模式。更改将保存在本地，待网络恢复后自动同步。")
                            .font(.caption)
                            .foregroundColor(.orange)
                    }
                }
            }
            .navigationTitle("iCloud 同步")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("完成") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private func syncNow() {
        syncTask?.cancel()

        isSyncing = true
        
        syncTask = Task {
            // 触发同步
            await syncService.fetchAllSessionsFromCloud()
            // Haptic feedback
            let impact = UIImpactFeedbackGenerator(style: .success)
            impact.impactOccurred()            isSyncing = false
        }
    }
    
    private func showCloudKitSettings() {
        // 打开系统设置
        if let url = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(url)
        }
    }
}

// MARK: - 扩展 CloudKitSyncService 用于视图
extension CloudKitSyncService {
    func fetchAllSessionsFromCloud() async {
        do {
            _ = try await fetchAllSessions()
            await MainActor.run {
                syncStatus = .success(lastSync: Date())
            }
        } catch {
            await MainActor.run {
                syncStatus = .error(message: error.localizedDescription)
            }
        }
    }
}

// MARK: - 预览
struct SyncStatusView_Previews: PreviewProvider {
    static var previews: some View {
        SyncStatusView()
    }
}
