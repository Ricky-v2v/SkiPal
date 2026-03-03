//
//  WeatherService.swift
//  SkiPal
//
//  天气服务 - 使用 Open-Meteo API 获取雪场天气
//

import Foundation
import CoreLocation

/// 滑雪天气数据
struct SkiWeather: Codable {
    let temperature: Double           // 当前温度 (°C)
    let feelsLike: Double             // 体感温度 (°C)
    let snowfall: Double              // 降雪量 (cm)
    let windSpeed: Double             // 风速 (km/h)
    let visibility: Double            // 能见度 (m)
    let weatherCode: Int              // 天气代码
    let skiIndex: Int                 // 滑雪指数 (0-100)
    let forecast: [DailyForecast]     // 5 天预报
    
    /// 天气描述
    var weatherDescription: String {
        switch weatherCode {
        case 0: return "☀️ 晴朗"
        case 1, 2, 3: return "⛅ 多云"
        case 45, 48: return "🌫️ 雾"
        case 51, 53, 55: return "🌧️ 毛毛雨"
        case 61, 63, 65: return "🌧️ 雨"
        case 71, 73, 75: return "🌨️ 雪"
        case 77: return "🌨️ 阵雪"
        case 80, 81, 82: return "🌦️ 阵雨"
        case 85, 86: return "🌨️ 雪阵"
        case 95, 96, 99: return "⛈️ 雷雨"
        default: return "🌤️ 未知"
        }
    }
    
    /// 滑雪指数描述
    var skiIndexDescription: String {
        switch skiIndex {
        case 0..<20: return "😐 较差"
        case 20..<40: return "🙂 一般"
        case 40..<60: return "😊 良好"
        case 60..<80: return "😄 很好"
        case 80..<100: return "🤩 极佳"
        default: return "完美"
        }
    }
}

/// 每日预报
struct DailyForecast: Codable, Identifiable {
    let id: UUID
    let date: Date
    let tempMax: Double
    let tempMin: Double
    let snowfall: Double
    let windSpeed: Double
    let weatherCode: Int
    let skiIndex: Int
    
    init(id: UUID = UUID(), date: Date, tempMax: Double, tempMin: Double, snowfall: Double, windSpeed: Double, weatherCode: Int, skiIndex: Int) {
        self.id = id
        self.date = date
        self.tempMax = tempMax
        self.tempMin = tempMin
        self.snowfall = snowfall
        self.windSpeed = windSpeed
        self.weatherCode = weatherCode
        self.skiIndex = skiIndex
    }
}

/// 天气服务
class WeatherService: ObservableObject {
    @Published var currentWeather: SkiWeather?
    @Published var isLoading = false
    @Published var error: String?
    
    static let shared = WeatherService()
    
    private let baseURL = "https://api.open-meteo.com/v1"
    private let session = URLSession.shared
    
    private init() {}
    
