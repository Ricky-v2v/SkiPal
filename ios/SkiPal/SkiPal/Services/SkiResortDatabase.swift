//
//  SkiResortDatabase.swift
//  SkiPal
//
//  雪场数据库服务 - 加载和管理全球雪场数据
//

import Foundation
import CoreLocation

/// 雪场数据库服务
class SkiResortDatabase: ObservableObject {
    @Published var resorts: [SkiResort] = []
    @Published var isLoading = false
    @Published var loadError: String?
    @Published var nearbyResorts: [SkiResort] = []
    
    static let shared = SkiResortDatabase()
    
    private let databaseQueue = DispatchQueue(label: "com.skipal.resortdb", qos: .userInitiated)
    private var isLoaded = false
    
    private init() {}
    
    /// 加载雪场数据
    func loadResorts() async {
        guard !isLoaded && !isLoading else { return }
        
        await MainActor.run {
            isLoading = true
        }
        
        do {
            guard let url = Bundle.main.url(forResource: "ski_resorts", withExtension: "json") else {
                print("❌ 未找到雪场数据文件")
                await MainActor.run {
                    isLoading = false
                    loadError = "未找到雪场数据文件"
                }
                return
            }
            
            let data = try Data(contentsOf: url)
            let decoder = JSONDecoder()
            let container = try decoder.decode(SkiResortContainer.self, from: data)
            
            await MainActor.run {
                self.resorts = container.resorts.sorted { $0.name < $1.name }
                self.isLoaded = true
                self.isLoading = false
                print("✅ 成功加载 \(self.resorts.count) 个雪场")
            }
        } catch {
            print("❌ 加载雪场数据失败：\(error.localizedDescription)")
            await MainActor.run {
                self.loadError = error.localizedDescription
                self.isLoading = false
            }
        }
    }
    
    /// 根据坐标检测附近雪场 (5km 范围内)
    func detectNearbyResorts(location: CLLocation, radius: Double = 5000) {
        databaseQueue.async { [weak self] in
            guard let self = self else { return }
            
            let nearby = self.resorts.filter { resort in
                let resortLocation = resort.location
                let distance = location.distance(from: resortLocation)
                return distance <= radius
            }.sorted { location.distance(from: $0.location) < location.distance(from: $1.location) }
            
            DispatchQueue.main.async {
                self.nearbyResorts = nearby
                if let closest = nearby.first {
                    let distance = location.distance(from: closest.location)
                    print("📍 检测到最近雪场：\(closest.name) (距离：\(String(format: "%.1f", distance/1000))km)")
                }
            }
        }
    }
    
    /// 根据名称搜索雪场
    func searchResorts(query: String) -> [SkiResort] {
        let lowercasedQuery = query.lowercased()
        return resorts.filter {
            $0.name.lowercased().contains(lowercasedQuery) ||
            ($0.nameEn?.lowercased().contains(lowercasedQuery) ?? false)
        }
    }
    
    /// 根据国家/地区筛选雪场
    func filterResorts(byCountry country: String) -> [SkiResort] {
        resorts.filter { $0.country == country }
    }
    
    /// 获取所有国家列表
    var availableCountries: [String] {
        Set(resorts.map { $0.country }).sorted()
    }
}

/// JSON 容器结构
struct SkiResortContainer: Codable {
    let resorts: [SkiResort]
}
