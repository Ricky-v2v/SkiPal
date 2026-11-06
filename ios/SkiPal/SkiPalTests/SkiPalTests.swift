//
//  SkiPalTests.swift
//  SkiPalTests
//
//  SkiPal 单元测试
//

import XCTest
import CoreLocation
@testable import SkiPal

final class SkiPalTests: XCTestCase {

    // SkiLocation 只提供从 CLLocation 转换的初始化方法。
    private func makeSkiLocation(
        latitude: Double,
        longitude: Double,
        altitude: Double,
        speed: Double,
        course: Double,
        timestamp: Date = Date()
    ) -> SkiLocation {
        let location = CLLocation(
            coordinate: CLLocationCoordinate2D(latitude: latitude, longitude: longitude),
            altitude: altitude,
            horizontalAccuracy: 5,
            verticalAccuracy: 5,
            course: course,
            speed: speed,
            timestamp: timestamp
        )
        return SkiLocation(from: location)
    }
    
    // MARK: - SkiSession 测试
    
    func testSkiSessionInitialization() {
        let expectedID = UUID()
        let session = SkiSession(id: expectedID)
        
        XCTAssertEqual(session.id, expectedID)
        XCTAssertEqual(session.locations.count, 0)
        XCTAssertEqual(session.duration, 0, accuracy: 1.0)
        XCTAssertEqual(session.totalDistance, 0)
        XCTAssertEqual(session.maxSpeed, 0)
    }
    
    func testSkiSessionWithLocations() {
        let location1 = makeSkiLocation(
            latitude: 40.3089,
            longitude: 116.6231,
            altitude: 450,
            speed: 10,
            course: 0
        )
        
        let location2 = makeSkiLocation(
            latitude: 40.3099,
            longitude: 116.6241,
            altitude: 440,
            speed: 15,
            course: 45
        )
        
        let session = SkiSession(locations: [location1, location2])
        
        XCTAssertEqual(session.locations.count, 2)
        XCTAssertEqual(session.maxSpeed, 15)
        XCTAssertGreaterThan(session.totalDistance, 0)
    }
    
    func testAchievementStars() {
        var session = SkiSession()
        session.locations = Array(repeating: makeSkiLocation(
            latitude: 40.0,
            longitude: 116.0,
            altitude: 500,
            speed: 35,  // > 30 km/h
            course: 0
        ), count: 100)
        session.endTime = Date()
        
        // 速度>30 应该获得至少 2 星
        XCTAssertGreaterThanOrEqual(session.achievementStars, 2)
    }
    
    // MARK: - SkiResort 测试
    
    func testSkiResortLocation() {
        let resort = SkiResort(
            id: UUID(),
            name: "南山滑雪场",
            nameEn: "Nanshan",
            country: "中国",
            region: "北京",
            latitude: 40.3089,
            longitude: 116.6231,
            baseElevation: 450,
            summitElevation: 680,
            totalRuns: 22,
            difficultyDistribution: DifficultyDistribution(beginner: 8, intermediate: 10, advanced: 4, expert: 0),
            website: nil,
            imageUrl: nil
        )
        
        XCTAssertEqual(resort.location.coordinate.latitude, 40.3089, accuracy: 0.001)
        XCTAssertEqual(resort.location.coordinate.longitude, 116.6231, accuracy: 0.001)
    }
    
    // MARK: - WeatherService 测试
    
    func testSkiIndexCalculation() {
        let service = WeatherService.shared
        
        // 理想条件：-10°C, 10cm 雪，10km/h 风，10000m 能见度
        let idealIndex = service.calculateSkiIndex(
            temperature: -10,
            snowfall: 10,
            windSpeed: 10,
            visibility: 10000
        )
        
        XCTAssertGreaterThanOrEqual(idealIndex, 80, "理想条件滑雪指数应该>=80")
        
        // 差条件：5°C, 0cm 雪，50km/h 风，100m 能见度
        let poorIndex = service.calculateSkiIndex(
            temperature: 5,
            snowfall: 0,
            windSpeed: 50,
            visibility: 100
        )
        
        XCTAssertLessThan(poorIndex, 40, "差条件滑雪指数应该<40")
    }
    
    // MARK: - 性能测试
    
    func testPerformanceExample() throws {
        self.measure {
            var session = SkiSession()
            session.locations = (0..<1000).map { _ in
                self.makeSkiLocation(
                    latitude: 40.0 + Double.random(in: 0..<0.1),
                    longitude: 116.0 + Double.random(in: 0..<0.1),
                    altitude: 500 + Double.random(in: 0..<100),
                    speed: Double.random(in: 0..<50),
                    course: Double.random(in: 0..<360)
                )
            }
            session.endTime = Date()
            
            _ = session.totalDistance
            _ = session.maxSpeed
            _ = session.achievementStars
        }
    }
}
