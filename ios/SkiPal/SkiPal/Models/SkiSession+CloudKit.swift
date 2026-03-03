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
            record["sessionData"] = CKRecord.Value(CKAsset(data: data))
        }
        
        record["sessionID"] = CKRecord.Value(CKAsset(string: id.uuidString))
        record["startTime"] = CKRecord.Value(CKAsset(date: startTime))
        record["endTime"] = CKRecord.Value(CKAsset(date: endTime ?? Date()))
        record["resortName"] = CKRecord.Value(CKAsset(string: resortName ?? ""))
        record["modifiedDate"] = CKRecord.Value(CKAsset(date: Date()))
        
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
            switch sessionData {
            case let .asset(asset):
                if let data = asset.data {
                    return try decoder.decode(SkiSession.self, from: data)
                }
            default:
                break
            }
        } catch {
            print("❌ 从 CloudKit 记录解码失败：\(error.localizedDescription)")
        }
        
        return nil
    }
}

// MARK: - CKRecordValue 扩展
extension CKRecordValue {
    convenience init(_ asset: CKAsset) {
        self.init(asset)
    }
}

extension CKAsset {
    convenience init(string: String) {
        self.init(data: string.data(using: .utf8))
    }
    
    convenience init(date: Date) {
        let formatter = ISO8601DateFormatter()
        let string = formatter.string(from: date)
        self.init(string: string)
    }
}