    /// 获取雪场天气
    func fetchWeather(for location: CLLocation) async {
        await MainActor.run {
            isLoading = true
            error = nil
        }
        
        let lat = location.coordinate.latitude
        let lon = location.coordinate.longitude
        
        let urlString = """
        \(baseURL)/forecast?latitude=\(lat)&longitude=\(lon)&current=temperature_2m,relative_humidity_2m,weather_code,wind_speed_10m,snowfall,visibility&daily=weather_code,temperature_2m_max,temperature_2m_min,snowfall_sum,wind_speed_10m_max&timezone=auto&forecast_days=5
        """
        
        guard let url = URL(string: urlString) else {
            await MainActor.run {
                error = "无效的 URL"
                isLoading = false
            }
            return
        }
        
        do {
            let (data, response) = try await session.data(from: url)
            
            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                throw NSError(domain: "WeatherService", code: -1, userInfo: [NSLocalizedDescriptionKey: "网络请求失败"])
            }
            
            let decoder = JSONDecoder()
            // Open-Meteo uses ISO8601 dates like "2024-01-15" for daily data
            decoder.dateDecodingStrategy = .custom { decoder in
                let container = try decoder.singleValueContainer()
                let dateString = try container.decode(String.self)

                // Try full ISO8601 with time first
                if let date = ISO8601DateFormatter().date(from: dateString) {
                    return date
                }

                // Fallback to date-only format "YYYY-MM-DD"
                let formatter = DateFormatter()
                formatter.dateFormat = "yyyy-MM-dd"
                formatter.timeZone = TimeZone(secondsFromGMT: 0)

                if let date = formatter.date(from: dateString) {
                    return date
                }

                throw DecodingError.dataCorruptedError(in: container, debugDescription: "Cannot decode date: \(dateString)")
            }
            
            let weatherData = try decoder.decode(OpenMeteoResponse.self, from: data)
            let skiWeather = weatherData.toSkiWeather()
            
            await MainActor.run {
                self.currentWeather = skiWeather
                self.isLoading = false
            }
            
            print("✅ 天气数据获取成功 - 滑雪指数：\(skiWeather.skiIndex)")
            
        } catch {
            print("❌ 获取天气失败：\(error.localizedDescription)")
            await MainActor.run {
                self.error = error.localizedDescription
                self.isLoading = false
            }
        }
    }
    
    /// 计算滑雪指数 (0-100)
    public func calculateSkiIndex(temperature: Double, snowfall: Double, windSpeed: Double, visibility: Double) -> Int {
        var index = 50  // 基础分数
        
        // 温度因素 (-20°C 到 -5°C 最佳)
        if temperature >= -20 && temperature <= -5 {
            index += 20
        } else if temperature >= -30 && temperature <= 0 {
            index += 10
        } else if temperature > 0 {
            index -= Int(min(temperature * 5, 20))
        }
        
        // 降雪因素 (新雪 5-20cm 最佳)
        if snowfall >= 5 && snowfall <= 20 {
            index += 25
        } else if snowfall > 20 {
            index += 15  // 太多雪可能影响视线
        } else if snowfall > 0 {
            index += 10
        }
        
        // 风速因素 (<15km/h 最佳)
        if windSpeed < 15 {
            index += 15
        } else if windSpeed < 30 {
            index += 5
        } else if windSpeed > 50 {
            index -= 20  // 强风危险
        }
        
        // 能见度因素 (>1000m 最佳)
        if visibility > 5000 {
            index += 10
        } else if visibility > 1000 {
            index += 5
        } else if visibility < 100 {
            index -= 20  // 能见度太低
        }
        
        return max(0, min(100, index))
    }
}

/// Open-Meteo API 响应结构
struct OpenMeteoResponse: Codable {
    let current: CurrentWeather?
    let daily: DailyWeather?
    
    struct CurrentWeather: Codable {
        let temperature_2m: Double?
        let relative_humidity_2m: Double?
        let weather_code: Int?
        let wind_speed_10m: Double?
        let snowfall: Double?
        let visibility: Double?
    }
    
    struct DailyWeather: Codable {
        let time: [Date]?
        let weather_code: [Int]?
        let temperature_2m_max: [Double]?
        let temperature_2m_min: [Double]?
        let snowfall_sum: [Double]?
        let wind_speed_10m_max: [Double]?
    }
    
    func toSkiWeather() -> SkiWeather {
        let current = self.current ?? CurrentWeather(
            temperature_2m: 0,
            relative_humidity_2m: 50,
            weather_code: 0,
            wind_speed_10m: 0,
            snowfall: 0,
            visibility: 10000
        )
        
        let temperature = current.temperature_2m ?? 0
        let snowfall = current.snowfall ?? 0
        let windSpeed = current.wind_speed_10m ?? 0
        let visibility = current.visibility ?? 10000
        
        let skiIndex = WeatherService.shared.calculateSkiIndex(
            temperature: temperature,
            snowfall: snowfall,
            windSpeed: windSpeed,
            visibility: visibility
        )
        
        // 生成 5 天预报
        var forecasts: [DailyForecast] = []
        if let daily = self.daily, let times = daily.time {
            for i in 0..<min(times.count, 5) {
                let forecast = DailyForecast(
                    date: times[i],
                    tempMax: daily.temperature_2m_max?[i] ?? 0,
                    tempMin: daily.temperature_2m_min?[i] ?? 0,
                    snowfall: daily.snowfall_sum?[i] ?? 0,
                    windSpeed: daily.wind_speed_10m_max?[i] ?? 0,
                    weatherCode: daily.weather_code?[i] ?? 0,
                    skiIndex: WeatherService.shared.calculateSkiIndex(temperature: daily.temperature_2m_max?[i] ?? 0, snowfall: daily.snowfall_sum?[i] ?? 0, windSpeed: daily.wind_speed_10m_max?[i] ?? 0, visibility: 10000)
                )
                forecasts.append(forecast)
            }
        }
        
        return SkiWeather(
            temperature: temperature,
            feelsLike: temperature - (windSpeed * 0.5),  // 简化体感温度计算
            snowfall: snowfall,
            windSpeed: windSpeed,
            visibility: visibility,
            weatherCode: current.weather_code ?? 0,
            skiIndex: skiIndex,
            forecast: forecasts
        )
    }
}
