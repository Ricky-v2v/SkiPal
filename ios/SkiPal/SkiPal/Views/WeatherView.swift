//
//  WeatherView.swift
//  SkiPal
//
//  天气视图 - 显示当前雪场天气和预报
//

import SwiftUI

/// 天气视图
struct WeatherView: View {
    @ObservedObject var weatherService: WeatherService
    @ObservedObject var resortDatabase: SkiResortDatabase
    @State private var selectedResort: SkiResort?
    @State private var showingResortPicker = false
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // 雪场选择器
                    resortPickerSection
                    
                    // 当前天气
                    if let weather = weatherService.currentWeather {
                        currentWeatherCard(weather: weather)
                        
                        // 滑雪指数
                        skiIndexCard(skiIndex: weather.skiIndex)
                        
                        // 5 天预报
                        forecastSection(forecast: weather.forecast)
                    } else if weatherService.isLoading {
                        loadingView
                    } else if let error = weatherService.error {
                        errorView(error: error)
                    } else {
                        emptyStateView
                    }
                }
                .padding()
            }
            .navigationTitle("雪场天气")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showingResortPicker = true }) {
                        Image(systemName: "list.bullet")
                    }
                }
            }
            .sheet(isPresented: $showingResortPicker) {
                ResortPickerView(
                    resorts: resortDatabase.resorts,
                    selectedResort: $selectedResort
                )
            }
            .task {
                await resortDatabase.loadResorts()
            }
            .onChange(of: selectedResort) { _, newValue in
                if let resort = newValue {
                    Task {
                        await weatherService.fetchWeather(for: resort.location)
                    }
                }
            }
        }
    }
    
    // MARK: - 子视图
    
    private var resortPickerSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("选择雪场")
                .font(.headline)
                .foregroundColor(.secondary)
            
            Button(action: { showingResortPicker = true }) {
                HStack {
                    Image(systemName: "mountain.fill")
                        .foregroundColor(.blue)
                    
                    if let resort = selectedResort {
                        VStack(alignment: .leading) {
                            Text(resort.name)
                                .font(.headline)
                            Text(resort.region)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    } else {
                        Text("选择雪场...")
                            .font(.headline)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    Image(systemName: "chevron.right")
                        .foregroundColor(.secondary)
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(12)
            }
        }
    }
    
    private func currentWeatherCard(weather: SkiWeather) -> some View {
        VStack(spacing: 15) {
            // 天气图标和温度
            HStack {
                VStack(alignment: .leading, spacing: 5) {
                    Text(weather.weatherDescription)
                        .font(.title2)
                        .fontWeight(.semibold)
                    
                    Text(String(format: "%.0f°C", weather.temperature))
                        .font(.system(size: 48, weight: .bold, design: .rounded))
                }
                
                Spacer()
                
                Image(systemName: weatherIconName(for: weather.weatherCode))
                    .font(.system(size: 60))
                    .foregroundColor(.orange)
            }
            
            Divider()
            
            // 详细数据
            HStack(spacing: 20) {
                WeatherDetailItem(
                    icon: "wind",
                    label: "风速",
                    value: String(format: "%.0f", weather.windSpeed),
                    unit: "km/h"
                )
                
                WeatherDetailItem(
                    icon: "cloud.drizzle",
                    label: "降雪",
                    value: String(format: "%.1f", weather.snowfall),
                    unit: "cm"
                )
                
                WeatherDetailItem(
                    icon: "eye",
                    label: "能见度",
                    value: String(format: "%.0f", weather.visibility / 1000),
                    unit: "km"
                )
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 5)
    }
    
    private func skiIndexCard(skiIndex: Int) -> some View {
        VStack(spacing: 10) {
            Text("滑雪指数")
                .font(.headline)
                .foregroundColor(.secondary)
            
            HStack(alignment: .center, spacing: 15) {
                // 指数仪表
                ZStack {
                    Circle()
                        .stroke(Color.gray.opacity(0.2), lineWidth: 12)
                        .frame(width: 120, height: 120)
                    
                    Circle()
                        .trim(from: 0, to: CGFloat(skiIndex) / 100)
                        .stroke(
                            skiIndexColor(for: skiIndex),
                            style: StrokeStyle(lineWidth: 12, lineCap: .round)
                        )
                        .frame(width: 120, height: 120)
                        .rotationEffect(.degrees(-90))
                    
                    VStack {
                        Text("\(skiIndex)")
                            .font(.system(size: 36, weight: .bold, design: .rounded))
                        Text("/ 100")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                VStack(alignment: .leading, spacing: 5) {
                    Text(SkiWeather(skiIndex: skiIndex).skiIndexDescription)
                        .font(.title2)
                        .fontWeight(.semibold)
                        .foregroundColor(skiIndexColor(for: skiIndex))
                    
                    Text(skiIndexDescription(for: skiIndex))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 5)
    }
    
    private func forecastSection(forecast: [DailyForecast]) -> some View {
        VStack(alignment: .leading, spacing: 15) {
            Text("5 天预报")
                .font(.headline)
                .foregroundColor(.secondary)
            
            VStack(spacing: 10) {
                ForEach(forecast) { day in
                    ForecastRow(forecast: day)
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 5)
    }
    
    private var loadingView: some View {
        VStack(spacing: 20) {
            ProgressView()
                .scaleEffect(1.5)
            Text("正在获取天气数据...")
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, minHeight: 300)
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "cloud.sun")
                .font(.system(size: 60))
                .foregroundColor(.secondary)
            
            Text("选择一个雪场查看天气")
                .font(.headline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, minHeight: 300)
    }
    
    private func errorView(error: String) -> some View {
        VStack(spacing: 20) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 60))
                .foregroundColor(.orange)
            
            Text("获取天气失败")
                .font(.headline)
                .foregroundColor(.secondary)
            
            Text(error)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            Button(action: {
                Task {
                    if let resort = selectedResort {
                        await weatherService.fetchWeather(for: resort.location)
                    }
                }
            }) {
                Label("重试", systemImage: "arrow.clockwise")
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(10)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 300)
    }
    
    // MARK: - 辅助方法
    
    private func weatherIconName(for code: Int) -> String {
        switch code {
        case 0: return "sun.max.fill"
        case 1, 2, 3: return "cloud.sun.fill"
        case 45, 48: return "cloud.fog.fill"
        case 51...55, 61...65: return "cloud.rain.fill"
        case 71...77, 85, 86: return "cloud.snow.fill"
        case 80...82: return "cloud.sun.rain.fill"
        case 95...99: return "cloud.bolt.rain.fill"
        default: return "cloud.fill"
        }
    }
    
    private func skiIndexColor(for index: Int) -> Color {
        switch index {
        case 0..<20: return .gray
        case 20..<40: return .orange
        case 40..<60: return .yellow
        case 60..<80: return .green
        default: return .blue
        }
    }
    
    private func skiIndexDescription(for index: Int) -> String {
        switch index {
        case 0..<20: return "条件较差，谨慎出行"
        case 20..<40: return "条件一般，适合练习"
        case 40..<60: return "条件良好，适合滑雪"
        case 60..<80: return "条件很好，强烈推荐"
        default: return "完美条件，不要错过！"
        }
    }
}

// MARK: - 子组件

struct WeatherDetailItem: View {
    let icon: String
    let label: String
    let value: String
    let unit: String
    
    var body: some View {
        VStack(spacing: 5) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(.blue)
            
            Text(value)
                .font(.title3)
                .fontWeight(.semibold)
            
            Text("\(label) · \(unit)")
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

struct ForecastRow: View {
    let forecast: DailyForecast
    
    var body: some View {
        HStack {
            Text(formatDate(forecast.date))
                .font(.subheadline)
                .frame(width: 80, alignment: .leading)
            
            Image(systemName: weatherIconName(for: forecast.weatherCode))
                .font(.title2)
                .foregroundColor(.orange)
                .frame(width: 40)
            
            VStack(alignment: .leading) {
                Text(String(format: "%.0f° / %.0f°", forecast.tempMax, forecast.tempMin))
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                if forecast.snowfall > 0 {
                    Text(String(format: "🌨️ %.1fcm", forecast.snowfall))
                        .font(.caption2)
                        .foregroundColor(.blue)
                }
            }
            
            Spacer()
            
            SkiIndexBadge(index: forecast.skiIndex)
        }
        .padding(.vertical, 5)
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MM/dd"
        return formatter.string(from: date)
    }
    
    private func weatherIconName(for code: Int) -> String {
        switch code {
        case 0: return "sun.max.fill"
        case 1, 2, 3: return "cloud.sun.fill"
        case 45, 48: return "cloud.fog.fill"
        case 51...55, 61...65: return "cloud.rain.fill"
        case 71...77, 85, 86: return "cloud.snow.fill"
        case 80...82: return "cloud.sun.rain.fill"
        case 95...99: return "cloud.bolt.rain.fill"
        default: return "cloud.fill"
        }
    }
}

struct SkiIndexBadge: View {
    let index: Int
    
    var body: some View {
        Text("\(index)")
            .font(.caption)
            .fontWeight(.bold)
            .foregroundColor(indexColor)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(indexColor.opacity(0.1))
            .cornerRadius(8)
    }
    
    private var indexColor: Color {
        switch index {
        case 0..<20: return .gray
        case 20..<40: return .orange
        case 40..<60: return .yellow
        case 60..<80: return .green
        default: return .blue
        }
    }
}

struct ResortPickerView: View {
    let resorts: [SkiResort]
    @Binding var selectedResort: SkiResort?
    @Environment(\.dismiss) var dismiss
    @State private var searchText = ""
    
    var filteredResorts: [SkiResort] {
        if searchText.isEmpty {
            return resorts
        }
        return resorts.filter {
            $0.name.contains(searchText) ||
            ($0.nameEn?.contains(searchText) ?? false) ||
            $0.region.contains(searchText)
        }
    }
    
    var body: some View {
        NavigationView {
            List(filteredResorts) { resort in
                Button(action: {
                    selectedResort = resort
                    dismiss()
                }) {
                    VStack(alignment: .leading, spacing: 5) {
                        HStack {
                            Text(resort.name)
                                .font(.headline)
                            
                            if resort.isMajorResort {
                                Text("大雪场")
                                    .font(.caption2)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 2)
                                    .background(Color.blue.opacity(0.1))
                                    .cornerRadius(4)
                            }
                        }
                        
                        Text("\(resort.region), \(resort.country)")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        Text(resort.difficultyDescription)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .searchable(text: $searchText, prompt: "搜索雪场")
            .navigationTitle("选择雪场")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("取消") {
                        dismiss()
                    }
                }
            }
        }
    }
}

// Helper extension for SkiWeather initialization with partial data
extension SkiWeather {
    init(skiIndex: Int) {
        self.temperature = 0
        self.feelsLike = 0
        self.snowfall = 0
        self.windSpeed = 0
        self.visibility = 0
        self.weatherCode = 0
        self.skiIndex = skiIndex
        self.forecast = []
    }
}
