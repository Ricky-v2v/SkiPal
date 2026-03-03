//
//  SkiResort.swift
//  SkiPal
//
//  雪场数据模型
//

import Foundation
import CoreLocation

/// 雪道难度分布
struct DifficultyDistribution: Codable {
    let beginner: Int       // 初级道数量
    let intermediate: Int   // 中级道数量
    let advanced: Int       // 高级道数量
    let expert: Int         // 专家道数量

    /// 总雪道数
    var total: Int {
        beginner + intermediate + advanced + expert
    }
}

/// 雪场模型
struct SkiResort: Identifiable, Codable, Hashable {
    let id: UUID
    let name: String            // 雪场名称
    let nameEn: String?         // 英文名称
    let country: String         // 国家
    let region: String          // 省份/地区
    let latitude: Double        // 纬度
    let longitude: Double       // 经度
    let baseElevation: Double   // 基础海拔 (m)
    let summitElevation: Double // 顶峰海拔 (m)
    let totalRuns: Int          // 雪道总数
    let difficultyDistribution: DifficultyDistribution
    let website: String?        // 官网
    let imageUrl: String?       // 图片 URL

    /// 雪场中心位置
    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    /// 雪场 CLLocation 对象
    var location: CLLocation {
        CLLocation(latitude: latitude, longitude: longitude)
    }

    /// 海拔落差 (米)
    var verticalDrop: Double {
        summitElevation - baseElevation
    }

    /// 判断是否为知名大雪场 (雪道数 > 50)
    var isMajorResort: Bool {
        totalRuns > 50
    }

    /// 等级分布百分比描述
    var difficultyDescription: String {
        let total = difficultyDistribution.total
        guard total > 0 else { return "暂无数据" }

        let beginnerPct = Double(difficultyDistribution.beginner) / Double(total) * 100
        let intermediatePct = Double(difficultyDistribution.intermediate) / Double(total) * 100
        let advancedPct = Double(difficultyDistribution.advanced) / Double(total) * 100

        return String(format: "初级 %.0f%% · 中级 %.0f%% · 高级 %.0f%%",
                      beginnerPct, intermediatePct, advancedPct)
    }

    /// 自定义 Decodable 初始化 - 处理 JSON 中的 string ID
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        // 处理 string 或 UUID 格式的 ID
        let idString = try container.decode(String.self, forKey: .id)
        self.id = UUID(uuidString: idString) ?? UUID()
        
        self.name = try container.decode(String.self, forKey: .name)
        self.nameEn = try container.decodeIfPresent(String.self, forKey: .nameEn)
        self.country = try container.decode(String.self, forKey: .country)
        self.region = try container.decode(String.self, forKey: .region)
        self.latitude = try container.decode(Double.self, forKey: .latitude)
        self.longitude = try container.decode(Double.self, forKey: .longitude)
        self.baseElevation = try container.decode(Double.self, forKey: .baseElevation)
        self.summitElevation = try container.decode(Double.self, forKey: .summitElevation)
        self.totalRuns = try container.decode(Int.self, forKey: .totalRuns)
        self.difficultyDistribution = try container.decode(DifficultyDistribution.self, forKey: .difficultyDistribution)
        self.website = try container.decodeIfPresent(String.self, forKey: .website)
        self.imageUrl = try container.decodeIfPresent(String.self, forKey: .imageUrl)
    }

    /// 初始化
    init(
        id: UUID = UUID(),
        name: String,
        nameEn: String? = nil,
        country: String,
        region: String,
        latitude: Double,
        longitude: Double,
        baseElevation: Double,
        summitElevation: Double,
        totalRuns: Int,
        difficultyDistribution: DifficultyDistribution,
        website: String? = nil,
        imageUrl: String? = nil
    ) {
        self.id = id
        self.name = name
        self.nameEn = nameEn
        self.country = country
        self.region = region
        self.latitude = latitude
        self.longitude = longitude
        self.baseElevation = baseElevation
        self.summitElevation = summitElevation
        self.totalRuns = totalRuns
        self.difficultyDistribution = difficultyDistribution
        self.website = website
        self.imageUrl = imageUrl
    }

    // MARK: - Hashable

    static func == (lhs: SkiResort, rhs: SkiResort) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

// MARK: - 用户自定义雪场

/// 用户添加的雪场（本地存储）
struct UserResort: Identifiable, Codable {
    let id: UUID
    let name: String
    let country: String
    let region: String
    let latitude: Double
    let longitude: Double
    let createdAt: Date
    var isSynced: Bool  // 是否已同步到服务器（未来功能）

    init(
        id: UUID = UUID(),
        name: String,
        country: String,
        region: String,
        latitude: Double,
        longitude: Double
    ) {
        self.id = id
        self.name = name
        self.country = country
        self.region = region
        self.latitude = latitude
        self.longitude = longitude
        self.createdAt = Date()
        self.isSynced = false
    }

    /// 转换为 SkiResort（用于统一处理）
    func toSkiResort() -> SkiResort {
        SkiResort(
            id: id,
            name: name,
            country: country,
            region: region,
            latitude: latitude,
            longitude: longitude,
            baseElevation: 0,
            summitElevation: 0,
            totalRuns: 0,
            difficultyDistribution: DifficultyDistribution(beginner: 0, intermediate: 0, advanced: 0, expert: 0)
        )
    }
}
