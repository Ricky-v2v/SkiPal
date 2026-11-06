//
//  SkiSession+CloudKit.swift
//  SkiPal
//
//  SkiSession CloudKit 扩展
//

import Foundation
import CloudKit

extension SkiSession {
    /// 转换为 CloudKit 记录
    func toCloudKitRecord() -> CKRecord {
        let recordID = CKRecord.ID(recordName: id.uuidString)
        let record = CKRecord(recordType: "SkiSession", recordID: recordID)
        
        // 编码会话数据
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        
        if let data = try? encoder.encode(self) {
            record["sessionData"] = makeSessionDataAsset(from: data)
        }
        
        record["sessionID"] = id.uuidString
        record["startTime"] = startTime
        record["endTime"] = endTime ?? Date()
        record["resortName"] = resortName ?? ""
        record["modifiedDate"] = Date()
        
        return record
    }
    
    /// 从 CloudKit 记录解码
    static func fromCloudKitRecord(_ record: CKRecord) -> SkiSession? {
        guard let sessionData = record["sessionData"] else {
            return nil
        }
        
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        
        do {
            if let asset = sessionData as? CKAsset, let fileURL = asset.fileURL {
                let data = try Data(contentsOf: fileURL)
                return try decoder.decode(SkiSession.self, from: data)
            }

            // 兼容旧版本直接把 JSON Data 写入该字段的记录。
            if let data = sessionData as? Data {
                return try decoder.decode(SkiSession.self, from: data)
            }
        } catch {
            print("❌ 从 CloudKit 记录解码失败：\(error.localizedDescription)")
        }

        return nil
    }
}

private extension SkiSession {
    /// CKAsset 只接受文件 URL，临时文件需在 CloudKit 保存完成前保留。
    func makeSessionDataAsset(from data: Data) -> CKAsset? {
        let fileName = "SkiPal-\(id.uuidString)-\(UUID().uuidString).json"
        let fileURL = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)

        do {
            try data.write(to: fileURL, options: .atomic)
            return CKAsset(fileURL: fileURL)
        } catch {
            print("❌ 创建 CloudKit 资产文件失败：\(error.localizedDescription)")
            return nil
        }
    }
}
