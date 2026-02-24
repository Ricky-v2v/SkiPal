//
//  SkiMapView.swift
//  SkiPal
//
//  地图视图 - 显示滑雪轨迹
//

import SwiftUI
import MapKit

struct SkiMapView: View {
    @EnvironmentObject var locationService: LocationService
    @EnvironmentObject var recordingService: RecordingService
    
    @State private var cameraPosition: MapCameraPosition = .userLocation(followsHeading: true, fallback: .automatic)
    @State private var selectedMapStyle: MapStyle = .standard
    
    var body: some View {
        NavigationView {
            Map(position: $cameraPosition) {
                // 当前位置
                UserAnnotation()
                
                // 当前记录的轨迹
                if !recordingService.currentPath.isEmpty {
                    MapPolyline(coordinates: recordingService.currentPath.map { $0.coordinate })
                        .stroke(.blue, lineWidth: 4)
                }
            }
            .mapStyle(selectedMapStyle)
            .mapControls {
                MapUserLocationButton()
                MapCompass()
                MapScaleView()
            }
            .overlay(alignment: .top) {
                if recordingService.isRecording {
                    RecordingBanner()
                }
            }
            .overlay(alignment: .bottomTrailing) {
                MapControlsOverlay()
            }
            .navigationTitle("轨迹地图")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button("标准") { selectedMapStyle = .standard }
                        Button("卫星") { selectedMapStyle = .imagery }
                        Button("混合") { selectedMapStyle = .hybrid }
                    } label: {
                        Image(systemName: "map")
                    }
                }
            }
        }
    }
}

// MARK: - 记录中横幅
struct RecordingBanner: View {
    @EnvironmentObject var recordingService: RecordingService
    
    var body: some View {
        HStack(spacing: 10) {
            Circle()
                .fill(.red)
                .frame(width: 10, height: 10)
                .overlay(
                    Circle()
                        .stroke(.red, lineWidth: 2)
                        .scaleEffect(1.5)
                        .opacity(0.5)
                )
                .animation(.easeInOut(duration: 1).repeatForever(autoreverses: true), value: UUID())
            
            Text("正在记录轨迹...")
                .font(.subheadline)
                .fontWeight(.medium)
            
            Spacer()
            
            Text(formatDuration(recordingService.currentDuration))
                .font(.subheadline)
                .fontWeight(.bold)
                .monospacedDigit()
        }
        .foregroundStyle(.white)
        .padding()
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .padding()
    }
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let hours = Int(duration) / 3600
        let minutes = Int(duration) / 60 % 60
        let seconds = Int(duration) % 60
        
        if hours > 0 {
            return String(format: "%02d:%02d:%02d", hours, minutes, seconds)
        } else {
            return String(format: "%02d:%02d", minutes, seconds)
        }
    }
}

// MARK: - 地图控制覆盖层
struct MapControlsOverlay: View {
    @EnvironmentObject var locationService: LocationService
    
    var body: some View {
        VStack(spacing: 10) {
            Button(action: {
                // 定位到当前位置
            }) {
                Image(systemName: "location.fill")
                    .font(.title2)
                    .foregroundStyle(.white)
                    .frame(width: 50, height: 50)
                    .background(.ultraThinMaterial)
                    .clipShape(Circle())
            }
        }
        .padding()
    }
}

// MARK: - 轨迹预览（用于历史记录详情）
struct TrajectoryPreview: View {
    let locations: [SkiLocation]
    
    var body: some View {
        Map {
            MapPolyline(coordinates: locations.map { $0.coordinate })
                .stroke(.blue, lineWidth: 3)
            
            if let first = locations.first {
                Marker("起点", coordinate: first.coordinate)
            }
            
            if let last = locations.last, locations.count > 1 {
                Marker("终点", coordinate: last.coordinate)
            }
        }
        .mapStyle(.standard)
        .frame(height: 200)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

#Preview {
    SkiMapView()
        .environmentObject(LocationService())
        .environmentObject(RecordingService(locationService: LocationService()))
}
